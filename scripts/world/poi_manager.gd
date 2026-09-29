class_name PoiManager
extends Node
## Find spots along the path: deterministic from the seed, appear with the near chunks.
## Things already taken are remembered and don't show up again.

const CELL := 170.0

var gen: WorldGen
var world: ChunkManager
var lib: AssetLibrary
## uid -> true for collected items and opened/harvested find spots
var taken := {}
var _mats := {}

const TYPES := [
	["picknick", 18], ["rucksack", 14], ["bank", 16], ["quelle", 12], ["kiste", 12],
	["beeren", 14], ["fund", 4], ["schild", 10], ["unterstand", 6], ["lagerfeuer", 9],
]
const PLACES := ["Somewhere", "Nowhere", "Further", "Past the Horizon", "Almost There", "A Bit More",
	"Grandma", "Kiosk", "North Pole", "To the Sea", "Mountain Lake", "Lunch Break", "Back? Nope."]


func setup(p_gen: WorldGen, p_world: ChunkManager, p_lib: AssetLibrary) -> void:
	gen = p_gen
	world = p_world
	lib = p_lib
	world.chunk_ready.connect(_on_chunk_ready)


# ================================================================ Planning

func poi(k: int) -> Dictionary:
	return plan(gen, k)


## Pure function (thread-safe): find spot in cell k or {}
static func plan(gen: WorldGen, k: int) -> Dictionary:
	if k < 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen.seed_value, k, 404])
	var z := -(k + 0.3 + rng.randf() * 0.4) * CELL
	if k == 0:
		z = -14.0
	elif rng.randf() > 0.8:
		return {}
	var type := "schild" if k == 0 else _weighted(rng)
	if k != 0 and gen.obstacle_zone(z, 45.0):
		return {}
	var r := gen.row(z)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var off: float = r["half_w"] + rng.randf_range(2.2, 4.0)
	# rainy biomes have more shelters (decided after the other rolls, so other worlds keep their find spots)
	var rainy: float = gen.biomes[gen.dominant_biome(z)]["atmosphere"].get("rain", 1.0)
	if type in ["kiste", "fund"] and rainy >= 1.1 and hash([gen.seed_value, k, 17]) % 3 == 0:
		type = "unterstand"
	if type == "schild":
		off = r["half_w"] + 1.2
	elif type == "unterstand":
		off = r["half_w"] + 3.2
	elif type == "lagerfeuer":
		off = r["half_w"] + rng.randf_range(4.0, 5.5)
	var x: float = r["px"] + side * off / r["inv_len"]
	if gen.water_level(x, z) > -INF:
		return {}
	var biome := gen.dominant_biome(z)
	# the shelter's open side faces the path
	var yaw := rng.randf() * TAU
	if type == "unterstand":
		yaw = atan2(-side, 0.0)
	return {"k": k, "type": type, "x": x, "z": z, "side": side, "yaw": yaw,
		"items": _loot(type, biome, rng), "seed": rng.randi()}


static func _weighted(rng: RandomNumberGenerator) -> String:
	var total := 0
	for t in TYPES:
		total += t[1]
	var roll := rng.randi() % total
	for t in TYPES:
		roll -= t[1]
		if roll < 0:
			return t[0]
	return "picknick"


