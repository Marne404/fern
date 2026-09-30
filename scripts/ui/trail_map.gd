class_name TrailMap
extends Control
## What the map and the compass show while you hold them.
## Map: a paper map of the trail ahead (1.8 km, the way ahead points up) with obstacles, rest spots, landmarks and
## the biomes' borders. Compass: a ribbon at the top with the directions and a flag where the trail goes.

const AHEAD := 1800.0
const MAP_SIZE := Vector2(430, 330)

var show_map := false
var show_compass := false
var _gen: WorldGen
var _pos := Vector3.ZERO        # world position of the hiker
var _yaw := 0.0                 # camera yaw (radians, 0 = north = -Z)
var _trail_yaw := 0.0
var _heading := Vector2(0, -1)  # map up direction in world xz
var _path := PackedVector2Array()
var _marks: Array = []          # [world xz, kind, label]
var _borders: Array = []        # [world xz, name]
var _poi_cache := {}
var _lm_cache := {}
var _t := 0.0
var _anim := 0.0
var _canim := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_view(gen: WorldGen, world_pos: Vector3, cam_yaw: float, map_on: bool, compass_on: bool, delta: float) -> void:
	_gen = gen
	_pos = world_pos
	_yaw = cam_yaw
	show_map = map_on
	show_compass = compass_on
	_anim = move_toward(_anim, 1.0 if map_on else 0.0, delta * 4.0)
	_canim = move_toward(_canim, 1.0 if compass_on else 0.0, delta * 5.0)
	visible = _anim > 0.0 or _canim > 0.0
	if not visible:
		return
	var a := _gen.path_point(_pos.z - 30.0) - _gen.path_point(_pos.z)
	_trail_yaw = atan2(-a.x, -a.z)
	_t -= delta
	if _t <= 0.0 and _anim > 0.0:
		_t = 0.5
		_rebuild()
	queue_redraw()


func _rebuild() -> void:
	var z0 := _pos.z
	var far := _gen.path_point(z0 - 400.0)
	var h := Vector2(far.x - _pos.x, far.z - _pos.z)
	_heading = h.normalized() if h.length() > 1.0 else Vector2(0, -1)
	_path.clear()
	var d := -60.0
	while d <= AHEAD:
		var p := _gen.path_point(z0 - d)
		_path.append(Vector2(p.x, p.z))
		d += 20.0
	_marks.clear()
	var seen := {}
	for probe in range(0, int(AHEAD) + 600, 600):
		for o in _gen.obstacles_near(z0 - probe):
			if seen.has(o["k"]) or o["z"] > z0 + 20.0 or o["z"] < z0 - AHEAD:
				continue
			seen[o["k"]] = true
			var op := _gen.path_point(o["z"])
			_marks.append([Vector2(op.x, op.z), "ob_" + str(o["type"]), ""])
	var k0 := floori(-z0 / PoiManager.CELL)
	for k in range(k0, k0 + int(AHEAD / PoiManager.CELL) + 2):
		if not _poi_cache.has(k):
			_poi_cache[k] = PoiManager.plan(_gen, k)
		var pl: Dictionary = _poi_cache[k]
		if pl.is_empty() or pl["z"] > z0 + 20.0:
			continue
		if pl["type"] in ["bank", "quelle", "lagerfeuer", "unterstand", "picknick", "schild"]:
			_marks.append([Vector2(pl["x"], pl["z"]), pl["type"], ""])
	var l0 := floori(-z0 / LandmarkManager.CELL)
	for k in range(l0, l0 + int(AHEAD / LandmarkManager.CELL) + 2):
		if not _lm_cache.has(k):
			_lm_cache[k] = LandmarkManager.plan(_gen, k)
		var lm: Dictionary = _lm_cache[k]
		if lm.is_empty() or lm["z"] > z0 + 20.0:
			continue
		_marks.append([Vector2(lm["x"], lm["z"]), "landmark", ""])
	_borders.clear()
	var ks := _gen.segment_at(-z0)
	for k in range(ks + 1, ks + 4):
		var s := _gen.segment_start(k)
		if s > -z0 + AHEAD:
			break
		var bp := _gen.path_point(-s)
		_borders.append([Vector2(bp.x, bp.z), _gen.biomes[_gen.segment_biome(k)]["name"]])


## world xz -> map point (you at the bottom middle, the way ahead up)
func _to_map(w: Vector2, origin: Vector2, scale: float) -> Vector2:
	var rel := w - Vector2(_pos.x, _pos.z)
	var up := _heading
	var right := Vector2(-up.y, up.x)
	return origin + Vector2(rel.dot(right), -rel.dot(up)) * scale


