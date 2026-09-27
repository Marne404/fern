class_name Menus
extends CanvasLayer
## Main menu, pause menu and settings.

signal start_pressed
signal resume_pressed
signal main_menu_pressed
## Scout editor opened/closed; the look changed; dragged to turn the scout
signal scout_editor(open: bool)
signal scout_changed
signal scout_dragged(dx: float)

var _theme: Theme
var _main: Control
var _pause: Control
var _settings: Control
var _scout: Control
var _scout_controls := {}       # look key -> [kind, Control]
var _settings_back: Control      # where "Back" leads
var _record_label: Label
var _seed_edit: LineEdit
var _seed_info: Label
var _controls := {}              # settings key -> Control
var _tabs: TabContainer
var _updating := false

const AA_NAMES := ["Off", "FXAA", "MSAA 2×", "MSAA 4×", "TAA"]
const SHADOW_NAMES := ["Off", "Low", "Medium", "High", "Ultra"]
const FPS_TARGETS := [30, 45, 60, 90, 120]
const FPS_LIMITS := [0, 30, 60, 90, 120, 144]


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = UiTheme.make()
	_main = _build_main()
	_pause = _build_pause()
	_settings = _build_settings()
	_scout = _build_scout()
	for c in [_main, _pause, _settings, _scout]:
		c.theme = _theme
		c.visible = false
		add_child(c)
	Settings.changed.connect(func(_k): _refresh_settings())


# ================================================================ Showing

func set_seed_text(t: String) -> void:
	_seed_edit.text = t
	_update_seed_info()


func seed_value() -> int:
	return Settings.parse_seed(_seed_edit.text)


func _update_seed_info() -> void:
	var t := _seed_edit.text.strip_edges()
	_seed_info.text = "Seed %d" % seed_value() if t != "" and not t.is_valid_int() else ""


func show_main(record_km: float) -> void:
	_record_label.text = "Longest journey: %s km" % _km(record_km) if record_km > 0.01 else "No journey yet"
	_show(_main)


func show_pause(seed_v := -1) -> void:
	var t := _pause.find_child("PauseTitle", true, false) as Label
	if t:
		t.text = "Paused" if seed_v < 0 else "Paused · World %d" % seed_v
	_show(_pause)


func hide_all() -> void:
	_show(null)


func is_open() -> bool:
	return _main.visible or _pause.visible or _settings.visible or _scout.visible


func is_main_open() -> bool:
	return _main.visible or _scout.visible or (_settings.visible and _settings_back == _main)


func _show(c: Control) -> void:
	# release focus, otherwise Space/Enter in game still triggers hidden buttons
	var owner := get_viewport().gui_get_focus_owner()
	if owner:
		owner.release_focus()
	var was_scout := _scout.visible
	for x in [_main, _pause, _settings, _scout]:
		x.visible = x == c
	if was_scout != _scout.visible:
		scout_editor.emit(_scout.visible)
	if c:
		var first := c.find_child("FirstButton", true, false) as Control
		if first:
			first.grab_focus.call_deferred()


func back() -> void:
	if _scout.visible:
		_show(_main)
	elif _settings.visible:
		_show(_settings_back)
	elif _pause.visible:
		resume_pressed.emit()


static func _km(v: float) -> String:
	return "%.1f" % v


# ================================================================ Theme

func _big_label(text: String, size: int, color := UiTheme.INK) -> Label:
	if size >= 40:
		return UiTheme.sticker(text, size, UiTheme.SUN if color == UiTheme.INK else color)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.body(800))
	l.add_theme_color_override("font_color", color)
	return l


func _secondary(b: Button) -> Button:
	b.theme_type_variation = "SecondaryButton"
	return b


func _button(text: String, cb: Callable, first := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 0)
	b.pressed.connect(cb)
	if first:
		b.name = "FirstButton"
	return b


# ================================================================ Main menu

