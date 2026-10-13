shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float radius = length(local_pos.xz);
	float inner = 7.55;
	float outer = 11.05;
	float span = outer - inner;
	float t = clamp((radius - inner) / span, 0.0, 1.0);
	float edge = smoothstep(inner, inner + 0.18, radius) * (1.0 - smoothstep(outer - 0.16, outer, radius));
	float ang = atan(local_pos.z, local_pos.x);
	float inner_band = smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.42, 0.54, t));
	float outer_band = smoothstep(0.62, 0.72, t) * (1.0 - smoothstep(0.9, 1.0, t));
	float gap = smoothstep(0.46, 0.54, t) * (1.0 - smoothstep(0.6, 0.68, t));
	float clumps = 0.62 + 0.38 * sin(ang * 4.0 + t * 6.0);
	clumps *= 0.8 + 0.2 * sin(ang * 11.0 - t * 3.0);
	float belt = max(inner_band, outer_band * 0.55);
	vec3 dust = mix(vec3(0.4, 0.48, 0.36), vec3(0.9, 0.94, 0.84), clumps);
	dust = mix(dust, dust * 0.22, gap);
	ALBEDO = dust;
	EMISSION = dust * 0.28;
	ALPHA = edge * belt * (0.28 + clumps * 0.45);
}
