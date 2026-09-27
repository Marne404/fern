class_name UiTheme
extends RefCounted
## Shared look of all menus: dark, semi-transparent glass with a green accent.

## Display font for titles and headings (Luckiest Guy, Apache 2.0)
const DISPLAY_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.08, 0.07, 0.8)
	panel.set_corner_radius_all(18)
	panel.set_content_margin_all(28)
	panel.shadow_color = Color(0, 0, 0, 0.25)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		match state:
			"normal": sb.bg_color = Color(1, 1, 1, 0.07)
			"hover": sb.bg_color = Color(1, 1, 1, 0.16)
			"pressed": sb.bg_color = Color(0.55, 0.8, 0.35, 0.45)
			"focus":
				sb.bg_color = Color(1, 1, 1, 0.12)
				sb.border_color = Color(0.7, 0.9, 0.5, 0.8)
				sb.set_border_width_all(2)
			"disabled": sb.bg_color = Color(1, 1, 1, 0.03)
		t.set_stylebox(state, "Button", sb)
		t.set_stylebox(state, "OptionButton", sb)
	t.set_color("font_color", "Button", Color(0.95, 0.96, 0.92))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_color", "Label", Color(0.93, 0.95, 0.9))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.6, 0.85, 0.4)
	grab.set_corner_radius_all(4)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.1)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	return t
