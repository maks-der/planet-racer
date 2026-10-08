shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.04, 0.06, 0.11);
	vec3 horizon = vec3(0.55, 0.34, 0.18);
	vec3 ground = vec3(0.16, 0.09, 0.06);
	vec3 col = mix(top, horizon, smoothstep(0.0, 0.58, uv.y));
	col = mix(col, ground, smoothstep(0.52, 1.0, uv.y));
	float dune = sin(uv.x * 18.0 + uv.y * 4.0) * 0.012;
	col += vec3(0.35, 0.18, 0.05) * dune * smoothstep(0.45, 0.8, uv.y);
	vec2 sun_uv = (uv - vec2(0.74, 0.4)) * vec2(1.15, 1.7);
	float sun = pow(max(1.0 - length(sun_uv), 0.0), 2.4);
	col += vec3(1.0, 0.72, 0.38) * sun;
	float vignette = smoothstep(1.15, 0.25, length((uv - 0.5) * vec2(1.3, 1.0)));
	COLOR = vec4(col * vignette, 1.0);
}
