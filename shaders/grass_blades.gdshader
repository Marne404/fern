// Anime grass carpet made of real blades.
// Mesh: a 2×2 m patch full of curved blades. UV.y = height along the blade (0 root, 1 tip),
// UV2 = root position in the patch, CUSTOM0 = random values per blade (color, height, bend, phase).
// Per instance (patch): INSTANCE_CUSTOM = ground heights at the 4 corners (relative), tile uniforms for path/pond/colors.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/wind.gdshaderinc"

global uniform vec3 player_pos;

uniform float patch_size = 2.0;
uniform float blade_height = 0.5;
uniform float fade_start = 20.0;
uniform float fade_end = 28.0;

instance uniform vec3 root_color : source_color = vec3(0.1, 0.3, 0.05);
instance uniform vec3 tip_color : source_color = vec3(0.55, 0.85, 0.2);
instance uniform vec3 tip_color2 : source_color = vec3(0.85, 0.8, 0.3);
instance uniform vec3 root_color_b : source_color = vec3(0.1, 0.3, 0.05);
instance uniform vec3 tip_color_b : source_color = vec3(0.55, 0.85, 0.2);
instance uniform vec3 tip_color2_b : source_color = vec3(0.85, 0.8, 0.3);
instance uniform vec2 tile_z = vec2(0.0, 8.0);   // z start of the tile (world) and tile size
uniform float near_radius = 20.0;
instance uniform vec4 path_line = vec4(0.0, 0.0, 0.0, 1.0);  // point (world xz) and direction
// height at tile start, height at tile end, dense near mesh (1/0), half path width – combined,
// because a shader may have at most 16 instance parameters
instance uniform vec4 params = vec4(1.0, 1.0, 1.0, 1.6);
instance uniform vec4 pond = vec4(0.0, 0.0, 0.0, -10000.0);   // x, z, radius, water level
instance uniform vec4 rock0 = vec4(0.0);   // rock footprints: x, z, radius
instance uniform vec4 rock1 = vec4(0.0);
instance uniform vec4 rock2 = vec4(0.0);
instance uniform vec4 rock3 = vec4(0.0);

varying float v_t;
varying vec3 v_root;
varying vec3 v_col;
varying float v_cloud;
varying float v_gust;
varying float v_short;
varying float v_flower;
varying vec3 v_flower_col;

float bilerp(vec4 c, vec2 f) {
	return mix(mix(c.x, c.y, f.x), mix(c.z, c.w, f.x), f.y);
}

