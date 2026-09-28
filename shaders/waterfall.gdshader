// Waterfall strand: curved surface (UV.x across, UV.y from the edge to the foot).
// Streaks pulling downwards, white spray at the edge and foot, fraying at the sides.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;
global uniform float daylight;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 water_color : source_color = vec3(0.5, 0.86, 0.94);
uniform vec3 deep_color : source_color = vec3(0.18, 0.55, 0.72);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform float speed = 1.0;
uniform float length_m = 10.0;
uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float fall = uv.y * length_m;
	float n1 = texture(noise_tex, vec2(uv.x * 1.3 + seed, fall * 0.04 - TIME * speed * 0.32)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 3.7 + 0.3 + seed, fall * 0.11 - TIME * speed * 0.75)).r;
	float n3 = texture(noise_tex, vec2(uv.x * 9.0 + seed, fall * 0.3 - TIME * speed * 1.6)).r;
	float streak = smoothstep(0.42, 0.78, n1 * 0.55 + n2 * 0.45);
	float lip = 1.0 - smoothstep(0.0, 0.1, uv.y);
	float base = smoothstep(0.78, 1.0, uv.y);
	float foam = clamp(streak * 0.55 + lip * 0.7 + base * 0.95 + smoothstep(0.7, 0.9, n3) * 0.3, 0.0, 1.0);
	vec3 col = mix(mix(deep_color, water_color, 0.5 + n2 * 0.5), foam_color, foam);
	ALBEDO = col * 0.35;
	EMISSION = col * 0.62 * daylight;
	// fray at the sides, dissolve into spray at the bottom
	float edge = smoothstep(0.0, 0.18 + n2 * 0.15, uv.x) * smoothstep(1.0, 0.82 - n1 * 0.15, uv.x);
	ALPHA = clamp((0.72 + foam * 0.28) * edge * (0.75 + n3 * 0.25), 0.0, 1.0);
	ROUGHNESS = 0.15;
}
