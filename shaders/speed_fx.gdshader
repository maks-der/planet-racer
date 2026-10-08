shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float intensity = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 from_mid = uv - vec2(0.5);
	float side = smoothstep(0.42, 0.88, abs(from_mid.x) * 2.0);
	float rush = TIME * (10.0 + intensity * 36.0);
	float fine = sin(uv.y * 70.0 - rush);
	float broad = sin(uv.y * 16.0 - rush * 0.45);
	float lines = smoothstep(0.72, 0.97, fine) * 0.55 + smoothstep(0.15, 0.9, broad) * 0.28;
	lines *= side;
	float vig = smoothstep(0.42, 1.15, length(from_mid * vec2(1.45, 1.05)));
	float shade = intensity * (lines * 0.34 + vig * 0.22);
	COLOR = vec4(vec3(0.9, 0.92, 0.94), clamp(shade, 0.0, 0.38));
}
