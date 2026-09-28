// Shared body of foliage.gdshader and grass_clump.gdshader.
#include "res://shaders/wind.gdshaderinc"
global uniform vec2 grass_fade;   // grass tufts: start and end of the thinning (m)

// 0 = tree crown, 1 = grass (colors per instance), 2 = plant with texture color, 3 = plant with vertex colors
uniform int mode = 0;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float alpha_cut = 0.45;
uniform vec3 color_dark : source_color = vec3(0.2, 0.45, 0.1);
uniform vec3 color_light : source_color = vec3(0.75, 0.92, 0.3);
uniform vec3 texture_tint : source_color = vec3(1.0);
uniform float texture_color_mix = 0.0;
uniform float saturation = 1.0;

// crown shape for soft, spherical normals
uniform vec3 crown_center = vec3(0.0, 4.0, 0.0);
uniform vec3 crown_extent = vec3(2.5, 2.5, 2.5);
uniform float sphere_normals = 0.75;
uniform float object_height = 6.0;

uniform float stiffness = 4.0;
uniform float flutter = 0.05;
uniform float translucency = 0.6;
uniform float wrap = 0.55;
uniform float ground_normal = 0.0; // grass: bend normals towards vertical
uniform float near_fade = 0.0;     // fade out blades right in front of the camera
uniform bool instance_tint = false; // blossom color per instance (INSTANCE_CUSTOM.rgb)


varying float v_grad;
varying float v_shade;
varying vec3 v_world;
varying vec3 v_tip;
varying float v_gust;
varying float v_var;
varying float v_cloud;
varying vec4 v_custom;
varying vec3 v_vcol;

vec3 adjust_saturation(vec3 c, float s) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(l), c, s);
}

void vertex() {
	vec3 origin = to_world(MODEL_MATRIX[3].xyz);
	vec3 world = to_world((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float weight;
	if (mode == 1) {
		weight = COLOR.r * COLOR.r;
		v_grad = COLOR.r;
		v_tip = INSTANCE_CUSTOM.rgb;
		v_shade = INSTANCE_CUSTOM.a;
	} else if (mode == 0) {
		float h = clamp(VERTEX.y / object_height, 0.0, 1.5);
		weight = h * h;
		vec3 rel = (VERTEX - crown_center) / crown_extent;
		float outer = clamp(length(rel), 0.0, 1.2);
		v_grad = clamp(0.35 * (rel.y * 0.5 + 0.5) + 0.75 * smoothstep(0.15, 1.05, outer), 0.0, 1.0);
		v_shade = INSTANCE_CUSTOM.a;
		v_tip = vec3(0.0);
		vec3 sphere_n = normalize(VERTEX - crown_center + vec3(0.0, crown_extent.y * 0.35, 0.0));
		NORMAL = normalize(mix(NORMAL, sphere_n, sphere_normals));
	} else {
		weight = clamp(VERTEX.y / object_height, 0.0, 1.0);
		v_grad = weight;
		v_shade = mode == 3 ? INSTANCE_CUSTOM.a : 0.0;
		v_tip = vec3(0.0);
	}
	v_vcol = COLOR.rgb;
	if (ground_normal > 0.0) {
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), ground_normal));
	}
	// sample the gust only once (saves a texture fetch per vertex, also in all shadow passes)
	float gust = wind_gust(origin.xz, TIME);
	vec3 off = wind_offset_g(world, origin, weight, stiffness, flutter, TIME, gust);
#ifndef OPAQUE_GRASS
	// flowers and small plants thin out round and random like the grass
	if (mode == 2) {
		float pd = length(origin - to_world(CAMERA_POSITION_WORLD));
		float keep_p = 1.0 - smoothstep(grass_fade.x * 1.2, grass_fade.y * 1.25, pd);
		float s_p = smoothstep(fract(INSTANCE_CUSTOM.a * 5.71 + 0.13) - 0.15, fract(INSTANCE_CUSTOM.a * 5.71 + 0.13), keep_p);
		VERTEX *= s_p;
		off *= s_p;
	}