func _build_main() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.05, 0.03, 0.55))
	g.set_color(1, Color(0.02, 0.05, 0.03, 0.0))
	grad.gradient = g
	grad.fill_to = Vector2(1, 0)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	tr.custom_minimum_size = Vector2(760, 0)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.offset_left = 90
	col.offset_top = -330
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	# multicolored logo like on the website, each letter slightly tilted
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", -4)
	var letters := [["F", UiTheme.SUN, -3.0], ["E", Color("f5a33e"), 2.0], ["R", Color("9ccc4a"), -2.0], ["N", Color("6fb6ee"), 3.0]]
	for lt in letters:
		var l := UiTheme.sticker(lt[0], 150, lt[1])
		l.pivot_offset = Vector2(50, 90)
		l.rotation_degrees = lt[2]
		logo.add_child(l)
	col.add_child(logo)
	var tag := Label.new()
	tag.text = "An endless hiking trail"
	tag.add_theme_font_override("font", UiTheme.body(900))
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", UiTheme.CREAM)
	tag.add_theme_color_override("font_outline_color", UiTheme.INK)
	tag.add_theme_constant_override("outline_size", 8)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	# record as a little merit badge
	var rec := HBoxContainer.new()
	rec.add_theme_constant_override("separation", 10)
	var badge := Label.new()
	badge.text = "★"
	badge.add_theme_font_size_override("font_size", 26)
	badge.add_theme_color_override("font_color", UiTheme.SUN)
	badge.add_theme_color_override("font_outline_color", UiTheme.INK)
	badge.add_theme_constant_override("outline_size", 6)
	rec.add_child(badge)
	_record_label = _big_label("", 19, UiTheme.INK)
	rec.add_child(_record_label)
	box.add_child(rec)
	# world seed: same input = same world (to share with friends)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	var sl := _big_label("World", 18, UiTheme.INK_SOFT)
	sl.custom_minimum_size = Vector2(60, 0)
	seed_row.add_child(sl)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(200, 0)
	_seed_edit.placeholder_text = "Seed or name"
	_seed_edit.max_length = 32
	_seed_edit.text_submitted.connect(func(_t): if _main.visible: start_pressed.emit())
	_seed_edit.text_changed.connect(func(_t): _update_seed_info())
	seed_row.add_child(_seed_edit)
	var dice := _secondary(Button.new())
	dice.text = "Random"
	dice.tooltip_text = "New random world"
	dice.pressed.connect(func():
		_seed_edit.text = str(randi() % 999999999)
		_update_seed_info())
	seed_row.add_child(dice)
	box.add_child(seed_row)
	_seed_info = _big_label("", 15, UiTheme.INK_SOFT)
	box.add_child(_seed_info)
	box.add_child(_button("Start hiking", func(): if _main.visible: start_pressed.emit(), true))
	box.add_child(_secondary(_button("Your scout", func(): _open_scout())))
	box.add_child(_secondary(_button("Settings", func(): _open_settings(_main))))
	box.add_child(_secondary(_button("Quit", func(): get_tree().quit())))
	return root


# ================================================================ Scout editor

func _open_scout() -> void:
	_refresh_scout()
	_show(_scout)


func _look() -> Dictionary:
	var l: Dictionary = Scout.DEFAULT_LOOK.duplicate()
	var saved: Dictionary = Settings.values.get("scout", {})
	for k in saved:
		if l.has(k):
			l[k] = int(saved[k])
	return l


func _set_look(key: String, v: int) -> void:
	var l := _look()
	l[key] = v
	Settings.set_value("scout", l, false)
	_refresh_scout()
	scout_changed.emit()


func _build_scout() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# dragging anywhere outside the panel turns the scout
	root.gui_input.connect(func(e):
		if e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			scout_dragged.emit(e.relative.x))
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -70
	panel.custom_minimum_size = Vector2(660, 0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_big_label("Your scout", 52))
	var hint := _big_label("Drag to turn them around", 16, UiTheme.INK_SOFT)
	box.add_child(hint)
	_cycle_row(box, "face", "Face", Scout.FACE_NAMES)
	_swatch_row(box, "skin", "Color", Scout.SKIN_COLORS)
	_swatch_row(box, "outfit", "Shirt", Scout.OUTFIT_COLORS)
	_swatch_row(box, "pants", "Shorts", Scout.PANTS_COLORS)
	_swatch_row(box, "sash", "Sash", Scout.ACCENT_COLORS)
	_cycle_row(box, "hat", "Hat", Scout.HAT_NAMES)
	_swatch_row(box, "hat_color", "Hat color", Scout.ACCENT_COLORS)
	_swatch_row(box, "pack", "Backpack", Scout.ACCENT_COLORS)
	_cycle_row(box, "extra", "Extras", Scout.EXTRA_NAMES)
	_swatch_row(box, "scarf", "Neckerchief", Scout.ACCENT_COLORS)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rnd := _button("Surprise me", func():
		Settings.set_value("scout", Scout.random_look(), false)
		_refresh_scout()
		scout_changed.emit())
	rnd.custom_minimum_size = Vector2(0, 0)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rnd)
	var done := _button("Done", func(): _show(_main), true)
	done.custom_minimum_size = Vector2(0, 0)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(done)
	box.add_child(row)
	return root


