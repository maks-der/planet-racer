class_name DebugConsole
extends CanvasLayer

var world
var _open := false
var _held_pause := false
var _root: Control
var _log: Label
var _line: LineEdit


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -220
	panel.offset_bottom = -12
	panel.offset_left = 16
	panel.offset_right = -16
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_log = Label.new()
	_log.text = "planet desert    planet ice"
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_size_override("font_size", 14)
	box.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "planet desert | planet ice"
	_line.text_submitted.connect(_submit)
	box.add_child(_line)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode != KEY_QUOTELEFT and key.keycode != KEY_ASCIITILDE and key.keycode != KEY_F8:
		return
	if _open:
		_close()
	else:
		_show()
	get_viewport().set_input_as_handled()


func _show() -> void:
	_open = true
	_root.visible = true
	_held_pause = get_tree().paused
	get_tree().paused = true
	_line.grab_focus()


func _close() -> void:
	_open = false
	_root.visible = false
	_line.release_focus()
	if not _held_pause:
		get_tree().paused = false


func _submit(text: String) -> void:
	var line := text.strip_edges()
	_line.text = ""
	if line.is_empty():
		return
	var parts := line.split(" ", false)
	if parts.size() >= 2 and parts[0] == "planet":
		var id := parts[1]
		if id != "desert" and id != "ice":
			_log.text = "Unknown planet. Use desert or ice."
			return
		if world == null:
			return
		_log.text = "Traveling to %s." % id
		_close()
		world.depart_to(id, true)
		return
	_log.text = "Commands: planet desert    planet ice"
