// Ice crystal in cold air: a tiny four-pointed spark that flashes when it turns into the sunlight.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

global uniform vec3 sun_vector;
global uniform vec4 sun_light;

varying float v_flash;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	vec3 view = normalize(MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD);
	// each crystal tumbles: it flashes only now and then; more often towards the sun
	float ph = float(INSTANCE_ID) * 1.7;
	float tumble = pow(max(sin(TIME * (1.3 + fract(ph) * 2.0) + ph * 5.0), 0.0), 24.0);
	float toward = pow(max(dot(view, normalize(sun_vector)), 0.0), 3.0);
	v_flash = tumble * (0.25 + toward * 2.5);
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float core = smoothstep(0.35, 0.0, length(p));
	float star = smoothstep(0.12, 0.0, min(p.x, p.y)) * smoothstep(1.0, 0.0, max(p.x, p.y));
	ALBEDO = sun_light.rgb * mix(vec3(0.85, 0.95, 1.0), vec3(1.0), 0.5) * (core + star * 0.8) * v_flash * COLOR.a * 3.0;
}