func _draw() -> void:
	if _gen == null:
		return
	if _anim > 0.0:
		_draw_map()
	if _canim > 0.0:
		_draw_compass()


func _draw_map() -> void:
	var e := 1.0 - pow(1.0 - _anim, 3.0)
	var sz := MAP_SIZE
	var vs := get_viewport_rect().size
	var at := Vector2(vs.x * 0.5 - sz.x * 0.5, vs.y - sz.y - 40.0 + (1.0 - e) * (sz.y + 60.0))
	var ink := Color(0.25, 0.2, 0.15, 0.9 * e)
	var paper := Color(0.96, 0.91, 0.78, 0.96 * e)
	# the sheet, a little crooked, with a folded crease
	draw_set_transform(at + sz * 0.5, -0.02, Vector2.ONE)
	var r := Rect2(-sz * 0.5, sz)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.25 * e))
	draw_rect(r, paper)
	draw_line(Vector2(0, -sz.y * 0.5), Vector2(0, sz.y * 0.5), Color(0.8, 0.72, 0.55, 0.6 * e), 2.0)
	draw_rect(r, ink, false, 3.0)
	var origin := Vector2(0, sz.y * 0.5 - 30.0)
	var scale := (sz.y - 60.0) / AHEAD
	var font: Font = UiTheme.BODY_FILE
	var clip := Rect2(-sz * 0.5 + Vector2(8, 8), sz - Vector2(16, 16))
	# biome borders: a dotted line across and the name
	for b in _borders:
		var p := _to_map(b[0], origin, scale)
		if not clip.has_point(p):
			continue
		for x in range(int(-sz.x * 0.5 + 14.0), int(sz.x * 0.5 - 14.0), 12):
			draw_line(Vector2(x, p.y), Vector2(x + 6, p.y), Color(0.45, 0.55, 0.3, 0.7 * e), 2.0)
		draw_string(font, Vector2(-sz.x * 0.5 + 16.0, p.y - 5.0), String(b[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.42, 0.2, e))
	# the trail: a dashed brown line
	var prev := Vector2.INF
	var i := 0
	for w in _path:
		var p := _to_map(w, origin, scale)
		if prev != Vector2.INF and clip.has_point(p) and clip.has_point(prev) and i % 2 == 0:
			draw_line(prev, p, Color(0.62, 0.38, 0.18, e), 4.0, true)
		prev = p
		i += 1
	# marks
	for m in _marks:
		var p := _to_map(m[0], origin, scale)
		if clip.has_point(p):
			_icon(p, m[1], e)
	# distance ticks
	for km: float in [0.5, 1.0, 1.5]:
		var y := origin.y - km * 1000.0 * scale
		draw_string(font, Vector2(sz.x * 0.5 - 52.0, y + 4.0), ("%.1f km" % km) if km != 1.0 else "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.6 * e))
		draw_line(Vector2(sz.x * 0.5 - 60.0, y), Vector2(sz.x * 0.5 - 54.0, y), Color(ink, 0.6 * e), 2.0)
	# you: a red arrow
	var tip := origin + Vector2(0, -12)
	draw_colored_polygon(PackedVector2Array([tip, origin + Vector2(-8, 6), origin + Vector2(0, 1), origin + Vector2(8, 6)]), Color(0.85, 0.2, 0.18, e))
	draw_string(font, Vector2(-sz.x * 0.5 + 14.0, -sz.y * 0.5 + 24.0), "Trail map", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _icon(p: Vector2, kind: String, e: float) -> void:
	var ink := Color(0.25, 0.2, 0.15, 0.9 * e)
	match kind:
		"ob_river":
			for k in 3:
				var y := p.y - 5.0 + k * 5.0
				draw_polyline(PackedVector2Array([p + Vector2(-12, y - p.y), p + Vector2(-6, y - p.y - 3), p + Vector2(0, y - p.y), p + Vector2(6, y - p.y - 3), p + Vector2(12, y - p.y)]), Color(0.25, 0.5, 0.85, e), 2.5, true)
		"ob_fallen_tree":
			draw_line(p + Vector2(-12, 3), p + Vector2(12, -3), Color(0.45, 0.28, 0.15, e), 5.0, true)
		"ob_cliff":
			draw_polyline(PackedVector2Array([p + Vector2(-12, 6), p + Vector2(-4, -6), p + Vector2(4, 2), p + Vector2(12, -8)]), ink, 3.0, true)
		"ob_stile":
			draw_line(p + Vector2(-10, 0), p + Vector2(10, 0), ink, 3.0)
			for x in [-8.0, 0.0, 8.0]:
				draw_line(p + Vector2(x, -6), p + Vector2(x, 6), ink, 2.0)
		"ob_mud":
			draw_circle(p, 8.0, Color(0.45, 0.32, 0.2, 0.8 * e))
		"ob_boulders":
			for o in [Vector2(-6, 2), Vector2(4, -3), Vector2(5, 5)]:
				draw_circle(p + o, 5.0, Color(0.55, 0.55, 0.55, e))
				draw_arc(p + o, 5.0, 0, TAU, 12, ink, 1.5)
		"bank":
			draw_line(p + Vector2(-7, 0), p + Vector2(7, 0), Color(0.55, 0.35, 0.18, e), 4.0)
			draw_line(p + Vector2(-5, 0), p + Vector2(-5, 5), ink, 2.0)
			draw_line(p + Vector2(5, 0), p + Vector2(5, 5), ink, 2.0)
		"quelle":
			draw_circle(p, 5.0, Color(0.3, 0.6, 0.95, e))
		"lagerfeuer":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 4), p + Vector2(-5, 4)]), Color(0.95, 0.5, 0.15, e))
		"unterstand":
			draw_polyline(PackedVector2Array([p + Vector2(-8, 5), p + Vector2(-8, -1), p + Vector2(0, -8), p + Vector2(8, -1), p + Vector2(8, 5)]), ink, 2.5, true)
		"picknick":
			draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), Color(0.85, 0.25, 0.2, 0.85 * e))
		"schild":
			draw_line(p + Vector2(0, 6), p + Vector2(0, -6), ink, 2.0)
			draw_line(p + Vector2(0, -5), p + Vector2(7, -5), ink, 3.0)
		"landmark":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(2.5, -2.5), p + Vector2(8, -2), p + Vector2(3.5, 2), p + Vector2(5, 8), p + Vector2(0, 4.5), p + Vector2(-5, 8), p + Vector2(-3.5, 2), p + Vector2(-8, -2), p + Vector2(-2.5, -2.5)]), Color(0.95, 0.75, 0.2, e))
			draw_polyline(PackedVector2Array([p + Vector2(0, -8), p + Vector2(2.5, -2.5), p + Vector2(8, -2), p + Vector2(3.5, 2), p + Vector2(5, 8), p + Vector2(0, 4.5), p + Vector2(-5, 8), p + Vector2(-3.5, 2), p + Vector2(-8, -2), p + Vector2(-2.5, -2.5), p + Vector2(0, -8)]), ink, 1.5, true)


