class_name StaminaBar
extends Control
## PEAK-style stamina bar: rounded, hand-drawn outline, current stamina in front, hatched segments at the end
## for everything that lowers the maximum (hunger, thirst, tiredness, cold/heat, injury) with tiny icons
## above them; active effects as small chips below; state shouts above the bar.

const W := 470.0
const H := 24.0
const LINE := Color(0.98, 0.96, 0.9, 0.92)
const BG := Color(0.12, 0.15, 0.11, 0.5)
const FILL := [Color("7ccf3a"), Color("f2c230"), Color("ec8a34"), Color("d1493f")]
const CAUSES := {
	"food": [Color("e9a23b"), "hunger"], "water": [Color("58a6e0"), "thirst"], "rest": [Color("9c86c9"), "tired"],
	"cold": [Color("9fd6f0"), "cold"], "hot": [Color("f07a3a"), "hot"], "health": [Color("d8453e"), "injury"],
}

var body: Body
var player: Wanderer
## Words like "Hungry", shown after the effect chips
var needs: Array[String] = []
var _shown := 0.0
var _max_shown := 100.0
var _shout := ""
var _shout_t := 0.0
var _last_state := 0
var _alpha := 0.7
## Colors of outline and background (the backpack shows the bar on paper)
var line := LINE
var bg := BG
## false: only the bar (no chips, needs or shouts), always fully visible
var hud := true


func _init() -> void:
	custom_minimum_size = Vector2(W + 20, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Short big text above the bar (display font), e.g. "EXHAUSTED!"
func shout(text: String) -> void:
	_shout = text
	_shout_t = 2.6


func _process(delta: float) -> void:
	if body == null:
		return
	_shown = lerpf(_shown, body.stamina, 1.0 - exp(-10.0 * delta))
	_max_shown = lerpf(_max_shown, body.max_stamina(), 1.0 - exp(-4.0 * delta))
	if body.state != _last_state:
		if body.state > _last_state:
			shout(["", "EXHAUSTED!", "WEAK!", "COLLAPSED!"][body.state])
		elif body.state == Body.State.FIT:
			shout("BACK ON YOUR FEET!")
		_last_state = body.state
	_shout_t = maxf(_shout_t - delta, 0.0)
	if not hud:
		_alpha = 1.0
		queue_redraw()
		return
	var busy := body.stamina < body.max_stamina() - 1.0 or body.state != Body.State.FIT or _max_shown < 97.0
	_alpha = move_toward(_alpha, 1.0 if busy else 0.55, delta * 1.5)
	queue_redraw()


## Shares of the lost maximum: -ln(factor) of each cause, normalized
func _causes() -> Array:
	var f := {
		"food": body._factor(body.food, 25.0),
		"water": body._factor(body.water, 25.0),
		"rest": body._factor(body.rest, 20.0),
		"health": lerpf(0.55, 1.0, body.health / 100.0),
	}
	var comfort := 1.0 - body.comfort_penalty() * 0.45
	f["cold" if body.feel_temp < 20.0 else "hot"] = comfort
	var out := []
	var total := 0.0
	for k in f:
		var v: float = -log(maxf(f[k], 0.001))
		if v > 0.001:
			out.append([k, v])
			total += v
	for o in out:
		o[1] /= maxf(total, 1e-6)
	return out


func _draw() -> void:
	if body == null:
		return
	var a := _alpha
	var o := Vector2(10, size.y - H - 40) if hud else Vector2(4, size.y - H - 4)
	var bw := W if hud else size.x - 8.0
	var r := Rect2(o, Vector2(bw, H))
	# background
	_round_rect(r, bg * Color(1, 1, 1, a), H * 0.5)
	# hatched max-stamina losses at the right end
	var lost := clampf(100.0 - _max_shown, 0.0, 100.0)
	var x_end := o.x + bw
	var causes := _causes()
	var seg_x := x_end - bw * lost / 100.0
	var x := seg_x
	var icons := []
	for c in causes:
		var w: float = bw * lost / 100.0 * c[1]
		if w < 1.0:
			continue
		var col: Color = CAUSES[c[0]][0]
		_hatch(Rect2(Vector2(x, o.y + 3), Vector2(w, H - 6)), Color(col, 0.9 * a))
		icons.append([x + w * 0.5, c[0]])
		x += w
	# current stamina
	var fw := clampf(bw * _shown / 100.0, 0.0, seg_x - o.x)
	if fw > 2.0:
		var col: Color = FILL[body.state]
		_round_rect(Rect2(o + Vector2(3, 3), Vector2(maxf(fw - 6.0, 4.0), H - 6)), Color(col, a), (H - 6) * 0.5)
		draw_line(o + Vector2(10, 7), o + Vector2(maxf(fw - 10.0, 10.0), 7), Color(1, 1, 1, 0.3 * a), 2.0, true)
	# hand-drawn outline: two slightly offset strokes
	_round_outline(r, Color(line, a), H * 0.5, 2.5)
	_round_outline(r.grow(1.0), Color(line, 0.25 * a), H * 0.5 + 1.0, 1.5)
	# icons over the segments
	for ic in icons:
		draw_set_transform(Vector2(ic[0], o.y - 15), 0.0, Vector2(1.3, 1.3))
		draw_icon(self, ic[1], Vector2.ZERO, a)
		draw_set_transform(Vector2.ZERO)
	if not hud:
		return
	# active effects as chips below the bar
	var chips := _effects()
	var cx := o.x + 12.0
	for ch in chips:
		var c := Vector2(cx, o.y + H + 18)
		draw_circle(c, 13.0, Color(bg, 0.7 * a))
		draw_arc(c, 13.0, 0.0, TAU, 28, Color(line, 0.8 * a), 2.0, true)
		draw_icon(self, ch, c, a)
		cx += 32.0
	if not needs.is_empty():
		var f := UiTheme.body(800)
		var t := "  ·  ".join(needs)
		var p0 := Vector2(cx - 8.0 if chips.size() > 0 else o.x + 4.0, o.y + H + 24)
		draw_string_outline(f, p0, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(UiTheme.INK, 0.7 * a))
		draw_string(f, p0, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.89, 0.66, a))
	# state shout
	if _shout_t > 0.0:
		var font := UiTheme.DISPLAY_FONT
		var k := minf(_shout_t / 0.3, 1.0) * minf((2.6 - _shout_t) / 0.15, 1.0)
		var sz := 36
		var col2: Color = FILL[mini(body.state, 3)] if body.state > 0 else FILL[0]
		var p := o + Vector2(4, -34)
		draw_string_outline(font, p, _shout, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 7, Color(UiTheme.INK, k))
		draw_string(font, p, _shout, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col2, k))


