class_name ItemDefs
extends RefCounted
## All items: weight, properties, effect and look.
##
## Properties: wasserfest (waterproof), zerbrechlich (fragile), verderblich (perishable), warm, elektrisch (electric), schwimmt (floats)
## Kinds: essen (food), trinken (drink), medizin (medicine), kleidung (clothing), werkzeug (tool), spass (fun), kram (stuff)

const ITEMS := {
	"apfel": {"name": "Apple", "weight": 0.2, "kind": "essen", "food": 16, "water": 4, "props": ["verderblich", "schwimmt"], "desc": "Crunchy and a little sour."},
	"beeren": {"name": "Berries", "weight": 0.1, "kind": "essen", "food": 9, "water": 3, "charges": 1, "stack": 8, "props": ["verderblich"], "desc": "Hopefully the edible kind. Picked by hand, bunch by bunch."},
	"brot": {"name": "Bread", "weight": 0.4, "kind": "essen", "food": 32, "props": ["verderblich"], "desc": "A bit dry, but filling."},
	"muesliriegel": {"name": "Granola bar", "weight": 0.1, "kind": "essen", "food": 18, "props": ["wasserfest"], "desc": "Chocolate with oats."},
	"bohnen": {"name": "Can of beans", "weight": 0.5, "kind": "essen", "food": 45, "props": ["wasserfest"], "desc": "They taste fine cold, too."},
	"wasserflasche": {"name": "Water bottle", "weight": 1.0, "kind": "trinken", "water": 35, "charges": 3, "refill": true,
		"props": ["wasserfest", "schwimmt"],
		"desc": "Can be refilled at springs and lakes."},
	"limonade": {"name": "Lemonade", "weight": 0.5, "kind": "trinken", "water": 28, "food": 4, "props": ["zerbrechlich"], "desc": "Glass bottle. Don't drop it."},
	"verband": {"name": "Bandage", "weight": 0.1, "kind": "medizin", "heal": 40, "props": [], "desc": "Stops bleeding and lifts the spirits."},
	"regenjacke": {"name": "Rain jacket", "weight": 0.8, "kind": "kleidung", "warmth": 10, "slot": "koerper", "props": ["wasserfest", "warm"], "desc": "Keeps out wind and rain."},
	"pullover": {"name": "Wool sweater", "weight": 0.7, "kind": "kleidung", "warmth": 14, "slot": "koerper", "props": ["warm"], "desc": "Itchy, but warm."},
	"muetze": {"name": "Wool hat", "weight": 0.2, "kind": "kleidung", "warmth": 6, "slot": "kopf", "props": ["warm"], "desc": "With a pompom."},
	"sonnenhut": {"name": "Sun hat", "weight": 0.2, "kind": "kleidung", "warmth": -8, "slot": "kopf", "props": [], "desc": "Protects against the heat."},
	"seil": {"name": "Rope", "weight": 2.0, "kind": "werkzeug", "props": ["wasserfest"], "desc": "For whatever you'll need it for later."},
	"taschenlampe": {"name": "Flashlight", "weight": 0.4, "kind": "werkzeug", "props": ["elektrisch", "zerbrechlich"], "desc": "For the night."},
	"fernglas": {"name": "Binoculars", "weight": 0.6, "kind": "werkzeug", "props": ["zerbrechlich"], "desc": "Right mouse button to look through."},
	"kamera": {"name": "Camera", "weight": 0.9, "kind": "spass", "props": ["elektrisch", "zerbrechlich"], "desc": "Use it to take a photo of the journey."},
	"feldhandbuch": {"name": "Field guide", "weight": 0.5, "kind": "werkzeug", "props": [], "desc": "Has anyone read it?"},
	"wasserpistole": {"name": "Water pistol", "weight": 0.3, "kind": "spass", "props": ["wasserfest", "schwimmt"], "desc": "Oh."},
	"gummihuhn": {"name": "Rubber chicken", "weight": 0.2, "kind": "spass", "props": ["wasserfest", "schwimmt"], "desc": "Squeaks."},
	"stein": {"name": "Pretty stone", "weight": 1.2, "kind": "kram", "props": ["wasserfest"], "desc": "Completely useless. Beautiful."},
	# ---------------------------------------------------------------- round 10
	"kaese": {"name": "Cheese wedge", "weight": 0.3, "kind": "essen", "food": 22, "props": ["verderblich"], "desc": "Holey and happy."},
	"pilze": {"name": "Mushrooms", "weight": 0.1, "kind": "essen", "food": 8, "queasy": 0.2, "charges": 1, "stack": 6, "props": ["verderblich"], "desc": "Probably fine. Probably."},
	"honig": {"name": "Jar of honey", "weight": 0.4, "kind": "essen", "food": 20, "water": 5, "props": ["zerbrechlich"], "desc": "Sticky fingers guaranteed."},
	"trockenobst": {"name": "Dried fruit", "weight": 0.15, "kind": "essen", "food": 14, "props": ["wasserfest"], "desc": "Chewy apricots and cranberries."},
	"schokolade": {"name": "Chocolate bar", "weight": 0.1, "kind": "essen", "food": 12, "stamina": 18, "props": [], "desc": "Instant morale boost."},
	"sandwich": {"name": "Sandwich", "weight": 0.3, "kind": "essen", "food": 28, "props": ["verderblich"], "desc": "Cheese, tomato, lettuce. A classic."},
	"moehre": {"name": "Carrot", "weight": 0.1, "kind": "essen", "food": 8, "water": 2, "props": ["schwimmt"], "desc": "Good for your eyes, they say."},
	"keks": {"name": "Cookie tin", "weight": 0.4, "kind": "essen", "food": 10, "charges": 3, "props": ["wasserfest"], "desc": "Three cookies left. Sharing is caring."},
	"tee": {"name": "Thermos of tea", "weight": 0.9, "kind": "trinken", "water": 20, "warm_time": 90.0, "charges": 2, "props": ["wasserfest"], "desc": "Hot tea. Warms you from the inside."},
	"kakao": {"name": "Cocoa", "weight": 0.3, "kind": "trinken", "water": 15, "food": 8, "warm_time": 60.0, "props": ["wasserfest"], "desc": "Just add hot water. Or eat it dry."},
	"saft": {"name": "Juice box", "weight": 0.25, "kind": "trinken", "water": 18, "food": 5, "props": [], "desc": "Apple-orange. With a tiny straw."},
	"pflaster": {"name": "Plasters", "weight": 0.05, "kind": "medizin", "heal": 15, "props": [], "desc": "For the small scrapes."},
	"erste_hilfe": {"name": "First aid kit", "weight": 0.8, "kind": "medizin", "heal": 70, "charges": 2, "props": ["wasserfest"], "desc": "Proper medical care. Twice."},
	"sonnencreme": {"name": "Sunscreen", "weight": 0.2, "kind": "medizin", "heat_protect": 180.0, "props": [], "desc": "Keeps the heat off for a while."},
	"schal": {"name": "Scarf", "weight": 0.2, "kind": "kleidung", "warmth": 6, "slot": "hals", "props": ["warm"], "desc": "Knitted by someone who loves you."},
	"handschuhe": {"name": "Gloves", "weight": 0.2, "kind": "kleidung", "warmth": 5, "slot": "haende", "props": ["warm"], "desc": "Warm hands, better grip on ropes."},
	"stiefel": {"name": "Hiking boots", "weight": 1.2, "kind": "kleidung", "warmth": 4, "slot": "fuesse", "props": ["wasserfest"], "desc": "Climbing costs less effort."},
	"poncho": {"name": "Rain poncho", "weight": 0.4, "kind": "kleidung", "warmth": 4, "slot": "koerper", "props": ["wasserfest"], "desc": "Stylish? No. Dry? Yes."},
	"kompass": {"name": "Compass", "weight": 0.15, "kind": "werkzeug", "props": ["wasserfest"], "desc": "Tells you which way the trail goes."},
	"karte": {"name": "Trail map", "weight": 0.1, "kind": "werkzeug", "props": [], "desc": "Shows what lies ahead."},
	"messer": {"name": "Pocket knife", "weight": 0.1, "kind": "werkzeug", "props": ["wasserfest"], "desc": "Cuts a rope in two."},
	"stock": {"name": "Walking stick", "weight": 0.6, "kind": "werkzeug", "props": ["schwimmt"], "desc": "Uphill feels a little easier with it."},
	"laterne": {"name": "Lantern", "weight": 0.9, "kind": "werkzeug", "props": ["zerbrechlich"], "desc": "A warm light for dark forests."},
	"pfeife": {"name": "Whistle", "weight": 0.03, "kind": "spass", "props": ["wasserfest"], "desc": "Loud. Very loud."},
	"mundharmonika": {"name": "Harmonica", "weight": 0.1, "kind": "spass", "props": [], "desc": "Play it while resting – you recover faster."},
	"drachen": {"name": "Kite", "weight": 0.5, "kind": "spass", "props": [], "desc": "Needs a bit of wind."},
	"federn": {"name": "Feather", "weight": 0.01, "kind": "kram", "props": ["schwimmt"], "desc": "Light as, well, a feather."},
	"muschel": {"name": "Seashell", "weight": 0.1, "kind": "kram", "props": ["wasserfest"], "desc": "Hold it to your ear."},
	"tannenzapfen": {"name": "Pinecone", "weight": 0.05, "kind": "kram", "props": ["schwimmt"], "desc": "Smells like a forest. Burns well."},
	"glueckskeks": {"name": "Fortune cookie", "weight": 0.02, "kind": "essen", "food": 3, "props": [], "desc": "There's a little note inside."},
	# ---------------------------------------------------------------- round 12
	"streichhoelzer": {"name": "Matches", "weight": 0.05, "kind": "werkzeug", "charges": 6, "props": [], "desc": "For a campfire. Keep them dry."},
	"feuerzeug": {"name": "Lighter", "weight": 0.05, "kind": "werkzeug", "props": ["wasserfest"], "desc": "Lights a campfire, even when it's damp."},
	"marshmallows": {"name": "Marshmallows", "weight": 0.2, "kind": "essen", "food": 5, "stamina": 6, "charges": 4, "props": [],
		"desc": "Nice raw. Much nicer roasted over a fire."},
	"kiesel": {"name": "Flat pebble", "weight": 0.15, "kind": "kram", "props": ["wasserfest"],
		"desc": "Perfect for skipping over water. Or for a cairn."},
	"fliegenpilz": {"name": "Fly agaric", "weight": 0.1, "kind": "essen", "food": 2, "poison": 30.0, "charges": 1, "stack": 6, "props": ["verderblich"],
		"desc": "Red with white dots. Beautiful. Do not eat."},
}

