class_name Hud
extends CanvasLayer
## HUD in the style of PEAK: stamina bar with status segments bottom left, distance top center,
## big biome sticker, center prompt with a keycap, messages as pills, backpack slot bottom right.

var player: Wanderer
var _distance: Label
var _biome_box: VBoxContainer
var _biome_toast: Label
var _biome_sub: Label
var _toast_tween: Tween
var _bar: StaminaBar
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _black: ColorRect
var _message: Label
var _fps: Label
var _hint: Label
var _prompt: HBoxContainer
var _prompt_title: Label
var _prompt_key: PanelContainer
var _prompt_action: Label
var _messages: VBoxContainer
var _pack: PackSlot
var _mic: Control


func _ready() -> void:
	layer = 5
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = preload("res://shaders/exhaustion.gdshader")
	_overlay.material = _overlay_mat
	add_child(_overlay)

	_distance = UiTheme.sticker("0.00 km", 34, UiTheme.CREAM)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_distance.offset_top = 14
	_distance.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_distance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_distance)

	# biome name: big sticker under the distance
	_biome_box = VBoxContainer.new()
	_biome_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_biome_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_biome_box.offset_top = 78
	_biome_box.add_theme_constant_override("separation", -4)
	_biome_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_box.modulate.a = 0.0
	add_child(_biome_box)
	_biome_toast = UiTheme.sticker("", 68, UiTheme.SUN_LIGHT)
	_biome_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_biome_box.add_child(_biome_toast)
	_biome_sub = _label(21, HORIZONTAL_ALIGNMENT_CENTER, 800)
	_biome_box.add_child(_biome_sub)

	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_message = UiTheme.sticker("", 40, UiTheme.CREAM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_preset(Control.PRESET_CENTER)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message.modulate.a = 0.0
	add_child(_message)

	_fps = _label(16, HORIZONTAL_ALIGNMENT_RIGHT, 700)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -260
	_fps.offset_right = -20
	_fps.offset_top = 16
	add_child(_fps)

	# prompt: OBJECT NAME [E] action
	_prompt = HBoxContainer.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 46
	_prompt.add_theme_constant_override("separation", 10)
	_prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_prompt_title = UiTheme.sticker("", 26, UiTheme.CREAM)
	_prompt_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt.add_child(_prompt_title)
	_prompt_key = keycap("E", 19)
	_prompt.add_child(_prompt_key)
	_prompt_action = _label(20, HORIZONTAL_ALIGNMENT_LEFT, 800)
	_prompt.add_child(_prompt_action)
	var dot := _label(22, HORIZONTAL_ALIGNMENT_CENTER, 900)
	dot.text = "·"
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dot.offset_top = -16
	dot.modulate.a = 0.6
	dot.name = "Crosshair"
	add_child(dot)

	_messages = VBoxContainer.new()
	_messages.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_messages.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_messages.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_messages.offset_top = -150
	_messages.offset_bottom = -150
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.add_theme_constant_override("separation", 6)
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_messages)

	# stamina bar bottom left
	_bar = StaminaBar.new()
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 18
	_bar.offset_top = -150
	_bar.offset_right = 18 + StaminaBar.W + 20
	_bar.offset_bottom = -10
	add_child(_bar)

	# microphone badge while you transmit (voice test)
	_mic = MicWidgets.Badge.new()
	_mic.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_mic.offset_left = 26
	_mic.offset_top = -216
	_mic.offset_right = 82
	_mic.offset_bottom = -160
	add_child(_mic)

	_pack = PackSlot.new()
	_pack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pack.offset_left = -250
	_pack.offset_top = -200
	_pack.offset_right = -20
	_pack.offset_bottom = -16
	add_child(_pack)

	_hint = _label(15, HORIZONTAL_ALIGNMENT_LEFT, 700)
	_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hint.offset_left = 22
	_hint.offset_top = 16
	_hint.text = "WASD walk · Shift run · Space jump · E use\nR rest · Tab backpack · G emotes · V view · Esc pause"
	_hint.modulate.a = 0.0
	add_child(_hint)


