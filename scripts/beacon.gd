extends Node3D


func _process(dt: float) -> void:
	var ring := get_node_or_null("Ring") as Node3D
	if ring:
		ring.rotate_y(dt * 0.55)
