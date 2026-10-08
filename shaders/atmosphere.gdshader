shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.7);
	vec3 glow = vec3(0.95, 0.55, 0.28);
	ALBEDO = glow;
	EMISSION = glow * fres * 1.6;
	ALPHA = fres * 0.7;
}
