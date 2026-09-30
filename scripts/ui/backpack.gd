class_name Backpack
extends CanvasLayer
## Backpack view (Tab): a paper card with the body (segmented stamina bar and needs), a slot grid with all
## items and the selected item in detail with its actions.

const COLS := 6
const SLOT := 82
const KIND_NAMES := {"essen": "Food", "trinken": "Drink", "medizin": "Medicine", "kleidung": "Clothing",
	"werkzeug": "Tool", "spass": "Fun", "kram": "Odds & ends"}
const NEEDS := [["food", "Food", "food"], ["water", "Water", "water"], ["rest", "Rest", "rest"], ["health", "Health", "health"]]

var player: Wanderer
var _root: Control
var _card: PanelContainer
var _grid: GridContainer
var _bar: StaminaBar
var _meters := {}
var _temp_label: Label
var _weight_label: Label
var _weight: WeightBar
var _detail: VBoxContainer
var _selected := {}
var _refresh_timer := 0.0
## func(book: bool, callback(q)) – opens the knot minigame
var on_knot: Callable


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_root.resized.connect(_fit)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme._box(UiTheme.PAPER, UiTheme.INK, 3, 26, 8, Vector4(30, 22, 30, 24)))
	_card.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_card.add_child(v)

	# header: title, load
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var title := UiTheme.sticker("BACKPACK", 44)
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var load := VBoxContainer.new()
	load.add_theme_constant_override("separation", 2)
	load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(load)
	_weight_label = _text("", 17, UiTheme.INK, 900)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	load.add_child(_weight_label)
	_weight = WeightBar.new()
	_weight.custom_minimum_size = Vector2(260, 14)
	load.add_child(_weight)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)

	# left: body
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(_section("YOU"))
	_bar = StaminaBar.new()
	_bar.hud = false
	_bar.line = UiTheme.INK
	_bar.bg = UiTheme.PAPER_3
	_bar.custom_minimum_size = Vector2(0, 52)
	left.add_child(_bar)
	for n in NEEDS:
		var m := Meter.new()
		m.kind = n[2]
		m.label = n[1]
		m.custom_minimum_size = Vector2(0, 30)
		left.add_child(m)
		_meters[n[0]] = m
	_temp_label = _text("", 16, UiTheme.INK_SOFT, 800)
	_temp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_temp_label)
	var hint := _text("Heavy luggage costs stamina.\nDouble-click an item to use it.\nTab closes the backpack.", 14, UiTheme.INK_SOFT, 600)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	left.add_child(hint)

	# middle: slot grid
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	h.add_child(mid)
	mid.add_child(_section("ITEMS"))
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(_grid)

	# right: selected item
	var det := PanelContainer.new()
	det.add_theme_stylebox_override("panel", UiTheme._box(UiTheme.CREAM, UiTheme.INK, 2, 18, 0, Vector4(18, 14, 18, 16)))
	det.custom_minimum_size = Vector2(290, 0)
	h.add_child(det)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	det.add_child(_detail)


