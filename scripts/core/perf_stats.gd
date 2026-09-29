class_name PerfStats
extends RefCounted
## Frame costs in one place (for the F3 overlay, the benchmark and --fps).
## GPU time needs render-time measuring on the viewport; `sample()` switches it on the first time.

static var _measuring := {}
## time of all _process callbacks of the last frame (between the first and the last marker node)
static var script_ms := 0.0
static var _t0 := 0


## Two marker nodes that run first and last in the process phase. Performance.TIME_PROCESS can't be
## used for this: it also contains the wait for the GPU (RenderingServer.sync).
static func install(parent: Node) -> void:
	for first in [true, false]:
		var m := Marker.new()
		m.first = first
		m.process_priority = -1000000 if first else 1000000
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		parent.add_child(m)


class Marker extends Node:
	var first := true

	func _process(_delta: float) -> void:
		if first:
			PerfStats._t0 = Time.get_ticks_usec()
		elif PerfStats._t0 > 0:
			PerfStats.script_ms = (Time.get_ticks_usec() - PerfStats._t0) / 1000.0


## Everything the engine reports about the last frame. `vp` is the viewport that renders the 3D world.
static func sample(vp: Viewport) -> Dictionary:
	var rid := vp.get_viewport_rid()
	if not _measuring.has(rid):
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_measuring[rid] = true
	return {
		"fps": Engine.get_frames_per_second(),
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
		# culling, sorting and draw-call submission on the CPU
		"render_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		# every _process of every node, and the physics step
		"process_ms": script_ms,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"prims": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"vram_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}


## Which side holds the frame back: the graphics card or the processor
static func verdict(frame_ms: float, gpu_ms: float, cpu_ms: float) -> String:
	if frame_ms <= 0.0:
		return "-"
	if gpu_ms > frame_ms * 0.8 and gpu_ms > cpu_ms:
		return "GPU-bound"
	if cpu_ms > frame_ms * 0.6:
		return "CPU-bound"
	return "balanced"


## Machine and renderer, for reports
static func system_info() -> String:
	var lines := PackedStringArray()
	lines.append("CPU      %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("GPU      %s (%s, driver %s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	lines.append("Renderer %s %s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_current_rendering_driver_name()])
	lines.append("OS       %s %s" % [OS.get_name(), OS.get_version_alias()])
	lines.append("Game     Fern %s, Godot %s" % [ProjectSettings.get_setting("application/config/version", "dev"),
		Engine.get_version_info()["string"]])
	return "\n".join(lines)
