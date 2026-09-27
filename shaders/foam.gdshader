// Foam carpet at the foot of a waterfall: churned up, fraying outwards.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = texture(noise_tex, vec2(a * 0.3 + TIME * 0.02, r * 0.8 - TIME * 0.35)).r;
	float n2 = texture(noise_tex, vec2(p * 1.7 + TIME * vec2(0.05, -0.04))).r;
	float mask = 1.0 - smoothstep(0.35 + n * 0.4, 0.95, r);
	float bubbles = smoothstep(0.45, 0.7, n2 * 0.6 + n * 0.5);
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = mask * (0.45 + bubbles * 0.5);
}