func _text(t: String, size: int, col: Color, weight := 700) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UiTheme.body(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _section(t: String) -> Label:
	var l := _text(t, 15, UiTheme.LEAF_DARK, 900)
	return l


## Scale the card down on small windows (1366×768 and smaller)
func _fit() -> void:
	if _card == null:
		return
	var avail := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var need := _card.get_combined_minimum_size()
	var k := minf(1.0, minf(avail.x / need.x, avail.y / need.y))
	_card.size = need
	_card.scale = Vector2(k, k)
	_card.position = ((avail + Vector2(24, 24) - need * k) * 0.5).floor()


func is_open() -> bool:
	return _root.visible


func open(p: Wanderer) -> void:
	if player != p:
		player = p
		player.inventory.changed.connect(_rebuild)
		_bar.body = p.body
		_bar.player = p
	_root.visible = true
	_rebuild()
	_refresh_stats()
	_fit.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.input_enabled = false


func close() -> void:
	_root.visible = false
	if player:
		player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not _root.visible or player == null:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.3
		_refresh_stats()


func _refresh_stats() -> void:
	var b := player.body
	for key in _meters:
		(_meters[key] as Meter).value = b.get(key)
	_temp_label.text = "Feels like %d °C · %s%s" % [roundi(b.feel_temp), b.temp_word(), "  ·  wet" if b.wet > 0.3 else ""]
	var w := player.inventory.total_weight()
	_weight.value = w
	_weight_label.text = "%s / %d kg%s" % [Wanderer._kg(w), int(Inventory.MAX_WEIGHT), "  · heavy!" if w > Inventory.COMFORT_WEIGHT else ""]


func _rebuild() -> void:
	if not _root.visible or player == null:
		return
	var items := player.inventory.items
	if not items.has(_selected):
		_selected = items[0] if not items.is_empty() else {}
	for c in _grid.get_children():
		c.queue_free()
	var first: Control = null
	for i in Inventory.SLOTS:
		var s := Slot.new()
		if i < items.size():
			var it: Dictionary = items[i]
			s.item = it
			s.selected = it == _selected
			s.pressed.connect(func(): _select(it))
			s.used.connect(func(): _use(it))
			if first == null or it == _selected:
				first = s
		else:
			s.focus_mode = Control.FOCUS_NONE
			s.disabled = true
		_grid.add_child(s)
	if first:
		first.grab_focus.call_deferred()
	_show_detail()
	_refresh_stats()


func _select(it: Dictionary) -> void:
	_selected = it
	for s: Slot in _grid.get_children():
		s.selected = s.item == it and not it.is_empty()
		s.queue_redraw()
	_show_detail()


func _use(it: Dictionary) -> void:
	player.use_item(it)
	_rebuild()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var it := _selected
	if it.is_empty():
		var l := _text("Empty.\nSurely there's something along the trail.", 17, UiTheme.INK_SOFT, 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		return
	var d := ItemDefs.def(it["id"])
	var icon := TextureRect.new()
	icon.texture = ItemDefs.icon(it["id"])
	icon.custom_minimum_size = Vector2(0, 118)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(icon)
	var name := _text(ItemDefs.display_name(it), 23, UiTheme.INK, 900)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(name)
	_detail.add_child(_text("%s  ·  %s kg%s" % [KIND_NAMES.get(d["kind"], ""), Wanderer._kg(ItemDefs.weight(it)),
		"  ·  worn" if it.get("equipped", false) else ""], 15, UiTheme.INK_SOFT, 800))
	# property chips
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for pr in d["props"]:
		chips.add_child(_chip(ItemDefs.PROP_NAMES[pr], UiTheme.PAPER_2))
	if it.get("wet", false):
		chips.add_child(_chip("wet", Color("cfe6f5")))
	if it.get("condition", 1.0) < 0.35:
		chips.add_child(_chip("broken", Color("f4c7bd")))
	if chips.get_child_count() > 0:
		_detail.add_child(chips)
	var desc := _text(d["desc"], 16, UiTheme.INK, 600)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	_detail.add_child(desc)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(sp)
	# actions
	var use_text: String = {"essen": "Eat", "trinken": "Drink", "medizin": "Apply", "kleidung": "Take off" if it.get("equipped", false) else "Put on"}.get(d["kind"], "Use")
	var use := Button.new()
	use.text = use_text
	use.pressed.connect(func(): _use(it))
	_detail.add_child(use)
	# take it in the hand / put it back on the pack
	if ScoutGear.holdable(it["id"]) and it.get("condition", 1.0) >= 0.35:
		var held := player.is_held(it)
		var hb := Button.new()
		hb.text = "Put away" if held else "Hold in hand"
		hb.theme_type_variation = "SecondaryButton"
		hb.pressed.connect(func():
			if held:
				player.stow_hand(ScoutGear.hand_of(it["id"]))
			else:
				player.hold_item(it)
			_show_detail())
		_detail.add_child(hb)
	var ropes: Array = player.inventory.items.filter(func(x): return x["id"] == "seil")
	if it["id"] == "seil" and ropes.size() >= 2 and on_knot.is_valid():
		var kb := Button.new()
		kb.text = "Knot ropes together"
		kb.theme_type_variation = "SecondaryButton"
		kb.pressed.connect(func(): _join_ropes(it))
		_detail.add_child(kb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	for spec in [["Throw", func(): player.drop_item(it, true); close()], ["Drop", func(): player.drop_item(it, false)]]:
		var b := Button.new()
		b.text = spec[0]
		b.theme_type_variation = "SecondaryButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)


func _chip(t: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme._box(col, UiTheme.INK, 2, 12, 0, Vector4(10, 1, 10, 3)))
	p.add_child(_text(t, 14, UiTheme.INK, 800))
	return p


## Join two ropes into a long one – the knot quality decides how much it holds later
func _join_ropes(a: Dictionary) -> void:
	var other := {}
	for x in player.inventory.items:
		if x["id"] == "seil" and x != a:
			other = x
			break
	if other.is_empty():
		return
	var book := player.inventory.items.any(func(x): return x["id"] == "feldhandbuch")
	_root.visible = false
	on_knot.call(book, func(q: float) -> void:
		_root.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if q < 0.0:
			return
		player.inventory.remove(other)
		a["length"] = int(a.get("length", 10)) + int(other.get("length", 10))
		a["knot"] = minf(minf(float(a.get("knot", 1.0)), float(other.get("knot", 1.0))), q)
		player.inventory.changed.emit()
		player.message.emit("Ropes knotted: %d m, knot %d %%." % [a["length"], roundi(q * 100)]))


## One slot of the grid: icon, charges/length badge, worn marker, wet/broken tint
class Slot extends Button:
	signal used
	var item := {}
	var selected := false

	func _init() -> void:
		custom_minimum_size = Vector2(SLOT, SLOT)
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(func(): pressed.emit())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			used.emit()
		elif e.is_action_pressed("ui_accept") and has_focus():
			used.emit()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 6))
		var empty := item.is_empty()
		var hover := is_hovered() and not empty
		var bg := UiTheme.PAPER_2 if empty else (UiTheme.CREAM if not selected else Color("fff1c2"))
		var sb := UiTheme._box(bg, UiTheme.INK if not empty else Color(UiTheme.INK, 0.25), 3 if selected else 2, 14, 0 if empty else 4)
		if selected:
			sb.border_color = UiTheme.ORANGE
			sb.shadow_color = UiTheme.ORANGE.darkened(0.35)
		draw_style_box(sb, r.grow(1.0) if hover else r)
		if empty:
			return
		var tex := ItemDefs.icon(item["id"])
		if tex:
			var ir := r.grow(-6.0)
			if hover:
				ir = ir.grow(3.0)
			draw_texture_rect(tex, ir, false, Color(0.75, 0.85, 1.0) if item.get("wet", false) else Color.WHITE)
		var font := UiTheme.body(900)
		var d := ItemDefs.def(item["id"])
		var badge := ""
		if item["id"] == "seil":
			badge = "%dm" % item.get("length", 10)
		elif d.has("charges") and d["charges"] > 1:
			badge = "%d/%d" % [item["charges"], d["charges"]]
		if badge != "":
			var tw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var br := Rect2(Vector2(r.end.x - tw - 14, r.end.y - 22), Vector2(tw + 10, 18))
			draw_style_box(UiTheme._box(UiTheme.INK, UiTheme.INK, 0, 9, 0, Vector4.ZERO), br)
			draw_string(font, br.position + Vector2(5, 14), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.CREAM)
		if item.get("equipped", false):
			var c := r.position + Vector2(14, 14)
			draw_circle(c, 10.0, UiTheme.LEAF)
			draw_arc(c, 10.0, 0.0, TAU, 20, UiTheme.INK, 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1.5, 4), c + Vector2(5, -4)]), UiTheme.CREAM, 2.5, true)
		if item.get("condition", 1.0) < 0.35:
			draw_line(r.position + Vector2(10, r.size.y - 10), r.position + Vector2(r.size.x - 10, 10), Color("d1493f", 0.8), 3.0, true)


