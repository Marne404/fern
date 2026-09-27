// Anime water: turquoise in the shallows, deep blue in the middle, shore foam, refraction,
// sky reflection via Fresnel and sparkling sun glints.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx, shadows_disabled;

global uniform vec2 world_origin;
global uniform vec2 wind_direction;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
instance uniform vec3 shallow_color : source_color = vec3(0.35, 0.78, 0.72);
instance uniform vec3 deep_color : source_color = vec3(0.08, 0.32, 0.5);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
uniform float clarity_depth = 2.2;
instance uniform vec2 flow = vec2(0.0);   // rivers: flow direction * speed (m/s)

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
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

	ALBEDO = body * 0.25;
	EMISSION = body * 0.62;
	NORMAL_MAP = vec3(nmap.x * 0.5 + 0.5, nmap.z * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = mix(0.04, 0.5, foam);
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
