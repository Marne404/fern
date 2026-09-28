class_name Wanderer
extends CharacterBody3D
## First-person player character: walking, body state, backpack, interaction, water, resting.

signal state_changed(state: int)
signal collapsed
signal recovered
signal message(text: String)
signal sleep_fade(on: bool)

const WALK_SPEED := 3.4
const SPRINT_SPEED := 6.2
const SWIM_SPEED := 1.8
const JUMP_VELOCITY := 4.6
const GRAVITY := 13.0
const EYE_HEIGHT := 1.62
const REACH := 2.6

var body := Body.new()
var inventory := Inventory.new()
var world: ChunkManager
var air_temp := 18.0
var head: Node3D
var camera: Camera3D
var input_enabled := true
## Test helper: provides a walking direction (local) when set
var autopilot: Callable
## Callback for spawning an item in the world: func(item, pos, velocity)
var spawn_item: Callable

var obstacles: ObstacleManager
## [k, root, anchor_local] while carrying a rope end
var carried_rope: Array = []
var crouching := false
## Debug: 0 normal, 1 flying (with collision), 2 noclip
var fly_mode := 0
## Test helper: force crouching (autopilot)
var force_crouch := false
var climbing := false
## Rope mode: {"a","b","sag","t","mode","k"}
var rope: Dictionary = {}
var _on_log: RigidBody3D = null
var _wall_push := 0.0
var _shape: CapsuleShape3D
var _cs: CollisionShape3D
var resting := false
var sleeping := false
var swimming := false
var in_water := false
var prompt := ""
## Structured prompt for the HUD: object name (may be empty), key, action
var prompt_title := ""
var prompt_action := ""
var _look_target: Object = null
var _water_target := false

var _yaw := 0.0
var _pitch := 0.0
var _bob := 0.0
var _collapse_timer := 0.0
var _rest_timer := 0.0
var _sleep_timer := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _last_state := Body.State.FIT
var _zoom := false

## The visible hiker. First person: only its shadow; third person (V): fully visible behind the camera arm.
var scout: Scout
var third_person := false
var _arm: SpringArm3D
var _cam_dist := 3.4
var _facing := 0.0
var _sprinting := false
## Emotes: lying down (rest pose), emote camera in first person, time since the emote started
var _lie := false
var _emote_cam := false
var _emote_age := 0.0


func _ready() -> void:
	# steeper than 40° is no longer ground: you slide off (rock steps, gorge walls)
	floor_max_angle = deg_to_rad(40.0)
	# don't simply walk up onto logs: steps above ~35 cm require a jump
	floor_block_on_wall = true
	floor_snap_length = 0.5
	collision_mask = 1
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.32
	_shape.height = 1.8
	_cs = CollisionShape3D.new()
	_cs.shape = _shape
	_cs.position.y = 0.9
	add_child(_cs)
	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.06
	camera.far = 4000.0
	camera.fov = Settings.values["fov"]
	head.add_child(camera)
	_arm = SpringArm3D.new()
	_arm.position = Vector3(0, 0.12, 0)
	_arm.spring_length = _cam_dist
	_arm.collision_mask = 1
	_arm.margin = 0.15
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_arm.shape = probe
	_arm.add_excluded_object(get_rid())
	head.add_child(_arm)
	scout = Scout.new(Settings.values.get("scout", {}))
	add_child(scout)
	set_third_person(Settings.values.get("third_person", false))
	# starting gear
	inventory.add(ItemDefs.make("wasserflasche"))
	inventory.add(ItemDefs.make("apfel"))
	inventory.add(ItemDefs.make("muesliriegel"))


func look_along(dir: Vector3) -> void:
	_yaw = atan2(-dir.x, -dir.z)
	_pitch = 0.0
	_facing = _yaw
	_apply_look()


func set_third_person(on: bool) -> void:
	third_person = on
	camera.reparent(_arm if on else head, false)
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	scout.set_shadow_only(not on)


## Plays an emote from the wheel. Sit and lie down are the normal rest (R) in a pose.
func play_emote(id: String) -> void:
	if not can_act() or swimming or climbing or not rope.is_empty() or not is_on_floor():
		return
	if id == "sit" or id == "lie":
		if not resting:
			_toggle_rest()
		_lie = id == "lie"
		return
	if resting:
		_toggle_rest()
	scout.play_emote(id)
	_emote_age = 0.0
	# first person: step back so you can see yourself
	if not third_person and Settings.values.get("emote_camera", true):
		_emote_cam = true
		set_third_person(true)


## Start of the view ray for interaction: in third person the point on the view ray level with the head
func view_origin() -> Vector3:
	if not third_person:
		return camera.global_position
	var dir := -camera.global_basis.z
	return camera.global_position + dir * dir.dot(head.global_position - camera.global_position)


