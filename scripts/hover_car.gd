class_name HoverCar
extends Node3D

var world
var stats: Dictionary = {}
var display_name := "PILOT"
var accent := Color(0.08, 0.9, 1.0)
var primary := Color(0.1, 0.7, 0.9)
var ai := false
var ai_loop := false
var ai_points: PackedVector3Array = PackedVector3Array()
var ai_dists: PackedFloat32Array = PackedFloat32Array()
var ai_cursor := 0
var ai_skill := 0.8
var smoke_drive := false

var velocity := Vector3.ZERO
var yaw := 0.0
var air_pitch := 0.0
var air_roll := 0.0
var boost := 100.0
var hp := 100.0
const HP_MAX := 100.0
var airborne := false
var left_pad := false
var drifting := false
var boosting := false
var controls_enabled := true
var last_steer := 0.0
var fix_flash := 0.0
const SLOPE_LIMIT := 0.5
const NOSE_AHEAD := 1.95
const SPEED_LIMIT_KMH := 1227.0
const SPEED_LIMIT := 1227.0 / 3.6

var cp_index := 1
var lap := 0
var finished := false
var finish_time := -1.0
var offtrack := 0.0
var route_hint := 0
var wrong_way := false
var stuck := 0.0

var _body_mats: Array[ShaderMaterial] = []
var _flames: Array[MeshInstance3D] = []
var _dust: GPUParticles3D
var _dust_mat: ParticleProcessMaterial
var _audio: AudioStreamPlayer
var _phase := 0.0
var _time := 0.0
var _thrust := 0.0
var _air_thrust := 0.0
var _steer_f := 0.0
var _smooth_y := 0.0
var _hover_ready := false
var _bolt_mesh: ImmediateMesh
var _bolt: MeshInstance3D
var _bolt_light: OmniLight3D
var _arc_timer := 0.0
var _arc_live := false
var _arc_seed := 0
var _arc_from := Vector3.ZERO
var _arc_to := Vector3.ZERO
var _arc2_live := false
var _arc2_from := Vector3.ZERO
var _arc2_to := Vector3.ZERO
var _hit_speed := 0.0
var _hit_decel := 0.0
var _hull_smoke: GPUParticles3D


func _ready() -> void:
	process_priority = 8
	if stats.is_empty():
		stats = GameState.preset()
	_bind_visuals()
	_setup_bolts()
	_setup_audio()


func note_collision(speed: float, decel: float) -> void:
	if ai or smoke_drive or decel < 9.0:
		return
	if decel > _hit_decel:
		_hit_decel = decel
		_hit_speed = speed


func restore_hull() -> void:
	var missing := HP_MAX - hp
	hp = HP_MAX
	if missing > 0.5:
		fix_flash = 1.8


func _crippled() -> bool:
	return hp <= 0.0 and not ai


func _apply_damage() -> void:
	if _hit_decel <= 0.0:
		return
	var amount := _hit_decel * (0.55 + _hit_speed / 70.0)
	_hit_decel = 0.0
	_hit_speed = 0.0
	hp = maxf(0.0, hp - amount)


