extends Node3D

const BOT_NAMES: PackedStringArray = ["VEX-9", "KIRA", "NOVA", "RIFT", "JINX", "HALO"]
const BOT_COLORS: Array[Color] = [
	Color("ff5a3c"), Color("c9ff4a"), Color("d56bff"), Color("7eb6ff"), Color("ffd15a"), Color("ff4f93"),
]

var terrain: TerrainField
var roads: RoadNetwork
var player: HoverCar
var bots: Array[HoverCar] = []
var race := RaceDirector.new()
var cam: Camera3D
var hud: GameHud
var beacon_positions: Array[Vector3] = []
var beacon_roots: Array[Node3D] = []
var gates: Array[Node3D] = []
var gate_mats: Array[StandardMaterial3D] = []
var near_race := -1
var waypoint := -1
var safe_pos := Vector3.ZERO
var safe_yaw := 0.0
var rock_grid: Dictionary = {}
var overview := false
var _smoke := false
var _gate_root: Node3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var arrival
var wasteland
var camera_mode := 0
var _snap_camera := false
var storm_level := 0.0
var run_over := false
var port_position := Vector3.ZERO
var port_yaw := 0.0
var _sky_mat: ShaderMaterial
var _storm_fx: GPUParticles3D
var _wind_fx: GPUParticles3D
var _storm_flash := 0.0
var _wreck_light: OmniLight3D
var _wreck_age := -1.0
var _roads_done := false
var _finish_until := 0

const VIEW_NAMES: PackedStringArray = ["CHASE", "FAR", "HOOD", "BUMPER"]
const ArrivalScene := preload("res://scenes/loading/arrival.tscn")
const CarScene := preload("res://scenes/vehicles/hover_car.tscn")
const BeaconScene := preload("res://scenes/props/beacon.tscn")
const GateScene := preload("res://scenes/props/gate.tscn")
const ShipScene := preload("res://scenes/loading/starship.tscn")
const WastelandScript := preload("res://scripts/wasteland_view.gd")


func _ready() -> void:
	add_to_group("world")
	process_priority = -1
	_smoke = "--smoke" in OS.get_cmdline_user_args()
	if GameState.world_seed < 1:
		GameState.begin_new_world()
	_env = WorldEnvironment.new()
	_env.environment = _space_environment()
	add_child(_env)
	arrival = ArrivalScene.instantiate()
	if _smoke:
		arrival.voyage_time = 0.45
	add_child(arrival)
	for _i in 20:
		await get_tree().process_frame
	if _smoke:
		var loading_img := get_viewport().get_texture().get_image()
		if loading_img != null and loading_img.get_width() > 0:
			loading_img.save_png(ProjectSettings.globalize_path("res://_load.png"))
			print("LOAD SHOT")
	arrival.set_progress(0.06, "STARSHIP INBOUND")
	for _warm in 8:
		await get_tree().process_frame
	terrain = TerrainField.new()
	terrain.begin(GameState.world_seed)
	var band := 4
	for z in range(0, TerrainField.RES, band):
		terrain.write_rows(z, mini(z + band, TerrainField.RES))
		arrival.set_progress(0.08 + 0.36 * float(z) / float(TerrainField.RES), "MAPPING THE DUNES")
		await get_tree().process_frame
	arrival.set_progress(0.46, "THREADING THE ROAD NETWORK")
	var field := terrain
	var seed := GameState.world_seed
	_roads_done = false
	WorkerThreadPool.add_task(func() -> void:
		var net := RoadNetwork.new()
		net.generate(field, seed)
		call_deferred("_finish_roads", net)
	)
	while not _roads_done:
		await get_tree().process_frame
	_place_spaceport()
	arrival.set_progress(0.5, "SHAPING THE SURFACE")
	await get_tree().process_frame
	await DesertView.build(self, terrain, roads, self)
	wasteland = WastelandScript.new()
	add_child(wasteland)
	await wasteland.build(terrain, self)
	_index_rocks()
	_gate_root = Node3D.new()
	_gate_root.name = "Gates"
	add_child(_gate_root)
	_spawn_beacons()
	_build_spaceport()
	_spawn_player()
	_spawn_ambient()
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-18, 32, 0)
	_sun.light_color = Color(1.0, 0.92, 0.74)
	_sun.light_energy = 1.55
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 340.0
	_sun.directional_shadow_blend_splits = false
	_sun.directional_shadow_fade_start = 0.78
	_sun.visible = false
	add_child(_sun)
	cam = Camera3D.new()
	cam.current = false
	cam.fov = 70.0
	cam.near = 0.08
	cam.far = 4800.0
	add_child(cam)
	cam.global_position = player.global_position + Vector3(0, 6, 12)
	player.controls_enabled = false
	while arrival.elapsed < arrival.voyage_time:
		await get_tree().process_frame
	await arrival.play_out(func() -> void:
		_env.environment = _desert_environment()
		_sun.visible = true
		cam.current = true
	)
	arrival = null
	player.controls_enabled = true
	hud = GameHud.new()
	add_child(hud)
	hud.bind(self)
	_build_storm()
	if _smoke:
		player.smoke_drive = true
		_run_smoke()