func _process(delta: float) -> void:
	# the lamp was dropped or thrown: its light goes with it
	if _light and not _has_item(_light_item):
		_light.queue_free()
		_light = null
		_light_item = ""
	if scout == null:
		return
	var hv := Vector2(velocity.x, velocity.z)
	var spd := hv.length() if fly_mode == 0 else 0.0
	# moving cancels an emote (after a short grace so a tap doesn't kill it instantly)
	_emote_age += delta
	if scout.emote_playing() != "" and spd > 0.8 and _emote_age > 0.3:
		scout.stop_emote()
	if _emote_cam and scout.emote_playing() == "":
		_emote_cam = false
		set_third_person(false)
	if not resting:
		_lie = false
	var prev := _facing
	if not third_person or not rope.is_empty() or climbing:
		_facing = _yaw
	elif spd > 0.4 and not resting:
		_facing = lerp_angle(_facing, atan2(-hv.x, -hv.y), 1.0 - exp(-9.0 * delta))
	scout.turn_rate = lerpf(scout.turn_rate, clampf(angle_difference(prev, _facing) / maxf(delta, 0.001), -4.0, 4.0), 1.0 - exp(-6.0 * delta))
	scout.rotation.y = angle_difference(_yaw, _facing)
	scout.speed = spd
	scout.sprint = _sprinting
	scout.on_floor = is_on_floor() or swimming or climbing or fly_mode != 0 or not rope.is_empty()
	scout.talk = Voice.mouth if Settings.values.get("voice_lipsync", true) else 0.0
	scout.vy = velocity.y
	scout.load = clampf((inventory.total_weight() - 8.0) / 16.0, 0.0, 1.0)
	var collapsed_now := body.state == Body.State.COLLAPSED
	if collapsed_now or sleeping:
		scout.pose = Scout.Pose.LIE
	elif resting:
		scout.pose = Scout.Pose.LIE if _lie else Scout.Pose.SIT
	elif swimming:
		scout.pose = Scout.Pose.SWIM
	elif climbing or not rope.is_empty():
		scout.pose = Scout.Pose.CLIMB
	elif crouching:
		scout.pose = Scout.Pose.CROUCH
	else:
		scout.pose = Scout.Pose.STAND
	if collapsed_now:
		scout.mood = Scout.Mood.KNOCKED_OUT
	elif sleeping or (resting and _lie):
		scout.mood = Scout.Mood.ASLEEP
	elif climbing or not rope.is_empty():
		scout.mood = Scout.Mood.EFFORT
	elif not is_on_floor() and not swimming and velocity.y < -7.0:
		scout.mood = Scout.Mood.SCARED
	elif body.state >= Body.State.TIRED:
		scout.mood = Scout.Mood.TIRED
	elif body.feel_temp < 8.0:
		scout.mood = Scout.Mood.COLD
	else:
		scout.mood = Scout.Mood.NORMAL


func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_apply_look()


func _apply_look() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	head.rotation = Vector3(_pitch, 0.0, 0.0)


func can_act() -> bool:
	return input_enabled and body.state != Body.State.COLLAPSED and not sleeping and not climbing


func _unhandled_input(event: InputEvent) -> void:
	# debug flight always works
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6:
			_set_fly(0 if fly_mode == 1 else 1)
			return
		if event.physical_keycode == KEY_F7:
			_set_fly(0 if fly_mode == 2 else 2)
			return
	if not can_act() and fly_mode == 0:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0022 * Settings.values["mouse_sens"] * (0.35 if _zoom else 1.0)
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.45, 1.45)
		_apply_look()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				interact()
			KEY_R:
				_toggle_rest()
			KEY_V:
				set_third_person(not third_person)
				Settings.set_value("third_person", third_person, false)
			KEY_Q:
				if _look_target and _look_target.has_meta("anchor") and obstacles:
					var an: Array = _look_target.get_meta("anchor")
					obstacles.untie_key(an[0], self, _look_target.get_parent())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_zoom = event.pressed and _has_item("fernglas")
	elif event is InputEventMouseButton and event.pressed and third_person and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cam_dist = clampf(_cam_dist * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.6, 7.0)
		_arm.spring_length = _cam_dist


# ================================================================ Movement



