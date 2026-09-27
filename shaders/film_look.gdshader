// Film look like an anime background (2D post-processing over the finished image):
// shadows towards turquoise/blue, highlights towards gold, richer midtones, soft vignette, fine grain.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 1.0;
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.55, 0.75);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.86, 0.62);
uniform float vibrance = 0.3;
uniform float vignette = 0.28;
uniform float grain = 0.014;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));

	// split toning
	float sh = 1.0 - smoothstep(0.0, 0.45, l);
	float hi = smoothstep(0.5, 1.0, l);
	vec3 g = c;
	g = mix(g, g * shadow_tint * 1.55, sh * 0.3);
	g = mix(g, g * highlight_tint * 1.1, hi * 0.25);

	// vibrance
	float mx = max(g.r, max(g.g, g.b));
	float mn = min(g.r, min(g.g, g.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	float lg = dot(g, vec3(0.2126, 0.7152, 0.0722));
	g = mix(vec3(lg), g, 1.0 + vibrance * (1.0 - sat));

	// slight S-curve for more depth
	g = mix(g, g * g * (3.0 - 2.0 * g), 0.25);

	vec2 q = uv - 0.5;
	g *= clamp(1.0 - dot(q, q) * vignette * 2.4, 0.0, 1.0);
	float n = fract(sin(dot(uv * 1000.0 + fract(TIME * 7.13) * 91.7, vec2(12.9898, 78.233))) * 43758.5453);
	g += (n - 0.5) * grain;

	COLOR = vec4(mix(c, clamp(g, 0.0, 1.0), strength), 1.0);
}
