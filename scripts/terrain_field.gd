class_name TerrainField
extends RefCounted

const HALF := 1400.0
const RES := 561
const BORDER := 150.0

var cell: float = (HALF * 2.0) / float(RES - 1)
var heights := PackedFloat32Array()
var road_mask := PackedFloat32Array()
var min_h := 0.0
var max_h := 1.0
var wind_dir := Vector3(0.82, 0.0, 0.42)

var _dune: FastNoiseLite
var _detail: FastNoiseLite
var _ridge: FastNoiseLite
var _range: FastNoiseLite
var _mask: FastNoiseLite
var _waste: FastNoiseLite
var _waste_ridge: FastNoiseLite
var _biome: FastNoiseLite
var _mesas: Array[Dictionary] = []
var _canyons: Array[Dictionary] = []
var _base_heights := PackedFloat32Array()


func generate(seed: int) -> void:
	begin(seed)
	write_rows(0, RES)


func begin(seed: int) -> void:
	_dune = _perlin(seed, 0.0018, 4)
	_detail = _perlin(seed + 11, 0.014, 3)
	_ridge = _noise(seed + 23, 0.0016, 5)
	_range = _noise(seed + 41, 0.00072, 2)
	_mask = _noise(seed + 57, 0.0014, 2)
	_waste = _noise(seed + 70, 0.0022, 3)
	_waste_ridge = _noise(seed + 88, 0.0011, 3)
	_biome = _noise(seed + 103, 0.0017, 2)
	_build_features(seed)
	var ang := float(seed % 628) * 0.01
	wind_dir = Vector3(cos(ang), 0.0, sin(ang)).normalized()
	heights.resize(RES * RES)
	heights.fill(1.0)
	road_mask.resize(RES * RES)
	road_mask.fill(0.0)
	min_h = 1000.0
	max_h = -1000.0


func write_rows(z0: int, z1: int) -> void:
	for z in range(z0, z1):
		for x in RES:
			var wx := -HALF + float(x) * cell
			var wz := -HALF + float(z) * cell
			var h := _base_height(wx, wz)
			heights[z * RES + x] = h
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)


