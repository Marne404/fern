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
## settings → Performance → Run benchmark
signal bench_pressed

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
var _preset_info: Label
var _rows := {}                  # settings key -> its row (dimmed when the setting has no effect)
var _bench_result: Control

const PRESET_INFO := {
	"Low": "Low – for integrated graphics and old laptops: short ranges, few effects, every simplification on.",
	"Medium": "Medium – light effects, moderate ranges, every simplification on.",
	"High": "High – the full look at moderate ranges; simplifications in the distance keep it smooth.",
	"Ultra": "Ultra – long ranges and every effect; only a few simplifications far away. Beautiful and still smooth on a good graphics card.",
	"Extreme": "Extreme – as beautiful as the game can look, whatever it costs: everything at full detail, as far as it makes sense. For very strong graphics cards and screenshots.",
	"Custom": "Custom – your own mix.",
}

## settings that only matter when another one is on: key -> condition on the current values
const DEPENDS := {
	"upscaler": "render_scale < 0.99",
	"target_fps": "dynamic_res",
	"soft_shadows": "shadows > 0",
	"shadow_range": "shadows > 0",
	"blade_range": "grass_blades > 0",
	"plant_detail_distance": "opt_far_plants",
	"impostor_distance": "impostors",
	"opt_tree_shadow_lod": "shadows > 0",
	"opt_shadow_filter": "shadows == 4",
	"opt_shafts_16": "sun_shafts",
	"day_minutes": "time_of_day == 0",
}

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
	_option(list, "preset", "Preset", Settings.PRESET_NAMES + ["Custom"],
		"Extreme looks as beautiful as the game can. Each step down trades a little of the look for frame rate.")
	_preset_info = Label.new()
	_preset_info.add_theme_font_size_override("font_size", 15)
	_preset_info.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_preset_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_preset_info)
	_section(list, "Image")
	_slider(list, "render_scale", "Render resolution", 0.5, 1.5, 0.05, func(v): return "%d %%" % roundi(v * 100),
		"The 3D world is drawn at this share of the screen resolution and scaled up. Above 100 %: supersampling.")
	_option(list, "upscaler", "Upscaling below 100 %", ["FSR 1 (sharp)", "FSR 2 (temporal, smooth)", "Bilinear"],
		"How the smaller image is scaled up to the screen.")
	_option(list, "aa", "Anti-aliasing", AA_NAMES,
		"Smooth edges. MSAA 4× is the cleanest for leaves and grass and the most expensive; TAA is smooth but a little soft.")
	_check(list, "dynamic_res", "Dynamic resolution",
		"Lowers the render resolution for a moment when the frame rate drops below the target.")
	_option(list, "target_fps", "Target frame rate", FPS_TARGETS.map(func(v): return "%d FPS" % v),
		"The frame rate dynamic resolution tries to keep.")
	_section(list, "Light & shadows")
	_option(list, "shadows", "Shadows", SHADOW_NAMES,
		"Resolution and cascades of the sun's shadows. One of the biggest costs.")
	_option(list, "soft_shadows", "Soft shadows", ["Filtered", "Soft", "Very soft"],
		"Soft and very soft: shadows are sharp where things touch the ground and blur with distance, like real sunlight. Costs a search per pixel.")
	_slider(list, "shadow_range", "Shadow distance", 0.5, 3.0, 0.1, func(v): return "%d %%" % roundi(v * 100),
		"How far shadows reach. Longer ranges draw many more trees into the shadow map.")
	_check(list, "ssao", "Ambient occlusion (SSAO)", "Soft darkening in corners, under bushes and between rocks.")
	_check(list, "ssil", "Indirect light (SSIL)", "Sunlit surfaces tint their surroundings with their color.")
	_check(list, "volumetric", "Volumetric fog & light rays", "Light you can see in the air, in the morning haze and through canopies.")
	_check(list, "sun_shafts", "Sun shafts", "Rays around the sun when it stands behind trees or clouds.")
	_check(list, "glow", "Glow", "Bright things shine softly into their surroundings.")
	_section(list, "Landscape")
	_slider(list, "view_distance", "View distance", 3, 24, 1, func(v): return "%d m" % (int(v) * 64),
		"How far the landscape is loaded. Costs memory and loading time more than frame rate.")
	_slider(list, "veg_density", "Vegetation density", 0.25, 2.5, 0.05, func(v): return "%d %%" % roundi(v * 100),
		"How many plants, flowers and grass tufts grow. A big cost.")
	_slider(list, "grass_distance", "Grass distance", 25, 250, 5, func(v): return "%d m" % int(v),
		"How far grass tufts and small flowers are drawn. A big cost.")
	_option(list, "grass_blades", "Grass blades", ["Off", "Normal", "Dense", "Paradise"],
		"A carpet of single swaying blades around you.")
	_slider(list, "blade_range", "Grass blade range", 0.6, 2.2, 0.1, func(v): return "%d %%" % roundi(v * 100),
		"How far the blade carpet reaches.")
	_slider(list, "lod", "Distant detail reduction", 0.25, 8.0, 0.25, func(v): return "%.2f" % v,
		"How early the engine's simplified models take over in the distance. Lower is more detailed.")
	_section(list, "Look")
	_check(list, "film_look", "Film look (anime color grading)", "Warmer highlights, cooler shadows, a soft vignette.")
	_check(list, "outlines", "Anime outlines", "Ink lines around shapes.")
	_check(list, "dof", "Distance depth of field", "Far scenery blurs softly, like a painting.")
	_check(list, "rest_blur", "Soft focus while resting", "The distance blurs while you sit down.")
	_check(list, "wind_fx", "Wind lines", "Streaks in the air that show the wind.")
	_check(list, "particles", "Leaves, pollen & weather effects", "Falling leaves, pollen, rain, snow and sand.")
	_check(list, "footprints", "Footprints & dust puffs", "Tracks behind you and dust where you step.")

	list = _tab("Performance")
	_option(list, "perf_overlay", "Performance overlay (F3)", ["Off", "Frame rate", "Detailed"],
		"Detailed shows what each frame costs: graphics card, processor, draw calls, triangles and memory.")
	var bench_row := _row(list, "Benchmark", "The same short hike for everyone: six places in world 1 at midday, then a walk. Takes about two minutes and ends the current hike. The report is saved and shown afterwards.")
	var bench := Button.new()
	bench.text = "Run benchmark"
	bench.pressed.connect(func(): bench_pressed.emit())
	bench_row.add_child(bench)
	_section(list, "Simplifications in the distance")
	_note(list, "Each saves time for a small change in the look. Extreme uses none of them, Ultra a few, High and below all.")
	_check(list, "opt_far_plants", "Simpler grass & flowers in the distance",
		"Beyond the distance below, grass tufts and flowers are drawn with fewer segments (every blade stays). 2–5× fewer triangles.")
	_slider(list, "plant_detail_distance", "Full-detail plants up to", 10, 120, 5, func(v): return "%d m" % int(v),
		"Grass tufts and flowers closer than this always keep their full detail.")
	_check(list, "impostors", "Distant trees as impostors",
		"Trees far away become pre-rendered pictures. Without them every tree up to the horizon is drawn as a model.")
	_slider(list, "impostor_distance", "Trees as impostors from", 120, 500, 10, func(v): return "%d m" % int(v),
		"Never closer than the shadow distance (impostors cast no shadows).")
	_check(list, "opt_tree_lod", "Simpler crowns for distant trees (75 m+)", "Distant trees use a crown with fewer, bigger leaf cards.")
	_check(list, "opt_tree_shadow_lod", "Simpler tree shadows (45 m+)", "The shadows of distant trees come from the simpler crown.")
	_check(list, "opt_far_trees", "Simpler trees in far areas", "Trees in far-away chunks are built with the simpler crown.")
	_check(list, "opt_small_noshadow", "No shadows for small props", "Pebbles, mushrooms and small stones cast no shadows.")
	_check(list, "opt_foliage_noaniso", "Leaves without anisotropic filtering", "Leaf textures seen at a flat angle get a little blurrier.")
	_check(list, "opt_shafts_16", "Sun shafts with fewer samples", "16 instead of 24 samples per pixel.")
	_check(list, "opt_shadow_filter", "Ultra shadows with the medium filter", "Shadow edges are filtered with fewer samples.")
	_section(list, "Free optimizations")
	_note(list, "No visible difference – always on. Turn one off only to compare.")
	_check(list, "opt_cells", "Batch plants in small cells", "Finer culling: less is drawn outside the view.")
	_check(list, "opt_far_batch", "Coarse batching for distant areas", "Fewer draw calls for far chunks.")
	_check(list, "opt_opaque_grass", "Grass tufts without alpha test", "Lets the graphics card skip hidden grass early.")
	_check(list, "opt_blade_budget", "Build grass blades gradually", "Spreads the building of grass blades over frames (prevents hitches).")
	_check(list, "opt_music_thread", "Load music in the background", "Prevents hitches when a new track starts.")

	list = _tab("Display")
	_check(list, "fullscreen", "Fullscreen")
	_check(list, "vsync", "VSync", "Waits for the monitor: no tearing, but the frame rate snaps to the monitor's steps.")
	_option(list, "fps_limit", "Frame rate limit", FPS_LIMITS.map(func(v): return "Unlimited" if v == 0 else "%d FPS" % v),
		"Caps the frame rate, e.g. to keep the graphics card cool and quiet.")
	_slider(list, "fov", "Field of view", 55, 100, 1, func(v): return "%d°" % int(v))

	list = _tab("World")
	_option(list, "time_of_day", "Time of day", ["Day cycle", "Always morning", "Always midday", "Always golden hour", "Always dusk", "Always night", "Each biome at its best"],
		"Each biome at its best: the clock follows the trail so every biome comes at its most beautiful hour.")
	_slider(list, "day_minutes", "Length of a day", 12, 120, 2, func(v): return "%d min" % int(v),
		"Real minutes for a whole day and night.")
	_option(list, "weather", "Weather", ["Changing", "Always fair", "Always rain"])
	list = _tab("Audio & voice")
	_check(list, "music", "Music")
	_slider(list, "music_volume", "Music volume", 0.0, 1.0, 0.05, func(v): return "%d %%" % roundi(v * 100))
	_slider(list, "sfx_volume", "Sound effects (steps, items)", 0.0, 1.0, 0.05, func(v): return "%d %%" % roundi(v * 100))
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
	_check(list, "scout_reactions", "My scout reacts to the world (rain, animals, the sky, a warm fire …)")
	_note(list, "The emote wheel has three pages of eight (hold G / LB; mouse wheel, Q/E or the D-pad flips pages).")
	for i in 24:
		_emote_slot(list, i)
	_slider(list, "mouse_sens", "Mouse sensitivity", 0.2, 3.0, 0.05, func(v): return "%.2f" % v)
	_note(list, "Controller: left stick walks, right stick looks, A jump, B crouch, L3 sprint, X use, Y backpack, RB use the item in your hand, D-pad items and rest, hold LB for emotes, LT binoculars, R3 view, Start pause.")
	_slider(list, "pad_look_sens", "Controller look speed", 0.3, 2.5, 0.05, func(v): return "%.2f" % v)
	_check(list, "pad_invert_y", "Invert looking up and down (controller)")
	_check(list, "pad_sprint_toggle", "L3 switches sprinting on (off: hold L3)")
	_check(list, "pad_crouch_toggle", "B switches crouching on and off (off: hold B)")
	_check(list, "vibration", "Controller vibration")
	_option(list, "button_style", "Button symbols", ["Automatic", "Xbox", "PlayStation"])

	var back := _button("Back", func(): back(), true)
	outer.add_child(back)
	return root


