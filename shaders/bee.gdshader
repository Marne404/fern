// Bee wings: glassy, beating so fast they blur (a quick up/down swing around the body axis).
shader_type spatial;
render_mode blend_mix, cull_disabled, specular_disabled, depth_draw_never, shadows_disabled;

void vertex() {
	float side = sign(VERTEX.x);
	float a = sin(TIME * 95.0 + INSTANCE_CUSTOM.r * 13.0) * 0.55;
	float c = cos(a * side), s = sin(a * side);
	vec3 v = VERTEX - vec3(0.0, 0.22, 0.0);
	VERTEX = vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z) + vec3(0.0, 0.22, 0.0);
}

void fragment() {
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = 0.4;
	BACKLIGHT = vec3(0.4);
}
