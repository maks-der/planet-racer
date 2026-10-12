shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform float frozen = 0.0;
uniform vec2 wind_dir = vec2(1.0, 0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float slope = COLOR.a;
	if (frozen > 0.5) {
		vec2 wind = normalize(wind_dir + vec2(0.001));
		vec2 across_v = vec2(-wind.y, wind.x);
		float across = dot(wpos.xz, across_v);
		float along = dot(wpos.xz, wind);
		float drift = sin(across * 0.35) * 0.6 + sin(across * 1.15 + along * 0.08) * 0.4;
		float trough = smoothstep(-0.15, 0.9, -drift);
		float crack_n = fract(sin(dot(floor(wpos.xz * 0.11), vec2(19.1, 47.7))) * 23421.63);
		float crack = smoothstep(0.965, 0.992, crack_n) * (1.0 - smoothstep(0.25, 0.7, slope));
		float strata = smoothstep(0.82, 0.96, fract(wpos.y * 0.07));
		vec3 albedo = COLOR.rgb;
		albedo = mix(albedo, albedo * vec3(0.68, 0.78, 0.9), trough * (1.0 - slope) * 0.55);
		albedo = mix(albedo, vec3(0.22, 0.4, 0.55), crack * 0.65);
		albedo = mix(albedo, vec3(0.95, 0.98, 1.0), strata * smoothstep(0.2, 0.55, slope));
		float spark = step(0.992, fract(sin(dot(wpos.xz, vec2(12.9898, 78.233))) * 43758.5453));
		albedo += vec3(0.12) * spark * (1.0 - slope);
		ALBEDO = albedo;
		ROUGHNESS = mix(0.62, 0.16, clamp(slope * 1.35, 0.0, 1.0));
		SPECULAR = mix(0.22, 0.78, clamp(slope, 0.0, 1.0));
	} else {
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
}
