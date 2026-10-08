class_name DesertView
extends RefCounted

const ROCK_SCENES: Array[PackedScene] = [
	preload("res://scenes/props/rock_a.tscn"),
	preload("res://scenes/props/rock_b.tscn"),
	preload("res://scenes/props/rock_c.tscn"),
	preload("res://scenes/props/rock_d.tscn"),
]
const POST_SCENE := preload("res://scenes/props/marker_post.tscn")
const ARCH_SCENE := preload("res://scenes/props/tunnel_arch.tscn")

static var solids: Array = []


static func build(parent: Node3D, terrain: TerrainField, roads: RoadNetwork, host: Node = null) -> void:
	solids = []
	await _add_terrain(parent, terrain, host)
	if host != null:
		host.arrival.set_progress(0.74, "THREADING ROADS")
		await host.get_tree().process_frame
	await _add_roads(parent, roads, terrain, host)
	if host != null:
		host.arrival.set_progress(0.88, "SETTLING ROCK")
		await host.get_tree().process_frame
	await _add_rocks(parent, terrain, roads, host)
	_add_scrub(parent, terrain, roads)
	if host != null:
		host.arrival.set_progress(0.9, "OPENING THE WASTES")


static func _add_terrain(parent: Node3D, terrain: TerrainField, host: Node = null) -> void:
	var root := Node3D.new()
	root.name = "Terrain"
	parent.add_child(root)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var quads := TerrainField.RES - 1
	const CHUNK := 80
	var chunks := int(ceil(float(quads) / float(CHUNK)))
	for cz in chunks:
		for cx in chunks:
			var x0 := cx * CHUNK
			var z0 := cz * CHUNK
			var x1 := mini(x0 + CHUNK, quads)
			var z1 := mini(z0 + CHUNK, quads)
			var inst := MeshInstance3D.new()
			inst.name = "Chunk_%d_%d" % [cx, cz]
			inst.mesh = await _terrain_chunk(terrain, x0, z0, x1, z1, host)
			inst.material_override = mat
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			root.add_child(inst)
			if host != null:
				host.arrival.set_progress(0.5 + 0.22 * float(cz * chunks + cx + 1) / float(chunks * chunks), "SHAPING THE SURFACE")
				await host.get_tree().process_frame


static func _terrain_chunk(terrain: TerrainField, x0: int, z0: int, x1: int, z1: int, host: Node = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var res := TerrainField.RES
	var half := TerrainField.HALF
	var cell := terrain.cell
	var stride := x1 - x0 + 1
	var z := z0
	while z <= z1:
		var z_stop := mini(z + 4, z1 + 1)
		for zz in range(z, z_stop):
			for x in range(x0, x1 + 1):
				var wx := -half + float(x) * cell
				var wz := -half + float(zz) * cell
				var h: float = terrain.heights[zz * res + x]
				var normal := terrain.normal_at(wx, wz)
				var col := terrain.ground_color(wx, wz, h, normal, terrain.road_factor(wx, wz))
				st.set_normal(normal)
				st.set_color(Color(col.r, col.g, col.b, 1.0 - normal.y))
				st.set_uv(Vector2(wx, wz) * 0.05)
				st.add_vertex(Vector3(wx, h, wz))
		z = z_stop
		if host != null and z <= z1:
			await host.get_tree().process_frame
	for qz in range(z0, z1):
		for x in range(x0, x1):
			var i00 := (qz - z0) * stride + (x - x0)
			var i10 := i00 + 1
			var i01 := i00 + stride
			var i11 := i01 + 1
			# Godot front faces are clockwise. This winding faces upward.
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)
	return st.commit()


static func _add_roads(parent: Node3D, roads: RoadNetwork, _terrain: TerrainField, host: Node = null) -> void:
	var root := Node3D.new()
	root.name = "Roadside"
	parent.add_child(root)
	await _place_arches(root, roads, host)
	await _place_posts(root, roads, host)


