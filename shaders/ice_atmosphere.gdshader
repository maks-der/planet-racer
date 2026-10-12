shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec3 light_dir = vec3(0.96, 0.12, 0.22);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float ndl = dot(normalize(world_normal), normalize(light_dir));
	float night = smoothstep(0.35, -0.55, ndl);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.65);
	float across = UV.x * 16.0 + TIME * 0.12;
	float wave = sin(UV.y * 10.0 + TIME * 0.35) * 1.6;
	float curtain = sin(across + wave);
	curtain = smoothstep(0.05, 0.8, curtain * 0.5 + 0.5);
	float rise = smoothstep(0.18, 0.62, UV.y) * (1.0 - smoothstep(0.78, 0.98, UV.y));
	float aurora = curtain * night * (0.25 + fres * 1.55) * (0.4 + rise);
	float hue = sin(across * 0.35 + UV.y * 4.0) * 0.5 + 0.5;
	vec3 green = vec3(0.2, 1.0, 0.55);
	vec3 teal = vec3(0.25, 0.75, 1.0);
	vec3 violet = vec3(0.55, 0.28, 1.0);
	vec3 col = mix(green, teal, hue);
	col = mix(col, violet, smoothstep(0.55, 0.9, hue));
	vec3 limb = vec3(0.45, 0.7, 1.0) * fres * smoothstep(-0.15, 0.55, ndl) * 0.45;
	vec3 glow = col * aurora + limb;
	ALBEDO = glow;
	EMISSION = glow * 1.8;
	ALPHA = clamp(aurora * 0.9 + fres * smoothstep(-0.05, 0.45, ndl) * 0.28, 0.0, 1.0);
}