func _draw_compass() -> void:
	var e := 1.0 - pow(1.0 - _canim, 3.0)
	var w := 520.0
	var c := Vector2(get_viewport_rect().size.x * 0.5, 96.0 - (1.0 - e) * 130.0)
	var ink := Color(0.25, 0.2, 0.15, 0.95)
	draw_rect(Rect2(c - Vector2(w * 0.5 + 6, 22), Vector2(w + 12, 44)), Color(0, 0, 0, 0.2 * e))
	draw_rect(Rect2(c - Vector2(w * 0.5, 24), Vector2(w, 44)), Color(0.96, 0.91, 0.78, 0.95 * e))
	draw_rect(Rect2(c - Vector2(w * 0.5, 24), Vector2(w, 44)), Color(ink, e), false, 3.0)
	var font: Font = UiTheme.DISPLAY_FONT
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var px_per_rad := w / (PI * 1.1)
	for i in 8:
		# yaw of direction i: north = 0, east = -PI/2 (camera yaw turns left positive)
		var d := angle_difference(_yaw, -i * TAU / 8.0)
		var x := -d * px_per_rad
		if absf(x) > w * 0.5 - 16.0:
			continue
		var big := i % 2 == 0
		var txt: String = names[i]
		var fs := 20 if big else 14
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(x - tw * 0.5, 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.2, 0.18, e) if i == 0 else Color(ink, e))
	for k in 36:
		var d := angle_difference(_yaw, -k * TAU / 36.0)
		var x := -d * px_per_rad
		if absf(x) < w * 0.5 - 6.0 and k % 9 != 0:
			draw_line(c + Vector2(x, 14), c + Vector2(x, 19), Color(ink, 0.5 * e), 1.5)
	# where the trail goes
	var td := angle_difference(_yaw, _trail_yaw)
	var tx := clampf(-td * px_per_rad, -w * 0.5 + 10.0, w * 0.5 - 10.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(tx, -14), c + Vector2(tx - 6, -24), c + Vector2(tx + 6, -24)]), Color(0.35, 0.6, 0.25, e))
	draw_line(c + Vector2(0, -22), c + Vector2(0, 22), Color(0.85, 0.2, 0.18, 0.5 * e), 2.0)
