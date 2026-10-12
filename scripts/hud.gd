class_name GameHud
extends CanvasLayer

var world
var speed_label: Label
var race_panel: PanelContainer
var race_label: Label
var race_meta: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var banner: Label
var wrong_label: Label
var hint_label: Label
var seed_label: Label
var standings_panel: PanelContainer
var standings: Label
var pause_panel: Control
var results_panel: Control
var mission_panel: Control
var results_body: Label
var minimap: Control
var preview_panel: PanelContainer
var preview_title: Label
var preview_note: Label
var track_preview: Control
var pointer: Control
var _garage: Control
var _paused := false
var view_label: Label
var view_time := 0.0
var storm_label: Label
var hull_label: Label
var _boost_fill: ColorRect
var _boost_lock: ColorRect
var _boost_mark: ColorRect
var map_panel: Control
var _medal_labels: Array[Label] = []
var _race_names: PackedStringArray = PackedStringArray()
var _medal_summary: Label
var _invite_note: Label
var _guide_note: Label
var _port_panel: Control
var _port_open := false
var _port_ice: Button
var _port_grass: Button
var _map_open := false
var map_texture: ImageTexture
var speed_fx: ColorRect
var _speed_mat: ShaderMaterial
var _impact: ColorRect


func bind(host) -> void:
	world = host
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_impact = ColorRect.new()
	_impact.set_anchors_preset(Control.PRESET_FULL_RECT)
	_impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact.color = Color(0.0, 0.0, 0.0, 0.0)
	root.add_child(_impact)
	_build_drive_ui(root)
	_build_pause(root)
	_build_results(root)
	_build_missions(root)
	_build_port(root)


func _process(_dt: float) -> void:
	if world == null or world.player == null:
		return
	_refresh()
	_impact_flash()
	if minimap:
		minimap.queue_redraw()
	if preview_panel and preview_panel.visible and track_preview:
		track_preview.queue_redraw()
	if _map_open and map_panel:
		map_panel.queue_redraw()
	if pointer:
		pointer.queue_redraw()
	if view_time > 0.0:
		view_time -= _dt
		if view_time <= 0.0 and view_label:
			view_label.visible = false
	if Input.is_action_just_pressed("pause"):
		_on_escape()
	elif _guide_pressed() and _garage == null and not _paused and not results_panel.visible:
		_toggle_guide()


func _impact_flash() -> void:
	if _impact == null or world == null or world.player == null:
		return
	var car: HoverCar = world.player
	var hurt := car.hit_shake
	var heal := clampf(car.fix_flash / 1.8, 0.0, 1.0)
	if hurt > 0.02:
		_impact.color = Color(0.78, 0.08, 0.04, hurt * 0.45)
	elif heal > 0.02:
		_impact.color = Color(0.22, 0.82, 0.42, heal * heal * 0.34)
	else:
		_impact.color = Color(0.0, 0.0, 0.0, 0.0)


func flash_view(view_name: String) -> void:
	if view_label == null:
		return
	view_label.text = "CAMERA  " + view_name
	view_label.visible = true
	view_time = 1.6


func dismiss_menus() -> void:
	_set_guide(false)
	if _paused:
		_set_paused(false)


func hide_results() -> void:
	if results_panel:
		results_panel.visible = false


func show_results() -> void:
	if results_panel == null or world == null:
		return
	results_panel.visible = true
	var place: int = world.race.player_place()
	var lines := PackedStringArray()
	lines.append(str(world.race.race.name).to_upper())
	lines.append(Util.place_text(place) if world.player.finished else "DNF")
	lines.append("YOUR TIME  " + Util.format_time(world.player.finish_time))
	var best := GameState.best_time(GameState.world_seed, str(world.race.race.name))
	if best > 0.0:
		lines.append("SECTOR BEST  " + Util.format_time(best))
	var medal := GameState.medal_rank(GameState.world_seed, str(world.race.race.name))
	if medal > 0:
		lines.append("%s MEDAL" % GameState.medal_name(medal))
	if GameState.just_invited:
		lines.append("")
		lines.append("A message arrives.")
		lines.append("You are invited to the races on the next planet. Drive to the space port.")
	lines.append("")
	for i in world.race.order.size():
		var car: HoverCar = world.race.order[i]
		var time := Util.format_time(car.finish_time) if car.finished else "RUNNING"
		lines.append("%s   %s   %s" % [Util.place_text(i + 1), car.display_name, time])
	results_body.text = "\n".join(lines)