func _physics_process(dt: float) -> void:
	if world == null:
		return
	if fix_flash > 0.0:
		fix_flash = maxf(0.0, fix_flash - dt)
	_time += dt
	var input := _read_input()
	_steer_f = lerpf(_steer_f, float(input.steer), 1.0 - exp(-7.5 * dt))
	input.steer = _steer_f
	last_steer = _steer_f
	var fwd := Util.forward_from_yaw(yaw)
	velocity += world.terrain.wind_force(global_position.x, global_position.z) * dt
	var surface := _look_ahead(fwd)
	var height: float = surface.height
	var normal: Vector3 = surface.normal
	var hover := float(stats.hover)
	var gap := global_position.y - height

	if input.jump and not airborne and gap < hover + 1.15:
		airborne = true
		left_pad = false
		velocity.y = float(stats.jump)
		_thrust = 0.0

	if airborne:
		if not left_pad and gap > hover + 2.0:
			left_pad = true
		_fly(dt, input)
		var ground_n := float(world.sample_surface(global_position).normal.y)
		if left_pad and velocity.y <= 0.0 and gap < hover + 0.55 and gap > -2.0 and ground_n >= SLOPE_LIMIT:
			airborne = false
			air_pitch = 0.0
			air_roll = 0.0
			if velocity.y < -8.0:
				var keep := clampf(1.0 + velocity.y / 110.0, 0.78, 1.0)
				velocity.x *= keep
				velocity.z *= keep
				velocity.y = -1.2
	if not airborne:
		if gap > hover + 5.0:
			airborne = true
			left_pad = true
		else:
			_drive(dt, input, surface, height, hover, normal)

	var steps := clampi(int(ceil(Vector2(velocity.x, velocity.z).length() * dt / 1.6)), 1, 6)
	var left := float(steps)
	var travel := velocity * dt
	while left > 0.0:
		var slice := travel / left
		global_position += slice
		var prev_v := velocity
		_resolve_terrain(hover)
		world.resolve_solids(self)
		left -= 1.0
		if left <= 0.0:
			break
		if prev_v.distance_squared_to(velocity) > 1.0:
			travel = velocity * dt * (left / float(steps))
		else:
			travel -= slice
	var lost := global_position.y < -30.0 or Vector2(global_position.x, global_position.z).length() > 20000.0
	if lost:
		world.recover_car(self)
	_apply_damage()
	_apply_visual(normal, dt)
	_update_fx(surface)


func _process(_dt: float) -> void:
	_fill_audio()


func speed_mps() -> float:
	return Vector2(velocity.x, velocity.z).length()


func reset_motion_filters() -> void:
	_thrust = 0.0
	_air_thrust = 0.0
	_steer_f = 0.0
	_hover_ready = false


func _read_input() -> Dictionary:
	var data := {
		"throttle": 0.0,
		"steer": 0.0,
		"roll": 0.0,
		"boost": false,
		"jump": false,
		"drift": false,
	}
	if not controls_enabled:
		return data
	if smoke_drive:
		data.throttle = 1.0
		data.steer = sin(_time * 0.55) * 0.22
		data.boost = _time > 1.2 and boost > 10.0
		return data
	if ai and ai_points.size() > 4:
		return _ai_input()
	data.throttle = Input.get_action_strength("throttle") - Input.get_action_strength("brake")
	data.steer = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	data.roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	data.boost = Input.is_action_pressed("boost")
	data.jump = Input.is_action_just_pressed("jump")
	data.drift = Input.is_action_pressed("drift")
	return data


func _ai_input() -> Dictionary:
	var fwd := Util.forward_from_yaw(yaw)
	var right := Util.right_from_yaw(yaw)
	var speed := speed_mps()
	var along := _ai_along()
	var length := ai_dists[ai_dists.size() - 1]
	var look := clampf(15.0 + speed * 0.4, 14.0, 52.0) * lerpf(0.82, 1.12, ai_skill)
	var target := _ai_sample(along + look, length)
	var far := _ai_sample(along + look * 2.1, length)
	var to := target - global_position
	to.y = 0.0
	var aim := to.normalized() if to.length() > 0.2 else fwd
	var ang := fwd.signed_angle_to(aim, Vector3.UP)
	var steer := clampf(-ang / 0.62, -1.0, 1.0)
	var far_dir := far - global_position
	far_dir.y = 0.0
	var corner := 0.0
	if far_dir.length() > 0.2:
		corner = absf(fwd.signed_angle_to(far_dir.normalized(), Vector3.UP))
	var throttle := 1.0
	var drift := false
	var use_boost := false
	if corner > 0.9:
		throttle = lerpf(0.18, 0.38, ai_skill)
		drift = speed > 22.0
	elif corner > 0.42:
		throttle = lerpf(0.48, 0.75, ai_skill)
		drift = speed > 30.0 and corner > 0.58
	else:
		use_boost = speed > 40.0 and boost > 28.0 and absf(ang) < 0.22
		if ai_skill < 0.75 and sin(_time * 3.0 + float(ai_cursor)) < 0.2:
			use_boost = false
	for other in get_tree().get_nodes_in_group("cars"):
		if other == self:
			continue
		var rel: Vector3 = other.global_position - global_position
		var ahead := rel.dot(fwd)
		var side := rel.dot(right)
		if ahead > 0.0 and ahead < 14.0 and absf(side) < 2.8:
			steer -= clampf(side, -1.0, 1.0) * 0.85
			throttle *= 0.75
	steer = clampf(steer, -1.0, 1.0)
	if speed < 3.5 and not airborne:
		stuck += get_physics_process_delta_time()
	else:
		stuck = 0.0
	if stuck > 2.2:
		stuck = 0.0
		var rescue := _ai_sample(along + 18.0, length)
		global_position = Vector3(rescue.x, rescue.y + float(stats.hover), rescue.z)
		yaw = Util.yaw_from_forward((target - rescue).normalized() if target.distance_to(rescue) > 1.0 else fwd)
		velocity = Util.forward_from_yaw(yaw) * 16.0
	var jump := target.y > global_position.y + 6.5 and to.length() < 38.0 and not airborne
	return {
		"throttle": throttle,
		"steer": steer,
		"roll": 0.0,
		"boost": use_boost,
		"jump": jump,
		"drift": drift,
	}