func _finish_roads(net: RoadNetwork) -> void:
	roads = net
	_roads_done = true


func sample_surface(p: Vector3) -> Dictionary:
	return roads.sample(p.x, p.z)


func place_car(car: HoverCar, pos: Vector3, dir: Vector3, speed: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.01:
		flat = Vector3(0, 0, -1)
	flat = flat.normalized()
	var surface := sample_surface(pos)
	var y := float(surface.height) + float(car.stats.hover)
	car.global_position = Vector3(pos.x, y, pos.z)
	car.yaw = Util.yaw_from_forward(flat)
	car.air_pitch = 0.0
	car.air_roll = 0.0
	car.airborne = false
	car.left_pad = false
	car.velocity = flat * speed
	car.reset_motion_filters()
	car.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, car.yaw, 0.0)), car.global_position)


func wreck_player(at: Vector3) -> void:
	if run_over:
		return
	run_over = true
	if race.active or race.started:
		for bot in bots:
			bot.controls_enabled = false
			bot.velocity = Vector3.ZERO
	player.wrecked = true
	player.controls_enabled = false
	player.visible = false
	player.velocity = Vector3.ZERO
	_spawn_explosion(at)
	if hud:
		hud.show_game_over()


func _spawn_explosion(at: Vector3) -> void:
	var boom := GPUParticles3D.new()
	boom.one_shot = true
	boom.explosiveness = 0.92
	boom.amount = 110
	boom.lifetime = 1.15
	boom.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 18, 24))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.6
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0, -6.0, 0)
	mat.scale_min = 0.6
	mat.scale_max = 2.4
	mat.color = Color(1.0, 0.45, 0.12, 0.9)
	boom.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qmat.albedo_color = Color(1.0, 0.55, 0.2, 0.85)
	quad.material = qmat
	boom.draw_pass_1 = quad
	add_child(boom)
	boom.global_position = at + Vector3(0, 0.8, 0)
	boom.emitting = true
	_wreck_light = OmniLight3D.new()
	add_child(_wreck_light)
	_wreck_light.global_position = at + Vector3(0, 1.5, 0)
	_wreck_light.light_color = Color(1.0, 0.46, 0.16)
	_wreck_light.light_energy = 10.0
	_wreck_light.omni_range = 36.0
	_wreck_age = 0.0


func recover_car(car: HoverCar) -> void:
	if car.wrecked or run_over:
		return
	if race.active and race.started:
		race.respawn(car)
		return
	var dir := Util.forward_from_yaw(safe_yaw)
	place_car(car, safe_pos, dir, 0.0)


func start_race(index: int) -> void:
	if race.active or index < 0 or index >= roads.races.size():
		return
	var def: Dictionary = roads.races[index]
	_clear_bots()
	_clear_gates()
	_build_gates(def)
	var slots := _grid_slots(def)
	player.controls_enabled = false
	player.finished = false
	player.boost = 100.0
	place_car(player, slots[0], def.start_dir, 0.0)
	var race_bots: Array[HoverCar] = []
	var skills: Array[float] = [0.7, 0.8, 0.88, 0.95]
	for i in 4:
		var bot := _make_bot(BOT_NAMES[i], BOT_COLORS[i], skills[i], i % GameState.PRESETS.size())
		bot.ai = true
		bot.ai_loop = str(def.type) == "circuit"
		bot.ai_points = def.points
		bot.ai_dists = def.distances
		bot.controls_enabled = false
		place_car(bot, slots[i + 1], def.start_dir, 0.0)
		bots.append(bot)
		race_bots.append(bot)
	waypoint = index
	race.begin(self, index, def, player, race_bots)
	if hud:
		hud.dismiss_menus()


