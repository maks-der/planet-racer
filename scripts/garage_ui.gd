class_name GarageUi
extends Control

signal closed

var _stat_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.theme()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.03, 0.78)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(720, 500)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	box.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var title := Label.new()
	title.text = "GARAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	root.add_child(title)
	var frames := HBoxContainer.new()
	frames.add_theme_constant_override("separation", 8)
	root.add_child(frames)
	for i in GameState.PRESETS.size():
		var preset: Dictionary = GameState.PRESETS[i]
		var btn := UiStyle.button(str(preset.name), 160)
		var index := i
		btn.pressed.connect(func() -> void:
			GameState.set_preset(index)
			_refresh()
		)
		frames.add_child(btn)
	_stat_label = Label.new()
	_stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_stat_label)
	root.add_child(_swatches("BODY", true))
	root.add_child(_swatches("ACCENT", false))
	var close := UiStyle.button("DONE", 180)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free()
	)
	root.add_child(close)
	_refresh()


func _swatches(label_text: String, primary: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 36)
	row.add_child(label)
	for swatch in GameState.SWATCHES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(42, 36)
		btn.text = ""
		var style := StyleBoxFlat.new()
		style.bg_color = swatch
		style.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		var color := swatch
		btn.pressed.connect(func() -> void:
			if primary:
				GameState.set_colors(color, GameState.accent)
			else:
				GameState.set_colors(GameState.primary, color)
			_refresh()
		)
		row.add_child(btn)
	return row


func _refresh() -> void:
	var preset := GameState.preset()
	_stat_label.text = "%s\n%s\nTop speed %d km/h    Boost %d km/h    Accel %d    Grip %d    Air %0.1f" % [
		preset.name,
		preset.blurb,
		int(float(preset.max_speed) * 3.6),
		int(float(preset.boost_speed) * 3.6),
		int(preset.accel),
		int(preset.grip),
		float(preset.air),
	]