func _refresh() -> void:
	var car: HoverCar = world.player
	var kmh := car.speed_mps() * 3.6
	speed_label.text = str(int(round(kmh)))
	if _speed_mat:
		var rush := Util.smoothstep(40.0, HoverCar.SPEED_LIMIT * 0.75, car.speed_mps())
		_speed_mat.set_shader_parameter("intensity", rush)
	if _boost_fill:
		var cap := clampf(car.hp / HoverCar.HP_MAX, 0.0, 1.0)
		var amount := clampf(car.boost / 100.0, 0.0, cap)
		_boost_fill.size = Vector2(180.0 * amount, 16.0)
		_boost_lock.position = Vector2(180.0 * cap, 0.0)
		_boost_lock.size = Vector2(180.0 * (1.0 - cap), 16.0)
		_boost_mark.position = Vector2(maxf(180.0 * cap - 1.0, 0.0), 0.0)
		_boost_mark.visible = cap < 0.995
		_boost_fill.color = Color(0.95, 0.28, 0.18) if cap < 0.3 else Color(1.0, 0.55, 0.16)
	if hull_label:
		if car.fix_flash > 0.0:
			hull_label.visible = true
			hull_label.text = "HULL RESTORED"
			hull_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62))
		elif car.hp <= 0.0:
			hull_label.visible = true
			hull_label.text = "HULL DOWN  —  DRIVE THROUGH A FIX ARCH"
			hull_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28))
		else:
			hull_label.visible = false
	seed_label.text = "%s   SEED %06d" % [GameState.planet_title(), GameState.world_seed]
	var race = world.race
	if race.active:
		prompt_label.text = ""
		if prompt_panel:
			prompt_panel.visible = false
		if not race.started:
			banner.text = str(maxi(ceili(race.countdown), 1))
			banner.visible = true
		elif race.go_time > 0.0:
			banner.text = "GO"
			banner.visible = true
		else:
			banner.visible = false
		wrong_label.visible = car.wrong_way and race.started and not race.finished
		var laps := ""
		if str(race.race.type) == "circuit":
			laps = "LAP %d/%d    " % [mini(car.lap + 1, int(race.race.laps)), int(race.race.laps)]
		var cp := "%d/%d" % [mini(car.cp_index, race.race.checkpoints.size()), race.race.checkpoints.size()]
		race_label.text = str(race.race.name).to_upper()
		race_meta.visible = true
		race_meta.text = "%s    %sCP %s    %s" % [
			Util.place_text(race.player_place()),
			laps,
			cp,
			Util.format_time(race.elapsed),
		]
		var board := PackedStringArray()
		for i in race.order.size():
			var racer: HoverCar = race.order[i]
			var mark := ">" if racer == car else " "
			board.append("%s %d  %s" % [mark, i + 1, racer.display_name])
		standings.text = "\n".join(board)
		standings_panel.visible = true
	else:
		banner.visible = false
		wrong_label.visible = false
		standings_panel.visible = false
		race_label.text = "FREE ROAM"
		if world.near_race >= 0:
			var def: Dictionary = world.roads.races[world.near_race]
			prompt_label.text = "F  —  START  %s\n%s" % [str(def.name).to_upper(), def.blurb]
			race_meta.visible = false
		elif world.near_port:
			prompt_label.text = "F  —  SPACE PORT"
			race_meta.visible = false
		else:
			prompt_label.text = ""
			race_meta.visible = true
			race_meta.text = "Drive the road network or press M"
	if prompt_panel:
		prompt_panel.visible = prompt_label.text != ""
	if storm_label:
		var storm := float(world.storm_level)
		storm_label.visible = storm > 0.28
		if storm > 0.72:
			storm_label.text = "WASTELAND STORM"
		elif storm > 0.28:
			storm_label.text = "DUST STORM"
	_update_preview()


func _on_escape() -> void:
	if _port_open:
		close_port()
		return
	if _garage != null:
		_garage.queue_free()
		_garage = null
		if not _paused:
			get_tree().paused = false
		return
	if _map_open:
		_set_guide(false)
		return
	if results_panel.visible:
		return
	if mission_panel.visible:
		_set_guide(false)
		return
	_set_paused(not _paused)


func _set_paused(value: bool) -> void:
	_paused = value
	pause_panel.visible = value
	get_tree().paused = value


