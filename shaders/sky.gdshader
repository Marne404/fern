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
uniform float cloud_time = 0.0;     // drift time from the game: runs faster in gusts
uniform float cirrus_amount = 0.6;
uniform float sun_size = 1.0;
uniform float sun_glow = 0.35;
uniform float horizon_haze = 1.0;
uniform float rainbow = 0.0;
uniform float cloud_detail = 0.0;   // Ultra: finer cloud structure
uniform float sea_amount = 0.0;     // coast: below the horizon the sky continues as sea haze
uniform vec3 sea_color : source_color = vec3(0.3, 0.45, 0.6);
uniform float stars = 0.0;          // night: star field
uniform float moon = 0.0;           // 1 = the light is the moon: a moon disc instead of the sun
uniform float sky_towers = 0.0;     // towering cumulus on the horizon
uniform float sky_mackerel = 0.0;   // small high cloudlets (altocumulus)
uniform float sky_bands = 0.0;      // pastel strata along the horizon (golden hour, dusk)
uniform float aurora = 0.0;         // northern lights (night)
uniform float shooting_stars = 0.0; // how often a shooting star crosses the night sky
uniform float shooting_seed = 0.0;  // debug: shifts the shooting stars' timing

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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

// towering cumulus rising from the horizon: a skyline of heaped clouds around the whole horizon
vec4 towers(vec3 d, float h, vec3 sun_dir, float t) {
	float az = atan(d.x, d.z);
	// silhouette: a few big heads with smaller puffs on their flanks (wrapped noise around the circle)
	vec2 ring = vec2(cos(az), sin(az));
	float big = texture(cloud_noise, ring * 0.22 + vec2(0.31 + t * 0.02, 0.57)).r;
	float small = texture(cloud_noise, ring * 0.9 + vec2(0.13, 0.29 + t * 0.03)).r;
	float top = sky_towers * (smoothstep(0.36, 0.72, big) * 0.36 + smoothstep(0.35, 0.85, small) * 0.06);
	// cauliflower edge: round cells along the boundary
	float cells = texture(cloud_cells, vec2(az * 2.2, h * 7.0) + vec2(t * 0.01, 0.0)).r;
	float cells2 = texture(cloud_cells, vec2(az * 6.0, h * 16.0) + vec2(0.37, t * 0.02)).r;
	float edge = top + ((cells - 0.5) * 0.05 + (cells2 - 0.5) * 0.02) * smoothstep(0.02, 0.1, top);
	float m = smoothstep(edge, edge - 0.006, h) * smoothstep(-0.01, 0.01, h) * step(0.004, top);
	if (m <= 0.0) {
		return vec4(0.0);
	}
	// light: sunlit tops and sun-facing flanks cream, bases and far flanks blue-grey
	float rel = clamp(h / max(top, 0.01), 0.0, 1.0);
	vec2 sun_az = normalize(sun_dir.xz + 0.0001);
	float facing = dot(normalize(d.xz + 0.0001), sun_az) * 0.5 + 0.5;
	float lit = clamp(0.25 + rel * 0.55 + facing * 0.35 + (cells - 0.5) * 0.4, 0.0, 1.0);
	vec3 base = mix(cloud_shadow * vec3(0.9, 0.95, 1.05), horizon_color, 0.35);
	vec3 c = mix(base, cloud_color * 1.02, smoothstep(0.3, 0.85, lit));
	// silver rim towards the sun, hazy feet that melt into the horizon
	c += LIGHT0_COLOR * (1.0 - smoothstep(0.0, 0.012, edge - h)) * pow(facing, 3.0) * 0.35;
	c = mix(horizon_color * 1.03, c, smoothstep(0.0, 0.08, h) * 0.8 + 0.2);
	return vec4(c, m);
}