static func _place_arches(root: Node3D, roads: RoadNetwork, host: Node = null) -> void:
	var placed: Array[Vector3] = []
	var xforms: Array[Transform3D] = []
	var steps := 0
	for edge in roads.edges:
		var pts: PackedVector3Array = edge.points
		var kinds: PackedByteArray = edge.kinds
		var radius := float(edge.width) * 0.5 + 2.6
		var i := 0
		while i < pts.size():
			if int(kinds[i]) != RoadNetwork.KIND_TUNNEL:
				i += 1
				continue
			var j := i
			while j < pts.size() and int(kinds[j]) == RoadNetwork.KIND_TUNNEL:
				j += 1
			var cursor := float(i)
			while cursor < float(j - 1):
				var at := int(round(cursor))
				at = clampi(at, i, j - 1)
				var pos := pts[at]
				var crowded := false
				for prev in placed:
					if prev.distance_to(pos) < 16.0:
						crowded = true
						break
				if not crowded:
					var fwd := _flat_forward(pts, at)
					var side := fwd.cross(Vector3.UP)
					if side.length_squared() < 0.0001:
						side = Vector3.RIGHT
					side = side.normalized()
					var basis := Basis(side, Vector3.UP, -fwd)
					basis.x *= radius
					basis.y *= radius * 0.82
					basis.z *= 15.5
					xforms.append(Transform3D(basis, Vector3(pos.x, pos.y + 0.35, pos.z)))
					for sign in [-1.0, 1.0]:
						var leg: Vector3 = side * float(sign) * 0.92 * radius
						solids.append({
							"x": pos.x + leg.x,
							"y": pos.y + radius * 0.32,
							"z": pos.z + leg.z,
							"r": 1.7,
							"h": radius * 0.5,
						})
					placed.append(pos)
				cursor += 3.4
				steps += 1
				if host != null and steps % 12 == 0:
					await host.get_tree().process_frame
			i = j
	var baked: Dictionary = _bake_merged(ARCH_SCENE)
	_paint(root, "Arches", baked.mesh, baked.material, xforms)


static func _place_posts(root: Node3D, roads: RoadNetwork, host: Node = null) -> void:
	var parts: Array = _bake_parts(POST_SCENE)
	var stake_xf: Array[Transform3D] = []
	var stake_col: Array[Color] = []
	var cap_xf: Array[Transform3D] = []
	var cap_col: Array[Color] = []
	var stake_base: Color = (parts[0].material as StandardMaterial3D).albedo_color
	var cap_base: Color = (parts[1].material as StandardMaterial3D).albedo_color
	var crossings := _crossing_points(roads)
	for edge in roads.edges:
		var pts: PackedVector3Array = edge.points
		var kinds: PackedByteArray = edge.kinds
		var shoulder := float(edge.width) * 0.58
		var tint := Color(0.72, 0.48, 0.28) if bool(edge.shortcut) else Color(0.85, 0.75, 0.62)
		var clear := float(edge.width) * 0.5 + 28.0
		for i in range(0, pts.size(), 8):
			if int(kinds[i]) != RoadNetwork.KIND_ROAD:
				continue
			var center := Vector2(pts[i].x, pts[i].z)
			if _near_points(center, crossings, clear):
				continue
			var ground := roads.terrain.height_at(pts[i].x, pts[i].z)
			if pts[i].y > ground + 1.8:
				continue
			var fwd := _flat_forward(pts, i)
			var side := fwd.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized()
			for sign in [-1.0, 1.0]:
				var pos: Vector3 = pts[i] + side * shoulder * float(sign)
				if roads.on_roadway(pos.x, pos.z):
					continue
				var foot := roads.terrain.height_at(pos.x, pos.z)
				if pos.y > foot + 1.8:
					continue
				var root_xf := Transform3D(Basis.IDENTITY, pos)
				stake_xf.append(root_xf * (parts[0].local as Transform3D))
				stake_col.append(stake_base.lerp(tint, 0.55))
				cap_xf.append(root_xf * (parts[1].local as Transform3D))
				cap_col.append(cap_base.lerp(tint, 0.55))
				solids.append({
					"x": pos.x,
					"y": pos.y + 0.75,
					"z": pos.z,
					"r": 0.85,
					"h": 1.6,
				})
		if host != null:
			await host.get_tree().process_frame
	_paint(root, "Stakes", parts[0].mesh, _vertex_tint(parts[0].material), stake_xf, stake_col)
	_paint(root, "Caps", parts[1].mesh, _vertex_tint(parts[1].material), cap_xf, cap_col)