func _ai_along() -> float:
	var best_d := 100000.0
	var best_i := ai_cursor
	var a := maxi(ai_cursor - 8, 0)
	var b := mini(ai_cursor + 36, ai_points.size() - 1)
	var flat := Vector2(global_position.x, global_position.z)
	for i in range(a, b + 1):
		var d := flat.distance_to(Vector2(ai_points[i].x, ai_points[i].z))
		if d < best_d:
			best_d = d
			best_i = i
	if ai_loop and ai_cursor > ai_points.size() - 12:
		for i in mini(12, ai_points.size()):
			var d2 := flat.distance_to(Vector2(ai_points[i].x, ai_points[i].z))
			if d2 < best_d:
				best_d = d2
				best_i = i
	ai_cursor = best_i
	return ai_dists[best_i]


func _ai_sample(dist: float, length: float) -> Vector3:
	if ai_loop:
		dist = fposmod(dist, maxf(length, 0.01))
	else:
		dist = clampf(dist, 0.0, length)
	return _point_along(dist)


func _point_along(dist: float) -> Vector3:
	var lo := 0
	var hi := ai_dists.size() - 1
	while lo < hi - 1:
		var mid := (lo + hi) >> 1
		if ai_dists[mid] < dist:
			lo = mid
		else:
			hi = mid
	var span := ai_dists[hi] - ai_dists[lo]
	var u := 0.0 if span < 0.001 else (dist - ai_dists[lo]) / span
	return ai_points[lo].lerp(ai_points[hi], u)


func _look_ahead(fwd: Vector3) -> Dictionary:
	var here: Dictionary = world.sample_surface(global_position)
	var look := clampf(speed_mps() * 0.35, 8.0, 150.0)
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	var mid: Dictionary = world.sample_surface(global_position + flat * look * 0.45)
	var ahead: Dictionary = world.sample_surface(global_position + flat * look)
	var h := float(here.height)
	var climb := maxf(float(mid.height), float(ahead.height)) - h
	if float(ahead.normal.y) < SLOPE_LIMIT and climb > 6.0:
		h += clampf(climb, 0.0, 0.4)
	elif climb > 0.0:
		h += clampf(climb, 0.0, look * 0.42)
	else:
		h = lerpf(h, float(ahead.height), 0.35)
	var n: Vector3 = (here.normal as Vector3).lerp(ahead.normal, 0.3).normalized()
	return {"height": h, "normal": n, "on_road": here.on_road, "kind": here.kind}


