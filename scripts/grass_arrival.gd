class_name GrassArrival
extends ArrivalLoading


func _init() -> void:
	voyage_time = 8.2
	fade_time = 1.8
	_wash = Color(0.45, 0.64, 0.86)
	planet_node_name = "GrassPlanet"
	planet_pos = Vector3(6.6, -4.2, -1.4)
	planet_scale = Vector3(1.58, 1.58, 1.58)
	ship_scale = Vector3(0.68, 0.68, 0.68)
	approach_from = Vector3(-7.2, -0.85, 9.6)
	approach_to = Vector3(-1.4, 0.45, 4.4)
	cam_from = Vector3(-8.0, 8.6, 48.0)
	cam_to = Vector3(-3.2, 5.4, 41.0)
	look_from = Vector3(5.2, -1.6, -0.6)
	look_to = Vector3(3.8, -0.8, 0.4)
	cam_fov = 42.0
	cam_roll = 6.0
	title_color = Color(0.86, 0.95, 0.72)


func _ready() -> void:
	super._ready()
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.look_at(sun.global_position + Vector3(0.55, -0.28, -0.5), Vector3.UP)
