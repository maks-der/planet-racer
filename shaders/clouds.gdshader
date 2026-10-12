shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.1, 0.24, 0.58);
uniform vec3 sky_horizon : source_color = vec3(0.98, 0.52, 0.24);
uniform vec3 ground_horizon : source_color = vec3(0.82, 0.4, 0.2);
uniform vec3 ground_bottom : source_color = vec3(0.38, 0.2, 0.12);
uniform float cloud_cover = 0.42;
uniform float cold = 0.0;
uniform float meadow = 0.0;
uniform float sunset = 0.0;
uniform float fluffy = 0.0;
uniform vec3 moon_dir = vec3(-0.42, 0.55, -0.72);
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
		if (sunset > 0.5 && LIGHT0_ENABLED) {
			float ang = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
			float u = clamp(ang / 1.55, 0.0, 1.0);
			vec3 yellow = vec3(1.0, 0.74, 0.22);
			vec3 orange = vec3(0.95, 0.4, 0.08);
			vec3 red = vec3(0.72, 0.14, 0.1);
			vec3 purple = vec3(0.32, 0.1, 0.36);
			col = mix(yellow, orange, smoothstep(0.02, 0.2, u));
			col = mix(col, red, smoothstep(0.14, 0.38, u));
			col = mix(col, purple, smoothstep(0.32, 0.6, u));
			col = mix(col, sky_top, smoothstep(0.5, 0.92, u));
		}
	} else {
		col = mix(ground_horizon, ground_bottom, pow(clamp(-h, 0.0, 1.0), 0.4));
	}
	if (cold > 0.5) {
		if (h > 0.0) {
			vec2 uv = EYEDIR.xz * (18.0 / (0.12 + h));
			vec2 w = normalize(wind_dir + vec2(0.001));
			float across = dot(uv, vec2(-w.y, w.x));
			float along = dot(uv, w);
			float wisps = fbm(vec2(across * 0.07, along * 0.5 + TIME * 0.015));
			float cirrus = smoothstep(0.56, 0.88, wisps);
			float high = smoothstep(0.03, 0.28, h) * (1.0 - smoothstep(0.78, 0.98, h));
			col = mix(col, vec3(0.97, 0.98, 1.0), cirrus * high * 0.72);
		}
		if (LIGHT0_ENABLED) {
			float sun_d = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
			col += vec3(0.72, 0.84, 1.0) * pow(sun_d, 6.0) * 0.2;
			col += vec3(1.0, 0.98, 0.96) * pow(sun_d, 90.0) * 1.55;
		}
	} else {
		if (h > 0.02) {
			vec2 uv = EYEDIR.xz * (22.0 / (0.28 + h));
			float base = fbm(uv * 0.85 + cloud_scroll * TIME);
			float detail = fbm(uv * 2.1 - cloud_scroll.yx * TIME * 1.6);
			float n = base * 0.68 + detail * 0.32;
			float lift = smoothstep(0.06, 0.42, h);
			if (sunset > 0.5) {
				lift = smoothstep(0.02, 0.28, h);
			}
			float body = smoothstep(cloud_cover, cloud_cover + 0.34, n) * lift;
			float blush = smoothstep(0.5, 0.78, fbm(uv * 0.18 + vec2(3.0, 8.0)));
			vec3 puff = mix(vec3(1.0, 0.97, 0.92), vec3(0.98, 0.75, 0.72), blush * 0.62);
			vec3 haze = vec3(0.78, 0.62, 0.52);
			float haze_amt = 0.18;
			if (meadow > 0.5) {
				puff = vec3(0.98, 0.99, 1.0);
				haze = vec3(0.86, 0.91, 0.96);
				haze_amt = 0.06;
			} else if (sunset > 0.5) {
				float sun_near = 0.0;
				if (LIGHT0_ENABLED) {
					float sun_ang = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
					sun_near = 1.0 - clamp(sun_ang / 1.15, 0.0, 1.0);
				}
				vec3 shade = mix(vec3(0.22, 0.12, 0.28), vec3(0.85, 0.4, 0.16), sun_near);
				vec3 lit = mix(vec3(0.48, 0.28, 0.46), vec3(1.0, 0.68, 0.32), sun_near);
				puff = mix(shade, lit, blush);
				haze = mix(vec3(0.16, 0.1, 0.22), vec3(0.9, 0.48, 0.18), sun_near);
				haze_amt = 0.22;
			} else if (fluffy > 0.5) {
				vec2 cuv = EYEDIR.xz * (5.5 / (0.2 + h));
				float billow = fbm(cuv * 0.28 + cloud_scroll * TIME * 0.06);
				float cotton = fbm(cuv * 0.85 + vec2(3.2, 1.4));
				float fringe = fbm(cuv * 2.1 - cloud_scroll.yx * TIME * 0.12);
				float pile = billow * 0.58 + cotton * 0.3 + fringe * 0.12;
				n = smoothstep(0.42, 0.74, pile);
				lift = smoothstep(0.015, 0.22, h);
				body = n * lift;
				float warmth = 0.35;
				if (LIGHT0_ENABLED) {
					float warm_ang = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
					warmth = 1.0 - clamp(warm_ang / 1.35, 0.0, 1.0);
				}
				float crown = smoothstep(0.35, 0.8, cotton);
				vec3 under = mix(vec3(0.5, 0.56, 0.64), vec3(0.9, 0.86, 0.78), warmth);
				vec3 top = mix(vec3(0.78, 0.84, 0.9), vec3(1.0, 0.99, 0.97), warmth);
				puff = mix(under, top, crown);
				haze = mix(vec3(0.62, 0.7, 0.8), vec3(0.92, 0.94, 0.96), warmth * 0.5);
				haze_amt = 0.12;
			}
			float cloud_lo = 0.22;
			float cloud_hi = 0.8;
			float cloud_gain = 0.82;
			if (fluffy > 0.5) {
				cloud_lo = 0.04;
				cloud_hi = 0.62;
				cloud_gain = 0.72;
			}
			col = mix(col, haze, body * haze_amt);
			col = mix(col, puff, smoothstep(cloud_lo, cloud_hi, body) * cloud_gain);
			vec2 w = normalize(wind_dir);
			float across = dot(uv, vec2(-w.y, w.x));
			float along = dot(uv, w) - TIME * 1.6;
			float streak = smoothstep(0.78, 0.97, sin(across * 9.0) * 0.5 + 0.5);
			streak *= smoothstep(0.55, 0.92, sin(along * 3.0) * 0.5 + 0.5);
			if (sunset < 0.5 && fluffy < 0.5) {
				col += vec3(1.0, 0.94, 0.86) * streak * lift * 0.07;
			}
		}
		if (LIGHT0_ENABLED) {
			float sun_d = clamp(dot(EYEDIR, LIGHT0_DIRECTION), 0.0, 1.0);
			vec3 corona = meadow > 0.5 ? vec3(1.0, 0.96, 0.82) : vec3(1.0, 0.62, 0.28);
			vec3 disc = meadow > 0.5 ? vec3(1.0, 0.98, 0.92) : vec3(1.0, 0.82, 0.5);
			float corona_pow = 12.0;
			float corona_amt = 0.28;
			float disc_pow = 64.0;
			float disc_amt = 1.35;
			if (sunset > 0.5) {
				corona = vec3(1.0, 0.38, 0.06);
				disc = vec3(1.0, 0.5, 0.1);
				corona_pow = 10.0;
				corona_amt = 0.22;
				disc_pow = 80.0;
				disc_amt = 0.85;
			} else if (fluffy > 0.5) {
				corona = vec3(1.0, 0.9, 0.62);
				disc = vec3(1.0, 0.96, 0.82);
				corona_pow = 16.0;
				corona_amt = 0.16;
				disc_pow = 96.0;
				disc_amt = 1.05;
			}
			col += corona * pow(sun_d, corona_pow) * corona_amt;
			col += disc * pow(sun_d, disc_pow) * disc_amt;
		}
		if (sunset > 0.5 || fluffy > 0.5) {
			vec3 mdir = normalize(moon_dir);
			float facing = clamp(dot(EYEDIR, mdir), 0.0, 1.0);
			float moon_body = pow(facing, 460.0);
			vec3 bite_dir = normalize(mdir + vec3(0.05, 0.01, -0.02));
			float bite = pow(clamp(dot(EYEDIR, bite_dir), 0.0, 1.0), 340.0);
			float phase = clamp(moon_body - bite * 0.78, 0.0, 1.0);
			vec3 up = abs(mdir.y) > 0.92 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
			vec3 tangent = normalize(cross(up, mdir));
			vec3 bitangent = cross(mdir, tangent);
			vec2 moon_uv = vec2(dot(EYEDIR, tangent), dot(EYEDIR, bitangent));
			float maria = noise(moon_uv * 380.0);
			vec3 moon_col = mix(vec3(0.62, 0.68, 0.76), vec3(0.96, 0.97, 1.0), maria);
			float moon_glow = sunset > 0.5 ? 0.14 : 0.035;
			float moon_amt = sunset > 0.5 ? 1.7 : 0.4;
			col += vec3(0.62, 0.7, 0.86) * pow(facing, 10.0) * moon_glow;
			col += moon_col * phase * moon_amt;
		}
	}
	COLOR = col;
}
