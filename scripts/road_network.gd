class_name RoadNetwork
extends RefCounted

const KIND_ROAD := 0
const KIND_BRIDGE := 1
const KIND_TUNNEL := 2
const SPACING := 5.0

var terrain: TerrainField
var node_xz := PackedVector2Array()
var node_y := PackedFloat32Array()
var edges: Array[Dictionary] = []
var races: Array[Dictionary] = []
var outer_ids: Array[int] = []
var inner_ids: Array[int] = []
var tunnel_points := 0
var bridge_points := 0
var shortcut_edges := 0

var _adj: Array = []
var _hash: Dictionary = {}
var _tracks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func generate(field: TerrainField, seed: int) -> void:
	terrain = field
	_rng.seed = seed + 501
	edges.clear()
	races.clear()
	_tracks.clear()
	node_xz = PackedVector2Array()
	node_y = PackedFloat32Array()
	outer_ids.clear()
	inner_ids.clear()
	_hash.clear()
	tunnel_points = 0
	bridge_points = 0
	shortcut_edges = 0
	_lay_tracks()
	_separate_tunnels()
	_carve_corridors()
	_build_hash()
	_build_races()


func sample(x: float, z: float) -> Dictionary:
	var ground_h := terrain.height_at(x, z)
	var ground_n := terrain.normal_at(x, z)
	var best: Dictionary = _closest_road(x, z)
	if best.is_empty():
		return _surface(ground_h, ground_n, false, KIND_ROAD)
	var half: float = float(best.width) * 0.5
	var gap: float = float(best.y) - ground_h
	if gap > 2.8:
		if float(best.dist) <= half:
			return _surface(float(best.y), best.normal, true, int(best.kind))
		return _surface(ground_h, ground_n, false, KIND_ROAD)
	var blend := 1.0 - Util.smoothstep(half * 0.3, half + 2.4, float(best.dist))
	if blend <= 0.0:
		return _surface(ground_h, ground_n, false, KIND_ROAD)
	var h := lerpf(ground_h, float(best.y), blend)
	var n: Vector3 = ground_n.lerp(best.normal, blend).normalized()
	return _surface(h, n, blend > 0.62, int(best.kind))


func distance_to_road(x: float, z: float) -> float:
	var best := _closest_road(x, z)
	if best.is_empty():
		return 9999.0
	return float(best.dist)


func on_roadway(x: float, z: float) -> bool:
	var hit := _closest_road(x, z)
	if hit.is_empty():
		return terrain.road_factor(x, z) > 0.2
	if float(hit.dist) < float(hit.width) * 0.47:
		return true
	return terrain.road_factor(x, z) > 0.2


