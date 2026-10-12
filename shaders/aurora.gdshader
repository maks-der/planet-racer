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
	float wave = fbm(vec2(across * 1.6 + TIME * 0.03, h * 2.4 + along * 0.35));
	float curtain = sin(across * 8.0 + wave * 4.5);
	curtain = smoothstep(0.05, 0.82, curtain * 0.5 + 0.5);
	float sheet = fbm(vec2(across * 2.4 - TIME * 0.02, h * 4.0 + 3.0));
	float band = smoothstep(-0.02, 0.16, h) * (1.0 - smoothstep(0.38, 0.72, h));
	float aurora = curtain * smoothstep(0.32, 0.72, sheet) * band;
	float hue = fbm(vec2(across * 0.7 + 4.0, 1.5));
	vec3 green = vec3(0.15, 0.95, 0.5);
	vec3 teal = vec3(0.15, 0.7, 1.0);
	vec3 violet = vec3(0.55, 0.22, 0.95);
	vec3 aurora_col = mix(green, teal, hue);
	aurora_col = mix(aurora_col, violet, smoothstep(0.5, 0.85, hue));
	col += aurora_col * aurora * 1.45;

	float curtain2 = sin(across * 4.5 + 1.8 + fbm(vec2(TIME * 0.04, across)) * 2.0);
	curtain2 = smoothstep(0.35, 0.9, curtain2 * 0.5 + 0.5);
	float band2 = smoothstep(0.08, 0.28, h) * (1.0 - smoothstep(0.48, 0.78, h));
	col += mix(teal, violet, 0.65) * curtain2 * band2 * 0.42;

	if (LIGHT0_ENABLED) {
		float moon = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
		col += vec3(0.35, 0.48, 0.7) * pow(moon, 6.0) * 0.12;
		col += vec3(0.82, 0.9, 1.0) * pow(moon, 220.0) * 1.1;
	}
	COLOR = col;
}
