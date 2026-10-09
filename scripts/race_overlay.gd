extends Control

var host: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if host == null or host.world == null or host.world.player == null:
		return
	if name == "Minimap":
		_draw_map()
	elif name == "WorldMap":
		_draw_world()
	elif name == "TrackPreview":
		_draw_preview()
	else:
		_draw_pointer()


func _draw_map() -> void:
	var world = host.world
	if world.race.active and world.race.started:
		var course: Dictionary = world.race.race
		_draw_course(course, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.85, 1.0, 0.8), false, 1.0)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.05, 0.78))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.85, 1.0, 0.8), false, 1.0)
	var player: Vector3 = world.player.global_position
	var ppm := size.x / 300.0
	var center := size * 0.5
	for edge in world.roads.edges:
		var pts: PackedVector3Array = edge.points
		var col := Color(0.72, 0.48, 0.24, 0.95) if bool(edge.shortcut) else Color(0.55, 0.36, 0.18, 0.92)
		var prev := Vector2.INF
		for i in range(0, pts.size(), 4):
			var mp := _map_point(pts[i], player, center, ppm)
			if prev != Vector2.INF and _on_map(prev) and _on_map(mp):
				draw_line(prev, mp, col, 1.6, true)
			prev = mp
	for i in world.beacon_positions.size():
		var bp: Vector3 = world.beacon_positions[i]
		var mp2 := _map_point(bp, player, center, ppm)
		if not _on_map(mp2):
			continue
		var c: Color = world.BOT_COLORS[i % world.BOT_COLORS.size()]
		draw_rect(Rect2(mp2 - Vector2(3, 3), Vector2(6, 6)), c)
	for bot in world.bots:
		if not is_instance_valid(bot):
			continue
		var mb := _map_point(bot.global_position, player, center, ppm)
		if _on_map(mb):
			draw_circle(mb, 2.5, bot.accent)
	var fwd := Util.forward_from_yaw(world.player.yaw)
	var right := Util.right_from_yaw(world.player.yaw)
	var tip := center + Vector2(fwd.x, fwd.z) * 9.0
	var a := center - Vector2(fwd.x, fwd.z) * 5.0 + Vector2(right.x, right.z) * 5.0
	var b := center - Vector2(fwd.x, fwd.z) * 5.0 - Vector2(right.x, right.z) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(1, 1, 1))
	for station in world.fix_stations:
		var ms := _map_point(station, player, center, ppm)
		if _on_map(ms):
			draw_circle(ms, 3.2, Color(0.3, 0.95, 0.48))
	var port: Vector3 = world.port_position
	var mp_port := _map_point(port, player, center, ppm)
	if _on_map(mp_port):
		draw_rect(Rect2(mp_port - Vector2(3, 3), Vector2(6, 6)), Color(0.4, 0.95, 1.0))


