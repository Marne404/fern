class_name UiTheme
extends RefCounted
## Shared look of all menus: "field guide" paper cards with an ink outline and a hard drop shadow,
## chunky pill buttons that press in, custom toggles and sliders – the same style as the website.
## The HUD uses the translucent PEAK-like style (see Hud).

## Display font for titles and headings (Luckiest Guy, Apache 2.0)
const DISPLAY_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BODY_FILE := preload("res://assets/fonts/Nunito.ttf")

const INK := Color("22301f")
const INK_SOFT := Color("4d5b46")
const PAPER := Color("fbf4e3")
const PAPER_2 := Color("f3e6c8")
const PAPER_3 := Color("eadab4")
const CREAM := Color("fffaf0")
const SUN := Color("f2c230")
const SUN_LIGHT := Color("f8d96a")
const LEAF := Color("5b8a4c")
const LEAF_DARK := Color("36602e")
const ORANGE := Color("ec8a34")

static var _fonts := {}


## Nunito at a given weight (600 semi-bold, 800 extra-bold, 900 black)
static func body(weight := 700) -> Font:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = BODY_FILE
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = f
	return _fonts[weight]


static func _box(bg: Color, border := INK, width := 3, radius := 18, shadow := 0, margin := Vector4(20, 10, 20, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if shadow != 0:
		sb.shadow_color = INK
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, shadow)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	return sb


## Small generated textures (toggle switch, slider knob, checkbox)
static func _tex(size: Vector2i, draw: Callable) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	draw.call(img)
	return ImageTexture.create_from_image(img)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < r + 0.5:
				var a := clampf(r + 0.5 - d, 0.0, 1.0) * col.a
				var old := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0).lerp(old, 1.0 - a) if old.a > 0.0 else Color(col.r, col.g, col.b, a))


static func _pill(img: Image, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			var d := p.distance_to(a.lerp(b, t))
			if d < r + 0.5:
				var al := clampf(r + 0.5 - d, 0.0, 1.0) * col.a
				var old := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0).lerp(old, 1.0 - al) if old.a > 0.0 else Color(col.r, col.g, col.b, al))


static func _toggle(on: bool) -> ImageTexture:
	return _tex(Vector2i(58, 32), func(img: Image):
		_pill(img, Vector2(16, 16), Vector2(42, 16), 14.5, INK)
		_pill(img, Vector2(16, 16), Vector2(42, 16), 11.5, LEAF if on else PAPER_3)
		var kx := 42.0 if on else 16.0
		_disc(img, Vector2(kx, 16), 10.0, INK)
		_disc(img, Vector2(kx, 16), 7.5, CREAM))