func _note(list: VBoxContainer, text: String) -> void:
	var note := Label.new()
	note.text = text
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)


## Benchmark report on top of the main menu: copy it, open its folder, close
func show_bench_result(report: String, path: String) -> void:
	if _bench_result:
		_bench_result.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
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
	box.add_child(_big_label("Benchmark", 40))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060, 520)
	box.add_child(scroll)
	var text := Label.new()
	text.text = report
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	text.add_theme_font_override("font", mono)
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", UiTheme.INK)
	scroll.add_child(text)
	var where := Label.new()
	where.text = "Saved: " + path
	where.add_theme_font_size_override("font_size", 13)
	where.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	box.add_child(where)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var copy := _secondary(_button("Copy report", func(): DisplayServer.clipboard_set(report)))
	buttons.add_child(copy)
	buttons.add_child(_secondary(_button("Open folder", func(): OS.shell_open(path.get_base_dir()))))
	var close := _button("Close", func():
		root.queue_free()
		_bench_result = null, true)
	buttons.add_child(close)
	add_child(root)
	_bench_result = root


## One slot of the emote wheel (G)
func _emote_slot(list: VBoxContainer, i: int) -> void:
	var row := _row(list, "Page %d · slot %d" % [i / 8 + 1, i % 8 + 1])
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = Scout.EMOTES.keys()
	for id in ids:
		ob.add_item(Scout.EMOTES[id][0])
	var cur: Array = ScoutEmotes.wheel_slots(Settings.values.get("emote_wheel", []))
	ob.select(ids.find(cur[i]))
	ob.item_selected.connect(func(k: int):
		var w: Array = ScoutEmotes.wheel_slots(Settings.values.get("emote_wheel", []))
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


func _row(list: VBoxContainer, text: String, hint := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	# a fixed column for the names: controls line up, long names wrap
	l.custom_minimum_size = Vector2(400, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if hint != "":
		# hovering the name explains the setting
		l.tooltip_text = hint
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(l)
	list.add_child(row)
	return row


func _option(list: VBoxContainer, key: String, text: String, items: Array, hint := "") -> void:
	var row := _row(list, text, hint)
	_rows[key] = row
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		ob.add_item(it)
	ob.item_selected.connect(func(i): _on_option(key, i))
	row.add_child(ob)
	_controls[key] = ob


func _check(list: VBoxContainer, key: String, text: String, hint := "") -> void:
	var row := _row(list, text, hint)
	_rows[key] = row
	var cb := CheckButton.new()
	cb.toggled.connect(func(on): if not _updating: Settings.set_value(key, on))
	row.add_child(cb)
	_controls[key] = cb


func _slider(list: VBoxContainer, key: String, text: String, lo: float, hi: float, step: float, fmt: Callable, hint := "") -> void:
	var row := _row(list, text, hint)
	_rows[key] = row
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


const HEAVY := ["view_distance", "veg_density", "grass_distance", "blade_range", "plant_detail_distance"]


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
	if _preset_info:
		_preset_info.text = PRESET_INFO.get(v["preset"], "")
	# dim what has no effect right now
	for key in DEPENDS:
		if not _rows.has(key):
			continue
		var expr := Expression.new()
		expr.parse(DEPENDS[key], PackedStringArray(v.keys()))
		var on: bool = expr.execute(v.values()) == true
		(_rows[key] as Control).modulate.a = 1.0 if on else 0.45
		var c = _controls[key]
		if c is HSlider:
			(c as HSlider).editable = on
		elif c is BaseButton:
			(c as BaseButton).disabled = not on
	_updating = false
