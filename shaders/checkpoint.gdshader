shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled, depth_draw_never;

uniform vec4 albedo : source_color = vec4(0.2, 0.85, 1.0, 0.4);
uniform float half_height = 14.0;
varying float height_t;

void vertex() {
	height_t = clamp(VERTEX.y / max(half_height, 0.001) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = 1.0 - smoothstep(0.28, 1.0, height_t);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * fade;
}