const PROP_NAMES := {"wasserfest": "waterproof", "zerbrechlich": "fragile", "verderblich": "perishable",
	"warm": "warm", "elektrisch": "electric", "schwimmt": "floats"}

static var _next_uid := 1


static func def(id: String) -> Dictionary:
	return ITEMS[id]


## New instance of an item (state belongs to the instance, not the definition)
static func make(id: String, uid := -1) -> Dictionary:
	var d: Dictionary = ITEMS[id]
	if uid < 0:
		uid = _next_uid
		_next_uid += 1
	var it := {"id": id, "uid": uid, "condition": 1.0, "wet": false, "charges": d.get("charges", 1), "equipped": false}
	if id == "seil":
		it["length"] = 10
		it["knot"] = 1.0   # weakest knot in the rope (1.0 = no knot)
	return it


## Something picked by hand (a berry bunch, a mushroom): onto a pile of the same kind in the backpack if there
## is one with room, else a new one. Returns false when nothing fits.
static func add_picked(inv: Inventory, id: String) -> bool:
	var stack: int = ITEMS[id].get("stack", 1)
	for it in inv.items:
		if it["id"] == id and not it.get("wet", false) and int(it.get("charges", 1)) < stack:
			it["charges"] = int(it.get("charges", 1)) + 1
			inv.changed.emit()
			return true
	return inv.add(make(id))


