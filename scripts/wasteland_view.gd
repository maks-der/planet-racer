class_name WastelandView
extends Node3D

const CHUNK := 350.0
const CELLS := 16
const RING := 3

var terrain: TerrainField
var _chunks: Dictionary = {}
var _player_cell := Vector2i(99999, 99999)


func build(field: TerrainField, host: Node = null) -> void:
	terrain = field
	name = "Wasteland"
	var core := int(TerrainField.HALF / CHUNK)
	for iz in range(-core - RING, core + RING):
		for ix in range(-core - RING, core + RING):
			if _fully_inside(ix, iz):
				continue
			_ensure(ix, iz)
			if host != null:
				host.arrival.set_progress(0.9 + 0.08 * float(iz + core + RING) / float((core + RING) * 2), "STIRRING THE WASTES")
				await host.get_tree().process_frame


func follow(pos: Vector3) -> void:
	var cell := Vector2i(int(floor(pos.x / CHUNK)), int(floor(pos.z / CHUNK)))
	if cell == _player_cell:
		return
	_player_cell = cell
	var keep := {}
	for iz in range(cell.y - 3, cell.y + 4):
		for ix in range(cell.x - 3, cell.x + 4):
			if _fully_inside(ix, iz):
				continue
			_ensure(ix, iz)
			keep[_key(ix, iz)] = true
	var stale: Array = []
	for key in _chunks.keys():
		if keep.has(key) or _is_skirt(key):
			continue
		stale.append(key)
	for key in stale:
		var inst: Node = _chunks[key]
		if is_instance_valid(inst):
			inst.queue_free()
		_chunks.erase(key)


func _fully_inside(ix: int, iz: int) -> bool:
	var min_x := float(ix) * CHUNK
	var max_x := min_x + CHUNK
	var min_z := float(iz) * CHUNK
	var max_z := min_z + CHUNK
	var core := TerrainField.HALF
	return max_x <= core and min_x >= -core and max_z <= core and min_z >= -core


func _is_skirt(key: int) -> bool:
	var ix := int(key / 100000) - 5000
	var iz := key % 100000 - 5000
	var min_x := float(ix) * CHUNK
	var max_x := min_x + CHUNK
	var min_z := float(iz) * CHUNK
	var max_z := min_z + CHUNK
	var outer := TerrainField.HALF + float(RING) * CHUNK
	if _fully_inside(ix, iz):
		return false
	return min_x >= -outer - 0.1 and max_x <= outer + 0.1 and min_z >= -outer - 0.1 and max_z <= outer + 0.1


func _key(ix: int, iz: int) -> int:
	return (ix + 5000) * 100000 + (iz + 5000)


func _ensure(ix: int, iz: int) -> void:
	var key := _key(ix, iz)
	if _chunks.has(key):
		return
	var inst := MeshInstance3D.new()
	inst.name = "Waste_%d_%d" % [ix, iz]
	inst.mesh = _mesh(float(ix) * CHUNK, float(iz) * CHUNK)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	inst.material_override = mat
	add_child(inst)
	_chunks[key] = inst


func _mesh(origin_x: float, origin_z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := CHUNK / float(CELLS)
	for z in CELLS + 1:
		for x in CELLS + 1:
			var wx := origin_x + float(x) * step
			var wz := origin_z + float(z) * step
			var h := terrain.waste_height(wx, wz)
			var normal := terrain.normal_at(wx, wz)
			var ash := terrain.ground_color(wx, wz, h, normal, 0.0)
			ash = ash.lerp(Color(0.34, 0.28, 0.22), clampf((h - 8.0) / 30.0, 0.0, 0.35))
			st.set_normal(normal)
			st.set_color(Color(ash.r, ash.g, ash.b, 1.0 - normal.y))
			st.set_uv(Vector2(wx, wz) * 0.02)
			st.add_vertex(Vector3(wx, h, wz))
	var stride := CELLS + 1
	for z in CELLS:
		for x in CELLS:
			var i00 := z * stride + x
			var i10 := i00 + 1
			var i01 := i00 + stride
			var i11 := i01 + 1
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)
	return st.commit()