static func _crossing_points(roads: RoadNetwork) -> PackedVector2Array:
	var out := roads.node_xz.duplicate()
	var edges: Array = roads.edges
	for a in edges.size():
		var ea: Dictionary = edges[a]
		var pa: PackedVector3Array = ea.points
		var wa := float(ea.width) * 0.5
		for b in range(a + 1, edges.size()):
			var eb: Dictionary = edges[b]
			var pb: PackedVector3Array = eb.points
			var reach := wa + float(eb.width) * 0.5 + 4.0
			var step := 4
			for i in range(step, pa.size() - step, step):
				var p := Vector2(pa[i].x, pa[i].z)
				for j in range(step, pb.size() - step, step):
					var q := Vector2(pb[j].x, pb[j].z)
					if p.distance_squared_to(q) > reach * reach:
						continue
					var da := Vector2(pa[i].x - pa[i - step].x, pa[i].z - pa[i - step].z)
					var db := Vector2(pb[j].x - pb[j - step].x, pb[j].z - pb[j - step].z)
					if da.length_squared() < 0.01 or db.length_squared() < 0.01:
						continue
					if absf(da.normalized().dot(db.normalized())) > 0.82:
						continue
					out.append((p + q) * 0.5)
					break
	return out


static func _near_points(p: Vector2, points: PackedVector2Array, clearance: float) -> bool:
	var limit := clearance * clearance
	for q in points:
		if p.distance_squared_to(q) < limit:
			return true
	return false


static func _add_rocks(parent: Node3D, terrain: TerrainField, roads: RoadNetwork, host: Node = null) -> void:
	var root := Node3D.new()
	root.name = "Rocks"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed := 0
	var tries := 0
	var span := TerrainField.HALF * 0.78
	var rock_xf: Array = [[], [], [], []]
	var rock_col: Array = [[], [], [], []]
	var rock_bake: Array = []
	for scene in ROCK_SCENES:
		rock_bake.append(_bake_merged(scene))
	while placed < 220 and tries < 1800:
		tries += 1
		var p := Vector2(rng.randf_range(-span, span), rng.randf_range(-span, span))
		if roads.distance_to_road(p.x, p.y) < 36.0:
			continue
		var h := terrain.height_at(p.x, p.y)
		var slope := terrain.slope_at(p.x, p.y)
		if h < 2.3 and slope < 0.2:
			continue
		if slope < 0.18 and rng.randf() > 0.22:
			continue
		var variant := rng.randi_range(0, ROCK_SCENES.size() - 1)
		var s := rng.randf_range(2.2, 6.5)
		if slope > 0.28 and rng.randf() > 0.4:
			s *= rng.randf_range(2.2, 4.4)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0))
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.72, 1.2), s))
		rock_xf[variant].append(Transform3D(basis, Vector3(p.x, h - 0.35, p.y)))
		var tint := terrain.ground_color(p.x, p.y, h, terrain.normal_at(p.x, p.y), 0.0)
		var base: Color = (rock_bake[variant].material as StandardMaterial3D).albedo_color
		rock_col[variant].append(base.lerp(tint.lerp(Color(0.45, 0.28, 0.18), 0.45), 0.7))
		solids.append({
			"x": p.x,
			"y": h + s * 0.45,
			"z": p.y,
			"r": s * 0.85,
			"h": s * 1.4,
		})
		placed += 1
	await _scatter_cliff_rocks(terrain, rng, rock_xf, rock_col, rock_bake, host)
	for variant in ROCK_SCENES.size():
		var baked: Dictionary = rock_bake[variant]
		var tinted := _vertex_tint(baked.material)
		_paint(root, "Rock%d" % variant, baked.mesh, tinted, rock_xf[variant], rock_col[variant])


