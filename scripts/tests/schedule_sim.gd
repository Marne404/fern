extends SceneTree
## Simulated hikes through the biome schedule: how much of each biome's time falls into its best window?
## godot --headless --path . -s res://scripts/tests/schedule_sim.gd [-- --days=12,36 --seeds=1,2,3 --km=80]
## Modes: legacy (old random order), reference (plan at world creation only), live (re-planned while hiking),
## director (live + the clock bends; after step 3).

var _done := false
var trace := false
var sleep_chance := 0.15
var _arr := 0.0


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var days: PackedFloat64Array = str(args.get("days", "12,24,36,60")).split_floats(",")
	var seeds: PackedFloat64Array = str(args.get("seeds", "1,2,3,4")).split_floats(",")
	var modes: PackedStringArray = str(args.get("modes", "legacy,reference,live,director")).split(",")
	var km := float(args.get("km", "80"))
	trace = args.has("trace")
	sleep_chance = float(args.get("sleep", "0.15"))
	print("day_min  mode        in-window  good-visits  night-biomes-at-night  biomes-seen  max-repeat-gap")
	for dm in days:
		for mode in modes:
			var sum := {"in": 0.0, "all": 0.0, "good": 0, "visits": 0, "nin": 0.0, "nall": 0.0, "seen": 0.0, "gap": 0.0}
			for sd in seeds:
				var r := _hike(int(sd), dm, mode, km)
				for k in r:
					sum[k] += r[k]
			var n := float(seeds.size())
			print("%6.0f   %-10s  %8.0f%%  %10.0f%%  %20.0f%%  %11.1f  %13.1f" % [dm, mode, 100.0 * sum["in"] / maxf(sum["all"], 1.0),
				100.0 * sum["good"] / maxf(sum["visits"], 1.0), 100.0 * sum["nin"] / maxf(sum["nall"], 1.0), sum["seen"] / n, sum["gap"] / n])
	quit()
	return true


## One hike: walking 3.4 m/s with breaks (every 3–8 min for 0.5–3 min), a night's sleep now and then.
func _hike(sd: int, day_minutes: float, mode: String, km: float) -> Dictionary:
	WorldGen.plan_defaults = {"start_hour": 7.0, "day_minutes": day_minutes, "fixed": 0, "pace": BiomeSchedule.PACE, "legacy": mode == "legacy"}
	var gen := WorldGen.new(sd)
	var sch := gen.schedule
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 7919 + int(day_minutes)
	var day := DayCycle.new()
	day.day_minutes = day_minutes
	day.hour = 7.0
	var hour_abs := 7.0
	var d := 0.0
	var dt := 2.0
	var t := 0.0
	var walk_left := rng.randf_range(180.0, 480.0)
	var rest_left := 0.0
	var pace := BiomeSchedule.PACE
	var d_prev := 0.0
	var plan_t := 0.0
	var scale := 1.0
	var dir_t := 0.0
	var out := {"in": 0.0, "all": 0.0, "good": 0, "visits": 0, "nin": 0.0, "nall": 0.0, "seen": 0.0, "gap": 0.0}
	var cur_k := -1
	var visit_in := 0.0
	var visit_all := 0.0
	var seen := {}
	var slept_night := -1
	while d < km * 1000.0:
		# hiker
		if rest_left > 0.0:
			rest_left -= dt
		else:
			d += 3.4 * dt
			walk_left -= dt
			if walk_left <= 0.0:
				rest_left = rng.randf_range(30.0, 180.0)
				walk_left = rng.randf_range(180.0, 480.0)
		# sleeping through some nights (a campfire, a shelter)
		var hm := fposmod(hour_abs, 24.0)
		var night_no := floori((hour_abs + 3.0) / 24.0)
		if hm > 21.5 and hm < 23.0 and slept_night != night_no:
			slept_night = night_no
			if rng.randf() < sleep_chance:
				hour_abs += fposmod(6.4 - hm, 24.0)
		if mode == "director":
			dir_t -= dt
			if dir_t <= 0.0:
				dir_t = 6.0
				var want := sch.director_scale(gen, d, hour_abs)
				scale = lerpf(scale, want, 1.0 - exp(-6.0 / 8.0))
		hour_abs = BiomeSchedule.hours_after(hour_abs, dt, day_minutes, scale)
		t += dt
		# pace estimate (EMA over a few minutes) and re-planning
		pace = lerpf(pace, (d - d_prev) / dt, 1.0 - exp(-dt / 600.0))
		d_prev = d
		if mode != "legacy" and mode != "reference":
			plan_t -= dt
			if plan_t <= 0.0:
				plan_t = 5.0
				sch.pace = clampf(pace, 0.8, 5.0)
				sch.lock_up_to(gen, d)
				sch.plan(gen, d, hour_abs, 6)
		# measure
		var k := gen.segment_at(d)
		var b := gen.segment_biome(k)
		if k != cur_k:
			if trace and cur_k >= 0:
				var cb := gen.segment_biome(cur_k)
				print("seg %3d  %-20s  arrive %5.1f  %4.0f%% in window  scale %.2f  pace %.2f" % [cur_k, gen.biomes[cb]["name"], _arr, 100.0 * visit_in / maxf(visit_all, 1.0) if visit_all > 0.0 else -1.0, scale, pace])
			_arr = fposmod(hour_abs, 24.0)
			if cur_k >= 0 and visit_all > 0.0:
				out["visits"] += 1
				if visit_in / visit_all >= 0.4:
					out["good"] += 1
			cur_k = k
			visit_in = 0.0
			visit_all = 0.0
			seen[b] = true
		var wins: Array = gen.biomes[b]["best"]["hours"]
		if not wins.is_empty():
			var inside := false
			for w in wins:
				inside = inside or BiomeSchedule.in_window(fposmod(hour_abs, 24.0), w)
			out["all"] += dt
			visit_all += dt
			if inside:
				out["in"] += dt
				visit_in += dt
			if wins[0] == BiomeDefs.NIGHT:
				out["nall"] += dt
				if inside:
					out["nin"] += dt
	out["seen"] = seen.size()
	# largest distance (in segments) between two visits of the same biome
	var lastk := {}
	var gap := 0
	for k in range(0, gen.segment_at(d) + 1):
		var b := gen.segment_biome(k)
		if lastk.has(b):
			gap = maxi(gap, k - lastk[b])
		lastk[b] = k
	out["gap"] = gap
	return out