func _build_drive_ui(root: Control) -> void:
	speed_fx = ColorRect.new()
	speed_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_fx.color = Color(1, 1, 1, 1)
	_speed_mat = ShaderMaterial.new()
	_speed_mat.shader = load("res://shaders/speed_fx.gdshader")
	_speed_mat.set_shader_parameter("intensity", 0.0)
	speed_fx.material = _speed_mat
	root.add_child(speed_fx)

	var speed_box := PanelContainer.new()
	speed_box.position = Vector2(28, 0)
	speed_box.anchor_top = 1.0
	speed_box.anchor_bottom = 1.0
	speed_box.offset_top = -164
	speed_box.offset_bottom = -28
	speed_box.offset_left = 28
	speed_box.offset_right = 250
	speed_box.add_theme_stylebox_override("panel", UiStyle.panel())
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(speed_box)
	var vb := VBoxContainer.new()
	speed_box.add_child(vb)
	speed_label = Label.new()
	speed_label.add_theme_font_size_override("font_size", 54)
	speed_label.add_theme_color_override("font_color", Color(0.8, 0.96, 1))
	speed_label.text = "0"
	vb.add_child(speed_label)
	var unit := Label.new()
	unit.text = "KM/H"
	unit.add_theme_color_override("font_color", Color(0.55, 0.75, 0.85))
	vb.add_child(unit)
	var meter := Control.new()
	meter.custom_minimum_size = Vector2(180, 16)
	vb.add_child(meter)
	var track := ColorRect.new()
	track.color = Color(0.08, 0.09, 0.11)
	track.size = Vector2(180, 16)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(track)
	_boost_fill = ColorRect.new()
	_boost_fill.color = Color(1.0, 0.55, 0.16)
	_boost_fill.size = Vector2(180, 16)
	_boost_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(_boost_fill)
	_boost_lock = ColorRect.new()
	_boost_lock.color = Color(0.28, 0.08, 0.06, 0.95)
	_boost_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(_boost_lock)
	_boost_mark = ColorRect.new()
	_boost_mark.color = Color(0.45, 0.95, 0.62)
	_boost_mark.size = Vector2(2, 16)
	_boost_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(_boost_mark)
	var boost_name := Label.new()
	boost_name.text = "BOOST"
	boost_name.add_theme_font_size_override("font_size", 12)
	boost_name.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	vb.add_child(boost_name)

	hull_label = Label.new()
	hull_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hull_label.position = Vector2(28, -236)
	hull_label.size = Vector2(420, 28)
	hull_label.add_theme_font_size_override("font_size", 16)
	hull_label.visible = false
	root.add_child(hull_label)

	view_label = Label.new()
	view_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	view_label.position = Vector2(-120, 96)
	view_label.size = Vector2(240, 32)
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_label.add_theme_font_size_override("font_size", 18)
	view_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	view_label.visible = false
	root.add_child(view_label)

	seed_label = Label.new()
	seed_label.position = Vector2(28, 20)
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1, 0.85))
	root.add_child(seed_label)

	race_panel = PanelContainer.new()
	race_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	race_panel.offset_left = -250
	race_panel.offset_top = 12
	race_panel.offset_right = 250
	race_panel.offset_bottom = 84
	race_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_panel.add_theme_stylebox_override("panel", UiStyle.hud_panel())
	root.add_child(race_panel)
	var race_box := VBoxContainer.new()
	race_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_box.alignment = BoxContainer.ALIGNMENT_CENTER
	race_box.add_theme_constant_override("separation", 0)
	race_panel.add_child(race_box)
	race_label = Label.new()
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_label.add_theme_font_size_override("font_size", 20)
	race_label.add_theme_color_override("font_color", Color(0.9, 0.97, 1))
	race_label.text = "FREE ROAM"
	race_box.add_child(race_label)
	race_meta = Label.new()
	race_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_meta.add_theme_font_size_override("font_size", 15)
	race_meta.add_theme_color_override("font_color", Color(0.7, 0.9, 0.96))
	race_meta.text = "Drive the road network or press M"
	race_box.add_child(race_meta)

	storm_label = Label.new()
	storm_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	storm_label.position = Vector2(-180, 132)
	storm_label.size = Vector2(360, 28)
	storm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm_label.add_theme_font_size_override("font_size", 18)
	storm_label.add_theme_color_override("font_color", Color(0.95, 0.62, 0.32))
	storm_label.visible = false
	root.add_child(storm_label)

	standings_panel = PanelContainer.new()
	standings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	standings_panel.offset_left = -236
	standings_panel.offset_top = 12
	standings_panel.offset_right = -16
	standings_panel.offset_bottom = 168
	standings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings_panel.visible = false
	standings_panel.add_theme_stylebox_override("panel", UiStyle.hud_panel())
	root.add_child(standings_panel)
	var order_box := VBoxContainer.new()
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_box.add_theme_constant_override("separation", 4)
	standings_panel.add_child(order_box)
	var order_title := Label.new()
	order_title.text = "ORDER"
	order_title.add_theme_font_size_override("font_size", 12)
	order_title.add_theme_color_override("font_color", Color(0.55, 0.78, 0.86))
	order_box.add_child(order_title)
	standings = Label.new()
	standings.add_theme_font_size_override("font_size", 16)
	standings.add_theme_color_override("font_color", Color(0.9, 0.97, 1))
	order_box.add_child(standings)

	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.offset_left = -280
	prompt_panel.offset_top = -196
	prompt_panel.offset_right = 280
	prompt_panel.offset_bottom = -112
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false
	prompt_panel.add_theme_stylebox_override("panel", UiStyle.hud_panel())
	root.add_child(prompt_panel)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.94))
	prompt_panel.add_child(prompt_label)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-80, -80)
	banner.size = Vector2(160, 100)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 84)
	banner.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	banner.visible = false
	root.add_child(banner)

	wrong_label = Label.new()
	wrong_label.text = "WRONG WAY"
	wrong_label.set_anchors_preset(Control.PRESET_CENTER)
	wrong_label.position = Vector2(-120, 40)
	wrong_label.size = Vector2(240, 40)
	wrong_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_label.add_theme_font_size_override("font_size", 28)
	wrong_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	wrong_label.visible = false
	root.add_child(wrong_label)

	hint_label = Label.new()
	hint_label.text = "WASD drive   SHIFT boost   SPACE jump   CTRL/C drift   Q/E air roll   V camera   TAB/M map   F start   R reset"
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-460, -36)
	hint_label.size = Vector2(920, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85, 0.75))
	root.add_child(hint_label)

	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_script(load("res://scripts/race_overlay.gd"))
	minimap.host = self
	minimap.custom_minimum_size = Vector2(210, 210)
	minimap.position = Vector2(-238, -238)
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.offset_left = -238
	minimap.offset_top = -238
	minimap.offset_right = -28
	minimap.offset_bottom = -28
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	_build_track_preview(root)

	pointer = Control.new()
	pointer.name = "Pointer"
	pointer.set_script(load("res://scripts/race_overlay.gd"))
	pointer.host = self
	pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pointer)


