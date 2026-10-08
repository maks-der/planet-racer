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
var _rng := RandomNumberGenerator.new()


func generate(field: TerrainField, seed: int) -> void:
	terrain = field
	_rng.seed = seed + 501
	edges.clear()
	races.clear()
	node_xz = PackedVector2Array()
	node_y = PackedFloat32Array()
	outer_ids.clear()
	inner_ids.clear()
	_hash.clear()
	tunnel_points = 0
	bridge_points = 0
	shortcut_edges = 0
	_place_nodes()
	_connect_network()
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


func _place_nodes() -> void:
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var base := Vector2(cos(ang), sin(ang)) * TerrainField.HALF * 0.6
		outer_ids.append(_add_node(_relax(base, TerrainField.HALF * 0.07)))
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.4
		var base := Vector2(cos(ang), sin(ang)) * TerrainField.HALF * 0.26
		inner_ids.append(_add_node(_relax(base, TerrainField.HALF * 0.055)))
	_spread(outer_ids, TerrainField.HALF * 0.1)
	_spread(inner_ids, TerrainField.HALF * 0.07)
	for i in node_xz.size():
		node_y[i] = terrain.height_at(node_xz[i].x, node_xz[i].y) + 0.55


func _relax(base: Vector2, jitter: float) -> Vector2:
	var best := base
	var best_score := 100000.0
	for attempt in 28:
		var p := base
		if attempt > 0:
			p += Vector2(_rng.randf_range(-jitter * 1.8, jitter * 1.8), _rng.randf_range(-jitter * 1.8, jitter * 1.8))
		var limit := TerrainField.HALF * 0.72
		p.x = clampf(p.x, -limit, limit)
		p.y = clampf(p.y, -limit, limit)
		var slope := terrain.slope_at(p.x, p.y)
		var h := terrain.height_at(p.x, p.y)
		var score := slope * 280.0 + maxf(h - 16.0, 0.0) * 2.4 + maxf(h - 40.0, 0.0) * 16.0
		if score < best_score:
			best_score = score
			best = p
	return best


func _spread(ids: Array[int], min_dist: float) -> void:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := node_xz[ids[i]]
			var b := node_xz[ids[j]]
			var d := a.distance_to(b)
			if d < min_dist and d > 0.1:
				var push := (b - a).normalized() * ((min_dist - d) * 0.5)
				node_xz[ids[i]] = _clamp_map(a - push)
				node_xz[ids[j]] = _clamp_map(b + push)


func _clamp_map(p: Vector2) -> Vector2:
	var limit := TerrainField.HALF * 0.76
	return Vector2(clampf(p.x, -limit, limit), clampf(p.y, -limit, limit))


func _add_node(p: Vector2) -> int:
	node_xz.append(p)
	node_y.append(0.0)
	return node_xz.size() - 1


