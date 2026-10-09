shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_back;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float grain = fract(sin(dot(vec2(u * 37.0, v * 19.0), vec2(12.9898, 78.233))) * 43758.5453);
	float pebbles = fract(sin(dot(vec2(u * 96.0, v * 58.0), vec2(39.1, 11.7))) * 24634.6345);
	float wash = sin(v * 2.6 + u * 1.4) * 0.5 + 0.5;
	vec3 shoulder = vec3(0.71, 0.54, 0.33);
	vec3 packed = vec3(0.48, 0.33, 0.18);
	vec3 rut_col = vec3(0.33, 0.22, 0.12);
	vec3 gravel = vec3(0.6, 0.5, 0.38);
	float crown = smoothstep(0.5, 0.1, abs(u - 0.5));
	vec3 albedo = mix(shoulder, packed, crown);
	float rut_l = smoothstep(0.06, 0.01, abs(u - 0.36));
	float rut_r = smoothstep(0.06, 0.01, abs(u - 0.64));
	float ruts = clamp(rut_l + rut_r, 0.0, 1.0);
	ruts *= 0.72 + 0.28 * sin(v * 17.0);
	albedo = mix(albedo, rut_col, ruts * 0.82);
	float stones = step(0.84, pebbles) * (1.0 - crown * 0.7);
	albedo = mix(albedo, gravel, stones * 0.5);
	albedo *= 0.9 + grain * 0.16 + wash * 0.05;
	ALBEDO = albedo;
	ROUGHNESS = mix(1.0, 0.9, crown);
	METALLIC = 0.0;
	SPECULAR = 0.04;
}