// mackerel sky: a field of small cloudlets high up, in soft ripples
float mackerel(vec2 plane, float hh, float t) {
	vec2 axis = normalize(vec2(0.6, 0.8));
	vec2 p = vec2(dot(plane, axis), dot(plane, vec2(-axis.y, axis.x)) * 1.6) * 0.55 + vec2(t * 0.6, 0.0);
	float cell = texture(cloud_cells, p).r;
	float ripple = texture(cloud_noise, p * 0.08 + 0.4).r;
	float field = smoothstep(0.42, 0.62, texture(cloud_noise, plane * 0.018 + 0.77 + t * 0.1).r);
	float v = smoothstep(0.55, 0.72, cell * 0.8 + ripple * 0.35);
	return v * field * smoothstep(0.18, 0.4, hh);
}

// thin pastel strata along the horizon
float bands(vec3 d, float h, float t) {
	float az = atan(d.x, d.z);
	vec2 ring = vec2(cos(az), sin(az));
	float s = texture(cloud_noise, ring * 1.4 + vec2(h * 22.0, t * 0.05)).r;
	float layer = smoothstep(0.5, 0.75, s) * smoothstep(0.006, 0.03, h) * (1.0 - smoothstep(0.07, 0.15, h));
	return layer;
}

// northern lights: curtains with vertical rays over the forward (northern) sky
vec3 aurora_light(vec3 d, float h, float time) {
	if (h < 0.03) {
		return vec3(0.0);
	}
	float az = atan(d.x, -d.z);                      // 0 = straight ahead (−z)
	float sector = 1.0 - smoothstep(1.0, 1.9, abs(az));
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		// the curtain's lower edge waves slowly along the sky
		float base = 0.14 + fk * 0.07 + 0.05 * sin(az * 2.3 + time * 0.07 + fk * 2.0) + 0.03 * sin(az * 5.1 - time * 0.11 + fk);
		float above = h - base;
		if (above < -0.01) {
			continue;
		}
		float rays = texture(cloud_noise, vec2(az * (3.2 + fk) + time * 0.012, fk * 0.37)).r;
		rays = 0.35 + 0.65 * smoothstep(0.35, 0.8, rays);
		float fine = 0.75 + 0.25 * sin(az * 90.0 + time * 0.6 + fk * 3.0);
		float body = smoothstep(-0.01, 0.015, above) * exp(-max(above, 0.0) / (0.16 + fk * 0.06));
		vec3 green = vec3(0.25, 1.0, 0.62);
		vec3 violet = vec3(0.62, 0.35, 1.0);
		vec3 c = mix(green, violet, smoothstep(0.04, 0.3, above));
		// the violet tops fade out well below the zenith
		acc += c * body * rays * fine * (fk == 0.0 ? 1.0 : 0.6) * (1.0 - smoothstep(0.3, 0.6, h));
	}
	return acc * sector;
}

