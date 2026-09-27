// Underwater: the image wobbles, turns turquoise, loses contrast in the depth, light caustics.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float amount = 0.0;          // 0..1 (soft when submerging)
uniform vec3 tint : source_color = vec3(0.12, 0.45, 0.55);
uniform float depth = 1.0;           // depth below the surface in m

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 wob = vec2(texture(noise_tex, uv * 1.5 + vec2(t * 0.05, 0.0)).r, texture(noise_tex, uv * 1.5 + vec2(0.0, t * 0.04) + 0.5).r) - 0.5;
	vec2 suv = uv + wob * 0.025 * amount;
	vec3 c = textureLod(screen_tex, suv, 1.5 * amount).rgb;
	float murk = clamp(0.55 + depth * 0.08, 0.0, 0.92);
	vec3 col = mix(c * vec3(0.55, 0.85, 0.95), tint, murk);
	// caustics from above
	float ca = texture(noise_tex, uv * vec2(3.0, 1.2) + vec2(t * 0.03, -t * 0.02)).r;
	float cb = texture(noise_tex, uv * vec2(2.3, 1.6) - vec2(t * 0.025, t * 0.015)).r;
	float caustic = smoothstep(0.8, 0.95, 1.0 - abs(ca - cb) * 4.0);
	col += vec3(0.5, 0.85, 0.9) * caustic * 0.08 * (1.0 - uv.y) * (1.0 - smoothstep(0.0, 6.0, depth));
	// darker towards the edge and downwards
	vec2 q = uv - vec2(0.5, 0.35);
	col *= 1.0 - dot(q, q) * 0.9;
	COLOR = vec4(mix(textureLod(screen_tex, uv, 0.0).rgb, col, amount), 1.0);
}
