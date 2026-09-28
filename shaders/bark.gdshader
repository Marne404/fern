// Bark with normal map, vertex AO and the same trunk sway as the crown.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform float desaturate = 0.0;
uniform float brightness = 1.0;
uniform float normal_strength = 1.0;
uniform float object_height = 6.0;
uniform float stiffness = 4.0;
uniform float ao_strength = 0.8;
uniform float birch_marks = 0.0;
uniform bool impostor_cut = false;
instance uniform float bake_mask = 0.0;

varying float v_ao;
varying vec3 v_local;
varying float v_cloud;

void vertex() {
	vec3 origin = to_world(MODEL_MATRIX[3].xyz);
	vec3 world = to_world((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float h = clamp(VERTEX.y / object_height, 0.0, 1.5);
	vec3 off = wind_offset(world, origin, h * h, stiffness, 0.0, TIME);
	if (impostor_cut) {
		float ik = impostor_mesh_keep(MODEL_MATRIX[3].xyz, INSTANCE_CUSTOM.a);
		VERTEX *= ik;
		off *= ik;
	}
	VERTEX += world_to_model_dir(MODEL_MATRIX, off);
	v_ao = COLOR.r;
	v_local = VERTEX;
	v_cloud = cloud_shadow(world.xz, TIME);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desaturate) * tint * brightness;
	if (birch_marks > 0.0) {
		// dark, horizontal birch marks
		float band = floor(UV.y * 14.0);
		float r = hash(vec2(band, floor(UV.x * 3.0)));
		float m = step(0.72, r) * step(abs(fract(UV.y * 14.0) - 0.5), 0.18);
		m *= smoothstep(0.2, 0.5, abs(fract(UV.x * 3.0 + r) - 0.5));
		c = mix(c, vec3(0.16, 0.14, 0.13), m * birch_marks);
	}
	float ao = mix(1.0, smoothstep(0.0, 1.0, v_ao), ao_strength);
	ALBEDO = bake_mask > 0.5 ? vec3(1.0) : c * mix(0.35, 1.0, ao) * (1.0 - v_cloud * 0.45);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
