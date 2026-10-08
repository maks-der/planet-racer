shader_type spatial;
render_mode unshaded, cull_front;

vec3 star_tint(float n) {
	float h = fract(n * 17.13);
	if (h < 0.2) {
		return vec3(0.25, 0.55, 1.0);
	}
	if (h < 0.38) {
		return vec3(1.0, 0.72, 0.15);
	}
	if (h < 0.56) {
		return vec3(1.0, 0.28, 0.62);
	}
	if (h < 0.74) {
		return vec3(0.15, 1.0, 0.82);
	}
	if (h < 0.9) {
		return vec3(1.0, 0.32, 0.12);
	}
	return vec3(0.96, 0.97, 1.0);
}

void fragment() {
	vec2 grid = UV * vec2(520.0, 260.0);
	vec2 cell = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);
	float n = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float twinkle = 0.55 + 0.45 * sin(TIME * (1.1 + n * 2.8) + n * 40.0);
	float dist = length(gv);
	vec3 tint = star_tint(n);
	float spark = smoothstep(0.28, 0.02, dist) * step(0.955, n);
	float halo = smoothstep(0.55, 0.08, dist) * step(0.985, n);
	vec3 col = tint * spark * twinkle + tint * halo * 0.55;
	ALBEDO = col;
	EMISSION = col * 3.2;
}