static func has_prop(item: Dictionary, prop: String) -> bool:
	return (ITEMS[item["id"]]["props"] as Array).has(prop)


static func display_name(item: Dictionary) -> String:
	var d: Dictionary = ITEMS[item["id"]]
	var n: String = d["name"]
	if item["id"] == "seil":
		n = "Rope (%d m%s)" % [item.get("length", 10), ", knot %d %%" % roundi(item["knot"] * 100) if item.get("knot", 1.0) < 0.999 else ""]
	if item.get("wet", false):
		n += " (wet)"
	if item.get("condition", 1.0) < 0.35:
		n += " (broken)"
	if d.has("charges") and d["kind"] == "trinken":
		n += " · %d/%d" % [item["charges"], d["charges"]]
	elif d.has("stack") and int(item.get("charges", 1)) > 1:
		n += " · %d" % item["charges"]
	return n


static func weight(item: Dictionary) -> float:
	var w: float = ITEMS[item["id"]]["weight"]
	if item["id"] == "seil":
		w *= float(item.get("length", 10)) / 10.0
	if item.get("wet", false) and not has_prop(item, "wasserfest"):
		w *= 1.3
	return w


## Hand-built model of the item (see ItemModels)
static func make_mesh(id: String) -> Mesh:
	return ItemModels.mesh(id)


## Rendered icon (assets/icons, made with scripts/tests/item_icons.gd)
## Cached, so textures drawn with draw_texture_rect stay alive after _draw()
static var _icons := {}


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := "res://assets/icons/%s.png" % id
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


static func half_extent(id: String) -> float:
	return ItemModels.mesh(id).get_aabb().size.length() * 0.5