func restore_at_port() -> void:
	if player == null:
		return
	run_over = false
	player.wrecked = false
	player.visible = true
	player.boost = 100.0
	player.controls_enabled = true
	stop_race()
	var fwd := Util.forward_from_yaw(port_yaw)
	var right := Util.right_from_yaw(port_yaw)
	var spawn := port_position + right * 10.0 + fwd * 2.0 + Vector3(0, 0.4, 0)
	place_car(player, spawn, fwd, 0.0)
	safe_pos = player.global_position
	safe_yaw = player.yaw
	_snap_camera = true
	_clear_finish_hold()
	if hud:
		hud.hide_game_over()
		hud._refresh()


func restart_wrecked_race() -> void:
	if player == null:
		return
	var index := race.race_index
	if index < 0:
		restore_at_port()
		return
	run_over = false
	player.wrecked = false
	player.visible = true
	player.boost = 100.0
	player.controls_enabled = true
	_snap_camera = true
	if hud:
		hud.hide_game_over()
	stop_race()
	start_race(index)


func stop_race() -> void:
	_clear_finish_hold()
	var racing: bool = race.active or race.started or gates.size() > 0
	race.active = false
	race.started = false
	race.finished = false
	race.just_finished = false
	race.countdown = 0.0
	race.go_time = 0.0
	if player:
		player.finished = false
		player.cp_index = 1
		player.lap = 0
		player.wrong_way = false
		player.offtrack = 0.0
	if racing:
		_clear_bots()
		_clear_gates()
		waypoint = -1
		_spawn_ambient()
	if hud:
		hud.hide_results()


func return_to_roam() -> void:
	_clear_finish_hold()
	race.active = false
	race.started = false
	race.finished = false
	player.controls_enabled = true
	player.finished = false
	_clear_bots()
	_clear_gates()
	_spawn_ambient()
	if hud:
		hud.hide_results()


func retry_race() -> void:
	var index := race.race_index
	return_to_roam()
	start_race(index)


func _physics_process(dt: float) -> void:
	if player == null or run_over:
		return
	_separate_cars()
	if race.active:
		var was_finished := race.finished
		race.tick(dt)
		_highlight_gate()
		if race.just_finished and not was_finished:
			race.just_finished = false
			if hud and not run_over:
				_begin_finish_slowmo()
		if Input.is_action_just_pressed("reset") and race.started and not race.finished and not run_over:
			race.respawn(player)
	else:
		_update_prompt()
		if near_race >= 0 and Input.is_action_just_pressed("interact") and not player.airborne:
			start_race(near_race)
		_remember_safe(dt)
	if player and not race.active:
		safe_yaw = player.yaw


func _begin_finish_slowmo() -> void:
	Engine.time_scale = 0.25
	_finish_until = Time.get_ticks_msec() + 2400


func _clear_finish_hold() -> void:
	_finish_until = 0
	Engine.time_scale = 1.0
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false


func _process(dt: float) -> void:
	if _finish_until > 0 and Time.get_ticks_msec() >= _finish_until and not get_tree().paused:
		_finish_until = 0
		Engine.time_scale = 1.0
		if hud and not run_over:
			hud.show_results()
		get_tree().paused = true
	_update_storm(dt)
	if player != null and Input.is_action_just_pressed("camera_view") and not get_tree().paused:
		camera_mode = (camera_mode + 1) % VIEW_NAMES.size()
		_snap_camera = true
		if hud:
			hud.flash_view(VIEW_NAMES[camera_mode])
	_update_camera(dt)


func _space_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = false
	return env


