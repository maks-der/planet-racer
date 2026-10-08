extends Node

const PRESETS: Array[Dictionary] = [
	{
		"id": "striker",
		"name": "STRIKER",
		"blurb": "Balanced frame. Hard acceleration and predictable grip.",
		"accel": 52.0,
		"brake": 72.0,
		"max_speed": 74.0,
		"boost_speed": 100.0,
		"grip": 16.0,
		"drift_grip": 3.4,
		"turn": 2.05,
		"jump": 16.0,
		"air": 1.8,
		"hover": 0.95,
		"boost_drain": 34.0,
		"boost_regen": 16.0,
		"drift_boost": 24.0,
	},
	{
		"id": "viper",
		"name": "VIPER",
		"blurb": "Top-speed shell with a long boost and a loose rear.",
		"accel": 44.0,
		"brake": 62.0,
		"max_speed": 86.0,
		"boost_speed": 118.0,
		"grip": 11.0,
		"drift_grip": 2.5,
		"turn": 1.72,
		"jump": 14.0,
		"air": 1.55,
		"hover": 0.82,
		"boost_drain": 26.0,
		"boost_regen": 14.0,
		"drift_boost": 16.0,
	},
	{
		"id": "sidecut",
		"name": "SIDECUT",
		"blurb": "Drift frame. Sharp rotation, and slides refill the boost.",
		"accel": 48.0,
		"brake": 66.0,
		"max_speed": 72.0,
		"boost_speed": 96.0,
		"grip": 9.0,
		"drift_grip": 1.65,
		"turn": 2.65,
		"jump": 15.0,
		"air": 1.7,
		"hover": 0.9,
		"boost_drain": 32.0,
		"boost_regen": 12.0,
		"drift_boost": 38.0,
	},
	{
		"id": "skyblade",
		"name": "SKYBLADE",
		"blurb": "Aerial frame. Higher hover, stronger jump, looser air control.",
		"accel": 46.0,
		"brake": 64.0,
		"max_speed": 70.0,
		"boost_speed": 104.0,
		"grip": 13.0,
		"drift_grip": 3.0,
		"turn": 1.9,
		"jump": 22.0,
		"air": 2.7,
		"hover": 1.35,
		"boost_drain": 30.0,
		"boost_regen": 18.0,
		"drift_boost": 18.0,
	},
]

const SWATCHES: Array[Color] = [
	Color("14e6ff"),
	Color("ff8a1e"),
	Color("ff3d8a"),
	Color("b6ff3a"),
	Color("f4f7ff"),
	Color("ff3b3b"),
	Color("7aa2ff"),
	Color("c58bff"),
]

var world_seed: int = 0
var preset_index: int = 0
var primary := Color("14e6ff")
var accent := Color("ff8a1e")
var best_times: Dictionary = {}


func _ready() -> void:
	_ensure_inputs()
	_load_car()


func _ensure_inputs() -> void:
	_action("throttle", [KEY_W, KEY_UP])
	_action("brake", [KEY_S, KEY_DOWN])
	_action("steer_left", [KEY_A, KEY_LEFT])
	_action("steer_right", [KEY_D, KEY_RIGHT])
	_action("boost", [KEY_SHIFT])
	_action("jump", [KEY_SPACE])
	_action("drift", [KEY_CTRL, KEY_C])
	_action("roll_left", [KEY_Q])
	_action("roll_right", [KEY_E])
	_action("interact", [KEY_F])
	_action("pause", [KEY_ESCAPE])
	_action("reset", [KEY_R])
	_action("missions", [KEY_M])
	_action("camera_view", [KEY_V])
	_action("map", [KEY_TAB])
	_joy_button("jump", JOY_BUTTON_A)
	_joy_button("boost", JOY_BUTTON_B)
	_joy_button("drift", JOY_BUTTON_X)
	_joy_button("boost", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_button("interact", JOY_BUTTON_Y)
	_joy_button("pause", JOY_BUTTON_START)
	_joy_button("reset", JOY_BUTTON_BACK)
	_joy_button("camera_view", JOY_BUTTON_RIGHT_STICK)
	_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("throttle", JOY_AXIS_LEFT_Y, -1.0)
	_axis("brake", JOY_AXIS_LEFT_Y, 1.0)
	_axis("throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)


func _action(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(name, ev)


func _joy_button(name: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(name, ev)


func _axis(name: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(name, ev)


func begin_new_world() -> void:
	world_seed = randi() % 999983
	if world_seed < 1:
		world_seed = 1
	best_times.clear()


func preset() -> Dictionary:
	return PRESETS[clampi(preset_index, 0, PRESETS.size() - 1)]


func set_preset(index: int) -> void:
	preset_index = clampi(index, 0, PRESETS.size() - 1)
	save_car()


func set_colors(body: Color, trim: Color) -> void:
	primary = body
	accent = trim
	save_car()


func remember_time(seed: int, race_name: String, time: float) -> bool:
	var key := "%d|%s" % [seed, race_name]
	if not best_times.has(key) or time < float(best_times[key]):
		best_times[key] = time
		return true
	return false


func best_time(seed: int, race_name: String) -> float:
	var key := "%d|%s" % [seed, race_name]
	if best_times.has(key):
		return float(best_times[key])
	return -1.0


func save_car() -> void:
	var cf := ConfigFile.new()
	cf.set_value("car", "preset", preset_index)
	cf.set_value("car", "primary", primary.to_html(false))
	cf.set_value("car", "accent", accent.to_html(false))
	cf.save("user://car.cfg")


func _load_car() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://car.cfg") != OK:
		return
	preset_index = int(cf.get_value("car", "preset", 0))
	primary = Color.html(str(cf.get_value("car", "primary", "14e6ff")))
	accent = Color.html(str(cf.get_value("car", "accent", "ff8a1e")))
