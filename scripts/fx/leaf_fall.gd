class_name LeafFall
extends Node3D
## Leaves and blossoms fall from the crowns of colorful trees nearby (autumn trees, maples, blossom trees)
## and are carried by the wind; gusts sweep whole swarms away.

const RADIUS := 40.0
const POINTS_PER_CROWN := 6
const MAX_CROWNS := 60

var world: ChunkManager
var gusts: WindGusts
var particles: GPUParticles3D
var _pm: ParticleProcessMaterial
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	particles = GPUParticles3D.new()
	particles.local_coords = false
	particles.amount = 700
	particles.lifetime = 9.0
	# particles live in world coordinates, the node stays at the origin: the box must cover the whole area
	particles.visibility_aabb = AABB(Vector3(-2500, -600, -2500), Vector3(5000, 1600, 5000))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	_pm.direction = Vector3(0, -1, 0)
	_pm.spread = 70.0
	_pm.initial_velocity_min = 0.1
	_pm.initial_velocity_max = 0.4
	_pm.gravity = Vector3(0, -0.3, 0)
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_scale = 4.0
	_pm.turbulence_noise_strength = 1.6
	_pm.turbulence_influence_min = 0.06
	_pm.turbulence_influence_max = 0.16
	_pm.scale_min = 0.18
	_pm.scale_max = 0.3
	# shrink and vanish shortly before the ground (lifetime matches the crowns' fall height)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.08, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curve
	_pm.scale_curve = ct
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/leaf_particle.gdshader")
	var quad := QuadMesh.new()
	quad.material = mat
	particles.process_material = _pm
	particles.draw_pass_1 = quad
	add_child(particles)


func update(cam: Camera3D, delta: float) -> void:
	var on: bool = Settings.values["particles"]
	visible = on
	if not on:
		particles.emitting = false
		return
	# wind drives the leaves; during gusts they fly far
	var wd := WindGusts.direction()
	var g := gusts.gust if gusts else 0.0
	_pm.gravity = wd * (0.25 + g * 1.6) + Vector3(0, -0.2 + g * 0.08, 0)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.6
	var crowns := world.crowns_near(cam.global_position, RADIUS)
	if crowns.is_empty():
		particles.emitting = false
		return
	var cp := cam.global_position
	crowns.sort_custom(func(a, b): return (a[0] as Vector3).distance_squared_to(cp) < (b[0] as Vector3).distance_squared_to(cp))
	var n := mini(crowns.size(), MAX_CROWNS)
	var count := n * POINTS_PER_CROWN
	var pts := Image.create(count, 1, false, Image.FORMAT_RGBF)
	var cols := Image.create(count, 1, false, Image.FORMAT_RGBA8)
	for i in n:
		var c: Array = crowns[i]
		var center: Vector3 = c[0]
		var r: float = c[1]
		var col: Color = c[2]
		for k in POINTS_PER_CROWN:
			# points at the edge of the crown: leaves detach there and are visible right away (not hidden in the foliage)
			var ang := _rng.randf() * TAU
			var rr := r * _rng.randf_range(0.95, 1.3)
			var p := center + Vector3(cos(ang) * rr, -r * _rng.randf_range(0.1, 0.8), sin(ang) * rr)
			pts.set_pixel(i * POINTS_PER_CROWN + k, 0, Color(p.x, p.y, p.z))
			cols.set_pixel(i * POINTS_PER_CROWN + k, 0, col.lightened(_rng.randf_range(-0.1, 0.12)))
	_pm.emission_point_texture = ImageTexture.create_from_image(pts)
	_pm.emission_color_texture = ImageTexture.create_from_image(cols)
	_pm.emission_point_count = count
	# few trees = few leaves
	var ratio := clampf(float(n) / 14.0, 0.15, 1.0)
	if absf(ratio - particles.amount_ratio) > 0.1:
		particles.amount_ratio = ratio
	if not particles.emitting:
		particles.emitting = true


func restart() -> void:
	particles.restart()
	_timer = 0.0