func _swatch_row(box: VBoxContainer, key: String, text: String, colors: Array) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var l := _big_label(text, 18, UiTheme.LEAF_DARK)
	l.custom_minimum_size = Vector2(130, 0)
	line.add_child(l)
	box.add_child(line)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 6)
	var buttons := []
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = text
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = colors[i] if st != "hover" else (colors[i] as Color).lightened(0.15)
			sb.set_corner_radius_all(15)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_set_look.bind(key, i))
		flow.add_child(b)
		buttons.append(b)
	line.add_child(flow)
	_scout_controls[key] = ["swatch", buttons]


func _cycle_row(box: VBoxContainer, key: String, text: String, names: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _big_label(text, 18, UiTheme.LEAF_DARK)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(func(): _set_look(key, posmod(_look()[key] - 1, names.size())))
	row.add_child(prev)
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(func(): _set_look(key, posmod(_look()[key] + 1, names.size())))
	row.add_child(next)
	box.add_child(row)
	_scout_controls[key] = ["cycle", val, names]


func _refresh_scout() -> void:
	var l := _look()
	for key in _scout_controls:
		var c: Array = _scout_controls[key]
		if c[0] == "swatch":
			for i in c[1].size():
				var b: Button = c[1][i]
				for st in ["normal", "hover", "pressed", "focus"]:
					var sb := b.get_theme_stylebox(st) as StyleBoxFlat
					sb.set_border_width_all(3 if i == l[key] else 0)
					sb.border_color = UiTheme.ORANGE if i == l[key] else UiTheme.INK
					sb.set_border_width_all(4 if i == l[key] else 2)
		else:
			(c[1] as Label).text = c[2][l[key]]


# ================================================================ Pause

func _build_pause() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _big_label("Paused", 44)
	title.name = "PauseTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_button("Keep hiking", func(): resume_pressed.emit(), true))
	box.add_child(_button("Settings", func(): _open_settings(_pause)))
	box.add_child(_button("End journey", func(): main_menu_pressed.emit()))
	box.add_child(_button("Quit game", func(): get_tree().quit()))
	return root


# ================================================================ Settings

func _open_settings(from: Control) -> void:
	_settings_back = from
	_refresh_settings()
	_show(_settings)


func _build_settings() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)
	outer.add_child(_big_label("Settings", 48))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(840, 600)
	outer.add_child(_tabs)
	var list := _tab("Graphics")
	_option(list, "preset", "Preset", Settings.PRESET_NAMES + ["Custom"])
	_slider(list, "render_scale", "Render resolution", 0.5, 1.5, 0.05, func(v): return "%d %%" % roundi(v * 100))
	_option(list, "upscaler", "Upscaling below 100 %", ["FSR 1 (sharp)", "FSR 2 (temporal, smooth)", "Bilinear"])
	_check(list, "dynamic_res", "Dynamic resolution (lowers resolution when FPS drop)")
	_option(list, "target_fps", "Target frame rate", FPS_TARGETS.map(func(v): return "%d FPS" % v))
	_option(list, "aa", "Anti-aliasing", AA_NAMES)
	_option(list, "shadows", "Shadows", SHADOW_NAMES)
	_check(list, "ssao", "Ambient occlusion (SSAO)")
	_check(list, "volumetric", "Volumetric fog / light rays")
	_check(list, "glow", "Glow")
	_check(list, "sun_shafts", "Sun shafts")
	_option(list, "grass_blades", "Grass blades", ["Off", "Normal", "Dense", "Paradise"])
	_slider(list, "blade_range", "Grass blade range", 0.6, 2.2, 0.1, func(v): return "%d %%" % roundi(v * 100))
	_check(list, "film_look", "Film look (anime color grading)")
	_check(list, "outlines", "Anime outlines")
	_check(list, "ssil", "Indirect light (SSIL)")
	_check(list, "dof", "Distance depth of field")
	_slider(list, "lod", "Distant detail reduction", 0.25, 8.0, 0.25, func(v): return "%.2f" % v)
	_slider(list, "view_distance", "View distance", 3, 24, 1, func(v): return "%d m" % (int(v) * 64))
	_slider(list, "veg_density", "Vegetation density", 0.25, 2.5, 0.05, func(v): return "%d %%" % roundi(v * 100))
	_slider(list, "grass_distance", "Grass distance", 25, 250, 5, func(v): return "%d m" % int(v))
	_slider(list, "shadow_range", "Shadow distance", 0.5, 3.0, 0.1, func(v): return "%d %%" % roundi(v * 100))
	_check(list, "wind_fx", "Wind lines")
	_check(list, "particles", "Leaves, pollen & weather effects")
	list = _tab("Performance")
	var note := Label.new()
	note.text = "All of these save time without a visible difference. Toggle individually to compare."
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)
	_check(list, "opt_cells", "Batch plants in small cells")
	_check(list, "opt_far_batch", "Coarse batching for distant areas")
	_check(list, "opt_far_trees", "Simplify distant trees")
	_check(list, "opt_opaque_grass", "Grass tufts without alpha test")
	_check(list, "opt_small_noshadow", "No shadows for small props")
	_check(list, "opt_foliage_noaniso", "Leaves without anisotropic filtering")
	_check(list, "opt_shafts_16", "Sun shafts with fewer samples")
	_check(list, "opt_shadow_filter", "Ultra shadows: medium filter")
	_check(list, "opt_blade_budget", "Build grass blades gradually (prevents hitches)")
	_check(list, "opt_music_thread", "Load music in the background")
	list = _tab("Display")
	_option(list, "fps_limit", "Frame rate limit", FPS_LIMITS.map(func(v): return "Unlimited" if v == 0 else "%d FPS" % v))
	_check(list, "vsync", "VSync")
	_check(list, "fullscreen", "Fullscreen")
	_check(list, "show_fps", "Show frame rate")
	list = _tab("Audio & voice")
	_check(list, "music", "Music")
	_slider(list, "music_volume", "Music volume", 0.0, 1.0, 0.05, func(v): return "%d %%" % roundi(v * 100))
	_section(list, "Voice (local test – nothing is sent)")
	_check(list, "voice_enabled", "Use microphone")
	var dev_row := _row(list, "Input device")
	var dev := OptionButton.new()
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev.pressed.connect(func():
		# refresh the list when opened (devices can come and go)
		dev.clear()
		for d in Voice.devices():
			dev.add_item(d)
		var cur := Voice.devices().find(Settings.values.get("voice_device", "Default"))
		dev.select(maxi(cur, 0)))
	for d in Voice.devices():
		dev.add_item(d)
	dev.select(maxi(Voice.devices().find(Settings.values.get("voice_device", "Default")), 0))
	dev.item_selected.connect(func(i: int): Settings.set_value("voice_device", dev.get_item_text(i), false))
	dev_row.add_child(dev)
	_option(list, "voice_mode", "Mode", Voice.MODE_NAMES)
	var hint := Label.new()
	hint.text = "Push to talk: hold T."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	list.add_child(hint)
	_slider(list, "voice_threshold", "Voice activation threshold", -60.0, -10.0, 1.0, func(v): return "%d dB" % int(v))
	var meter_row := _row(list, "Level")
	meter_row.add_child(MicWidgets.Meter.new())
	_check(list, "voice_monitor", "Hear myself")
	_check(list, "voice_lipsync", "My scout's mouth moves when I talk")
	list = _tab("Controls")
	_check(list, "emote_camera", "Emote camera (first person steps back while an emote plays)")
	for i in 8:
		_emote_slot(list, i)
	_slider(list, "fov", "Field of view", 55, 100, 1, func(v): return "%d°" % int(v))
	_slider(list, "mouse_sens", "Mouse sensitivity", 0.2, 3.0, 0.05, func(v): return "%.2f" % v)

	var back := _button("Back", func(): back(), true)
	outer.add_child(back)
	return root