func point_at(points: PackedVector3Array, dists: PackedFloat32Array, dist: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	dist = clampf(dist, 0.0, dists[dists.size() - 1])
	var lo := 0
	var hi := dists.size() - 1
	while lo < hi - 1:
		var mid := (lo + hi) >> 1
		if dists[mid] < dist:
			lo = mid
		else:
			hi = mid
	var span := dists[hi] - dists[lo]
	var u := 0.0 if span < 0.001 else (dist - dists[lo]) / span
	return points[lo].lerp(points[hi], u)


func _surface(h: float, n: Vector3, on_road: bool, kind: int) -> Dictionary:
	return {"height": h, "normal": n, "on_road": on_road, "kind": kind}


func _clamp_map(p: Vector2) -> Vector2:
	var limit := TerrainField.HALF * 0.76
	return Vector2(clampf(p.x, -limit, limit), clampf(p.y, -limit, limit))


func _add_node(p: Vector2) -> int:
	var placed := _clamp_map(p)
	node_xz.append(placed)
	node_y.append(terrain.height_at(placed.x, placed.y) + 0.55)
	return node_xz.size() - 1


func _lay_tracks() -> void:
	_tracks.clear()
	for slot in 8:
		var control := _article_polygon(slot)
		_tracks.append(_commit_loop(control))
	_link_tracks()


func _article_polygon(slot: int) -> PackedVector2Array:
	var ang := TAU * float(slot) / 8.0 + _rng.randf_range(-0.22, 0.22)
	var ring := 540.0 + _rng.randf_range(-40.0, 50.0)
	var center := Vector2(cos(ang), sin(ang)) * ring
	var half_x := lerpf(250.0, 390.0, float(slot) / 7.0) * _rng.randf_range(0.92, 1.06)
	var half_z := half_x * _rng.randf_range(0.68, 0.9)
	var difficulty := lerpf(0.45, 7.0, float(slot) / 7.0)
	var span := maxf(half_x, half_z) * 2.0
	var apart := maxf(88.0, span * 0.07)
	var max_disp := span * 0.16
	for attempt in 8:
		var shaped := _shape_polygon(center, half_x, half_z, difficulty, apart, max_disp, attempt < 6)
		if shaped.size() < 6 or _closed_crosses(shaped):
			difficulty = minf(difficulty * 1.65, 16.0)
			max_disp *= 0.82
			continue
		var spline := _spline_closed(shaped)
		if _path_length(spline) < 900.0 or _closed_crosses(_resample(spline, 18.0)):
			difficulty = minf(difficulty * 1.65, 16.0)
			max_disp *= 0.82
			continue
		return shaped
	return _oval_fallback(center, half_x, half_z, apart)


func _shape_polygon(center: Vector2, half_x: float, half_z: float, difficulty: float, apart: float, max_disp: float, displace: bool) -> PackedVector2Array:
	var cloud := PackedVector2Array()
	var count := _rng.randi_range(12, 18)
	for _i in count:
		var p := center + Vector2(_rng.randf_range(-half_x, half_x), _rng.randf_range(-half_z, half_z))
		cloud.append(_clamp_map(p))
	var hull := _convex_hull(cloud)
	if hull.size() < 4:
		return PackedVector2Array()
	for _k in 3:
		_push_apart(hull, apart)
	var shaped := hull
	if displace:
		shaped = _displace(hull, difficulty, max_disp)
		for _k in 3:
			_push_apart(shaped, apart)
	for _k in 10:
		_fix_angles(shaped)
		_push_apart(shaped, apart)
	return shaped


func _oval_fallback(center: Vector2, half_x: float, half_z: float, apart: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(_clamp_map(center + Vector2(cos(a) * half_x * 0.86, sin(a) * half_z * 0.86)))
	for _k in 6:
		_fix_angles(pts)
		_push_apart(pts, apart)
	return pts


func _convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	var src: Array[Vector2] = []
	for p in points:
		src.append(p)
	src.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if absf(a.x - b.x) > 0.01:
			return a.x < b.x
		return a.y < b.y
	)
	var unique: Array[Vector2] = []
	for p in src:
		if unique.is_empty() or unique[unique.size() - 1].distance_squared_to(p) > 0.25:
			unique.append(p)
	if unique.size() < 3:
		return PackedVector2Array()
	var lower: Array[Vector2] = []
	for p in unique:
		while lower.size() >= 2 and _turn_cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)
	var upper: Array[Vector2] = []
	for i in range(unique.size() - 1, -1, -1):
		var q: Vector2 = unique[i]
		while upper.size() >= 2 and _turn_cross(upper[upper.size() - 2], upper[upper.size() - 1], q) <= 0.0:
			upper.pop_back()
		upper.append(q)
	if not lower.is_empty():
		lower.pop_back()
	if not upper.is_empty():
		upper.pop_back()
	var hull := PackedVector2Array()
	for p in lower:
		hull.append(p)
	for p in upper:
		hull.append(p)
	return hull


func _turn_cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


func _push_apart(data: PackedVector2Array, dst: float) -> void:
	var dst2 := dst * dst
	var n := data.size()
	for i in n:
		for j in range(i + 1, n):
			var delta := data[j] - data[i]
			var hl2 := delta.length_squared()
			if hl2 < 0.01 or hl2 >= dst2:
				continue
			var hl := sqrt(hl2)
			var shift := delta / hl * (dst - hl)
			data[i] = _clamp_map(data[i] - shift)
			data[j] = _clamp_map(data[j] + shift)


