class_name GameHud
extends CanvasLayer

var world
var speed_label: Label
var boost_bar: ProgressBar
var race_label: Label
var prompt_label: Label
var banner: Label
var wrong_label: Label
var hint_label: Label
var seed_label: Label
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
var game_over_panel: Control
var wreck_note: Label
var wreck_retry: Button
var map_panel: Control
var _mission_starts: Array[Button] = []
var _guide_note: Label
var _map_open := false
var map_texture: ImageTexture
var speed_fx: ColorRect
var _speed_mat: ShaderMaterial


func bind(host) -> void:
	world = host
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_build_drive_ui(root)
	_build_pause(root)
	_build_game_over(root)
	_build_results(root)
	_build_missions(root)


func _process(_dt: float) -> void:
	if world == null or world.player == null:
		return
	_refresh()
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
	elif _guide_pressed() and _garage == null and not _paused and not world.run_over and not results_panel.visible and not game_over_panel.visible:
		_toggle_guide()


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
		var rush := Util.smoothstep(55.0, 108.0, car.speed_mps())
		_speed_mat.set_shader_parameter("intensity", rush)
	boost_bar.value = car.boost
	seed_label.text = "VERMILION WASTES   SEED %06d" % GameState.world_seed
	var race = world.race
	if race.active:
		prompt_label.text = ""
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
			laps = "   LAP %d/%d" % [mini(car.lap + 1, int(race.race.laps)), int(race.race.laps)]
		var cp := "%d/%d" % [mini(car.cp_index, race.race.checkpoints.size()), race.race.checkpoints.size()]
		race_label.text = "%s\n%s%s\nCP %s    %s" % [
			str(race.race.name).to_upper(),
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
		standings.visible = true
	else:
		banner.visible = false
		wrong_label.visible = false
		standings.visible = false
		if world.near_race >= 0:
			var def: Dictionary = world.roads.races[world.near_race]
			prompt_label.text = "F  —  START  %s\n%s" % [str(def.name).to_upper(), def.blurb]
			race_label.text = "FREE ROAM"
		else:
			prompt_label.text = ""
			race_label.text = "FREE ROAM\nDrive the road network or press M"
	if storm_label:
		var storm := float(world.storm_level)
		storm_label.visible = storm > 0.28
		if storm > 0.72:
			storm_label.text = "WASTELAND STORM"
		elif storm > 0.28:
			storm_label.text = "DUST STORM"
	_update_preview()


func show_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = true
	if pause_panel:
		pause_panel.visible = false
	if results_panel:
		results_panel.visible = false
	_set_guide(false)
	if wreck_note and world:
		var racing: bool = bool(world.race.active or world.race.started or world.gates.size() > 0)
		wreck_note.text = "The car is wrecked.\nRestart the race, or return to the port." if racing else "The car is wrecked.\nIt will be moved back to the port."
		if wreck_retry:
			wreck_retry.visible = racing
	_paused = false
	get_tree().paused = false


func hide_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = false


func _return_to_port() -> void:
	get_tree().paused = false
	if world:
		world.restore_at_port()


func _restart_race() -> void:
	get_tree().paused = false
	if world:
		world.restart_wrecked_race()


func _on_escape() -> void:
	if world != null and world.run_over:
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
	speed_box.offset_top = -150
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
	boost_bar = ProgressBar.new()
	boost_bar.max_value = 100
	boost_bar.value = 100
	boost_bar.show_percentage = false
	boost_bar.custom_minimum_size = Vector2(180, 16)
	var boost_bg := StyleBoxFlat.new()
	boost_bg.bg_color = Color(0.08, 0.09, 0.11)
	boost_bg.set_corner_radius_all(2)
	var boost_fill := StyleBoxFlat.new()
	boost_fill.bg_color = Color(1.0, 0.55, 0.16)
	boost_fill.set_corner_radius_all(2)
	boost_bar.add_theme_stylebox_override("background", boost_bg)
	boost_bar.add_theme_stylebox_override("fill", boost_fill)
	vb.add_child(boost_bar)
	var boost_name := Label.new()
	boost_name.text = "BOOST"
	boost_name.add_theme_font_size_override("font_size", 12)
	boost_name.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	vb.add_child(boost_name)

	view_label = Label.new()
	view_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	view_label.position = Vector2(-120, 108)
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

	race_label = Label.new()
	race_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	race_label.position = Vector2(-180, 18)
	race_label.size = Vector2(360, 90)
	race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_label.add_theme_font_size_override("font_size", 20)
	race_label.add_theme_color_override("font_color", Color(0.9, 0.97, 1))
	root.add_child(race_label)

	storm_label = Label.new()
	storm_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	storm_label.position = Vector2(-180, 112)
	storm_label.size = Vector2(360, 28)
	storm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm_label.add_theme_font_size_override("font_size", 18)
	storm_label.add_theme_color_override("font_color", Color(0.95, 0.62, 0.32))
	storm_label.visible = false
	root.add_child(storm_label)

	standings = Label.new()
	standings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	standings.position = Vector2(-230, 18)
	standings.size = Vector2(200, 160)
	standings.add_theme_font_size_override("font_size", 16)
	standings.visible = false
	root.add_child(standings)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-260, -220)
	prompt_label.size = Vector2(520, 70)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.95))
	root.add_child(prompt_label)

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
	var blocked := _paused or _map_open or game_over_panel.visible or results_panel.visible or mission_panel.visible
	var show := false
	var def: Dictionary = {}
	if not blocked and world.race.active and not world.race.started:
		var live: Dictionary = world.race.race
		def = live
		show = not live.is_empty()
	elif not blocked and not world.race.active and int(world.near_race) >= 0:
		var races: Array = world.roads.races
		var idx := int(world.near_race)
		if idx < races.size():
			var picked: Dictionary = races[idx]
			def = picked
			show = true
	preview_panel.visible = show
	if not show:
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
	for btn in _mission_starts:
		btn.disabled = busy
	if _guide_note:
		_guide_note.text = "A race is already running." if busy else "Routes share the desert road network. Start here, or drive into a beacon."


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


