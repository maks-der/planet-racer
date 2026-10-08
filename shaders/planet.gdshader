shader_type spatial;
render_mode diffuse_burley, cull_back;

void fragment() {
	float dunes = sin(UV.x * 48.0 + UV.y * 10.0) * sin(UV.y * 30.0);
	float grain = fract(sin(dot(UV * 140.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 sand = vec3(0.84, 0.6, 0.32);
	vec3 deep = vec3(0.52, 0.3, 0.16);
	vec3 rock = vec3(0.4, 0.26, 0.2);
	vec3 albedo = mix(deep, sand, dunes * 0.5 + 0.5);
	albedo = mix(albedo, albedo * 0.92, grain);
	float ridge = smoothstep(0.55, 0.9, abs(UV.y - 0.5) * 2.0);
	albedo = mix(albedo, rock, ridge * 0.45);
	float basin = smoothstep(0.72, 0.95, fract(sin(dot(floor(UV * 18.0), vec2(19.1, 47.7))) * 23421.63));
	albedo = mix(albedo, deep * 0.85, basin * 0.35);
	ALBEDO = albedo;
	ROUGHNESS = 0.94;
	SPECULAR = 0.08;
}