#endif
#ifdef OPAQUE_GRASS
	// towards the distance the grass thins out in circles and randomly – no cell squares
	{
		float gd = length(origin - to_world(CAMERA_POSITION_WORLD));
		float keep_f = 1.0 - smoothstep(grass_fade.x, grass_fade.y, gd);
		float mine = fract(INSTANCE_CUSTOM.a * 7.13 + 0.37);
		float s_f = smoothstep(mine - 0.15, mine, keep_f);
		VERTEX *= s_f;
		off *= s_f;
	}
	// blades right in front of the camera sink into the ground instead of being discarded per pixel
	if (near_fade > 0.0) {
		float cam_d = length(world - to_world(CAMERA_POSITION_WORLD));
		float keep = smoothstep(near_fade * 0.4, near_fade, cam_d);
		VERTEX *= keep;
		off *= keep;
	}
#endif
	v_gust = gust;
	v_var = textureLod(wind_noise, world.xz * 0.004, 0.0).r;
	v_cloud = cloud_shadow(world.xz, TIME);
	v_custom = INSTANCE_CUSTOM;
	VERTEX += world_to_model_dir(MODEL_MATRIX, off);
	v_world = world;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec3 col;
	if (mode == 3) {
		col = v_vcol * (0.82 + 0.3 * v_grad) * (0.92 + 0.16 * fract(v_shade * 17.31));
	} else if (mode == 1) {
		vec3 tip = v_tip;
		vec3 root = mix(pow(tip, vec3(1.5)) * 0.42, tip * 0.6, 0.5);
		col = mix(root, tip, smoothstep(0.0, 0.95, v_grad));
		// wind waves: gusts make the blade tips shimmer brightly
		col = mix(col, col * 1.35 + vec3(0.04, 0.05, 0.0), v_gust * v_grad * v_grad * 0.7);
	} else {
		vec3 grad = mix(color_dark * (mode == 0 ? 0.78 : 1.0), color_light, smoothstep(0.0, 1.0, v_grad));
		col = mix(grad, tex.rgb * texture_tint, texture_color_mix);
		if (instance_tint && v_custom.a > 0.5 && length(v_custom.rgb) > 0.01) {
			float l = dot(tex.rgb, vec3(0.3, 0.59, 0.11));
			vec3 tinted = v_custom.rgb * (0.55 + l * 0.9);
			// flower center (dark yellow/orange) is preserved
			float centre = smoothstep(0.1, 0.35, tex.r - tex.b);
			col = mix(tinted, col, centre * 0.6);
		}
		col *= mix(1.0, 0.9 + 0.2 * fract(v_shade * 17.31), step(0.001, abs(v_shade)));
	}
	// large-scale color variation so nothing looks tiled
	float n = v_var;
	col *= 0.9 + 0.2 * n;
	ALBEDO = adjust_saturation(col, saturation);
#ifndef OPAQUE_GRASS
	// mipmaps average the leaf edges below the cutoff -> distant crowns dissolve.
	// raise the opacity depending on the mip level (keeps the coverage in the distance).
	vec2 tuv = UV * vec2(textureSize(albedo_tex, 0));
	float mip = max(0.5 * log2(max(dot(dFdx(tuv), dFdx(tuv)), dot(dFdy(tuv), dFdy(tuv)))), 0.0);
	ALPHA = tex.a * (1.0 + mip * 0.28);
	ALPHA_SCISSOR_THRESHOLD = max(alpha_cut, 0.01);
	ALPHA_ANTIALIASING_EDGE = 0.3;
#endif
	ROUGHNESS = 1.0;
	// soft normals shouldn't be mirrored on back faces
	if (mode != 2 && mode != 3) {
		NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diff = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	diff = smoothstep(0.0, 1.0, diff);
	float sun = 1.0 - v_cloud;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diff * sun / PI;
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * back * min(translucency, 0.8) * 0.45 * sun / PI;
	// anime: rim light on sun-facing silhouettes, cool fill on the shadow side
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * smoothstep(-0.2, 0.6, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * rim * 0.35 * sun / PI;
	DIFFUSE_LIGHT += vec3(0.05, 0.08, 0.16) * (1.0 - clamp(diff * ATTENUATION * sun, 0.0, 1.0)) * 0.3;
}