func _displace(data: PackedVector2Array, difficulty: float, max_disp: float) -> PackedVector2Array:
	var n := data.size()
	var out := PackedVector2Array()
	for i in n:
		var disp_len := pow(_rng.randf(), difficulty) * max_disp
		var mid := (data[i] + data[(i + 1) % n]) * 0.5
		mid += Vector2.from_angle(_rng.randf() * TAU) * disp_len
		out.append(data[i])
		out.append(_clamp_map(mid))
	return out


func _fix_angles(data: PackedVector2Array) -> void:
	var n := data.size()
	if n < 3:
		return
	var limit := deg_to_rad(100.0)
	for i in n:
		var previous := (i - 1 + n) % n
		var next := (i + 1) % n
		var incoming := data[i] - data[previous]
		var pl := incoming.length()
		if pl < 0.01:
			continue
		incoming /= pl
		var outgoing := data[next] - data[i]
		var nl := outgoing.length()
		if nl < 0.01:
			continue
		outgoing /= nl
		var a := atan2(incoming.x * outgoing.y - incoming.y * outgoing.x, incoming.x * outgoing.x + incoming.y * outgoing.y)
		if absf(a) <= limit:
			continue
		var diff := limit * signf(a) - a
		var c := cos(diff)
		var s := sin(diff)
		var turned := Vector2(outgoing.x * c - outgoing.y * s, outgoing.x * s + outgoing.y * c) * nl
		data[next] = _clamp_map(data[i] + turned)


func _spline_closed(control: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in control.size():
		var seg := _catmull_segment(control, i)
		var start_i := 0 if out.is_empty() else 1
		for s in range(start_i, seg.size()):
			out.append(seg[s])
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) > 1.0:
		out.append(out[0])
	return out


func _catmull_segment(control: PackedVector2Array, index: int) -> PackedVector2Array:
	var n := control.size()
	var p0: Vector2 = control[(index - 1 + n) % n]
	var p1: Vector2 = control[index]
	var p2: Vector2 = control[(index + 1) % n]
	var p3: Vector2 = control[(index + 2) % n]
	var raw := PackedVector2Array()
	raw.append(p1)
	var t := 0.0
	var guard := 0
	while t < 1.0 and guard < 400:
		guard += 1
		var speed := maxf(_catmull_tangent(p0, p1, p2, p3, t).length(), 1.0)
		t += SPACING / speed
		if t >= 1.0:
			break
		raw.append(_clamp_map(_catmull(p0, p1, p2, p3, t)))
	raw.append(p2)
	return _resample(raw, SPACING)


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _catmull_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var b := -p0 + p2
	var c := 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3
	var d := -p0 + 3.0 * p1 - 3.0 * p2 + p3
	return 0.5 * (b + 2.0 * c * t + 3.0 * d * t2)


func _commit_loop(control: PackedVector2Array) -> Dictionary:
	var node_ids: Array[int] = []
	for i in control.size():
		node_ids.append(_add_node(control[i]))
	var edge_ids: Array[int] = []
	var n := control.size()
	for i in n:
		var xz := _catmull_segment(control, i)
		edge_ids.append(_add_road(node_ids[i], node_ids[(i + 1) % n], xz))
	return {"nodes": node_ids, "edges": edge_ids}


func _link_tracks() -> void:
	var count := _tracks.size()
	var parent: Array[int] = []
	parent.resize(count)
	for i in count:
		parent[i] = i
	var pairs: Array[Dictionary] = []
	for i in count:
		for j in range(i + 1, count):
			pairs.append(_closest_nodes(i, j))
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.dist) < float(b.dist)
	)
	var added := 0
	for raw_pair in pairs:
		var pair: Dictionary = raw_pair
		var ia := int(pair.i)
		var ib := int(pair.j)
		var dist := float(pair.dist)
		var separated := _find_parent(parent, ia) != _find_parent(parent, ib)
		if dist < 56.0:
			if separated:
				_union_parent(parent, ia, ib)
			continue
		if dist > 900.0:
			continue
		if not separated and (dist > 320.0 or added >= 12):
			continue
		var xz := _link_curve(node_xz[int(pair.a)], node_xz[int(pair.b)])
		_add_road(int(pair.a), int(pair.b), xz)
		_union_parent(parent, ia, ib)
		added += 1