func height_at(x: float, z: float) -> float:
	var gx := (x + HALF) / cell
	var gz := (z + HALF) / cell
	if gx < 0.0 or gz < 0.0 or gx > float(RES - 1) or gz > float(RES - 1):
		return waste_height(x, z)
	var x0 := clampi(int(floor(gx)), 0, RES - 2)
	var z0 := clampi(int(floor(gz)), 0, RES - 2)
	var tx := clampf(gx - float(x0), 0.0, 1.0)
	var tz := clampf(gz - float(z0), 0.0, 1.0)
	var h00 := heights[z0 * RES + x0]
	var h10 := heights[z0 * RES + x0 + 1]
	var h01 := heights[(z0 + 1) * RES + x0]
	var h11 := heights[(z0 + 1) * RES + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func normal_at(x: float, z: float) -> Vector3:
	var d := cell
	var hl := height_at(x - d, z)
	var hr := height_at(x + d, z)
	var hd := height_at(x, z - d)
	var hu := height_at(x, z + d)
	return Vector3(hl - hr, 2.0 * d, hd - hu).normalized()


func slope_at(x: float, z: float) -> float:
	return 1.0 - normal_at(x, z).y


func region_weights(x: float, z: float) -> Vector4:
	var a := _biome.get_noise_2d(x, z)
	var b := _biome.get_noise_2d(x * 0.73 + 340.0, z * 0.73)
	var dune := pow(Util.smoothstep(0.08, -0.42, a) * Util.smoothstep(0.12, -0.38, b), 1.35)
	var rock := pow(Util.smoothstep(-0.02, 0.46, a) * Util.smoothstep(0.1, -0.36, b), 1.35)
	var hills := pow(Util.smoothstep(-0.02, 0.46, a) * Util.smoothstep(-0.08, 0.42, b), 1.35)
	var scrub := pow(Util.smoothstep(0.08, -0.4, a) * Util.smoothstep(-0.06, 0.4, b), 1.35)
	var sum := maxf(dune + rock + hills + scrub, 0.001)
	return Vector4(dune / sum, rock / sum, hills / sum, scrub / sum)


func ground_color(x: float, z: float, h: float, normal: Vector3, road: float) -> Color:
	var w := region_weights(x, z)
	var grit := _detail.get_noise_2d(x * 1.6, z * 1.6) * 0.5 + 0.5
	var slope := clampf(1.0 - normal.y, 0.0, 1.0)
	var gold := Color(0.78, 0.46, 0.16).lerp(Color(0.48, 0.24, 0.08), slope * 0.9)
	var red := Color(0.7, 0.24, 0.1).lerp(Color(0.36, 0.12, 0.08), slope)
	var tan := Color(0.58, 0.42, 0.24).lerp(Color(0.34, 0.26, 0.16), slope * 0.85)
	var pale := Color(0.7, 0.56, 0.34).lerp(Color(0.42, 0.34, 0.2), grit * 0.45)
	var col := gold * w.x + red * w.y + tan * w.z + pale * w.w
	if normal.y < 0.74:
		var cliff := Color(0.66, 0.28, 0.14).lerp(Color(0.38, 0.24, 0.18), w.z)
		col = col.lerp(cliff, clampf((0.74 - normal.y) / 0.38, 0.0, 1.0))
	if h > 88.0 and w.y + w.z > 0.35:
		col = col.lerp(Color(0.9, 0.86, 0.8), clampf((h - 88.0) / 55.0, 0.0, 0.5))
	if h < 3.2 and normal.y > 0.94 and w.w > 0.45:
		col = col.lerp(Color(0.74, 0.68, 0.54), 0.4)
	if road > 0.05:
		var track := Color(col.r * 0.62, col.g * 0.55, col.b * 0.42).lerp(Color(0.42, 0.28, 0.14), 0.4)
		col = col.lerp(track, clampf(road * 1.15, 0.0, 1.0))
	return col


func waste_height(x: float, z: float) -> float:
	var w := region_weights(x, z)
	var n := _waste.get_noise_2d(x, z)
	var ridge := pow(1.0 - absf(_waste_ridge.get_noise_2d(x, z)), 1.8)
	var ripple := sin(x * 0.08 + z * 0.02) * sin(z * 0.1) * w.x
	var h := 4.0 + n * lerpf(3.5, 9.0, w.x) + ripple * 1.6
	h += ridge * lerpf(16.0, 48.0, clampf(w.y + w.z * 0.7, 0.0, 1.0))
	h = lerpf(h, 5.5 + n * 2.4, w.w * 0.45)
	return maxf(h, 1.2)


func storm_factor(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	return Util.smoothstep(HALF * 0.96, HALF * 1.28, dist)


func wind_force(x: float, z: float) -> Vector3:
	var storm := storm_factor(x, z)
	if storm <= 0.001:
		return Vector3.ZERO
	var gust := 0.62 + 0.38 * sin(Time.get_ticks_msec() * 0.0008 + x * 0.004)
	return wind_dir * storm * gust * 26.0


func road_factor(x: float, z: float) -> float:
	if road_mask.is_empty():
		return 0.0
	var gx := (x + HALF) / cell
	var gz := (z + HALF) / cell
	if gx < 0.0 or gz < 0.0 or gx > float(RES - 1) or gz > float(RES - 1):
		return 0.0
	var x0 := clampi(int(floor(gx)), 0, RES - 2)
	var z0 := clampi(int(floor(gz)), 0, RES - 2)
	var tx := clampf(gx - float(x0), 0.0, 1.0)
	var tz := clampf(gz - float(z0), 0.0, 1.0)
	var m00 := road_mask[z0 * RES + x0]
	var m10 := road_mask[z0 * RES + x0 + 1]
	var m01 := road_mask[(z0 + 1) * RES + x0]
	var m11 := road_mask[(z0 + 1) * RES + x0 + 1]
	return lerpf(lerpf(m00, m10, tx), lerpf(m01, m11, tx), tz)


func grade_network(edges: Array) -> void:
	var weight := PackedFloat32Array()
	var accum := PackedFloat32Array()
	var berms := PackedFloat32Array()
	weight.resize(RES * RES)
	accum.resize(RES * RES)
	berms.resize(RES * RES)
	var tubes: Array[Dictionary] = []
	for ei in edges.size():
		var src: Dictionary = edges[ei]
		var src_kinds: PackedByteArray = src.kinds
		var src_pts: PackedVector3Array = src.points
		for i in src_pts.size():
			if int(src_kinds[i]) != 2:
				continue
			tubes.append({"x": src_pts[i].x, "z": src_pts[i].z, "id": ei, "r": float(src.width) * 0.5})
	for ei in edges.size():
		var edge: Dictionary = edges[ei]
		var pts: PackedVector3Array = edge.points
		var half_w := float(edge.width) * 0.5
		var reach_m := half_w + 6.0
		var reach := int(ceil(reach_m / cell)) + 1
		for p in pts:
			if _in_other_tunnel(p, ei, half_w, tubes):
				continue
			var cx := int(round((p.x + HALF) / cell))
			var cz := int(round((p.z + HALF) / cell))
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var ix := cx + dx
					var iz := cz + dz
					if ix < 1 or iz < 1 or ix >= RES - 1 or iz >= RES - 1:
						continue
					var wx := -HALF + float(ix) * cell
					var wz := -HALF + float(iz) * cell
					var dist := Vector2(wx, wz).distance_to(Vector2(p.x, p.z))
					if dist > reach_m:
						continue
					var idx := iz * RES + ix
					var bed := 1.0 - Util.smoothstep(half_w * 0.25, half_w * 1.08, dist)
					var shoulder := Util.smoothstep(half_w * 0.78, half_w * 1.12, dist)
					shoulder *= 1.0 - Util.smoothstep(half_w * 1.12, half_w + 5.2, dist)
					if bed > 0.004:
						var target := p.y - 0.42 * bed
						weight[idx] += bed
						accum[idx] += bed * target
					if shoulder > berms[idx]:
						berms[idx] = shoulder
	for i in heights.size():
		var w := weight[i]
		if w > 0.004:
			var blend := clampf(w, 0.0, 1.0)
			heights[i] = lerpf(heights[i], accum[i] / w, blend)
			road_mask[i] = maxf(road_mask[i], blend)
		if berms[i] > 0.03 and w < 0.42:
			heights[i] += 1.7 * berms[i]
		min_h = minf(min_h, heights[i])
		max_h = maxf(max_h, heights[i])
	blend_border()


func stamp_pad(cx: float, cz: float, radius: float, height: float) -> void:
	var reach := int(ceil(radius / cell)) + 2
	var cx_i := int(round((cx + HALF) / cell))
	var cz_i := int(round((cz + HALF) / cell))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var ix := cx_i + dx
			var iz := cz_i + dz
			if ix < 1 or iz < 1 or ix >= RES - 1 or iz >= RES - 1:
				continue
			var wx := -HALF + float(ix) * cell
			var wz := -HALF + float(iz) * cell
			var dist := Vector2(wx - cx, wz - cz).length()
			if dist > radius:
				continue
			var blend := 1.0 - Util.smoothstep(radius * 0.55, radius, dist)
			var idx := iz * RES + ix
			heights[idx] = lerpf(heights[idx], height, blend)
			road_mask[idx] *= 1.0 - blend
			min_h = minf(min_h, heights[idx])
			max_h = maxf(max_h, heights[idx])


func _in_other_tunnel(p: Vector3, edge_id: int, half_w: float, tubes: Array[Dictionary]) -> bool:
	for tube in tubes:
		if int(tube.id) == edge_id:
			continue
		var reach := float(tube.r) + half_w * 0.55
		if Vector2(p.x, p.z).distance_to(Vector2(tube.x, tube.z)) < reach:
			return true
	return false


func blend_border() -> void:
	for z in RES:
		for x in RES:
			var wx := -HALF + float(x) * cell
			var wz := -HALF + float(z) * cell
			var edge := minf(minf(wx + HALF, HALF - wx), minf(wz + HALF, HALF - wz))
			var t := 1.0 - Util.smoothstep(0.0, BORDER, edge)
			if t <= 0.0:
				continue
			var idx := z * RES + x
			heights[idx] = lerpf(heights[idx], waste_height(wx, wz), t)
			road_mask[idx] *= 1.0 - t


func _build_features(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 90
	_mesas.clear()
	var reach := HALF * 0.7
	for i in 6:
		_mesas.append({
			"pos": Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)),
			"radius": rng.randf_range(210.0, 380.0),
			"height": rng.randf_range(62.0, 128.0),
			"flat": i < 2,
		})
	for i in 8:
		_mesas.append({
			"pos": Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)),
			"radius": rng.randf_range(70.0, 150.0),
			"height": rng.randf_range(28.0, 58.0),
			"flat": i < 5,
		})
	for i in 6:
		_mesas.append({
			"pos": Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)),
			"radius": rng.randf_range(34.0, 72.0),
			"height": rng.randf_range(48.0, 98.0),
			"flat": true,
		})
	_canyons.clear()
	for i in 3:
		var pts := PackedVector2Array()
		var offset := rng.randf_range(-HALF * 0.18, HALF * 0.18)
		var phase := rng.randf_range(0.0, TAU)
		var amp := rng.randf_range(160.0, 320.0)
		var steps := 12
		for s in steps:
			var t := lerpf(-HALF * 0.82, HALF * 0.82, float(s) / float(steps - 1))
			var wobble := sin(phase + float(s) * 0.72) * amp
			if i == 0:
				pts.append(Vector2(t, offset + wobble * 0.55))
			elif i == 1:
				pts.append(Vector2(offset + wobble * 0.55, t))
			else:
				pts.append(Vector2(t * 0.72 + wobble * 0.25, t * 0.62 - wobble * 0.2))
		_canyons.append({
			"pts": pts,
			"inner": rng.randf_range(24.0, 42.0),
			"outer": rng.randf_range(120.0, 210.0),
			"depth": rng.randf_range(38.0, 68.0),
		})


