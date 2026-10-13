shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.1);
	vec3 glow = vec3(0.35, 0.62, 1.0);
	ALBEDO = glow;
	EMISSION = glow * fres * 1.7;
	ALPHA = fres * 0.72;
}
