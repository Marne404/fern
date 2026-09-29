extends SceneTree
## Measures the scout's gait: moves a scout along -Z at several speeds and checks how well the feet stick to
## the ground (slip speed of a foot while it touches the ground, sinking, floating, time in the air).
## godot --headless --path . -s res://scripts/tests/gait_probe.gd [-- --speeds=1,3.4,6.2 --fps=60]

const TOUCH := 0.025


var _done := false


func _process(_d: float) -> bool:
	if not _done:
		_done = true
		_run()
	return true


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var speeds: PackedFloat64Array = str(args.get("speeds", "0.8,1.6,2.2,3.4,4.5,6.2")).split_floats(",")
	var fps := float(args.get("fps", "60"))
	var dt := 1.0 / fps
	print("speed  sprint  cadence  slip(m/s)  slip%%  sink(cm)  float(cm)  air%%  ik_miss(cm)")
	for v in speeds:
		var sc := Scout.new()
		root.add_child(sc)
		sc.set_process(false)
		var sprint := v > 3.5
		var feet: Array[Node3D] = [sc.find_child("FootL", true, false), sc.find_child("FootR", true, false)]
		var prev := [Vector3.INF, Vector3.INF]
		var prev2 := [[Vector3.INF, Vector3.INF], [Vector3.INF, Vector3.INF]]
		var slip_sum := 0.0
		var slip_n := 0
		var miss := 0.0
		var sink := 0.0
		var float_sum := 0.0
		var air := 0
		var steps := [0]
		sc.stepped.connect(func(_f): steps[0] += 1)
		var frames := int(6.0 * fps)
		var warm := int(2.0 * fps)
		for f in frames:
			sc.speed = v
			sc.sprint = sprint
			sc.position.z -= v * dt
			sc.animate(dt)
			var low := INF
			for i in 2:
				var p := _sole(feet[i])
				low = minf(low, p.y)
				# slip: the lowest sole point of a planted foot must not move
				# a rolling foot always has one fixed point (heel or toe): slip = the slower of the two
				var ht := _heel_toe(feet[i])
				if f >= warm and prev2[i][0] != Vector3.INF and sc._feet[i]["stance"] and sc._feet[i]["w"] >= 1.0:
					var hv := minf((ht[0] - prev2[i][0]).length(), (ht[1] - prev2[i][1]).length()) / dt
					slip_sum += hv
					slip_n += 1
					miss = maxf(miss, ((sc._feet[i]["ankle"] as Vector3) - feet[i].global_position).length())
				prev2[i] = ht
				prev[i] = p
			if f >= warm:
				sink = minf(sink, low)
				if low > TOUCH:
					air += 1
					float_sum += low
		var slip := slip_sum / maxf(slip_n, 1)
		var span := float(frames - warm)
		print("%5.1f  %6s  %7.2f  %9.2f  %5.0f  %8.1f  %9.1f  %4.0f  %6.1f" % [v, sprint, steps[0] / (frames * dt), slip, 100.0 * slip / maxf(v, 0.01),
			-sink * 100.0, 100.0 * float_sum / maxf(air, 1), 100.0 * air / span, miss * 100.0])
		sc.free()


## Lowest point of the sole (heel or toe), world space
func _sole(foot: Node3D) -> Vector3:
	var g := foot.global_transform
	var heel := g * Vector3(0, -0.132, 0.09)
	var toe := g * Vector3(0, -0.132, -0.16)
	return heel if heel.y < toe.y else toe


func _heel_toe(foot: Node3D) -> Array:
	var g := foot.global_transform
	return [g * Vector3(0, -0.132, 0.085), g * Vector3(0, -0.132, -0.16)]