func _base_height(x: float, z: float) -> float:
	var w := region_weights(x, z)
	var dune := _dune.get_noise_2d(x, z)
	var detail := _detail.get_noise_2d(x, z)
	var broad := _dune.get_noise_2d(x * 0.32, z * 0.32)
	var ripple := sin(x * 0.085 + z * 0.018) * sin(z * 0.11) * lerpf(0.15, 1.7, w.x)
	var dune_h := 7.0 + dune * lerpf(9.0, 24.0, w.x) + broad * lerpf(7.0, 15.0, w.x) + ripple
	var rock_h := 13.0 + broad * 9.0 + dune * 3.5 + detail * 1.2
	var hill_h := 10.0 + broad * 16.0 + dune * 4.0 + detail * 1.6
	var scrub_h := 6.2 + dune * 4.2 + detail * 0.7
	var h := dune_h * w.x + rock_h * w.y + hill_h * w.z + scrub_h * w.w
	var salt := Util.smoothstep(0.34, 0.78, _mask.get_noise_2d(x, z)) * (0.35 + w.w * 0.65)
	h = lerpf(h, 2.4 + detail * 0.35, salt * 0.82)
	return maxf(h, 0.35)


func raise_highlands() -> void:
	_base_heights = heights.duplicate()
	for z in RES:
		for x in RES:
			var wx := -HALF + float(x) * cell
			var wz := -HALF + float(z) * cell
			var idx := z * RES + x
			heights[idx] += _highland_lift(wx, wz)
			min_h = minf(min_h, heights[idx])
			max_h = maxf(max_h, heights[idx])


