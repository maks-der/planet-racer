shader_type spatial;
render_mode diffuse_burley, cull_back;

void fragment() {
	float lat = abs(UV.y - 0.5) * 2.0;
	float cracks = smoothstep(0.78, 0.93, fract(sin(dot(floor(UV * 28.0), vec2(19.1, 47.7))) * 23421.63));
	float shelves = sin(UV.y * 18.0 + UV.x * 4.0) * 0.5 + 0.5;
	float grain = fract(sin(dot(UV * 180.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 snow = vec3(0.96, 0.98, 1.0);
	vec3 ice = vec3(0.45, 0.74, 0.9);
	vec3 deep = vec3(0.18, 0.42, 0.64);
	vec3 albedo = mix(snow, ice, smoothstep(0.15, 0.72, shelves) * 0.35);
	albedo = mix(albedo, deep, cracks * (0.35 + lat * 0.4));
	albedo = mix(albedo, snow, smoothstep(0.55, 0.9, lat));
	albedo *= 0.96 + grain * 0.06;
	ALBEDO = albedo;
	ROUGHNESS = mix(0.48, 0.22, cracks);
	SPECULAR = 0.46;
}
