// Sun shafts: radial blur of the sky from the sun (backlight through trees and clouds).
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 sun_uv = vec2(0.5);
uniform float strength = 0.0;
uniform int samples = 16;
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	// Only very bright sky pixels near the sun create shafts: real light rays through gaps
	// in tree crowns and clouds instead of a veil over the whole image.
	int SAMPLES = samples;
	vec2 uv = SCREEN_UV;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 delta = (uv - sun_uv) * (0.9 / float(SAMPLES));
	float illum = 0.0;
	float decay = 1.0;
	vec2 cuv = uv;
	for (int i = 0; i < SAMPLES; i++) {
		cuv -= delta;
		float d = textureLod(depth_tex, cuv, 0.0).r;
		float sky = step(d, 0.000001);
		vec3 c = textureLod(screen_tex, cuv, 0.0).rgb;
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		float near_sun = 1.0 - smoothstep(0.0, 0.28, length((cuv - sun_uv) * vec2(aspect, 1.0)));
		illum += sky * smoothstep(0.75, 1.1, lum) * near_sun * decay;
		decay *= 0.93;
	}
	illum /= float(SAMPLES);
	float dist = length((uv - sun_uv) * vec2(aspect, 1.0));
	ALBEDO = sun_color * illum * strength * 1.6 * (1.0 - smoothstep(0.05, 0.9, dist));
}