func _physics_process(delta: float) -> void:
	if fly_mode != 0:
		_fly(delta)
		return
	if not rope.is_empty():
		_rope_physics(delta)
		body.update(delta, 1, 0.0, inventory.total_weight(), air_temp, inventory.warmth(), false)
		_update_body_events(delta)
		_update_camera(delta, false, false)
		return
	if climbing:
		return
	var on_floor := is_on_floor()
	_update_crouch()
	_update_water()
	if swimming:
		# buoyancy: head stays above water
		var wl := _water_level_here()
		var target := wl - 1.35
		velocity.y = lerpf(velocity.y, (target - global_position.y) * 3.0, 1.0 - exp(-4.0 * delta))
		# swam against a bank: climb out
		for i in get_slide_collision_count():
			var n := get_slide_collision(i).get_normal()
			if n.y > 0.25 and n.y < 0.95 and Vector2(velocity.x, velocity.z).length() > 0.3:
				velocity.y = 3.2
				break
	elif not on_floor:
		velocity.y -= GRAVITY * delta
	elif not _was_on_floor and velocity.y < -3.0:
		_land_dip = clampf(-velocity.y * 0.012, 0.0, 0.12)
	if on_floor and not _was_on_floor and _fall_speed > 11.0 and not in_water:
		_fall_damage(_fall_speed)
	_fall_speed = -velocity.y if not on_floor else 0.0
	_was_on_floor = on_floor

	var dir := Vector3.ZERO
	var sprint := false
	if can_act():
		var fwd := -global_basis.z
		var right := global_basis.x
		if Input.is_physical_key_pressed(KEY_W): dir += fwd
		if Input.is_physical_key_pressed(KEY_S): dir -= fwd
		if Input.is_physical_key_pressed(KEY_A): dir -= right
		if Input.is_physical_key_pressed(KEY_D): dir += right
		if autopilot.is_valid():
			dir = autopilot.call()
		dir.y = 0.0
		dir = dir.normalized()
		if dir != Vector3.ZERO and resting:
			resting = false
		sprint = Input.is_physical_key_pressed(KEY_SHIFT) and dir != Vector3.ZERO and body.state < Body.State.WEAK and not swimming
		if Input.is_physical_key_pressed(KEY_SPACE) and on_floor and not swimming and _try_climb():
			return
		if Input.is_physical_key_pressed(KEY_SPACE) and on_floor and body.stamina > 8.0 and not swimming and not crouching:
			var load_f := clampf(1.0 - (inventory.total_weight() - Inventory.COMFORT_WEIGHT) / 30.0, 0.6, 1.0)
			velocity.y = JUMP_VELOCITY * (0.8 if body.state >= Body.State.TIRED else 1.0) * load_f
			body.spend(6.0)
			resting = false

	if crouching:
		sprint = false
	_sprinting = sprint
	var speed := SWIM_SPEED if swimming else (SPRINT_SPEED if sprint else WALK_SPEED)
	if crouching:
		speed = 1.6
	speed *= [1.0, 0.85, 0.65, 0.0][body.state]
	speed *= clampf(1.0 - (inventory.total_weight() - 14.0) / 40.0, 0.55, 1.0)
	if in_water and not swimming:
		speed *= 0.7
	# balancing: slower on a log, gently pulled to the log's center while walking
	if is_instance_valid(_on_log) and on_floor:
		if not sprint:
			speed = minf(speed, 2.0)
			var axis := _on_log.global_basis.z
			var rel := global_position - _on_log.global_position
			var lateral := rel - axis * rel.dot(axis)
			lateral.y = 0.0
			global_position -= lateral * minf(1.0, delta * 5.0)
	var accel := 10.0 if on_floor or swimming else 2.5
	velocity.x = lerpf(velocity.x, dir.x * speed, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, dir.z * speed, 1.0 - exp(-accel * delta))
	_block_low_obstacles()
	_limit_corridor()
	# the river current carries you away
	if in_water and world:
		var w := world.local_to_world(global_position)
		var flow := world.gen.river_flow(w.x, w.z)
		global_position += Vector3(flow.x, 0.0, flow.y) * delta * (1.0 if swimming else 0.45)
	move_and_slide()
	_step_up(dir)
	_push_bodies(dir, delta)
	# in the water against an edge (bank wall, base): pull up after pushing briefly
	if in_water and dir != Vector3.ZERO and is_on_wall() and can_act():
		_wall_push += delta
		if _wall_push > 0.5:
			_wall_push = 0.0
			_try_ledge()
	else:
		_wall_push = 0.0

	# passive item effects: walking stick in the pack, boots worn, harmonica after playing
	body.climb_factor = (0.85 if _has_item("stock") else 1.0) * (0.8 if _wears("stiefel") else 1.0)
	_harmonica_t = maxf(_harmonica_t - delta, 0.0)
	body.rest_bonus = 1.5 if _harmonica_t > 0.0 else 1.0
	var effort := 3 if swimming else (2 if sprint else (1 if dir != Vector3.ZERO else 0))
	var climb := maxf(get_real_velocity().y, 0.0) if on_floor else 0.0
	body.update(delta, effort, climb, inventory.total_weight(), air_temp, inventory.warmth(), resting)
	_update_body_events(delta)
	_update_camera(delta, dir != Vector3.ZERO, sprint)
	_update_look_target()


var _fall_speed := 0.0
var _corridor_msg := 0


## Soft boundary far off the path: moving outwards you get slower and slower and are finally
## gently pushed back. That way the land beyond can continue naturally (hills, dunes) instead of a wall.
func _limit_corridor() -> void:
	if not world:
		return
	var w := world.local_to_world(global_position)
	var gen := world.gen
	var off := gen.path_offset(w.x, w.z)
	var excess := absf(off) - WorldGen.CORRIDOR
	if excess <= 0.0:
		return
	var k := gen.path_slope(w.z)
	var outward := Vector3(1.0, 0.0, -k).normalized() * signf(off)
	var vout := velocity.x * outward.x + velocity.z * outward.z
	if vout > 0.0:
		velocity -= outward * vout * smoothstep(0.0, 8.0, excess)
	if excess > 8.0:
		velocity -= outward * minf((excess - 8.0) * 0.8, 3.0)
	var now := Time.get_ticks_msec()
	if now - _corridor_msg > 20000 and excess > 4.0:
		_corridor_msg = now
		message.emit("This far off the trail you'd get lost – the path is behind you.")


