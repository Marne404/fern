class_name KnotGame
extends CanvasLayer
## Knot minigame: enter an arrow sequence, the rope is visibly guided along.
## The result is a knot quality (0..1), not a matter of right/wrong.
## Without the field guide you only see the sequence briefly at the start.

signal finished(quality: float)   # -1 = cancelled

const KNOTS := [
	{"name": "Overhand knot", "seq": ["up", "right", "down"], "base": 0.35, "time": 5.0, "stars": "★"},
	{"name": "Bowline", "seq": ["up", "right", "down", "left", "up"], "base": 0.85, "time": 9.0, "stars": "★★★"},
	{"name": "Double figure-eight", "seq": ["up", "right", "down", "right", "up", "left", "down"], "base": 0.98, "time": 14.0, "stars": "★★★★"},
]
const ARROWS := {"up": "↑", "down": "↓", "left": "←", "right": "→"}
const DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}

var has_book := false
var _root: Control
var _title: Label
var _seq_label: Label
var _info: Label
var _rope: Line2D
var _other: Line2D
var _knot := -1
var _pos := 0
var _mistakes := 0
var _time := 0.0
var _show_until := 0.0
var _active := false


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	_title.add_theme_color_override("font_color", UiTheme.SUN)
	_title.add_theme_color_override("font_outline_color", UiTheme.INK)
	_title.add_theme_constant_override("outline_size", 8)
	box.add_child(_title)
	_seq_label = Label.new()
	_seq_label.add_theme_font_size_override("font_size", 40)
	_seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_seq_label)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(560, 280)
	box.add_child(canvas)
	_other = Line2D.new()
	_other.width = 14
	_other.default_color = Color(0.7, 0.58, 0.36)
	_other.points = PackedVector2Array([Vector2(40, 200), Vector2(520, 200)])
	canvas.add_child(_other)
	_rope = Line2D.new()
	_rope.width = 14
	_rope.default_color = Color(0.9, 0.78, 0.5)
	_rope.joint_mode = Line2D.LINE_JOINT_ROUND
	_rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	canvas.add_child(_rope)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)


func is_open() -> bool:
	return _root.visible


func start(book: bool) -> void:
	has_book = book
	_knot = -1
	_active = true
	_root.visible = true
	_title.text = "Which knot?"
	_seq_label.text = ""
	_rope.points = PackedVector2Array()
	var lines := []
	for i in KNOTS.size():
		var k: Dictionary = KNOTS[i]
		lines.append("%d  %s  %s  (holds up to %d %%)" % [i + 1, k["name"], k["stars"], roundi(k["base"] * 100)])
	_info.text = "\n".join(lines) + "\n\nEsc cancels." + ("" if has_book else "\nWithout the field guide you only see the steps briefly!")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not _active or _knot < 0:
		return
	_time += delta
	if not has_book and _time > _show_until:
		var seq: Array = KNOTS[_knot]["seq"]
		var shown := ""
		for i in seq.size():
			shown += (ARROWS[seq[i]] if i < _pos else "?") + " "
		_seq_label.text = shown


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		_end(-1.0)
		return
	if _knot < 0:
		if key >= KEY_1 and key <= KEY_3:
			_choose(key - KEY_1)
		return
	var dir := ""
	match key:
		KEY_UP, KEY_W: dir = "up"
		KEY_DOWN, KEY_S: dir = "down"
		KEY_LEFT, KEY_A: dir = "left"
		KEY_RIGHT, KEY_D: dir = "right"
	if dir == "":
		return
	var seq: Array = KNOTS[_knot]["seq"]
	if dir == seq[_pos]:
		_pos += 1
		var last: Vector2 = _rope.points[_rope.points.size() - 1]
		# the rope is visibly guided in the direction, small loop like a real knot
		var step: Vector2 = DIRS[dir] * 42.0
		_rope.add_point(last + step * 0.5 + Vector2(step.y, -step.x) * 0.25)
		_rope.add_point(last + step)
		_refresh_seq()
		if _pos >= seq.size():
			var k: Dictionary = KNOTS[_knot]
			var q: float = k["base"] * maxf(1.0 - 0.18 * _mistakes, 0.1)
			if _time > k["time"] * 1.5:
				q *= 0.8
			_title.text = "Done: %s – quality %d %%" % [k["name"], roundi(q * 100)]
			_active = false
			await get_tree().create_timer(1.0, true).timeout
			_end(clampf(q, 0.05, 0.99))
	else:
		_mistakes += 1
		_title.text = "%s – wrong way round! (%d mistakes)" % [KNOTS[_knot]["name"], _mistakes]
		var tw := create_tween()
		tw.tween_property(_rope, "position", Vector2(8, 0), 0.05)
		tw.tween_property(_rope, "position", Vector2(-8, 0), 0.05)
		tw.tween_property(_rope, "position", Vector2.ZERO, 0.05)


func _choose(i: int) -> void:
	_knot = i
	_pos = 0
	_mistakes = 0
	_time = 0.0
	_show_until = 2.2
	_title.text = KNOTS[i]["name"]
	_rope.points = PackedVector2Array([Vector2(140, 200)])
	_info.text = "Arrow keys (or WASD) in the right order." + \
		("\nThe field guide lies open next to you." if has_book else "\nMemorize the sequence – it'll be gone in a moment!")
	_refresh_seq()


func _refresh_seq() -> void:
	var seq: Array = KNOTS[_knot]["seq"]
	var shown := ""
	for i in seq.size():
		shown += ARROWS[seq[i]] + " "
	if has_book or _time <= _show_until:
		_seq_label.text = shown


func _end(q: float) -> void:
	_active = false
	_root.visible = false
	finished.emit(q)
