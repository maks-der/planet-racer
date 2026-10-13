class_name GarageUi
extends Control

signal closed

var _balance: Label
var _detail: Label
var _car_buttons: Array[Button] = []
var _part_buttons: Array[Button] = []
var _nav: Array[Button] = []
var _nav_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.theme()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.03, 0.82)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(640, 560)
	box.add_theme_stylebox_override("panel", UiStyle.panel())
	center.add_child(box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	box.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var title := Label.new()
	title.text = "GARAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_balance)
	for i in GameState.PRESETS.size():
		var btn := UiStyle.button("", 580)
		var index := i
		btn.pressed.connect(func() -> void:
			_pick_car(index)
		)
		root.add_child(btn)
		_car_buttons.append(btn)
		_nav.append(btn)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_detail)
	for part_i in GameState.PARTS.size():
		var part_btn := UiStyle.button("", 580)
		var slot := part_i
		part_btn.pressed.connect(func() -> void:
			if GameState.buy_part(GameState.preset_index, slot):
				_refresh()
		)
		root.add_child(part_btn)
		_part_buttons.append(part_btn)
		_nav.append(part_btn)
	root.add_child(_swatches("BODY", true))
	root.add_child(_swatches("ACCENT", false))
	var close := UiStyle.button("DONE", 580)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free()
	)
	root.add_child(close)
	_nav.append(close)
	UiStyle.trap_focus(_nav)
	_refresh()
	_focus_nav(0)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_step_nav(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_step_nav(1)
		get_viewport().set_input_as_handled()


func _pick_car(index: int) -> void:
	if GameState.owns_car(index):
		GameState.set_preset(index)
	elif not GameState.buy_car(index):
		_detail.text = "Not enough funds for %s." % str(GameState.PRESETS[index].name)
		return
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
		var style := StyleBoxFlat.new()
		style.bg_color = swatch
		style.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		var color: Color = swatch
		btn.pressed.connect(func() -> void:
			if primary:
				GameState.set_colors(color, GameState.accent)
			else:
				GameState.set_colors(GameState.primary, color)
			_refresh()
		)
		row.add_child(btn)
		_nav.append(btn)
	return row


func _refresh() -> void:
	_balance.text = "FUNDS  $%d" % GameState.money
	for i in _car_buttons.size():
		var preset: Dictionary = GameState.PRESETS[i]
		var btn := _car_buttons[i]
		if GameState.owns_car(i):
			var mark := "  ·  DRIVING" if i == GameState.preset_index else ""
			btn.text = "%s%s" % [str(preset.name), mark]
		else:
			btn.text = "%s    $%d" % [str(preset.name), GameState.CAR_COST[i]]
	var current: Dictionary = GameState.preset()
	_detail.text = "%s\n%s" % [str(current.name), str(current.blurb)]
	for part_i in _part_buttons.size():
		var level := GameState._part(GameState.preset_index, part_i)
		var cost := GameState.next_part_cost(GameState.preset_index, part_i)
		var btn := _part_buttons[part_i]
		if not GameState.owns_car(GameState.preset_index):
			btn.disabled = true
			btn.text = "%s" % GameState.PARTS[part_i]
		elif cost < 0:
			btn.disabled = true
			btn.text = "%s    MAX" % GameState.PARTS[part_i]
		else:
			btn.disabled = false
			btn.text = "%s    LV %d    $%d" % [GameState.PARTS[part_i], level, cost]


func _focus_nav(index: int) -> void:
	if _nav.is_empty():
		return
	_nav_i = posmod(index, _nav.size())
	var guard := 0
	while guard < _nav.size():
		var btn := _nav[_nav_i]
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return
		_nav_i = posmod(_nav_i + 1, _nav.size())
		guard += 1


func _step_nav(dir: int) -> void:
	if _nav.is_empty():
		return
	_nav_i = posmod(_nav_i + dir, _nav.size())
	var guard := 0
	while guard < _nav.size():
		var btn := _nav[_nav_i]
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return
		_nav_i = posmod(_nav_i + dir, _nav.size())
		guard += 1
