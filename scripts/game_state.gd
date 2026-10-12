extends Node

const PRESETS: Array[Dictionary] = [
	{
		"id": "striker",
		"name": "STRIKER",
		"blurb": "Balanced frame. Hard acceleration and predictable grip.",
		"accel": 22.0,
		"brake": 72.0,
		"max_speed": 1227.0 / 3.6,
		"boost_speed": 1227.0 / 3.6,
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
		"accel": 18.0,
		"brake": 62.0,
		"max_speed": 1227.0 / 3.6,
		"boost_speed": 1227.0 / 3.6,
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
		"accel": 20.0,
		"brake": 66.0,
		"max_speed": 1227.0 / 3.6,
		"boost_speed": 1227.0 / 3.6,
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
		"accel": 19.0,
		"brake": 64.0,
		"max_speed": 1227.0 / 3.6,
		"boost_speed": 1227.0 / 3.6,
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
var desert_seed: int = 0
var ice_seed: int = 0
var planet := "desert"
var ice_unlocked := false
var preset_index: int = 0
var primary := Color("14e6ff")
var accent := Color("ff8a1e")
var best_times: Dictionary = {}
var medals: Dictionary = {}
var just_invited := false


func _ready() -> void:
	_ensure_inputs()
	_load_car()
	_load_medals()
	_load_progress()


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


func _action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action_name, ev)


func _joy_button(action_name: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)


func _axis(action_name: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action_name, ev)


func begin_new_world() -> void:
	desert_seed = randi() % 999983
	if desert_seed < 1:
		desert_seed = 1
	ice_seed = 0
	world_seed = desert_seed
	planet = "desert"
	best_times.clear()
	_save_progress()


func preset() -> Dictionary:
	return PRESETS[clampi(preset_index, 0, PRESETS.size() - 1)]


func set_preset(index: int) -> void:
	preset_index = clampi(index, 0, PRESETS.size() - 1)
	save_car()


func set_colors(body: Color, trim: Color) -> void:
	primary = body
	accent = trim
	save_car()


func remember_time(world_id: int, race_name: String, time: float) -> bool:
	var key := "%d|%s" % [world_id, race_name]
	if not best_times.has(key) or time < float(best_times[key]):
		best_times[key] = time
		return true
	return false


func best_time(world_id: int, race_name: String) -> float:
	var key := "%d|%s" % [world_id, race_name]
	if best_times.has(key):
		return float(best_times[key])
	return -1.0


func medal_rank(world_id: int, race_name: String) -> int:
	return int(medals.get(_medal_key(world_id, race_name), 0))


func medal_name(rank: int) -> String:
	if rank >= 3:
		return "GOLD"
	if rank == 2:
		return "SILVER"
	if rank == 1:
		return "BRONZE"
	return ""


func gold_count(world_id: int) -> int:
	var prefix := "%d|" % world_id
	var count := 0
	for key in medals.keys():
		if str(key).begins_with(prefix) and int(medals[key]) >= 3:
			count += 1
	return count


func award_medal(world_id: int, race_name: String, place: int) -> void:
	just_invited = false
	var rank := 0
	if place == 1:
		rank = 3
	elif place == 2:
		rank = 2
	elif place == 3:
		rank = 1
	if rank == 0:
		return
	var key := _medal_key(world_id, race_name)
	if rank <= int(medals.get(key, 0)):
		return
	var before := gold_count(world_id)
	medals[key] = rank
	if desert_seed > 0 and gold_count(desert_seed) >= 4:
		ice_unlocked = true
	_save_medals()
	_save_progress()
	just_invited = before < 4 and gold_count(world_id) >= 4 and world_id == desert_seed


func _medal_key(world_id: int, race_name: String) -> String:
	return "%d|%s" % [world_id, race_name]


func _save_medals() -> void:
	var cf := ConfigFile.new()
	for key in medals.keys():
		cf.set_value("medals", str(key), int(medals[key]))
	cf.save("user://medals.cfg")


func _load_medals() -> void:
	medals.clear()
	var cf := ConfigFile.new()
	if cf.load("user://medals.cfg") != OK:
		return
	if not cf.has_section("medals"):
		return
	for key in cf.get_section_keys("medals"):
		medals[key] = int(cf.get_value("medals", key, 0))


func planet_title() -> String:
	if planet == "ice":
		return "FROST REACH"
	return "VERMILION WASTES"


func set_planet(id: String) -> void:
	if id != "desert" and id != "ice":
		return
	planet = id
	if planet == "ice":
		if ice_seed < 1:
			var base := desert_seed if desert_seed > 0 else world_seed
			ice_seed = (base * 17 + 91) % 999983
			if ice_seed < 1:
				ice_seed = 3
		world_seed = ice_seed
	else:
		if desert_seed < 1:
			desert_seed = world_seed if world_seed > 0 else 1
		world_seed = desert_seed
	_save_progress()


func _save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "planet", planet)
	cf.set_value("progress", "desert_seed", desert_seed)
	cf.set_value("progress", "ice_seed", ice_seed)
	cf.set_value("progress", "ice_unlocked", ice_unlocked)
	cf.set_value("progress", "world_seed", world_seed)
	cf.save("user://progress.cfg")


func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://progress.cfg") != OK:
		return
	planet = str(cf.get_value("progress", "planet", "desert"))
	if planet != "ice":
		planet = "desert"
	desert_seed = int(cf.get_value("progress", "desert_seed", 0))
	ice_seed = int(cf.get_value("progress", "ice_seed", 0))
	ice_unlocked = bool(cf.get_value("progress", "ice_unlocked", false))
	world_seed = int(cf.get_value("progress", "world_seed", 0))
	if desert_seed < 1 and world_seed > 0 and planet == "desert":
		desert_seed = world_seed


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