func _closest_nodes(i: int, j: int) -> Dictionary:
	var na: Array = _tracks[i].nodes
	var nb: Array = _tracks[j].nodes
	var best_d := 1000000.0
	var best_a := int(na[0])
	var best_b := int(nb[0])
	for raw_a in na:
		var pa: Vector2 = node_xz[int(raw_a)]
		for raw_b in nb:
			var d := pa.distance_to(node_xz[int(raw_b)])
			if d < best_d:
				best_d = d
				best_a = int(raw_a)
				best_b = int(raw_b)
	return {"i": i, "j": j, "a": best_a, "b": best_b, "dist": best_d}


func _find_parent(parent: Array[int], index: int) -> int:
	var cursor := index
	while parent[cursor] != cursor:
		parent[cursor] = parent[parent[cursor]]
		cursor = parent[cursor]
	return cursor


func _union_parent(parent: Array[int], a: int, b: int) -> void:
	var ra := _find_parent(parent, a)
	var rb := _find_parent(parent, b)
	if ra != rb:
		parent[rb] = ra


func _link_curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var chord := b - a
	var length := chord.length()
	var raw := PackedVector2Array()
	if length < 1.0:
		raw.append(a)
		raw.append(b)
		return raw
	var dir := chord / length
	var perp := Vector2(-dir.y, dir.x)
	if perp.dot((a + b) * 0.5) < 0.0:
		perp = -perp
	var amp := minf(32.0, length * 0.08)
	var steps := clampi(int(length / 16.0), 4, 48)
	for i in steps + 1:
		var t := float(i) / float(steps)
		raw.append(_clamp_map(a.lerp(b, t) + perp * sin(t * PI) * amp))
	raw[0] = a
	raw[raw.size() - 1] = b
	return _resample(raw, SPACING)


func _add_road(a: int, b: int, xz: PackedVector2Array) -> int:
	var profile: Dictionary = _profile(xz, node_y[a], node_y[b], false)
	var pts := PackedVector3Array()
	var kinds: PackedByteArray = profile.kinds
	var ys: PackedFloat32Array = profile.y
	for i in xz.size():
		pts.append(Vector3(xz[i].x, ys[i], xz[i].y))
	var length := 0.0
	var tunnels := 0
	var bridges := 0
	for i in pts.size():
		if i > 0:
			length += pts[i].distance_to(pts[i - 1])
		if kinds[i] == KIND_TUNNEL:
			tunnels += 1
		elif kinds[i] == KIND_BRIDGE:
			bridges += 1
	tunnel_points += tunnels
	bridge_points += bridges
	edges.append({
		"a": a,
		"b": b,
		"points": pts,
		"kinds": kinds,
		"shortcut": false,
		"width": 46.0,
		"length": length,
		"tunnels": tunnels,
		"bridges": bridges,
	})
	return edges.size() - 1


func _path_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


func _closed_crosses(pts: PackedVector2Array) -> bool:
	var n := pts.size()
	if n < 4:
		return false
	var last := n - 1
	if pts[0].distance_to(pts[last]) < 4.0:
		last -= 1
	var count := last + 1
	for i in count:
		var a := pts[i]
		var b := pts[(i + 1) % count]
		for j in range(i + 2, count):
			if i == 0 and j == count - 1:
				continue
			if _segments_cross(a, b, pts[j], pts[(j + 1) % count]):
				return true
	return false


func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var r := b - a
	var s := d - c
	var den := r.cross(s)
	if absf(den) < 0.0001:
		return false
	var q := c - a
	var t := q.cross(s) / den
	var u := q.cross(r) / den
	return t > 0.04 and t < 0.96 and u > 0.04 and u < 0.96



