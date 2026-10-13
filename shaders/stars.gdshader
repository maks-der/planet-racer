shader_type spatial;
render_mode unshaded, cull_front;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 star_layer(vec2 suv, float scale, float threshold, float radius) {
	vec2 grid = suv * scale;
	vec2 cell = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);
	float n = hash21(cell);
	float dist = length(gv);
	float spark = smoothstep(radius, 0.0, dist) * step(threshold, n);
	float mag = spark * mix(0.22, 1.0, smoothstep(threshold, 1.0, n));
	vec3 tint = vec3(0.94, 0.95, 1.0);
	if (n > 0.992) {
		tint = vec3(1.0, 0.93, 0.78);
	} else if (n > 0.978) {
		tint = vec3(0.72, 0.82, 1.0);
	}
	return tint * mag;
}

void fragment() {
	vec3 dir = normalize(VERTEX);
	float lift = smoothstep(-0.42, 0.28, dir.y);
	vec3 col = mix(vec3(0.004, 0.005, 0.012), vec3(0.012, 0.016, 0.03), lift);
	vec2 suv = vec2(atan(dir.x, dir.z) * 0.15915 + 0.5, asin(clamp(dir.y, -1.0, 1.0)) * 0.31831 + 0.5);
	vec3 points = star_layer(suv, 2600.0, 0.9, 0.14);
	points += star_layer(suv + vec2(0.13, 0.27), 1800.0, 0.94, 0.12);
	col += points;
	ALBEDO = col;
	EMISSION = points * 0.25;
}
