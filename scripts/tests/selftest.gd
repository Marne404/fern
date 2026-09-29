extends Node
## Automated test of the body and backpack mechanics (M2). Start: godot --path . -- --selftest

var main: Node
var _fails := 0


func check(name: String, ok: bool, info := "") -> void:
	print(("  OK    " if ok else "  FAIL   ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	print("== Self test M2 ==")
	while main.player == null or not main.player.is_physics_processing():
		await get_tree().process_frame
	var p: Wanderer = main.player
	var inv := p.inventory
	check("Starting gear", inv.items.size() == 4, "%d items" % inv.items.size())
	check("Weight", absf(inv.total_weight() - 1.35) < 0.01, "%.2f kg" % inv.total_weight())

	# eating
	p.body.food = 40.0
	var apple: Dictionary = inv.items.filter(func(i): return i["id"] == "apfel")[0]
	p.use_item(apple)
	check("Ate apple", p.body.food > 50.0 and not inv.items.has(apple), "food %.0f" % p.body.food)

	# drinking from the bottle
	var bottle: Dictionary = inv.items.filter(func(i): return i["id"] == "wasserflasche")[0]
	p.body.water = 30.0
	p.use_item(bottle)
	check("Drank from bottle", p.body.water > 60.0 and bottle["charges"] == 2, "water %.0f, charges %d" % [p.body.water, bottle["charges"]])

	# throwing
	var lemo := ItemDefs.make("limonade")
	inv.add(lemo)
	p.drop_item(lemo, true)
	await frames(5)
	check("Threw lemonade", main.dropped.get_child_count() == 1 and not inv.items.has(lemo))

	# picking up: put an item right in front of the camera (clear away thrown things first)
	for c in main.dropped.get_children():
		c.free()
	var stone := ItemDefs.make("stein")
	var fwd := -p.camera.global_basis.z
	main._spawn_dropped(stone, p.camera.global_position + fwd * 1.2, Vector3.ZERO)
	var wi: WorldItem = main.dropped.get_child(main.dropped.get_child_count() - 1)
	wi.freeze = true
	await frames(3)
	p._update_look_target()
	check("Prompt when looking at it", p.prompt.contains("stone"), p.prompt)
	p.interact()
	await frames(2)
	check("Picked up stone", inv.items.has(stone))

	# clothing
	var jacket := ItemDefs.make("pullover")
	inv.add(jacket)
	p.use_item(jacket)
	check("Put on sweater", jacket["equipped"] and inv.warmth() >= 14.0, "warmth %.0f" % inv.warmth())

	# hunger and thirst over time
	var f0 := p.body.food
	var w0 := p.body.water
	for i in 600:
		p.body.update(1.0, 1, 0.0, inv.total_weight(), 20.0, 0.0, false)
	check("Hunger rises while hiking", p.body.food < f0 - 10.0, "%.0f -> %.0f" % [f0, p.body.food])
	check("Thirst rises faster", (w0 - p.body.water) > (f0 - p.body.food), "water %.0f -> %.0f" % [w0, p.body.water])
	p.body.food = 5.0
	check("Hunger lowers max stamina", p.body.max_stamina() < 50.0, "max %.0f" % p.body.max_stamina())
	p.body.food = 90.0
	p.body.water = 90.0

	# cold without clothing
	jacket["equipped"] = false
	for i in 200:
		p.body.update(1.0, 0, 0.0, 2.0, 2.0, inv.warmth(), false)
	check("Cold is felt", p.body.feel_temp < 10.0 and p.body.needs().has("Cold"), "%.0f °C" % p.body.feel_temp)
	p.body.feel_temp = 18.0

	# weight slows you down
	var heavy: Array = []
	for i in 12:
		var s := ItemDefs.make("stein")
		if inv.add(s):
			heavy.append(s)
	var st0 := 60.0
	p.body.stamina = st0
	for i in 10:
		p.body.update(1.0, 1, 0.0, inv.total_weight(), 18.0, 0.0, false)
	check("Heavy load costs stamina", p.body.stamina < st0, "%.1f kg, stamina %.0f" % [inv.total_weight(), p.body.stamina])
	for s in heavy:
		inv.remove(s)

	# swimming: put the player into the nearest pond
	var pond := Vector4.ZERO
	for k in range(1, 40):
		var pd: Vector4 = main.gen.pond(k)
		if pd.z > 12.0:
			pond = pd
			break
	var cam: bool = inv.add(ItemDefs.make("kamera"))
	main.start_z = pond.y
	p.global_position = main.world.world_to_local(Vector3(pond.x, pond.w - 1.6, pond.y))
	main.world.focus = Vector2(pond.x, pond.y)
	while not main.world.is_ready_around(Vector2(pond.x, pond.y)):
		await get_tree().process_frame
	p.global_position = main.world.world_to_local(Vector3(pond.x, pond.w - 1.6, pond.y))
	await frames(20)
	var cam_item := inv.items.filter(func(i): return i["id"] == "kamera")
	check("Swimming in the pond", p.swimming, "pond r=%.0f" % pond.z)
	check("Camera wet and broken", cam and not cam_item.is_empty() and cam_item[0]["wet"] and cam_item[0]["condition"] < 0.35)
	check("Player is wet", p.body.wet > 0.5)

	# open a chest (build a find spot and use it)
	var kiste := {}
	for k in range(1, 60):
		var pl := PoiManager.plan(main.gen, k)
		if not pl.is_empty() and pl["type"] == "kiste":
			kiste = pl
			break
	var root: Node3D = main.pois._build(kiste, Vector2.ZERO)
	add_child(root)
	var area: Node = null
	for c in root.get_children():
		if c.has_meta("poi_action"):
			area = c
	check("Chest has interaction", area != null)
	if area:
		(area.get_meta("poi_action") as Callable).call(p)
		await frames(2)
		var spawned: int = root.get_children().filter(func(c): return c is WorldItem).size()
		check("Chest releases items", spawned == (kiste["items"] as Array).size(), "%d items" % spawned)

	await _test_all_items(p)
	await _test_emotes(p)
	await _test_voice(p)
	await _test_backpack(p)
	await _test_steps(p)
	_test_day_cycle()
	_test_weather()
	_test_brook()
	print("== %s: %d failures ==" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Every item: model, add, use, drop as a world item; plus the special effects
func _test_all_items(p: Wanderer) -> void:
	var inv := p.inventory
	for it in inv.items.duplicate():
		inv.remove(it)
	var bad := []
	for id in ItemDefs.ITEMS:
		var m := ItemModels.mesh(id)
		if m == null or m.get_surface_count() == 0 or m.get_aabb().size.length() < 0.02 or m.get_aabb().size.length() > 1.5:
			bad.append(id)
	check("All %d item models built" % ItemDefs.ITEMS.size(), bad.is_empty(), str(bad))
	var icons := ItemDefs.ITEMS.keys().filter(func(id): return ItemDefs.icon(id) == null)
	check("All item icons exist", icons.is_empty(), str(icons))
	var used := 0
	for id in ItemDefs.ITEMS:
		var it := ItemDefs.make(id)
		if not inv.add(it):
			continue
		p.body.food = 50.0
		p.body.water = 50.0
		p.use_item(it)
		used += 1
		if inv.items.has(it):
			p.drop_item(it)
		await frames(1)
	check("Every item can be used and dropped", used == ItemDefs.ITEMS.size(), "%d used" % used)
	for c in main.dropped.get_children():
		c.free()
	# charges: the cookie tin lasts three times
	var tin := ItemDefs.make("keks")
	inv.add(tin)
	p.use_item(tin)
	p.use_item(tin)
	check("Cookie tin has charges", inv.items.has(tin) and tin["charges"] == 1)
	p.use_item(tin)
	check("Cookie tin used up", not inv.items.has(tin))
	# warming drink and sunscreen timers
	var tea := ItemDefs.make("tee")
	inv.add(tea)
	p.use_item(tea)
	check("Tea warms", p.body.warm_bonus_t > 60.0)
	var sun := ItemDefs.make("sonnencreme")
	inv.add(sun)
	p.use_item(sun)
	check("Sunscreen protects", p.body.heat_protect_t > 100.0)
	# knife cuts a rope
	for it in inv.items.duplicate():
		inv.remove(it)
	var rope := ItemDefs.make("seil")
	inv.add(rope)
	var knife := ItemDefs.make("messer")
	inv.add(knife)
	p.use_item(knife)
	var ropes := inv.items.filter(func(i): return i["id"] == "seil")
	check("Knife cuts the rope in two", ropes.size() == 2 and ropes[0]["length"] == 5 and ropes[1]["length"] == 5)
	# lantern light on and off with dropping
	var lamp := ItemDefs.make("laterne")
	inv.add(lamp)
	p.use_item(lamp)
	check("Lantern gives light", p._light != null)
	p.drop_item(lamp)
	for i in 3:
		await get_tree().process_frame
	check("Light goes when the lantern is dropped", p._light == null)
	# walking stick lowers climbing effort
	inv.add(ItemDefs.make("stock"))
	await frames(3)
	check("Walking stick eases climbs", p.body.climb_factor < 1.0, "%.2f" % p.body.climb_factor)
	for c in main.dropped.get_children():
		c.free()


func _test_emotes(p: Wanderer) -> void:
	# back onto the dry trail
	var gen: WorldGen = main.gen
	var z: float = main.start_z - 20.0
	var x := gen.path_x(z)
	p.velocity = Vector3.ZERO
	p.global_position = main.world.world_to_local(Vector3(x, gen.height(x, z) + 0.3, z))
	for i in 120:
		await frames(1)
		if p.is_on_floor() and not p.in_water and i > 10:
			break
	var third_before := p.third_person
	p.play_emote("cheer")
	await frames(10)
	check("Emote plays", p.scout.emote_playing() == "cheer")
	p.autopilot = func() -> Vector3: return -p.global_basis.z
	for i in 60:
		await get_tree().process_frame
	p.autopilot = Callable()
	check("Walking cancels the emote", p.scout.emote_playing() == "")
	check("Emote camera returns to the previous view", p.third_person == third_before)
	p.velocity = Vector3.ZERO
	for i in 20:
		await frames(1)
	p.play_emote("sit")
	for i in 3:
		await get_tree().process_frame
	check("Sit emote rests", p.resting and p.scout.pose == Scout.Pose.SIT, "resting %s, pose %d, floor %s" % [p.resting, p.scout.pose, p.is_on_floor()])
	p.play_emote("wave")
	await get_tree().process_frame
	check("Another emote stands up again", not p.resting)
	var wheel: EmoteWheel = main.emote_wheel
	wheel.open()
	check("Emote wheel opens with 8 slots", wheel.is_open() and wheel._ids.size() == 8 and wheel._icons.all(func(t): return t != null))
	wheel.close(false)


## Backpack screen: slot grid, selection, use and drop through the buttons, HUD slot
func _test_backpack(p: Wanderer) -> void:
	var inv := p.inventory
	inv.add(ItemDefs.make("apfel"))
	inv.add(ItemDefs.make("keks"))
	var bp: Backpack = main.backpack
	bp.open(p)
	await frames(3)
	var slots := bp._grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	check("Backpack shows all slots", slots.size() == Inventory.SLOTS, "%d" % slots.size())
	check("Backpack card fits the window", bp._card.get_global_rect().size.x * bp._card.scale.x <= bp.get_viewport().get_visible_rect().size.x + 1.0)
	var keks: Dictionary = inv.items[inv.items.size() - 1]
	(slots[inv.items.size() - 1] as Button).pressed.emit()
	check("Selecting a slot shows the item", bp._selected == keks)
	var n := inv.items.size()
	var use: Button = bp._detail.get_children().filter(func(c): return c is Button and not c.is_queued_for_deletion())[0]
	use.pressed.emit()
	await frames(2)
	check("Use button eats a cookie from the tin", inv.items.size() == n and keks["charges"] == 2, "%d" % keks["charges"])
	var apfel: Dictionary = inv.items.filter(func(x): return x["id"] == "apfel")[0]
	bp._select(apfel)
	await frames(1)
	var drop: Button = null
	for c in bp._detail.get_children():
		if c is HBoxContainer and not c.is_queued_for_deletion():
			drop = c.get_child(1)
	drop.pressed.emit()
	await frames(2)
	check("Drop button drops the apple", not inv.items.has(apfel) and bp.is_open())
	check("HUD backpack slot knows the player", main.hud._pack.player == p)
	bp.close()
	for c in main.dropped.get_children():
		c.queue_free()


## Footsteps: ground kind, a print on soft ground, no print in water, sound players clean up
func _test_steps(p: Wanderer) -> void:
	var gen: WorldGen = main.gen
	var z: float = main.start_z - 12.0
	var x := gen.path_x(z)
	check("Path counts as path", gen.ground_kind(x, z) in ["path", "sand", "snow"], gen.ground_kind(x, z))
	check("Far off the path is not path", gen.ground_kind(x + 60.0, z) != "path", gen.ground_kind(x + 60.0, z))
	p.global_position = main.world.world_to_local(Vector3(x, gen.height(x, z) + 0.3, z))
	await frames(20)
	var fp: Footprints = main.footprints
	var before := fp._prints.filter(func(d): return d.visible).size()
	var foot := p.scout.find_child("FootL", true, false) as Node3D
	p._on_step(foot)
	var after := fp._prints.filter(func(d): return d.visible).size()
	var kind := p._ground_kind(foot.global_position)
	check("A step on the path leaves a print", after == before + 1 or kind in ["grass", "wood", "water"], "%s %d→%d" % [kind, before, after])
	await frames(40)
	check("Step sound players are freed", p.get_children().filter(func(c): return c is AudioStreamPlayer and not c.playing).size() == 0)


## Times of day: moods, sun/moon, sleep, speed
func _test_day_cycle() -> void:
	var d := DayCycle.new()
	d.hour = 23.0
	check("Night has stars and fireflies", d.mood()["stars"] > 0.9 and d.mood()["flies"] > 0.9)
	check("At night the light is the moon", d.light_dir(Vector3(0.4, -0.6, 0.7))[1] == true)
	d.hour = 12.5
	var sun: Vector3 = d.light_dir(Vector3(0.4, -0.6, 0.7))[0]
	check("At midday the sun keeps the biome's direction", sun.normalized().dot(Vector3(0.4, -0.6, 0.7).normalized()) > 0.99, str(sun))
	d.hour = 6.3
	check("Morning mist", d.mood()["mist"] > 0.8)
	d.hour = 21.0
	d.sleep()
	check("Sleeping through the night: morning", absf(d.hour - 6.4) < 0.01, "%.2f" % d.hour)
	d.hour = 12.0
	d.day_minutes = 36.0
	d.advance(60.0)
	check("A day minute passes at the right speed", absf((d.hour - 12.0) - (DayCycle.SUNSET - DayCycle.SUNRISE) / (36.0 * 0.8)) < 0.001, "%.3f h" % (d.hour - 12.0))
	var c := {"sun_dir": Vector3(0.4, -0.6, 0.7), "sun_color": Color(1, 0.9, 0.8), "sun_energy": 1.8, "zenith_color": Color(0.3, 0.6, 0.9),
		"horizon_color": Color(0.8, 0.9, 1.0), "ambient_energy": 0.5, "ambient_color": Color(0.6, 0.7, 0.5), "fog_color": Color(0.8, 0.9, 0.95),
		"cloud_shadow": Color(0.6, 0.7, 0.9), "exposure": 0.9, "sun_glow": 0.35, "temperature": 16.0}
	d.hour = 23.0
	var n := d.apply(c)
	check("Nights are darker and cooler", n["sun_energy"] < 0.8 and n["temperature"] < 11.0, "%.2f / %.1f °C" % [n["sun_energy"], n["temperature"]])
	c["rainbow"] = 0.8
	d.hour = 20.1
	check("No rainbow at dusk", float(d.apply(c)["rainbow"]) < 0.05, "%.2f" % float(d.apply(c)["rainbow"]))
	d.hour = 12.5
	check("The biome's rainbow by day", float(d.apply(c)["rainbow"]) > 0.5)


## Weather: a whole shower cycle, wet ground, rainbow, desert stays dry
func _test_weather() -> void:
	var w := Weather.new()
	w.reset()
	w.next_shower = 0.0
	var began := false
	var max_rain := 0.0
	var max_rb := 0.0
	for i in 6000:
		if w.advance(0.1, 1.0):
			began = true
		max_rain = maxf(max_rain, w.rain)
		max_rb = maxf(max_rb, w.rainbow)
		if began and w.state == Weather.FAIR:
			break
	check("A shower begins and ends", began and w.state == Weather.FAIR, "state %d" % w.state)
	check("It rained and the ground got wet", max_rain > 0.4, "%.2f" % max_rain)
	check("A rainbow after the shower", max_rb > 0.5, "%.2f" % max_rb)
	var d := Weather.new()
	d.reset()
	d.next_shower = 0.0
	for i in 3000:
		d.advance(0.1, 0.0)
	check("No rain in the desert", d.rain < 0.01 and d.state == Weather.FAIR)
	# snow instead of rain in the mountains: white ground, no rainbow, dry-ish
	var sn := Weather.new()
	sn.reset()
	sn.next_shower = 0.0
	var max_cover := 0.0
	var max_rb2 := 0.0
	for i in 6000:
		sn.advance(0.1, 1.0, 0.0, 1.0)
		max_cover = maxf(max_cover, sn.snow_cover)
		max_rb2 = maxf(max_rb2, sn.rainbow)
	check("Snowfall covers the ground", max_cover > 0.5, "%.2f" % max_cover)
	check("No rainbow after snow", max_rb2 < 0.05, "%.2f" % max_rb2)
	# a fog day comes, stays and lifts again
	var fg := Weather.new()
	fg.reset()
	fg.next_shower = 99999.0
	fg.next_fog = 0.0
	var max_fog := 0.0
	var lifted := false
	for i in 12000:
		fg.advance(0.1, 1.0, 1.0)
		max_fog = maxf(max_fog, fg.fog)
		if max_fog > 0.9 and fg.state == Weather.FAIR and fg.fog < 0.05:
			lifted = true
			break
	check("A fog day rises and lifts", max_fog > 0.9 and lifted, "fog %.2f" % max_fog)
	var shown := fg.apply({"fog_color": Color(0.8, 0.9, 0.95), "fog_density": 0.002, "sun_energy": 1.8, "sun_glow": 0.3,
		"horizon_color": Color(0.8, 0.9, 1.0), "zenith_color": Color(0.2, 0.5, 0.9), "ambient_energy": 0.5, "cloud_coverage": 0.5,
		"cirrus_amount": 0.5, "cloud_shadow": Color(0.6, 0.7, 0.8), "ambient_color": Color(0.6, 0.7, 0.6)})
	check("Fog day state is applied", shown.has("overcast"))
	# heat lightning flickers only when there is some
	var hl := Weather.new()
	var flashes := 0
	for i in 3000:
		hl.advance_flash(0.05, 1.0)
		if hl.flash > 0.5:
			flashes += 1
	var none := Weather.new()
	var none_flash := 0.0
	for i in 3000:
		none.advance_flash(0.05, 0.0)
		none_flash = maxf(none_flash, none.flash)
	check("Heat lightning flickers on warm evenings", flashes > 0 and none_flash == 0.0, "%d frames" % flashes)


## A brook: carved bed under water, banks above it, water found by water_level
func _test_brook() -> void:
	var gen: WorldGen = main.gen
	var b := {}
	for k in range(1, 80):
		b = gen.brook(k)
		if not b.is_empty():
			break
	check("There are brooks", not b.is_empty())
	if b.is_empty():
		return
	var z: float = (float(b["z0"]) + float(b["z1"])) * 0.5
	var r := gen.row(z)
	var c := gen.brook_center(b, r)
	var lvl := gen.brook_level(b, r, c.x)
	var bed := gen.height_in_row(c.x, r)
	var bank := gen.height_in_row(c.x + float(b["side"]) * 4.0 / r["inv_len"], r)
	check("Brook bed lies under the water", bed < lvl - 0.3, "bed %.2f water %.2f" % [bed, lvl])
	check("Brook banks rise above the water", bank > lvl, "bank %.2f" % bank)
	check("water_level finds the brook", absf(gen.water_level(c.x, z) - lvl) < 0.01)


func _test_voice(p: Wanderer) -> void:
	# gate logic with synthetic levels (threshold -38 dB)
	var v: Node = Voice
	var g := func(mode: int, db: float, share: float, key: bool, dt: float) -> bool: return v.gate(mode, db, share, -38.0, key, dt)
	check("Voice activation opens on speech", g.call(2, -25.0, 0.8, false, 0.016))
	var still := true
	for i in 12:
		still = still and g.call(2, -70.0, 0.8, false, 0.016)
	check("Voice activation holds briefly", still)
	var closed := false
	for i in 30:
		closed = not g.call(2, -70.0, 0.8, false, 0.016)
	check("Voice activation closes after silence", closed)
	# (the live microphone may be transmitting right now: test the gate from a closed state)
	var was: bool = v.transmitting
	v.transmitting = false
	check("Noise without voice does not open", not g.call(2, -20.0, 0.1, false, 0.016))
	v.transmitting = was
	check("Push to talk needs the key", g.call(0, -70.0, 0.0, true, 0.016) and not g.call(0, -10.0, 0.9, false, 0.016))
	check("Always on", g.call(1, -80.0, 0.0, false, 0.016))
	# lip sync with a fake signal
	var old_mode = Settings.values["voice_mode"]
	Settings.values["voice_mode"] = 1
	v.fake_db = -18.0
	var opened := false
	for i in 40:
		await get_tree().process_frame
		opened = opened or p.scout._face_state.begins_with("dot/open") or p.scout._face_state.contains("/open/")
	check("Talking moves the scout's mouth", v.transmitting and v.mouth > 0.05 and opened, "mouth %.2f face %s" % [v.mouth, p.scout._face_state])
	v.fake_db = NAN
	Settings.values["voice_mode"] = old_mode
	for i in 10:
		await get_tree().process_frame
