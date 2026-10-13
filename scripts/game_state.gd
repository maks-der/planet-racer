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
var grass_seed: int = 0
var planet := "desert"
var ice_unlocked := false
var grass_unlocked := false
var preset_index: int = 0
var primary := Color("14e6ff")
var accent := Color("ff8a1e")
var best_times: Dictionary = {}
var medals: Dictionary = {}
var just_invited := false
var money := 1500
var owned: Array[bool] = [true, false, false, false]
var part_levels: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var pending_bet := 0
var purse_note := ""

const CAR_COST: Array[int] = [0, 8000, 8500, 10000]
const PARTS: PackedStringArray = ["ENGINE", "GRIP", "BOOST", "AIR"]
const PART_COST: Array[int] = [1000, 2500, 5000]
const BET_AMOUNTS: Array[int] = [250, 500, 1000, 2500]
const BET_MULT := 3


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
	grass_seed = 0
	world_seed = desert_seed
	planet = "desert"
	best_times.clear()
	_save_progress()


func preset() -> Dictionary:
	return PRESETS[clampi(preset_index, 0, PRESETS.size() - 1)]


func tuned_stats() -> Dictionary:
	var stats: Dictionary = preset().duplicate()
	var engine := _part(preset_index, 0)
	var grip := _part(preset_index, 1)
	var boost := _part(preset_index, 2)
	var air := _part(preset_index, 3)
	stats.accel = float(stats.accel) + float(engine) * 2.2
	stats.grip = float(stats.grip) + float(grip) * 1.5
	stats.drift_grip = float(stats.drift_grip) + float(grip) * 0.18
	stats.boost_regen = float(stats.boost_regen) + float(boost) * 5.0
	stats.boost_drain = maxf(14.0, float(stats.boost_drain) - float(boost) * 3.0)
	stats.jump = float(stats.jump) + float(air) * 1.6
	stats.air = float(stats.air) + float(air) * 0.14
	return stats


func owns_car(index: int) -> bool:
	return index >= 0 and index < owned.size() and owned[index]


func _part(car_i: int, part_i: int) -> int:
	var slot := car_i * 4 + part_i
	if slot < 0 or slot >= part_levels.size():
		return 0
	return clampi(part_levels[slot], 0, 3)


func next_part_cost(car_i: int, part_i: int) -> int:
	var level := _part(car_i, part_i)
	if level >= PART_COST.size():
		return -1
	return PART_COST[level]


func buy_car(index: int) -> bool:
	if index < 0 or index >= PRESETS.size():
		return false
	if owns_car(index):
		set_preset(index)
		return true
	var cost := CAR_COST[index]
	if money < cost:
		return false
	money -= cost
	owned[index] = true
	set_preset(index)
	save_car()
	return true


func buy_part(car_i: int, part_i: int) -> bool:
	if not owns_car(car_i):
		return false
	var cost := next_part_cost(car_i, part_i)
	if cost < 0 or money < cost:
		return false
	money -= cost
	var slot := car_i * 4 + part_i
	part_levels[slot] = _part(car_i, part_i) + 1
	save_car()
	return true


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	save_car()


func place_bet(amount: int) -> bool:
	if amount < 0 or amount > money:
		return false
	money -= amount
	pending_bet = amount
	save_car()
	return true


func settle_race(place: int) -> void:
	var prize := 0
	if place == 1:
		prize = 3500
	elif place == 2:
		prize = 1800
	elif place == 3:
		prize = 900
	money += prize
	var lines: PackedStringArray = PackedStringArray()
	if prize > 0:
		lines.append("PRIZE  $%d" % prize)
	if pending_bet > 0:
		if place == 1:
			var pay := pending_bet * BET_MULT
			money += pay
			lines.append("BET WON  $%d" % pay)
		else:
			lines.append("BET LOST  $%d" % pending_bet)
		pending_bet = 0
	lines.append("BALANCE  $%d" % money)
	purse_note = "\n".join(lines)
	save_car()


func forfeit_bet() -> void:
	if pending_bet <= 0:
		return
	pending_bet = 0
	save_car()


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
	if ice_seed > 0 and gold_count(ice_seed) >= 4:
		grass_unlocked = true
	_save_medals()
	_save_progress()
	var desert_invite := before < 4 and gold_count(world_id) >= 4 and world_id == desert_seed
	var ice_invite := before < 4 and gold_count(world_id) >= 4 and world_id == ice_seed
	just_invited = desert_invite or ice_invite