func _resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return pts
	out.append(pts[0])
	var acc := 0.0
	for i in range(1, pts.size()):
		var origin := pts[i - 1]
		var target := pts[i]
		var seg := origin.distance_to(target)
		if seg < 0.0001:
			continue
		var walked := 0.0
		while acc + (seg - walked) >= spacing:
			var need := spacing - acc
			walked += need
			out.append(origin.lerp(target, walked / seg))
			acc = 0.0
		acc += seg - walked
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > spacing * 0.3:
		out.append(pts[pts.size() - 1])
	else:
		out[out.size() - 1] = pts[pts.size() - 1]
	return out


func _profile(xz: PackedVector2Array, y0: float, y1: float, shortcut: bool) -> Dictionary:
	var n := xz.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	var total := 0.0
	dist[0] = 0.0
	for i in range(1, n):
		total += xz[i].distance_to(xz[i - 1])
		dist[i] = total
	if total < 0.1:
		total = 0.1
	var max_slope := 0.16 if shortcut else 0.085
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		raw[i] = terrain.height_at(xz[i].x, xz[i].y)
	var desired := PackedFloat32Array()
	desired.resize(n)
	for i in n:
		var t := dist[i] / total
		var chord := lerpf(y0, y1, t)
		var follow := sin(t * PI) * (0.94 if shortcut else 0.9)
		desired[i] = lerpf(chord, raw[i] + 0.35, follow)
	desired[0] = y0
	desired[n - 1] = y1
	var forward := desired.duplicate()
	for i in range(1, n):
		var cap := maxf(dist[i] - dist[i - 1], 0.25) * max_slope
		forward[i] = clampf(desired[i], forward[i - 1] - cap, forward[i - 1] + cap)
	var backward := desired.duplicate()
	backward[n - 1] = y1
	for i in range(n - 2, -1, -1):
		var cap2 := maxf(dist[i + 1] - dist[i], 0.25) * max_slope
		backward[i] = clampf(desired[i], backward[i + 1] - cap2, backward[i + 1] + cap2)
	var ys := PackedFloat32Array()
	ys.resize(n)
	for i in n:
		ys[i] = lerpf(forward[i], backward[i], dist[i] / total)
	for _pass in 2:
		var copy := ys.duplicate()
		for i in range(1, n - 1):
			ys[i] = copy[i - 1] * 0.22 + copy[i] * 0.56 + copy[i + 1] * 0.22
	ys[0] = y0
	ys[n - 1] = y1
	_span_bridges(ys, raw, dist)
	ys[0] = y0
	ys[n - 1] = y1
	var kinds := PackedByteArray()
	kinds.resize(n)
	for i in n:
		var ground := raw[i]
		if ground > ys[i] + 5.5:
			kinds[i] = KIND_TUNNEL
		elif ys[i] > ground + 5.0:
			kinds[i] = KIND_BRIDGE
		else:
			kinds[i] = KIND_ROAD
	_keep_runs(kinds, KIND_TUNNEL, 4)
	_keep_runs(kinds, KIND_BRIDGE, 3)
	return {"y": ys, "kinds": kinds}


func _span_bridges(ys: PackedFloat32Array, raw: PackedFloat32Array, dist: PackedFloat32Array) -> void:
	var n := ys.size()
	var i := 1
	while i < n - 1:
		if raw[i] > raw[i - 1] - 6.0:
			i += 1
			continue
		var start := i
		var floor_y := raw[i]
		while i < n - 1 and raw[i] < raw[start - 1] - 5.0:
			floor_y = minf(floor_y, raw[i])
			i += 1
		var finish := mini(i, n - 1)
		var span := dist[finish] - dist[start - 1]
		if span < 16.0 or span > 200.0 or finish <= start:
			continue
		var y_a := raw[start - 1] + 1.0
		var y_b := raw[finish] + 1.0
		for k in range(start, finish):
			var t := (dist[k] - dist[start - 1]) / span
			var deck := lerpf(y_a, y_b, t)
			if deck > floor_y + 5.0:
				ys[k] = maxf(ys[k], deck)