void vertex() {
	float t = UV.y;
	vec2 root_local = UV2;
	vec4 rnd = CUSTOM0;

	// root in world coordinates
	vec3 root_w = (MODEL_MATRIX * vec4(root_local.x, 0.0, root_local.y, 1.0)).xyz;
	vec3 root_world = to_world(root_w);

	// ground height exactly from the 4 corners of the patch
	float ground = bilerp(INSTANCE_CUSTOM, root_local / patch_size);

	// blend biome colors and height within the tile (no color tiles at biome borders)
	float tz = clamp((root_world.z - tile_z.x) / tile_z.y, 0.0, 1.0);
	float hs = mix(params.x, params.y, tz);
	// clumps: height varies in patches, plus small clearings
	float clump = textureLod(wind_noise, root_world.xz * 0.045, 0.0).r;
	float clump2 = textureLod(wind_noise, root_world.xz * 0.19 + 0.3, 0.0).r;
	float h = blade_height * hs * (0.45 + rnd.y * 0.75) * (0.55 + clump * 0.9) * smoothstep(0.18, 0.4, clump2 + clump * 0.3);

	// leave out the path (distance to the tile's path line), soft transition at the edge
	vec2 rel = root_world.xz - path_line.xy;
	float d_path = abs(rel.x * path_line.w - rel.y * path_line.z);
	h *= smoothstep(params.w * 0.85, params.w * 1.35, d_path);
	// leave out the pond
	float d_pond = length(root_world.xz - pond.xy);
	if (pond.w > -9999.0 && d_pond < pond.z * 1.08) {
		h *= step(pond.w + 0.12, ground + MODEL_MATRIX[3].y);
	}
	// nothing grows under rocks
	if (length(root_world.xz - rock0.xy) < rock0.z || length(root_world.xz - rock1.xy) < rock1.z
			|| length(root_world.xz - rock2.xy) < rock2.z || length(root_world.xz - rock3.xy) < rock3.z) {
		h = 0.0;
	}
	// steepness per blade from the patch's corner heights: no grass on rock walls, soft transition
	vec2 fp = root_local / patch_size;
	float dhx = mix(INSTANCE_CUSTOM.y - INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.w - INSTANCE_CUSTOM.z, fp.y) / patch_size;
	float dhz = mix(INSTANCE_CUSTOM.z - INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.w - INSTANCE_CUSTOM.y, fp.x) / patch_size;
	h *= 1.0 - smoothstep(0.7, 1.0, length(vec2(dhx, dhz)));
	// get shorter towards the distance instead of vanishing abruptly
	float dist = length(root_w - CAMERA_POSITION_WORLD);
	h *= 1.0 - smoothstep(fade_start, fade_end, dist);
	// the dense near mesh thins out towards its edge to the far mesh density (no visible ring)
	if (params.z > 0.5) {
		float thin = smoothstep(near_radius - 12.0, near_radius, dist);
		h *= step(thin * 0.78, fract(rnd.x * 13.7 + rnd.z * 3.1));
	}

	// shape: blade geometry is in the mesh with unit height
	vec3 p = VERTEX;
	p.y = 0.0;
	vec3 blade_off = VERTEX - vec3(root_local.x, 0.0, root_local.y);
	blade_off.y = 0.0;
	float bend_rest = (rnd.z - 0.5) * 0.6;

	// wind: large waves + flutter
	float time = TIME;
	float gust = wind_gust(root_world.xz, time);
	float wave = sin(time * 1.6 - dot(root_world.xz, wind_direction) * 0.35 + rnd.w * 1.5) * 0.5 + 0.5;
	float flutter = sin(time * 6.0 + rnd.w * 12.0) * 0.06;
	float bend = (gust * 0.75 + wave * 0.25 + 0.08) * wind_strength;
	vec3 wdir = vec3(wind_direction.x, 0.0, wind_direction.y);

	// the player pushes the grass aside
	vec3 to_blade = root_w - player_pos;
	float pd = length(to_blade.xz);
	float push = (1.0 - smoothstep(0.35, 1.3, pd)) * step(abs(to_blade.y), 2.5);
	vec3 push_dir = normalize(vec3(to_blade.x, 0.0, to_blade.z) + vec3(0.0001));

	vec3 world_bend = wdir * bend * 0.55 + vec3(flutter, 0.0, flutter * 0.7) + push_dir * push * 0.9;
	vec3 local_bend = world_to_model_dir(MODEL_MATRIX, world_bend);
	float curve = t * t;
	// make very short blades (path, pond, distance) narrow too, otherwise flat triangles remain
	float keep = smoothstep(0.02, 0.12, h) * clamp(h / (blade_height * 0.6), 0.2, 1.0);
	vec3 pos = vec3(root_local.x, ground, root_local.y) + blade_off * (1.0 - t * 0.6) * keep;
	pos.y += t * h * (1.0 - push * 0.55);
	pos += (local_bend + vec3(bend_rest, 0.0, bend_rest * 0.5)) * curve * h;
	// blades must not dip into the ground when bending
	pos.y = max(pos.y, ground + t * h * 0.25);
	if (keep < 0.001) {
		pos = vec3(root_local.x, ground - 0.05, root_local.y);
	}
	VERTEX = pos;

	// soft normals pointing to the sky (anime look)
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));

	// color per blade
	float region = textureLod(wind_noise, root_world.xz * 0.011 + 0.7, 0.0).r;
	vec3 tc = mix(tip_color, tip_color_b, tz);
	vec3 tc2 = mix(tip_color2, tip_color2_b, tz);
	vec3 tip = mix(tc, tc2, smoothstep(0.55, 0.75, region + (rnd.x - 0.5) * 0.25));
	tip *= 0.85 + rnd.x * 0.3;
	v_col = tip;
	v_root = mix(root_color, root_color_b, tz);
	v_t = t;
	v_cloud = cloud_shadow_fast(root_world.xz, time);
	v_gust = gust;
	v_short = 1.0 - smoothstep(0.08, 0.3, h);
	// a few blades carry small flower heads (white, yellow, pink, blue)
	v_flower = step(0.955, fract(rnd.x * 7.31 + rnd.w * 3.17)) * step(0.15, h);
	float fc = fract(rnd.w * 5.13);
	v_flower_col = fc < 0.4 ? vec3(1.0, 0.98, 0.92) : (fc < 0.7 ? vec3(1.0, 0.86, 0.25) : (fc < 0.88 ? vec3(1.0, 0.62, 0.78) : vec3(0.55, 0.7, 1.0)));
}

void fragment() {
	float t = v_t;
	vec3 root = v_root;
	root = mix(root, v_col * 0.55, 0.25);
	vec3 col = mix(root, v_col, smoothstep(0.0, 0.85, t));
	// don't show short blades (path edge, clearings) as dark stubble
	col = mix(col, v_col * 0.85, v_short * 0.8);
	// wind wave: tips shimmer brightly
	col = mix(col, col * 1.3 + vec3(0.05, 0.06, 0.0), v_gust * t * t * 0.6);
	// contact shadow at the root
	col *= mix(mix(0.55, 0.9, v_short), 1.0, smoothstep(0.0, 0.35, t));
	// flower head at the tip
	col = mix(col, v_flower_col, v_flower * smoothstep(0.82, 0.92, t));
	// snow: the blades are bent under a white dusting
	col = mix(col, vec3(0.9, 0.93, 1.0), clamp(snow_cover * 1.3, 0.0, 1.0) * mix(0.35, 0.8, t));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.0);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float sun = 1.0 - v_cloud;
	float ndl = dot(NORMAL, LIGHT);
	float diff = smoothstep(-0.2, 0.9, ndl) * 0.8 + 0.2;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diff * sun / PI;
	// translucency in backlight
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * back * v_t * 0.4 * sun / PI;
	// anime sheen on the tips
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 24.0) * v_t * v_t;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * 0.15 * sun;
	// cool shadow side
	DIFFUSE_LIGHT += vec3(0.05, 0.08, 0.14) * (1.0 - clamp(ndl * ATTENUATION, 0.0, 1.0)) * 0.35;
}
