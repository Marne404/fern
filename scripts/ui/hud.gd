class_name Hud
extends CanvasLayer
## Minimal HUD: distance, biome name, body state, exhaustion overlay.

var _distance: Label
var _biome_toast: Label
var _biome_sub: Label
var _toast_tween: Tween
var _state_box: HBoxContainer
var _state_dot: ColorRect
var _state_label: Label
var _stamina_bar: ColorRect
var _stamina_bg: ColorRect
var _state_alpha := 0.0
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _black: ColorRect
var _message: Label
var _fps: Label
var _hint: Label
var _prompt: Label
var _messages: VBoxContainer
var _needs: Label


func _ready() -> void:
	layer = 5
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = preload("res://shaders/exhaustion.gdshader")
	_overlay.material = _overlay_mat
	add_child(_overlay)

	_distance = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_distance.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_distance.offset_top = 18
	_distance.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_distance)

	_biome_toast = _label(58, HORIZONTAL_ALIGNMENT_LEFT)
	_biome_toast.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	_biome_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_biome_toast.offset_left = 64
	_biome_toast.offset_top = -170
	_biome_toast.modulate.a = 0.0
	add_child(_biome_toast)
	_biome_sub = _label(22, HORIZONTAL_ALIGNMENT_LEFT)
	_biome_sub.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_biome_sub.offset_left = 68
	_biome_sub.offset_top = -92
	_biome_sub.modulate.a = 0.0
	add_child(_biome_sub)

	_state_box = HBoxContainer.new()
	_state_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_state_box.offset_top = -64
	_state_box.offset_left = -130
	_state_box.add_theme_constant_override("separation", 10)
	_state_box.modulate.a = 0.0
	add_child(_state_box)
	_state_dot = ColorRect.new()
	_state_dot.custom_minimum_size = Vector2(14, 14)
	_state_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_state_box.add_child(_state_dot)
	_state_label = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_state_label.custom_minimum_size = Vector2(110, 0)
	_state_box.add_child(_state_label)
	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.35)
	_stamina_bg.custom_minimum_size = Vector2(140, 6)
	_stamina_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_state_box.add_child(_stamina_bg)
	_stamina_bar = ColorRect.new()
	_stamina_bar.size = Vector2(140, 6)
	_stamina_bg.add_child(_stamina_bar)

	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_message = _label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_preset(Control.PRESET_CENTER)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.modulate.a = 0.0
	add_child(_message)

	_fps = _label(16, HORIZONTAL_ALIGNMENT_RIGHT)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -260
	_fps.offset_right = -20
	_fps.offset_top = 16
	add_child(_fps)

	_prompt = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 60
	add_child(_prompt)
	var dot := _label(22, HORIZONTAL_ALIGNMENT_CENTER)
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
	_messages.offset_top = -110
	_messages.offset_bottom = -110
	_messages.alignment = BoxContainer.ALIGNMENT_END
	add_child(_messages)

	_needs = _label(17, HORIZONTAL_ALIGNMENT_CENTER)
	_needs.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_needs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_needs.offset_top = -34
	_needs.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	add_child(_needs)

	_hint = _label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 26
	_hint.offset_top = -44
	_hint.text = "WASD walk · Shift run · Space jump · E pick up/use · Tab backpack · R rest · Esc pause · F6/F7 debug flight"
	_hint.modulate.a = 0.0
	add_child(_hint)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.05, 0.5))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 4))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_playing(on: bool) -> void:
	_distance.visible = on
	_state_box.visible = on
	_prompt.visible = on
	_needs.visible = on
	get_node("Crosshair").visible = on
	_overlay.visible = on
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
	_distance.text = "%s km" % "%.2f" % (maxf(meters, 0.0) / 1000.0)


func show_biome(name: String, subtitle: String) -> void:
	_biome_toast.text = name
	_biome_sub.text = subtitle
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween().set_parallel(true)
	for l in [_biome_toast, _biome_sub]:
		l.modulate.a = 0.0
		_toast_tween.tween_property(l, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	_toast_tween.chain().tween_interval(3.0)
	_toast_tween.chain().tween_property(_biome_toast, "modulate:a", 0.0, 1.6)
	_toast_tween.parallel().tween_property(_biome_sub, "modulate:a", 0.0, 1.6)


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_message(text: String) -> void:
	var l := _label(19, HORIZONTAL_ALIGNMENT_CENTER)
	l.text = text
	_messages.add_child(l)
	while _messages.get_child_count() > 4:
		_messages.get_child(0).free()
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(l, "modulate:a", 0.0, 1.0)
	t.tween_callback(l.queue_free)


func set_needs(needs: Array[String]) -> void:
	_needs.text = "  ·  ".join(needs)


func update_body(stamina: float, state: int, delta: float) -> void:
	var c: Color = Body.STATE_COLORS[state]
	_state_dot.color = c
	_state_label.text = Body.STATE_NAMES[state]
	_stamina_bar.size.x = 140.0 * stamina / 100.0
	_stamina_bar.color = c
	# only fade in when there's something to say
	var want := 1.0 if (stamina < 99.0 or state != Body.State.FIT) else 0.0
	_state_alpha = move_toward(_state_alpha, want, delta * (2.0 if want > 0.0 else 0.5))
	_state_box.modulate.a = _state_alpha
	var tired := 1.0 - clampf(stamina / 55.0, 0.0, 1.0)
	_overlay_mat.set_shader_parameter("amount", tired)
	_overlay.visible = tired > 0.01


func collapse_fade(on: bool, text := "You collapsed from exhaustion …") -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_black, "color:a", 0.92 if on else 0.0, 1.2 if on else 2.0)
	_message.text = text if on else ""
	t.tween_property(_message, "modulate:a", 1.0 if on else 0.0, 1.0)


func update_fps(show: bool) -> void:
	_fps.visible = show
	if show:
		_fps.text = "%d FPS · %d %%" % [Engine.get_frames_per_second(), roundi(get_viewport().scaling_3d_scale * 100.0)]
