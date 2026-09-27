class_name Kite
extends Node3D
## A kite flying downwind behind its owner for a while, dancing in the gusts, on a string to the hand.

var owner_body: Node3D
var life := 22.0
var _t := 0.0
var _mesh: MeshInstance3D
var _line: MeshInstance3D
var _im := ImmediateMesh.new()
var _pos := Vector3.ZERO


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ItemModels.mesh("drachen")
	_mesh.scale = Vector3.ONE * 2.2
	add_child(_mesh)
	_line = MeshInstance3D.new()
	_line.mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.93, 0.88)
	_line.material_override = m
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	top_level = true
	if owner_body:
		_pos = owner_body.global_position + Vector3(0, 1.5, 0)


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body):
		queue_free()
		return
	_t += delta
	life -= delta
	var down := WindGusts.direction()
	var ws := WindGusts.current_strength
	var hand := owner_body.global_position + Vector3(0, 1.1, 0)
	# climbs at the start, sinks when time runs out, dances with the gusts
	var height := lerpf(1.5, 7.5 + ws * 1.5, minf(_t / 3.0, 1.0)) * clampf(life / 3.0, 0.0, 1.0)
	var dist := 7.0 + ws * 2.0
	var target := hand + down * dist + Vector3(sin(_t * 1.3) * 1.2, height + sin(_t * 2.1) * 0.6, cos(_t * 0.9) * 0.8)
	_pos = _pos.lerp(target, 1.0 - exp(-2.5 * delta))
	_mesh.global_position = _pos
	_mesh.look_at(hand, Vector3.UP)
	_mesh.rotate_object_local(Vector3.RIGHT, -PI * 0.5 + 0.4)
	_mesh.rotate_object_local(Vector3.UP, sin(_t * 3.0) * 0.25)
	# the string sags a little
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var f := i / 12.0
		var p := hand.lerp(_pos, f) - Vector3(0, sin(f * PI) * 0.8, 0)
		_im.surface_add_vertex(p)
	_im.surface_end()
	if life <= 0.0:
		queue_free()
