class_name Sfx
extends RefCounted
## Tiny synthesizer for item sounds (no audio files needed): whistle, harmonica tune, squeak, footsteps.

const RATE := 22050

static var _cache := {}


## Plays a synthesized sound on a short-lived player attached to `parent`
static func play(parent: Node, which: String, volume_db := -6.0, pitch := 1.0) -> void:
	# looked up at runtime so tool scripts (-s, no autoloads) can still use the synthesizer
	var settings := parent.get_node_or_null("/root/Settings")
	var vol: float = settings.values.get("sfx_volume", 0.8) if settings else 0.8
	if vol <= 0.01:
		return
	if not _cache.has(which):
		_cache[which] = _make_step(which) if which.begins_with("step_") else _make(which)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[which]
	p.volume_db = volume_db + linear_to_db(vol)
	p.pitch_scale = pitch
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Footstep "step_<kind>_<variant>": filtered noise bursts per ground (grass, path, sand, snow, wood, water)
static func _make_step(which: String) -> AudioStreamWAV:
	var parts := which.split("_")
	var kind := parts[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(which)
	var dur: float = {"grass": 0.16, "path": 0.12, "sand": 0.16, "snow": 0.2, "wood": 0.14, "water": 0.3, "mud": 0.26}.get(kind, 0.14)
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	# low-pass amount (0..1, higher = brighter) and grain density per ground
	var bright: float = {"grass": 0.35, "path": 0.55, "sand": 0.12, "snow": 0.45, "wood": 0.2, "water": 0.3, "mud": 0.08}.get(kind, 0.3)
	var grains: float = {"grass": 0.002, "path": 0.012, "sand": 0.0, "snow": 0.02, "wood": 0.0, "water": 0.004}.get(kind, 0.0)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.012, 1.0) * pow(1.0 - t / dur, 2.2)
		var x := rng.randf_range(-1.0, 1.0)
		var b := bright
		if kind == "water":
			b = lerpf(0.5, 0.08, t / dur)
		lp += (x - lp) * b
		lp2 += (lp - lp2) * b
		var v := lp2 * 1.6
		if kind == "grass":
			v = (lp - lp2) * 2.2 + lp2 * 0.6
		if rng.randf() < grains:
			v += rng.randf_range(-0.8, 0.8)
		if kind == "wood":
			ph += TAU * lerpf(210.0, 150.0, t / dur) / RATE
			v = v * 0.5 + sin(ph) * 0.9 * exp(-t * 30.0)
		if kind == "snow":
			v *= 0.8 + 0.4 * sin(t * TAU * 90.0)
		if kind == "mud":
			# squelch: low, sucking wobble that rises at the end
			ph += TAU * lerpf(90.0, 260.0, pow(t / dur, 3.0)) / RATE
			v = v * 0.6 + sin(ph) * 0.5 * smoothstep(0.3, 0.9, t / dur)
		samples[i] = v * env
	# same loudness for every ground (quiet sand would vanish, grainy gravel would click)
	var rms := 0.0
	var peak := 0.0
	for v in samples:
		rms += v * v
		peak = maxf(peak, absf(v))
	rms = sqrt(rms / n)
	var gain := minf(0.12 / maxf(rms, 1e-5), 0.9 / maxf(peak, 1e-5))
	for i in n:
		samples[i] *= gain
	return _wav(samples)


