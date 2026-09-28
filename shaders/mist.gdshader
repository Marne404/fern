// Valley mist (mornings): exponential height fog integrated along every view ray, so it lies in the
// hollows, thickens with distance, thins out towards the camera and glows golden towards the low sun.
// Drawn as a full-screen pass after the opaque world (like the sun shafts).
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 world_origin;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float amount = 0.0;          // 0..1 mood strength
uniform float base_y = 0.0;          // valley floor near the camera (local)
uniform float thickness = 7.0;       // height scale of the mist layer (m)
uniform float density = 0.02;        // extinction at the valley floor (1/m)
uniform vec3 mist_color : source_color = vec3(0.9, 0.9, 0.92);
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.6);
uniform vec3 to_sun = vec3(0.0, 0.3, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, max(depth, 1e-7), 1.0);
	vec3 view_pos = v.xyz / v.w;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
	vec3 ray = wp - cam;
	float L = length(ray);
	vec3 dir = ray / max(L, 1e-4);
	if (depth < 1e-6) {
		L = 2500.0;
		wp = cam + dir * L;
	}
	// optical depth of exp(-(y - base) / H) from the camera to the point, analytically
	float H = thickness;
	float c0 = clamp((cam.y - base_y) / H, -2.5, 30.0);
	float k = (wp.y - cam.y) / H;
	float fk = abs(k) < 0.001 ? 1.0 - 0.5 * k : (1.0 - exp(-k)) / k;
	float tau = density * exp(-c0) * L * fk;
	// patches drifting slowly along the valley
	vec2 p = (wp.xz + world_origin);
	float n = textureLod(noise_tex, p * 0.006 + vec2(TIME * 0.004, TIME * 0.0015), 0.0).r;
	float n2 = textureLod(noise_tex, p * 0.019 - vec2(TIME * 0.006, 0.0), 0.0).r;
	// (only near enough: far away the patches would alias into streaks, there the mist is even anyway)
	float patchy = mix(0.3, 1.45, smoothstep(0.25, 0.75, n * 0.7 + n2 * 0.3));
	tau *= mix(patchy, 1.0, smoothstep(250.0, 600.0, L));
	// never a wall right in front of you: the mist starts a few meters away
	tau *= smoothstep(3.0, 45.0, L);
	float a = (1.0 - exp(-tau)) * amount;
	// towards the low sun the mist lights up warm (forward scattering)
	float sc = pow(max(dot(dir, normalize(to_sun)), 0.0), 5.0);
	vec3 col = mix(mist_color, mist_color * 0.55 + sun_color * 0.75, sc * 0.8);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.88);
}
