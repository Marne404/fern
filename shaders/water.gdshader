// Anime water: turquoise in the shallows, deep blue in the middle, shore foam, refraction,
// sky reflection via Fresnel and sparkling sun glints.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx, shadows_disabled;
global uniform float daylight;

global uniform vec2 world_origin;
global uniform vec2 wind_direction;
// rings where the scout wades or swims: x, z (local), age in s, strength
global uniform vec4 water_ring0;
global uniform vec4 water_ring1;
global uniform vec4 water_ring2;
global uniform vec4 water_ring3;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
instance uniform vec3 shallow_color : source_color = vec3(0.35, 0.78, 0.72);
instance uniform vec3 deep_color : source_color = vec3(0.08, 0.32, 0.5);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float clarity_depth = 2.2;
instance uniform vec2 flow = vec2(0.0);   // rivers: flow direction * speed (m/s)

varying vec3 v_world;
varying vec2 v_local;

void vertex() {
	vec3 lw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local = lw.xz;
	v_world = lw + vec3(world_origin.x, 0.0, world_origin.y);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// one expanding ring (two crests): x = brightness of the crests, y = radial slope (bends the reflection)
vec2 ring(vec2 p, vec2 c, float age, float life, float speed, out vec2 dir) {
	vec2 d = p - c;
	float dist = length(d);
	dir = dist > 1e-4 ? d / dist : vec2(0.0);
	if (age < 0.0 || age > life) return vec2(0.0);
	float r = 0.08 + age * speed;
	float fade = 1.0 - age / life;
	float w = 0.07 + age * 0.05;
	float a = (dist - r) / w;
	float b = (dist - r * 0.62) / w;
	float ea = exp(-a * a);
	float eb = exp(-b * b);
	return vec2(ea + 0.5 * eb, -2.0 * a * ea - b * eb) * fade;
}

void fragment() {
	vec2 p = v_world.xz;
	vec2 drift = wind_direction * TIME * 0.02;
	float fs = length(flow);
	// flowing water: the pattern moves with the current, stretched in the flow direction
	vec2 fdir = fs > 0.01 ? flow / fs : vec2(1.0, 0.0);
	vec2 fp = fs > 0.01 ? vec2(dot(p, fdir) * 0.35, dot(p, vec2(-fdir.y, fdir.x))) : p;
	vec2 fo = fs > 0.01 ? vec2(-TIME * fs * 0.35 * 0.06, 0.0) : drift;
	float n1 = texture(noise_tex, fp * 0.06 + fo).r;
	float n2 = texture(noise_tex, fp * 0.13 + fo * 1.6 + 0.5).r;
	float n3 = texture(noise_tex, p * 0.45 + vec2(TIME * 0.015, -TIME * 0.01)).r;
	vec3 nmap = normalize(vec3((n1 - n2) * 0.9 + (n3 - 0.5) * 0.3, 1.0, (n2 - n1 * 0.7 - 0.15) * 0.9));

	// rings: the scout's steps/strokes and, on still water, now and then a rising fish or a water strider
	float rings = 0.0;
	vec2 rdir;
	vec4 wr[4] = vec4[4](water_ring0, water_ring1, water_ring2, water_ring3);
	for (int i = 0; i < 4; i++) {
		vec2 v = ring(v_local, wr[i].xy, wr[i].z, 2.4, 0.9, rdir) * wr[i].w;
		rings += v.x;
		nmap.xz += rdir * v.y * 0.35;
	}
	float near = 1.0 - smoothstep(20.0, 40.0, length(VERTEX));
	if (fs < 0.01 && near > 0.0) {
		vec2 cell = floor(p / 7.0);
		float hc = hash1(cell);
		float period = 7.0 + hc * 9.0;
		float t = TIME + hc * 37.0;
		float cyc = floor(t / period);
		if (hash1(cell + cyc * 1.37) < 0.45) {
			// center far enough from the cell edge that the ring is never cut off
			vec2 c = (cell + 0.22 + 0.56 * vec2(hash1(cell + cyc), hash1(cell - cyc * 0.7))) * 7.0;
			vec2 v = ring(p, c, t - cyc * period, 2.8, 0.45, rdir) * near;
			rings += v.x;
			nmap.xz += rdir * v.y * 0.35;
		}
	}
	nmap = normalize(nmap);

	// water depth along the view ray
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float thickness = max(-view.z - (-VERTEX.z), 0.0);
	float depth_fac = smoothstep(0.0, 3.5, thickness);

	// refraction: let the bottom show through slightly distorted
	vec2 refr_uv = SCREEN_UV + nmap.xz * 0.02 * smoothstep(0.0, 1.0, thickness);
	float refr_depth = texture(depth_tex, refr_uv).r;
	vec4 rv = INV_PROJECTION_MATRIX * vec4(refr_uv * 2.0 - 1.0, refr_depth, 1.0);
	if (-(rv.z / rv.w) < -VERTEX.z) {
		refr_uv = SCREEN_UV; // don't distort anything in front of the water surface
	}
	vec3 under = textureLod(screen_tex, refr_uv, 0.0).rgb;

	// Genshin water: strong turquoise in the shallows, clear blue in the depth
	vec3 water = mix(shallow_color * vec3(0.85, 1.05, 1.1), deep_color * vec3(0.9, 1.0, 1.15), depth_fac);
	float clarity = exp(-thickness / clarity_depth);
	vec3 body = mix(water, under * mix(vec3(1.0), shallow_color * 1.4, 0.4), clarity * 0.75);

	// shore foam in lines that run gently onto the shore
	float shore = (1.0 - smoothstep(0.0, 0.35, thickness)) * smoothstep(0.3, 0.6, n3 + n1 * 0.3);
	float bands = smoothstep(0.55, 0.75, fract(thickness * 1.6 - TIME * 0.25 + n2 * 0.8));
	float foam = clamp(shore * 0.9 + bands * shore * 0.6, 0.0, 1.0) * smoothstep(0.35, 0.6, n3 + shore * 0.4);
	if (fs > 0.01) {
		// foam streaks that drift with the current
		float streak = texture(noise_tex, vec2(fp.x * 0.08 - TIME * fs * 0.045, fp.y * 0.45)).r;
		foam = max(foam, smoothstep(0.66, 0.78, streak) * 0.55);
	}
	// foam is a close-up detail: no white ring from afar
	foam *= 1.0 - smoothstep(18.0, 60.0, length(VERTEX));
	body = mix(body, foam_color, foam * 0.75);
	body = mix(body, foam_color, clamp(rings, 0.0, 1.0) * 0.4);

	ALBEDO = body * 0.25;
	EMISSION = body * 0.62 * daylight;
	NORMAL_MAP = vec3(nmap.x * 0.5 + 0.5, nmap.z * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.9;
	// ring crests break up the mirror image (otherwise they vanish in the bright reflection)
	ROUGHNESS = max(mix(0.04, 0.5, foam), clamp(rings, 0.0, 1.0) * 0.5);
	SPECULAR = 0.65;
	ALPHA = mix(0.88, 1.0, depth_fac) * smoothstep(0.0, 0.04, thickness);
}

void light() {
	// glitter path: sharp sun reflections on the small waves
	vec3 r = reflect(-LIGHT, NORMAL);
	float rv = clamp(dot(r, VIEW), 0.0, 1.0);
	float sparkle = pow(rv, 900.0) * 30.0 + pow(rv, 120.0) * 2.5 + pow(rv, 12.0) * 0.12;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * sparkle;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * 0.3 / PI;
}
