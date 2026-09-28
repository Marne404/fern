// Shared wind functions for trees, bushes and grass.
global uniform vec2 wind_direction;
global uniform float wind_strength;
global uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable;
global uniform vec2 world_origin;  // floating origin offset (world coordinates = local + world_origin)

vec3 to_world(vec3 local_world) {
	return local_world + vec3(world_origin.x, 0.0, world_origin.y);
}

global uniform float cloud_shadow_strength;

// Distant trees change to impostors inside this band (meters from the camera, 0 = off). camera_world is the
// camera position in local coordinates, set by the game every frame (the same in the shadow passes).
global uniform vec3 camera_world;
global uniform vec2 impostor_band;

// 1 = the mesh draws this tree, 0 = its impostor does. Every tree switches at its own distance inside the band,
// so there is no line where all trees change at once; mesh and impostor use the same test and never overlap.
float impostor_mesh_keep(vec3 origin_local, float custom_a) {
	if (impostor_band.y <= 0.0) {
		return 1.0;
	}
	float keep = 1.0 - smoothstep(impostor_band.x, impostor_band.y, length(origin_local.xz - camera_world.xz));
	return step(fract(custom_a * 7.13 + 0.37), keep);
}

// cloud shadows drifting slowly across the land with the wind (0 = sun, 1 = full shadow)
float cloud_shadow(vec2 world_xz, float time) {
	vec2 uv = world_xz * 0.0011 - wind_direction * time * 0.0022;
	float n = textureLod(wind_noise, uv, 0.0).r * 0.75 + textureLod(wind_noise, uv * 2.3 + 0.3, 0.0).r * 0.25;
	return smoothstep(0.5, 0.62, n) * cloud_shadow_strength;
}

// cheaper variant (one sample) for very many vertices, e.g. grass blades
float cloud_shadow_fast(vec2 world_xz, float time) {
	vec2 uv = world_xz * 0.0011 - wind_direction * time * 0.0022;
	return smoothstep(0.5, 0.62, textureLod(wind_noise, uv, 0.0).r) * cloud_shadow_strength;
}

// Gusts: large-scale noise that travels across the landscape in the wind direction.
float wind_gust(vec2 world_xz, float time) {
	vec2 uv = world_xz * 0.012 - wind_direction * time * 0.035;
	float n = textureLod(wind_noise, uv, 0.0).r;
	return smoothstep(0.25, 0.85, n);
}

// Offset in world coordinates. weight = 0 at the ground/trunk, 1 at the tip.
vec3 wind_offset_g(vec3 world_pos, vec3 origin, float weight, float stiffness, float flutter, float time, float gust) {
	vec2 dir = normalize(wind_direction);
	float phase = dot(origin.xz, vec2(0.37, 0.61));
	float sway = sin(time * 1.1 + phase) * 0.35 + sin(time * 0.53 + phase * 1.7) * 0.25;
	float bend = (gust * 1.2 + sway * 0.6 + 0.25) * wind_strength / stiffness;
	vec3 offset = vec3(dir.x, 0.0, dir.y) * bend * weight;
	// small flutter of individual leaves/blades
	float f = sin(time * 5.7 + dot(world_pos, vec3(2.3, 1.7, 2.9))) * cos(time * 3.1 + world_pos.y * 3.0);
	offset += vec3(f * 0.6, f * 0.35, -f * 0.5) * flutter * weight * (0.4 + gust) * wind_strength;
	return offset;
}

vec3 wind_offset(vec3 world_pos, vec3 origin, float weight, float stiffness, float flutter, float time) {
	return wind_offset_g(world_pos, origin, weight, stiffness, flutter, time, wind_gust(origin.xz, time));
}

// Convert a world offset into object coordinates (for uniformly scaled instances).
vec3 world_to_model_dir(mat4 model, vec3 v) {
	float s2 = dot(model[0].xyz, model[0].xyz);
	return (transpose(mat3(model)) * v) / s2;
}


// Anime palette: saturated neon yellow-greens become a calm, slightly cool meadow green (Genshin look).
// Other hues (autumn, blossoms, rock) stay untouched.
vec3 grade_green(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 1e-4);
	// share of "green": g dominates
	float green = smoothstep(0.02, 0.2, c.g - max(c.r, c.b)) * smoothstep(0.05, 0.3, sat);
	vec3 cooled = vec3(c.r * 0.84, c.g * 0.97, c.b + (c.g - c.b) * 0.16);
	float l = dot(cooled, vec3(0.3, 0.59, 0.11));
	cooled = mix(vec3(l), cooled, 0.88);
	// keep brightness (Genshin meadows are bright), only change hue and saturation
	float l0 = dot(c, vec3(0.3, 0.59, 0.11));
	cooled *= l0 / max(dot(cooled, vec3(0.3, 0.59, 0.11)), 1e-4) * 1.03;
	return mix(c, cooled, green);
}