func _keep_runs(kinds: PackedByteArray, kind: int, minimum: int) -> void:
	var i := 0
	while i < kinds.size():
		if kinds[i] != kind:
			i += 1
			continue
		var j := i
		while j < kinds.size() and kinds[j] == kind:
			j += 1
		if j - i < minimum:
			for k in range(i, j):
				kinds[k] = KIND_ROAD
		i = j


func _separate_tunnels() -> void:
	tunnel_points = 0
	var kept: Array[Dictionary] = []
	for edge in edges:
		var pts: PackedVector3Array = edge.points
		var kinds: PackedByteArray = edge.kinds
		var radius := float(edge.width) * 0.52
		var i := 0
		while i < kinds.size():
			if kinds[i] != KIND_TUNNEL:
				i += 1
				continue
			var j := i
			while j < kinds.size() and kinds[j] == KIND_TUNNEL:
				j += 1
			var hits := false
			for k in range(i, j):
				if _tunnel_blocked(pts[k], radius, kept):
					hits = true
					break
			if hits:
				for k in range(i, j):
					kinds[k] = KIND_ROAD
					var ground := terrain.height_at(pts[k].x, pts[k].z) + 0.5
					var lifted := pts[k]
					lifted.y = ground
					pts[k] = lifted
			else:
				var run := PackedVector3Array()
				for k in range(i, j):
					run.append(pts[k])
				kept.append({"pts": run, "radius": radius})
			i = j
		var tunnels := 0
		for k in kinds.size():
			if kinds[k] == KIND_TUNNEL:
				tunnels += 1
		edge.points = pts
		edge.kinds = kinds
		edge.tunnels = tunnels
		tunnel_points += tunnels


func _tunnel_blocked(p: Vector3, radius: float, kept: Array[Dictionary]) -> bool:
	for run in kept:
		var tube: PackedVector3Array = run.pts
		var reach := radius + float(run.radius) * 0.82
		for i in range(tube.size() - 1):
			var d := _dist_to_seg2(Vector2(p.x, p.z), Vector2(tube[i].x, tube[i].z), Vector2(tube[i + 1].x, tube[i + 1].z))
			if d < reach:
				return true
	return false


func _dist_to_seg2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _carve_corridors() -> void:
	terrain.grade_network(edges)


func _build_hash() -> void:
	_hash.clear()
	for edge in edges:
		var pts: PackedVector3Array = edge.points
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var kind := int(edge.kinds[i])
			var fwd := b - a
			var side := fwd.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized()
			var normal := side.cross(fwd).normalized()
			if normal.y < 0.0:
				normal = -normal
			var seg := {
				"ax": a.x, "az": a.z, "ay": a.y,
				"bx": b.x, "bz": b.z, "by": b.y,
				"width": edge.width,
				"kind": kind,
				"normal": normal,
			}
			_insert_segment(seg, a, b)


func _insert_segment(seg: Dictionary, a: Vector3, b: Vector3) -> void:
	var grid := 24.0
	var min_x := int(floor(minf(a.x, b.x) / grid)) - 1
	var max_x := int(floor(maxf(a.x, b.x) / grid)) + 1
	var min_z := int(floor(minf(a.z, b.z) / grid)) - 1
	var max_z := int(floor(maxf(a.z, b.z) / grid)) + 1
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var key := (x + 10000) * 100000 + (z + 10000)
			if not _hash.has(key):
				_hash[key] = []
			(_hash[key] as Array).append(seg)


