// Bird silhouette with wing beats and short gliding phases.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

instance uniform float phase = 0.0;
uniform vec3 color : source_color = vec3(0.16, 0.17, 0.2);

void vertex() {
	float glide = smoothstep(0.3, 0.8, sin(TIME * 0.7 + phase * 3.0));
	float flap = mix(sin(TIME * 9.0 + phase) * 0.7, 0.12, glide);
	float side = sign(VERTEX.x);
	float a = flap * side * abs(VERTEX.x);
	VERTEX.y += a * 0.9;
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