## One slot of the emote wheel (G)
func _emote_slot(list: VBoxContainer, i: int) -> void:
	var row := _row(list, "Emote wheel slot %d" % (i + 1))
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = Scout.EMOTES.keys()
	for id in ids:
		ob.add_item(Scout.EMOTES[id][0])
	var cur: Array = Settings.values.get("emote_wheel", [])
	if cur.size() != 8:
		cur = Scout.DEFAULT_WHEEL.duplicate()
	ob.select(ids.find(cur[i]))
	ob.item_selected.connect(func(k: int):
		var w: Array = Settings.values.get("emote_wheel", [])
		w = w.duplicate() if w.size() == 8 else Scout.DEFAULT_WHEEL.duplicate()
		w[i] = ids[k]
		Settings.set_value("emote_wheel", w, false))
	row.add_child(ob)


## Test helper: scroll the settings so the section whose title starts with `text` is at the top
func scroll_settings_to(text: String) -> void:
	await get_tree().process_frame
	for l in _settings.find_children("*", "Label", true, false):
		if (l as Label).text.to_lower().begins_with(text.to_lower()):
			var n: Node = l
			while n and not (n is ScrollContainer):
				n = n.get_parent()
			if n:
				_tabs.current_tab = n.get_index()
				await get_tree().process_frame
				(n as ScrollContainer).scroll_vertical = int(l.position.y)
			return


