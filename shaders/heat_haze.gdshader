// Heat shimmer over hot ground: the distant ground (not the sky) wavers with rising, scrolling noise.
// Full-screen pass after the opaque world, like the valley mist.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float amount = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float far_ground(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, max(d, 1e-7), 1.0);
	float dist = -v.z / v.w;
	// reversed z: the sky has depth 0
	return smoothstep(35.0, 180.0, dist) * step(1e-6, d);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float here = far_ground(uv, INV_PROJECTION_MATRIX);
	if (here * amount < 0.002) {
		discard;
	}
	vec2 n = texture(noise_tex, vec2(uv.x * 3.0, uv.y * 1.6 + TIME * 0.32)).rg - 0.5;
	n += (texture(noise_tex, vec2(uv.x * 8.0 - TIME * 0.04, uv.y * 5.0 + TIME * 0.7)).rg - 0.5) * 0.6;
	vec2 off = n * vec2(0.0012, 0.0035) * amount * here;
	// only shift onto ground: where the offset would fetch sky, stay put
	vec2 uv2 = uv + off;
	uv2 = mix(uv, uv2, far_ground(uv2, INV_PROJECTION_MATRIX) > 0.01 ? 1.0 : 0.0);
	ALBEDO = textureLod(screen_tex, uv2, 0.0).rgb;
}
