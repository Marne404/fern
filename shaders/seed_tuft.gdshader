// Dandelion seed: a tiny white tuft (radiating hairs around a dot), camera-facing, lit softly and glowing
// when it floats between you and the sun.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;

global uniform vec3 sun_vector;
global uniform vec4 sun_light;

varying vec3 v_view;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	v_view = normalize(MODEL_MATRIX[3].xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// 14 fine hairs fading outwards, a soft round halo and the small seed dot
	float hairs = pow(abs(cos(ang * 7.0)), 18.0) * smoothstep(1.0, 0.25, r) * smoothstep(0.05, 0.2, r);
	float halo = smoothstep(1.0, 0.0, r) * 0.25;
	float dot_ = smoothstep(0.22, 0.1, r);
	float a = clamp(hairs * 0.9 + halo + dot_, 0.0, 1.0);
	float glint = pow(max(dot(v_view, normalize(sun_vector)), 0.0), 5.0);
	vec3 c = mix(vec3(0.92, 0.94, 0.96), sun_light.rgb * 1.6, glint);
	ALBEDO = c * (1.0 + glint * 1.5);
	ALPHA = a * COLOR.a * 0.85;
}
