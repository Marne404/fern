class_name WorldGen
extends RefCounted
## Deterministic, infinite world: main path, heights, biomes, ground colors.
## Only read after _init, and therefore safe to call from worker threads
## (exception: arc_length(), which only the main thread uses).
##
## The path runs roughly in the -Z direction; x = path_x(z). "Forward" = -z.

const CHUNK := 64.0
const SEGMENT := 1700.0      # average biome length along the path
const TRANSITION := 280.0    # width of a biome transition
const BIOME_TABLE := 6000    # precomputed biome segments (~10,000 km)

var seed_value: int
var biomes: Array[Dictionary]
var biome_count: int

var _path_a := FastNoiseLite.new()
var _path_b := FastNoiseLite.new()
var _elev_a := FastNoiseLite.new()
var _elev_b := FastNoiseLite.new()
var _und := FastNoiseLite.new()
var _hill := FastNoiseLite.new()
var _region := FastNoiseLite.new()
var _paint := FastNoiseLite.new()
var _width := FastNoiseLite.new()
var _vary := FastNoiseLite.new()
var _path_c := FastNoiseLite.new()
var _elev_c := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _bay := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _plateau := FastNoiseLite.new()
var _grove := FastNoiseLite.new()
var _far := FastNoiseLite.new()
var _dune := FastNoiseLite.new()
var _mesa := FastNoiseLite.new()

var _segment_biome := PackedInt32Array()
var _segment_start := PackedFloat32Array()

# ponds and mountain lakes (cache, shared by worker threads)
const POND_CELL := 240.0
var _ponds := {}
var _pond_mutex := Mutex.new()

# arc length (main thread only)
var _arc := PackedFloat64Array()
const ARC_STEP := 2.0


func _init(p_seed: int) -> void:
	seed_value = p_seed
	biomes = BiomeDefs.all()
	biome_count = biomes.size()
	_setup_noise(_path_a, 1, 0.0022, 2)
	_setup_noise(_path_b, 2, 0.011, 1)
	_setup_noise(_elev_a, 3, 0.0011, 2)
	_setup_noise(_elev_b, 4, 0.0045, 2)
	_setup_noise(_und, 5, 0.018, 3)
	_setup_noise(_hill, 6, 0.0065, 4)
	_setup_noise(_region, 7, 0.012, 2)
	_setup_noise(_paint, 8, 0.03, 3)
	_setup_noise(_width, 9, 0.04, 1)
	_setup_noise(_vary, 10, 0.0016, 2)
	_setup_noise(_grove, 11, 0.011, 2)
	_setup_noise(_path_c, 12, 0.00045, 2)
	_setup_noise(_elev_c, 13, 0.00032, 2)
	_setup_noise(_warp, 14, 0.006, 2)
	_setup_noise(_bay, 15, 0.0045, 2)
	_setup_noise(_ridge, 16, 0.0075, 3)
	_setup_noise(_plateau, 17, 0.0035, 1)
	_setup_noise(_far, 18, 0.0021, 2)
	_setup_noise(_dune, 19, 0.011, 2)
	_setup_noise(_mesa, 20, 0.0048, 2)
	_build_biome_table()


func _setup_noise(n: FastNoiseLite, offset: int, freq: float, octaves: int) -> void:
	n.seed = seed_value * 31 + offset
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves


# ================================================================ Path

func path_x(z: float) -> float:
	# at the start, settle smoothly onto x = 0
	var fade := smoothstep(0.0, 120.0, absf(z))
	# three scales: wide bends over kilometers, curves over hundreds of meters, small wiggles
	return (_path_c.get_noise_1d(z) * 200.0 + _path_a.get_noise_1d(z) * 42.0 + _path_b.get_noise_1d(z) * 6.0) * fade


func path_slope(z: float) -> float:
	return (path_x(z + 0.5) - path_x(z - 0.5))


## Signed distance to the path center (right is positive, walking direction -z)
func path_offset(x: float, z: float) -> float:
	var k := path_slope(z)
	return (x - path_x(z)) / sqrt(1.0 + k * k)


func path_width(z: float) -> float:
	return 1.0 + 0.3 * _width.get_noise_1d(z)


## Elevation profile of the path: long climbs, passes and dips
func _raw_elevation(z: float) -> float:
	# long ascents and descents (passes, valleys), plus medium hills and small waves
	return _elev_c.get_noise_1d(z) * 65.0 + _elev_a.get_noise_1d(z) * 28.0 + _elev_b.get_noise_1d(z) * 9.0


## Elevation profile of the path including cliff steps.
func path_elevation(z: float) -> float:
	return base_elevation(z) + cliff_delta(0.0, z, cliffs_near(z))