func cut_road_canyons(edges: Array) -> void:
	var high := heights.duplicate()
	var best_d := PackedFloat32Array()
	var best_y := PackedFloat32Array()
	best_d.resize(RES * RES)
	best_y.resize(RES * RES)
	best_d.fill(100000.0)
	var reach_m := 76.0
	var reach := int(ceil(reach_m / cell)) + 1
	var floor_r := 30.0
	var wall := 42.0
	for edge in edges:
		var src: Dictionary = edge
		var pts: PackedVector3Array = src.points
		var kinds: PackedByteArray = src.kinds
		for pi in pts.size():
			var p: Vector3 = pts[pi]
			var floor_y := p.y
			if int(kinds[pi]) == 1 and not _base_heights.is_empty():
				floor_y = _height_from(_base_heights, p.x, p.z)
			var cx := int(round((p.x + HALF) / cell))
			var cz := int(round((p.z + HALF) / cell))
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var ix := cx + dx
					var iz := cz + dz
					if ix < 1 or iz < 1 or ix >= RES - 1 or iz >= RES - 1:
						continue
					var wx := -HALF + float(ix) * cell
					var wz := -HALF + float(iz) * cell
					var dist := Vector2(wx, wz).distance_to(Vector2(p.x, p.z))
					if dist > reach_m:
						continue
					var idx := iz * RES + ix
					if dist >= best_d[idx]:
						continue
					best_d[idx] = dist
					best_y[idx] = floor_y
	min_h = 1000.0
	max_h = -1000.0
	for i in heights.size():
		var dist := best_d[i]
		if dist > floor_r + wall:
			min_h = minf(min_h, heights[i])
			max_h = maxf(max_h, heights[i])
			continue
		var floor_y := best_y[i]
		var cap := high[i]
		if dist <= floor_r:
			heights[i] = minf(cap, floor_y)
			road_mask[i] = maxf(road_mask[i], 1.0)
		else:
			var u := (dist - floor_r) / wall
			var s := u * u * (3.0 - 2.0 * u)
			heights[i] = minf(cap, lerpf(floor_y, cap, s))
			if u < 0.4:
				road_mask[i] = maxf(road_mask[i], 1.0 - u)
		min_h = minf(min_h, heights[i])
		max_h = maxf(max_h, heights[i])
	blend_border()


