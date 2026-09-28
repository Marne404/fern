class_name Footprints
extends Node3D
## Footprints (decals on the terrain only) and small dust/snow puffs of the scout.
## Pooled: 48 prints that fade after half a minute, 6 puff emitters.

const MAX := 48
const LIFE := 30.0
const FADE := 8.0
## Visual layer only the terrain has (see ChunkManager), so prints never land on the scout or plants
const TERRAIN_VIS_LAYER := 1 << 10
const PRINT_COLORS := {
	"path": Color(0.3, 0.22, 0.14, 0.6),
	"sand": Color(0.55, 0.38, 0.2, 0.65),
	"snow": Color(0.5, 0.58, 0.78, 0.75),
	"mud": Color(0.12, 0.08, 0.05, 0.7),
}
const PUFF_COLORS := {
	"path": Color(0.86, 0.76, 0.58, 0.55),
	"sand": Color(0.95, 0.85, 0.65, 0.6),
	"snow": Color(1.0, 1.0, 1.0, 0.85),
	"mud": Color(0.3, 0.2, 0.12, 0.0),
	"grass": Color(0.8, 0.78, 0.6, 0.0),
}

static var _sole: ImageTexture
static var _soft: GradientTexture2D

var _prints: Array[Decal] = []
var _life := PackedFloat32Array()
var _alpha := PackedFloat32Array()
var _next := 0
var _puffs: Array[CPUParticles3D] = []
var _next_puff := 0


func _ready() -> void:
	_life.resize(MAX)
	_alpha.resize(MAX)
	for i in MAX:
		var d := Decal.new()
		d.texture_albedo = _sole_texture()
		d.size = Vector3(0.17, 0.4, 0.3)
		d.cull_mask = TERRAIN_VIS_LAYER
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.visible = false
		add_child(d)
		_prints.append(d)
	for i in 6:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 10
		p.lifetime = 0.9
		p.explosiveness = 0.95
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.12
		p.direction = Vector3(0, 1, 0)
		p.spread = 70.0
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.1
		p.gravity = Vector3(0, -0.6, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.35))
		curve.add_point(Vector2(0.4, 1.0))
		curve.add_point(Vector2(1, 1.3))
		p.scale_amount_curve = curve
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = ramp
		var q := QuadMesh.new()
		q.size = Vector2(0.28, 0.28)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_texture()
		m.disable_receive_shadows = true
		q.material = m
		p.mesh = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_puffs.append(p)


## A print where a foot touched the ground (pos on the ground, yaw of the scout)
func add_print(pos: Vector3, yaw: float, kind: String) -> void:
	if not PRINT_COLORS.has(kind) or not Settings.values.get("footprints", true):
		return
	var d := _prints[_next]
	_life[_next] = LIFE
	_alpha[_next] = (PRINT_COLORS[kind] as Color).a
	_next = (_next + 1) % MAX
	d.global_transform = Transform3D(Basis(Vector3.UP, yaw + randf_range(-0.12, 0.12)), pos + Vector3(0, 0.05, 0))
	d.modulate = PRINT_COLORS[kind]
	d.visible = true


## Small cloud of dust or snow, strength 0..1
func puff(pos: Vector3, kind: String, strength: float) -> void:
	if not Settings.values.get("footprints", true) or not Settings.values.get("particles", true):
		return
	var col: Color = PUFF_COLORS.get(kind, PUFF_COLORS["grass"])
	if col.a <= 0.0:
		return
	var p := _puffs[_next_puff]
	_next_puff = (_next_puff + 1) % _puffs.size()
	p.global_position = pos + Vector3(0, 0.08, 0)
	p.amount = clampi(roundi(4 + strength * 12.0), 3, 16)
	p.initial_velocity_max = 0.6 + strength * 1.4
	p.color = col
	p.restart()


func shift(s: Vector3) -> void:
	position -= s


func _process(delta: float) -> void:
	for i in MAX:
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		var d := _prints[i]
		if _life[i] <= 0.0:
			d.visible = false
		elif _life[i] < FADE:
			d.modulate.a = _alpha[i] * _life[i] / FADE


## Boot sole: heel and forefoot with lugs (white, alpha = shape; the decal modulate gives the color)
static func _sole_texture() -> ImageTexture:
	if _sole:
		return _sole
	var w := 48
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h
			# forefoot (top, wider) and heel (bottom), joined by a narrow arch
			var fore := Vector2(u / 0.92, (v - 0.3) / 0.28).length()
			var heel := Vector2(u / 0.72, (v - 0.8) / 0.18).length()
			var arch := absf(u + 0.12) < 0.45 and v > 0.4 and v < 0.75
			var inside := fore < 1.0 or heel < 1.0 or arch
			if not inside:
				continue
			var edge := minf(1.0 - minf(fore, heel), 0.2) / 0.2 if not arch else 1.0
			var lug := 0.75 + 0.25 * signf(sin(v * 60.0 + (0.8 if u > 0.0 else 0.0)))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(edge, 0.3, 1.0) * lug * (0.6 if arch and fore >= 1.0 and heel >= 1.0 else 1.0)))
	_sole = ImageTexture.create_from_image(img)
	return _sole


static func _soft_texture() -> GradientTexture2D:
	if _soft:
		return _soft
	_soft = GradientTexture2D.new()
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.55))
	_soft.gradient = g
	_soft.width = 64
	_soft.height = 64
	return _soft
