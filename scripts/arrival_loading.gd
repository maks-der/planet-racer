class_name ArrivalLoading
extends Node3D

var voyage_time := 6.4
var fade_time := 1.6
var progress := 0.04
var elapsed := 0.0
var _fade := 0.0

var _cam: Camera3D
var _planet: Node3D
var _ship: Node3D
var _status: Label
var _bar: ProgressBar
var _veil: ColorRect
var _approach_from := Vector3(9.4, 1.6, 7.2)
var _approach_to := Vector3(4.6, 0.85, 3.4)


func _ready() -> void:
	position = Vector3(0.0, 16000.0, 0.0)
	_planet = get_node_or_null("DesertPlanet") as Node3D
	_ship = get_node_or_null("Starship") as Node3D
	_cam = get_node_or_null("Camera3D") as Camera3D
	if _planet:
		_planet.position = Vector3(-3.1, 0.15, -0.4)
		_planet.rotation.y = PI
	if _ship:
		_ship.position = _approach_from
	_build_ui()


func set_progress(value: float, status: String) -> void:
	progress = maxf(progress, clampf(value, 0.0, 1.0))
	if _status:
		_status.text = status
	if _bar:
		_bar.value = progress * 100.0


func play_out(switch_to_world: Callable) -> void:
	var alpha := 0.0
	while alpha < 1.0:
		alpha = minf(1.0, alpha + get_process_delta_time() * 2.4)
		_veil.color = Color(0.45, 0.28, 0.14, alpha)
		await get_tree().process_frame
	switch_to_world.call()
	while alpha > 0.0:
		alpha = maxf(0.0, alpha - get_process_delta_time() * 1.8)
		_veil.color = Color(0.45, 0.28, 0.14, alpha)
		await get_tree().process_frame
	queue_free()


func _process(dt: float) -> void:
	if _planet:
		_planet.rotate_y(dt * 0.028)
	if _fade < 1.0:
		_fade = minf(1.0, _fade + dt / fade_time)
		var eased_fade := _fade * _fade * (3.0 - 2.0 * _fade)
		if _veil:
			_veil.color = Color(0.01, 0.012, 0.02, 1.0 - eased_fade)
		_frame_approach(0.0)
		return
	elapsed += dt
	var travel := clampf(elapsed / voyage_time, 0.0, 1.0)
	var eased := travel * travel * (3.0 - 2.0 * travel)
	_frame_approach(eased)


func _frame_approach(u: float) -> void:
	if _planet:
		_planet.position = Vector3(-3.1, 0.15, -0.4)
		_planet.scale = Vector3.ONE
	if _ship:
		_ship.position = _approach_from.lerp(_approach_to, u)
		_ship.scale = Vector3.ONE
		_aim_ship((_approach_to - _approach_from).normalized())
		_set_flames(u > 0.001)
	if _cam:
		_cam.position = Vector3(4.4, 1.15, 9.6)
		_cam.look_at(to_global(Vector3(1.7, 0.25, -0.2)), Vector3.UP)


func _aim_ship(dir: Vector3) -> void:
	if _ship == null:
		return
	var aim := _ship.position + dir
	if _ship.global_position.distance_squared_to(to_global(aim)) > 0.01:
		_ship.look_at(to_global(aim), Vector3.UP)


func _set_flames(on: bool) -> void:
	if _ship == null:
		return
	for flame in _ship.find_children("Flame*", "MeshInstance3D"):
		(flame as Node3D).visible = on


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	layer.add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-280, -168)
	panel.custom_minimum_size = Vector2(560, 132)
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var kicker := Label.new()
	kicker.text = "PLANET RACER"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	box.add_child(kicker)
	var title := Label.new()
	title.text = "VERMILION WASTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.62))
	box.add_child(title)
	_status = Label.new()
	_status.text = "STARSHIP INBOUND"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.82, 0.9, 0.95))
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.max_value = 100.0
	_bar.value = 4.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(520, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.9, 1.0)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.01, 0.012, 0.02, 1.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)