func set_medal(world_id: int, race_name: String, rank: int) -> void:
	var had_ice := ice_unlocked
	var had_grass := grass_unlocked
	var key := _medal_key(world_id, race_name)
	var clamped := clampi(rank, 0, 3)
	if clamped == 0:
		medals.erase(key)
	else:
		medals[key] = clamped
	if desert_seed > 0 and gold_count(desert_seed) >= 4:
		ice_unlocked = true
	if ice_seed > 0 and gold_count(ice_seed) >= 4:
		grass_unlocked = true
	just_invited = (not had_ice and ice_unlocked) or (not had_grass and grass_unlocked)
	_save_medals()
	_save_progress()


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
	if planet == "grass":
		return "EMERALD STEPPE"
	return "VERMILION WASTES"


func set_planet(id: String) -> void:
	if id != "desert" and id != "ice" and id != "grass":
		return
	planet = id
	if planet == "ice":
		if ice_seed < 1:
			var base := desert_seed if desert_seed > 0 else world_seed
			ice_seed = (base * 17 + 91) % 999983
			if ice_seed < 1:
				ice_seed = 3
		world_seed = ice_seed
	elif planet == "grass":
		if grass_seed < 1:
			var base := ice_seed if ice_seed > 0 else desert_seed
			if base < 1:
				base = world_seed if world_seed > 0 else 1
			grass_seed = (base * 29 + 137) % 999983
			if grass_seed < 1:
				grass_seed = 5
		world_seed = grass_seed
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
	cf.set_value("progress", "grass_seed", grass_seed)
	cf.set_value("progress", "ice_unlocked", ice_unlocked)
	cf.set_value("progress", "grass_unlocked", grass_unlocked)
	cf.set_value("progress", "world_seed", world_seed)
	cf.save("user://progress.cfg")


func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://progress.cfg") != OK:
		return
	planet = str(cf.get_value("progress", "planet", "desert"))
	if planet != "ice" and planet != "grass":
		planet = "desert"
	desert_seed = int(cf.get_value("progress", "desert_seed", 0))
	ice_seed = int(cf.get_value("progress", "ice_seed", 0))
	grass_seed = int(cf.get_value("progress", "grass_seed", 0))
	ice_unlocked = bool(cf.get_value("progress", "ice_unlocked", false))
	grass_unlocked = bool(cf.get_value("progress", "grass_unlocked", false))
	world_seed = int(cf.get_value("progress", "world_seed", 0))
	if desert_seed < 1 and world_seed > 0 and planet == "desert":
		desert_seed = world_seed


func save_car() -> void:
	var cf := ConfigFile.new()
	cf.set_value("car", "preset", preset_index)
	cf.set_value("car", "primary", primary.to_html(false))
	cf.set_value("car", "accent", accent.to_html(false))
	cf.set_value("car", "money", money)
	var owned_bits: PackedStringArray = PackedStringArray()
	for flag in owned:
		owned_bits.append("1" if flag else "0")
	cf.set_value("car", "owned", ",".join(owned_bits))
	var part_bits: PackedStringArray = PackedStringArray()
	for level in part_levels:
		part_bits.append(str(level))
	cf.set_value("car", "parts", ",".join(part_bits))
	cf.save("user://car.cfg")


func _load_car() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://car.cfg") != OK:
		return
	preset_index = int(cf.get_value("car", "preset", 0))
	primary = Color.html(str(cf.get_value("car", "primary", "14e6ff")))
	accent = Color.html(str(cf.get_value("car", "accent", "ff8a1e")))
	money = maxi(0, int(cf.get_value("car", "money", money)))
	if cf.has_section_key("car", "owned"):
		var bits := str(cf.get_value("car", "owned", "1,0,0,0")).split(",", false)
		for i in owned.size():
			owned[i] = i < bits.size() and bits[i] == "1"
	if cf.has_section_key("car", "parts"):
		var bits := str(cf.get_value("car", "parts", "")).split(",", false)
		for i in part_levels.size():
			part_levels[i] = int(bits[i]) if i < bits.size() else 0
	preset_index = clampi(preset_index, 0, PRESETS.size() - 1)
	if not owns_car(preset_index):
		owned[preset_index] = true
	owned[0] = true