static func _loot(type: String, biome: int, rng: RandomNumberGenerator) -> Array:
	var cold := biome in [6, 7, 14, 20]  # Mountain Pines, Deadwood Bog, Heather Highlands, Rock Gorge
	var hot := biome in [2, 12, 17]      # Desert Valley, Lavender Hills, Wheat Fields
	var forest := biome in [1, 5, 10, 13, 15, 16, 19, 21] # Forest Trail, Red Maple Wood, Glowing Forest, Birch Wood, Giants' Old Forest, Mushroom Wood
	var coast := biome == 8              # Sunset Coast
	var food := ["apfel", "apfel", "brot", "muesliriegel", "bohnen", "beeren", "kaese", "sandwich", "schokolade",
		"trockenobst", "moehre", "keks", "honig", "glueckskeks", "marshmallows"]
	if forest:
		food += ["pilze", "pilze", "beeren"]
	var drink := ["wasserflasche", "limonade", "saft"]
	if hot:
		drink += ["wasserflasche", "saft", "wasserflasche"]
	if biome == 12:
		food += ["honig", "honig"]
	if cold:
		drink += ["tee", "kakao", "tee"]
	var gear := ["verband", "seil", "taschenlampe", "fernglas", "feldhandbuch", "kamera", "kompass", "karte", "messer",
		"stock", "laterne", "pflaster", "erste_hilfe", "pfeife", "streichhoelzer", "feuerzeug"]
	var clothes := ["regenjacke", "pullover", "muetze", "poncho", "schal", "handschuhe", "stiefel"]
	if hot:
		clothes = ["sonnenhut", "sonnenhut", "sonnencreme", "sonnencreme", "stiefel", "poncho"]
	if cold:
		clothes = ["pullover", "muetze", "regenjacke", "pullover", "schal", "handschuhe", "stiefel"]
	var fun := ["wasserpistole", "gummihuhn", "kamera", "fernglas", "stein", "mundharmonika", "drachen", "federn", "pfeife", "kiesel", "kiesel"]
	if coast:
		fun += ["muschel", "muschel", "muschel", "drachen"]
	if biome == 6:
		fun += ["tannenzapfen", "tannenzapfen"]
	var out := []
	var pick := func(list: Array) -> String: return list[rng.randi() % list.size()]
	match type:
		"picknick":
			for i in rng.randi_range(2, 4):
				out.append(pick.call(food))
			out.append(pick.call(drink))
		"rucksack":
			out.append(pick.call(clothes))
			out.append(pick.call(gear))
			if rng.randf() < 0.6:
				out.append(pick.call(food))
		"kiste":
			out.append(pick.call(gear))
			out.append(pick.call(clothes))
			if rng.randf() < 0.5:
				out.append(pick.call(["verband", "pflaster", "erste_hilfe"]))
		"bank":
			if rng.randf() < 0.35:
				out.append(pick.call(food))
		"fund":
			out.append(pick.call(fun))
	return out


# ================================================================ Building

func _on_chunk_ready(coord: Vector2i, node: Node3D, lod: int) -> void:
	if lod != 0:
		return
	var z0 := coord.y * ChunkBuilder.SIZE
	var z1 := z0 + ChunkBuilder.SIZE
	var k0 := floori(-z1 / CELL) - 1
	var k1 := floori(-z0 / CELL) + 1
	for k in range(maxi(k0, 0), k1 + 1):
		var p := poi(k)
		if p.is_empty():
			continue
		if p["x"] < coord.x * ChunkBuilder.SIZE or p["x"] >= (coord.x + 1) * ChunkBuilder.SIZE or p["z"] < z0 or p["z"] >= z1:
			continue
		node.add_child(_build(p, Vector2(coord.x * ChunkBuilder.SIZE, z0)))


func _uid(p: Dictionary, i: int) -> int:
	return (hash([gen.seed_value, p["k"], i, 77]) & 0xffffffff) | (1 << 33)


