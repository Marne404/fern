// Campfire flame puff: a soft teardrop, camera-facing, glowing yellow to orange to red over its life
// (color from the particle ramp), licking upwards with a little noise. Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying float v_seed;

void vertex() {
	v_seed = float(INSTANCE_ID) * 0.13;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], vec4(0.0, 1.0, 0.0, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s * 1.6, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	// flicker the outline
	float n = texture(noise_tex, vec2(UV.x * 0.6 + v_seed, UV.y * 0.5 - TIME * 1.6)).r - 0.5;
	p.x += n * 0.35 * (p.y + 1.0) * 0.5;
	// teardrop: round at the bottom, pointed at the top
	float w = mix(0.95, 0.05, clamp((p.y + 1.0) * 0.5, 0.0, 1.0));
	float d = length(vec2(p.x / max(w, 0.05), (p.y + 0.35) * 0.8));
	float a = smoothstep(1.0, 0.35, d);
	float core = smoothstep(0.55, 0.0, d);
	vec3 c = COLOR.rgb * (a + core * 0.6);
	ALBEDO = c * COLOR.a * 2.2;
}