func _build_game_over(root: Control) -> void:
	game_over_panel = _overlay(root)
	game_over_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -150)
	box.custom_minimum_size = Vector2(440, 400)
	box.add_theme_constant_override("separation", 12)
	game_over_panel.add_child(box)
	var title := Label.new()
	title.text = "CAR WRECKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.28))
	box.add_child(title)
	wreck_note = Label.new()
	var note := wreck_note
	note.text = "The car is wrecked.\nIt will be moved back to the port."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 18)
	box.add_child(note)
	wreck_retry = UiStyle.button("RESTART RACE", 440)
	wreck_retry.visible = false
	wreck_retry.pressed.connect(_restart_race)
	box.add_child(wreck_retry)
	var again := UiStyle.button("RETURN TO PORT", 440)
	again.pressed.connect(_return_to_port)
	box.add_child(again)
	var menu := UiStyle.button("MAIN MENU", 440)
	menu.pressed.connect(_to_menu)
	box.add_child(menu)


func _build_results(root: Control) -> void:
	results_panel = _overlay(root)
	results_panel.visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -180)
	box.custom_minimum_size = Vector2(440, 360)
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
	_guide_note.text = "Routes share the desert road network. Start here, or drive into a beacon."
	_guide_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_guide_note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	map_panel = Control.new()
	map_panel.name = "WorldMap"
	map_panel.custom_minimum_size = Vector2(760, 640)
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.set_script(load("res://scripts/race_overlay.gd"))
	map_panel.host = self
	columns.add_child(map_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 640)
	columns.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in world.roads.races.size():
		var def: Dictionary = world.roads.races[i]
		var row := HBoxContainer.new()
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
		info.custom_minimum_size = Vector2(280, 52)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var go := UiStyle.button("START", 110)
		var index: int = i
		go.pressed.connect(func() -> void: world.start_race(index))
		_mission_starts.append(go)
		row.add_child(go)
		var mark := UiStyle.button("PIN", 80)
		mark.pressed.connect(func() -> void:
			world.waypoint = index
			_set_guide(false)
		)
		row.add_child(mark)
	var close := UiStyle.button("CLOSE", 200)
	close.pressed.connect(func() -> void: _set_guide(false))
	box.add_child(close)


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
