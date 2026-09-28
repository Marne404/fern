// Gossamer threads drifting in the air: a hair-thin line along the particle's Y axis, turned towards the
// camera around that axis. Almost invisible, but they glint silver and faintly iridescent against the sun.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;

global uniform vec3 sun_vector;
global uniform vec4 sun_light;
uniform float strength = 1.0;

varying float v_width_gain;
varying vec3 v_view;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = length(axis);
	axis /= max(len, 1e-4);
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	float dist = length(to_cam);
	vec3 side = normalize(cross(axis, to_cam / max(dist, 1e-4)));
	// at least ~1 pixel wide; the brightness is spread out accordingly so far threads don't flicker
	float w = max(0.004, dist * 0.0011);
	v_width_gain = 0.004 / w;
	// a gentle sag: the middle hangs a little lower
	float yy = VERTEX.y * 2.0;
	float sag = (1.0 - yy * yy) * 0.05 * len;
	vec3 wp = center + axis * VERTEX.y * len * 1.3 + side * VERTEX.x * w * 2.0 - vec3(0.0, sag, 0.0);
	v_view = normalize(wp - CAMERA_POSITION_WORLD);
	// the vertex is already in world space
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = wp;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	// forward scattering: bright only when the sun is behind the thread
	float glint = pow(max(dot(v_view, normalize(sun_vector)), 0.0), 4.0);
	float lit = 0.1 + glint * 4.0;
	// a soft rainbow sheen running along the thread
	float h = fract(UV.y * 1.4 + TIME * 0.03 + COLOR.r * 3.0);
	vec3 sheen = 0.75 + 0.25 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
	vec3 c = sun_light.rgb * mix(vec3(1.0), sheen, 0.5) * lit;
	ALBEDO = c * across * along * v_width_gain * strength * COLOR.a;
}