func _resolve_terrain(hover: float) -> void:
	var fwd := Util.forward_from_yaw(yaw)
	for _i in 4:
		var surface: Dictionary = world.sample_surface(global_position)
		var floor_y := float(surface.height)
		var n: Vector3 = surface.normal
		var nose_p := global_position + fwd * NOSE_AHEAD
		var nose: Dictionary = world.sample_surface(nose_p)
		var steep := n.y < SLOPE_LIMIT and global_position.y < floor_y + 0.45
		var nose_steep := float(nose.normal.y) < SLOPE_LIMIT and nose_p.y < float(nose.height) + 0.35
		if steep or nose_steep:
			var face: Vector3 = nose.normal if nose_steep else n
			if face.y >= SLOPE_LIMIT:
				face = n
			var out := Vector3(face.x, 0.0, face.z)
			if out.length_squared() < 0.0001:
				global_position.y = _float_height(hover, floor_y, n)
				return
			out = out.normalized()
			var planar := Vector3(velocity.x, 0.0, velocity.z)
			var approach := planar.dot(out)
			if approach < 0.0:
				note_collision(planar.length(), -approach)
			global_position += out * 2.2
			if approach < 0.0:
				planar -= out * approach * 1.25
				velocity.x = planar.x
				velocity.z = planar.z
			velocity.y = maxf(velocity.y, 1.5)
			continue
		var float_y := _float_height(hover, floor_y, n)
		if global_position.y >= float_y - 0.02:
			return
		if velocity.y < -36.0:
			note_collision(speed_mps(), -velocity.y)
		global_position.y = float_y
		var into := n.dot(velocity)
		if into < 0.0:
			velocity -= n * into
		if velocity.y < 0.0:
			velocity.y = 0.0
		airborne = false
	var final_surface: Dictionary = world.sample_surface(global_position)
	if float(final_surface.normal.y) >= SLOPE_LIMIT and global_position.y < float(final_surface.height) + hover * 0.45:
		global_position.y = float(final_surface.height) + hover
		velocity.y = maxf(velocity.y, 0.0)


func _float_height(hover: float, floor_y: float, normal: Vector3) -> float:
	var target := floor_y + hover
	if normal.y < SLOPE_LIMIT:
		return target
	# Bottom of the nose and the two front corners, in the pose the mesh has right now.
	var tips: Array[Vector3] = [
		Vector3(0.0, 0.19, -2.27),
		Vector3(0.52, 0.18, -2.0),
		Vector3(-0.52, 0.18, -2.0),
	]
	for tip in tips:
		var offset: Vector3 = global_transform.basis * tip
		var at := global_position + Vector3(offset.x, 0.0, offset.z)
		var nose: Dictionary = world.sample_surface(at)
		if float(nose.normal.y) < SLOPE_LIMIT:
			continue
		target = maxf(target, float(nose.height) + 0.36 - offset.y)
	return target


func _scaled_accel(base: float, speed: float) -> float:
	return base * pow(0.5, absf(speed) * 3.6 / 250.0)