// shooting stars: a few slots, each fires now and then along its own path
vec3 shooting(vec3 d, float h, float time) {
	vec3 acc = vec3(0.0);
	if (h < 0.08) {
		return acc;
	}
	vec2 p = d.xz / (h + 0.4);
	for (int k = 0; k < 3; k++) {
		float fk = float(k) + 1.0;
		float period = 22.0 + fk * 9.0;
		float tt = (time + shooting_seed * 7.0) / period + fk * 0.37;
		float slot = floor(tt);
		float ph = fract(tt) * period;           // seconds since this slot's start
		float dur = 0.9;
		if (shooting_seed < -0.5) {
			// debug (screenshots): every slot in mid-flight
			ph = 0.5;
		} else if (ph > dur || hash21(vec2(slot, fk)) > shooting_stars * 0.9) {
			continue;
		}
		vec2 a = vec2(hash21(vec2(slot, fk * 3.1)), hash21(vec2(slot, fk * 5.7))) * 1.6 - 0.8;
		float ang = hash21(vec2(slot, fk * 9.3)) * 6.2832;
		vec2 dir = vec2(cos(ang), sin(ang));
		float k01 = ph / dur;
		vec2 head = a + dir * (0.15 + k01 * 0.55);
		vec2 tail = head - dir * 0.22;
		vec2 pa = p - tail;
		float along = clamp(dot(pa, dir) / 0.22, 0.0, 1.0);
		float dist = length(pa - dir * along * 0.22);
		float line = smoothstep(0.006, 0.0, dist) * along * along;
		float life = smoothstep(0.0, 0.12, k01) * (1.0 - smoothstep(0.7, 1.0, k01));
		acc += vec3(0.95, 0.97, 1.0) * line * life * 2.2;
	}
	return acc;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	// anime sky: strong cobalt blue far down, bright, clear horizon band
	vec3 zen = zenith_color;
	vec3 col = mix(horizon_color, zen, pow(clamp(h, 0.0, 1.0), 0.48));
	col = mix(col, horizon_color * 1.04, exp(-max(h, 0.0) * 16.0) * horizon_haze * 0.65);

	// stars: two layers of twinkling points and a faint milky band, fading into the horizon glow
	if (stars > 0.0 && h > 0.0 && !AT_CUBEMAP_PASS) {
		float fade = smoothstep(0.03, 0.3, h) * stars;
		for (int layer = 0; layer < 2; layer++) {
			float sc = layer == 0 ? 55.0 : 120.0;
			vec2 sp = d.xz / (h + 0.4) * sc + float(layer) * 31.7;
			vec2 cell = floor(sp);
			float r = hash21(cell);
			float thr = layer == 0 ? 0.972 : 0.955;
			if (r > thr) {
				vec2 off = vec2(hash21(cell + 3.1), hash21(cell + 7.7)) * 0.6 + 0.2;
				float dd = length(fract(sp) - off);
				float tw = 0.65 + 0.35 * sin(TIME * (1.3 + r * 3.0) + r * 60.0);
				float size = layer == 0 ? 0.16 : 0.09;
				float st = smoothstep(size, 0.0, dd) * tw * (0.4 + 0.6 * (r - thr) / (1.0 - thr));
				vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash21(cell + 1.3));
				col += tint * st * fade * (layer == 0 ? 1.3 : 0.7);
			}
		}
		vec3 band_axis = normalize(vec3(0.35, 0.25, 0.9));
		float band = exp(-pow(dot(d, band_axis) * 3.2, 2.0));
		float mw = texture(cloud_noise, d.xz / (h + 0.5) * 0.35 + 0.2).r;
		col += vec3(0.28, 0.3, 0.45) * band * smoothstep(0.35, 0.8, mw) * fade * 0.35;
		if (aurora > 0.0) {
			col += aurora_light(d, h, TIME) * aurora * stars * 0.55;
		}
		if (shooting_stars > 0.0) {
			col += shooting(d, h, TIME) * fade;
		}
	}

	vec3 sun_dir = LIGHT0_DIRECTION;
	float sd = dot(d, sun_dir);
	col += LIGHT0_COLOR * pow(max(sd, 0.0), 10.0) * sun_glow;
	col += LIGHT0_COLOR * pow(max(sd, 0.0), 300.0) * 0.5;

	if (h > -0.02) {
		float hh = max(h, 0.0);
		vec2 plane = d.xz / (hh + 0.09);
		vec2 plane_c = d.xz / (hh + 0.2);   // cumulus: less distortion at the horizon
		float t = cloud_time * cloud_speed;

		// towering cumulus far away on the horizon (behind every other cloud)
		if (sky_towers > 0.0 && !AT_CUBEMAP_PASS) {
			vec4 tw = towers(d, hh, sun_dir, cloud_time * cloud_speed);
			col = mix(col, tw.rgb, tw.a);
		}
		// pastel strata low on the horizon: gold towards the sun, pink and lilac away from it
		if (sky_bands > 0.0) {
			float bnd = bands(d, hh, cloud_time * cloud_speed);
			float toward = pow(max(sd, 0.0), 2.0);
			vec3 bcol = mix(mix(cloud_color, vec3(1.0, 0.72, 0.8), 0.35), LIGHT0_COLOR * 1.1 + cloud_color * 0.2, toward);
			col = mix(col, bcol, bnd * sky_bands * 0.85);
		}
		// cirrus: long, thin streaks high up
		vec2 axis = normalize(vec2(0.8, -0.6));
		vec2 cp = vec2(dot(plane, axis) * 0.012, dot(plane, vec2(-axis.y, axis.x)) * 0.16);
		float cir = texture(cloud_noise, cp + vec2(t * 0.4, 0.0)).r;
		float cir_mask = texture(cloud_noise, plane * 0.012 + 0.5).r;
		cir = smoothstep(0.58, 0.7, cir) * smoothstep(0.45, 0.65, cir_mask);
		col = mix(col, vec3(1.0), cir * cirrus_amount * 0.6 * smoothstep(0.08, 0.35, hh));
		// mackerel sky: small cloudlets, their undersides tinted by the low sun
		if (sky_mackerel > 0.0) {
			float mk = mackerel(plane, hh, t);
			vec3 mcol = mix(cloud_shadow * 1.05, cloud_color, 0.7) + LIGHT0_COLOR * pow(max(sd, 0.0), 3.0) * 0.25;
			col = mix(col, mcol, mk * sky_mackerel * 0.85);
		}

		// cumulus: denser low at the horizon (cloud banks), looser higher up
		vec2 uv = plane_c * 0.11 + vec2(t, t * 0.3);
		float cov = cloud_coverage + 0.05 * smoothstep(0.05, 0.45, hh) - 0.06 * (1.0 - smoothstep(0.02, 0.18, hh));
		// towers and mackerel skies want room: the ordinary heaps thin out when they are strong
		cov += 0.2 * clamp(max(sky_towers, sky_mackerel * 0.85), 0.0, 1.0);
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
		cc += cloud_color * edge * 0.12;
		cc += LIGHT0_COLOR * edge * pow(max(sd, 0.0), 8.0) * 1.1;
		float fade = smoothstep(-0.02, 0.06, h);
		cc = mix(horizon_color * 1.06, cc, smoothstep(0.0, 0.12, hh) * 0.75 + 0.25);
		col = mix(col, cc, c * fade);
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.3, h));
		col = mix(col, mix(horizon_color * 0.94, sea_color, smoothstep(0.0, -0.25, h)), sea_amount);
	}

	if (rainbow > 0.0 && h > 0.0) {
		// strong rainbows (after a shower) are wider, brighter and reach higher
		float rb = clamp(rainbow, 0.0, 1.5);
		col += rainbow_color(d, sun_dir) * rb * mix(0.3, 0.55, smoothstep(0.6, 1.2, rb)) * smoothstep(0.0, 0.05, h) * (1.0 - smoothstep(mix(0.35, 0.6, smoothstep(0.6, 1.2, rb)), 0.8, h));
	}
	float sun = smoothstep(0.99955 - sun_size * 0.0001, 0.9997, sd);
	if (!AT_CUBEMAP_PASS) {
		if (moon > 0.5) {
			// moon: a pale disc with soft maria and a cool halo (behind clouds only where they are thin)
			float md = smoothstep(0.99925, 0.99942, sd);
			vec3 mcol = vec3(0.93, 0.95, 1.0) * (0.78 + 0.22 * texture(cloud_noise, d.xz * 18.0 + 0.4).r);
			col = mix(col, mcol * 1.25, md);
			col += vec3(0.5, 0.6, 0.9) * pow(max(sd, 0.0), 600.0) * 0.35;
		} else {
			col += LIGHT0_COLOR * sun * 3.0;
		}
	}
	COLOR = col;
}
