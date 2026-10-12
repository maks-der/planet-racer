shader_type spatial;
render_mode diffuse_burley, cull_back;

void fragment() {
	float lat = abs(UV.y - 0.5) * 2.0;
	float grain = fract(sin(dot(UV * 90.0, vec2(12.9898, 78.233))) * 43758.5453);
	float rolls = sin(UV.x * 22.0 + UV.y * 8.0) * sin(UV.y * 16.0 - UV.x * 4.0);
	vec3 low = vec3(0.14, 0.38, 0.1);
	vec3 mid = vec3(0.3, 0.58, 0.16);
	vec3 high = vec3(0.55, 0.74, 0.26);
	vec3 albedo = mix(low, mid, rolls * 0.5 + 0.5);
	albedo = mix(albedo, high, smoothstep(0.35, 0.9, lat) * 0.45);
	float cloud_a = sin(UV.x * 28.0 + UV.y * 6.0) * sin(UV.y * 18.0 + 1.7);
	float cloud_b = sin(UV.x * 11.0 - UV.y * 9.0 + 0.4);
	float clouds = smoothstep(0.25, 0.72, cloud_a * 0.55 + cloud_b * 0.45 + 0.15);
	clouds *= smoothstep(0.05, 0.35, lat);
	albedo = mix(albedo, vec3(0.97, 0.98, 1.0), clouds * 0.92);
	albedo *= 0.95 + grain * 0.08;
	ALBEDO = albedo;
	ROUGHNESS = mix(0.86, 0.55, clouds);
	SPECULAR = 0.08;
}
