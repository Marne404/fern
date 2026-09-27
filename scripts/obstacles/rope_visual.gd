class_name RopeVisual
extends MeshInstance3D
## Rope as a thin tube along a sagging curve between two points (local coordinates of the parent node).

const SIDES := 6
const SEGMENTS := 24

var radius := 0.025
var _im := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	mesh = _im
	_mat.albedo_color = Color(0.86, 0.72, 0.45)
	_mat.roughness = 0.9
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	extra_cull_margin = 30.0


## sag = sag in meters at the middle
func set_points(a: Vector3, b: Vector3, sag := 0.4) -> void:
	_im.clear_surfaces()
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := (p1 - p0).normalized()
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		var s := dir.cross(up).normalized()
		var u := s.cross(dir).normalized()
		for k in SIDES:
			var a0 := k * TAU / SIDES
			var a1 := (k + 1) * TAU / SIDES
			var n0 := s * cos(a0) + u * sin(a0)
			var n1 := s * cos(a1) + u * sin(a1)
			for v in [[p0, n0], [p1, n0], [p1, n1], [p0, n0], [p1, n1], [p0, n1]]:
				_im.surface_set_normal(v[1])
				_im.surface_add_vertex(v[0] + v[1] * radius)
	_im.surface_end()


## Point on the rope at t (same curve as set_points)
static func point_at(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	var p := a.lerp(b, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p
