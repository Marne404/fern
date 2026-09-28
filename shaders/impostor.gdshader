// Impostor for a distant tree: a billboard that turns around the tree's axis and shows the nearest of 8
// pre-rendered views (albedo + normals), crossfading between neighbouring views. Lit like the tree crowns
// (wrap diffuse, translucency, rim light, cool fill, cloud shadows) so the hand-over is invisible.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D bark_atlas : filter_linear_mipmap, repeat_disable;   // 1 = bark, 0 = leaves
uniform float frames = 8.0;
uniform float elevation = 0.1;       // pitch of the bake camera (rad)
uniform float bake_tone = 1.0;       // large-scale color variation at the bake spot (divided out)
uniform float wrap = 0.55;
uniform float translucency = 0.6;
uniform float sway = 0.04;           // gentle bending of the top in gusts (in quad heights)

varying float v_frame;
varying float v_cloud;
varying float v_tone;
varying float v_shade;
varying float v_gust;
varying float v_bark;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float show = 1.0 - impostor_mesh_keep(origin, INSTANCE_CUSTOM.a);
	// camera direction in the tree's own space (rotation and scale of the instance included)
	vec3 cl = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec2 d = normalize(cl.xz + vec2(1e-4, 0.0));
	vec3 right = vec3(d.y, 0.0, -d.x);
	float h = UV.y < 0.5 ? 1.0 : 0.0;      // 1 at the top edge
	vec3 w_origin = to_world(origin);
	float gust = wind_gust(w_origin.xz, TIME);
	v_gust = gust;
	vec2 wd = normalize(wind_direction);
	vec3 bend = (inverse(mat3(MODEL_MATRIX)) * vec3(wd.x, 0.0, wd.y)) * (gust * 0.8 + 0.2) * wind_strength * sway * h * VERTEX.y;
	VERTEX = right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0) + bend;
	VERTEX *= show;
	NORMAL = vec3(d.x, 0.0, d.y);
	// view index: 0 = seen from the tree's +Z, counting towards +X
	v_frame = atan(d.x, d.y) / (TAU / frames);
	v_cloud = cloud_shadow(w_origin.xz, TIME);
	v_tone = textureLod(wind_noise, w_origin.xz * 0.004, 0.0).r;
	v_shade = INSTANCE_CUSTOM.a;
}

// normal of view i (bake camera space) → tree space
vec3 view_normal(vec3 enc, float i) {
	vec3 n = enc * 2.0 - 1.0;
	float ce = cos(elevation), se = sin(elevation);
	// camera pitched down by `elevation`: camera space → bake world
	n = vec3(n.x, n.y * ce + n.z * se, -n.y * se + n.z * ce);
	// the tree of view i stood rotated by -a_i: undo it
	float a = i * TAU / frames;
	float ca = cos(a), sa = sin(a);
	return normalize(vec3(n.x * ca + n.z * sa, n.y, -n.x * sa + n.z * ca));
}

void fragment() {
	float f = mod(v_frame, frames);
	float i0 = floor(f);
	float t = f - i0;
	float i1 = mod(i0 + 1.0, frames);
	vec2 uv = vec2(clamp(UV.x, 0.004, 0.996), UV.y);
	vec2 uv0 = vec2((i0 + uv.x) / frames, uv.y);
	vec2 uv1 = vec2((i1 + uv.x) / frames, uv.y);
	vec4 c0 = texture(albedo_atlas, uv0);
	vec4 c1 = texture(albedo_atlas, uv1);
	float w0 = c0.a * (1.0 - t), w1 = c1.a * t;
	float alpha = w0 + w1;
	vec3 col = (c0.rgb * w0 + c1.rgb * w1) / max(alpha, 1e-4);
	vec4 e0 = texture(normal_atlas, uv0);
	vec4 e1 = texture(normal_atlas, uv1);
	vec3 n0 = view_normal(e0.rgb, i0);
	vec3 n1 = view_normal(e1.rgb, i1);
	// bark is lit plainly, leaves like the crowns
	v_bark = smoothstep(0.35, 0.65, (texture(bark_atlas, uv0).r * w0 + texture(bark_atlas, uv1).r * w1) / max(alpha, 1e-4));
	vec3 n_local = normalize(n0 * w0 + n1 * w1 + vec3(0.0, 1e-4, 0.0));
	// same variation as the meshes: per-tree shade and large-scale color noise
	col *= 0.9 + 0.2 * fract(v_shade * 17.31);
	col *= (0.9 + 0.2 * v_tone) / bake_tone;
	// trunks of real trees sit in the crown's shade and ambient occlusion, a flat billboard gets neither
	col *= mix(1.0, 0.58, v_bark);
	ALBEDO = col;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n_local, 0.0))).xyz);
	ROUGHNESS = 1.0;
	// mipmaps thin the silhouette out: keep coverage in the distance (like the leaf cards)
	vec2 tuv = uv0 * vec2(textureSize(albedo_atlas, 0));
	float mip = max(0.5 * log2(max(dot(dFdx(tuv), dFdx(tuv)), dot(dFdy(tuv), dFdy(tuv)))), 0.0);
	ALPHA = alpha * (1.0 + mip * 0.3);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sun = 1.0 - v_cloud;
	if (v_bark > 0.5) {
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(ndl, 0.0, 1.0) * sun / PI;
	} else {
		float diff = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
		diff = smoothstep(0.0, 1.0, diff);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diff * sun / PI;
		float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * back * min(translucency, 0.8) * 0.45 * sun / PI;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * smoothstep(-0.2, 0.6, ndl);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * rim * 0.35 * sun / PI;
		DIFFUSE_LIGHT += vec3(0.05, 0.08, 0.16) * (1.0 - clamp(diff * ATTENUATION * sun, 0.0, 1.0)) * 0.3;
	}
}