func _desert_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/clouds.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.27, 0.48, 0.82))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.98, 0.74, 0.5))
	sky_mat.set_shader_parameter("ground_horizon", Color(0.9, 0.58, 0.32))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.42, 0.24, 0.14))
	var blow := terrain.wind_dir
	sky_mat.set_shader_parameter("wind_dir", Vector2(blow.x, blow.z))
	_sky_mat = sky_mat
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.00048
	env.fog_light_color = Color(0.9, 0.74, 0.55)
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.4
	return env


func _place_spaceport() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.world_seed + 77
	var best := Vector2(160.0, -90.0)
	var best_score := 100000.0
	for _n in 32:
		var p := Vector2(rng.randf_range(-560.0, 560.0), rng.randf_range(-560.0, 560.0))
		if roads.distance_to_road(p.x, p.y) < 78.0:
			continue
		var slope := terrain.slope_at(p.x, p.y)
		var h := terrain.height_at(p.x, p.y)
		if h > 42.0:
			continue
		var score := slope * 140.0 + absf(h - 9.0) * 0.06
		if score < best_score:
			best_score = score
			best = p
	var pad_h := terrain.height_at(best.x, best.y)
	terrain.stamp_pad(best.x, best.y, 84.0, pad_h)
	port_position = Vector3(best.x, pad_h, best.y)
	port_yaw = rng.randf_range(-PI, PI)


func _build_spaceport() -> void:
	var root := Node3D.new()
	root.name = "Spaceport"
	add_child(root)
	var fwd := Util.forward_from_yaw(port_yaw)
	var right := Util.right_from_yaw(port_yaw)
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(46.0, 0.32, 30.0)
	deck.mesh = deck_mesh
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.16, 0.18, 0.2)
	deck_mat.metallic = 0.72
	deck_mat.roughness = 0.38
	deck.material_override = deck_mat
	deck.position = port_position + Vector3(0, 0.16, 0)
	deck.rotation.y = port_yaw
	root.add_child(deck)
	var mark := MeshInstance3D.new()
	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(18.0, 0.06, 0.35)
	mark.mesh = mark_mesh
	var mark_mat := StandardMaterial3D.new()
	mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_mat.albedo_color = Color(0.25, 0.9, 1.0)
	mark_mat.emission_enabled = true
	mark_mat.emission = Color(0.2, 0.85, 1.0)
	mark_mat.emission_energy_multiplier = 2.2
	mark.material_override = mark_mat
	mark.position = port_position + fwd * 4.0 + Vector3(0, 0.36, 0)
	mark.rotation.y = port_yaw
	root.add_child(mark)
	for side in [-1.0, 1.0]:
		for along in [-1.0, 1.0]:
			var mast := MeshInstance3D.new()
			var mast_mesh := BoxMesh.new()
			mast_mesh.size = Vector3(0.35, 4.2, 0.35)
			mast.mesh = mast_mesh
			mast.material_override = deck_mat
			mast.position = port_position + right * 20.0 * side + fwd * 12.0 * along + Vector3(0, 2.1, 0)
			root.add_child(mast)
			var lamp := OmniLight3D.new()
			lamp.position = mast.position + Vector3(0, 2.3, 0)
			lamp.light_color = Color(0.45, 0.9, 1.0)
			lamp.light_energy = 2.4
			lamp.omni_range = 16.0
			root.add_child(lamp)
	var ship := ShipScene.instantiate()
	ship.name = "LandedShip"
	ship.scale = Vector3(7.2, 7.2, 7.2)
	ship.position = port_position + right * -14.0 + Vector3(0, 1.35, 0)
	ship.rotation.y = port_yaw
	root.add_child(ship)
	for flame in ship.find_children("Flame*", "MeshInstance3D"):
		(flame as Node3D).visible = false


func _spawn_player() -> void:
	player = CarScene.instantiate()
	player.world = self
	player.display_name = "PILOT"
	player.stats = GameState.preset().duplicate()
	player.primary = GameState.primary
	player.accent = GameState.accent
	player.ai = false
	add_child(player)
	var fwd := Util.forward_from_yaw(port_yaw)
	var right := Util.right_from_yaw(port_yaw)
	var spawn := port_position + right * 10.0 + fwd * 2.0 + Vector3(0, 0.4, 0)
	place_car(player, spawn, fwd, 0.0)
	safe_pos = player.global_position
	safe_yaw = player.yaw


