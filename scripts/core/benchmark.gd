class_name Benchmark
extends Node
## Benchmark: the same hike for everyone. World 1, midday, fair weather, VSync and frame limit off.
## The scout stands at a spot in each of the first biomes (the world loads completely, then 2.5 s to settle
## and 6 s of measuring), then walks for 25 s along the trail (streaming, hitches). The report goes to
## user://benchmarks/ and is shown at the end.
## Start: settings → Performance → "Run benchmark", or from the command line `-- --bench` (quits afterwards).

signal progress(text: String)
signal finished(report: String, path: String)

const SEED := 1
const STATIONS := 6
const LOAD_MAX := 45.0
const SETTLE := 2.5
const MEASURE := 6.0
const WALK := 25.0

## main.gd (teleports the player, knows world and atmosphere)
var main: Node
var _stations: Array = []     # [z, biome name]
var _i := -1
var _phase := ""
var _t := 0.0
var _last_us := 0
var _cur: Dictionary
var _results: Array = []
var _started_ms := 0
var _quiet := 0.0
var _timed_out := false


func start() -> void:
	var gen: WorldGen = main.gen
	for k in STATIONS:
		var d0 := maxf(gen.segment_start(k), 0.0)
		var d1 := gen.segment_start(k + 1)
		var z := -(d0 + (d1 - d0) * 0.45)
		_stations.append([z, gen.biomes[gen.dominant_biome(z)]["name"]])
	# the same light and sky for every run
	var atm: Atmosphere = main.atmosphere
	atm.day.fixed = 2
	atm.day.advance(0.0)
	atm.weather.mode = 1
	atm.weather.reset()
	# measure what the machine can do, not the monitor
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_started_ms = Time.get_ticks_msec()
	_next_station()


func _next_station() -> void:
	_i += 1
	if _i >= _stations.size():
		_phase = "walk"
		_t = 0.0
		_cur = _new_run("Walking (streaming)")
		main.bench_walk(true)
		progress.emit("Benchmark: walking along the trail …")
		return
	_phase = "load"
	_t = 0.0
	_quiet = 0.0
	main.bench_place(_stations[_i][0])
	progress.emit("Benchmark %d/%d: %s – loading …" % [_i + 1, _stations.size(), _stations[_i][1]])


func _new_run(title: String) -> Dictionary:
	return {"title": title, "frames": PackedFloat32Array(), "gpu": 0.0, "render": 0.0, "process": 0.0,
		"physics": 0.0, "draws": 0.0, "prims": 0.0, "vram": 0.0, "n": 0}


func _process(delta: float) -> void:
	if _phase == "" or _phase == "done":
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0 if _last_us > 0 else delta * 1000.0
	_last_us = now
	_t += delta / maxf(Engine.time_scale, 0.001)
	match _phase:
		"load":
			var w: ChunkManager = main.world
			var loaded: bool = not main.bench_spawning() and w.pending_count() == 0 and w.backlog_count() == 0 \
				and w.impostors.pending_count() == 0
			# quiet for a while: between two plans (every 0.2 s) the job list can be empty for a moment
			_quiet = _quiet + delta if loaded else 0.0
			if _quiet > 1.5 or _t > LOAD_MAX:
				_timed_out = _quiet <= 1.5
				_phase = "settle"
				_t = 0.0
				progress.emit("Benchmark %d/%d: %s – measuring …" % [_i + 1, _stations.size(), _stations[_i][1]])
		"settle":
			if _t > SETTLE:
				_phase = "measure"
				_t = 0.0
				# * = the place hadn't finished loading after LOAD_MAX seconds
				_cur = _new_run(_stations[_i][1] + ("*" if _timed_out else ""))
		"measure":
			_record(frame_ms)
			if _t > MEASURE:
				_results.append(_cur)
				_next_station()
		"walk":
			_record(frame_ms)
			if _t > WALK:
				_results.append(_cur)
				main.bench_walk(false)
				_finish()