func _mat(color: Color, rough := 0.85) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _model(parent: Node3D, mesh: Mesh, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build(p: Dictionary, corner: Vector2) -> Node3D:
	var root := Node3D.new()
	var x: float = p["x"]
	var z: float = p["z"]
	root.position = Vector3(x - corner.x, gen.height(x, z), z - corner.y)
	root.rotation.y = p["yaw"]
	var items: Array = p["items"]
	var spots: Array[Vector3] = []
	match p["type"]:
		"picknick":
			_model(root, StructureModels.picnic_blanket(), Vector3(0, 0.02, 0))
			_model(root, StructureModels.basket(), Vector3(0.6, 0.03, -0.4), 0.4)
			spots = [Vector3(-0.4, 0.2, 0.2), Vector3(0.0, 0.2, -0.2), Vector3(0.3, 0.2, 0.35), Vector3(-0.2, 0.2, -0.45), Vector3(0.45, 0.2, 0.1)]
		"rucksack":
			var packs := [Color("4f8f4a"), Color("d1493f"), Color("3f5fae"), Color("ec8a34"), Color("8b5a36")]
			_model(root, StructureModels.lost_pack(packs[int(p["seed"]) % packs.size()]), Vector3.ZERO, 0.4)
			spots = [Vector3(0.5, 0.2, 0.1), Vector3(-0.45, 0.2, 0.25), Vector3(0.15, 0.2, 0.55)]
		"bank":
			var body := StaticBody3D.new()
			root.add_child(body)
			_model(body, StructureModels.bench(), Vector3.ZERO)
			Songbirds.mark(root, Vector3(0.55, 0.92, -0.28))
			Songbirds.mark(root, Vector3(-0.6, 0.92, -0.28))
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.6, 0.5, 0.45)
			cs.shape = shape
			cs.position.y = 0.25
			body.add_child(cs)
			_interactable(root, Vector3(0, 0.6, 0), Vector3(1.6, 0.8, 0.6), "Sit on the bench", func(w: Wanderer):
				if not w.resting:
					w.resting = true
					w.body.rest = minf(w.body.rest + 5.0, 100.0)
					w.message.emit("What a view."))
			spots = [Vector3(0.3, 0.6, 0.0)]
		"quelle":
			_model(root, StructureModels.spring_stones(int(p["seed"]) % 4), Vector3(0, -0.04, 0))
			var pool := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.66
			disc.bottom_radius = 0.66
			disc.height = 0.02
			pool.mesh = disc
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.25, 0.6, 0.75)
			wm.roughness = 0.05
			wm.metallic_specular = 0.9
			wm.emission_enabled = true
			wm.emission = Color(0.12, 0.35, 0.45)
			pool.material_override = wm
			pool.position.y = 0.08
			root.add_child(pool)
			_interactable(root, Vector3(0, 0.3, 0), Vector3(1.5, 0.6, 1.5), "Drink spring water", func(w: Wanderer):
				w.body.water = minf(w.body.water + 40.0, 100.0)
				for it in w.inventory.items:
					if ItemDefs.def(it["id"]).get("refill", false):
						it["charges"] = ItemDefs.def(it["id"])["charges"]
				w.inventory.changed.emit()
				w.message.emit("Ice-cold spring water. Bottles are full."))
		"kiste":
			var box := StaticBody3D.new()
			root.add_child(box)
			_model(box, StructureModels.chest_body(), Vector3.ZERO)
			var cs2 := CollisionShape3D.new()
			var sh2 := BoxShape3D.new()
			sh2.size = Vector3(0.8, 0.56, 0.55)
			cs2.shape = sh2
			cs2.position.y = 0.28
			box.add_child(cs2)
			var box_uid := _uid(p, 99)
			if not taken.has(box_uid):
				var it_list := items.duplicate()
				_interactable(root, Vector3(0, 0.4, 0), Vector3(0.9, 0.7, 0.7), "Open chest", func(w: Wanderer):
					taken[box_uid] = true
					for i in it_list.size():
						var uid := _uid(p, i)
						if taken.has(uid):
							continue
						var wi := _spawn(root, ItemDefs.make(it_list[i], uid), Vector3(0.0, 0.7, 0.0))
						wi.linear_velocity = Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(-1.5, 1.5))
					w.message.emit("Creak. There's something inside!")
					for c in root.get_children():
						if c.has_meta("poi_prompt"):
							c.queue_free())
			items = []
		"beeren":
			var bush := MeshInstance3D.new()
			bush.mesh = lib.mesh("Bush_Common", {"leaves": {"color_dark": Color(0.15, 0.4, 0.08), "color_light": Color(0.45, 0.72, 0.16), "sphere_normals": 0.85}, "stiffness": 6.0})
			bush.scale = Vector3.ONE * 1.3
			root.add_child(bush)
			var bush_uid := _uid(p, 98)
			if not taken.has(bush_uid):
				var berries := Node3D.new()
				root.add_child(berries)
				var rng := RandomNumberGenerator.new()
				rng.seed = p["seed"]
				var bmesh := SphereMesh.new()
				bmesh.radius = 0.045
				bmesh.height = 0.09
				bmesh.radial_segments = 8
				bmesh.rings = 4
				for i in 22:
					var b := MeshInstance3D.new()
					b.mesh = bmesh
					b.material_override = _mat(Color(0.45, 0.1, 0.5), 0.3)
					var a := rng.randf() * TAU
					b.position = Vector3(cos(a) * rng.randf_range(0.6, 1.05), rng.randf_range(0.5, 1.3), sin(a) * rng.randf_range(0.6, 1.05))
					berries.add_child(b)
				_interactable(root, Vector3(0, 0.8, 0), Vector3(2.2, 1.6, 2.2), "Pick berries", func(w: Wanderer):
					var n := 0
					for i in 3:
						if w.inventory.add(ItemDefs.make("beeren")):
							n += 1
					if n == 0:
						w.message.emit("No room in the backpack.")
						return
					taken[bush_uid] = true
					berries.queue_free()
					w.message.emit("Picked %d handfuls of berries." % n)
					for c in root.get_children():
						if c.has_meta("poi_prompt"):
							c.queue_free())
		"fund":
			var rock := MeshInstance3D.new()
			rock.mesh = lib.mesh("Rock_Medium_2", {"rock": {"flatten": 0.5, "flat_color": Color(0.7, 0.7, 0.68), "moss_amount": 0.4}})
			rock.scale = Vector3.ONE * 0.35
			root.add_child(rock)
			spots = [Vector3(0.7, 0.2, 0.2)]
		"schild":
			_signpost(root, p)
		"unterstand":
			_shelter(root)
		"lagerfeuer":
			_campfire(root, p)
	for i in items.size():
		var uid := _uid(p, i)
		if taken.has(uid) or i >= spots.size():
			continue
		_spawn(root, ItemDefs.make(items[i], uid), spots[i])
	return root


