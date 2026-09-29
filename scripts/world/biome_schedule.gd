class_name BiomeSchedule
extends RefCounted
## Strings the biomes together so that each one tends to show its best side: the golden birch slopes in
## the golden hour, the glowing woods at night, the cherry valley in the morning.
##
## Two parts share one idea, a timeline: for every segment the plan knows at which hour the hiker arrives and
## how fast the clock should run there (the clock may bend between `scales[0]` and SCALE_MAX).
## - The scheduler draws the next biomes with weights that favor biomes whose window can fill the segment
##   (never always: every biome keeps coming, no repeats within NO_REPEAT segments, long-unseen ones get a bonus).
## - The time director sets the clock's pace for the biome you are in, so its window lasts to its border (or
##   prepares the next biome when this one has nothing to show).
## Arrival hours come from the current hour, the length of a day and the hiker's real pace (breaks included).
## A segment is locked once the hiker is LOCK_AHEAD meters before it: nothing that was built can change.
## No back reference to the WorldGen (it owns the schedule): every call gets it passed in.

const LOCK_AHEAD := 2400.0
const NO_REPEAT := 8
## segments ordered by the schedule (~500 km); beyond, the old random blocks remain
const PLANNED := 300
## assumed pace (m/s along the trail, breaks included) until the real one is known
const PACE := 2.6
const SUNRISE := 5.6
const SUNSET := 19.6
const SCALE_MAX := 1.45
## match of a biome without a time window (Birch Wood, the rain and fog biomes)
const NEUTRAL := 0.45

var day_minutes := 36.0
## the setting "time of day": 0 = the clock runs; otherwise hours don't matter for the order
var fixed := 0
var pace := PACE
## first segment that may still be (re)planned
var first_open := 0


## the clock paces the director may choose (slowest first)
var scales: Array[float] = []


func configure(d: Dictionary) -> void:
	day_minutes = float(d.get("day_minutes", 36.0))
	fixed = int(d.get("fixed", 0))
	pace = float(d.get("pace", PACE))
	# short days pass a whole biome in most of a day: there the windows may be held longer
	var lo := clampf(0.6 * sqrt(day_minutes / 36.0), 0.35, 0.6)
	scales = [lo, lerpf(lo, 0.9, 0.33), lerpf(lo, 0.9, 0.67), 0.9, 1.0, 1.12, 1.25, SCALE_MAX]


# ---------------------------------------------------------------- clock arithmetic (hours may exceed 24)

## Game hours after `seconds` of real time, starting at hour h (like DayCycle.advance: days take 80 % of
## the cycle for 14 hours, nights 20 % for 10 hours), at a steady rate scale
static func hours_after(h: float, seconds: float, minutes: float, scale := 1.0) -> float:
	var total := minutes * 60.0
	var r_day := (SUNSET - SUNRISE) / (total * 0.8) * scale
	var r_night := (24.0 - (SUNSET - SUNRISE)) / (total * 0.2) * scale
	var s := seconds
	var out := h
	for i in 64:
		if s <= 0.0:
			break
		var hm := fposmod(out, 24.0)
		var day := hm >= SUNRISE and hm < SUNSET
		var to_edge: float
		if day:
			to_edge = SUNSET - hm
		else:
			to_edge = fposmod(SUNRISE - hm, 24.0)
			if to_edge <= 0.0:
				to_edge = 24.0
		var rate := r_day if day else r_night
		var need := to_edge / rate
		if need >= s:
			out += s * rate
			s = 0.0
		else:
			out += to_edge + 1e-5
			s -= need
	return out


## Is hour h (0..24) inside the window [from, to] (may wrap past midnight)?
static func in_window(h: float, win: Array) -> bool:
	var a: float = win[0]
	var b: float = win[1]
	return (h >= a and h < b) if a <= b else (h >= a or h < b)


## Share of the real time of a stretch (seconds long, starting at hour h, clock at scale) spent inside the
## biome's windows
func share_inside(wins: Array, h: float, seconds: float, scale: float) -> float:
	const N := 10
	var inside := 0
	var hh := h
	var step := seconds / N
	# sample the middle of each tenth
	hh = hours_after(hh, step * 0.5, day_minutes, scale)
	for i in N:
		var hm := fposmod(hh, 24.0)
		for w in wins:
			if in_window(hm, w):
				inside += 1
				break
		hh = hours_after(hh, step, day_minutes, scale)
	return float(inside) / N


