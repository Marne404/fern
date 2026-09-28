// Mud hollow: glossy dark mud with shiny puddles and a soft, irregular edge (COLOR.a = mud amount).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

global uniform vec2 world_origin;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 mud_color : source_color = vec3(0.36, 0.25, 0.15);
uniform vec3 wet_color : source_color = vec3(0.25, 0.17, 0.1);

varying vec3 v_world;
varying float v_mud;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + vec3(world_origin.x, 0.0, world_origin.y);
	v_mud = COLOR.a;
}

void fragment() {
	vec2 p = v_world.xz;
	float n1 = texture(noise_tex, p * 0.09).r;
	float n2 = texture(noise_tex, p * 0.37 + 0.3).r;
	float n3 = texture(noise_tex, p * 1.3 + 0.7).r;
	// puddles where the mud is deep, lumps and boot marks elsewhere
	float puddle = smoothstep(0.63, 0.68, n1 + (v_mud - 0.8) * 0.4);
	vec3 col = mix(mud_color, wet_color, smoothstep(0.3, 0.8, n2)) * (0.85 + 0.3 * n3);
	col = mix(col, vec3(0.18, 0.14, 0.1), puddle * 0.6);
	ALBEDO = col;
	ROUGHNESS = mix(0.72, 0.08, puddle);
	SPECULAR = mix(0.2, 0.6, puddle);
	vec3 nm = normalize(vec3((n2 - n3) * 0.8, 1.0, (n3 - n1) * 0.8));
	NORMAL_MAP = mix(vec3(nm.x * 0.5 + 0.5, nm.z * 0.5 + 0.5, 1.0), vec3(0.5, 0.5, 1.0), puddle * 0.9);
	NORMAL_MAP_DEPTH = 0.6;
	ALPHA = smoothstep(0.05, 0.45, v_mud + (n3 - 0.5) * 0.25);
}