## Push rigid bodies (logs); standing on a log presses it down with your own weight
func _push_bodies(dir: Vector3, delta: float) -> void:
	var kg := 75.0 + inventory.total_weight()
	var done := {}
	_on_log = null
	# log under the feet? (when standing still, physics reports no floor contact)
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position - Vector3(0, 0.45, 0), 1)
	q.exclude = [get_rid()]
	var under := get_world_3d().direct_space_state.intersect_ray(q)
	if not under.is_empty() and under["collider"] is RigidBody3D and (under["collider"] as Object).has_meta("pushable"):
		var lrb: RigidBody3D = under["collider"]
		_on_log = lrb
		done[lrb] = true
		var lax := lrb.global_basis.z
		var at0 := (under["position"] as Vector3) - lrb.global_position
		lrb.apply_force(Vector3.DOWN * kg * 9.8, lax * at0.dot(lax))
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb == null or done.has(rb):
			continue
		done[rb] = true
		var at := c.get_position() - rb.global_position
		# standing on top? (feet above the log axis)
		var on_top := c.get_normal().y > 0.6 and global_position.y > rb.global_position.y + 0.1
		if on_top:
			# weight acts on the log axis: leverage along the length, but no rolling away
			var ax := rb.global_basis.z
			rb.apply_force(Vector3.DOWN * kg * 9.8, ax * at.dot(ax))
			if rb.has_meta("pushable"):
				_on_log = rb
		elif dir != Vector3.ZERO:
			# a person pushes with about 700 N, much less when exhausted
			var strength: float = 950.0 * [1.0, 0.8, 0.5, 0.0][body.state]
			rb.apply_force(Vector3(dir.x, 0.0, dir.z) * strength, Vector3(at.x, 0.0, at.z))
			body.spend(4.0 * delta)


# ================================================================ Debug freecam

func _set_fly(m: int) -> void:
	fly_mode = m
	_cs.disabled = m == 2
	velocity = Vector3.ZERO
	rope = {}
	climbing = false
	message.emit(["Debug: walking normally", "Debug: flying (F6) – Space up, Ctrl down, Shift fast", "Debug: noclip (F7) – pass through everything"][m])


func _fly(delta: float) -> void:
	var dir := Vector3.ZERO
	if input_enabled:
		var b := camera.global_basis
		if Input.is_physical_key_pressed(KEY_W): dir -= b.z
		if Input.is_physical_key_pressed(KEY_S): dir += b.z
		if Input.is_physical_key_pressed(KEY_A): dir -= b.x
		if Input.is_physical_key_pressed(KEY_D): dir += b.x
		if Input.is_physical_key_pressed(KEY_SPACE): dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_CTRL): dir -= Vector3.UP
	var spd := 8.0
	if Input.is_physical_key_pressed(KEY_SHIFT):
		spd = 40.0
	if Input.is_physical_key_pressed(KEY_ALT):
		spd = 2.0
	var target := dir.normalized() * spd
	velocity = velocity.lerp(target, 1.0 - exp(-8.0 * delta))
	if fly_mode == 1:
		move_and_slide()
	else:
		global_position += velocity * delta
	head.position = Vector3(0, EYE_HEIGHT, 0)
	camera.rotation.z = 0.0
	_update_look_target()


## Step up small ledges (up to 30 cm) – but only onto flat, walkable ground
func _step_up(dir: Vector3) -> void:
	if dir == Vector3.ZERO or not is_on_floor() or not is_on_wall() or swimming:
		return
	# not on movable objects (round logs): balancing/climbing applies there
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is RigidBody3D:
			return
	var fwd := Vector3(dir.x, 0.0, dir.z).normalized() * 0.2
	var up := Vector3(0, 0.32, 0)
	var xf := global_transform
	if test_move(xf, up):
		return
	xf.origin += up
	if test_move(xf, fwd):
		return
	xf.origin += fwd
	# find the ground under the new position
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(xf.origin + Vector3(0, 0.05, 0), xf.origin - Vector3(0, 0.45, 0), collision_mask)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < cos(floor_max_angle):
		return
	global_position = (hit["position"] as Vector3) + Vector3(0, 0.02, 0)


## Round, low obstacles (fallen trunks) block at head height.
## Without this, physics pushes the character diagonally under the round underside.
func _block_low_obstacles() -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() < 0.05:
		return
	var d := hv.normalized()
	var space := get_world_3d().direct_space_state
	for h in [_shape.height - 0.04, _shape.height * 0.8]:
		var from := global_position + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 0.75, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["collider"] as Object).has_meta("climb_over"):
			velocity.x -= d.x * hv.dot(d)
			velocity.z -= d.z * hv.dot(d)
			return


func _update_crouch() -> void:
	var want := can_act() and (Input.is_physical_key_pressed(KEY_CTRL) or force_crouch)
	# with a big backpack you don't get as small when crouching
	var low := 1.0 + (0.4 if inventory.total_weight() > 12.0 else 0.0)
	if want and not crouching:
		crouching = true
		_set_height(low)
	elif not want and crouching:
		# only stand up if there's room above the head
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.8
		q.shape = cap
		q.transform = Transform3D(Basis(), global_position + Vector3(0, 0.95, 0))
		q.exclude = [get_rid()]
		q.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			crouching = false
			_set_height(1.8)
	elif crouching and absf(_shape.height - low) > 0.01:
		_set_height(low)


func _set_height(h: float) -> void:
	_shape.height = h
	_cs.position.y = h * 0.5