func _closest_road(x: float, z: float) -> Dictionary:
	var grid := 24.0
	var cx := int(floor(x / grid))
	var cz := int(floor(z / grid))
	var best_d := 70.0
	var best_y := 0.0
	var best_w := 0.0
	var best_kind := 0
	var best_n := Vector3.UP
	var found := false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := (cx + dx + 10000) * 100000 + (cz + dz + 10000)
			if not _hash.has(key):
				continue
			var segs: Array = _hash[key]
			for seg in segs:
				var ax := float(seg.ax)
				var az := float(seg.az)
				var bx := float(seg.bx)
				var bz := float(seg.bz)
				var abx := bx - ax
				var abz := bz - az
				var len2 := abx * abx + abz * abz
				var t := 0.0
				if len2 > 0.0001:
					t = clampf(((x - ax) * abx + (z - az) * abz) / len2, 0.0, 1.0)
				var px := lerpf(ax, bx, t)
				var pz := lerpf(az, bz, t)
				var dist := Vector2(x - px, z - pz).length()
				if dist < best_d:
					best_d = dist
					best_y = lerpf(float(seg.ay), float(seg.by), t)
					best_w = float(seg.width)
					best_kind = int(seg.kind)
					best_n = seg.normal
					found = true
	if not found:
		return {}
	return {
		"dist": best_d,
		"y": best_y,
		"width": best_w,
		"kind": best_kind,
		"normal": best_n,
	}


func _build_races() -> void:
	var circuit_names: Array[String] = [
		"Mesa Loop", "Bridge Circuit", "Tunnel Gauntlet", "Grand Horizon",
		"Needle Circuit", "Oasis Ring", "Scorch GP", "Vortex Cup",
	]
	for i in _tracks.size():
		var edge_ids: Array = _tracks[i].edges
		var pts := _align_to_apex(_trace_loop(edge_ids))
		races.append(_finalize_race(_pack_points(pts, edge_ids), circuit_names[i], "circuit"))


func _trace_loop(edge_ids: Array) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for raw in edge_ids:
		var seq: PackedVector3Array = edges[int(raw)].points
		var start_i := 0 if pts.is_empty() else 1
		for s in range(start_i, seq.size()):
			pts.append(seq[s])
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) > 4.0:
		pts.append(pts[0])
	return pts


func _align_to_apex(pts: PackedVector3Array) -> PackedVector3Array:
	var count := _open_count(pts)
	if count < 4:
		return pts
	var peaks := _apex_indices(pts)
	var start := 0
	var best := -1.0
	for index in peaks:
		var prev: Vector3 = pts[(index + count - 1) % count]
		var here: Vector3 = pts[index]
		var nxt: Vector3 = pts[(index + 1) % count]
		var back := Vector2(here.x - prev.x, here.z - prev.z)
		var fwd := Vector2(nxt.x - here.x, nxt.z - here.z)
		var ang := 0.0
		if back.length_squared() > 0.04 and fwd.length_squared() > 0.04:
			ang = absf(back.normalized().angle_to(fwd.normalized()))
		if ang > best:
			best = ang
			start = index
	var out := PackedVector3Array()
	for i in count:
		out.append(pts[(start + i) % count])
	out.append(out[0])
	return out


func _apex_indices(pts: PackedVector3Array) -> Array[int]:
	var count := _open_count(pts)
	if count < 8:
		return [0]
	var turn := PackedFloat32Array()
	turn.resize(count)
	for i in count:
		var prev: Vector3 = pts[(i + count - 1) % count]
		var here: Vector3 = pts[i]
		var nxt: Vector3 = pts[(i + 1) % count]
		var back := Vector2(here.x - prev.x, here.z - prev.z)
		var fwd := Vector2(nxt.x - here.x, nxt.z - here.z)
		if back.length_squared() < 0.04 or fwd.length_squared() < 0.04:
			turn[i] = 0.0
		else:
			turn[i] = absf(back.normalized().angle_to(fwd.normalized()))
	var smooth := PackedFloat32Array()
	smooth.resize(count)
	for i in count:
		var acc := 0.0
		for k in range(-3, 4):
			acc += turn[(i + k + count) % count]
		smooth[i] = acc / 7.0
	var min_sep := 8
	var peaks: Array[int] = []
	for i in count:
		if smooth[i] < 0.012:
			continue
		if smooth[i] + 0.000001 < smooth[(i + count - 1) % count]:
			continue
		if smooth[i] + 0.000001 < smooth[(i + 1) % count]:
			continue
		var merged := false
		for p in peaks.size():
			if _ring_gap(peaks[p], i, count) < min_sep:
				if smooth[i] > smooth[peaks[p]]:
					peaks[p] = i
				merged = true
				break
		if not merged:
			peaks.append(i)
	if peaks.size() >= 2 and _ring_gap(peaks[0], peaks[peaks.size() - 1], count) < min_sep:
		if smooth[peaks[peaks.size() - 1]] > smooth[peaks[0]]:
			peaks[0] = peaks[peaks.size() - 1]
		peaks.remove_at(peaks.size() - 1)
	if peaks.size() < 4:
		peaks = _strongest_peaks(smooth, 4, min_sep)
	peaks.sort()
	return peaks


