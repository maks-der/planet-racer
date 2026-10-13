extends Control

var _buttons: Array[Button] = []
var _pick := 0


func _ready() -> void:
	theme = UiStyle.theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_bg.gdshader")
	bg.material = mat
	add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(90, -210)
	column.custom_minimum_size = Vector2(460, 420)
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var kicker := Label.new()
	kicker.text = "SECTOR 01"
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.add_theme_color_override("font_color", Color(1.0, 0.62, 0.28))
	column.add_child(kicker)

	var title := Label.new()
	title.text = "PLANET RACER"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	column.add_child(title)

	var sub := Label.new()
	sub.text = "VERMILION WASTES"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.95, 0.82, 0.62))
	column.add_child(sub)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 70)
	body.text = "Each New Game builds a new desert. Hard hits drain the hull. At zero the car limps and smokes until you drive through a fix arch."
	body.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92))
	column.add_child(body)

	var new_game := UiStyle.button("NEW GAME", 280)
	new_game.pressed.connect(func() -> void:
		GameState.begin_new_world()
		get_tree().change_scene_to_file("res://scenes/world.tscn")
	)
	column.add_child(new_game)

	var quit := UiStyle.button("QUIT", 280)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	_buttons = [new_game, quit]
	UiStyle.trap_focus(_buttons)
	_focus(0)

	var hint := Label.new()
	hint.text = "Arrows choose    Enter or Space confirm    WASD drive    Shift boost    V camera"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(90, -48)
	hint.add_theme_color_override("font_color", Color(0.75, 0.84, 0.9, 0.8))
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if _buttons.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_focus(_pick - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_focus(_pick + 1)
		get_viewport().set_input_as_handled()


func _focus(index: int) -> void:
	_pick = posmod(index, _buttons.size())
	_buttons[_pick].grab_focus()
