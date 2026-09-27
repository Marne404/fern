// Exhaustion: vignette, slightly desaturated edges, pulsing like a heartbeat.
shader_type canvas_item;

uniform float amount = 0.0;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = length(uv - 0.5) * 1.4;
	float pulse = 0.85 + 0.15 * sin(TIME * (2.5 + amount * 3.0));
	float v = smoothstep(0.35, 1.05, d) * amount * pulse;
	vec3 col = texture(screen, uv).rgb;
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l), v * 0.8);
	col = mix(col, vec3(0.05, 0.02, 0.02), v * 0.55);
	COLOR = vec4(col, 1.0);
}
