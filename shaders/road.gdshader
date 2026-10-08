shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 line_color : source_color = vec3(0.25, 0.95, 1.0);
uniform float shortcut = 0.0;

void fragment() {
	vec3 amber = vec3(1.0, 0.64, 0.2);
	vec3 lines = mix(line_color, amber, shortcut);
	float edge = smoothstep(0.14, 0.0, UV.x) + smoothstep(0.86, 1.0, UV.x);
	float center = smoothstep(0.055, 0.0, abs(UV.x - 0.5));
	float dash = step(0.4, fract(UV.y * 0.16));
	float grain = fract(sin(dot(UV * vec2(80.0, 26.0), vec2(12.9898, 78.233))) * 43758.5453);
	float rip = sin(UV.y * 14.0 + UV.x * 6.0) * 0.5 + 0.5;
	vec3 sand = vec3(0.9, 0.74, 0.48);
	vec3 packed = vec3(0.78, 0.6, 0.36);
	vec3 albedo = mix(sand, packed, rip * 0.5 + grain * 0.3);
	albedo = mix(albedo, sand * 1.06, smoothstep(0.48, 0.12, abs(UV.x - 0.5)));
	ALBEDO = albedo;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.97, 0.78, edge);
	SPECULAR = 0.1;
	EMISSION = lines * edge * 2.8 + lines * center * dash * 1.2;
}
