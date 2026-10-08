class_name Util
extends RefCounted

static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var span := edge1 - edge0
	if absf(span) < 0.00001:
		return 0.0
	var t := clampf((x - edge0) / span, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func yaw_from_forward(fwd: Vector3) -> float:
	return atan2(-fwd.x, -fwd.z)


static func forward_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func right_from_yaw(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--"
	var m := int(t) / 60
	var s := t - float(m * 60)
	return "%d:%05.2f" % [m, s]


static func place_text(n: int) -> String:
	match n:
		1:
			return "1ST"
		2:
			return "2ND"
		3:
			return "3RD"
		_:
			return "%dTH" % n


static func km(meters: float) -> String:
	return "%.1f km" % (meters / 1000.0)