## Elevation profile without obstacles. Flat at the coast so the sea can be level.
func base_elevation(z: float) -> float:
	var raw := _raw_elevation(z)
	var c := coast_info(z)
	if c.y <= 0.0:
		return raw
	return lerpf(raw, c.x + COAST_HEIGHT, c.y)


const COAST_HEIGHT := 16.0   # the path lies this many meters above the sea


## Vector2(sea level, coast weight 0..1) for a position z
func coast_info(z: float) -> Vector2:
	var d := -z
	if d < 0.0:
		return Vector2(0.0, 0.0)
	var k := _segment_at(d)
	var bb := biome_blend(z)
	var w := 0.0
	var ks := -1
	for cand in [k - 1, k, k + 1]:
		if cand >= 0 and cand < BIOME_TABLE and biomes[_segment_biome[cand]]["terrain"].get("coast", 0.0) > 0.0:
			var bid := _segment_biome[cand]
			var cw := 0.0
			if int(bb.x) == bid:
				cw += 1.0 - bb.z
			if int(bb.y) == bid:
				cw += bb.z
			if cw > w or ks < 0 and cw > 0.0:
				w = cw
				ks = cand
	if ks < 0:
		return Vector2(0.0, 0.0)
	return Vector2(sea_level_of_segment(ks), w)


func sea_level_of_segment(k: int) -> float:
	var mid := (_segment_start[k] + _segment_start[k + 1]) * 0.5
	return _raw_elevation(-mid) - COAST_HEIGHT


## Sea nearby (for the sea surface): Vector2(level, visible 0/1)
func sea_near(z: float) -> Vector2:
	var k := _segment_at(-z)
	for cand in [k, k + 1, k - 1]:
		if cand >= 0 and cand < BIOME_TABLE and biomes[_segment_biome[cand]]["terrain"].get("coast", 0.0) > 0.0:
			var dist := 0.0
			if -z < _segment_start[cand]:
				dist = _segment_start[cand] + z
			elif -z > _segment_start[cand + 1]:
				dist = -z - _segment_start[cand + 1]
			if dist < 700.0:
				return Vector2(sea_level_of_segment(cand), 1.0)
	return Vector2(0.0, 0.0)


## 1 at the path center, 0.5 at the edge, 0 outside
func path_value(dist: float, half_width: float) -> float:
	return clampf(1.0 - absf(dist) / (half_width * 2.0), 0.0, 1.0)


# ================================================================ Biomes

func _hash(a: int, b: int) -> int:
	var h := hash([seed_value, a, b])
	return h & 0x7fffffff


