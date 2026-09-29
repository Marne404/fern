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
	// forewing: a rounded triangle sweeping forward; hindwing: a scalloped lobe behind it
	vec2 fp = (p - vec2(0.48, -0.38)) * vec2(1.0, 1.3);
	float fore = length(fp) - 0.08 * sin(atan(fp.y, fp.x) * 3.0);
	vec2 hp = (p - vec2(0.36, 0.42)) * vec2(1.3, 1.35);
	float scallop = 0.03 * sin(atan(hp.y, hp.x) * 7.0);
	float hind = length(hp) + scallop;
	float wing = min(fore, hind);
	ALPHA = step(wing, 0.5);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// color: deep at the base, bright in the middle, a dark rim with pale dots, faint veins
	vec3 base = wing_color * 0.55;
	vec3 col = mix(base, wing_color * 1.08, smoothstep(0.05, 0.4, UV.x));
	float vein = smoothstep(0.035, 0.0, abs(fract(atan(p.y + 0.1, p.x) * 2.2) - 0.5)) * smoothstep(0.15, 0.4, UV.x) * 0.25;
	col *= 1.0 - vein;
	float rim = smoothstep(0.38, 0.46, wing);
	col = mix(col, vec3(0.08, 0.06, 0.05), rim);
	float dots = 0.0;
	for (int i = 0; i < 5; i++) {
		float a = -1.25 + float(i) * 0.3;
		dots += step(length(p - vec2(0.48, -0.38) - vec2(cos(a), sin(a)) * 0.42 / vec2(1.0, 1.3)), 0.035);
	}
	col = mix(col, vec3(1.0, 0.98, 0.9), clamp(dots, 0.0, 1.0) * rim);
	// an eye spot on the hindwing
	float eye_d = length(p - vec2(0.42, 0.55));
	col = mix(col, vec3(0.1, 0.12, 0.25), step(eye_d, 0.075));
	col = mix(col, vec3(0.95, 0.9, 0.6), step(eye_d, 0.04));
	ALBEDO = col;
	BACKLIGHT = col * 0.6;
	ROUGHNESS = 1.0;
}