func _spawn_ambient() -> void:
	var loops: Array[Dictionary] = []
	for race_def in roads.races:
		if str(race_def.type) == "circuit":
			loops.append(race_def)
		if loops.size() == 2:
			break
	if loops.is_empty():
		return
	for i in 4:
		var loop: Dictionary = loops[i % loops.size()]
		var bot := _make_bot(BOT_NAMES[i], BOT_COLORS[i], 0.62, i % GameState.PRESETS.size())
		bot.ai = true
		bot.ai_loop = true
		bot.ai_skill = 0.6
		bot.ai_points = loop.points
		bot.ai_dists = loop.distances
		var dist := float(loop.length) * float(i) / 4.0
		var pos := roads.point_at(loop.points, loop.distances, dist)
		var ahead := roads.point_at(loop.points, loop.distances, dist + 16.0)
		place_car(bot, pos, ahead - pos, 28.0)
		bots.append(bot)


func _make_bot(bot_name: String, color: Color, skill: float, preset_i: int) -> HoverCar:
	var bot: HoverCar = CarScene.instantiate()
	bot.world = self
	bot.display_name = bot_name
	bot.primary = color
	bot.accent = color
	var stats := GameState.PRESETS[preset_i].duplicate()
	stats.accel = float(stats.accel) * lerpf(0.88, 1.0, skill)
	stats.max_speed = float(stats.max_speed) * lerpf(0.9, 1.0, skill)
	stats.turn = float(stats.turn) * lerpf(0.9, 1.03, skill)
	bot.stats = stats
	bot.ai = true
	bot.ai_skill = skill
	add_child(bot)
	return bot


func _spawn_beacons() -> void:
	var root := Node3D.new()
	root.name = "Beacons"
	add_child(root)
	for i in roads.races.size():
		var def: Dictionary = roads.races[i]
		var p: Vector3 = def.checkpoints[0]
		var y := float(sample_surface(p).height)
		var pos := Vector3(p.x, y, p.z)
		beacon_positions.append(pos)
		var holder := BeaconScene.instantiate() as Node3D
		holder.position = pos
		root.add_child(holder)
		beacon_roots.append(holder)
		var tint: Color = BOT_COLORS[i % BOT_COLORS.size()]
		var ring := holder.get_node("Ring") as MeshInstance3D
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = tint
		ring_mat.emission_enabled = true
		ring_mat.emission = tint
		ring_mat.emission_energy_multiplier = 2.4
		ring.material_override = ring_mat
		var beam := holder.get_node("Beam") as MeshInstance3D
		var beam_mat := ring_mat.duplicate() as StandardMaterial3D
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.35)
		beam.material_override = beam_mat
		var label := holder.get_node("NameLabel") as Label3D
		label.text = str(def.name).to_upper()
		label.modulate = tint


func _build_gates(def: Dictionary) -> void:
	var cps: PackedVector3Array = def.checkpoints
	for i in cps.size():
		var prev: Vector3 = def.start_dir
		if i > 0:
			prev = cps[i] - cps[i - 1]
		elif cps.size() > 1:
			prev = cps[1] - cps[0]
		prev.y = 0.0
		if prev.length_squared() < 0.01:
			prev = Vector3(0, 0, -1)
		prev = prev.normalized()
		var side := prev.cross(Vector3.UP).normalized()
		var y := float(sample_surface(cps[i]).height)
		var pos := Vector3(cps[i].x, y, cps[i].z)
		var holder := GateScene.instantiate() as Node3D
		holder.position = pos
		holder.basis = Basis(side, Vector3.UP, -prev)
		_gate_root.add_child(holder)
		gates.append(holder)
		var mat := StandardMaterial3D.new()
		var tint := Color(1.0, 0.72, 0.25) if i == 0 else Color(0.2, 0.9, 1.0)
		mat.albedo_color = tint
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 2.0
		gate_mats.append(mat)
		for mesh_node in holder.find_children("*", "MeshInstance3D"):
			(mesh_node as MeshInstance3D).material_override = mat