func _strongest_peaks(smooth: PackedFloat32Array, want: int, min_sep: int) -> Array[int]:
	var order: Array[int] = []
	for i in smooth.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return smooth[a] > smooth[b]
	)
	var picked: Array[int] = []
	var count := smooth.size()
	for index in order:
		var clear := true
		for have in picked:
			if _ring_gap(have, index, count) < min_sep:
				clear = false
				break
		if not clear:
			continue
		picked.append(index)
		if picked.size() >= want:
			break
	picked.sort()
	return picked


func _ring_gap(a: int, b: int, count: int) -> int:
	var d := absi(a - b)
	return mini(d, count - d)


func _open_count(pts: PackedVector3Array) -> int:
	if pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 4.0:
		return pts.size() - 1
	return pts.size()


func _pack_points(pts: PackedVector3Array, edge_ids: Array) -> Dictionary:
	var dists := PackedFloat32Array()
	dists.resize(pts.size())
	var total := 0.0
	dists[0] = 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		dists[i] = total
	var has_tunnel := false
	var has_bridge := false
	var has_shortcut := false
	for raw in edge_ids:
		var e: Dictionary = edges[int(raw)]
		if int(e.tunnels) > 3:
			has_tunnel = true
		if int(e.bridges) > 2:
			has_bridge = true
		if bool(e.shortcut):
			has_shortcut = true
	return {
		"points": pts,
		"distances": dists,
		"length": total,
		"edges": edge_ids,
		"has_tunnel": has_tunnel,
		"has_bridge": has_bridge,
		"has_shortcut": has_shortcut,
	}


func _finalize_race(data: Dictionary, race_name: String, kind: String) -> Dictionary:
	var pts: PackedVector3Array = data.points
	var dists: PackedFloat32Array = data.distances
	var length := float(data.length)
	var circuit := kind == "circuit"
	var laps := 1
	if circuit:
		laps = 3 if length < 1500.0 else 2
	var peaks := _apex_indices(pts)
	var cps := PackedVector3Array()
	var cp_dist := PackedFloat32Array()
	for index in peaks:
		cps.append(pts[index])
		cp_dist.append(dists[index])
	if cps.is_empty():
		cps.append(pts[0])
		cp_dist.append(0.0)
	var dir := pts[mini(3, pts.size() - 1)] - pts[0]
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	var features: PackedStringArray = []
	if bool(data.has_tunnel):
		features.append("tunnels")
	if bool(data.has_bridge):
		features.append("bridges")
	if bool(data.has_shortcut):
		features.append("shortcuts")
	if features.is_empty():
		features.append("open desert")
	var blurb := "%s · %s · %s" % [
		"Circuit" if circuit else "Point to point",
		Util.km(length * float(laps)),
		", ".join(features),
	]
	return {
		"name": race_name,
		"type": kind,
		"laps": laps,
		"points": pts,
		"distances": dists,
		"length": length,
		"checkpoints": cps,
		"checkpoint_dist": cp_dist,
		"start_dir": dir,
		"blurb": blurb,
		"has_tunnel": data.has_tunnel,
		"has_bridge": data.has_bridge,
		"has_shortcut": data.has_shortcut,
	}