func _build_track_preview(root: Control) -> void:
	preview_panel = PanelContainer.new()
	preview_panel.visible = false
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.anchor_left = 0.0
	preview_panel.anchor_top = 0.5
	preview_panel.anchor_right = 0.0
	preview_panel.anchor_bottom = 0.5
	preview_panel.offset_left = 28.0
	preview_panel.offset_top = -250.0
	preview_panel.offset_right = 448.0
	preview_panel.offset_bottom = 230.0
	preview_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	root.add_child(preview_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	preview_panel.add_child(box)
	preview_title = Label.new()
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 20)
	preview_title.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	box.add_child(preview_title)
	preview_note = Label.new()
	preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_note.add_theme_font_size_override("font_size", 13)
	preview_note.add_theme_color_override("font_color", Color(0.7, 0.84, 0.9))
	box.add_child(preview_note)
	track_preview = Control.new()
	track_preview.name = "TrackPreview"
	track_preview.set_script(load("res://scripts/race_overlay.gd"))
	track_preview.host = self
	track_preview.custom_minimum_size = Vector2(380, 360)
	track_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(track_preview)


func _update_preview() -> void:
	if preview_panel == null or world == null:
		return
	var blocked := _paused or _map_open or results_panel.visible or mission_panel.visible
	var open_preview := false
	var def: Dictionary = {}
	if not blocked and world.race.active and not world.race.started:
		var live: Dictionary = world.race.race
		def = live
		open_preview = not live.is_empty()
	elif not blocked and not world.race.active and int(world.near_race) >= 0:
		var races: Array = world.roads.races
		var idx := int(world.near_race)
		if idx < races.size():
			var picked: Dictionary = races[idx]
			def = picked
			open_preview = true
	preview_panel.visible = open_preview
	if not open_preview:
		return
	preview_title.text = str(def.name).to_upper()
	preview_note.text = str(def.blurb)
	if track_preview:
		track_preview.queue_redraw()