func _section(list: VBoxContainer, text: String) -> void:
	var l := _big_label(text, 22, UiTheme.LEAF_DARK)
	list.add_child(l)
	list.add_child(HSeparator.new())


## A settings tab: a scrolling list
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list


func _row(list: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(330, 0)
	row.add_child(l)
	list.add_child(row)
	return row


func _option(list: VBoxContainer, key: String, text: String, items: Array) -> void:
	var row := _row(list, text)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		ob.add_item(it)
	ob.item_selected.connect(func(i): _on_option(key, i))
	row.add_child(ob)
	_controls[key] = ob


func _check(list: VBoxContainer, key: String, text: String) -> void:
	var row := _row(list, text)
	var cb := CheckButton.new()
	cb.toggled.connect(func(on): if not _updating: Settings.set_value(key, on))
	row.add_child(cb)
	_controls[key] = cb


func _slider(list: VBoxContainer, key: String, text: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := _row(list, text)
	var s := HSlider.new()
	s.drag_started.connect(func(): s.set_meta("dragging", true))
	s.drag_ended.connect(func(_c): s.remove_meta("dragging"))
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size = Vector2(90, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(_on_slider.bind(s, key, val, fmt))
	s.drag_ended.connect(func(_changed): _on_slider(s.value, s, key, val, fmt, true))
	row.add_child(s)
	row.add_child(val)
	_controls[key] = s


const HEAVY := ["view_distance", "veg_density", "grass_distance", "blade_range"]


## Apply heavy settings (world rebuild) only on release
func _on_slider(v: float, s: HSlider, key: String, val: Label, fmt: Callable, released := false) -> void:
	val.text = fmt.call(v)
	if _updating:
		return
	if key in HEAVY and not released and s.has_meta("dragging"):
		return
	Settings.set_value(key, int(v) if key == "view_distance" else v)


func _on_option(key: String, i: int) -> void:
	if _updating:
		return
	match key:
		"preset":
			if i < Settings.PRESET_NAMES.size():
				Settings.apply_preset(Settings.PRESET_NAMES[i])
		"target_fps":
			Settings.set_value(key, FPS_TARGETS[i], false)
		"fps_limit":
			Settings.set_value(key, FPS_LIMITS[i], false)
		_:
			Settings.set_value(key, i)


func _refresh_settings() -> void:
	_updating = true
	var v := Settings.values
	for key in _controls:
		var c = _controls[key]
		match key:
			"preset":
				var idx: int = Settings.PRESET_NAMES.find(v["preset"])
				(c as OptionButton).select(idx if idx >= 0 else Settings.PRESET_NAMES.size())
			"target_fps":
				(c as OptionButton).select(maxi(FPS_TARGETS.find(v[key]), 0))
			"fps_limit":
				(c as OptionButton).select(maxi(FPS_LIMITS.find(v[key]), 0))
			_:
				if c is OptionButton:
					(c as OptionButton).select(v[key])
				elif c is CheckButton:
					(c as CheckButton).button_pressed = v[key]
				elif c is HSlider:
					(c as HSlider).value = v[key]
					(c as HSlider).value_changed.emit((c as HSlider).value)
	_updating = false
