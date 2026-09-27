class_name WindGusts
extends Node
## Gusts: at irregular intervals the wind picks up for a few seconds.
## Grass, trees, leaves, sand and tumbleweeds all react to the same gust (global shader value wind_strength).

var gust := 0.0          # current gust strength 0..1
var strength := 0.5      # how gusty the biome is (desert and autumn stronger)
var force := -1.0        # test helper: fixed gust strength
var _next := 6.0
var _age := -1.0
var _dur := 6.0
var _peak := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Wind direction in world xz as a Vector3 (y = 0)
static func direction() -> Vector3:
	var w: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	return Vector3(w.x, 0.0, w.y).normalized()


func _process(delta: float) -> void:
	_next -= delta
	if _age < 0.0 and _next <= 0.0:
		_age = 0.0
		_dur = _rng.randf_range(5.0, 9.0)
		_peak = _rng.randf_range(0.55, 1.0)
	var target := 0.0
	if _age >= 0.0:
		_age += delta
		var x := _age / _dur
		# pick up quickly, die down slowly, with small bursts in between
		target = smoothstep(0.0, 0.2, x) * (1.0 - smoothstep(0.45, 1.0, x)) * _peak
		target *= 0.85 + 0.15 * sin(_age * 5.3) * sin(_age * 2.1)
		if x >= 1.0:
			_age = -1.0
			_next = _rng.randf_range(10.0, 26.0) / (0.6 + strength * 0.8)
	if force >= 0.0:
		target = force
	gust = lerpf(gust, target, 1.0 - exp(-4.0 * delta))
	RenderingServer.global_shader_parameter_set("wind_strength", 1.0 + gust * (0.6 + 1.0 * strength))