## Climb over a fallen trunk (costs stamina, impossible with heavy luggage)
func _try_climb() -> bool:
	var from := global_position + Vector3(0, 1.15, 0)
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1.1, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# high trunks: ray at shoulder height
		var qs := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.45, 0), from + Vector3(0, 0.45, 0) + fwd * 1.3, 1)
		qs.exclude = [get_rid()]
		hit = get_world_3d().direct_space_state.intersect_ray(qs)
	if hit.is_empty():
		# low trunks: ray at knee height
		var q2 := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.45, 0), global_position + Vector3(0, 0.45, 0) + fwd * 1.0, 1)
		q2.exclude = [get_rid()]
		hit = get_world_3d().direct_space_state.intersect_ray(q2)
		if hit.is_empty():
			return false
	var col: Object = hit["collider"]
	if col is RigidBody3D and col.has_meta("pushable"):
		# step up onto the log
		var rb := col as RigidBody3D
		# top edge at the hit point (the log can lie at an angle)
		var ax := rb.global_basis.z
		var hp: Vector3 = hit["position"]
		var on_axis := rb.global_position + ax * clampf((hp - rb.global_position).dot(ax), -float(rb.get_meta("length", 10.0)) * 0.5, float(rb.get_meta("length", 10.0)) * 0.5)
		var top := on_axis.y + float(rb.get_meta("radius", 0.4))
		if top - global_position.y > 1.3:
			return false
		body.spend(3.0)
		climbing = true
		var target := Vector3(on_axis.x, top + 0.05, on_axis.z)
		var tw2 := create_tween()
		tw2.tween_property(self, "global_position", target + Vector3(0, 0.25, 0) - fwd * 0.25, 0.25)
		tw2.tween_property(self, "global_position", target, 0.2)
		tw2.tween_callback(func():
			climbing = false
			velocity = Vector3.ZERO)
		return true
	if not col.has_meta("climb_over"):
		return _try_ledge()
	if inventory.total_weight() > 16.0:
		message.emit("You can't get over with that heavy backpack.")
		return true
	if body.stamina < 15.0:
		message.emit("Too exhausted to climb.")
		return true
	body.spend(14.0)
	climbing = true
	var start := global_position
	var over := start + fwd * 2.3
	var peak := Vector3(start.x, (hit["position"] as Vector3).y + 1.0, start.z) + fwd * 1.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", peak, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", over + Vector3(0, 0.3, 0), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		climbing = false
		velocity = Vector3.ZERO)
	return true


## Find a ledge in front (up to 2.4 m above the feet) and pull yourself up
func _try_ledge() -> bool:
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var top_from := global_position + fwd * 0.7 + Vector3(0, 2.6, 0)
	var q := PhysicsRayQueryParameters3D.create(top_from, top_from - Vector3(0, 2.6, 0), 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var ledge: Vector3 = hit["position"]
	var hit_body := hit["collider"] as CollisionObject3D
	if hit_body and (hit_body.collision_layer & ChunkManager.TERRAIN_LAYER) != 0 and not in_water:
		return false
	var rise := ledge.y - global_position.y
	if rise < 0.35 or rise > 2.4 or (hit["normal"] as Vector3).y < 0.7:
		return false
	# room to stand on top?
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	sq.shape = cap
	sq.transform = Transform3D(Basis(), ledge + Vector3(0, 0.9, 0))
	sq.exclude = [get_rid()]
	sq.collision_mask = 1
	if not space.intersect_shape(sq, 1).is_empty():
		return false
	if inventory.total_weight() > 18.0 and rise > 1.2:
		message.emit("You can't get up the ledge with that heavy backpack.")
		return true
	body.spend(4.0 + rise * 4.0)
	climbing = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(global_position.x, ledge.y + 0.2, global_position.z), 0.25 + rise * 0.2)
	tw.tween_property(self, "global_position", ledge + Vector3(0, 0.05, 0), 0.25)
	tw.tween_callback(func():
		climbing = false
		velocity = Vector3.ZERO)
	return true


# ================================================================ Rope

func start_rope(a: Vector3, b: Vector3, sag: float, t: float, mode: String, k: int) -> void:
	rope = {"a": a, "b": b, "sag": sag, "t": t, "mode": mode, "k": k}
	resting = false
	crouching = false
	_set_height(1.8)
	message.emit("You hold on to the rope. W/S to move, Space to let go." if mode == "hangel" else "Rappelling: S down, W up, Space to let go.")


func _rope_physics(delta: float) -> void:
	var a: Vector3 = rope["a"]
	var b: Vector3 = rope["b"]
	var length := a.distance_to(b)
	var move := 0.0
	if can_act():
		if rope["mode"] == "hangel":
			# forward = away from the nearer end in view direction
			var fwd := -global_basis.z
			var along := (b - a).normalized()
			var sgn := 1.0 if fwd.dot(along) >= 0.0 else -1.0
			if Input.is_physical_key_pressed(KEY_W): move += sgn
			if Input.is_physical_key_pressed(KEY_S): move -= sgn
		else:
			if Input.is_physical_key_pressed(KEY_S): move += 1.0
			if Input.is_physical_key_pressed(KEY_W): move -= 1.0
		if Input.is_physical_key_pressed(KEY_SPACE):
			_leave_rope("Let go!")
			return
	var spd := 1.2 if rope["mode"] == "hangel" else 1.6
	rope["t"] = clampf(rope["t"] + move * spd * delta / maxf(length, 0.1), 0.0, 1.0)
	var p := RopeVisual.point_at(a, b, rope["sag"], rope["t"])
	var kg := 75.0 + inventory.total_weight()
	if rope["mode"] == "hangel":
		global_position = p - Vector3(0, 1.95, 0)
		# climbing across is exhausting, luggage makes it worse
		body.spend((4.5 + inventory.total_weight() * 0.3) * delta)
	else:
		global_position = p - Vector3(0, 1.1, 0) + Vector3(0, 0, -0.35)
		body.spend((2.5 + inventory.total_weight() * 0.15) * delta * absf(move))
	velocity = Vector3.ZERO
	if obstacles and not obstacles.rope_load(rope["k"], kg, delta):
		_leave_rope("")
		return
	if body.stamina <= 1.0:
		_leave_rope("Your arms give out!")
		return
	var at_end: bool = (rope["t"] >= 0.999 and move > 0.0) or (rope["t"] <= 0.001 and move < 0.0)
	if at_end:
		_leave_rope("")


