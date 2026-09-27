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
	check("Starting gear", inv.items.size() == 3, "%d items" % inv.items.size())
	check("Weight", absf(inv.total_weight() - 1.3) < 0.01, "%.2f kg" % inv.total_weight())

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
	check("Noise without voice does not open", not g.call(2, -20.0, 0.1, false, 0.016))
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