func _connect_network() -> void:
	_adj.clear()
	for _i in node_xz.size():
		_adj.append([])
	var linked := {}
	for i in outer_ids.size():
		_try_edge(outer_ids[i], outer_ids[(i + 1) % outer_ids.size()], false, linked)
	for i in inner_ids.size():
		_try_edge(inner_ids[i], inner_ids[(i + 1) % inner_ids.size()], false, linked)
	for i in inner_ids.size():
		_try_edge(inner_ids[i], outer_ids[(i * 2) % outer_ids.size()], false, linked)
	_try_edge(outer_ids[0], outer_ids[4], false, linked)
	_try_edge(outer_ids[2], outer_ids[6], false, linked)
	var shortcut_pairs := [
		[0, 2], [2, 5], [4, 7], [1, 6], [3, 6], [0, 5],
	]
	for i in range(shortcut_pairs.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Array = shortcut_pairs[i]
		shortcut_pairs[i] = shortcut_pairs[j]
		shortcut_pairs[j] = tmp
	var added := 0
	for pair in shortcut_pairs:
		if added >= 4:
			break
		var a: int = outer_ids[int(pair[0])]
		var b: int = outer_ids[int(pair[1])]
		if _try_edge(a, b, true, linked):
			added += 1
	if added < 3:
		for i in outer_ids.size():
			if added >= 4:
				break
			var a2: int = outer_ids[i]
			var b2: int = outer_ids[(i + 3) % outer_ids.size()]
			if _try_edge(a2, b2, true, linked):
				added += 1


func _try_edge(a: int, b: int, shortcut: bool, linked: Dictionary) -> bool:
	if a == b:
		return false
	var key := "%d-%d" % [mini(a, b), maxi(a, b)]
	if linked.has(key):
		return false
	var span := node_xz[a].distance_to(node_xz[b])
	if span < 40.0:
		return false
	linked[key] = true
	var edge := _build_edge(a, b, shortcut)
	var index := edges.size()
	edges.append(edge)
	_adj[a].append({"to": b, "edge": index})
	_adj[b].append({"to": a, "edge": index})
	if shortcut:
		shortcut_edges += 1
	return true


func _build_edge(a: int, b: int, shortcut: bool) -> Dictionary:
	var xz := _curve(node_xz[a], node_xz[b], shortcut)
	var profile := _profile(xz, node_y[a], node_y[b], shortcut)
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
	return {
		"a": a,
		"b": b,
		"points": pts,
		"kinds": kinds,
		"shortcut": shortcut,
		"width": 32.0 if shortcut else 46.0,
		"length": length,
		"tunnels": tunnels,
		"bridges": bridges,
	}


func _curve(a: Vector2, b: Vector2, shortcut: bool) -> PackedVector2Array:
	var length := a.distance_to(b)
	if length < 0.01:
		var tiny := PackedVector2Array()
		tiny.append(a)
		tiny.append(b)
		return tiny
	var controls := _relief_controls(a, b, shortcut)
	return _resample(_smooth_relief(controls), SPACING)


func _relief_controls(a: Vector2, b: Vector2, shortcut: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(a)
	var pos := a
	var step := 24.0 if shortcut else 30.0
	var reach := 64.0 if shortcut else 150.0
	var bend := _rng.randf_range(-0.9, 0.9)
	var guard := 0
	while pos.distance_to(b) > step * 1.55 and guard < 110:
		guard += 1
		var remain := b - pos
		var dist := remain.length()
		if dist < 0.01:
			break
		var dir := remain / dist
		var perp := Vector2(-dir.y, dir.x)
		if dist > step * 4.5:
			bend = clampf(bend + _rng.randf_range(-0.34, 0.34), -1.0, 1.0)
		else:
			bend = move_toward(bend, 0.0, 0.45)
		var want := bend * reach * 0.62
		var best := _clamp_map(pos + dir * step)
		var best_cost := 1000000.0
		var samples := 7 if shortcut else 11
		for i in samples:
			var off := lerpf(-reach, reach, float(i) / float(samples - 1))
			var candidate := _clamp_map(pos + dir * step + perp * off)
			var gained := dist - candidate.distance_to(b)
			if gained < step * 0.36:
				continue
			var ahead := _clamp_map(candidate + dir * minf(step, dist * 0.35))
			var cost := _ground_penalty(candidate) + _ground_penalty(ahead) * 0.65
			cost += absf(off - want) * 0.05
			if cost < best_cost:
				best_cost = cost
				best = candidate
		if best.distance_to(pos) < step * 0.3:
			best = _clamp_map(pos + dir * step)
		pts.append(best)
		pos = best
	pts.append(b)
	return pts


func _ground_penalty(p: Vector2) -> float:
	var h := terrain.height_at(p.x, p.y)
	var slope := terrain.slope_at(p.x, p.y)
	var cost := 0.0
	if h > 18.0:
		cost += (h - 18.0) * 2.4
	if h > 42.0:
		cost += (h - 42.0) * 26.0
	if slope > 0.055:
		cost += (slope - 0.055) * 340.0
	if slope > 0.15:
		cost += 1600.0
	return cost


func _smooth_relief(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 4:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i - 1] * 0.22 + pts[i] * 0.56 + pts[i + 1] * 0.22
		out.append(_clamp_map(p))
	out.append(pts[pts.size() - 1])
	return out


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
	var circuits := _circuit_candidates()
	circuits.sort_custom(func(a, b): return float(a.length) < float(b.length))
	var picked := _pick_spread(circuits, 8)
	while picked.size() < 8 and not circuits.is_empty():
		picked.append(circuits[mini(picked.size(), circuits.size() - 1)])
	if picked.size() < 8:
		picked.append_array(_fallback_loops(8 - picked.size()))
	var circuit_names := [
		"Mesa Loop", "Bridge Circuit", "Tunnel Gauntlet", "Grand Horizon",
		"Needle Circuit", "Oasis Ring", "Scorch GP", "Vortex Cup",
	]
	for i in 8:
		races.append(_finalize_race(picked[i], circuit_names[i], "circuit"))


func _circuit_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	_add_cycle(out, seen, _ring_edges(outer_ids), outer_ids[0])
	_add_cycle(out, seen, _ring_edges(inner_ids), inner_ids[0])
	var diameter_a := _find_edge(outer_ids[0], outer_ids[4])
	var diameter_b := _find_edge(outer_ids[2], outer_ids[6])
	if diameter_a >= 0:
		var left: Array = []
		for i in 4:
			left.append(_find_edge(outer_ids[i], outer_ids[(i + 1) % 8]))
		left.append(diameter_a)
		_add_cycle(out, seen, left, outer_ids[0])
		var right: Array = []
		for i in range(4, 8):
			right.append(_find_edge(outer_ids[i], outer_ids[(i + 1) % 8]))
		right.append(diameter_a)
		_add_cycle(out, seen, right, outer_ids[4])
	if diameter_b >= 0:
		var arc: Array = []
		for i in range(2, 6):
			arc.append(_find_edge(outer_ids[i], outer_ids[(i + 1) % 8]))
		arc.append(diameter_b)
		_add_cycle(out, seen, arc, outer_ids[2])
	for edge_i in edges.size():
		if not bool(edges[edge_i].shortcut):
			continue
		var edge: Dictionary = edges[edge_i]
		var path: Dictionary = _shortest(int(edge.a), int(edge.b), edge_i)
		if path.is_empty():
			continue
		var ids: Array = (path.edges as Array).duplicate()
		ids.append(edge_i)
		_add_cycle(out, seen, ids, int(edge.a))
	return out


func _add_cycle(bucket: Array[Dictionary], seen: Dictionary, edge_ids: Array, start_node: int) -> void:
	if edge_ids.is_empty() or edge_ids.has(-1):
		return
	var signature := _signature(edge_ids)
	if seen.has(signature):
		return
	var built := _compose(edge_ids, start_node)
	if built.is_empty():
		return
	if float(built.length) < 420.0:
		return
	seen[signature] = true
	built["edges"] = edge_ids
	bucket.append(built)


func _pick_spread(items: Array[Dictionary], count: int) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	if items.is_empty():
		return picked
	var used := {}
	for slot in count:
		var target := lerpf(0.08, 0.92, float(slot) / float(maxi(count - 1, 1)))
		var want := lerpf(float(items[0].length), float(items[items.size() - 1].length), target)
		var best_i := -1
		var best_score := 100000000.0
		for i in items.size():
			if used.has(i):
				continue
			var score := absf(float(items[i].length) - want)
			if score < best_score:
				best_score = score
				best_i = i
		if best_i >= 0:
			used[best_i] = true
			picked.append(items[best_i])
	return picked


func _fallback_loops(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var center := Vector2.ZERO
	for n in count:
		var pts := PackedVector3Array()
		var rx := 260.0 + float(n) * 70.0
		var rz := 200.0 + float(n) * 55.0
		var steps := 64
		for i in steps + 1:
			var a := TAU * float(i) / float(steps)
			var p := center + Vector2(cos(a) * rx, sin(a) * rz)
			var y := terrain.height_at(p.x, p.y) + 0.6
			pts.append(Vector3(p.x, y, p.y))
		out.append(_pack_points(pts, []))
	return out


func _ring_edges(ids: Array[int]) -> Array:
	var list: Array = []
	for i in ids.size():
		list.append(_find_edge(ids[i], ids[(i + 1) % ids.size()]))
	return list


func _find_edge(a: int, b: int) -> int:
	for link in _adj[a]:
		if int(link.to) == b:
			return int(link.edge)
	return -1


func _shortest(start: int, goal: int, ignore_edge: int, prefer_shortcut: bool = false) -> Dictionary:
	var n := node_xz.size()
	var dist: Array[float] = []
	dist.resize(n)
	dist.fill(INF)
	var prev_n: Array[int] = []
	prev_n.resize(n)
	prev_n.fill(-1)
	var prev_e: Array[int] = []
	prev_e.resize(n)
	prev_e.fill(-1)
	dist[start] = 0.0
	var open: Array[int] = [start]
	while not open.is_empty():
		var best_i := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var u := open[best_i]
		open.remove_at(best_i)
		if u == goal:
			break
		for link in _adj[u]:
			var ei := int(link.edge)
			if ei == ignore_edge:
				continue
			var e: Dictionary = edges[ei]
			var w := float(e.length)
			if prefer_shortcut and bool(e.shortcut):
				w *= 0.45
			var v := int(link.to)
			if dist[u] + w < dist[v]:
				dist[v] = dist[u] + w
				prev_n[v] = u
				prev_e[v] = ei
				if not open.has(v):
					open.append(v)
	if dist[goal] == INF or prev_n[goal] == -1 and start != goal:
		return {}
	var edge_ids: Array = []
	var cur := goal
	var guard := 0
	while cur != start and guard < 64:
		guard += 1
		if prev_e[cur] < 0:
			return {}
		edge_ids.append(prev_e[cur])
		cur = prev_n[cur]
	edge_ids.reverse()
	return {"edges": edge_ids, "start": start, "length": dist[goal]}


func _compose(edge_ids: Array, start_node: int) -> Dictionary:
	var pts := _walk(edge_ids, start_node)
	if pts.size() < 8:
		return {}
	return _pack_points(pts, edge_ids)


func _walk(edge_ids: Array, start_node: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var current := start_node
	for raw in edge_ids:
		var ei := int(raw)
		var e: Dictionary = edges[ei]
		var seq: PackedVector3Array = e.points
		var forward := int(e.a) == current
		if forward:
			var start_i := 0 if pts.is_empty() else 1
			for i in range(start_i, seq.size()):
				pts.append(seq[i])
			current = int(e.b)
		else:
			var from_i := seq.size() - 1 if pts.is_empty() else seq.size() - 2
			for i in range(from_i, -1, -1):
				pts.append(seq[i])
			current = int(e.a)
	return pts


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
	var spacing := 78.0 if length > 1100.0 else 58.0
	var cps := PackedVector3Array()
	var cp_dist := PackedFloat32Array()
	cps.append(pts[0])
	cp_dist.append(0.0)
	var cursor := spacing
	var margin := spacing * 0.7 if circuit else 12.0
	while cursor < length - margin:
		cps.append(point_at(pts, dists, cursor))
		cp_dist.append(cursor)
		cursor += spacing
	if not circuit:
		cps.append(pts[pts.size() - 1])
		cp_dist.append(length)
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


func _signature(edge_ids: Array) -> String:
	var ids: Array[int] = []
	for raw in edge_ids:
		ids.append(int(raw))
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		parts.append(str(id))
	return ",".join(parts)
