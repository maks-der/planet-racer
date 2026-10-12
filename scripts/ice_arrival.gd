class_name IceArrival
extends ArrivalLoading


func _init() -> void:
	voyage_time = 8.6
	fade_time = 1.8
	_wash = Color(0.02, 0.04, 0.09)
	planet_node_name = "IcePlanet"
	planet_pos = Vector3(-7.4, -4.6, -2.2)
	planet_scale = Vector3(1.72, 1.72, 1.72)
	ship_scale = Vector3(0.62, 0.62, 0.62)
	approach_from = Vector3(8.6, -1.35, 10.4)
	approach_to = Vector3(1.6, 0.35, 4.8)
	cam_from = Vector3(6.8, 2.6, 17.2)
	cam_to = Vector3(3.4, 1.05, 12.4)
	look_from = Vector3(-2.2, -0.4, -1.2)
	look_to = Vector3(0.4, 0.15, 2.6)
	cam_fov = 42.0
	cam_roll = -7.0
	title_color = Color(0.78, 0.9, 1.0)


func _ready() -> void:
	super._ready()
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.look_at(sun.global_position + Vector3(-1.0, -0.12, -0.2), Vector3.UP)
