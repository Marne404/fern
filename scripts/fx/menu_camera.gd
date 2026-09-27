class_name MenuCamera
extends Camera3D
## Slow camera flight along the main path as the main menu background.
## Your scout hikes a few meters ahead; in the scout editor ("portrait") it turns around,
## the flight stops and the camera moves in close.

var world: ChunkManager
var start_z := 30.0
var z_world := 30.0
var speed := 2.2
var _time := 0.0
var _target := Vector3.ZERO
const LOOP_LENGTH := 450.0

## Scout walking ahead of the camera
var scout: Scout
const SCOUT_AHEAD := 5.5
## Scout editor open: camera in front of the scout
var portrait := false
## Extra turn of the scout by dragging with the mouse
var drag_yaw := 0.0
var _blend := 0.0
var _scout_yaw := 0.0


func start() -> void:
	z_world = start_z
	_time = 0.0
	_place(true, 0.0)


func _process(delta: float) -> void:
	if world == null or not current:
		if scout:
			scout.visible = false
		return
	_time += delta
	if not portrait:
		z_world -= speed * delta
	_blend = move_toward(_blend, 1.0 if portrait else 0.0, delta * 0.9)
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
	var flight := Transform3D(Basis(), world.world_to_local(pos)).looking_at(world.world_to_local(_target), Vector3.UP)
	if scout == null:
		global_transform = flight
		return
	# scout on the trail ahead, facing along the path (or back towards the camera in the editor)
	var sz := z_world - SCOUT_AHEAD
	var sx := gen.path_x(sz)
	var sp := world.world_to_local(Vector3(sx, gen.height(sx, sz), sz))
	var d := gen.path_point(sz - 1.0) - gen.path_point(sz + 1.0)
	var walk_yaw := atan2(-d.x, -d.z)
	var face_yaw := walk_yaw + PI
	var want := face_yaw + drag_yaw if portrait else walk_yaw
	_scout_yaw = want if snap else lerp_angle(_scout_yaw, want, 1.0 - exp(-5.0 * delta))
	scout.visible = true
	scout.global_position = sp
	scout.rotation = Vector3(0, _scout_yaw, 0)
	scout.speed = 0.0 if portrait else speed
	scout.look_target = global_position if _blend > 0.3 else Vector3.INF
	if _blend <= 0.0:
		global_transform = flight
		return
	# portrait: in front of the scout, scout on the left third (the editor panel is on the right)
	var front := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var cam_pos := sp + front * 2.6 + Vector3(0, 1.25, 0)
	var right := (-front).cross(Vector3.UP).normalized()
	var portrait_xf := Transform3D(Basis(), cam_pos).looking_at(sp + Vector3(0, 0.82, 0) + right * 0.62, Vector3.UP)
	var b := smoothstep(0.0, 1.0, _blend)
	global_transform = Transform3D(flight.basis.slerp(portrait_xf.basis, b), flight.origin.lerp(portrait_xf.origin, b))