## Best clock scale for a stretch in a biome: [share inside its window, scale] (neutral biomes: NEUTRAL, 1)
func best_span(wins: Array, h: float, seconds: float) -> Array:
	if wins.is_empty() or fixed != 0:
		return [NEUTRAL, 1.0]
	var best := [-1.0, 1.0]
	for sc: float in scales:
		# a slight preference for the normal pace
		var m := share_inside(wins, h, seconds, sc) - 0.02 * absf(log(sc))
		if m > best[0]:
			best = [m, sc]
	best[0] = maxf(best[0], 0.0)
	return best


func _wins(gen: WorldGen, k: int) -> Array:
	return gen.biomes[gen.segment_biome(k)]["best"]["hours"]


func _seconds(gen: WorldGen, k: int, from_d := -INF) -> float:
	return maxf(gen.segment_start(k + 1) - maxf(gen.segment_start(k), from_d), 1.0) / pace


# ---------------------------------------------------------------- planning

## The plan made at world creation: a hike from the start at 7:00 at the assumed pace
func plan_reference(gen: WorldGen) -> void:
	first_open = gen.intro_len
	plan(gen, 0.0, float(WorldGen.plan_defaults.get("start_hour", 7.0)), PLANNED)


## (Re)plans the open segments from the hiker's position d and the current hour (absolute hours, may exceed
## 24 – only the time differences matter). count: how many segments ahead.
func plan(gen: WorldGen, d: float, hour: float, count: int) -> void:
	var k0 := maxi(first_open, 1)
	var k1 := mini(k0 + count, mini(PLANNED, gen.segment_count() - 1))
	# the timeline up to the first open segment: the segment you are in and the locked ones, each at the pace
	# the director will give it
	var kc := gen.segment_at(d)
	var h := hour
	for k in range(kc, k0):
		var secs := _seconds(gen, k, d)
		h = hours_after(h, secs, day_minutes, best_span(_wins(gen, k), h, secs)[1])
	if kc >= k0:
		# (only at the very start of a plan) the gap up to the first open segment at the normal pace
		h = hours_after(hour, maxf(gen.segment_start(k0) - d, 0.0) / pace, day_minutes)
	# when each biome was seen last (segment index)
	var last := {}
	for k in range(maxi(k0 - 60, 0), k0):
		last[gen.segment_biome(k)] = k
	var rng := RandomNumberGenerator.new()
	for k in range(k0, k1):
		var secs := _seconds(gen, k)
		var weights := PackedFloat32Array()
		weights.resize(gen.biome_count)
		var scales := PackedFloat32Array()
		scales.resize(gen.biome_count)
		var total := 0.0
		# biomes share a handful of windows: rate each window once per segment
		var rated := {}
		for b in gen.biome_count:
			# never seen yet: as if just before the start (the bonus for long-unseen biomes starts later)
			var seen: int = last.get(b, -NO_REPEAT - 1)
			var age := k - seen
			if age <= NO_REPEAT:
				continue
			var wins: Array = gen.biomes[b]["best"]["hours"]
			var key := hash(wins)
			if not rated.has(key):
				rated[key] = best_span(wins, h, secs) if fixed != AT_BEST else [_at_best_match(gen, b, k), 1.0]
			var span: Array = rated[key]
			var m: float = span[0]
			var w := 0.04 + 3.0 * m * m * m + 0.08 * maxf(float(age) - 22.0, 0.0)
			weights[b] = w
			scales[b] = span[1]
			total += w
		# seeded per segment: the choice only changes when the prediction does
		rng.seed = hash([gen.seed_value, k, 4242])
		var r := rng.randf() * total
		var pick := -1
		for b in gen.biome_count:
			if weights[b] <= 0.0:
				continue
			pick = b
			r -= weights[b]
			if r <= 0.0:
				break
		if pick < 0:
			pick = (gen.segment_biome(k - 1) + 1) % gen.biome_count
		gen.set_segment_biome(k, pick)
		last[pick] = k
		h = hours_after(h, secs, day_minutes, scales[pick] if scales[pick] > 0.0 else 1.0)


## Locks the segments the hiker is getting close to: from now on they never change
func lock_up_to(gen: WorldGen, d: float) -> void:
	while first_open < gen.segment_count() - 1 and gen.segment_start(first_open) < d + LOCK_AHEAD:
		first_open += 1


# ---------------------------------------------------------------- time director