## Need meter with an icon: rounded bar on paper, color by level
class Meter extends Control:
	var kind := ""
	var label := ""
	var value := 100.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var font := UiTheme.body(800)
		var cy := size.y * 0.5
		StaminaBar.draw_icon(self, kind, Vector2(11, cy), 1.0, UiTheme.INK)
		draw_string(font, Vector2(28, cy + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.INK)
		var r := Rect2(Vector2(96, cy - 7), Vector2(size.x - 100, 14))
		draw_style_box(UiTheme._box(UiTheme.PAPER_3, UiTheme.INK, 2, 7, 0, Vector4.ZERO), r)
		var col := UiTheme.LEAF.lightened(0.2) if value > 50.0 else (UiTheme.SUN if value > 25.0 else Color("d1493f"))
		var fw := (r.size.x - 6) * clampf(value / 100.0, 0.0, 1.0)
		if fw > 3.0:
			draw_style_box(UiTheme._box(col, col, 0, 5, 0, Vector4.ZERO), Rect2(r.position + Vector2(3, 3), Vector2(fw, r.size.y - 6)))


## Load bar with the comfort limit marked
class WeightBar extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme._box(UiTheme.PAPER_3, UiTheme.INK, 2, 7, 0, Vector4.ZERO), r)
		var frac := clampf(value / Inventory.MAX_WEIGHT, 0.0, 1.0)
		var col := UiTheme.LEAF.lightened(0.2) if value <= Inventory.COMFORT_WEIGHT else (UiTheme.SUN if frac < 0.8 else UiTheme.ORANGE)
		var fw := (size.x - 6) * frac
		if fw > 3.0:
			draw_style_box(UiTheme._box(col, col, 0, 4, 0, Vector4.ZERO), Rect2(Vector2(3, 3), Vector2(fw, size.y - 6)))
		var x := 3.0 + (size.x - 6) * Inventory.COMFORT_WEIGHT / Inventory.MAX_WEIGHT
		draw_line(Vector2(x, -3), Vector2(x, size.y + 3), UiTheme.INK, 2.0)
