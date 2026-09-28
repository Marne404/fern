// Glowing spore: a soft colored dot (color from the particle ramp) that shines in the dark.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

global uniform float daylight;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = smoothstep(1.0, 0.0, d);
	a = a * a * (0.6 + 0.4 * smoothstep(0.4, 0.0, d));
	ALBEDO = COLOR.rgb * a * COLOR.a * mix(4.0, 1.6, daylight);
}