func _highlight_gate() -> void:
	if not race.active:
		return
	var idx := player.cp_index
	for i in gate_mats.size():
		gate_mats[i].emission_energy_multiplier = 5.0 if i == idx else 1.2


func _clear_gates() -> void:
	for gate in gates:
		if is_instance_valid(gate):
			gate.free()
	gates.clear()
	gate_mats.clear()


func _clear_bots() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.free()
	bots.clear()


func _grid_slots(def: Dictionary) -> Array[Vector3]:
	var origin: Vector3 = def.checkpoints[0]
	var dir: Vector3 = def.start_dir
	dir.y = 0.0
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var slots: Array[Vector3] = []
	for i in 5:
		var row := int(float(i) / 2.0)
		var lateral := -1.0 if i % 2 == 0 else 1.0
		slots.append(origin + side * lateral * 3.2 - dir * float(row) * 7.2)
	return slots


func _update_prompt() -> void:
	near_race = -1
	var best := 20.0
	var flat := Vector2(player.global_position.x, player.global_position.z)
	for i in beacon_positions.size():
		var b := beacon_positions[i]
		var d := flat.distance_to(Vector2(b.x, b.z))
		if d < best:
			best = d
			near_race = i


func _remember_safe(dt: float) -> void:
	if player == null or player.airborne:
		return
	if player.speed_mps() < 2.0:
		return
	safe_pos = player.global_position
	safe_yaw = player.yaw
	if dt < 0.0:
		pass


func _separate_cars() -> void:
	var all: Array[HoverCar] = [player]
	for bot in bots:
		if is_instance_valid(bot):
			all.append(bot)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a := all[i]
			var b := all[j]
			var delta := b.global_position - a.global_position
			delta.y = 0.0
			var dist := delta.length()
			if dist < 2.65 and dist > 0.001:
				var push := delta / dist * (2.65 - dist) * 0.55
				a.global_position -= push
				b.global_position += push
				a.velocity -= Vector3(push.x, 0, push.z) * 6.0
				b.velocity += Vector3(push.x, 0, push.z) * 6.0


func _index_rocks() -> void:
	rock_grid.clear()
	for rock in DesertView.solids:
		var key := _rock_key(float(rock.x), float(rock.z))
		if not rock_grid.has(key):
			rock_grid[key] = []
		(rock_grid[key] as Array).append(rock)