static func _knob() -> ImageTexture:
	return _tex(Vector2i(28, 28), func(img: Image):
		_disc(img, Vector2(14, 14), 12.5, INK)
		_disc(img, Vector2(14, 14), 9.5, SUN))


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body(700)
	t.default_font_size = 20
	# paper card
	t.set_stylebox("panel", "PanelContainer", _box(PAPER, INK, 3, 26, 8, Vector4(30, 26, 30, 28)))
	t.set_stylebox("panel", "Panel", _box(PAPER, INK, 3, 26, 8))
	# buttons: sun-yellow pills with a hard shadow that press in
	var normal := _box(SUN, INK, 3, 22, 5, Vector4(24, 9, 24, 11))
	var hover := _box(SUN_LIGHT, INK, 3, 22, 7, Vector4(24, 7, 24, 13))
	var pressed := _box(Color("e0ae1c"), INK, 3, 22, 1, Vector4(24, 13, 24, 7))
	var focus := _box(Color(0, 0, 0, 0), ORANGE, 3, 24, 0)
	focus.draw_center = false
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 8
	var disabled := _box(PAPER_3, INK_SOFT, 3, 22, 3, Vector4(24, 9, 24, 11))
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, normal if cls == "Button" else _box(CREAM, INK, 3, 16, 4, Vector4(18, 8, 18, 10)))
		t.set_stylebox("hover", cls, hover if cls == "Button" else _box(Color("fff4d2"), INK, 3, 16, 5, Vector4(18, 7, 18, 11)))
		t.set_stylebox("pressed", cls, pressed if cls == "Button" else _box(PAPER_2, INK, 3, 16, 1, Vector4(18, 10, 18, 8)))
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, disabled)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(k, cls, INK)
		t.set_font("font", cls, body(900))
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	# secondary buttons: cream instead of sun yellow
	t.set_type_variation("SecondaryButton", "Button")
	t.set_stylebox("normal", "SecondaryButton", _box(CREAM, INK, 3, 22, 5, Vector4(24, 9, 24, 11)))
	t.set_stylebox("hover", "SecondaryButton", _box(Color("fff4d2"), INK, 3, 22, 7, Vector4(24, 7, 24, 13)))
	t.set_stylebox("pressed", "SecondaryButton", _box(PAPER_2, INK, 3, 22, 1, Vector4(24, 13, 24, 7)))
	# toggles
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckButton", empty)
		t.set_stylebox(st, "CheckBox", empty)
	t.set_icon("checked", "CheckButton", _toggle(true))
	t.set_icon("unchecked", "CheckButton", _toggle(false))
	t.set_icon("checked_disabled", "CheckButton", _toggle(true))
	t.set_icon("unchecked_disabled", "CheckButton", _toggle(false))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "CheckButton", INK)
	# slider
	t.set_icon("grabber", "HSlider", _knob())
	t.set_icon("grabber_highlight", "HSlider", _knob())
	var track := _box(PAPER_3, INK, 2, 6, 0, Vector4(0, 4, 0, 4))
	var fill := _box(LEAF, INK, 2, 6, 0, Vector4(0, 4, 0, 4))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# text
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", body(700))
	var le := _box(CREAM, INK, 3, 14, 0, Vector4(14, 8, 14, 8))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _box(CREAM, ORANGE, 3, 14, 0, Vector4(14, 8, 14, 8)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK_SOFT, 0.6))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(SUN, 0.6))
	# popup menus (option buttons)
	t.set_stylebox("panel", "PopupMenu", _box(PAPER, INK, 3, 14, 4, Vector4(8, 8, 8, 8)))
	t.set_stylebox("hover", "PopupMenu", _box(SUN_LIGHT, INK, 0, 10, 0))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font("font", "PopupMenu", body(800))
	t.set_font_size("font_size", "PopupMenu", 18)
	# tabs
	t.set_stylebox("panel", "TabContainer", _box(PAPER, INK, 3, 18, 0, Vector4(18, 14, 18, 14)))
	t.set_stylebox("tab_selected", "TabContainer", _box(SUN, INK, 3, 14, 0, Vector4(16, 6, 16, 8)))
	t.set_stylebox("tab_unselected", "TabContainer", _box(PAPER_2, INK, 3, 14, 0, Vector4(16, 6, 16, 8)))
	t.set_stylebox("tab_hovered", "TabContainer", _box(SUN_LIGHT, INK, 3, 14, 0, Vector4(16, 6, 16, 8)))
	t.set_stylebox("tab_focus", "TabContainer", focus)
	for k in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		t.set_color(k, "TabContainer", INK)
	t.set_font("font", "TabContainer", body(900))
	t.set_constant("side_margin", "TabContainer", 0)
	# scroll bars
	var sbar := _box(PAPER_2, INK, 0, 6, 0, Vector4(4, 4, 4, 4))
	var grab := _box(LEAF, INK, 2, 6, 0, Vector4(4, 4, 4, 4))
	t.set_stylebox("scroll", "VScrollBar", sbar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(LEAF_DARK, INK, 2, 6, 0, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(LEAF_DARK, INK, 2, 6, 0, Vector4(4, 4, 4, 4)))
	# separators and tooltips
	var sep := StyleBoxLine.new()
	sep.color = Color(INK, 0.18)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("panel", "TooltipPanel", _box(CREAM, INK, 2, 10, 0, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", INK)
	return t


## Label in the display font with a thick ink outline ("sticker" look like the website)
static func sticker(text: String, size: int, color := SUN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DISPLAY_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(size / 5, 6))
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(size / 12, 3))
	l.add_theme_constant_override("shadow_outline_size", maxi(size / 5, 6))
	return l