func _build_pause(root: Control) -> void:
	pause_panel = _overlay(root)
	pause_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-160, -140)
	box.custom_minimum_size = Vector2(320, 280)
	pause_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	box.add_child(HSeparator.new())
	var resume := UiStyle.button("RESUME")
	resume.pressed.connect(func() -> void: _set_paused(false))
	box.add_child(resume)
	var garage := UiStyle.button("GARAGE")
	garage.pressed.connect(_open_garage)
	box.add_child(garage)
	var missions := UiStyle.button("MAP")
	missions.pressed.connect(func() -> void:
		_set_paused(false)
		_set_guide(true)
	)
	box.add_child(missions)
	var retire := UiStyle.button("RETIRE TO ROAM")
	retire.pressed.connect(func() -> void:
		_set_paused(false)
		if world.race.active:
			world.return_to_roam()
	)
	box.add_child(retire)
	var menu := UiStyle.button("MAIN MENU")
	menu.pressed.connect(_to_menu)
	box.add_child(menu)


func _guide_pressed() -> bool:
	return Input.is_action_just_pressed("missions") or Input.is_action_just_pressed("map")


func _toggle_guide() -> void:
	_set_guide(not _map_open)


func _set_guide(open: bool) -> void:
	_map_open = open
	if mission_panel:
		mission_panel.visible = open
	if not open:
		return
	if map_texture == null:
		_bake_map()
	if map_panel:
		map_panel.queue_redraw()
	var busy: bool = world != null and bool(world.race.active)
	_refresh_medals()
	if _guide_note:
		_guide_note.text = "A race is already running." if busy else "Drive to a start beacon to begin that race."


func _refresh_medals() -> void:
	if world == null or _medal_summary == null:
		return
	var world_id := GameState.world_seed
	var gold := 0
	var silver := 0
	var bronze := 0
	for i in _medal_labels.size():
		var rank := GameState.medal_rank(world_id, _race_names[i])
		_paint_medal(_medal_labels[i], rank)
		if rank >= 3:
			gold += 1
		elif rank == 2:
			silver += 1
		elif rank == 1:
			bronze += 1
	_medal_summary.text = "%d GOLD    %d SILVER    %d BRONZE" % [gold, silver, bronze]
	if _invite_note:
		_invite_note.visible = gold >= 4


func _paint_medal(label: Label, rank: int) -> void:
	if rank >= 3:
		label.text = "GOLD"
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.28))
	elif rank == 2:
		label.text = "SILVER"
		label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	elif rank == 1:
		label.text = "BRONZE"
		label.add_theme_color_override("font_color", Color(0.82, 0.5, 0.26))
	else:
		label.text = "—"
		label.add_theme_color_override("font_color", Color(0.45, 0.52, 0.58))


func _bake_map() -> void:
	var n := 176
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var half := TerrainField.HALF
	for y in n:
		for x in n:
			var wx := lerpf(-half, half, float(x) / float(n - 1))
			var wz := lerpf(half, -half, float(y) / float(n - 1))
			var h: float = world.terrain.height_at(wx, wz)
			var normal: Vector3 = world.terrain.normal_at(wx, wz)
			var road: float = world.terrain.road_factor(wx, wz)
			var col: Color = world.terrain.ground_color(wx, wz, h, normal, road)
			img.set_pixel(x, y, col)
	map_texture = ImageTexture.create_from_image(img)


func _build_results(root: Control) -> void:
	results_panel = _overlay(root)
	results_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -210)
	box.custom_minimum_size = Vector2(440, 420)
	results_panel.add_child(box)
	results_body = Label.new()
	results_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_body.add_theme_font_size_override("font_size", 20)
	box.add_child(results_body)
	var cont := UiStyle.button("CONTINUE", 440)
	cont.pressed.connect(func() -> void: world.return_to_roam())
	box.add_child(cont)
	var retry := UiStyle.button("RETRY", 440)
	retry.pressed.connect(func() -> void: world.retry_race())
	box.add_child(retry)
	var menu := UiStyle.button("MAIN MENU", 440)
	menu.pressed.connect(_to_menu)
	box.add_child(menu)