## Rain: soft, even hiss (low-passed noise) with a few droplets tapping on leaves; loops seamlessly
static func rain_loop() -> AudioStreamWAV:
	if _cache.has("rain"):
		return _cache["rain"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(RATE * 3.0)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.32
		lp2 += (lp - lp2) * 0.5
		samples[i] = lp2 * 0.55 + (lp - lp2) * 0.35
	# droplets: tiny ticks with a short ring, spread over the loop
	for d in 90:
		var start := rng.randi_range(0, n - 800)
		var f := rng.randf_range(1800.0, 4200.0)
		var amp := rng.randf_range(0.08, 0.3)
		for k in 700:
			var t := float(k) / RATE
			samples[start + k] += sin(TAU * f * t) * exp(-t * 90.0) * amp
	# crossfade the end into the start so the loop has no click
	var fade := 2000
	for k in fade:
		var w := float(k) / fade
		samples[k] = samples[k] * w + samples[n - fade + k] * (1.0 - w)
	var out := PackedFloat32Array(samples.slice(0, n - fade))
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	for i in out.size():
		out[i] = out[i] / maxf(peak, 1e-5) * 0.7
	var w := _wav(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = out.size()
	_cache["rain"] = w
	return w


## Crackling campfire: a soft roar of low noise with little pops and snaps, loops (4 s)
static func fire_loop() -> AudioStreamWAV:
	if _cache.has("fire"):
		return _cache["fire"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var n := int(RATE * 4.0)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.2
		# the roar breathes slowly
		samples[i] = lp2 * (0.55 + 0.25 * sin(float(i) / RATE * 2.3))
	for c in 70:
		var start := rng.randi_range(0, n - 1200)
		var amp := rng.randf_range(0.2, 0.9) * (1.0 if rng.randf() < 0.8 else 1.8)
		var len := rng.randi_range(80, 900)
		var hp := 0.0
		for k in len:
			var t := float(k) / len
			var x := rng.randf_range(-1.0, 1.0)
			hp = x - hp * 0.3
			samples[start + k] += hp * amp * exp(-t * 6.0) * 0.5
	var fade := 2000
	for k in fade:
		var w := float(k) / fade
		samples[k] = samples[k] * w + samples[n - fade + k] * (1.0 - w)
	var out := PackedFloat32Array(samples.slice(0, n - fade))
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	for i in out.size():
		out[i] = out[i] / maxf(peak, 1e-5) * 0.7
	var wv := _wav(out)
	wv.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wv.loop_begin = 0
	wv.loop_end = out.size()
	_cache["fire"] = wv
	return wv


## A babbling brook: soft rushing noise with bubbly little tones, loops seamlessly (4 s)
static func brook_loop() -> AudioStreamWAV:
	if _cache.has("brook"):
		return _cache["brook"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n := int(RATE * 4.0)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.2
		hp = lp - hp * 0.0
		var t := float(i) / RATE
		# the rush swells a little (whole cycles in the loop)
		samples[i] = lp * 0.35 * (0.8 + 0.2 * sin(t * TAU * 0.5))
	# bubbles: short rising blips
	for bnum in 140:
		var start := rng.randi_range(0, n - 2000)
		var f0 := rng.randf_range(500.0, 1400.0)
		var d := rng.randf_range(0.02, 0.06)
		var m := int(RATE * d)
		var ph := 0.0
		for k in m:
			var tt := float(k) / m
			ph += TAU * f0 * (1.0 + tt * 0.8) / RATE
			samples[start + k] += sin(ph) * sin(tt * PI) * rng.randf_range(0.08, 0.2)
	var fade := 3000
	for k in fade:
		var w := float(k) / fade
		samples[k] = samples[k] * w + samples[n - fade + k] * (1.0 - w)
	var out := PackedFloat32Array(samples.slice(0, n - fade))
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	for i in out.size():
		out[i] = out[i] / maxf(peak, 1e-5) * 0.6
	var w := _wav(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = out.size()
	_cache["brook"] = w
	return w


## A bee's buzz: a soft, wobbling hum (sawtooth through a low-pass), loops
static func buzz_loop() -> AudioStreamWAV:
	if _cache.has("buzz"):
		return _cache["buzz"]
	var n := int(RATE * 1.0)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# pitch wobbles with whole cycles inside the loop (1 s) so it loops seamlessly
		var f := 225.0 + sin(t * TAU * 3.0) * 12.0 + sin(t * TAU * 7.0) * 5.0
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		lp += (saw - lp) * 0.18
		var amp := 0.75 + 0.25 * sin(t * TAU * 5.0)
		samples[i] = lp * amp * 0.8
	var w := _wav(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	_cache["buzz"] = w
	return w


## A positional sound (birds, splashes) that frees itself
static func play_at(parent: Node, which: String, pos: Vector3, volume_db := -6.0, pitch := 1.0) -> void:
	var vol: float = 0.8
	var settings := parent.get_node_or_null("/root/Settings")
	if settings:
		vol = settings.values.get("sfx_volume", 0.8)
	if vol <= 0.01:
		return
	if not _cache.has(which):
		_cache[which] = _make(which)
	var p := AudioStreamPlayer3D.new()
	p.stream = _cache[which]
	p.volume_db = volume_db + linear_to_db(vol)
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = 45.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


static func _make(which: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match which:
		"whistle":
			# pea whistle: bright tone with a fast trill, slight glide up
			var n := int(RATE * 0.55)
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				var f := 2350.0 + 180.0 * t + sin(t * TAU * 38.0) * 120.0
				ph += TAU * f / RATE
				var env := minf(t / 0.02, 1.0) * minf((0.55 - t) / 0.08, 1.0)
				samples.append((sin(ph) * 0.8 + sin(ph * 2.0) * 0.12 + (randf() - 0.5) * 0.06) * env)
		"harmonica":
			# a little folk tune with reedy chords (fundamental + two harmonics, slight tremolo)
			var notes := [[392.0, 0.3], [440.0, 0.3], [494.0, 0.45], [440.0, 0.3], [392.0, 0.3], [330.0, 0.6], [392.0, 0.35], [294.0, 0.8]]
			for nt in notes:
				var f: float = nt[0]
				var d: float = nt[1]
				var m := int(RATE * d)
				for i in m:
					var t := float(i) / RATE
					var env := minf(t / 0.03, 1.0) * minf((d - t) / 0.06, 1.0) * (0.85 + 0.15 * sin(t * TAU * 5.5))
					var s := 0.0
					for h: float in [1.0, 1.25, 1.5]:
						var x := TAU * f * h * t
						s += (sin(x) + 0.35 * sin(2.0 * x) + 0.2 * sin(3.0 * x)) * (1.0 if h == 1.0 else 0.45)
					samples.append(s * 0.22 * env)
		"chirp_0", "chirp_1", "chirp_2", "chirp_3":
			# songbird calls: short whistled notes that glide (robin-like trills, tit "tee-tee", sparrow chirps)
			var v := int(which.right(1))
			var notes: Array = [[[3200, 4200, 0.07], [4100, 3500, 0.06], [3600, 4400, 0.08]],
				[[5200, 5000, 0.09], [0, 0, 0.05], [5200, 5000, 0.09], [0, 0, 0.05], [3900, 3800, 0.14]],
				[[2800, 3400, 0.05], [0, 0, 0.04], [2900, 3500, 0.05], [0, 0, 0.04], [3000, 3300, 0.05]],
				[[4400, 3000, 0.16], [0, 0, 0.06], [4200, 3200, 0.12]]][v]
			var ph := 0.0
			for nt in notes:
				var f0: float = nt[0]
				var f1: float = nt[1]
				var d: float = nt[2]
				var m := int(RATE * d)
				for i in m:
					var t := float(i) / m
					if f0 <= 0.0:
						samples.append(0.0)
						continue
					var f := lerpf(f0, f1, t) + sin(t * 40.0) * 60.0
					ph += TAU * f / RATE
					var env := sin(t * PI) * (1.0 if t > 0.1 else t * 10.0)
					samples.append(sin(ph) * env * 0.5)
		"flutter":
			# wings taking off: a few soft, fast whooshes
			var n := int(RATE * 0.35)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp += (randf_range(-1.0, 1.0) - lp) * 0.25
				var beats := pow(maxf(sin(t * TAU * 16.0), 0.0), 3.0)
				samples.append(lp * beats * (1.0 - t / 0.35) * 0.9)
		"stone_click":
			# two stones knocking: a short dry click with a woody ring
			var n := int(RATE * 0.18)
			for i in n:
				var t := float(i) / RATE
				var env := exp(-t * 45.0)
				samples.append((sin(TAU * 1900.0 * t) * 0.5 + sin(TAU * 3100.0 * t) * 0.3 + randf_range(-1.0, 1.0) * 0.4) * env * 0.7)
		"skip":
			# a pebble kissing the water: a bright "tip"
			var n := int(RATE * 0.12)
			for i in n:
				var t := float(i) / RATE
				samples.append(sin(TAU * (1400.0 - t * 5000.0) * t) * exp(-t * 55.0) * 0.6 + randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.25)
		"plop":
			# sinking: a round, falling "blop"
			var n := int(RATE * 0.3)
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				ph += TAU * (520.0 - t * 900.0) / RATE
				samples.append(sin(ph) * exp(-t * 14.0) * minf(t / 0.005, 1.0) * 0.7)
		"whoosh":
			var n := int(RATE * 0.25)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp += (randf_range(-1.0, 1.0) - lp) * 0.35
				samples.append(lp * sin(t / 0.25 * PI) * 0.6)
		"squeak":
			var n := int(RATE * 0.35)
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				var f := 900.0 + 700.0 * sin(t * PI / 0.35)
				ph += TAU * f / RATE
				samples.append(signf(sin(ph)) * 0.25 * minf((0.35 - t) / 0.05, 1.0) * minf(t / 0.01, 1.0))
	return _wav(samples)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
