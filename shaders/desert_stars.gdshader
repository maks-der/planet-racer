shader_type spatial;
render_mode unshaded, cull_front;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

vec3 star_layer(vec2 suv, float scale, float threshold, float radius) {
	vec2 grid = suv * scale;
	vec2 cell = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);
	float n = hash21(cell);
	float dist = length(gv);
	float spark = smoothstep(radius, 0.0, dist) * step(threshold, n);
	float mag = spark * mix(0.35, 1.0, smoothstep(threshold, 1.0, n));
	vec3 tint = vec3(0.96, 0.94, 0.88);
	if (n > 0.985) {
		tint = vec3(1.0, 0.82, 0.55);
	} else if (n > 0.965) {
		tint = vec3(0.72, 0.84, 1.0);
	}
	float glow = smoothstep(radius * 2.4, radius * 0.35, dist) * step(threshold + 0.03, n);
	return tint * (mag + glow * 0.22);
}

void fragment() {
	vec3 dir = normalize(VERTEX);
	float lift = smoothstep(-0.2, 0.55, dir.y);
	vec3 col = mix(vec3(0.045, 0.018, 0.008), vec3(0.0, 0.0, 0.008), lift);
	col += vec3(0.16, 0.05, 0.015) * smoothstep(0.25, -0.45, dir.y);
	vec2 suv = vec2(atan(dir.x, dir.z) * 0.15915 + 0.5, asin(clamp(dir.y, -1.0, 1.0)) * 0.31831 + 0.5);
	vec3 points = star_layer(suv + vec2(0.17, 0.63), 720.0, 0.82, 0.1);
	points += star_layer(suv + vec2(0.48, 0.09), 340.0, 0.9, 0.15);
	points += star_layer(suv + vec2(0.81, 0.37), 120.0, 0.955, 0.24);
	vec3 focus = normalize(vec3(-0.42, 0.38, 0.82));
	float lobe = pow(clamp(dot(dir, focus), 0.0, 1.0), 5.0);
	points += star_layer(suv + vec2(0.05, 0.22), 220.0, 0.78, 0.12) * lobe * 1.6;
	col += points;
	ALBEDO = col;
	EMISSION = points * 0.4;
}