## How fast the clock should run right now (DayCycle.rate_scale): the best pace for the rest of this biome and
## the start of the next one together – the window lingers to the border (a long golden hour on the golden
## slopes, a long night in the glowing woods), a biome without a window prepares the next one. 1 = normal.
func director_scale(gen: WorldGen, d: float, hour: float) -> float:
	if fixed != 0:
		return 1.0
	var k := gen.segment_at(d)
	var secs := _seconds(gen, k, d)
	var wins := _wins(gen, k)
	var wins2 := _wins(gen, k + 1)
	var secs2 := _seconds(gen, k + 1)
	var best := -INF
	var best_sc := 1.0
	for sc: float in scales:
		var here := share_inside(wins, hour, secs, sc) if not wins.is_empty() else 0.0
		var h2 := hours_after(hour, secs, day_minutes, sc)
		var nxt: float = best_span(wins2, h2, secs2)[0] if not wins2.is_empty() else 0.0
		# the biome you are in counts more; the rest of a short remainder counts less
		var wh := clampf(secs / 240.0, 0.3, 1.0)
		var v := here * wh + nxt * 0.6 - 0.03 * absf(log(sc))
		if v > best:
			best = v
			best_sc = sc
	return best_sc


# ---------------------------------------------------------------- weather wishes

## The weather a biome wishes for on this visit: "rain", "fog", "clear" or "" (one roll per segment,
## from the biome's chances – the bog wants rain most of the time, the golden slopes a clear sky)
func weather_wish(gen: WorldGen, k: int) -> String:
	var w: Dictionary = gen.biomes[gen.segment_biome(k)]["best"]["weather"]
	if w.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen.seed_value, k, 777])
	var r := rng.randf()
	for kind in ["rain", "fog", "clear"]:
		r -= float(w.get(kind, 0.0))
		if r < 0.0:
			return kind
	return ""


# ---------------------------------------------------------------- "each biome at its best" (time mode 6)
# No running clock: the hour follows the trail. Inside a biome it drifts slowly through the heart of its
# window; around every border (±BLEND) it moves forward to the next biome's hour – golden hour → dusk →
# night → dawn. A biome without a window bridges its neighbours' hours.

const AT_BEST := 6
const BLEND := 350.0


## Hours at which a biome begins and ends in this mode (0..24)
func _in_out(wins: Array) -> Vector2:
	var win: Array = wins[0]
	var s := float(win[0])
	var e := float(win[1])
	if e < s:
		e += 24.0
	var l := e - s
	return Vector2(fposmod(s + 0.25 * l, 24.0), fposmod(e - 0.2 * l, 24.0))


func segment_hours(gen: WorldGen, k: int) -> Vector2:
	var wins := _wins(gen, k)
	if not wins.is_empty():
		return _in_out(wins)
	# bridge: from the previous biome's hour to the next one's
	var wp := _wins(gen, maxi(k - 1, 0))
	var wn := _wins(gen, k + 1)
	return Vector2(_in_out(wp).y if not wp.is_empty() else 12.0, _in_out(wn).x if not wn.is_empty() else 12.0)


## The hour at forward distance d in this mode
func best_hour_at(gen: WorldGen, d: float) -> float:
	var k := gen.segment_at(d)
	var s0 := gen.segment_start(k)
	var s1 := gen.segment_start(k + 1)
	var hk := segment_hours(gen, k)
	if d < s0 + BLEND and k > 0:
		var hp := segment_hours(gen, k - 1)
		return fposmod(hp.y + fposmod(hk.x - hp.y, 24.0) * smoothstep(s0 - BLEND, s0 + BLEND, d), 24.0)
	if d > s1 - BLEND:
		var hn := segment_hours(gen, k + 1)
		return fposmod(hk.y + fposmod(hn.x - hk.y, 24.0) * smoothstep(s1 - BLEND, s1 + BLEND, d), 24.0)
	var u := clampf((d - s0 - BLEND) / maxf(s1 - s0 - 2.0 * BLEND, 1.0), 0.0, 1.0)
	return fposmod(hk.x + fposmod(hk.y - hk.x, 24.0) * u, 24.0)


## In this mode the order favors small steps forward in time (a natural day: morning, midday, golden hour,
## dusk, night, dawn …): match of biome b after the previous segment
func _at_best_match(gen: WorldGen, b: int, k: int) -> float:
	var wins: Array = gen.biomes[b]["best"]["hours"]
	if wins.is_empty():
		return NEUTRAL
	var wp := _wins(gen, k - 1)
	var prev_out := _in_out(wp).y if not wp.is_empty() else 12.0
	var delta := fposmod(_in_out(wins).x - prev_out, 24.0)
	if delta < 0.4:
		return 0.5
	return 1.0 if delta <= 7.0 else maxf(0.0, 1.0 - (delta - 7.0) / 8.0)


## Hour for the title screen: the heart of the first biome's window (the golden hour without one)
func title_hour(gen: WorldGen, d: float) -> float:
	var wins := _wins(gen, gen.segment_at(d))
	if wins.is_empty():
		return 17.2
	var hh := _in_out(wins)
	return hh.x