func _record(frame_ms: float) -> void:
	var s := PerfStats.sample(get_viewport() if main.bench_viewport() == null else main.bench_viewport())
	if OS.get_cmdline_user_args().has("--benchspikes") and frame_ms > 50.0:
		print("[spike] %s t=%.2f %.0f ms  gpu %.1f  script %.1f  physics %.1f  chunks +%d" % [_cur["title"], _t, frame_ms,
			s["gpu_ms"], s["process_ms"], s["physics_ms"], main.world.pending_count()])
	_cur["frames"].append(frame_ms)
	_cur["gpu"] += s["gpu_ms"]
	_cur["render"] += s["render_ms"]
	_cur["process"] += s["process_ms"]
	_cur["physics"] += s["physics_ms"]
	_cur["draws"] += s["draws"]
	_cur["prims"] += s["prims"]
	_cur["vram"] = maxf(_cur["vram"], s["vram_mb"])
	_cur["n"] += 1


## Average frame time and the 1 % low (the frame time that only 1 % of the frames exceed)
static func _frame_stats(frames: PackedFloat32Array) -> Vector3:
	if frames.is_empty():
		return Vector3.ZERO
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in frames:
		total += f
	var p99 := sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]
	return Vector3(total / frames.size(), p99, sorted[sorted.size() - 1])


func report_has_star() -> bool:
	for r in _results:
		if (r["title"] as String).ends_with("*"):
			return true
	return false


func _finish() -> void:
	_phase = "done"
	Settings.apply_all()
	var lines := PackedStringArray()
	var vp_size: Vector2i = main.bench_viewport().size if main.bench_viewport() else get_viewport().get_visible_rect().size
	lines.append("Fern benchmark  %s" % Time.get_datetime_string_from_system(false, true))
	lines.append(PerfStats.system_info())
	lines.append("Screen   %d×%d, render scale %d %%" % [vp_size.x, vp_size.y, roundi(get_viewport().scaling_3d_scale * 100.0)])
	lines.append("Preset   %s" % Settings.values["preset"])
	lines.append("")
	lines.append("%-22s %6s %7s %7s %7s %7s %7s %6s %6s" % ["Place", "FPS", "1% low", "frame", "GPU", "render", "script", "draws", "Mtris"])
	var sum_fps := 0.0
	var worst_low := 9999.0
	var tot := {"frame": 0.0, "gpu": 0.0, "cpu": 0.0, "n": 0}
	var vram := 0.0
	for r in _results:
		var n: int = maxi(r["n"], 1)
		var fs := _frame_stats(r["frames"])
		var fps := 1000.0 / maxf(fs.x, 0.01)
		var low := 1000.0 / maxf(fs.y, 0.01)
		var cpu: float = (r["render"] + r["process"] + r["physics"]) / n
		lines.append("%-22s %6.1f %7.1f %5.1fms %5.1fms %5.1fms %5.1fms %6d %6.2f" % [
			(r["title"] as String).left(22), fps, low, fs.x, r["gpu"] / n, r["render"] / n,
			(r["process"] + r["physics"]) / n, int(r["draws"] / n), r["prims"] / n / 1000000.0])
		if not (r["title"] as String).begins_with("Walking"):
			sum_fps += fps
			tot["frame"] += fs.x
			tot["gpu"] += r["gpu"] / n
			tot["cpu"] += cpu
			tot["n"] += 1
		worst_low = minf(worst_low, low)
		vram = maxf(vram, r["vram"])
	var sn: int = maxi(tot["n"], 1)
	lines.append("")
	lines.append("Average  %.1f FPS   worst 1%% low %.1f FPS   VRAM %.0f MB" % [sum_fps / sn, worst_low, vram])
	lines.append("Bottleneck  %s  (frame %.1f ms, GPU %.1f ms, CPU %.1f ms)" % [
		PerfStats.verdict(tot["frame"] / sn, tot["gpu"] / sn, tot["cpu"] / sn), tot["frame"] / sn, tot["gpu"] / sn, tot["cpu"] / sn])
	lines.append("Duration %d s%s" % [(Time.get_ticks_msec() - _started_ms) / 1000,
		"   (* still loading after %d s)" % int(LOAD_MAX) if report_has_star() else ""])
	lines.append("")
	lines.append("Settings")
	var keys: Array = Settings.PRESETS["Extreme"].keys()
	keys.sort()
	for k in keys:
		lines.append("  %-22s %s" % [k, str(Settings.values[k])])
	var report := "\n".join(lines)
	DirAccess.make_dir_recursive_absolute("user://benchmarks")
	var path := "user://benchmarks/bench_%s.txt" % Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(report + "\n")
		f.close()
	finished.emit(report, ProjectSettings.globalize_path(path))
