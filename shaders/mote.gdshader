// Floating pollen / dust that sparkles in backlight.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.95, 0.75);
uniform float intensity = 1.0;
uniform float near_fade = 0.0;   // fade out closer than this (m), so big glows don't fill the screen

varying float v_near;

void vertex() {
	v_near = near_fade > 0.0 ? smoothstep(near_fade * 0.4, near_fade, length(MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD)) : 1.0;
	// billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = smoothstep(1.0, 0.0, d);
	a *= a;
	ALBEDO = tint * a * intensity * COLOR.a * v_near;
}
