// Falling leaves: procedural leaf shape, tumbling rotation.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

varying vec3 v_color;

mat3 rot(vec3 axis, float a) {
	axis = normalize(axis);
	float s = sin(a), c = cos(a), oc = 1.0 - c;
	return mat3(
		vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y + axis.z * s, oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s, oc * axis.y * axis.z - axis.x * s, oc * axis.z * axis.z + c));
}

void vertex() {
	float ph = float(INSTANCE_ID) * 1.618;
	mat3 r = rot(vec3(sin(ph), 0.6, cos(ph * 1.3)), TIME * (1.5 + fract(ph) * 2.0) + ph);
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	v_color = COLOR.rgb;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// pointed oval leaf shape with a midrib
	float w = 1.0 - p.y * p.y;
	float leaf = step(abs(p.x), w * 0.55 * (0.8 + 0.2 * (1.0 - p.y)));
	ALPHA = leaf;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = v_color * (0.85 + 0.15 * (1.0 - smoothstep(0.0, 0.05, abs(p.x))));
	BACKLIGHT = v_color * 0.8;
	ROUGHNESS = 1.0;
}
