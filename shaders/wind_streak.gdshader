// White wind lines like in cartoons: a light streak travels along a curve.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform float width = 0.05;
uniform float progress = 0.0;   // 0..1 head position
uniform float trail = 0.35;     // length of the tail
uniform float opacity = 0.75;

varying float v_u;

void vertex() {
	// NORMAL stores the tangent, UV.y the side (-1/+1)
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world);
	vec3 side = normalize(cross(tangent, to_cam));
	float taper = sin(clamp(UV.x, 0.0, 1.0) * PI);
	world += side * (UV.y * width * (0.4 + 0.6 * taper));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	v_u = UV.x;
}

void fragment() {
	float head = progress * (1.0 + trail);
	float d = head - v_u;
	float a = smoothstep(0.0, 0.03, d) * (1.0 - smoothstep(0.0, trail, d));
	a *= smoothstep(0.0, 0.08, v_u) * smoothstep(1.0, 0.92, v_u);
	ALBEDO = vec3(1.0);
	ALPHA = a * opacity;
}
