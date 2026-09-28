// A soft beam of sunlight falling through a gap in a tree crown. The quad turns around the beam's axis
// towards the camera; brightest just under the crown, fading to the ground, with slow drifting streaks.
// INSTANCE_CUSTOM: r = own strength (fade in/out), g = random phase.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 light_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.0;
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying float v_k;
varying float v_phase;
varying float v_facing;
varying float v_len;
varying float v_phase_fn;

void vertex() {
	vec3 axis = MODEL_MATRIX[1].xyz;            // top → ground, length = beam length
	vec3 origin = MODEL_MATRIX[3].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 p = origin + axis * VERTEX.y;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - p);
	vec3 ax = normalize(axis);
	vec3 side = normalize(cross(ax, to_cam));
	// a little wider at the bottom: light spreads
	vec3 world = p + side * VERTEX.x * width * mix(0.8, 1.35, VERTEX.y);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	v_k = INSTANCE_CUSTOM.r;
	v_phase = INSTANCE_CUSTOM.g;
	// seen along the beam the quad degenerates: fade it out
	v_facing = 1.0 - abs(dot(ax, to_cam));
	v_len = length(axis);
	// light scatters forwards: beams glow when you look towards the sun, stay faint with the sun behind you
	float cos_t = dot(-to_cam, normalize(to_sun));
	v_phase_fn = mix(0.35, 2.2, pow(clamp(cos_t * 0.5 + 0.5, 0.0, 1.0), 3.0));
}

void fragment() {
	float u = UV.x;
	float v = 1.0 - UV.y;                        // 0 at the crown, 1 at the ground
	float across = pow(max(1.0 - abs(u * 2.0 - 1.0), 0.0), 1.6);
	// inside the crown the beam is hidden by leaves anyway: bright from a third down, fading to the ground
	float along = smoothstep(0.15, 0.4, v) * (1.0 - smoothstep(0.7, 1.0, v));
	// dusty streaks drifting down the beam, and a slow pulse as leaves move in front of the sun
	float streak = texture(noise_tex, vec2(u * 0.9 + v_phase, v * v_len * 0.05 - TIME * 0.03)).r;
	float pulse = 0.75 + 0.25 * sin(TIME * 0.7 + v_phase * 20.0);
	float a = across * along * mix(0.55, 1.2, streak) * pulse;
	// soft where the beam meets the ground or a trunk, and never right in front of the camera
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -sv.z / sv.w;
	float soft = clamp((scene_z - (-VERTEX.z)) / 1.5, 0.0, 1.0);
	float near = smoothstep(1.5, 5.0, -VERTEX.z);
	ALBEDO = light_color * a * strength * v_k * soft * near * smoothstep(0.05, 0.35, v_facing) * v_phase_fn * 0.7;
}