func _drive(dt: float, input: Dictionary, surface: Dictionary, height: float, hover: float, normal: Vector3) -> void:
	var fwd := Util.forward_from_yaw(yaw)
	var right := Util.right_from_yaw(yaw)
	var target_y := _float_height(hover, height, normal)
	if not _hover_ready:
		_smooth_y = global_position.y
		_hover_ready = true
	_smooth_y = lerpf(_smooth_y, target_y, 1.0 - exp(-5.5 * dt))
	var error := _smooth_y - global_position.y
	velocity.y += (error * 34.0 - velocity.y * 7.5) * dt
	velocity.y = clampf(velocity.y, -16.0, 22.0)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := flat.dot(fwd)
	var side_speed := flat.dot(right)
	var on_road := bool(surface.on_road)
	var crippled := _crippled()
	boosting = bool(input.boost) and boost > 1.0 and not crippled
	var accel := float(stats.accel) * (0.78 if not on_road else 1.0)
	var cap := minf(float(stats.max_speed), SPEED_LIMIT)
	if crippled:
		cap = minf(cap, 16.0)
		accel *= 0.42
	if boosting:
		accel *= 3.0
		boost -= float(stats.boost_drain) * dt
	else:
		boost = minf(100.0, boost + float(stats.boost_regen) * dt)
	accel = _scaled_accel(accel, forward_speed)
	drifting = bool(input.drift) and absf(forward_speed) > 12.0
	var throttle := float(input.throttle)
	var reverse_cap := minf(36.0, cap * 0.48)
	var ramp := maxf(accel, float(stats.accel) * (1.05 if boosting else 0.35)) * 4.0
	if throttle > 0.05:
		_thrust = move_toward(_thrust, throttle * accel, ramp * dt)
		forward_speed += _thrust * dt
	elif throttle < -0.05:
		_thrust = move_toward(_thrust, 0.0, float(stats.accel) * 2.4 * dt)
		if forward_speed > 2.0:
			forward_speed = move_toward(forward_speed, 0.0, float(stats.brake) * 0.85 * dt)
		else:
			forward_speed += throttle * accel * 0.7 * dt
	else:
		_thrust = move_toward(_thrust, 0.0, float(stats.accel) * 2.0 * dt)
		forward_speed = move_toward(forward_speed, 0.0, float(stats.brake) * 0.28 * dt)
	forward_speed = clampf(forward_speed, -reverse_cap, cap)
	var grip := float(stats.drift_grip if drifting else stats.grip)
	if not on_road:
		grip *= 0.72
	side_speed = move_toward(side_speed, 0.0, grip * dt * 5.0)
	if drifting:
		side_speed += float(input.steer) * forward_speed * 0.9 * dt
		boost = minf(100.0, boost + float(stats.drift_boost) * dt * clampf(absf(side_speed) / 14.0, 0.2, 1.0))
	var speed_factor := clampf(absf(forward_speed) / 16.0, 0.22, 1.0)
	var turn := float(stats.turn) * (1.5 if drifting else 1.0)
	var dir_sign := -1.0 if forward_speed < -2.0 else 1.0
	yaw -= float(input.steer) * turn * speed_factor * dir_sign * dt
	fwd = Util.forward_from_yaw(yaw)
	right = Util.right_from_yaw(yaw)
	var planar := fwd * forward_speed + right * side_speed
	velocity.x = planar.x
	velocity.z = planar.z
	if normal.y > 0.55 and not on_road:
		var slide := Vector3(normal.x, 0.0, normal.z)
		velocity += slide * (1.0 - normal.y) * 4.0 * dt
	air_pitch = move_toward(air_pitch, 0.0, dt * 3.0)
	air_roll = move_toward(air_roll, 0.0, dt * 3.0)


func _fly(dt: float, input: Dictionary) -> void:
	velocity.y -= 27.0 * dt
	var air := float(stats.air)
	var invert := -1.0 if (not ai and not smoke_drive) else 1.0
	air_pitch = clampf(air_pitch - float(input.throttle) * air * dt * invert, -0.75, 0.7)
	air_roll = clampf(air_roll + float(input.roll) * air * 1.15 * dt * invert, -1.05, 1.05)
	if absf(float(input.roll)) < 0.15:
		air_roll = move_toward(air_roll, 0.0, dt * 0.65)
	if absf(float(input.throttle)) < 0.15:
		air_pitch = move_toward(air_pitch, 0.0, dt * 0.4)
	yaw -= float(input.steer) * float(stats.turn) * 0.72 * dt
	var nose := Basis.from_euler(Vector3(air_pitch, yaw, 0.0)) * Vector3(0, 0, -1)
	var crippled := _crippled()
	boosting = bool(input.boost) and boost > 1.0 and not crippled
	var desired_air := 0.0
	if float(input.throttle) > 0.0:
		desired_air = float(stats.accel) * 0.45
	if crippled:
		desired_air *= 0.35
	if boosting:
		desired_air *= 3.0
		boost -= float(stats.boost_drain) * 0.65 * dt
	else:
		boost = minf(100.0, boost + float(stats.boost_regen) * 0.5 * dt)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	desired_air = _scaled_accel(desired_air, planar.length())
	var air_ramp := float(stats.accel) * (5.4 if boosting else 1.8)
	_air_thrust = move_toward(_air_thrust, desired_air, air_ramp * dt)
	velocity += nose * _air_thrust * dt
	velocity.y += air_pitch * 9.0 * dt
	velocity += Util.right_from_yaw(yaw) * air_roll * 7.0 * dt
	velocity.x -= velocity.x * 0.14 * dt
	velocity.z -= velocity.z * 0.14 * dt
	var glide := Vector3(velocity.x, 0.0, velocity.z)
	var air_cap := 16.0 if crippled else minf(float(stats.max_speed), SPEED_LIMIT)
	if glide.length() > air_cap:
		glide = glide.normalized() * air_cap
		velocity.x = glide.x
		velocity.z = glide.z
	drifting = false


