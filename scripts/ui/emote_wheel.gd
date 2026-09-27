class_name EmoteWheel
extends CanvasLayer
## Radial emote menu: hold G, move the mouse towards a slot (no cursor needed), release to play.
## Keys 1–8 pick a slot directly while the wheel is open.

signal chosen(id: String)

const RADIUS := 200.0
const INNER := 74.0
const SLOTS := 8

var _root: Control
var _open := false
var _aim := Vector2.ZERO
var _sel := -1
var _ids: Array = []
var _icons: Array[Texture2D] = []
var _anim := 0.0


func _ready() -> void:
	layer = 12
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_wheel)
	add_child(_root)
	_root.visible = false
	reload()


## Re-read the slots from the settings
func reload() -> void:
	var w: Array = Settings.values.get("emote_wheel", [])
	_ids = w.duplicate() if w.size() == SLOTS else Scout.DEFAULT_WHEEL.duplicate()
	_icons.clear()
	for id in _ids:
		var path := "res://assets/emotes/%s.png" % id
		_icons.append(load(path) if ResourceLoader.exists(path) else null)


func is_open() -> bool:
	return _open


func open() -> void:
	reload()
	_open = true
	_aim = Vector2.ZERO
	_sel = -1
	_anim = 0.0
	_root.visible = true


## Closes the wheel; plays the selected emote unless cancelled
func close(play := true) -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if play and _sel >= 0:
		chosen.emit(_ids[_sel])


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		# the mouse steers the selection, the camera stays still
		_aim = (_aim + event.relative * 0.9).limit_length(RADIUS)
		_sel = int(fposmod(atan2(_aim.x, -_aim.y) + PI / SLOTS, TAU) / (TAU / SLOTS)) if _aim.length() > 28.0 else -1
		get_viewport().set_input_as_handled()
		_root.queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < SLOTS:
			_sel = n
			get_viewport().set_input_as_handled()
			close(true)
		elif event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		close(true)


func _process(delta: float) -> void:
	if _open:
		_anim = minf(_anim + delta * 6.0, 1.0)
		_root.queue_redraw()


func _draw_wheel() -> void:
	var c := _root.size * 0.5
	var ease := 1.0 - pow(1.0 - _anim, 3.0)
	var r := RADIUS * (0.85 + 0.15 * ease)
	var ink := Color(0.13, 0.17, 0.12, 0.62 * ease)
	var line := Color(0.98, 0.96, 0.9, 0.85 * ease)
	# ring
	_arc_fill(c, INNER, r, 0.0, TAU, ink)
	# highlighted wedge
	if _sel >= 0:
		var a0 := -PI * 0.5 + (_sel - 0.5) * TAU / SLOTS
		_arc_fill(c, INNER + 4.0, r - 4.0, a0, a0 + TAU / SLOTS, Color(0.95, 0.76, 0.19, 0.85 * ease))
	# separators and outlines (slightly hand-drawn: doubled lines)
	for i in SLOTS:
		var a := -PI * 0.5 + (i - 0.5) * TAU / SLOTS
		var d := Vector2(cos(a), sin(a))
		_root.draw_line(c + d * (INNER + 6.0), c + d * (r - 6.0), Color(line, 0.35 * ease), 2.0, true)
	_root.draw_arc(c, r, 0.0, TAU, 96, line, 3.0, true)
	_root.draw_arc(c, INNER, 0.0, TAU, 64, line, 3.0, true)
	# icons and numbers
	var font := UiTheme.DISPLAY_FONT
	for i in _ids.size():
		var a := -PI * 0.5 + i * TAU / SLOTS
		var p := c + Vector2(cos(a), sin(a)) * (INNER + r) * 0.5
		var s := 92.0 * (1.12 if i == _sel else 1.0) * ease
		if _icons[i]:
			_root.draw_texture_rect(_icons[i], Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		_root.draw_string(font, p + Vector2(-5, s * 0.5 + 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(line, 0.8 * ease))
	# name in the middle
	var text := "Emotes" if _sel < 0 else String(Scout.EMOTES[_ids[_sel]][0])
	var size := 26 if _sel >= 0 else 22
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_root.draw_string_outline(font, c + Vector2(-tw * 0.5, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.1, 0.13, 0.09, ease))
	_root.draw_string(font, c + Vector2(-tw * 0.5, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.95, 0.75, ease))


func _arc_fill(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	var n := maxi(int((a1 - a0) / TAU * 96.0), 6)
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for i in range(n, -1, -1):
		var a := a0 + (a1 - a0) * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r0)
	_root.draw_colored_polygon(pts, col)