func _build_missions(root: Control) -> void:
	mission_panel = _overlay(root)
	mission_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "DESERT MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_guide_note = Label.new()
	_guide_note.text = "Drive to a start beacon to begin that race."
	_guide_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_guide_note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	map_panel = Control.new()
	map_panel.name = "WorldMap"
	map_panel.custom_minimum_size = Vector2(700, 620)
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.set_script(load("res://scripts/race_overlay.gd"))
	map_panel.host = self
	columns.add_child(map_panel)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(420, 620)
	side.add_theme_constant_override("separation", 6)
	columns.add_child(side)
	_medal_summary = Label.new()
	_medal_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_medal_summary.add_theme_font_size_override("font_size", 14)
	side.add_child(_medal_summary)
	_invite_note = Label.new()
	_invite_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_invite_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite_note.custom_minimum_size = Vector2(400, 0)
	_invite_note.add_theme_font_size_override("font_size", 14)
	_invite_note.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	_invite_note.text = "A message arrives. You are invited to the races on the next planet. Drive to the space port."
	_invite_note.visible = false
	side.add_child(_invite_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_medal_labels.clear()
	_race_names = PackedStringArray()
	for i in world.roads.races.size():
		var def: Dictionary = world.roads.races[i]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(row)
		var info := Label.new()
		var kind := "CIRCUIT"
		info.text = "%s\n%s · %d lap%s · %s" % [
			str(def.name).to_upper(),
			kind,
			int(def.laps),
			"" if int(def.laps) == 1 else "s",
			def.blurb,
		]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(180, 44)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var medal := Label.new()
		medal.custom_minimum_size = Vector2(72, 44)
		medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		medal.add_theme_font_size_override("font_size", 13)
		row.add_child(medal)
		_medal_labels.append(medal)
		_race_names.append(str(def.name))
		var mark := UiStyle.button("PIN", 72)
		mark.custom_minimum_size = Vector2(72, 36)
		mark.add_theme_font_size_override("font_size", 14)
		var index: int = i
		mark.pressed.connect(func() -> void:
			world.waypoint = index
			_set_guide(false)
		)
		row.add_child(mark)
	_refresh_medals()
	var close := UiStyle.button("CLOSE", 200)
	close.pressed.connect(func() -> void: _set_guide(false))
	box.add_child(close)


func _build_port(root: Control) -> void:
	_port_panel = _overlay(root)
	_port_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-180, -210)
	box.custom_minimum_size = Vector2(360, 400)
	_port_panel.add_child(box)
	var title := Label.new()
	title.text = "SPACE PORT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var note := Label.new()
	note.text = "Choose a planet."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var desert := UiStyle.button("VERMILION WASTES", 360)
	desert.pressed.connect(func() -> void: world.depart_to("desert"))
	box.add_child(desert)
	_port_ice = UiStyle.button("FROST REACH", 360)
	_port_ice.pressed.connect(func() -> void: world.depart_to("ice"))
	box.add_child(_port_ice)
	_port_grass = UiStyle.button("EMERALD STEPPE", 360)
	_port_grass.pressed.connect(func() -> void: world.depart_to("grass"))
	box.add_child(_port_grass)
	var close := UiStyle.button("CLOSE", 360)
	close.pressed.connect(close_port)
	box.add_child(close)


func open_port() -> void:
	if _port_panel == null or _port_open:
		return
	_port_open = true
	_port_panel.visible = true
	if _port_ice:
		_port_ice.disabled = not GameState.ice_unlocked
		_port_ice.text = "FROST REACH" if GameState.ice_unlocked else "FROST REACH  —  4 GOLD MEDALS"
	if _port_grass:
		_port_grass.disabled = not GameState.grass_unlocked
		_port_grass.text = "EMERALD STEPPE" if GameState.grass_unlocked else "EMERALD STEPPE  —  4 ICE GOLDS"
	get_tree().paused = true


func close_port() -> void:
	_port_open = false
	if _port_panel:
		_port_panel.visible = false
	if not _paused:
		get_tree().paused = false


func _overlay(root: Control) -> Control:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	return dim


func _open_garage() -> void:
	if _garage != null:
		return
	_garage = GarageUi.new()
	_garage.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_garage)
	_garage.closed.connect(func() -> void:
		_garage = null
		if world.player:
			world.player.stats = GameState.preset().duplicate()
			world.player.primary = GameState.primary
			world.player.accent = GameState.accent
			if world.player._body_mat:
				var body := Color(0.05, 0.055, 0.07).lerp(GameState.primary, 0.34)
				world.player._body_mat.set_shader_parameter("body_color", body)
				world.player._body_mat.set_shader_parameter("accent_color", GameState.accent)
	)


func _to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