func _apply_visual(normal: Vector3, dt: float) -> void:
	var basis: Basis
	if airborne:
		basis = Basis.from_euler(Vector3(air_pitch, yaw, air_roll))
	else:
		var fwd := Util.forward_from_yaw(yaw)
		var right := Util.right_from_yaw(yaw)
		var sp := clampf(-normal.dot(fwd), -1.047, 1.047)
		var sr := clampf(-normal.dot(right), -0.28, 0.28)
		var bank := -last_steer * 0.28 * clampf(speed_mps() / 40.0, 0.0, 1.0)
		if drifting:
			bank *= 1.25
		basis = Basis.from_euler(Vector3(sp, yaw, sr + bank))
	var blended := global_transform.basis.slerp(basis.orthonormalized(), 1.0 - exp(-14.0 * dt))
	global_transform = Transform3D(blended, global_position)


func _update_fx(surface: Dictionary) -> void:
	var speed := speed_mps()
	var power := clampf(speed / (SPEED_LIMIT * 0.45), 0.05, 1.0)
	if boosting:
		power = 1.0
	for flame in _flames:
		var len := lerpf(0.15, 1.35, power) * (1.25 if boosting else 1.0)
		flame.scale = Vector3(lerpf(0.35, 1.0, power), len, lerpf(0.35, 1.0, power))
		flame.visible = controls_enabled and (speed > 6.0 or boosting)
	if _dust:
		var moving := (not airborne) and speed > 10.0 and controls_enabled
		_dust.emitting = moving
	if _hull_smoke:
		_hull_smoke.emitting = _crippled()
		if _dust_mat:
			_dust_mat.color = Color(1.0, 0.45, 0.12, 0.55) if drifting or boosting else Color(0.75, 0.55, 0.32, 0.4)
	var glow := 1.0 if boosting else 0.0
	for mat in _body_mats:
		mat.set_shader_parameter("boost_glow", glow)
	_update_bolts()


func _setup_bolts() -> void:
	_bolt_mesh = ImmediateMesh.new()
	_bolt = MeshInstance3D.new()
	_bolt.name = "GroundArc"
	_bolt.mesh = _bolt_mesh
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt.material_override = mat
	add_child(_bolt)
	_bolt_light = OmniLight3D.new()
	_bolt_light.light_color = Color(0.65, 0.88, 1.0)
	_bolt_light.omni_range = 7.0
	_bolt_light.light_energy = 0.0
	_bolt_light.position = Vector3(0, 0.2, 0)
	add_child(_bolt_light)


func _update_bolts() -> void:
	if ai:
		if _bolt:
			_bolt.visible = false
		if _bolt_light:
			_bolt_light.light_energy = 0.0
		return
	if _bolt_mesh == null or world == null:
		return
	var moving := (not airborne) and controls_enabled and speed_mps() > 14.0
	if not moving:
		_arc_live = false
		_arc2_live = false
		_bolt.visible = false
		_bolt_light.light_energy = 0.0
		return
	var dt := get_physics_process_delta_time()
	_arc_timer -= dt
	if _arc_timer <= 0.0:
		if randf() < 0.42:
			_arc_live = false
			_arc2_live = false
			_arc_timer = randf_range(0.05, 0.16)
		else:
			_arc_live = true
			_arc_timer = randf_range(0.028, 0.07)
			_arc_seed = randi()
			_arc_from = Vector3(randf_range(-0.7, 0.7), randf_range(0.02, 0.2), randf_range(-1.05, 0.45))
			_arc_to = Vector3(randf_range(-1.45, 1.45), 0.0, randf_range(-1.7, 1.15))
			_arc2_live = randf() < 0.38
			if _arc2_live:
				_arc2_from = Vector3(randf_range(-0.7, 0.7), randf_range(0.02, 0.18), randf_range(-0.8, 0.6))
				_arc2_to = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.4, 0.9))
	var flicker := int(_time * 78.0) % 5 == 0
	if not _arc_live or flicker:
		_bolt.visible = false
		_bolt_light.light_energy = 0.0
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _arc_seed + int(_time * 46.0)
	_bolt_mesh.clear_surfaces()
	_bolt.visible = true
	_draw_discharge(_arc_from, _arc_to, rng, 0.42)
	if _arc2_live:
		_draw_discharge(_arc2_from, _arc2_to, rng, 0.28)
	_bolt_light.position = _arc_from
	_bolt_light.light_energy = rng.randf_range(1.6, 4.4)