func resolve_solids(car: HoverCar) -> void:
	var body := 1.4
	var cx := int(floor(car.global_position.x / 40.0))
	var cz := int(floor(car.global_position.z / 40.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := (cx + dx) * 10000 + (cz + dz)
			if not rock_grid.has(key):
				continue
			for rock in rock_grid[key]:
				if absf(car.global_position.y - float(rock.y)) > float(rock.h) + 0.6:
					continue
				var delta := Vector2(car.global_position.x - float(rock.x), car.global_position.z - float(rock.z))
				var dist := delta.length()
				var radius := float(rock.r) + body
				if dist >= radius:
					continue
				var n := Vector2(1, 0) if dist < 0.001 else delta / dist
				var push := radius - dist
				car.global_position.x += n.x * push
				car.global_position.z += n.y * push
				var out := Vector3(n.x, 0.0, n.y)
				var planar := Vector3(car.velocity.x, 0.0, car.velocity.z)
				var approach := planar.dot(out)
				if approach < 0.0:
					car.notify_impact(-approach)
					if car.wrecked:
						return
					planar -= out * approach * 1.35
					car.velocity.x = planar.x
					car.velocity.z = planar.z


func _rock_key(x: float, z: float) -> int:
	return int(floor(x / 40.0)) * 10000 + int(floor(z / 40.0))


func _build_storm() -> void:
	_storm_fx = GPUParticles3D.new()
	_storm_fx.name = "DustStorm"
	_storm_fx.amount = 700
	_storm_fx.lifetime = 1.6
	_storm_fx.visibility_aabb = AABB(Vector3(-50, -20, -50), Vector3(100, 60, 100))
	_storm_fx.local_coords = false
	_storm_fx.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(28, 10, 28)
	mat.direction = terrain.wind_dir
	mat.spread = 18.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 36.0
	mat.gravity = Vector3(0, -0.4, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.6
	mat.color = Color(0.62, 0.4, 0.22, 0.45)
	_storm_fx.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.albedo_color = Color(0.72, 0.5, 0.28, 0.55)
	quad.material = qmat
	_storm_fx.draw_pass_1 = quad
	add_child(_storm_fx)
	_build_wind()


func _build_wind() -> void:
	_wind_fx = GPUParticles3D.new()
	_wind_fx.name = "Wind"
	_wind_fx.amount = 48
	_wind_fx.lifetime = 1.15
	_wind_fx.visibility_aabb = AABB(Vector3(-40, -16, -40), Vector3(80, 40, 80))
	_wind_fx.local_coords = true
	_wind_fx.amount_ratio = 0.55
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 2.2, 18)
	mat.direction = terrain.wind_dir
	mat.spread = 8.0
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 34.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = Color(0.95, 0.88, 0.74, 0.22)
	_wind_fx.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.albedo_color = Color(1.0, 0.93, 0.8, 0.28)
	quad.material = qmat
	_wind_fx.draw_pass_1 = quad
	add_child(_wind_fx)


func _update_storm(dt: float) -> void:
	if player == null or _env == null or _env.environment == null or _sky_mat == null:
		return
	storm_level = terrain.storm_factor(player.global_position.x, player.global_position.z)
	if wasteland:
		wasteland.follow(player.global_position)
	var env := _env.environment
	env.fog_density = lerpf(0.00048, 0.011, storm_level)
	env.fog_light_color = Color(0.9, 0.74, 0.55).lerp(Color(0.42, 0.24, 0.12), storm_level)
	env.ambient_light_energy = lerpf(0.9, 0.28, storm_level)
	env.fog_sky_affect = lerpf(0.35, 0.85, storm_level)
	_sky_mat.set_shader_parameter("sky_top", Color(0.27, 0.48, 0.82).lerp(Color(0.22, 0.14, 0.1), storm_level))
	_sky_mat.set_shader_parameter("sky_horizon", Color(0.98, 0.74, 0.5).lerp(Color(0.48, 0.26, 0.12), storm_level))
	_sky_mat.set_shader_parameter("ground_horizon", Color(0.9, 0.58, 0.32).lerp(Color(0.32, 0.2, 0.12), storm_level))
	_sky_mat.set_shader_parameter("ground_bottom", Color(0.42, 0.24, 0.14).lerp(Color(0.16, 0.1, 0.08), storm_level))
	_sky_mat.set_shader_parameter("cloud_cover", lerpf(0.42, 0.3, storm_level))
	if _sun:
		_storm_flash = maxf(0.0, _storm_flash - dt)
		if storm_level > 0.62 and _storm_flash <= 0.0 and randf() < dt * 0.35:
			_storm_flash = 0.08
		var flash := 1.0 if _storm_flash > 0.0 else 0.0
		_sun.light_energy = lerpf(1.55, 0.32, storm_level) + flash * 1.8
		_sun.light_color = Color(1.0, 0.92, 0.74).lerp(Color(0.85, 0.62, 0.4), storm_level)
	if _storm_fx:
		_storm_fx.emitting = storm_level > 0.08
		_storm_fx.amount_ratio = clampf(storm_level, 0.0, 1.0)
		if cam:
			_storm_fx.global_position = cam.global_position
	if _wind_fx and cam:
		_wind_fx.global_position = cam.global_position + Vector3(0, -0.4, 0)
		_wind_fx.amount_ratio = lerpf(0.45, 1.0, storm_level)
	if _wreck_age >= 0.0 and _wreck_light:
		_wreck_age += dt
		_wreck_light.light_energy = maxf(0.0, 10.0 - _wreck_age * 7.0)
		if _wreck_age > 1.6:
			_wreck_light.queue_free()
			_wreck_light = null


func _update_camera(dt: float) -> void:
	if player == null or cam == null or not cam.current:
		return
	var speed := player.speed_mps()
	var back := -Util.forward_from_yaw(player.yaw)
	var dist := 8.0
	var height := 3.0
	var look_ahead := 5.0
	var look_up := 0.85
	var target_fov := 70.0
	var lag := 3.4
	match camera_mode:
		1:
			dist = lerpf(20.0, 28.0, clampf(speed / 80.0, 0.0, 1.0))
			height = lerpf(8.0, 13.0, clampf(speed / 80.0, 0.0, 1.0))
			look_ahead = 9.0
			look_up = 1.2
			target_fov = 62.0 + clampf(speed / 90.0, 0.0, 1.0) * 10.0
			lag = 2.4
		2:
			var seat := player.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, -0.25))
			var blend_hood := 1.0 if _snap_camera else 1.0 - exp(-14.0 * dt)
			_snap_camera = false
			cam.global_transform = cam.global_transform.interpolate_with(seat, blend_hood)
			cam.fov = lerpf(cam.fov, 80.0, blend_hood)
			return
		3:
			dist = 4.1
			height = 1.55
			look_ahead = 7.0
			look_up = 0.7
			target_fov = 82.0
			lag = 8.0
		_:
			dist = lerpf(11.0, 16.5, clampf(speed / 80.0, 0.0, 1.0))
			height = lerpf(4.2, 6.4, clampf(speed / 80.0, 0.0, 1.0))
			if player.airborne:
				dist += 2.2
				height += 1.4
			target_fov = 68.0 + clampf(speed / 85.0, 0.0, 1.0) * 18.0
			if player.boosting:
				target_fov += 6.0
	var look := player.global_position + Vector3.UP * look_up - back * look_ahead
	var desired := player.global_position + back * dist + Vector3.UP * height
	if overview:
		desired = player.global_position + Vector3(40, 55, 40)
		look = player.global_position
	var blend := 1.0 if _snap_camera else 1.0 - exp(-lag * dt)
	_snap_camera = false
	cam.global_position = cam.global_position.lerp(desired, blend)
	if cam.global_position.distance_squared_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(cam.fov, target_fov, blend)