func _draw_world() -> void:
	var world = host.world
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.06, 0.88))
	var half := TerrainField.HALF
	var side := minf(size.x, size.y) - 24.0
	var origin := (size - Vector2(side, side)) * 0.5
	var scale := side / (half * 2.0)
	if host.map_texture:
		draw_texture_rect(host.map_texture, Rect2(origin, Vector2(side, side)), false)
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.45, 0.9, 1.0, 0.85), false, 2.0)
	for edge in world.roads.edges:
		var pts: PackedVector3Array = edge.points
		var col := Color(0.72, 0.48, 0.24, 0.95) if bool(edge.shortcut) else Color(0.58, 0.38, 0.2, 0.92)
		var prev := Vector2.INF
		for i in range(0, pts.size(), 3):
			var mp := _world_point(pts[i], origin, scale, half)
			if prev != Vector2.INF:
				draw_line(prev, mp, col, 2.0, true)
			prev = mp
	for i in world.beacon_positions.size():
		var bp: Vector3 = world.beacon_positions[i]
		draw_circle(_world_point(bp, origin, scale, half), 4.0, world.BOT_COLORS[i % world.BOT_COLORS.size()])
	for station in world.fix_stations:
		draw_circle(_world_point(station, origin, scale, half), 3.4, Color(0.3, 0.95, 0.48))
	var port := _world_point(world.port_position, origin, scale, half)
	draw_rect(Rect2(port - Vector2(5, 5), Vector2(10, 10)), Color(0.5, 0.95, 1.0))
	for bot in world.bots:
		if is_instance_valid(bot):
			draw_circle(_world_point(bot.global_position, origin, scale, half), 3.5, bot.accent)
	var player: Vector3 = world.player.global_position
	var pc := _world_point(player, origin, scale, half)
	var fwd := Util.forward_from_yaw(world.player.yaw)
	var right := Util.right_from_yaw(world.player.yaw)
	var tip := pc + Vector2(fwd.x, -fwd.z) * 12.0
	var pa := pc - Vector2(fwd.x, -fwd.z) * 7.0 + Vector2(right.x, -right.z) * 6.0
	var pb := pc - Vector2(fwd.x, -fwd.z) * 7.0 - Vector2(right.x, -right.z) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, pa, pb]), Color(1, 1, 1))


func _draw_preview() -> void:
	var def := _preview_race()
	if def.is_empty():
		return
	var world = host.world
	_draw_course(def, bool(world.race.active))


func _preview_race() -> Dictionary:
	var world = host.world
	if world.race.active and not world.race.started:
		var live: Dictionary = world.race.race
		return live
	if not world.race.active and int(world.near_race) >= 0:
		var races: Array = world.roads.races
		var idx := int(world.near_race)
		if idx < races.size():
			var picked: Dictionary = races[idx]
			return picked
	return {}


func _draw_course(def: Dictionary, show_racers: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.035, 0.05, 0.9))
	var pts: PackedVector3Array = def.points
	if pts.size() < 2 or size.x < 8.0 or size.y < 8.0:
		return
	var min_x := pts[0].x
	var max_x := pts[0].x
	var min_z := pts[0].z
	var max_z := pts[0].z
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	var span_x := maxf(max_x - min_x, 20.0)
	var span_z := maxf(max_z - min_z, 20.0)
	var pad := 14.0
	var inner := Vector2(size.x - pad * 2.0, size.y - pad * 2.0)
	var scale := minf(inner.x / span_x, inner.y / span_z)
	var origin := (size - Vector2(span_x, span_z) * scale) * 0.5
	var step := 1 if pts.size() < 500 else 2
	var width := clampf(size.x / 70.0, 2.4, 5.0)
	var prev := Vector2.INF
	for i in range(0, pts.size(), step):
		var mp := origin + Vector2((pts[i].x - min_x) * scale, (max_z - pts[i].z) * scale)
		if prev != Vector2.INF:
			draw_line(prev, mp, Color(0.28, 0.18, 0.1, 0.95), width + 3.0, true)
			draw_line(prev, mp, Color(0.62, 0.42, 0.22, 0.95), width, true)
		prev = mp
	var last := origin + Vector2((pts[pts.size() - 1].x - min_x) * scale, (max_z - pts[pts.size() - 1].z) * scale)
	if prev != Vector2.INF and prev.distance_to(last) > 1.0:
		draw_line(prev, last, Color(0.62, 0.42, 0.22, 0.95), width, true)
	var start := origin + Vector2((pts[0].x - min_x) * scale, (max_z - pts[0].z) * scale)
	if str(def.type) == "circuit":
		draw_line(last, start, Color(0.62, 0.42, 0.22, 0.95), width, true)
	var cps: PackedVector3Array = def.checkpoints
	var next_i := -1
	if show_racers:
		next_i = int(host.world.player.cp_index)
	for i in cps.size():
		var cp := origin + Vector2((cps[i].x - min_x) * scale, (max_z - cps[i].z) * scale)
		if i == next_i:
			draw_circle(cp, 5.5, Color(1.0, 0.78, 0.28))
		else:
			draw_circle(cp, 2.6, Color(0.55, 0.95, 1.0, 0.75))
	var world_map = host.world
	for station in world_map.fix_stations:
		if station.x < min_x - 40.0 or station.x > max_x + 40.0 or station.z < min_z - 40.0 or station.z > max_z + 40.0:
			continue
		var fs := origin + Vector2((station.x - min_x) * scale, (max_z - station.z) * scale)
		draw_circle(fs, 4.0, Color(0.3, 0.95, 0.48))
	draw_rect(Rect2(start - Vector2(4, 4), Vector2(8, 8)), Color(0.95, 0.98, 1.0))
	if str(def.type) != "circuit":
		draw_rect(Rect2(last - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.55, 0.2))
	if not show_racers:
		return
	var world = host.world
	for bot in world.bots:
		if not is_instance_valid(bot):
			continue
		var bp: Vector3 = bot.global_position
		var mb := origin + Vector2((bp.x - min_x) * scale, (max_z - bp.z) * scale)
		draw_circle(mb, 3.2, bot.accent)
	var player: Vector3 = world.player.global_position
	var pc := origin + Vector2((player.x - min_x) * scale, (max_z - player.z) * scale)
	var fwd := Util.forward_from_yaw(world.player.yaw)
	var right := Util.right_from_yaw(world.player.yaw)
	var tip := pc + Vector2(fwd.x, -fwd.z) * 9.0
	var a := pc - Vector2(fwd.x, -fwd.z) * 5.0 + Vector2(right.x, -right.z) * 5.0
	var b := pc - Vector2(fwd.x, -fwd.z) * 5.0 - Vector2(right.x, -right.z) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(1, 1, 1))


