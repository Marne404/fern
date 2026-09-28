// Butterfly: two wings flapping around the body axis.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

instance uniform vec3 wing_color : source_color = vec3(1.0, 0.55, 0.1);
instance uniform float phase = 0.0;
instance uniform float flap_speed = 16.0;
instance uniform float rest = 0.0;       // 1 = sitting on a flower: wings up, slowly opening and closing

varying float v_side;

void vertex() {
	float side = sign(VERTEX.x);
	float flap = (sin(TIME * flap_speed + phase) * 0.5 + 0.5) * 1.25 - 0.15;
	float sit = 1.35 - (sin(TIME * 1.3 + phase) * 0.5 + 0.5) * 0.9;
	flap = mix(flap, sit, rest);
	float a = flap * side;
	float c = cos(a), s = sin(a);
	VERTEX = vec3(VERTEX.x * c, abs(VERTEX.x) * s, VERTEX.z);
	NORMAL = vec3(-s * side, c, 0.0);
	v_side = side;
}

void fragment() {
	// UV.x: 0 = body, 1 = wing tip; UV.y: front (0) to back (1)
	vec2 p = vec2(UV.x, UV.y * 2.0 - 1.0);
	float fore = length((p - vec2(0.5, -0.35)) * vec2(1.0, 1.25));
	float hind = length((p - vec2(0.38, 0.45)) * vec2(1.25, 1.4));
	float wing = min(fore, hind);
	float body = step(UV.x, 0.06) * step(abs(p.y), 0.6);
	ALPHA = max(step(wing, 0.5), body);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 col = wing_color;
	float rim = smoothstep(0.36, 0.46, wing);
	col = mix(col, vec3(0.08, 0.06, 0.05), rim);
	float spot = step(length(p - vec2(0.72, -0.45)), 0.07) + step(length(p - vec2(0.58, -0.62)), 0.05);
	col = mix(col, vec3(1.0), clamp(spot, 0.0, 1.0) * rim);
	col = mix(col, vec3(0.1, 0.08, 0.06), body);
	ALBEDO = col;
	BACKLIGHT = col * 0.6;
	ROUGHNESS = 1.0;
}