func _build_biome_table() -> void:
	# segments in blocks as a permutation of all biomes; no direct repetition.
	_segment_biome.resize(BIOME_TABLE)
	_segment_start.resize(BIOME_TABLE + 1)
	var prev := -1
	var order: Array[int] = []
	# fixed, especially beautiful opening: Autumn Meadow, Spring Meadow, Cliff Lands, Sunset Coast
	var intro := [0, 4, 9, 8]
	if seed_value != 1:
		# other worlds: start with a friendly biome, random afterwards
		var friendly := [0, 3, 4, 9, 11]
		intro = [friendly[_hash(1, 5) % friendly.size()]]
	for k in BIOME_TABLE:
		if k < intro.size():
			_segment_biome[k] = intro[k]
			prev = intro[k]
		else:
			if order.is_empty():
				var block := (k - intro.size()) / biome_count
				var rng := RandomNumberGenerator.new()
				rng.seed = _hash(block, 77)
				for i in biome_count:
					order.append(i)
				for i in range(biome_count - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var t := order[i]
					order[i] = order[j]
					order[j] = t
				if order[0] == prev:
					var t2 := order[0]
					order[0] = order[1]
					order[1] = t2
				# right after the opening, no repetition of the opening biomes
				if k == intro.size():
					for b in intro:
						var mi := order.find(b)
						if mi < 4:
							var last := biome_count - 1 - intro.find(b)
							order[mi] = order[last]
							order[last] = b
			var b: int = order.pop_front()
			_segment_biome[k] = b
			prev = b
		var jitter := 0.0 if k == 0 else (float(_hash(k, 13) % 1000) / 1000.0 - 0.5) * 700.0
		_segment_start[k] = k * SEGMENT + jitter - 400.0
	_segment_start[BIOME_TABLE] = BIOME_TABLE * SEGMENT


## Segment index for a forward distance d = -z
func _segment_at(d: float) -> int:
	var k := clampi(int(floor((d + 400.0) / SEGMENT)), 0, BIOME_TABLE - 1)
	while k > 0 and d < _segment_start[k]:
		k -= 1
	while k < BIOME_TABLE - 1 and d >= _segment_start[k + 1]:
		k += 1
	return k


## Vector3(biome A, biome B, weight of B)
func biome_blend(z: float) -> Vector3:
	var d := -z
	if d < 0.0:
		return Vector3(0, 0, 0)
	var k := _segment_at(d)
	var cur := _segment_biome[k]
	var into := d - _segment_start[k]
	var left := _segment_start[k + 1] - d
	var half := TRANSITION * 0.5
	if into < half and k > 0:
		var w := smoothstep(-half, half, into)
		return Vector3(_segment_biome[k - 1], cur, w)
	if left < half and k < BIOME_TABLE - 1:
		var w2 := smoothstep(half, -half, left)
		return Vector3(cur, _segment_biome[k + 1], w2)
	return Vector3(cur, cur, 0.0)


func dominant_biome(z: float) -> int:
	var b := biome_blend(z)
	return int(b.y) if b.z >= 0.5 else int(b.x)


## Distance to the next biome change (for hints / debugging)
func next_biome_start(z: float) -> float:
	var k := _segment_at(-z)
	return -_segment_start[min(k + 1, BIOME_TABLE)]


# ================================================================ Row data
# All values that only depend on z are computed once per row.

func row(z: float, with_ponds := true) -> Dictionary:
	var bb := biome_blend(z)
	var a: Dictionary = biomes[int(bb.x)]["terrain"]
	var b: Dictionary = biomes[int(bb.y)]["terrain"]
	var t := bb.z
	var k := path_slope(z)
	var gdz := gorge_distance(z)
	var gorge := _gorge_from(gdz)
	var shape := valley_shape(z)
	return {
		"z": z,
		"px": path_x(z),
		"inv_len": 1.0 / sqrt(1.0 + k * k),
		"elev": base_elevation(z),
		"cliffs": cliffs_near(z),
		"rivers": rivers_near(z),
		"half_w": lerpf(a["path_width"], b["path_width"], t) * 0.5 * path_width(z) * lerpf(1.0, 0.8, gorge),
		"blend": bb,
		"vw": lerpf(a["valley_width"], b["valley_width"], t) * shape.x,
		"vr": lerpf(a["valley_ramp"], b["valley_ramp"], t) * shape.y,
		"vh": lerpf(a["valley_height"], b["valley_height"], t) * shape.z,
		"gorge": gorge,
		"gorge_wall": 1.0 - smoothstep(14.0, 62.0, gdz),
		"far_h": lerpf(a["far_height"], b["far_height"], t),
		"dunes": lerpf(a["dunes"], b["dunes"], t),
		"und": lerpf(lerpf(a["undulation"], b["undulation"], t), 0.05, gorge),
		"depth": lerpf(a["path_depth"], b["path_depth"], t),
		"rough": lerpf(a["roughness"], b["roughness"], t),
		"terr": lerpf(a["terraces"], b["terraces"], t),
		"coast": lerpf(a.get("coast", 0.0), b.get("coast", 0.0), t),
		"sea": coast_info(z).x,
		"a": a, "b": b, "t": t,
		"ponds": ponds_near(z) if with_ponds else [],
		"pools": pools_near(z),
	}


func offset_in_row(x: float, r: Dictionary) -> float:
	return (x - r["px"]) * r["inv_len"]


func height_in_row(x: float, r: Dictionary) -> float:
	var z: float = r["z"]
	var d := absf(offset_in_row(x, r))
	var h: float = r["elev"] + _und.get_noise_2d(x, z) * r["und"]
	if not (r["cliffs"] as Array).is_empty():
		h += cliff_delta(offset_in_row(x, r), z, r["cliffs"], x)
	# warped coordinates: hills, bays and ridges instead of parallel walls
	var wx := x + _warp.get_noise_2d(x, z) * 45.0
	var wz := z + _warp.get_noise_2d(x + 517.0, z - 211.0) * 45.0
	var hill := _hill.get_noise_2d(wx, wz) * 0.5 + 0.5
	# the valley edge varies: meadows open into bays, hills push in.
	# In the narrow at the fallen tree the width stays fixed (the trunk must reach both walls).
	var gorge: float = r["gorge"]
	var vw: float = r["vw"] * (0.55 + 1.0 * (_bay.get_noise_2d(x, z) * 0.5 + 0.5))
	var rise := smoothstep(vw, vw + r["vr"], d)
	var vh: float = r["vh"]
	var peaks := pow(hill, 1.7) * 2.0
	var rdg := 1.0 - absf(_ridge.get_noise_2d(wx, wz))
	rdg *= rdg
	var hr: float = rise * vh * (0.12 + peaks + rdg * (0.25 + r["rough"] * 0.5))
	# gentle knolls near the path too: the meadow is never completely flat
	hr += (1.0 - rise) * smoothstep(r["half_w"] + 3.0, r["half_w"] + 16.0, d) * hill * minf(vh, 16.0) * 0.14 * (1.0 - r["dunes"])
	# hinterland: forested hills and mountains, rocky peaks or wide dunes with mesas
	hr += _hinterland(x, z, d, wx, wz, hill, rdg, vw, r)
	# narrow at the fallen tree: long before it, banks close in on the path and get higher
	# (a sunken lane); at the trunk there are vertical rock walls with narrow ledges that you can't climb
	if gorge > 0.0:
		var bw := lerpf(vw, 4.2, gorge)
		var br := lerpf(22.0, 6.5, gorge)
		# first flat, grassy banks, steep rock walls only shortly before the trunk
		var bank := smoothstep(bw, bw + br, d) * (lerpf(1.5, 15.0, gorge * gorge) + hill * 3.0 * gorge * gorge)
		hr = lerpf(hr, maxf(hr, bank), smoothstep(0.0, 0.25, gorge))
	var gw: float = r["gorge_wall"]
	if gw > 0.0:
		var wall := hr
		var q: float = wall / 2.4 + _warp.get_noise_2d(x * 2.5, z * 2.5) * 0.5
		var fq: float = q - floor(q)
		var ledges: float = (floor(q) + smoothstep(0.45, 0.9, fq)) * 2.4
		hr = lerpf(hr, lerpf(wall, ledges, 0.65), gw)
	# plateaus only in patches, with warped, irregular steps (no stacked plates)
	var terr: float = r["terr"]
	if terr > 0.5:
		var pm := smoothstep(0.1, 0.45, _plateau.get_noise_2d(x, z))
		if pm > 0.0:
			var step_h := terr * (0.8 + 0.5 * (_bay.get_noise_2d(wz, wx) * 0.5 + 0.5))
			var q: float = hr / step_h + _warp.get_noise_2d(x * 3.0, z * 3.0) * 0.6
			var f: float = q - floor(q)
			var stepped: float = (floor(q) + smoothstep(0.6, 0.85, f)) * step_h
			hr = lerpf(hr, stepped, pm * clampf(terr / 6.0, 0.0, 1.0) * smoothstep(0.02, 0.2, rise))
	h += hr
	# rugged edges in rocky biomes
	var rough: float = r["rough"]
	if rough > 0.0:
		h += absf(_paint.get_noise_2d(x * 0.5, z * 0.5)) * rough * 6.0 * rise
	# coast: to the right of the path the land drops into the sea as a cliff
	var coast: float = r["coast"]
	if coast > 0.0:
		var off := offset_in_row(x, r)
		var cd := vw * 0.9 + 8.0
		var drop := smoothstep(cd, cd + 16.0, off + _paint.get_noise_2d(x * 0.4, z * 0.4) * 6.0)
		var floor_h: float = r["sea"] - 5.0 - maxf(off - cd, 0.0) * 0.04
		h = lerpf(h, floor_h, drop * coast)
	var pv := path_value(d, r["half_w"])
	h -= smoothstep(0.3, 0.8, pv) * r["depth"]
	# river channels: winding, limited length, banks ~32° (walkable)
	for rv in r["rivers"]:
		var along := river_along(x, z, rv)
		var lr: float = rv["length"]
		if absf(along) > lr + 4.0:
			continue
		var dist := river_distance(x, z, rv)
		var half: float = river_half(along, rv)
		var lvl: float = rv["level"]
		var target: float
		if dist < half:
			target = lvl - 0.2 - rv["depth"] * (1.0 - (dist / half) * (dist / half))
		else:
			target = lvl - 0.2 + (dist - half) * 0.62
		# at the ends the channel stops at a steep rock wall
		var end_fade := 1.0 - smoothstep(lr - 1.0, lr + 3.0, absf(along))
		h = lerpf(h, minf(h, target), end_fade)
	# waterfall pools below cliffs: deep, steep wall towards the cliff
	for p in r["pools"]:
		var pd := Vector2(x - p.x, z - p.y).length()
		var pr: float = water_radius(p, x, z)
		if pd < pr * 1.25:
			var tg: float
			if pd < pr:
				tg = p.w - 0.2 - 3.6 * (1.0 - (pd / pr) * (pd / pr))
			else:
				tg = p.w - 0.2 + (pd - pr) * 0.62
			h = lerpf(h, minf(h, tg), smoothstep(pr * 1.25, pr * 1.0, pd))
	# pond hollows: pull the ground below the water level, gently rising shore
	for p in r["ponds"]:
		var pd := Vector2(x - p.x, z - p.y).length()
		var pr: float = water_radius(p, x, z)
		if pd < pr * 1.7:
			var target: float
			if pd < pr:
				var depth := 1.0 + pr * 0.06
				target = p.w - depth * (1.0 - (pd / pr) * (pd / pr)) - 0.15
			else:
				target = p.w - 0.15 + (pd - pr) * 0.32
			h = lerpf(h, minf(h, target), smoothstep(pr * 1.7, pr * 0.95, pd))
	return h


## Irregular shoreline: effective radius of a body of water in direction (x, z)
func water_radius(p: Vector4, x: float, z: float) -> float:
	var a := atan2(z - p.y, x - p.x)
	var ph := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
	return p.z * (1.0 + 0.2 * sin(3.0 * a + ph) + 0.1 * sin(5.0 * a + ph * 1.7) + 0.05 * sin(9.0 * a + ph * 2.3))


## Distance relative to the shore (1 = on the shoreline)
func water_rel(p: Vector4, x: float, z: float) -> float:
	return Vector2(x - p.x, z - p.y).length() / water_radius(p, x, z)


## Pond in cell k: Vector4(x, z, radius, water level); radius 0 = no pond
func pond(k: int) -> Vector4:
	_pond_mutex.lock()
	var cached = _ponds.get(k)
	_pond_mutex.unlock()
	if cached != null:
		return cached
	var p := _compute_pond(k)
	_pond_mutex.lock()
	_ponds[k] = p
	_pond_mutex.unlock()
	return p


func _compute_pond(k: int) -> Vector4:
	if k < 1:
		return Vector4.ZERO
	var hsh := _hash(k, 91)
	var zc := -(k + 0.5) * POND_CELL + (float(hsh % 1000) / 1000.0 - 0.5) * POND_CELL * 0.5
	var bb := biome_blend(zc)
	var ta: Dictionary = biomes[int(bb.x)]["terrain"]
	var tb: Dictionary = biomes[int(bb.y)]["terrain"]
	var chance := lerpf(ta["ponds"], tb["ponds"], bb.z)
	if float((hsh >> 10) % 1000) / 1000.0 >= chance:
		return Vector4.ZERO
	if obstacle_zone(zc, 70.0):
		return Vector4.ZERO
	var size: Vector2 = (ta["pond_size"] as Vector2).lerp(tb["pond_size"], bb.z)
	var r := lerpf(size.x, size.y, float((hsh >> 3) % 1000) / 1000.0)
	var side := 1.0 if (hsh >> 20) & 1 == 1 else -1.0
	var vw := lerpf(ta["valley_width"], tb["valley_width"], bb.z)
	var off := maxf(vw * 0.55, 6.0) + r + 5.0
	var slope := path_slope(zc)
	var x := path_x(zc) + side * off * sqrt(1.0 + slope * slope)
	# water level just below the lowest ground point anywhere under the water surface mesh (it reaches
	# 1.6 × r; the terrain hides the rest). Otherwise a lower trail nearby would see the water as a ceiling.
	var level := INF
	for rad: float in [r, r * 1.3, r * 1.62]:
		for i in 16:
			var a := i * TAU / 16.0
			var sx := x + cos(a) * rad
			var sz := zc + sin(a) * rad
			level = minf(level, height_in_row(sx, row(sz, false)))
	return Vector4(x, zc, r, level - 0.35)


func ponds_near(z: float) -> Array:
	var out := []
	var k := floori(-z / POND_CELL)
	for kk in [k - 1, k, k + 1]:
		var p := pond(kk)
		if p.z > 0.0 and absf(z - p.y) < p.z * 2.1:
			out.append(p)
	return out


## Water level at a point or -INF (ponds, pools, rivers, sea)
func water_level(x: float, z: float) -> float:
	return water_in_row(x, row(z))


## margin > 1 extends ponds/rivers by a shore zone (for shore colors and plants)
func water_in_row(x: float, r: Dictionary, margin := 1.05) -> float:
	var z: float = r["z"]
	for p in r["ponds"]:
		if water_rel(p, x, z) < margin:
			return p.w
	for p in r["pools"]:
		if water_rel(p, x, z) < margin:
			return p.w
	for rv in r["rivers"]:
		if river_distance(x, z, rv) < river_half(river_along(x, z, rv), rv) * margin + 0.3:
			return rv["level"]
	if r["coast"] > 0.01:
		return r["sea"]
	return -INF


# ================================================================ Obstacles
# At most one obstacle per cell (600 m). Deterministic from the seed, cached thread-safely.

const OB_CELL := 600.0
const CORRIDOR := 135.0      # how far you may stray sideways from the path
var _obst := {}
var _ob_mutex := Mutex.new()


func obstacle(k: int) -> Dictionary:
	_ob_mutex.lock()
	var cached = _obst.get(k)
	_ob_mutex.unlock()
	if cached != null:
		return cached
	var o := _compute_obstacle(k)
	_ob_mutex.lock()
	_obst[k] = o
	_ob_mutex.unlock()
	return o


func _compute_obstacle(k: int) -> Dictionary:
	if k < 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(k, 555)
	var z := -(k + 0.3 + rng.randf() * 0.4) * OB_CELL
	var type := ""
	match k:
		0:
			z = -215.0
			type = "fallen_tree"
		1:
			z = -760.0
			type = "river"
		2:
			z = -1380.0
			type = "cliff"
		_:
			if rng.randf() > 0.85:
				return {}
			var allowed: Array = biomes[dominant_biome(z)]["terrain"].get("obstacles", ["river", "fallen_tree", "cliff"])
			if allowed.is_empty():
				return {}
			type = allowed[rng.randi() % allowed.size()]
	# not in coastal sections (sea) except the tree
	if type != "fallen_tree" and coast_info(z).y > 0.05:
		type = "fallen_tree"
	var slope := path_slope(z)
	var o := {"k": k, "type": type, "z": z, "px": path_x(z), "dir": Vector2(slope, -1.0).normalized(),
		"side": 1.0 if rng.randf() < 0.5 else -1.0, "seed": rng.randi()}
	match type:
		"river":
			var a := rng.randf_range(-0.3, 0.3)
			o["angle"] = a
			o["axis"] = Vector2(cos(a), sin(a))          # flow direction
			o["width"] = rng.randf_range(8.0, 10.5)
			o["depth"] = 3.0
			o["level"] = base_elevation(z) - 1.1
			o["flow"] = rng.randf_range(0.9, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
			o["length"] = rng.randf_range(85.0, 115.0)     # half length
			o["mphase"] = Vector2(rng.randf() * TAU, rng.randf() * TAU)
			o["mamp"] = rng.randf_range(11.0, 17.0)
		"cliff":
			o["drop"] = rng.randf_range(16.0, 22.0)
			var r := 8.5
			var half := 1.6
			var side: float = o["side"]
			var pz := z - (r + 0.3)
			var px := path_x(pz) + side * (half + r + 1.2)
			var below := base_elevation(pz) + _cliff_term(pz, o, 0.0, px)
			o["pool"] = Vector4(px, pz, r, below - 0.7)
		"fallen_tree":
			o["height"] = 1.55     # trunk axis above the path
	return o


func obstacles_near(z: float, reach := 0.0) -> Array:
	var out := []
	var k := floori(-z / OB_CELL)
	for kk in [k - 1, k, k + 1]:
		var o := obstacle(kk)
		if o.is_empty():
			continue
		if reach <= 0.0 or absf(z - o["z"]) < reach:
			out.append(o)
	return out


## Is z near any obstacle? (for ponds and find spots)
func obstacle_zone(z: float, margin: float) -> bool:
	for o in obstacles_near(z):
		var extent: float = margin + (40.0 if o["type"] == "cliff" else 0.0)
		if absf(z - o["z"]) < extent:
			return true
	return false


func cliffs_near(z: float) -> Array:
	var out := []
	for o in obstacles_near(z):
		if o["type"] == "cliff" and z > o["z"] - 30.0 and z < o["z"] + 300.0:
			out.append(o)
	return out


func rivers_near(z: float) -> Array:
	var out := []
	for o in obstacles_near(z):
		if o["type"] == "river" and absf(z - o["z"]) < (float(o["length"]) + 5.0) * absf(sin(o["angle"])) + o["mamp"] + 4.0 + o["width"] + 30.0:
			out.append(o)
	return out


func pools_near(z: float) -> Array:
	var out := []
	for o in obstacles_near(z):
		if o["type"] == "cliff":
			var p: Vector4 = o["pool"]
			if absf(z - p.y) < p.z * 1.65:
				out.append(p)
	return out


## Current (m/s, world xz) at a point in the river, otherwise 0. Far out at sea it drifts you back to the shore.
func river_flow(x: float, z: float) -> Vector2:
	var ci := coast_info(z)
	if ci.y > 0.3:
		var r := row(z)
		var off := offset_in_row(x, r)
		if off > r["vw"] * 0.9 + 60.0:
			var slope := path_slope(z)
			return -Vector2(1.0, slope).normalized() * 2.5 * smoothstep(60.0, 90.0, off - r["vw"] * 0.9)
	for rv in rivers_near(z):
		var d := river_distance(x, z, rv)
		var half: float = river_half(river_along(x, z, rv), rv)
		if d < half + 0.3:
			# strongest in the middle
			var al := river_along(x, z, rv)
			var tangent := (river_point(al + 1.0, rv) - river_point(al - 1.0, rv)).normalized()
			return tangent * float(rv["flow"]) * (1.0 - 0.6 * (d / (half + 0.3)) * (d / (half + 0.3)))
	return Vector2.ZERO


## Position along the river axis (0 = bridge/path)
func river_along(x: float, z: float, rv: Dictionary) -> float:
	var ax: Vector2 = rv["axis"]
	return (x - rv["px"]) * ax.x + (z - rv["z"]) * ax.y


## Sideways offset of the river center (meander); straight at the bridge
func river_meander(along: float, rv: Dictionary) -> float:
	var ph: Vector2 = rv["mphase"]
	var m: float = sin(along * 0.038 + ph.x) * rv["mamp"] + sin(along * 0.09 + ph.y) * 3.5 + sin(along * 0.21 + ph.x * 2.0) * 1.2
	return m * smoothstep(9.0, 40.0, absf(along))


## Half river width at a position (narrows and widenings), unchanged at the bridge
func river_half(along: float, rv: Dictionary) -> float:
	var ph: Vector2 = rv["mphase"]
	var v := 0.26 * sin(along * 0.047 + ph.y * 2.0) + 0.12 * sin(along * 0.13 + ph.x)
	return float(rv["width"]) * 0.5 * (1.0 + v * smoothstep(8.0, 30.0, absf(along)))


## Distance to the (winding) river center; very large outside the river's length
func river_distance(x: float, z: float, rv: Dictionary) -> float:
	var ax: Vector2 = rv["axis"]
	var along := river_along(x, z, rv)
	if absf(along) > float(rv["length"]) + 4.0:
		return 1e6
	var perp: float = (x - rv["px"]) * ax.y - (z - rv["z"]) * ax.x
	return absf(perp - river_meander(along, rv))


## Point on the river center (world xz)
func river_point(along: float, rv: Dictionary) -> Vector2:
	var ax: Vector2 = rv["axis"]
	var nrm := Vector2(ax.y, -ax.x)
	return Vector2(rv["px"], rv["z"]) + ax * along + nrm * river_meander(along, rv)


## Valley shape along the path: Vector3(width, ramp, height factor).
## Wide plains with low hills alternate with narrow, high valleys.
func valley_shape(z: float) -> Vector3:
	var n := _vary.get_noise_1d(z)
	var wide := smoothstep(-0.05, 0.45, n)
	var narrow := smoothstep(-0.15, -0.55, n)
	return Vector3(lerpf(1.0, 2.6, wide) * lerpf(1.0, 0.62, narrow),
		lerpf(1.0, 1.6, wide) * lerpf(1.0, 0.75, narrow),
		lerpf(1.0, 0.5, wide) * lerpf(1.0, 1.35, narrow))


## Groves and clearings: 0 = open meadow, 1 = dense grove
func grove(x: float, z: float) -> float:
	return smoothstep(0.38, 0.62, _grove.get_noise_2d(x, z) * 0.5 + 0.5)


## Distance (along z) to the nearest fallen tree, very large if none is nearby
func gorge_distance(z: float) -> float:
	var best := 1e6
	var k := floori(-z / OB_CELL)
	for kk in [k - 1, k, k + 1]:
		var o := obstacle(kk)
		if not o.is_empty() and o["type"] == "fallen_tree":
			best = minf(best, absf(z - o["z"]))
	return best


## Narrow around fallen trees: 1 at the trunk, 0 far away. The valley already narrows ~180 m before
## slowly into a narrow sunken lane.
func gorge_factor(z: float) -> float:
	return _gorge_from(gorge_distance(z))


func _gorge_from(dz: float) -> float:
	return 1.0 - smoothstep(14.0, 185.0, dz)


## Side hinterland beyond the valley hills. Depending on the biome: forested hills and mountains with rocky peaks,
## or (desert) endless dunes with occasional mesas. Gradually gets higher towards the outside,
## height and shape vary on a large scale so nothing repeats.
func _hinterland(x: float, z: float, d: float, wx: float, wz: float, hill: float, rdg: float, vw: float, r: Dictionary) -> float:
	var dunes: float = r["dunes"]
	var out := 0.0
	if dunes < 1.0:
		var t := smoothstep(vw + 25.0, 300.0, d)
		if t > 0.0:
			var fh: float = r["far_h"]
			# large landforms: a mountain massif here, an open side valley there
			var big := smoothstep(-0.5, 0.55, _far.get_noise_2d(x, z))
			var mass := t * fh * (0.15 + 1.1 * big)
			out += (mass * (0.55 + 0.45 * hill) + rdg * fh * 0.45 * t * big) * (1.0 - dunes)
	if dunes > 0.0:
		# dune crests across the wind, higher towards the edge; only flat waves near the path
		var u := x * 0.94 + z * 0.34
		var v := -x * 0.34 + z * 0.94
		var dn := 1.0 - absf(_dune.get_noise_2d(u + _warp.get_noise_2d(x, z) * 30.0, v * 0.3))
		dn *= dn
		var near := smoothstep(r["half_w"] + 3.0, r["half_w"] + 30.0, d)
		var td := smoothstep(20.0, 260.0, d)
		var dune_h := near * (1.2 + 9.0 * td) * dn * (0.55 + 0.45 * hill) + td * 6.0
		# mesas: flat tops with steep sandstone walls and scree slopes at the foot
		var mn := _mesa.get_noise_2d(wx, wz)
		var mm := smoothstep(70.0, 120.0, d)
		var mesa := mm * (22.0 + 20.0 * (_far.get_noise_2d(x, z) * 0.5 + 0.5)) \
			* (0.72 * smoothstep(0.4, 0.46, mn) + 0.28 * smoothstep(0.22, 0.42, mn))
		out += maxf(dune_h, mesa) * dunes
	return out


## Height change from cliffs. off = distance to the path center (signed)
func cliff_delta(off: float, z: float, cliffs: Array, x := 0.0) -> float:
	var d := 0.0
	for c in cliffs:
		d += _cliff_term(z, c, off, x)
	return d


func _cliff_term(z: float, c: Dictionary, off: float, x: float) -> float:
	var side: float = c["side"]
	# opposite the pool (side -side) the step turns into a walkable ramp further out
	var span := lerpf(2.2, 46.0, smoothstep(12.0, 30.0, -off * side))
	var edge: float = c["z"] + _paint.get_noise_1d(x * 0.9 + c["z"]) * 1.2
	# above the edge (z > edge) lies a plateau that the path climbs up to beforehand
	var above := smoothstep(edge - span * 0.5, edge + span * 0.5, z)
	var approach := 1.0 - smoothstep(c["z"] + 45.0, c["z"] + 290.0, z)
	return c["drop"] * above * approach


func height(x: float, z: float) -> float:
	return height_in_row(x, row(z))


func region(x: float, z: float) -> float:
	return _region.get_noise_2d(x, z) * 0.5 + 0.5


func paint(x: float, z: float) -> float:
	return _paint.get_noise_2d(x, z) * 0.5 + 0.5


## Base ground color (without path). slope = 1 - normal.y, rel_h = height above the path
func ground_color(x: float, z: float, r: Dictionary, slope: float, rel_h := 0.0) -> Color:
	var t: float = r["t"]
	var c := _ground_color_for(r["a"], x, z, slope, rel_h)
	if t > 0.001:
		c = c.lerp(_ground_color_for(r["b"], x, z, slope, rel_h), t)
	return c


func _ground_color_for(tr: Dictionary, x: float, z: float, slope: float, rel_h: float) -> Color:
	var n := paint(x, z)
	var g := smoothstep(0.3, 0.72, n)
	var col: Color = (tr["grass_dark"] as Color).lerp(tr["grass_light"], g)
	var reg := smoothstep(0.45, 0.7, region(x, z))
	if reg > 0.0:
		var rc: Color = (tr["region_dark"] as Color).lerp(tr["region_light"], g)
		col = col.lerp(rc, reg)
	var s := smoothstep(0.3, 0.6, slope + (n - 0.5) * 0.25)
	col = col.lerp(tr["slope_color"], s)
	var snow: float = tr["snow"]
	if snow > 0.0:
		var sn := smoothstep(snow, snow + 7.0, rel_h + (n - 0.5) * 8.0) * (1.0 - smoothstep(0.55, 0.85, slope))
		col = col.lerp(tr["snow_color"], sn)
	return col


## What the ground at a point is made of (footprints, dust, step sounds): snow, sand, path or grass
func ground_kind(x: float, z: float) -> String:
	var r := row(z, false)
	var tr: Dictionary = r["a"] if r["t"] < 0.5 else r["b"]
	var snow: float = tr["snow"]
	if snow > 0.0:
		var rel_h := height_in_row(x, r) - float(r["elev"])
		if rel_h + (paint(x, z) - 0.5) * 8.0 > snow + 3.5:
			return "snow"
	if lerpf(r["a"]["ripple"], r["b"]["ripple"], r["t"]) > 0.3:
		return "sand"
	if path_value(offset_in_row(x, r), r["half_w"]) > 0.45:
		return "path"
	return "grass"


# ================================================================ Arc length (main thread)

## Distance walked along the path from z = 0 to z (meters, forward is positive)
func arc_length(z: float) -> float:
	var d := -z
	if d <= 0.0:
		return d
	var need := int(ceil(d / ARC_STEP)) + 1
	if _arc.is_empty():
		_arc.append(0.0)
	while _arc.size() <= need:
		var i := _arc.size()
		var z0 := -(i - 1) * ARC_STEP
		var z1 := -i * ARC_STEP
		var dx := path_x(z1) - path_x(z0)
		var dy := path_elevation(z1) - path_elevation(z0)
		_arc.append(_arc[i - 1] + sqrt(ARC_STEP * ARC_STEP + dx * dx + dy * dy))
	var f := d / ARC_STEP
	var j := int(f)
	return lerpf(_arc[j], _arc[j + 1], f - j)


## Point on the path (world coordinates, including height)
func path_point(z: float) -> Vector3:
	var x := path_x(z)
	return Vector3(x, height(x, z), z)
