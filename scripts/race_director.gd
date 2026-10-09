class_name RaceDirector
extends RefCounted

var active := false
var started := false
var finished := false
var just_finished := false
var countdown := 0.0
var go_time := 0.0
var elapsed := 0.0
var race: Dictionary = {}
var race_index := -1
var racers: Array[HoverCar] = []
var player: HoverCar
var order: Array[HoverCar] = []
var world
var _beeped := 4


func begin(host: Node, index: int, race_def: Dictionary, pilot: HoverCar, bots: Array[HoverCar]) -> void:
	world = host
	race_index = index
	race = race_def
	player = pilot
	racers.clear()
	racers.append(pilot)
	for bot in bots:
		racers.append(bot)
	active = true
	started = false
	finished = false
	just_finished = false
	countdown = 3.2
	go_time = 0.0
	elapsed = 0.0
	_beeped = 4
	order = racers.duplicate()
	for car in racers:
		car.cp_index = 1
		car.lap = 0
		car.finished = false
		car.finish_time = -1.0
		car.offtrack = 0.0
		car.route_hint = 0
		car.wrong_way = false
		car.controls_enabled = false


func tick(dt: float) -> void:
	if not active:
		return
	if not started:
		countdown -= dt
		var sec := ceili(countdown)
		if sec < _beeped and sec > 0:
			_beeped = sec
			Sfx.beep(world, 480.0 + float(3 - sec) * 70.0, 0.1, -10.0)
		if countdown <= 0.0:
			started = true
			go_time = 0.9
			_beeped = 0
			Sfx.beep(world, 880.0, 0.2, -6.0)
			for car in racers:
				if not car.finished:
					car.controls_enabled = true
		_refresh_order()
		return
	elapsed += dt
	go_time = maxf(go_time - dt, 0.0)
	_pass_gates()
	_watch_track(dt)
	_refresh_order()
	if player.finished and not finished:
		finished = true
		just_finished = true
		Sfx.beep(world, 640.0, 0.16, -8.0)
		Sfx.beep(world, 880.0, 0.22, -8.0)
		for car in racers:
			car.controls_enabled = false
			if not car.finished:
				car.finished = false


func player_place() -> int:
	for i in order.size():
		if order[i] == player:
			return i + 1
	return 1


func next_gate_position() -> Vector3:
	if race.is_empty():
		return Vector3.ZERO
	var cps: PackedVector3Array = race.checkpoints
	var idx := clampi(player.cp_index, 0, cps.size() - 1)
	return cps[idx]


func _pass_gates() -> void:
	var cps: PackedVector3Array = race.checkpoints
	var n := cps.size()
	var circuit := str(race.type) == "circuit"
	for car in racers:
		if car.finished:
			continue
		var idx := car.cp_index
		if idx < 0 or idx >= n:
			idx = 0
		if car.global_position.distance_to(cps[idx]) > 24.0:
			var to := cps[idx] - car.global_position
			to.y = 0.0
			var fwd := Util.forward_from_yaw(car.yaw)
			car.wrong_way = to.length() > 8.0 and fwd.dot(to.normalized()) < -0.35 and car.speed_mps() > 14.0
			continue
		car.wrong_way = false
		if circuit and idx == 0:
			car.lap += 1
			if car.lap >= int(race.laps):
				_finish(car)
				continue
			car.cp_index = 1
		elif not circuit and idx == n - 1:
			_finish(car)
		else:
			car.cp_index = idx + 1
			if circuit and car.cp_index >= n:
				car.cp_index = 0
		if car == player:
			Sfx.beep(world, 760.0, 0.05, -16.0)


func _finish(car: HoverCar) -> void:
	car.finished = true
	car.finish_time = elapsed
	car.controls_enabled = false
	car.velocity *= 0.4
	if car == player:
		GameState.remember_time(GameState.world_seed, str(race.name), elapsed)


func _watch_track(dt: float) -> void:
	var pts: PackedVector3Array = race.points
	var count := pts.size()
	if count < 2:
		return
	var circular := str(race.type) == "circuit" or pts[0].distance_to(pts[count - 1]) < 4.0
	if circular and pts[0].distance_to(pts[count - 1]) < 4.0:
		count -= 1
	for car in racers:
		if car.finished:
			continue
		var flat := Vector2(car.global_position.x, car.global_position.z)
		var hint := clampi(car.route_hint, 0, count - 1)
		var found := _nearest_track_index(pts, count, circular, flat, hint, 80)
		if flat.distance_to(Vector2(pts[found].x, pts[found].z)) > 36.0:
			found = _nearest_track_index(pts, count, circular, flat, 0, count)
		car.route_hint = found
		var along := flat.distance_to(Vector2(pts[found].x, pts[found].z))
		var on_road: bool = world.roads.on_roadway(flat.x, flat.y)
		if along > 56.0 and not on_road:
			car.offtrack += dt
		else:
			car.offtrack = 0.0
		if car.offtrack > 4.0:
			car.offtrack = 0.0
			respawn(car)


func _nearest_track_index(pts: PackedVector3Array, count: int, circular: bool, flat: Vector2, hint: int, window: int) -> int:
	var best := 100000.0
	var found := clampi(hint, 0, count - 1)
	var span := window if window < count else count
	var start := -span if window < count else 0
	for step in range(start, span + 1):
		var i := hint + step
		if circular:
			i = posmod(i, count)
		elif i < 0 or i >= count:
			continue
		var d := flat.distance_to(Vector2(pts[i].x, pts[i].z))
		if d < best:
			best = d
			found = i
	return found


func respawn(car: HoverCar) -> void:
	var cps: PackedVector3Array = race.checkpoints
	if cps.is_empty():
		return
	var idx := clampi(car.cp_index, 0, cps.size() - 1)
	var prev := maxi(idx - 1, 0)
	if str(race.type) == "circuit" and idx == 0:
		prev = cps.size() - 1
	var pos := cps[prev]
	var aim := cps[idx] - pos
	if aim.length_squared() < 1.0:
		aim = race.start_dir
	world.place_car(car, pos, aim, 20.0)
	car.offtrack = 0.0
	var pts: PackedVector3Array = race.points
	if pts.size() > 1:
		var count := pts.size()
		var circular := str(race.type) == "circuit"
		if pts[0].distance_to(pts[count - 1]) < 4.0:
			count -= 1
			circular = true
		car.route_hint = _nearest_track_index(pts, count, circular, Vector2(pos.x, pos.z), 0, count)


func _refresh_order() -> void:
	order = racers.duplicate()
	order.sort_custom(func(a: HoverCar, b: HoverCar) -> bool:
		return _progress(a) > _progress(b)
	)


func _progress(car: HoverCar) -> float:
	if car.finished:
		return 1000000.0 - car.finish_time
	var length := float(race.length)
	var cps: PackedVector3Array = race.checkpoints
	var cp_dist: PackedFloat32Array = race.checkpoint_dist
	var n := cps.size()
	var idx := clampi(car.cp_index, 0, n - 1)
	var prev_d := 0.0
	var next_d := 0.0
	if str(race.type) == "circuit" and idx == 0:
		next_d = length
		prev_d = float(cp_dist[n - 1]) if n > 1 else 0.0
	else:
		next_d = float(cp_dist[idx])
		prev_d = float(cp_dist[maxi(idx - 1, 0)])
	var seg := maxf(next_d - prev_d, 1.0)
	var gate := cps[idx]
	var remain := Vector2(car.global_position.x - gate.x, car.global_position.z - gate.z).length()
	var frac := 1.0 - clampf(remain / seg, 0.0, 1.0)
	return float(car.lap) * length + prev_d + frac * seg