func _highland_lift(x: float, z: float) -> float:
	var fade := _border_fade(x, z)
	if fade <= 0.001:
		return 0.0
	var w := region_weights(x, z)
	var salt := Util.smoothstep(0.34, 0.78, _mask.get_noise_2d(x, z)) * (0.35 + w.w * 0.65)
	var lift := 0.0
	for mesa in _mesas:
		var d: float = Vector2(x, z).distance_to(mesa.pos)
		var radius: float = mesa.radius
		if d >= radius:
			continue
		var shape := 0.0
		if bool(mesa.flat):
			shape = Util.smoothstep(radius, radius * 0.62, d)
		else:
			var u := 1.0 - d / radius
			shape = u * u
		lift += float(mesa.height) * shape * (1.0 - salt * 0.35)
	var ridged := pow(1.0 - absf(_ridge.get_noise_2d(x, z)), 1.7)
	var range_mask := Util.smoothstep(-0.05, 0.62, _range.get_noise_2d(x, z))
	var range_amp := lerpf(78.0, 130.0, clampf(w.y + w.z * 0.8, 0.0, 1.0))
	lift += ridged * range_mask * range_amp * (1.0 - salt * 0.15)
	return lift * fade


func _border_fade(x: float, z: float) -> float:
	var edge := minf(minf(x + HALF, HALF - x), minf(z + HALF, HALF - z))
	return Util.smoothstep(0.0, BORDER, edge)


func _height_from(grid: PackedFloat32Array, x: float, z: float) -> float:
	var gx := (x + HALF) / cell
	var gz := (z + HALF) / cell
	if gx < 0.0 or gz < 0.0 or gx > float(RES - 1) or gz > float(RES - 1):
		return waste_height(x, z)
	var x0 := clampi(int(floor(gx)), 0, RES - 2)
	var z0 := clampi(int(floor(gz)), 0, RES - 2)
	var tx := clampf(gx - float(x0), 0.0, 1.0)
	var tz := clampf(gz - float(z0), 0.0, 1.0)
	var h00 := grid[z0 * RES + x0]
	var h10 := grid[z0 * RES + x0 + 1]
	var h01 := grid[(z0 + 1) * RES + x0]
	var h11 := grid[(z0 + 1) * RES + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := 100000.0
	for i in range(pts.size() - 1):
		best = minf(best, _dist_to_seg(p, pts[i], pts[i + 1]))
	return best


func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _perlin(seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := _noise(seed, frequency, octaves)
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	return n


func _noise(seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	return n
