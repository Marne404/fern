// Anime sky: gradient, sun, crisply outlined cumulus and cirrus clouds.
shader_type sky;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_cells : filter_linear_mipmap, repeat_enable;   // round cells = cloud puffs
uniform vec3 zenith_color : source_color = vec3(0.22, 0.58, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.9, 0.98);
uniform vec3 ground_color : source_color = vec3(0.6, 0.7, 0.6);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.62, 0.7, 0.86);
uniform float cloud_coverage = 0.5;
uniform float cloud_speed = 0.003;
uniform float cirrus_amount = 0.6;
uniform float sun_size = 1.0;
uniform float sun_glow = 0.35;
uniform float horizon_haze = 1.0;
uniform float rainbow = 0.0;
uniform float cloud_detail = 0.0;   // Ultra: finer cloud structure

float cloud_field(vec2 uv) {
	float n = texture(cloud_noise, uv).r * 0.72;
	n += texture(cloud_noise, uv * 2.9 + 0.37).r * 0.2;
	n += texture(cloud_noise, uv * 7.3 + 0.71).r * 0.08;
	if (cloud_detail > 0.0) {
		n += (texture(cloud_noise, uv * 17.0 + 0.13).r - 0.5) * 0.05 * cloud_detail;
	}
	return n;
}

// rainbow: arc at 42° around the sun's antipode
vec3 rainbow_color(vec3 d, vec3 sun_dir) {
	// sun's antipode raised artistically so the arc stands above the land even with a high sun
	vec3 anti = -sun_dir;
	anti.y = max(anti.y, -0.22);
	anti = normalize(anti);
	float a = degrees(acos(clamp(dot(d, anti), -1.0, 1.0)));
	float x = (a - 40.5) / 3.2;
	if (x < 0.0 || x > 1.0) return vec3(0.0);
	vec3 spec = clamp(vec3(abs(x * 6.0 - 3.0) - 1.0, 2.0 - abs(x * 6.0 - 2.0), 2.0 - abs(x * 6.0 - 4.0)), 0.0, 1.0);
	return spec.bgr * sin(x * 3.14159);
}

// cloud density with turbulence: round, towering heaps instead of flat blotches
float puffs(vec2 uv) {
	vec2 w = vec2(texture(cloud_noise, uv * 0.45 + 0.21).r, texture(cloud_noise, uv * 0.45 + 0.67).r) - 0.5;
	float n = cloud_field(uv + w * 0.18);
	// round puffs from cellular noise (large + small) – gives the towering cumulus shape
	float b1 = texture(cloud_cells, uv * 0.9 + w * 0.3).r;
	float b2 = texture(cloud_cells, uv * 2.6 + 0.4 + w * 0.2).r;
	// large-scale mask: cloud groups with lots of open blue in between
	float group = smoothstep(0.38, 0.62, texture(cloud_noise, uv * 0.16 + 0.83).r);
	return (n * 0.6 + b1 * 0.34 + b2 * 0.06) * mix(0.84, 1.06, group);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	// anime sky: strong cobalt blue far down, bright, clear horizon band
	vec3 zen = zenith_color;
	vec3 col = mix(horizon_color, zen, pow(clamp(h, 0.0, 1.0), 0.48));
	col = mix(col, horizon_color * 1.04, exp(-max(h, 0.0) * 16.0) * horizon_haze * 0.65);

	vec3 sun_dir = LIGHT0_DIRECTION;
	float sd = dot(d, sun_dir);
	col += LIGHT0_COLOR * pow(max(sd, 0.0), 10.0) * sun_glow;
	col += LIGHT0_COLOR * pow(max(sd, 0.0), 300.0) * 0.5;

	if (h > -0.02) {
		float hh = max(h, 0.0);
		vec2 plane = d.xz / (hh + 0.09);
		vec2 plane_c = d.xz / (hh + 0.2);   // cumulus: less distortion at the horizon
		float t = TIME * cloud_speed;

		// cirrus: long, thin streaks high up
		vec2 axis = normalize(vec2(0.8, -0.6));
		vec2 cp = vec2(dot(plane, axis) * 0.012, dot(plane, vec2(-axis.y, axis.x)) * 0.16);
		float cir = texture(cloud_noise, cp + vec2(t * 0.4, 0.0)).r;
		float cir_mask = texture(cloud_noise, plane * 0.012 + 0.5).r;
		cir = smoothstep(0.58, 0.7, cir) * smoothstep(0.45, 0.65, cir_mask);
		col = mix(col, vec3(1.0), cir * cirrus_amount * 0.6 * smoothstep(0.08, 0.35, hh));

		// cumulus: denser low at the horizon (cloud banks), looser higher up
		vec2 uv = plane_c * 0.11 + vec2(t, t * 0.3);
		float cov = cloud_coverage + 0.05 * smoothstep(0.05, 0.45, hh) - 0.06 * (1.0 - smoothstep(0.02, 0.18, hh));
		float n = puffs(uv);
		float c = smoothstep(cov, cov + 0.025, n);
		// volume from the density gradient: top edge in the image (towards the viewer) bright,
		// underside (towards the horizon) bluish, sun-facing side brighter
		vec2 radial = normalize(plane_c + 0.0001);
		float e = 0.022;
		float g_up = puffs(uv + radial * e) - puffs(uv - radial * e);
		vec2 to_sun = normalize(sun_dir.xz + 0.0001);
		float g_sun = puffs(uv - to_sun * e) - puffs(uv + to_sun * e);
		float inner = smoothstep(cov, cov + 0.22, n);
		float lit = clamp(0.62 + g_up * 7.0 + g_sun * 3.0 - inner * 0.18, 0.0, 1.0);
		vec3 shadow_col = mix(cloud_shadow * vec3(0.88, 0.94, 1.06), zen * 0.45 + vec3(0.45), 0.45);
		vec3 cc = mix(shadow_col, cloud_color, smoothstep(0.25, 0.8, lit));
		// thin edges glow, as a silver lining in backlight
		float edge = 1.0 - smoothstep(cov + 0.01, cov + 0.07, n);
		cc += vec3(1.0) * edge * 0.12;
		cc += LIGHT0_COLOR * edge * pow(max(sd, 0.0), 8.0) * 1.1;
		float fade = smoothstep(-0.02, 0.06, h);
		cc = mix(horizon_color * 1.06, cc, smoothstep(0.0, 0.12, hh) * 0.75 + 0.25);
		col = mix(col, cc, c * fade);
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.3, h));
	}

	if (rainbow > 0.0 && h > 0.0) {
		col += rainbow_color(d, sun_dir) * rainbow * 0.3 * smoothstep(0.0, 0.05, h) * (1.0 - smoothstep(0.35, 0.6, h));
	}
	float sun = smoothstep(0.99955 - sun_size * 0.0001, 0.9997, sd);
	if (!AT_CUBEMAP_PASS) {
		col += LIGHT0_COLOR * sun * 3.0;
	}
	COLOR = col;
}
