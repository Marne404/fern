// Sand streamer: thin, soft streak in the direction of flight (particles with align_y).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 color : source_color = vec3(0.95, 0.83, 0.6);

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = sin(UV.y * PI);
	ALBEDO = color;
	ALPHA = across * along * 0.4 * COLOR.a;
}
