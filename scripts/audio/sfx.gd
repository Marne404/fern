class_name Sfx
extends RefCounted
## Tiny synthesizer for item sounds (no audio files needed): whistle, harmonica tune, squeak.

const RATE := 22050

static var _cache := {}


## Plays a synthesized sound on a short-lived player attached to `parent`
static func play(parent: Node, which: String, volume_db := -6.0) -> void:
	if not _cache.has(which):
		_cache[which] = _make(which)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[which]
	p.volume_db = volume_db
	parent.add_child(p)
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
		"squeak":
			var n := int(RATE * 0.35)
			var ph := 0.0
			for i in n:
				var t := float(i) / RATE
				var f := 900.0 + 700.0 * sin(t * PI / 0.35)
				ph += TAU * f / RATE
				samples.append(signf(sin(ph)) * 0.25 * minf((0.35 - t) / 0.05, 1.0) * minf(t / 0.01, 1.0))
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