static func _scatter_cliff_rocks(terrain: TerrainField, rng: RandomNumberGenerator, rock_xf: Array, rock_col: Array, rock_bake: Array, host: Node) -> void:
	var cliff_ny := 0.5
	var stride := 4
	var budget := 1600
	var placed := 0
	var rows := 0
	var half := TerrainField.HALF
	var cell := terrain.cell
	var res := TerrainField.RES
	for z in range(4, res - 4, stride):
		for x in range(4, res - 4, stride):
			if placed >= budget:
				break
			var wx := -half + float(x) * cell
			var wz := -half + float(z) * cell
			var n := terrain.normal_at(wx, wz)
			if n.y >= cliff_ny:
				continue
			if terrain.road_factor(wx, wz) > 0.15:
				continue
			var steepness := clampf((cliff_ny - n.y) / cliff_ny, 0.0, 1.0)
			if rng.randf() > lerpf(0.42, 1.0, steepness):
				continue
			var cluster := 3 + int(steepness * 3.0)
			for _k in cluster:
				if placed >= budget:
					break
				var px := wx + rng.randf_range(-7.0, 7.0)
				var pz := wz + rng.randf_range(-7.0, 7.0)
				var hn := terrain.normal_at(px, pz)
				if hn.y >= cliff_ny + 0.06:
					continue
				if terrain.road_factor(px, pz) > 0.2:
					continue
				var hh := terrain.height_at(px, pz)
				var s := rng.randf_range(0.85, 2.2) + steepness * rng.randf_range(0.3, 2.6)
				var y_axis := hn.normalized()
				var x_axis := y_axis.cross(Vector3(0.0, 0.0, 1.0))
				if x_axis.length_squared() < 0.001:
					x_axis = Vector3.RIGHT
				x_axis = x_axis.normalized()
				var z_axis := x_axis.cross(y_axis).normalized()
				var spin := Basis(x_axis, y_axis, z_axis).rotated(y_axis, rng.randf() * TAU)
				spin = spin.scaled(Vector3(s, s * rng.randf_range(0.62, 1.15), s))
				var variant := rng.randi_range(0, ROCK_SCENES.size() - 1)
				var pos := Vector3(px, hh, pz) - y_axis * (0.2 * s)
				rock_xf[variant].append(Transform3D(spin, pos))
				var tint := terrain.ground_color(px, pz, hh, hn, 0.0)
				var base: Color = (rock_bake[variant].material as StandardMaterial3D).albedo_color
				rock_col[variant].append(base.lerp(tint.lerp(Color(0.42, 0.26, 0.16), 0.5), 0.75))
				solids.append({
					"x": pos.x,
					"y": pos.y + s * 0.35,
					"z": pos.z,
					"r": s * 0.72,
					"h": s * 1.1,
				})
				placed += 1
		rows += 1
		if host != null and rows % 8 == 0:
			await host.get_tree().process_frame
		if placed >= budget:
			break


static func _add_scrub(parent: Node3D, terrain: TerrainField, roads: RoadNetwork) -> void:
	var root := Node3D.new()
	root.name = "Scrub"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	var bushes: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var trees: Array[Transform3D] = []
	var tree_colors: Array[Color] = []
	var span := TerrainField.HALF * 0.84
	var tries := 0
	while bushes.size() < 170 and tries < 1400:
		tries += 1
		var p := Vector2(rng.randf_range(-span, span), rng.randf_range(-span, span))
		if roads.distance_to_road(p.x, p.y) < 28.0:
			continue
		if terrain.slope_at(p.x, p.y) > 0.22:
			continue
		var w := terrain.region_weights(p.x, p.y)
		if w.w + w.x < 0.35 and rng.randf() > 0.15:
			continue
		var h := terrain.height_at(p.x, p.y)
		var s := rng.randf_range(0.7, 1.6)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(s, s * rng.randf_range(0.75, 1.25), s))
		bushes.append(Transform3D(basis, Vector3(p.x, h, p.y)))
		bush_colors.append(Color(0.46, 0.32, 0.16).lerp(Color(0.28, 0.34, 0.16), w.w * 0.45))
	tries = 0
	while trees.size() < 16 and tries < 700:
		tries += 1
		var p2 := Vector2(rng.randf_range(-span, span), rng.randf_range(-span, span))
		if roads.distance_to_road(p2.x, p2.y) < 40.0:
			continue
		if terrain.slope_at(p2.x, p2.y) > 0.1:
			continue
		if terrain.region_weights(p2.x, p2.y).w < 0.28:
			continue
		var h2 := terrain.height_at(p2.x, p2.y)
		var s2 := rng.randf_range(1.4, 2.4)
		var basis2 := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(s2, s2, s2))
		trees.append(Transform3D(basis2, Vector3(p2.x, h2, p2.y)))
		tree_colors.append(Color(0.32, 0.52, 0.24).lerp(Color(0.55, 0.38, 0.18), rng.randf() * 0.25))
	_scatter(root, "Brush", _bush_mesh(), bushes, bush_colors)
	_scatter(root, "Trees", _tree_mesh(), trees, tree_colors)