func _world_point(p: Vector3, origin: Vector2, scale: float, half: float) -> Vector2:
	return origin + Vector2(p.x + half, half - p.z) * scale


func _draw_pointer() -> void:
	var world = host.world
	var target := Vector3.ZERO
	var active := false
	if world.race.active and world.race.started and not world.player.finished:
		target = world.race.next_gate_position()
		active = true
	elif world.waypoint >= 0 and world.waypoint < world.beacon_positions.size() and not world.race.active:
		target = world.beacon_positions[world.waypoint]
		active = true
	if not active or world.cam == null:
		return
	var cam: Camera3D = world.cam
	var screen := cam.unproject_position(target)
	var behind := cam.is_position_behind(target)
	var center := size * 0.5
	if behind:
		screen = center - (screen - center)
	var margin := 42.0
	var on_screen := not behind and screen.x > margin and screen.y > margin and screen.x < size.x - margin and screen.y < size.y - margin
	var col := Color(0.35, 1.0, 1.0)
	if on_screen:
		_diamond(screen, col)
		return
	var dir := screen - center
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	var half := size * 0.5 - Vector2(margin, margin)
	var scale := 1.0
	if absf(dir.x) > 0.001:
		scale = minf(scale, half.x / absf(dir.x))
	if absf(dir.y) > 0.001:
		scale = minf(scale, half.y / absf(dir.y))
	_diamond(center + dir.normalized() * dir.length() * scale, Color(1.0, 0.7, 0.25))


func _diamond(p: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -10),
		p + Vector2(8, 0),
		p + Vector2(0, 10),
		p + Vector2(-8, 0),
	])
	draw_colored_polygon(pts, col)


func _map_point(p: Vector3, player: Vector3, center: Vector2, ppm: float) -> Vector2:
	return center + Vector2(p.x - player.x, p.z - player.z) * ppm


func _on_map(p: Vector2) -> bool:
	return p.x > -20.0 and p.y > -20.0 and p.x < size.x + 20.0 and p.y < size.y + 20.0
