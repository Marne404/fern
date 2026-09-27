// Painted ground for world chunks.
// COLOR.rgb = base color (biome, region, slope), CUSTOM0 = path color + cracks, CUSTOM1.x = sand ripples.
// The path mask comes as a small texture per chunk.
shader_type spatial;
render_mode specular_disabled, cull_disabled;

#include "res://shaders/wind.gdshaderinc"

uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform float path_res = 65.0;
uniform float chunk_size = 64.0;
uniform sampler2D paint_noise : filter_linear_mipmap, repeat_enable;
uniform float path_softness = 0.18;
global uniform float sand_storm;

varying vec3 v_world;
varying vec3 v_local;
varying vec4 v_path;
varying float v_ripple;
varying float v_cloud;
varying vec3 v_wnormal;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
	v_path = CUSTOM0;
	v_ripple = CUSTOM1.x;
	v_cloud = cloud_shadow(v_world.xz, TIME);
	v_wnormal = NORMAL;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg, mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 r = g + hash2(n + g) - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++)
	for (int i = -2; i <= 2; i++) {
		vec2 g = mg + vec2(float(i), float(j));
		vec2 r = g + hash2(n + g) - f;
		if (dot(mr - r, mr - r) > 0.00001)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return md;
}

void fragment() {
	vec2 p = v_world.xz;
	float n_mid = texture(paint_noise, p * 0.021 + 0.3).r;
	float n_small = texture(paint_noise, p * 0.11 + 0.7).r;
	float n_fine = texture(paint_noise, p * 0.45).r;

	vec3 ground = COLOR.rgb * (0.9 + 0.22 * n_small);
	// rock walls: rock strata with relief (ledges, overhangs), vertical cracks, moss.
	// color follows the biome (slope color in COLOR): gray limestone, red sandstone, dark basalt …
	// sand may lie steeper (dunes), rock only on real walls (mesas)
	float steep = 1.0 - smoothstep(mix(0.5, 0.36, v_ripple), mix(0.68, 0.5, v_ripple), normalize(v_wnormal).y);
	if (steep > 0.01) {
		vec3 wn = normalize(v_wnormal);
		vec3 T = normalize(vec3(-wn.z, 0.0, wn.x) + vec3(1e-4, 0.0, 0.0));
		vec3 B = cross(wn, T);
		// two side projections (x and z) softly blended: no jumps at triangle edges
		float wz = smoothstep(0.3, 0.7, abs(wn.x) / (abs(wn.x) + abs(wn.z) + 1e-4));
		float v = v_world.y;
		float warp = mix(texture(paint_noise, vec2(v_world.x * 0.018, v * 0.01)).r, texture(paint_noise, vec2(v_world.z * 0.018 + 0.37, v * 0.01)).r, wz);
		// strata slightly wavy, sometimes thin, sometimes thick (no uniform layer cake)
		float thick_n = mix(texture(paint_noise, vec2(v_world.x * 0.006, v * 0.004 + 0.2)).r, texture(paint_noise, vec2(v_world.z * 0.006 + 0.6, v * 0.004)).r, wz);
		float thick = mix(1.1, 3.4, smoothstep(0.3, 0.7, thick_n));
		float lay = (v + warp * 3.5) / thick;
		float fl = floor(lay);
		float fr = fract(lay);
		float lh = fract(sin(fl * 78.233) * 43758.5453);
		// relief: each layer juts out at the top (ledge) and recedes at the bottom
		float prof = smoothstep(0.0, 0.18, fr) * (0.7 + 0.3 * fr);
		vec2 cu = vec2(v_world.x, v_world.z) * 0.11 + lh * 3.0;
		float cx = texture(paint_noise, vec2(cu.x, v * 0.018)).r;
		float cz = texture(paint_noise, vec2(cu.y + 0.5, v * 0.018)).r;
		float crack_n = mix(cx, cz, wz);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(crack_n - 0.5));
		float u = mix(v_world.x, v_world.z, wz);
		// normal from the relief (derivative upwards, crack edges sideways)
		float fr2 = min(fr + 0.04, 1.0);
		float dprof_dv = (smoothstep(0.0, 0.18, fr2) * (0.7 + 0.3 * fr2) - prof) / (0.04 * thick);
		float bump_u = (smoothstep(0.0, 0.08, abs(crack_n - 0.5)) - 0.5) * sign(crack_n - 0.5) * 0.5;
		vec3 n_w = normalize(wn - B * clamp(dprof_dv, -3.0, 3.0) * 0.35 - T * bump_u * 0.6);
		float fade = 1.0 - smoothstep(50.0, 110.0, length(VERTEX));
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n_w, 0.0)).xyz, steep * fade));

		vec3 rock_base = mix(COLOR.rgb, vec3(0.62, 0.6, 0.56), 0.22);
		float patch = texture(paint_noise, vec2(u, v) * 0.03 + 0.5).r;
		vec3 rock = rock_base * (0.86 + lh * 0.16 + (patch - 0.5) * 0.25);
		// shadow under the ledges, bright top edges, dark cracks
		rock *= mix(0.62, 1.0, prof);
		rock *= 1.0 + smoothstep(0.85, 1.0, fr) * 0.12;
		rock *= 1.0 - crack * 0.45;
		// moss and plant cushions on the ledges, green drip marks below
		float moss_n = texture(paint_noise, vec2(u, v) * 0.07 + 0.2).r;
		float drip = texture(paint_noise, vec2(u * 0.25, v * 0.01)).r;
		float ledge = smoothstep(0.8, 0.97, fr);
		float moss = (smoothstep(0.45, 0.7, moss_n) * ledge * 0.8 + smoothstep(0.66, 0.84, drip) * 0.3) * (1.0 - smoothstep(0.0, 0.12, COLOR.r - COLOR.g));
		vec3 moss_col = mix(COLOR.rgb * vec3(0.55, 0.85, 0.4), vec3(0.22, 0.34, 0.1), 0.5);
		rock = mix(rock, moss_col, clamp(moss, 0.0, 0.7));
		ground = mix(ground, rock, steep);
	}

	// path with a soft, irregular edge
	vec2 puv = (v_local.xz / chunk_size * (path_res - 1.0) + 0.5) / path_res;
	float pv = texture(path_tex, puv).r;
	float path = pv + (n_mid - 0.5) * 0.45 + (n_fine - 0.5) * 0.12;
	float wall = 1.0 - smoothstep(0.45, 0.7, normalize(v_wnormal).y);
	float path_mask = smoothstep(0.5 - path_softness, 0.5 + path_softness, path) * step(0.02, pv) * (1.0 - wall);
	float edge_mask = smoothstep(0.2, 0.45, path) * (1.0 - path_mask) * step(0.02, pv) * (1.0 - wall);
	vec3 dirt = v_path.rgb * (0.92 + 0.16 * n_small);

	float crack_amount = v_path.a;
	if (crack_amount > 0.01 && path_mask > 0.01) {
		vec2 cp = p * 0.55 + (vec2(n_small, n_fine) - 0.5) * 0.35;
		float e = voronoi_edge(cp);
		float crack = 1.0 - smoothstep(0.015, 0.06, e);
		float fade = smoothstep(0.35, 0.6, n_mid + n_fine * 0.3);
		dirt = mix(dirt, dirt * vec3(0.8, 0.76, 0.7), crack * fade * crack_amount);
	}

	if (v_ripple > 0.01) {
		vec2 rp = p + vec2(n_mid, n_small) * 6.0;
		float r = sin(dot(rp, vec2(0.95, 0.3)) * 2.2 + n_mid * 12.0);
		r = smoothstep(-0.2, 1.0, r);
		ground *= 1.0 + (r - 0.5) * 0.12 * v_ripple;
	}

	// sand gust: bright veils of sand race across the ground in the wind direction
	if (sand_storm > 0.01 && v_ripple > 0.01) {
		vec2 wd = normalize(wind_direction);
		vec2 q = vec2(dot(p, wd), dot(p, vec2(-wd.y, wd.x)));
		float s1 = texture(paint_noise, vec2(q.x * 0.04 - TIME * 0.55, q.y * 0.35)).r;
		float s2 = texture(paint_noise, vec2(q.x * 0.09 - TIME * 1.1, q.y * 0.8 + 0.4)).r;
		float drift = smoothstep(0.55, 0.8, s1) * 0.7 + smoothstep(0.6, 0.85, s2) * 0.5;
		ground = mix(ground, vec3(1.0, 0.93, 0.78), drift * sand_storm * v_ripple * 0.45);
	}

	vec3 col = mix(ground, mix(ground, dirt, 0.45) * 0.92, edge_mask * 0.6);
	col = mix(col, dirt, path_mask);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ndl * (1.0 - v_cloud) / PI;
}