func _label(size: int, align: HorizontalAlignment, weight := 700) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiTheme.body(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 0.99, 0.95, 0.97))
	l.add_theme_color_override("font_outline_color", Color(UiTheme.INK, 0.75))
	l.add_theme_constant_override("outline_size", maxi(size / 4, 5))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Cream key with an ink border and a hard shadow, e.g. [E]
static func keycap(text: String, size := 17) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme._box(UiTheme.CREAM, UiTheme.INK, 2, 7, 3, Vector4(9, 1, 9, 2)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.body(900))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiTheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = size * 0.9
	p.add_child(l)
	return p


func set_player(p: Wanderer) -> void:
	player = p
	_bar.body = p.body
	_bar.player = p
	_pack.player = p


func set_playing(on: bool) -> void:
	for c: CanvasItem in [_mic, _distance, _bar, _prompt, _pack, get_node("Crosshair"), _overlay]:
		c.visible = on
	if on:
		var t := create_tween()
		t.tween_property(_hint, "modulate:a", 1.0, 0.8)
		t.tween_interval(7.0)
		t.tween_property(_hint, "modulate:a", 0.0, 1.5)
	else:
		_hint.modulate.a = 0.0
		_black.color.a = 0.0
		_message.modulate.a = 0.0


func set_distance(meters: float) -> void:
	_distance.text = "%.2f km" % (maxf(meters, 0.0) / 1000.0)


func show_biome(name: String, subtitle: String) -> void:
	_biome_toast.text = name.to_upper()
	_biome_sub.text = subtitle
	if _toast_tween:
		_toast_tween.kill()
	_biome_box.modulate.a = 0.0
	_biome_box.pivot_offset = Vector2(_biome_box.size.x * 0.5, 40)
	_biome_box.scale = Vector2(0.85, 0.85)
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_biome_box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_property(_biome_box, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(3.4)
	_toast_tween.chain().tween_property(_biome_box, "modulate:a", 0.0, 1.6)


## Old single-string prompt (fallback) or the structured one from the player
func set_prompt(text: String, title := "", action := "") -> void:
	if text == "":
		_prompt.visible = false
		return
	_prompt.visible = true
	if action == "":
		action = text.trim_prefix("E  ")
	action = action.replace(" (E)", "")
	_prompt_title.text = title.to_upper()
	_prompt_title.visible = title != ""
	# "You could tie a rope here" is a hint, not an action
	_prompt_key.visible = not action.begins_with("You ")
	_prompt_action.text = action


func show_message(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme._box(Color(UiTheme.INK, 0.78), Color(1, 1, 1, 0.18), 2, 22, 0, Vector4(18, 5, 18, 7)))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(18, HORIZONTAL_ALIGNMENT_CENTER, 800)
	l.remove_theme_constant_override("outline_size")
	l.text = text
	p.add_child(l)
	_messages.add_child(p)
	while _messages.get_child_count() > 4:
		_messages.get_child(0).free()
	p.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.18)
	t.tween_interval(3.5)
	t.tween_property(p, "modulate:a", 0.0, 0.9)
	t.tween_callback(p.queue_free)


func set_needs(needs: Array[String]) -> void:
	_bar.needs = needs


func update_body(stamina: float, _state: int, _delta: float) -> void:
	var tired := 1.0 - clampf(stamina / 55.0, 0.0, 1.0)
	_overlay_mat.set_shader_parameter("amount", tired)
	_overlay.visible = tired > 0.01 and _bar.visible


func collapse_fade(on: bool, text := "You collapsed from exhaustion …") -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_black, "color:a", 0.92 if on else 0.0, 1.2 if on else 2.0)
	if on:
		_message.text = text
	t.tween_property(_message, "modulate:a", 1.0 if on else 0.0, 1.0)


func update_fps(show: bool) -> void:
	_fps.visible = show
	if show:
		_fps.text = "%d FPS · %d %%" % [Engine.get_frames_per_second(), roundi(get_viewport().scaling_3d_scale * 100.0)]