## Campfire: a fire ring with a woodpile and two log seats; light it, sit by it, roast marshmallows
func _campfire(root: Node3D, p: Dictionary) -> void:
	_model(root, StructureModels.fire_ring(int(p["seed"]) % 5), Vector3.ZERO)
	var fire := Campfire.new()
	fire.uid = _uid(p, 97)
	root.add_child(fire)
	var body := StaticBody3D.new()
	root.add_child(body)
	_model(body, StructureModels.woodpile(), Vector3(1.55, 0, -0.7), 0.3)
	_model(body, StructureModels.seat_log(1.6), Vector3(0, 0, 1.7))
	_model(body, StructureModels.seat_log(1.4), Vector3(-1.7, 0, -0.1), PI * 0.5)
	for bx in [[Vector3(0.75, 0.6, 0.8), Vector3(1.55, 0.3, -0.7)], [Vector3(1.6, 0.4, 0.42), Vector3(0, 0.2, 1.7)], [Vector3(0.42, 0.4, 1.4), Vector3(-1.7, 0.2, -0.1)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[0]
		cs.shape = sh
		cs.position = bx[1]
		body.add_child(cs)
	Songbirds.mark(root, Vector3(-0.5, 0.42, 1.7))
	var prompt := func(w: Wanderer) -> String:
		if fire.is_burning():
			return "Roast marshmallows" if _find(w, "marshmallows") else "Sit by the fire"
		return "Light the fire"
	_interactable(root, Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), prompt, func(w: Wanderer):
		if fire.is_burning():
			var mm := _find(w, "marshmallows")
			if not mm.is_empty():
				mm["charges"] -= 1
				w.body.food = minf(w.body.food + 14.0, 100.0)
				w.body.stamina = minf(w.body.stamina + 20.0, w.body.max_stamina())
				if mm["charges"] <= 0:
					w.inventory.remove(mm)
				else:
					w.inventory.changed.emit()
				w.message.emit("Golden brown and gooey. The best thing on the whole trail.")
			if not w.resting:
				w.resting = true
			if mm.is_empty():
				w.message.emit("You sit down by the crackling fire. Warm at last.")
			return
		_light_fire(w, fire))


func _find(w: Wanderer, id: String) -> Dictionary:
	for it in w.inventory.items:
		if it["id"] == id and it["condition"] >= 0.35 and it.get("charges", 1) > 0:
			return it
	return {}


func _light_fire(w: Wanderer, fire: Campfire) -> void:
	var lighter := _find(w, "feuerzeug")
	var matches := _find(w, "streichhoelzer")
	if lighter.is_empty() and matches.is_empty():
		w.message.emit("You need matches or a lighter to light the fire.")
		return
	if lighter.is_empty() and matches.get("wet", false):
		w.message.emit("The matches are soaked. They won't light.")
		return
	if lighter.is_empty():
		matches["charges"] -= 1
		if matches["charges"] <= 0:
			w.inventory.remove(matches)
		else:
			w.inventory.changed.emit()
	# heavy rain puts the flame out (unless the fire ring is under a roof)
	var main := w.get_tree().current_scene
	var weather: Weather = main.atmosphere.weather if main and "atmosphere" in main else null
	if weather and weather.rain * (1.0 - weather.snow_share) > 0.45:
		w.message.emit("The rain puts the little flame out. Maybe when it eases off.")
		return
	fire.light()
	w.message.emit("The kindling catches – the fire crackles to life.")


## Rain shelter: walls and roof collide, under the roof you stay dry (group "shelter"), rain stops at the roof
func _shelter(root: Node3D) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	_model(body, StructureModels.shelter(), Vector3.ZERO)
	var boxes := [
		[Vector3(0.2, 2.0, 0.2), Vector3(-1.28, 1.0, -0.88)], [Vector3(0.2, 2.0, 0.2), Vector3(1.28, 1.0, -0.88)],
		[Vector3(0.2, 2.0, 0.2), Vector3(-1.28, 1.0, 0.88)], [Vector3(0.2, 2.0, 0.2), Vector3(1.28, 1.0, 0.88)],
		[Vector3(2.6, 1.6, 0.12), Vector3(0, 0.85, -0.9)], [Vector3(2.4, 0.5, 0.4), Vector3(0, 0.25, -0.62)],
		[Vector3(3.3, 0.3, 2.8), Vector3(0, 2.45, 0)],
	]
	for bx in boxes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[0]
		cs.shape = sh
		cs.position = bx[1]
		body.add_child(cs)
	# rain and snow particles stop at the roof
	var roof := GPUParticlesCollisionBox3D.new()
	roof.size = Vector3(3.4, 0.9, 2.8)
	roof.position = Vector3(0, 2.3, 0)
	root.add_child(roof)
	# a warm lantern glow at night
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.6, 2.2, 0)
	lamp.light_color = Color(1.0, 0.78, 0.45)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.5
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 40.0
	lamp.distance_fade_length = 15.0
	root.add_child(lamp)
	var dry := Node3D.new()
	dry.add_to_group("shelter")
	root.add_child(dry)
	Songbirds.mark(root, Vector3(-1.5, 2.8, 0.0))
	_interactable(root, Vector3(0, 0.6, -0.4), Vector3(2.4, 1.2, 1.0), "Wait out the rain", func(w: Wanderer):
		if not w.resting:
			w.resting = true
			w.body.rest = minf(w.body.rest + 5.0, 100.0)
			w.message.emit("Dry and cozy. The rain drums on the roof."))