func _run_smoke() -> void:
	for _i in 25:
		await get_tree().physics_frame
	overview = true
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null and img.get_width() > 0:
		img.save_png(ProjectSettings.globalize_path("res://_smoke.png"))
		print("SMOKE SHOT ", img.get_width(), "x", img.get_height())
	overview = false
	var fps_sum := 0.0
	var fps_n := 0
	for _i in 150:
		await get_tree().physics_frame
		if _i > 20:
			fps_sum += Engine.get_frames_per_second()
			fps_n += 1
	if fps_n > 0:
		print("SMOKE fps=%.0f" % (fps_sum / float(fps_n)))
	var speed := player.speed_mps()
	var far := Vector3(TerrainField.HALF + 700.0, 30.0, 180.0)
	var waste_h := terrain.height_at(far.x, far.z)
	var waste_storm := terrain.storm_factor(far.x, far.z)
	print("SMOKE speed=%.1f y=%.2f wrecked=%s races=%d waste_h=%.1f storm=%.2f" % [speed, player.global_position.y, player.wrecked, roads.races.size(), waste_h, waste_storm])
	if waste_h < 0.5 or waste_storm < 0.8:
		push_error("Wasteland did not continue past the map")
		get_tree().quit(1)
		return
	for def in roads.races:
		print(" RACE ", def.name, " ", def.type, " len=%.0f cps=%d laps=%d" % [def.length, def.checkpoints.size(), def.laps])
	if player.global_position.y < 0.0 or speed < 8.0 or roads.races.size() != 8:
		push_error("Smoke test failed")
		get_tree().quit(1)
		return
	start_race(0)
	for _i in 240:
		await get_tree().physics_frame
	print("RACE started=%s bots=%d cp=%d place=%d" % [race.started, bots.size(), player.cp_index, race.player_place()])
	if not race.started or bots.size() != 4:
		push_error("Race failed to start")
		get_tree().quit(1)
		return
	for _i in 120:
		await get_tree().physics_frame
	if player.speed_mps() < 8.0:
		push_error("Player stalled in the race")
		get_tree().quit(1)
		return
	print("SMOKE OK")
	get_tree().quit(0)
