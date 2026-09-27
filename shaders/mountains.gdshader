// Distant mountain ranges like painted backdrops: faceted flanks, snowy peaks, haze.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled, depth_draw_opaque;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float height = 300.0;
uniform float radius = 1400.0;
uniform float seed = 0.0;
uniform vec3 base_color : source_color = vec3(0.35, 0.45, 0.4);
uniform vec3 shadow_color : source_color = vec3(0.3, 0.38, 0.5);
uniform vec3 haze_color : source_color = vec3(0.78, 0.9, 0.98);
uniform vec3 snow_color : source_color = vec3(0.96, 0.97, 1.0);
uniform float haze = 0.55;
uniform float snow = 0.5;
uniform vec3 sun_dir = vec3(0.4, 0.6, -0.7);   // towards the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);

varying vec3 v_pos;
varying float v_t;
varying float v_ridge;

float ridge(float a) {
	float u = a / 6.2831853;
	float n = texture(noise_tex, vec2(u * 3.0, seed)).r * 0.6;
	n += texture(noise_tex, vec2(u * 9.0, seed + 0.37)).r * 0.3;
	n += texture(noise_tex, vec2(u * 27.0, seed + 0.71)).r * 0.1;
	n = smoothstep(0.25, 0.8, n);
	return 0.15 + pow(n, 1.6) * 0.85;
}

void vertex() {
	// VERTEX.x = angle, VERTEX.y = height 0..1 along the flank, VERTEX.z = cross noise
	float a = VERTEX.x;
	float t = VERTEX.y;
	float r = ridge(a);
	float jag = (texture(noise_tex, vec2(a * 2.1, t * 0.7 + seed)).r - 0.5);
	float h = t * height * r;
	float rad = radius + (t - 0.3) * height * 1.6 * (0.7 + jag * 0.8);
	VERTEX = vec3(cos(a) * rad, h - 40.0 + jag * t * height * 0.08, sin(a) * rad);
	v_t = t;
	v_ridge = r;
	v_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(cross(dFdy(v_pos), dFdx(v_pos)));
	if (n.y < 0.0) n = -n;
	float lit = clamp(dot(n, normalize(sun_dir)) * 0.6 + 0.45, 0.0, 1.0);
	lit = smoothstep(0.2, 0.8, lit);
	vec3 col = mix(shadow_color, base_color * (0.8 + sun_color * 0.35), lit);
	// snow on the upper flanks, more on flat spots
	float h01 = v_t * v_ridge;
	float sn = smoothstep(1.0 - snow, 1.05 - snow, h01 + (n.y - 0.5) * 0.25) * step(0.01, snow);
	col = mix(col, snow_color * mix(0.72, 1.05, lit), sn);
	// aerial perspective: disappear into the haze at the bottom and in the distance
	float h = clamp(v_t, 0.0, 1.0);
	float fade = haze + (1.0 - haze) * (1.0 - smoothstep(0.0, 0.55, h)) * 0.9;
	col = mix(col, haze_color, clamp(fade, 0.0, 1.0));
	ALBEDO = col;
}