func _spawn(root: Node3D, item: Dictionary, local_pos: Vector3) -> WorldItem:
	var wi := WorldItem.create(item)
	wi.world_ref = world
	wi.position = local_pos
	wi.rotation.y = randf() * TAU
	wi.tree_exiting.connect(func():
		if wi.has_meta("taken"):
			taken[item["uid"]] = true)
	root.add_child(wi)
	return wi


## prompt: a text or a Callable(Wanderer) -> String for prompts that change (e.g. a fire that burns or not)
func _interactable(root: Node3D, pos: Vector3, size: Vector3, prompt: Variant, action: Callable) -> void:
	var area := Area3D.new()
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("poi_prompt", prompt)
	area.set_meta("poi_action", action)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	area.position = pos
	root.add_child(area)


func _signpost(root: Node3D, p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p["seed"]
	root.rotation.y = 0.0
	_model(root, StructureModels.signpost_post(), Vector3.ZERO)
	Songbirds.mark(root, Vector3(0, 2.2, 0))
	var names := PLACES.duplicate()
	for i in 2:
		var arm := Node3D.new()
		arm.position = Vector3(0, 1.75 - i * 0.36, 0)
		arm.rotation.y = rng.randf_range(-0.6, 0.6) + (PI if i == 1 else 0.0)
		root.add_child(arm)
		_model(arm, StructureModels.sign_arrow(1.2), Vector3(0.05, 0, 0))
		var label := Label3D.new()
		var place: String = names.pop_at(rng.randi() % names.size())
		label.text = "%s  %d km" % [place, rng.randi_range(2, 999)] if p["k"] != 0 else ("Fern  ∞ km" if i == 0 else "Home  0 km")
		label.font_size = 36
		label.pixel_size = 0.004
		label.modulate = Color(0.25, 0.18, 0.12)
		label.outline_size = 0
		label.position = Vector3(0.52, 0, 0.026)
		arm.add_child(label)
		var back := label.duplicate()
		back.position = Vector3(0.52, 0, -0.026)
		back.rotation.y = PI
		arm.add_child(back)


func _checker() -> ImageTexture:
	if _mats.has("checker"):
		return _mats["checker"]
	var img := Image.create(8, 8, true, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color(0.85, 0.2, 0.18) if (x / 2 + y / 2) % 2 == 0 else Color(0.96, 0.94, 0.9))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_mats["checker"] = t
	return t