## Bottom right: backpack slot with item count and weight, plus key hints
class PackSlot extends Control:
	var player: Wanderer
	var _w := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if player:
			_w = lerpf(_w, player.inventory.total_weight(), 1.0 - exp(-8.0 * delta))
		queue_redraw()

	func _draw() -> void:
		if player == null:
			return
		var line := Color(0.98, 0.96, 0.9, 0.92)
		var bg := Color(0.12, 0.15, 0.11, 0.5)
		var s := 84.0
		var r := Rect2(Vector2(size.x - s, size.y - s - 34), Vector2(s, s))
		draw_style_box(UiTheme._box(bg, line, 3, 16), r)
		# backpack glyph
		var c := r.get_center() + Vector2(0, 2)
		var body := StyleBoxFlat.new()
		body.bg_color = Color("b5673a")
		body.set_corner_radius_all(10)
		body.corner_detail = 8
		body.anti_aliasing = true
		body.border_color = UiTheme.INK
		body.set_border_width_all(2)
		draw_arc(c + Vector2(0, -18), 8.0, PI, TAU, 12, UiTheme.INK, 3.0, true)
		draw_style_box(body, Rect2(c + Vector2(-17, -18), Vector2(34, 40)))
		draw_line(c + Vector2(-15, -6), c + Vector2(15, -6), Color("7e3f22"), 3.0)
		var pocket := body.duplicate() as StyleBoxFlat
		pocket.bg_color = Color("d08a4f")
		pocket.set_corner_radius_all(6)
		draw_style_box(pocket, Rect2(c + Vector2(-11, 2), Vector2(22, 15)))
		# item count badge
		var n := player.inventory.items.size()
		var font := UiTheme.body(900)
		if n > 0:
			var bc := r.position + Vector2(s - 6, 6)
			draw_circle(bc, 14.0, UiTheme.SUN)
			draw_arc(bc, 14.0, 0.0, TAU, 24, UiTheme.INK, 2.0, true)
			var t := str(n)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, bc + Vector2(-tw * 0.5, 5.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.INK)
		# weight bar under the slot (comfortable / heavy / full), tick at the comfort limit
		var wr := Rect2(Vector2(r.position.x, r.end.y + 8), Vector2(s, 7))
		draw_rect(wr, Color(0, 0, 0, 0.35))
		var frac := clampf(_w / Inventory.MAX_WEIGHT, 0.0, 1.0)
		var wc := UiTheme.LEAF if _w <= Inventory.COMFORT_WEIGHT else (UiTheme.SUN if frac < 0.8 else UiTheme.ORANGE)
		draw_rect(Rect2(wr.position, Vector2(s * frac, 7)), wc.lightened(0.15))
		var ct := wr.position.x + s * Inventory.COMFORT_WEIGHT / Inventory.MAX_WEIGHT
		draw_line(Vector2(ct, wr.position.y - 2), Vector2(ct, wr.end.y + 2), line, 2.0)
		var kg := "%.1f kg" % _w
		var kw := font.get_string_size(kg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(font, Vector2(r.end.x - kw, wr.end.y + 19), kg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(UiTheme.INK, 0.7))
		draw_string(font, Vector2(r.end.x - kw, wr.end.y + 19), kg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, line)
		# key hints left of the slot
		var y := r.position.y + 8.0
		for h in [["Tab", "backpack"], ["G", "emotes"], ["V", "view"]]:
			_hint_row(h[0], h[1], Vector2(r.position.x - 14, y), font)
			y += 28.0

	## Right-aligned "[key] label" ending at pos.x
	func _hint_row(key: String, label: String, pos: Vector2, font: Font) -> void:
		var fs := 15
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var kw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
		var x := pos.x - lw
		draw_string_outline(font, Vector2(x, pos.y + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(UiTheme.INK, 0.6))
		draw_string(font, Vector2(x, pos.y + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.99, 0.95, 0.9))
		var kr := Rect2(Vector2(x - kw - 8, pos.y), Vector2(kw, 20))
		draw_style_box(UiTheme._box(UiTheme.CREAM, UiTheme.INK, 2, 5, 2, Vector4.ZERO), kr)
		draw_string(font, Vector2(kr.position.x + 7, pos.y + 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.INK)
