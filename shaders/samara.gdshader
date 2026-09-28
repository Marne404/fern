// Winged maple seed: a round nut with one veined wing, spinning fast around the vertical like a propeller
// while it sinks (the particles move it, this shader turns it).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

varying vec3 v_color;

void vertex() {
	float ph = float(INSTANCE_ID) * 2.399;
	// the wing lies nearly flat and rotates about the nut (at the quad's lower end)
	vec3 v = VERTEX + vec3(0.0, 0.5, 0.0);
	float tilt = 1.25;
	v = vec3(v.x, v.y * cos(tilt), v.y * sin(tilt));
	float a = TIME * (11.0 + fract(ph) * 5.0) + ph;
	float c = cos(a), s = sin(a);
	VERTEX = vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
	NORMAL = normalize(vec3(-s * 0.3, 0.95, c * 0.3));
	v_color = COLOR.rgb;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// nut at the bottom, the wing widening upwards with a curved front edge
	float nut = step(length((p - vec2(0.1, 0.72)) * vec2(1.6, 1.6)), 0.34);
	float t = clamp((0.6 - p.y) / 1.5, 0.0, 1.0);
	float wing = step(abs(p.x - 0.15 * t + 0.1), 0.18 + 0.3 * sin(t * 3.0)) * step(-0.95, p.y) * step(p.y, 0.72);
	float a = max(nut, wing);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float vein = smoothstep(0.06, 0.0, abs(fract(p.x * 3.0 + p.y * 1.2) - 0.5));
	ALBEDO = mix(v_color * (1.0 - vein * 0.25), v_color * 0.55, nut);
	BACKLIGHT = v_color * 0.9;
	ROUGHNESS = 1.0;
}