func _effects() -> Array:
	var out := []
	if body.warm_bonus_t > 0.0:
		out.append("warm")
	if body.heat_protect_t > 0.0:
		out.append("sun")
	if body.rest_bonus > 1.0:
		out.append("music")
	if body.climb_factor < 1.0:
		out.append("boot")
	if body.wet > 0.3:
		out.append("wet")
	if player and player.inventory.total_weight() > Inventory.COMFORT_WEIGHT:
		out.append("heavy")
	return out


# ---------------------------------------------------------------- drawing helpers

func _round_rect(r: Rect2, col: Color, rad: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _round_outline(r: Rect2, col: Color, rad: float, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _hatch(r: Rect2, col: Color) -> void:
	draw_rect(r, Color(col, col.a * 0.35), true)
	var step := 7.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(maxf(x, r.position.x), r.position.y + maxf(r.position.x - x, 0.0))
		var bx := x + r.size.y
		var b := Vector2(minf(bx, r.end.x), r.end.y - maxf(bx - r.end.x, 0.0))
		if b.x > a.x:
			draw_line(Vector2(a.x, r.end.y - (a.y - r.position.y)), Vector2(b.x, r.end.y - (b.y - r.position.y)), col, 3.0, true)
		x += step


## Tiny icons drawn with primitives, centered at c (also used by the backpack)
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, a: float, ink := LINE) -> void:
	ink = Color(ink, a)
	match kind:
		"food":
			ci.draw_circle(c + Vector2(-2, -2), 5.5, Color("e9a23b", a))
			ci.draw_line(c + Vector2(2, 2), c + Vector2(7, 7), ink, 2.5, true)
			ci.draw_circle(c + Vector2(7, 7), 2.0, ink)
		"water", "wet":
			var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(5, 1), c + Vector2(0, 6), c + Vector2(-5, 1)])
			ci.draw_colored_polygon(pts, Color("58a6e0", a))
			ci.draw_circle(c + Vector2(0, 1.5), 5.0, Color("58a6e0", a))
		"rest":
			ci.draw_arc(c, 5.0, deg_to_rad(20.0), deg_to_rad(250.0), 16, Color("c9b8f0", a), 4.0, true)
		"cold":
			for i in 3:
				var d := Vector2.from_angle(i * PI / 3.0) * 7.0
				ci.draw_line(c - d, c + d, Color("bfe6fb", a), 2.0, true)
		"hot", "sun":
			ci.draw_circle(c, 4.5, Color("f2c230", a))
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(c + d * 6.5, c + d * 9.0, Color("f2c230", a), 2.0, true)
		"health":
			ci.draw_circle(c + Vector2(-3, -2), 3.8, Color("d8453e", a))
			ci.draw_circle(c + Vector2(3, -2), 3.8, Color("d8453e", a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6.5, -1), c + Vector2(6.5, -1), c + Vector2(0, 7)]), Color("d8453e", a))
		"warm":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)]), Color("ec8a34", a))
			ci.draw_circle(c + Vector2(0, 1.5), 4.8, Color("ec8a34", a))
			ci.draw_circle(c + Vector2(0, 2.5), 2.2, Color("f2c230", a))
		"music":
			ci.draw_line(c + Vector2(2, -7), c + Vector2(2, 4), ink, 2.0, true)
			ci.draw_line(c + Vector2(2, -7), c + Vector2(6, -5), ink, 2.0, true)
			ci.draw_circle(c + Vector2(-1, 5), 3.2, ink)
		"boot":
			ci.draw_rect(Rect2(c + Vector2(-4, -7), Vector2(6, 10)), Color("8b5a36", a))
			ci.draw_rect(Rect2(c + Vector2(-4, 1), Vector2(10, 5)), Color("8b5a36", a))
		"heavy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(5, -2), c + Vector2(7, 7), c + Vector2(-7, 7)]), ink)
			ci.draw_arc(c + Vector2(0, -4), 3.0, PI, TAU, 10, ink, 2.0, true)