func _draw_discharge(local_from: Vector3, local_foot: Vector3, rng: RandomNumberGenerator, amp: float) -> void:
	var from_g := global_position + global_transform.basis * local_from
	var foot_g := global_position + global_transform.basis * Vector3(local_foot.x, 0.0, local_foot.z)
	var surface: Dictionary = world.sample_surface(foot_g)
	foot_g.y = float(surface.height) + 0.05
	var pts := _bolt_points(to_local(from_g), to_local(foot_g), rng, amp)
	_bolt_strip(pts, 0.055, Color(0.35, 0.72, 1.0, 0.34))
	_bolt_strip(pts, 0.012, Color(0.96, 0.98, 1.0, 0.98))
	if rng.randf() < 0.8 and pts.size() > 4:
		_bolt_branch(pts, rng)
	if rng.randf() < 0.35 and pts.size() > 5:
		_bolt_branch(pts, rng)


func _bolt_points(a: Vector3, b: Vector3, rng: RandomNumberGenerator, amp: float) -> PackedVector3Array:
	var count := 8
	var pts := PackedVector3Array()
	pts.resize(count + 1)
	pts[0] = a
	pts[count] = b
	var dir := b - a
	var axis := dir.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var bend := axis.cross(dir.normalized()) if dir.length_squared() > 0.0001 else Vector3.UP
	for i in range(1, count):
		var t := float(i) / float(count)
		var envelope := sin(PI * t)
		var p := a.lerp(b, t)
		p += axis * rng.randf_range(-amp, amp) * envelope
		p += bend * rng.randf_range(-amp * 0.4, amp * 0.65) * envelope
		pts[i] = p
	return pts


