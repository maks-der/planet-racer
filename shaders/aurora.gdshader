shader_type sky;

uniform vec2 wind_dir = vec2(0.9, 0.25);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.05 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	float h = EYEDIR.y;
	vec3 col = vec3(0.004, 0.006, 0.012);
	if (h >= 0.0) {
		col = mix(vec3(0.025, 0.05, 0.09), vec3(0.004, 0.006, 0.016), pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(vec3(0.015, 0.025, 0.04), vec3(0.004, 0.006, 0.01), pow(clamp(-h, 0.0, 1.0), 0.45));
	}

	vec3 dir = normalize(EYEDIR);
	vec3 cell = floor(dir * 110.0);
	vec3 gv = fract(dir * 110.0) - vec3(0.5);
	float star_n = hash21(cell.xy + cell.z * vec2(2.3, 5.1));
	float star = smoothstep(0.07, 0.0, length(gv)) * step(0.986, star_n);
	star *= 0.65 + 0.35 * sin(TIME * (1.4 + star_n * 3.0) + star_n * 30.0);
	col += vec3(0.75, 0.86, 1.0) * star * smoothstep(-0.08, 0.15, h);

	vec2 w = normalize(wind_dir + vec2(0.001));
	float across = dot(dir.xz, vec2(-w.y, w.x));
	float along = dot(dir.xz, w);
	float drift = TIME * 0.012;
	float rays = fbm(vec2(across * 2.4 + drift, h * 0.35 + along * 0.15));
	float sheet = fbm(vec2(across * 1.1 - drift * 0.6, h * 0.8 + 2.0));
	float columns = smoothstep(0.38, 0.78, fbm(vec2(across * 4.5 + rays, 1.7)));
	float hem = smoothstep(0.0, 0.16, h);
	float crown = 1.0 - smoothstep(0.16, 0.58, h);
	float veil = columns * hem * crown * smoothstep(0.28, 0.7, sheet);
	float rib = smoothstep(0.62, 0.95, sin(across * 14.0 + rays * 5.0) * 0.5 + 0.5);
	veil *= mix(0.42, 1.0, rib);
	vec3 green = vec3(0.22, 0.72, 0.38);
	vec3 pale = vec3(0.45, 0.78, 0.58);
	vec3 lower = vec3(0.48, 0.28, 0.42);
	vec3 aurora_col = mix(green, pale, rays);
	aurora_col = mix(lower, aurora_col, smoothstep(0.02, 0.2, h));
	col += aurora_col * veil * 0.42;
	float high = smoothstep(0.2, 0.34, h) * (1.0 - smoothstep(0.42, 0.7, h));
	float haze = smoothstep(0.45, 0.8, fbm(vec2(across * 0.7 - drift, along * 0.2 + 3.0)));
	col += vec3(0.16, 0.42, 0.32) * high * haze * 0.16;

	if (LIGHT0_ENABLED) {
		float moon = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
		col += vec3(0.35, 0.48, 0.7) * pow(moon, 6.0) * 0.12;
		col += vec3(0.82, 0.9, 1.0) * pow(moon, 220.0) * 1.1;
	}
	COLOR = col;
}
