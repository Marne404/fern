// Dust devil: twisted funnel of swirling sand, semi-transparent, fraying at the top.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(0.92, 0.78, 0.55);
uniform float fade = 1.0;

varying float v_h;

void vertex() {
	v_h = VERTEX.y / 17.0 + 0.5;
	// the funnel sways and bends in the wind
	VERTEX.x += sin(TIME * 0.9 + v_h * 3.0) * v_h * 1.8;
	VERTEX.z += cos(TIME * 0.7 + v_h * 2.4) * v_h * 1.1;
}

void fragment() {
	vec2 uv = vec2(UV.x * 2.0 - TIME * 0.8 + v_h * 1.4, v_h * 1.2 - TIME * 0.3);
	float n = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * vec2(2.7, 1.6) + 0.31).r * 0.35;
	float streak = smoothstep(0.38, 0.72, n);
	// edge stronger than the middle: reads like a volume
	float edge = 0.35 + 0.65 * (1.0 - abs(dot(NORMAL, VIEW)));
	float vert = smoothstep(0.0, 0.1, v_h) * (1.0 - smoothstep(0.55, 1.0, v_h));
	// darker, stirred-up dust at the bottom, bright in the light at the top
	ALBEDO = mix(color * vec3(0.72, 0.6, 0.48), color * 1.08, smoothstep(0.0, 0.7, v_h)) * (0.82 + 0.3 * n);
	ALPHA = clamp((streak * 0.8 + 0.25) * edge * vert * fade * 1.0, 0.0, 1.0);
}