func _leave_rope(text: String) -> void:
	rope = {}
	velocity = Vector3(0, -0.5, 0)
	_fall_speed = 0.0
	if text != "":
		message.emit(text)


func _update_body_events(delta: float) -> void:
	if body.state == Body.State.COLLAPSED:
		if _last_state != Body.State.COLLAPSED:
			_collapse_timer = 7.0
			resting = false
			collapsed.emit()
		_collapse_timer -= delta
		if _collapse_timer <= 0.0:
			body.recover_from_collapse()
			recovered.emit()
	if body.state != _last_state:
		state_changed.emit(body.state)
		_last_state = body.state
	# resting turns into sleep after a while when you're tired
	if resting and not sleeping:
		_rest_timer += delta
		if _rest_timer > 4.0 and body.rest < 45.0:
			_start_sleep()
	if sleeping:
		_sleep_timer -= delta
		body.rest = minf(body.rest + delta * 9.0, 100.0)
		body.stamina = minf(body.stamina + delta * 12.0, body.max_stamina())
		body.food = maxf(body.food - delta * 0.6, 0.0)
		body.water = maxf(body.water - delta * 0.8, 0.0)
		if _sleep_timer <= 0.0:
			sleeping = false
			resting = false
			sleep_fade.emit(false)
			message.emit("Well rested. Onwards.")


func _toggle_rest() -> void:
	if sleeping or swimming:
		return
	resting = not resting
	_rest_timer = 0.0
	message.emit("You sit down and rest." if resting else "You get back up.")


func _start_sleep() -> void:
	sleeping = true
	_sleep_timer = 9.0
	sleep_fade.emit(true)


func _fall_damage(speed: float) -> void:
	var dmg := (speed - 11.0) * 6.0
	body.health = maxf(body.health - dmg, 0.0)
	body.spend(dmg)
	var broken: Array[String] = []
	for it in inventory.items:
		if ItemDefs.has_prop(it, "zerbrechlich") and randf() < 0.5:
			it["condition"] = maxf(it["condition"] - 0.5, 0.0)
			broken.append(ItemDefs.def(it["id"])["name"])
	message.emit("Ouch!" + ("  %s damaged." % ", ".join(broken) if not broken.is_empty() else ""))


# ================================================================ Water

func _water_level_here() -> float:
	if world == null:
		return -INF
	var w := world.local_to_world(global_position)
	return world.gen.water_level(w.x, w.z)


func _update_water() -> void:
	var wl := _water_level_here()
	var feet := global_position.y
	var was_swimming := swimming
	var was_in := in_water
	in_water = wl > -INF and feet < wl - 0.1
	if in_water and not was_in and velocity.y < -5.0:
		# water breaks the fall
		velocity.y *= 0.2
		_fall_speed = 0.0
		message.emit("SPLASH!")
	swimming = wl > -INF and (feet < wl - 1.3 or (was_swimming and feet < wl - 1.1))
	if in_water:
		body.wet = maxf(body.wet, clampf((wl - feet) / 1.2, 0.2, 1.0))
	if swimming and not was_swimming:
		var soaked := inventory.soak()
		message.emit("You're swimming!" + ("  Got wet: %s" % ", ".join(soaked) if not soaked.is_empty() else ""))


# ================================================================ Interaction

func _update_look_target() -> void:
	_look_target = null
	_water_target = false
	prompt = ""
	prompt_title = ""
	prompt_action = ""
	if not can_act() or world == null:
		return
	var from := view_origin()
	var to := from - camera.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, (1 << (WorldItem.LAYER - 1)) | (1 << 2))
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		# small things shouldn't need pixel-perfect aiming
		var sphere := SphereShape3D.new()
		sphere.radius = 0.22
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = sphere
		sq.collision_mask = q.collision_mask
		sq.collide_with_areas = true
		sq.exclude = [get_rid()]
		for i in range(1, 6):
			sq.transform = Transform3D(Basis(), from.lerp(to, i / 5.0))
			var res := space.intersect_shape(sq, 1)
			if not res.is_empty():
				hit = res[0]
				break
	if not hit.is_empty():
		var c: Object = hit["collider"]
		if c is WorldItem:
			_look_target = c
			var it: Dictionary = (c as WorldItem).item
			prompt = "E  pick up %s · %s kg" % [ItemDefs.display_name(it), _kg(ItemDefs.weight(it))]
			prompt_title = ItemDefs.display_name(it)
			prompt_action = "pick up · %s kg" % _kg(ItemDefs.weight(it))
			return
		if c.has_meta("poi_prompt"):
			var pr = c.get_meta("poi_prompt")
			var text: String = (pr as Callable).call(self) if pr is Callable else str(pr)
			if text != "":
				_look_target = c
				prompt = "E  " + text
				prompt_action = text
				return
	# water in front of the feet?
	for i in range(1, 6):
		var p := from.lerp(to, i / 5.0)
		var w := world.local_to_world(p)
		var wl := world.gen.water_level(w.x, w.z)
		if wl > -INF and p.y < wl + 0.3:
			_water_target = true
			var bottle := _find_refillable()
			prompt = "E  drink water" + ("  ·  fill bottle" if not bottle.is_empty() else "")
			prompt_title = "Water"
			prompt_action = "drink" + (" · fill bottle" if not bottle.is_empty() else "")
			return