static var _baked: Dictionary = {}


static func _bake_merged(scene: PackedScene) -> Dictionary:
	var path := scene.resource_path + "#merged"
	if _baked.has(path):
		return _baked[path]
	var node := scene.instantiate() as Node3D
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	for child in node.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		if mat == null:
			var src := mi.get_surface_override_material(0)
			if src != null:
				mat = src.duplicate()
		st.append_from(mi.mesh, 0, mi.transform)
	node.free()
	var data := {"mesh": st.commit(), "material": mat}
	_baked[path] = data
	return data


static func _bake_parts(scene: PackedScene) -> Array:
	var path := scene.resource_path + "#parts"
	if _baked.has(path):
		return _baked[path]
	var node := scene.instantiate() as Node3D
	var parts: Array = []
	for child in node.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var src := mi.get_surface_override_material(0)
		parts.append({
			"mesh": mi.mesh,
			"local": mi.transform,
			"material": src.duplicate() if src != null else null,
		})
	node.free()
	_baked[path] = parts
	return parts


static func _vertex_tint(mat: Material) -> StandardMaterial3D:
	var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	copy.vertex_color_use_as_albedo = true
	copy.albedo_color = Color.WHITE
	return copy


static func _paint(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, xforms: Array, colors: Array = []) -> void:
	if xforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var tinted := not colors.is_empty()
	multi.use_colors = tinted
	multi.instance_count = xforms.size()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		if tinted:
			multi.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = multi
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


static func _scatter(parent: Node3D, node_name: String, mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	if xforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = xforms.size()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		multi.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = multi
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


static func _bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	st.set_material(mat)
	for i in 4:
		var yaw := float(i) * TAU / 4.0
		var lean := Transform3D(Basis.from_euler(Vector3(0.55, yaw, 0.12)), Vector3.ZERO)
		_prism(st, lean, 0.035, 1.15)
	return st.commit()


static func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	mat.vertex_color_use_as_albedo = true
	st.set_material(mat)
	_prism(st, Transform3D.IDENTITY, 0.11, 1.55)
	_blob(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.65, 0.0)), 0.72)
	return st.commit()


static func _prism(st: SurfaceTool, xform: Transform3D, radius: float, height: float) -> void:
	var top := xform * Vector3(0.0, height, 0.0)
	var ring: Array[Vector3] = []
	for i in 5:
		var a := float(i) * TAU / 5.0
		ring.append(xform * Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i in 5:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 5]
		st.set_color(Color(1, 1, 1))
		st.add_vertex(xform.origin)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(top)
		st.add_vertex(p1)
		st.add_vertex(p0)


static func _blob(st: SurfaceTool, xform: Transform3D, radius: float) -> void:
	var center := xform.origin
	for i in 6:
		var a := float(i) * TAU / 6.0
		var b := float(i + 1) * TAU / 6.0
		var p0 := center + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var p1 := center + Vector3(cos(b) * radius, 0.0, sin(b) * radius)
		var tip := center + Vector3(0.0, radius * 0.9, 0.0)
		st.set_color(Color(1, 1, 1))
		st.add_vertex(center)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(tip)
		st.add_vertex(p1)
		st.add_vertex(p0)


static func _flat_forward(pts: PackedVector3Array, i: int) -> Vector3:
	var fwd := Vector3.FORWARD
	if i == 0:
		fwd = pts[1] - pts[0]
	elif i == pts.size() - 1:
		fwd = pts[i] - pts[i - 1]
	else:
		fwd = pts[i + 1] - pts[i - 1]
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return fwd.normalized()
