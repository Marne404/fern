extends SceneTree
## How the music plays over long hikes: every track must play, none should dominate; per part of the day the
## most played tracks. godot --headless --path . -s res://scripts/tests/music_sim.gd [-- --hours=40 --days=36]

var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var hours := float(args.get("hours", "40"))
	var day_min := float(args.get("days", "36"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var plays := {}
	var by_band := [{}, {}, {}, {}, {}, {}]
	for t in MusicTracks.MOODS:
		plays[t] = 0
	var recent: Array = []
	for sd in [1, 2, 3, 4]:
		var gen := WorldGen.new(sd)
		var h := 7.0
		var d := 0.0
		var t := 0.0
		while t < hours * 3600.0 / 4.0:
			var biome := gen.segment_biome(gen.segment_at(d))
			var title := MusicTracks.pick(MusicTracks.biome_scores(biome, fposmod(h, 24.0)), recent, rng)
			recent.append(title)
			if recent.size() > 10:
				recent.pop_front()
			plays[title] = int(plays.get(title, 0)) + 1
			var hb := fposmod(h, 24.0)
			var band := 5 if hb < 5.0 or hb >= 21.0 else (0 if hb < 7.5 else (1 if hb < 10.5 else (2 if hb < 15.5 else (3 if hb < 19.0 else 4))))
			by_band[band][title] = int(by_band[band].get(title, 0)) + 1
			var secs: float = float(MusicTracks.TRACKS[title][2]) + 6.0
			t += secs
			d += secs * 2.6
			h = BiomeSchedule.hours_after(h, secs, day_min)
	var total := 0
	for k in plays:
		total += plays[k]
	var never := []
	var lines := []
	for k in plays:
		if plays[k] == 0:
			never.append(k)
		lines.append([plays[k], k])
	lines.sort()
	lines.reverse()
	print("tracks played: %d plays, %d of %d titles; never: %s" % [total, plays.size() - never.size(), plays.size(), ", ".join(never)])
	print("most: " + ", ".join(lines.slice(0, 6).map(func(x): return "%s %.1f%%" % [x[1], 100.0 * x[0] / total])))
	print("least: " + ", ".join(lines.slice(lines.size() - 6).map(func(x): return "%s %d" % [x[1], x[0]])))
	var names := ["dawn", "morning", "midday", "golden", "dusk", "night"]
	for b in 6:
		var bl := []
		for k in by_band[b]:
			bl.append([by_band[b][k], k])
		bl.sort()
		bl.reverse()
		print("%-8s " % names[b] + ", ".join(bl.slice(0, 6).map(func(x): return str(x[1]))))
	quit()
	return true
