class_name MenuCamera
extends Camera3D
## Slow camera flight along the main path as the main menu background.

var world: ChunkManager
var start_z := 30.0
var z_world := 30.0
var speed := 2.2
var _time := 0.0
var _target := Vector3.ZERO
const LOOP_LENGTH := 450.0


func start() -> void:
	z_world = start_z
	_time = 0.0
	_place(true, 0.0)


func _process(delta: float) -> void:
	if world == null or not current:
		return
	_time += delta
	z_world -= speed * delta
	if z_world < start_z - LOOP_LENGTH:
		z_world = start_z
		_place(true, delta)
		return
	_place(false, delta)


## Target is in world coordinates – nothing to do, the position is set anew every frame.
func shift_target(_shift: Vector3) -> void:
	pass


func world_position() -> Vector3:
	return world.local_to_world(global_position)


func _place(snap: bool, delta: float) -> void:
	var gen := world.gen
	var sway := sin(_time * 0.11) * 1.3
	var px := gen.path_x(z_world) + sway
	var pos := Vector3(px, gen.height(px, z_world) + 1.9 + sin(_time * 0.07) * 0.3, z_world)
	var az := z_world - 14.0
	var ax := gen.path_x(az) + sin(_time * 0.05 + 1.0) * 5.0
	var tgt := Vector3(ax, gen.height(ax, az) + 2.4, az)
	if snap:
		_target = tgt
	else:
		_target = _target.lerp(tgt, 1.0 - exp(-delta * 1.5))
	global_position = world.world_to_local(pos)
	look_at(world.world_to_local(_target), Vector3.UP)
