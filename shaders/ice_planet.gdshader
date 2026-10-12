shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform vec3 light_dir = vec3(0.96, 0.12, 0.22);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float lat = abs(UV.y - 0.5) * 2.0;
	float shelves = sin(UV.y * 22.0 + UV.x * 6.0) * 0.5 + 0.5;
	float cracks = smoothstep(0.74, 0.92, fract(sin(dot(floor(UV * 34.0), vec2(19.1, 47.7))) * 23421.63));
	float grain = fract(sin(dot(UV * 180.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 snow = vec3(0.86, 0.92, 0.98);
	vec3 ice = vec3(0.28, 0.52, 0.82);
	vec3 deep = vec3(0.08, 0.18, 0.38);
	vec3 albedo = mix(deep, ice, shelves);
	albedo = mix(albedo, snow, smoothstep(0.42, 0.86, lat));
	albedo = mix(albedo, snow, smoothstep(0.55, 0.9, shelves) * (1.0 - lat) * 0.55);
	albedo = mix(albedo, deep * 0.7, cracks * 0.65);
	albedo *= 0.94 + grain * 0.08;
	float ndl = dot(normalize(world_normal), normalize(light_dir));
	float night = smoothstep(0.18, -0.42, ndl);
	albedo = mix(albedo, vec3(0.015, 0.03, 0.07), night);
	ALBEDO = albedo;
	EMISSION = vec3(0.03, 0.08, 0.16) * night * 0.35;
	ROUGHNESS = mix(0.42, 0.72, night);
	SPECULAR = mix(0.4, 0.08, night);
}
