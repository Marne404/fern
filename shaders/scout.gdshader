// Scout (player character): soft cel shading with two bands, cool shadow fill, sunlit rim
// and a hard highlight for glossy parts (eyes, buttons). Fits the anime lighting of the foliage.
shader_type spatial;
render_mode cull_back;

uniform vec3 color : source_color = vec3(1.0);
uniform float gloss = 0.0;        // 1 = hard glossy highlight (eyes, metal)
uniform float cloth = 0.0;        // fine fabric noise
uniform float emission = 0.0;     // 1 = unlit (eye highlights)
uniform float shade_hue = 1.0;    // how strongly the shadow side shifts towards cool colors
uniform bool use_vertex_color = false; // merged meshes: color per vertex, alpha = 1 plain, 0.5 cloth, 0 glossy

#include "res://shaders/wind.gdshaderinc"

varying vec3 v_world;
varying vec3 v_local;
varying float v_cloud;
varying float v_gloss;
varying float v_cloth;

void vertex() {
	v_local = VERTEX;
	v_world = to_world((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_cloud = cloud_shadow(v_world.xz, TIME);
	v_gloss = use_vertex_color ? step(COLOR.a, 0.25) : gloss;
	v_cloth = use_vertex_color ? step(0.25, COLOR.a) * step(COLOR.a, 0.75) : cloth;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 c = use_vertex_color ? COLOR.rgb : color;
	if (v_cloth > 0.0) {
		// woven fabric: fine cross hatching in object space
		vec3 q = v_local * 180.0;
		float weave = sin(q.x + q.y * 0.5) * sin(q.y - q.z * 0.5);
		c *= 1.0 + weave * 0.035 * v_cloth + (hash(floor(v_local * 400.0)) - 0.5) * 0.03 * v_cloth;
	}
	ALBEDO = c;
	EMISSION = c * emission;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sun = 1.0 - v_cloud * 0.8;
	// two soft bands: light / shadow, the shadow terminator is slightly wrapped
	float lit = smoothstep(-0.08, 0.1, ndl) * mix(1.0, ATTENUATION, 0.92);
	lit = smoothstep(0.25, 0.55, lit);
	float mid = smoothstep(0.35, 0.75, ndl) * 0.18;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit * (0.82 + mid)) * sun / PI;
	// rim light on the sunny silhouette
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.9, 1.0 - nv) * smoothstep(-0.3, 0.4, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * 0.45 * sun / PI;
	// cool fill in the shadow, warm bounce from below
	float shade = 1.0 - lit;
	DIFFUSE_LIGHT += vec3(0.06, 0.09, 0.2) * shade * 0.35 * shade_hue;
	DIFFUSE_LIGHT += vec3(0.12, 0.09, 0.04) * clamp(-NORMAL.y * 0.5 + 0.2, 0.0, 1.0) * 0.12;
	if (v_gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.93, 0.96, dot(NORMAL, h)) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR * s * v_gloss * 0.9;
	}
}