func interact() -> void:
	if _look_target is WorldItem:
		var wi := _look_target as WorldItem
		if inventory.add(wi.item):
			message.emit("%s packed." % ItemDefs.def(wi.item["id"])["name"])
			wi.set_meta("taken", true)
			wi.queue_free()
		else:
			message.emit("The backpack is too full or too heavy.")
	elif _look_target and _look_target.has_meta("poi_action"):
		(_look_target.get_meta("poi_action") as Callable).call(self)
	elif _water_target:
		body.water = minf(body.water + 30.0, 100.0)
		var bottle := _find_refillable()
		if not bottle.is_empty():
			bottle["charges"] = ItemDefs.def("wasserflasche")["charges"]
			inventory.changed.emit()
			message.emit("You drink and refill the bottle.")
		else:
			message.emit("Cold, clear water.")


func _find_refillable() -> Dictionary:
	for it in inventory.items:
		var d := ItemDefs.def(it["id"])
		if d.get("refill", false) and it["charges"] < d["charges"]:
			return it
	return {}


func _wears(id: String) -> bool:
	for it in inventory.items:
		if it["id"] == id and it.get("equipped", false):
			return true
	return false


func _has_item(id: String) -> bool:
	for it in inventory.items:
		if it["id"] == id and it["condition"] >= 0.35:
			return true
	return false


## Use an item from the backpack
func use_item(item: Dictionary) -> void:
	var d := ItemDefs.def(item["id"])
	match d["kind"]:
		"essen", "trinken":
			if item.get("wet", false) and ItemDefs.has_prop(item, "verderblich"):
				message.emit("It's soaked and inedible.")
				return
			if d.get("refill", false):
				if item["charges"] <= 0:
					message.emit("The bottle is empty.")
					return
				item["charges"] -= 1
				body.water = minf(body.water + d.get("water", 0.0), 100.0)
				inventory.changed.emit()
				message.emit("A few sips of water.")
				return
			body.food = minf(body.food + d.get("food", 0.0), 100.0)
			body.water = minf(body.water + d.get("water", 0.0), 100.0)
			body.stamina = minf(body.stamina + 8.0 + d.get("stamina", 0.0), body.max_stamina())
			if d.has("warm_time"):
				body.warm_bonus_t = maxf(body.warm_bonus_t, d["warm_time"])
			_consume(item, d)
			if randf() < d.get("queasy", 0.0):
				body.spend(10.0)
				message.emit("Hmm. Your tummy doesn't like that.")
			elif item["id"] == "glueckskeks":
				message.emit("\"%s\"" % FORTUNES[randi() % FORTUNES.size()])
			elif d.has("warm_time"):
				message.emit("%s – warm all the way down." % d["name"])
			else:
				message.emit("%s – tasty." % d["name"])
		"medizin":
			body.health = minf(body.health + d.get("heal", 0.0), 100.0)
			if d.has("heat_protect"):
				body.heat_protect_t = d["heat_protect"]
				message.emit("Sunscreen on. The heat bothers you less.")
			else:
				message.emit("%s – better." % d["name"])
			_consume(item, d)
		"kleidung":
			inventory.toggle_equip(item)
			message.emit("%s %s." % [d["name"], "put on" if item["equipped"] else "taken off"])
		_:
			_use_special(item)


func _use_special(item: Dictionary) -> void:
	if item["condition"] < 0.35:
		message.emit("It's broken.")
		return
	match item["id"]:
		"kamera":
			DirAccess.make_dir_recursive_absolute("user://reise")
			var path := "user://reise/foto_%d.png" % Time.get_unix_time_from_system()
			get_viewport().get_texture().get_image().save_png(path)
			message.emit("Click! Photo saved.")
		"gummihuhn":
			Sfx.play(self, "squeak")
			message.emit("SQUEAK!")
		"pfeife":
			Sfx.play(self, "whistle", -8.0)
			message.emit("FWEEEET!")
		"mundharmonika":
			Sfx.play(self, "harmonica", -4.0)
			message.emit("A little tune. Resting feels even better now." if resting else "A little tune.")
			_harmonica_t = 40.0
		"taschenlampe", "laterne":
			_toggle_light(item["id"])
		"kompass":
			var tan := world.gen.path_point(_world_pos().z - 20.0) - world.gen.path_point(_world_pos().z)
			message.emit("The trail heads %s." % _dir_name(Vector2(tan.x, tan.z)))
		"karte":
			message.emit(_next_obstacle_text())
		"messer":
			_cut_rope()
		"drachen":
			_fly_kite()
		"muschel":
			message.emit("Whoosh... you can hear the sea.")
		"wasserpistole":
			message.emit("Pssshh! (In multiplayer this hits your friends.)")
		"fernglas":
			message.emit("Hold the right mouse button to look through.")
		"feldhandbuch":
			message.emit("Page 1: knots. Page 2: fire. Page 3: ... the pages are stuck together.")
		_:
			message.emit(ItemDefs.def(item["id"])["desc"])


