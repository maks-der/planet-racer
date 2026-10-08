shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec4 body_color : source_color = vec4(0.08, 0.09, 0.11, 1.0);
uniform vec4 accent_color : source_color = vec4(0.08, 0.9, 1.0, 1.0);
uniform float boost_glow = 0.0;
uniform float zone = 0.0;

void fragment() {
	float accent = smoothstep(0.72, 0.95, zone);
	float glass = smoothstep(0.38, 0.5, zone) * (1.0 - smoothstep(0.62, 0.74, zone));
	vec3 albedo = mix(body_color.rgb, accent_color.rgb, accent);
	albedo = mix(albedo, vec3(0.02, 0.035, 0.05), glass);
	ALBEDO = albedo;
	METALLIC = mix(0.82, 0.15, glass);
	ROUGHNESS = mix(0.22, 0.04, glass);
	EMISSION = accent_color.rgb * accent * (1.4 + boost_glow * 1.8);
	EMISSION += vec3(0.45, 0.8, 1.0) * glass * 0.35;
}
