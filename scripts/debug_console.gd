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
	panel.offset_top = -280
	panel.offset_bottom = -12
	panel.offset_left = 16
	panel.offset_right = -16
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_log = Label.new()
	_log.text = "planet desert | ice | grass\nreward <1-8> gold | silver | bronze | none\nfix\nmoney 1000"
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_size_override("font_size", 14)
	box.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "planet grass | reward 1 gold | fix | money 1000"
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
		if id != "desert" and id != "ice" and id != "grass":
			_log.text = "Unknown planet. Use desert, ice, or grass."
			return
		if world == null:
			return
		_log.text = "Traveling to %s." % id
		_close()
		world.depart_to(id, true)
		return
	if parts.size() >= 1 and parts[0] == "reward":
		_reward(parts)
		return
	if parts.size() >= 1 and parts[0] == "fix":
		_fix_car()
		return
	if parts.size() >= 1 and parts[0] == "money":
		_add_money(parts)
		return
	_log.text = "planet desert | ice | grass\nreward <1-8> gold | silver | bronze | none\nfix\nmoney 1000"


func _reward(parts: PackedStringArray) -> void:
	if parts.size() < 3:
		_log.text = "reward <1-8> gold | silver | bronze | none"
		return
	if world == null or world.roads == null:
		_log.text = "Races are not ready."
		return
	var index := int(parts[1]) - 1
	var kind := parts[2]
	var rank := -1
	if kind == "gold":
		rank = 3
	elif kind == "silver":
		rank = 2
	elif kind == "bronze":
		rank = 1
	elif kind == "none":
		rank = 0
	if rank < 0:
		_log.text = "Use gold, silver, bronze, or none."
		return
	var races: Array = world.roads.races
	if index < 0 or index >= races.size():
		_log.text = "Race %s is out of range." % parts[1]
		return
	var def: Dictionary = races[index]
	GameState.set_medal(GameState.world_seed, str(def.name), rank)
	if world.hud:
		world.hud._refresh_medals()
	_log.text = "%s is now %s." % [str(def.name), kind.to_upper()]


func _add_money(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		_log.text = "Funds $%d. Use money 1000 to add." % GameState.money
		return
	var raw := parts[1]
	if raw == "add" and parts.size() >= 3:
		raw = parts[2]
	var amount := int(raw)
	if amount == 0 and raw != "0":
		_log.text = "Use money 1000 to add funds."
		return
	GameState.add_money(amount)
	_log.text = "Funds $%d." % GameState.money


func _fix_car() -> void:
	if world == null or world.player == null:
		_log.text = "Car is not ready."
		return
	if world.player.hp >= HoverCar.HP_MAX - 0.05:
		_log.text = "Hull is already full."
		return
	world.player.restore_hull()
	_log.text = "Hull restored."
