// Rocks, pebbles and path stones. Large rocks use triplanar mapping in world coordinates.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float triplanar = 0.0;
uniform float triplanar_scale = 0.15;
uniform vec3 moss_color : source_color = vec3(0.45, 0.62, 0.18);
uniform float moss_amount = 0.0;
uniform float top_light = 0.25;
uniform float desaturate = 0.0;
uniform float flatten = 0.0;           // calm the texture in favor of the facets
uniform vec3 flat_color : source_color = vec3(0.5);

#include "res://shaders/wind.gdshaderinc"

varying vec3 v_world;
varying vec3 v_wnormal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
	v_wnormal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec3 sample_triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(albedo_tex, p.zy * triplanar_scale).rgb;
	vec3 y = texture(albedo_tex, p.xz * triplanar_scale).rgb;
	vec3 z = texture(albedo_tex, p.xy * triplanar_scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 c = triplanar > 0.5 ? sample_triplanar(v_world, v_wnormal) : texture(albedo_tex, UV).rgb;
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), desaturate);
	c = mix(c, flat_color * (0.85 + 0.3 * dot(c, vec3(0.33))), flatten);
	c *= tint * brightness;
	float up = v_wnormal.y;
	c *= 1.0 + top_light * smoothstep(0.2, 0.9, up);
	float n = texture(paint_noise, v_world.xz * 0.05 + v_world.y * 0.03).r;
	float moss = smoothstep(0.55, 0.85, up + (n - 0.5) * 0.8) * moss_amount;
	c = mix(c, moss_color * (0.8 + 0.4 * n), moss);
	// snow settles on the tops
	c = mix(c, vec3(0.93, 0.96, 1.0) * (0.92 + 0.08 * n), smoothstep(0.45, 0.8, up + (n - 0.5) * 0.5) * clamp(snow_cover * 1.4, 0.0, 1.0));
	// wet after rain: darker and with a sheen
	c *= mix(1.0, 0.68, wetness);
	ALBEDO = c * (1.0 - cloud_shadow(v_world.xz, TIME) * 0.45);
	ROUGHNESS = mix(0.85, 0.32, wetness);
	SPECULAR = mix(0.3, 0.55, wetness);
}
