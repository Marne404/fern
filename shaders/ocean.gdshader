// Open sea at the coast: several rotated, domain-warped wave layers (no visible tiling), detail that
// fades with distance, turquoise shallows -> deep blue -> sky color at the horizon, Fresnel sky
// reflection, a sun glitter path, drifting wind patches, sparse whitecaps and shore foam.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded, shadows_disabled;

global uniform vec2 world_origin;
global uniform vec2 wind_direction;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
instance uniform vec3 shallow_color : source_color = vec3(0.3, 0.72, 0.74);
instance uniform vec3 deep_color : source_color = vec3(0.05, 0.22, 0.42);
instance uniform vec3 horizon_color : source_color = vec3(0.9, 0.85, 0.8);
instance uniform vec3 sky_color : source_color = vec3(0.3, 0.5, 0.9);
instance uniform vec3 sun_dir = vec3(0.3, 0.3, -0.9);      // towards the sun (world)
instance uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.75);
uniform vec3 foam_color : source_color = vec3(0.96, 0.98, 1.0);
uniform float wave_strength = 1.0;

varying vec3 v_world;

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// slope (dh/dx, dh/dz) of a sum of rotated noise layers; detail fades the small layers out
vec2 slope(vec2 p, float t, float detail) {
	vec2 w = wind_direction;
	vec2 warp = vec2(texture(noise_tex, p * 0.0017 + t * 0.002).r, texture(noise_tex, p * 0.0019 - t * 0.0017 + 0.37).r) - 0.5;
	p += warp * 30.0;
	vec2 g = vec2(0.0);
	float amp = 1.0;
	float freq = 0.012;
	for (int i = 0; i < 5; i++) {
		float a = float(i) * 1.93 + 0.41;
		vec2 q = rot(p, a) * freq + rot(w, a) * t * (0.02 + 0.006 * float(i));
		float e = 0.012;
		float h0 = texture(noise_tex, q).r;
		float hx = texture(noise_tex, q + vec2(e, 0.0)).r;
		float hz = texture(noise_tex, q + vec2(0.0, e)).r;
		vec2 d = rot(vec2(hx - h0, hz - h0) / e * freq, -a);
		g += d * amp * (i < 2 ? 1.0 : detail);
		amp *= 0.55;
		freq *= 2.17;
	}
	return g;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
}

void fragment() {
	vec2 p = v_world.xz;
	float t = TIME;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
	vec3 to_cam = cam - v_world;
	float dist = length(to_cam);
	vec3 V = to_cam / dist;
	float detail = 1.0 - smoothstep(60.0, 700.0, dist);

	vec2 g = slope(p, t, detail) * wave_strength * mix(1.0, 0.35, smoothstep(150.0, 2000.0, dist));
	vec3 n = normalize(vec3(-g.x * 0.32, 1.0, -g.y * 0.32));

	// water depth along the view ray (shallows near the shore)
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float thickness = max(-view.z - (-VERTEX.z), 0.0);
	float shallow = 1.0 - smoothstep(0.0, 6.0, thickness);

	// body color: turquoise shallows, deep blue, gentle wind patches drifting across
	float patch = texture(noise_tex, p * 0.0009 + wind_direction * t * 0.0012).r;
	vec3 body = mix(deep_color, shallow_color, shallow * 0.85);
	body *= 0.86 + 0.28 * patch;
	// light through the wave crests facing the sun
	float crest = clamp(dot(n.xz, normalize(sun_dir.xz + 0.0001)) * 3.0, 0.0, 1.0);
	body += shallow_color * crest * 0.18 * (1.0 - shallow);

	// sky reflection (Fresnel): mirrors the sky gradient, strongest at grazing angles
	vec3 r = reflect(-V, n);
	vec3 sky = mix(horizon_color, sky_color, pow(clamp(r.y, 0.0, 1.0), 0.6));
	float fres = 0.03 + 0.97 * pow(1.0 - clamp(dot(n, V), 0.0, 1.0), 5.0);
	vec3 col = mix(body, sky * 0.92, clamp(fres * 0.85, 0.0, 0.85));

	// sun glitter: broad sheen along the sun path plus sharp sparkles on the small waves
	float rs = clamp(dot(r, normalize(sun_dir)), 0.0, 1.0);
	float sheen = pow(rs, 40.0) * 0.6 + pow(rs, 400.0) * 3.0;
	float sparkle_n = texture(noise_tex, rot(p, 0.7) * 0.9 + t * 0.35).r;
	float sparkle = smoothstep(0.985, 1.0, rs) * smoothstep(0.62, 0.8, sparkle_n) * 6.0 * detail;
	col += sun_color * (sheen + sparkle);

	// whitecaps: few, only where two wave layers meet, close to mid distance
	float wc = texture(noise_tex, rot(p, 0.9) * 0.021 + wind_direction * t * 0.03).r * texture(noise_tex, rot(p, -1.3) * 0.043 - t * 0.02).r;
	float caps = smoothstep(0.52, 0.6, wc) * (1.0 - smoothstep(60.0, 320.0, dist)) * 0.7;
	// shore foam: bands running up the beach
	float n3 = texture(noise_tex, p * 0.45 + vec2(t * 0.015, -t * 0.01)).r;
	float shore = (1.0 - smoothstep(0.0, 0.5, thickness)) * smoothstep(0.3, 0.6, n3);
	float bands = smoothstep(0.55, 0.75, fract(thickness * 1.2 - t * 0.22 + n3 * 0.8)) * (1.0 - smoothstep(0.0, 2.5, thickness));
	float foam = clamp(max(caps, shore * 0.9 + bands * 0.5), 0.0, 1.0);
	col = mix(col, foam_color * (0.8 + sun_color * 0.25), foam);

	// far away the sea melts into the sky's horizon band (no hard edge where the surface ends)
	col = mix(col, horizon_color * 0.94, smoothstep(700.0, 3000.0, dist));

	ALBEDO = col;
	ALPHA = mix(0.82, 1.0, smoothstep(0.0, 3.0, thickness)) * smoothstep(0.0, 0.05, thickness);
}