func _bolt_branch(pts: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	var i := rng.randi_range(2, pts.size() - 3)
	var origin := pts[i]
	var dir := (pts[i] - pts[maxi(i - 1, 0)])
	if dir.length_squared() < 0.0001:
		dir = Vector3.DOWN
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var tip := origin + side * rng.randf_range(-0.7, 0.7) + dir * rng.randf_range(0.12, 0.55) + Vector3.UP * rng.randf_range(-0.25, 0.3)
	var branch := _bolt_points(origin, tip, rng, 0.16)
	_bolt_strip(branch, 0.02, Color(0.4, 0.75, 1.0, 0.4))
	_bolt_strip(branch, 0.006, Color(0.94, 0.98, 1.0, 0.9))


func _bolt_strip(pts: PackedVector3Array, width: float, color: Color) -> void:
	if pts.size() < 2:
		return
	_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	_bolt_mesh.surface_set_color(color)
	var prev := pts[0]
	for i in pts.size():
		var p := pts[i]
		var tangent := (p - prev).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.DOWN
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized() * width
		_bolt_mesh.surface_add_vertex(p + side)
		_bolt_mesh.surface_add_vertex(p - side)
		prev = p
	_bolt_mesh.surface_end()


func _bind_visuals() -> void:
	var body := Color(0.05, 0.055, 0.07).lerp(primary, 0.34)
	for child in find_children("*", "MeshInstance3D"):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst.name.begins_with("Flame"):
			var flame_mat := StandardMaterial3D.new()
			flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			flame_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.8)
			flame_mat.emission_enabled = true
			flame_mat.emission = accent
			flame_mat.emission_energy_multiplier = 4.0
			mesh_inst.material_override = flame_mat
			_flames.append(mesh_inst)
			continue
		var source := mesh_inst.material_override as ShaderMaterial
		if source == null:
			source = mesh_inst.get_surface_override_material(0) as ShaderMaterial
		if source == null:
			continue
		var mat := source.duplicate() as ShaderMaterial
		mat.set_shader_parameter("body_color", body)
		mat.set_shader_parameter("accent_color", accent)
		mesh_inst.material_override = mat
		_body_mats.append(mat)
	_dust = get_node_or_null("Dust") as GPUParticles3D
	if _dust:
		_dust_mat = ParticleProcessMaterial.new()
		_dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_dust_mat.emission_box_extents = Vector3(0.7, 0.1, 0.3)
		_dust_mat.direction = Vector3(0, 0.25, 1)
		_dust_mat.spread = 28.0
		_dust_mat.initial_velocity_min = 1.2
		_dust_mat.initial_velocity_max = 3.4
		_dust_mat.gravity = Vector3(0, -1.5, 0)
		_dust_mat.scale_min = 0.25
		_dust_mat.scale_max = 0.8
		_dust_mat.color = Color(0.75, 0.55, 0.32, 0.45)
		_dust.process_material = _dust_mat
		var quad := QuadMesh.new()
		quad.size = Vector2(0.55, 0.55)
		var qmat := StandardMaterial3D.new()
		qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qmat.albedo_color = Color(1, 1, 1, 0.8)
		qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qmat.vertex_color_use_as_albedo = true
		quad.material = qmat
		_dust.draw_pass_1 = quad
		_dust.emitting = false
	_hull_smoke = GPUParticles3D.new()
	_hull_smoke.name = "HullSmoke"
	_hull_smoke.amount = 48
	_hull_smoke.lifetime = 1.35
	_hull_smoke.position = Vector3(0.0, 0.55, 1.15)
	_hull_smoke.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	_hull_smoke.emitting = false
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_mat.emission_sphere_radius = 0.25
	smoke_mat.direction = Vector3(0, 1, 0.15)
	smoke_mat.spread = 18.0
	smoke_mat.initial_velocity_min = 0.8
	smoke_mat.initial_velocity_max = 2.2
	smoke_mat.gravity = Vector3(0, 0.4, 0)
	smoke_mat.scale_min = 0.45
	smoke_mat.scale_max = 1.35
	smoke_mat.color = Color(0.22, 0.2, 0.18, 0.72)
	_hull_smoke.process_material = smoke_mat
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.7, 0.7)
	var smoke_draw := StandardMaterial3D.new()
	smoke_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_draw.albedo_color = Color(0.35, 0.32, 0.28, 0.8)
	smoke_quad.material = smoke_draw
	_hull_smoke.draw_pass_1 = smoke_quad
	add_child(_hull_smoke)
	if ai:
		var label := Label3D.new()
		label.text = display_name
		label.font_size = 42
		label.position = Vector3(0, 1.55, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = accent
		label.outline_size = 8
		label.pixel_size = 0.008
		label.no_depth_test = true
		add_child(label)
	add_to_group("cars")


func _setup_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.25
	_audio = AudioStreamPlayer.new()
	_audio.stream = gen
	_audio.volume_db = -22.0 if ai else -16.0
	add_child(_audio)
	_audio.play()


func _fill_audio() -> void:
	if _audio == null:
		return
	var playback := _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	var spd := clampf(speed_mps() / SPEED_LIMIT, 0.0, 1.3)
	var freq := lerpf(46.0, 128.0, spd)
	if boosting:
		freq *= 1.28
	var amp := lerpf(0.015, 0.1, clampf(spd, 0.0, 1.0))
	if not controls_enabled:
		amp *= 0.25
	for _i in frames:
		_phase += freq / 22050.0
		var s := sin(_phase * TAU) * amp + sin(_phase * TAU * 2.0) * amp * 0.22
		playback.push_frame(Vector2(s, s))
