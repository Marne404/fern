class_name CanopyShafts
extends Node3D
## Sunbeams falling through the tree crowns around you (forest biomes). Every tree has its own fixed chance
## and offset for a beam, so beams stay put while you walk and fade in and out with distance.

const MAX := 48
const RANGE := 42.0

var world: ChunkManager
var _mm: MultiMesh
var _mat: ShaderMaterial
var _timer := 0.0
var _beams := {}          # tree key → [strength now, target, transform]


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/canopy_shaft.gdshader")
	_mat.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mmi)
	top_level = true


## amount: how strong the beams are now (biome × time of day × clouds); to_sun: direction towards the sun
func update(amount: float, to_sun: Vector3, light: Color, cam_pos: Vector3, delta: float) -> void:
	var on: bool = amount > 0.01 and world != null and Settings.values.get("sun_shafts", true)
	_mat.set_shader_parameter("strength", amount)
	_mat.set_shader_parameter("light_color", light)
	_mat.set_shader_parameter("to_sun", to_sun.normalized())
	if not on:
		_mm.visible_instance_count = 0
		_beams.clear()
		return
	# light falls at least this steeply (flat evening light would make endless beams)
	var d := -to_sun.normalized()
	if d.y > -0.6:
		d = (Vector3(d.x, 0.0, d.z).normalized() * 0.8 + Vector3(0, -0.6, 0)).normalized()
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_choose(cam_pos, d)
	# fade every beam towards its target
	var i := 0
	for key in _beams.keys():
		var b: Array = _beams[key]
		b[0] = move_toward(b[0], b[1], delta * 0.5)
		if b[0] <= 0.0 and b[1] <= 0.0:
			_beams.erase(key)
			continue
		if i < MAX:
			_mm.set_instance_transform(i, b[2])
			_mm.set_instance_custom_data(i, Color(b[0], b[3], 0, 0))
			i += 1
	_mm.visible_instance_count = i


func _choose(cam_pos: Vector3, d: Vector3) -> void:
	for key in _beams:
		_beams[key][1] = 0.0
	var trees := world.canopy_near(cam_pos, RANGE)
	var picked := 0
	for t in trees:
		var c: Vector3 = t[0]
		var r: float = t[1]
		var h := hash(Vector2i(roundi(c.x * 4.0 + world.origin.x * 4.0), roundi(c.z * 4.0 + world.origin.y * 4.0)))
		# about every second tree lets a beam through
		if h % 2 != 0:
			continue
		var dist := Vector2(c.x - cam_pos.x, c.z - cam_pos.z).length()
		var target := 1.0 - smoothstep(RANGE * 0.7, RANGE, dist)
		if target <= 0.0:
			continue
		var a := float(h % 628) / 100.0
		# the beam starts high up in the crown and falls through it
		var top: float = t[2]
		var start := Vector3(c.x, lerpf(c.y, top, 0.6), c.z) + Vector3(cos(a), 0.0, sin(a)) * r * 0.35
		var ground := world.ground_y(start.x + d.x * 4.0, start.z + d.z * 4.0)
		var length := clampf((start.y - ground) / maxf(-d.y, 0.2), 3.0, 28.0) * 1.05
		# a gap in the leaves: a beam of about a meter
		var width := lerpf(0.4, 1.1, float(h % 97) / 97.0)
		var right := d.cross(Vector3.UP).normalized()
		var xf := Transform3D(Basis(right * width, d * length, right.cross(d).normalized()), start)
		if _beams.has(h):
			_beams[h][1] = target
			_beams[h][2] = xf
		else:
			_beams[h] = [0.0, target, xf, float(h % 1000) / 1000.0]
		picked += 1
		if picked >= MAX:
			break


func shift(offset: Vector3) -> void:
	for key in _beams:
		var xf: Transform3D = _beams[key][2]
		xf.origin -= offset
		_beams[key][2] = xf
