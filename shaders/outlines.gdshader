// Subtle anime silhouettes: no black lines, just the color underneath a bit darker and
// more saturated – and only at large depth jumps (tree crowns against sky, rock edges), not in the grass.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.6;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float lin(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = lin(uv, INV_PROJECTION_MATRIX);
	// largest depth jump to the neighbors, relative to the distance
	float far_n = max(max(lin(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX), lin(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX)),
		max(lin(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX), lin(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX)));
	float jump = (far_n - d0) / max(d0, 0.5);
	// line only on the front side of large jumps
	float edge = smoothstep(0.25, 0.8, jump) * (1.0 - smoothstep(60.0, 160.0, d0));
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 ink = mix(vec3(l), c, 1.35) * 0.62;
	ALBEDO = ink;
	ALPHA = edge * strength;
}
