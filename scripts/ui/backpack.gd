class_name Backpack
extends CanvasLayer
## Backpack view (Tab): body state in detail and all items with weight and properties.

var player: Wanderer
var _root: Control
var _list: VBoxContainer
var _bars := {}
var _temp_label: Label
var _weight_bar: ProgressBar
var _weight_label: Label
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
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	panel.add_child(h)

	# left column: body
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(_title("Body"))
	for key in [["stamina", "Stamina"], ["food", "Food"], ["water", "Water"], ["rest", "Rest"], ["health", "Health"]]:
		var l := Label.new()
		l.text = key[1]
		left.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		left.add_child(bar)
		_bars[key[0]] = bar
	_temp_label = Label.new()
	left.add_child(_temp_label)
	left.add_child(HSeparator.new())
	_weight_label = Label.new()
	left.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.max_value = Inventory.MAX_WEIGHT
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(0, 10)
	left.add_child(_weight_bar)
	var hint := Label.new()
	hint.text = "Heavy luggage costs stamina.\nTab closes the backpack."
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	left.add_child(hint)

	# right column: items
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	right.add_child(_title("Backpack"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 32)
	return l


func is_open() -> bool:
	return _root.visible


func open(p: Wanderer) -> void:
	if player != p:
		player = p
		player.inventory.changed.connect(_rebuild)
	_root.visible = true
	_rebuild()
	_refresh_stats()
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
	for key in _bars:
		var bar: ProgressBar = _bars[key]
		var v: float = b.get(key)
		bar.value = v
		var col := Color(0.55, 0.85, 0.35) if v > 50.0 else (Color(0.98, 0.8, 0.25) if v > 25.0 else Color(0.95, 0.35, 0.25))
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
	_temp_label.text = "Feels like: %d °C · %s%s" % [roundi(b.feel_temp), b.temp_word(), "  ·  wet" if b.wet > 0.3 else ""]
	var w := player.inventory.total_weight()
	_weight_bar.value = w
	_weight_label.text = "Load: %s / %d kg%s" % [Wanderer._kg(w), int(Inventory.MAX_WEIGHT), "  (heavy!)" if w > Inventory.COMFORT_WEIGHT else ""]


func _rebuild() -> void:
	if not _root.visible or player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	if player.inventory.items.is_empty():
		var l := Label.new()
		l.text = "Empty. Surely there's something along the trail."
		_list.add_child(l)
	for it in player.inventory.items:
		_list.add_child(_row(it))


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


func _row(it: Dictionary) -> Control:
	var d := ItemDefs.def(it["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.color = d["color"]
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var name := Label.new()
	name.text = ItemDefs.display_name(it) + ("  ✓ worn" if it.get("equipped", false) else "")
	info.add_child(name)
	var sub := Label.new()
	var props: Array = []
	for pr in d["props"]:
		props.append(ItemDefs.PROP_NAMES[pr])
	sub.text = "%s kg%s  ·  %s" % [Wanderer._kg(ItemDefs.weight(it)), ("  ·  " + ", ".join(props)) if not props.is_empty() else "", d["desc"]]
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(220, 0)
	info.add_child(sub)
	row.add_child(info)
	var use_text: String = {"essen": "Eat", "trinken": "Drink", "medizin": "Apply", "kleidung": "Take off" if it.get("equipped", false) else "Put on"}.get(d["kind"], "Use")
	var ropes: Array = player.inventory.items.filter(func(x): return x["id"] == "seil")
	if it["id"] == "seil" and ropes.size() >= 2 and on_knot.is_valid():
		var kb := Button.new()
		kb.text = "Knot"
		kb.add_theme_font_size_override("font_size", 15)
		kb.pressed.connect(func(): _join_ropes(it))
		row.add_child(kb)
	for spec in [[use_text, func(): player.use_item(it); _rebuild()],
			["Throw", func(): player.drop_item(it, true); close()],
			["Drop", func(): player.drop_item(it, false)]]:
		var b := Button.new()
		b.text = spec[0]
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(spec[1])
		row.add_child(b)
	return row
