shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.1, 0.24, 0.58);
uniform vec3 sky_horizon : source_color = vec3(0.98, 0.52, 0.24);
uniform vec3 ground_horizon : source_color = vec3(0.82, 0.4, 0.2);
uniform vec3 ground_bottom : source_color = vec3(0.38, 0.2, 0.12);
uniform float cloud_cover = 0.42;
uniform vec2 cloud_scroll = vec2(0.015, 0.006);
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
	float a = 0.52;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = rot * p * 2.05 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	float h = EYEDIR.y;
	vec3 col = ground_bottom;
	if (h >= 0.0) {
		col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(ground_horizon, ground_bottom, pow(clamp(-h, 0.0, 1.0), 0.4));
	}
	if (h > 0.02) {
		vec2 uv = EYEDIR.xz * (22.0 / (0.28 + h));
		float base = fbm(uv * 0.85 + cloud_scroll * TIME);
		float detail = fbm(uv * 2.1 - cloud_scroll.yx * TIME * 1.6);
		float n = base * 0.68 + detail * 0.32;
		float lift = smoothstep(0.06, 0.42, h);
		float body = smoothstep(cloud_cover, cloud_cover + 0.34, n) * lift;
		float blush = smoothstep(0.5, 0.78, fbm(uv * 0.18 + vec2(3.0, 8.0)));
		vec3 puff = mix(vec3(1.0, 0.97, 0.92), vec3(0.98, 0.75, 0.72), blush * 0.62);
		col = mix(col, vec3(0.78, 0.62, 0.52), body * 0.18);
		col = mix(col, puff, smoothstep(0.22, 0.8, body) * 0.82);
		vec2 w = normalize(wind_dir);
		float across = dot(uv, vec2(-w.y, w.x));
		float along = dot(uv, w) - TIME * 1.6;
		float streak = smoothstep(0.78, 0.97, sin(across * 9.0) * 0.5 + 0.5);
		streak *= smoothstep(0.55, 0.92, sin(along * 3.0) * 0.5 + 0.5);
		col += vec3(1.0, 0.94, 0.86) * streak * lift * 0.07;
	}
	if (LIGHT0_ENABLED) {
		float sun_d = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
		col += vec3(1.0, 0.62, 0.28) * pow(sun_d, 12.0) * 0.28;
		col += vec3(1.0, 0.82, 0.5) * pow(sun_d, 64.0) * 1.35;
	}
	COLOR = col;
}