const FORTUNES := ["The next hill is smaller than it looks.", "A friend will share their snacks with you.",
	"Your knots will hold today.", "Look up. The clouds are worth it.", "The river is shallower than you fear.",
	"Something shiny waits near a bench.", "Walk slower, see more.", "Your backpack is heavier than it needs to be.",
	"Adventure is just bad planning. Enjoy it.", "Tomorrow's trail starts with today's step."]

var _harmonica_t := 0.0
var _light: Light3D
var _light_item := ""


## Uses up one charge (cookie tin, thermos, first aid kit) or the whole item
func _consume(item: Dictionary, d: Dictionary) -> void:
	if d.has("charges") and not d.get("refill", false):
		item["charges"] -= 1
		if item["charges"] > 0:
			inventory.changed.emit()
			return
	inventory.remove(item)


func _world_pos() -> Vector3:
	return world.local_to_world(global_position) if world else global_position


static func _dir_name(v: Vector2) -> String:
	# world -Z is north
	var a := fposmod(atan2(v.x, -v.y), TAU)
	return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][int(round(a / (TAU / 8.0))) % 8]


func _next_obstacle_text() -> String:
	var z := _world_pos().z
	var best := {}
	for probe in [z, z - 600.0, z - 1200.0]:
		for o in world.gen.obstacles_near(probe):
			if o["z"] < z - 5.0 and (best.is_empty() or o["z"] > best["z"]):
				best = o
	if best.is_empty():
		return "The map shows nothing but trail for a while."
	var names := {"fallen_tree": "a fallen tree", "river": "a river with a broken bridge", "cliff": "a cliff"}
	return "The map shows %s about %d m ahead." % [names.get(best["type"], "something"), roundi(z - best["z"])]


func _cut_rope() -> void:
	for it in inventory.items:
		if it["id"] == "seil" and int(it.get("length", 10)) >= 10:
			if not inventory.can_add(ItemDefs.make("seil")):
				message.emit("No room for a second rope.")
				return
			var half := int(it["length"]) / 2
			it["length"] = half
			var other := ItemDefs.make("seil")
			other["length"] = half
			other["knot"] = it.get("knot", 1.0)
			inventory.add(other)
			inventory.changed.emit()
			message.emit("Snip. Two ropes of %d m." % half)
			return
	message.emit("Nothing to cut. (Needs a rope of 10 m or more.)")


func _toggle_light(id: String) -> void:
	if _light and _light_item == id:
		_light.queue_free()
		_light = null
		_light_item = ""
		message.emit("Light off.")
		return
	if _light:
		_light.queue_free()
	if id == "laterne":
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.8, 0.5)
		o.light_energy = 2.2
		o.omni_range = 9.0
		o.shadow_enabled = false
		o.position = Vector3(0.25, 1.0, -0.2)
		_light = o
		add_child(o)
	else:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.96, 0.85)
		sp.light_energy = 4.0
		sp.spot_range = 30.0
		sp.spot_angle = 24.0
		sp.shadow_enabled = true
		_light = sp
		head.add_child(sp)
	_light_item = id
	message.emit("Light on.")


func _fly_kite() -> void:
	var kite := Kite.new()
	kite.owner_body = self
	get_parent().add_child(kite)
	message.emit("Up it goes!")


func drop_item(item: Dictionary, throw := false) -> void:
	inventory.remove(item)
	item["equipped"] = false
	var fwd := -camera.global_basis.z
	var pos := view_origin() + fwd * 0.6 - Vector3(0, 0.25, 0)
	var vel := fwd * (9.0 if throw else 1.0) + Vector3(0, 2.5 if throw else 0.0, 0) + velocity
	if spawn_item.is_valid():
		spawn_item.call(item, pos, vel)
	if throw:
		body.spend(3.0)


static func _kg(v: float) -> String:
	return "%.1f" % v


# ================================================================ Camera

func _update_camera(delta: float, moving: bool, sprint: bool) -> void:
	var target_h := EYE_HEIGHT
	var roll := 0.0
	if body.state == Body.State.COLLAPSED or sleeping:
		target_h = 0.35
		roll = 0.9
	elif resting:
		target_h = 0.95
	elif crouching:
		target_h = _shape.height - 0.18
	elif moving and is_on_floor():
		_bob += delta * (11.0 if sprint else 7.5)
	if swimming:
		_bob += delta * 3.0
	var bob_amt := 0.045 if sprint else 0.03
	var s := body.stamina
	var breathe := sin(Time.get_ticks_msec() * 0.001 * (1.2 + (100.0 - s) * 0.02)) * 0.012 * (1.0 + (100.0 - s) * 0.03)
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-8.0 * delta))
	var y := target_h + sin(_bob) * bob_amt + breathe - _land_dip
	head.position.y = lerpf(head.position.y, y, 1.0 - exp(-10.0 * delta))
	head.position.x = cos(_bob * 0.5) * bob_amt * 0.6
	camera.rotation.z = lerpf(camera.rotation.z, roll, 1.0 - exp(-3.0 * delta))
	var fov: float = 22.0 if _zoom else Settings.values["fov"]
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-10.0 * delta))
