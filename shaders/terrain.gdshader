shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float slope = COLOR.a;
	float level = 1.0 - clamp(slope, 0.0, 1.0);
	float rip = sin(wpos.x * 0.32 + wpos.z * 0.06) * sin(wpos.z * 0.41);
	float fine = sin(wpos.x * 1.65 + wpos.z * 0.28);
	float grit = fract(sin(dot(wpos.xz, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 albedo = COLOR.rgb * (0.94 + rip * 0.07 * level + fine * 0.04 * level + grit * 0.045);
	albedo *= mix(1.05, 0.84, clamp(slope, 0.0, 1.0));
	ALBEDO = albedo;
	ROUGHNESS = mix(0.97, 0.72, slope);
	SPECULAR = 0.18;
}
