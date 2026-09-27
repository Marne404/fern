class_name ItemDefs
extends RefCounted
## All items: weight, properties, effect and look.
##
## Properties: wasserfest (waterproof), zerbrechlich (fragile), verderblich (perishable), warm, elektrisch (electric), schwimmt (floats)
## Kinds: essen (food), trinken (drink), medizin (medicine), kleidung (clothing), werkzeug (tool), spass (fun), kram (stuff)

const ITEMS := {
	"apfel": {"name": "Apple", "weight": 0.2, "kind": "essen", "food": 16, "water": 4, "props": ["verderblich", "schwimmt"],
		"shape": "sphere", "size": 0.08, "color": Color(0.85, 0.15, 0.1), "desc": "Crunchy and a little sour."},
	"beeren": {"name": "Berries", "weight": 0.1, "kind": "essen", "food": 9, "water": 3, "props": ["verderblich"],
		"shape": "sphere", "size": 0.05, "color": Color(0.35, 0.15, 0.55), "desc": "Hopefully the edible kind."},
	"brot": {"name": "Bread", "weight": 0.4, "kind": "essen", "food": 32, "props": ["verderblich"],
		"shape": "capsule", "size": 0.12, "color": Color(0.78, 0.55, 0.3), "desc": "A bit dry, but filling."},
	"muesliriegel": {"name": "Granola bar", "weight": 0.1, "kind": "essen", "food": 18, "props": ["wasserfest"],
		"shape": "box", "size": Vector3(0.12, 0.03, 0.04), "color": Color(0.9, 0.75, 0.3), "desc": "Chocolate with oats."},
	"bohnen": {"name": "Can of beans", "weight": 0.5, "kind": "essen", "food": 45, "props": ["wasserfest"],
		"shape": "cylinder", "size": Vector2(0.045, 0.12), "color": Color(0.75, 0.2, 0.15), "desc": "They taste fine cold, too."},
	"wasserflasche": {"name": "Water bottle", "weight": 1.0, "kind": "trinken", "water": 35, "charges": 3, "refill": true,
		"props": ["wasserfest", "schwimmt"], "shape": "cylinder", "size": Vector2(0.04, 0.24), "color": Color(0.35, 0.65, 0.95),
		"desc": "Can be refilled at springs and lakes."},
	"limonade": {"name": "Lemonade", "weight": 0.5, "kind": "trinken", "water": 28, "food": 4, "props": ["zerbrechlich"],
		"shape": "cylinder", "size": Vector2(0.035, 0.2), "color": Color(0.95, 0.8, 0.25), "desc": "Glass bottle. Don't drop it."},
	"verband": {"name": "Bandage", "weight": 0.1, "kind": "medizin", "heal": 40, "props": [],
		"shape": "cylinder", "size": Vector2(0.04, 0.08), "color": Color(0.95, 0.95, 0.92), "desc": "Stops bleeding and lifts the spirits."},
	"regenjacke": {"name": "Rain jacket", "weight": 0.8, "kind": "kleidung", "warmth": 10, "slot": "koerper", "props": ["wasserfest", "warm"],
		"shape": "box", "size": Vector3(0.35, 0.08, 0.3), "color": Color(0.95, 0.55, 0.15), "desc": "Keeps out wind and rain."},
	"pullover": {"name": "Wool sweater", "weight": 0.7, "kind": "kleidung", "warmth": 14, "slot": "koerper", "props": ["warm"],
		"shape": "box", "size": Vector3(0.32, 0.1, 0.28), "color": Color(0.55, 0.25, 0.25), "desc": "Itchy, but warm."},
	"muetze": {"name": "Wool hat", "weight": 0.2, "kind": "kleidung", "warmth": 6, "slot": "kopf", "props": ["warm"],
		"shape": "sphere", "size": 0.09, "color": Color(0.25, 0.45, 0.8), "desc": "With a pompom."},
	"sonnenhut": {"name": "Sun hat", "weight": 0.2, "kind": "kleidung", "warmth": -8, "slot": "kopf", "props": [],
		"shape": "cylinder", "size": Vector2(0.18, 0.04), "color": Color(0.92, 0.82, 0.55), "desc": "Protects against the heat."},
	"seil": {"name": "Rope", "weight": 2.0, "kind": "werkzeug", "props": ["wasserfest"],
		"shape": "torus", "size": 0.14, "color": Color(0.85, 0.7, 0.4), "desc": "For whatever you'll need it for later."},
	"taschenlampe": {"name": "Flashlight", "weight": 0.4, "kind": "werkzeug", "props": ["elektrisch", "zerbrechlich"],
		"shape": "cylinder", "size": Vector2(0.025, 0.18), "color": Color(0.2, 0.2, 0.22), "desc": "For the night."},
	"fernglas": {"name": "Binoculars", "weight": 0.6, "kind": "werkzeug", "props": ["zerbrechlich"],
		"shape": "box", "size": Vector3(0.12, 0.06, 0.1), "color": Color(0.15, 0.18, 0.15), "desc": "Right mouse button to look through."},
	"kamera": {"name": "Camera", "weight": 0.9, "kind": "spass", "props": ["elektrisch", "zerbrechlich"],
		"shape": "box", "size": Vector3(0.12, 0.08, 0.06), "color": Color(0.1, 0.1, 0.12), "desc": "Use it to take a photo of the journey."},
	"feldhandbuch": {"name": "Field guide", "weight": 0.5, "kind": "werkzeug", "props": [],
		"shape": "box", "size": Vector3(0.15, 0.03, 0.2), "color": Color(0.3, 0.45, 0.25), "desc": "Has anyone read it?"},
	"wasserpistole": {"name": "Water pistol", "weight": 0.3, "kind": "spass", "props": ["wasserfest", "schwimmt"],
		"shape": "box", "size": Vector3(0.16, 0.08, 0.04), "color": Color(0.2, 0.75, 0.95), "desc": "Oh."},
	"gummihuhn": {"name": "Rubber chicken", "weight": 0.2, "kind": "spass", "props": ["wasserfest", "schwimmt"],
		"shape": "capsule", "size": 0.1, "color": Color(1.0, 0.85, 0.1), "desc": "Squeaks."},
	"stein": {"name": "Pretty stone", "weight": 1.2, "kind": "kram", "props": ["wasserfest"],
		"shape": "sphere", "size": 0.07, "color": Color(0.6, 0.6, 0.62), "desc": "Completely useless. Beautiful."},
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
	return n


static func weight(item: Dictionary) -> float:
	var w: float = ITEMS[item["id"]]["weight"]
	if item["id"] == "seil":
		w *= float(item.get("length", 10)) / 10.0
	if item.get("wet", false) and not has_prop(item, "wasserfest"):
		w *= 1.3
	return w


## Simple model made of primitives (until real models arrive)
static func make_mesh(id: String) -> Mesh:
	var d: Dictionary = ITEMS[id]
	var m: Mesh
	match d["shape"]:
		"sphere":
			var s := SphereMesh.new()
			s.radius = d["size"]
			s.height = d["size"] * 2.0
			s.radial_segments = 12
			s.rings = 6
			m = s
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = d["size"] * 0.5
			c.height = d["size"] * 2.0
			c.radial_segments = 10
			c.rings = 4
			m = c
		"cylinder":
			var cy := CylinderMesh.new()
			var sz: Vector2 = d["size"]
			cy.top_radius = sz.x
			cy.bottom_radius = sz.x
			cy.height = sz.y
			cy.radial_segments = 12
			m = cy
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = d["size"] * 0.6
			t.outer_radius = d["size"]
			t.rings = 12
			t.ring_segments = 8
			m = t
		_:
			var b := BoxMesh.new()
			b.size = d["size"]
			m = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d["color"]
	mat.roughness = 0.7
	mat.rim_enabled = true
	mat.rim = 0.3
	m.surface_set_material(0, mat)
	return m


static func half_extent(id: String) -> float:
	var d: Dictionary = ITEMS[id]
	var sz = d["size"]
	if sz is float:
		return sz
	if sz is Vector2:
		return maxf(sz.x, sz.y * 0.5)
	return (sz as Vector3).length() * 0.5
