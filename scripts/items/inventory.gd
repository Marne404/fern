class_name Inventory
extends RefCounted
## A player's backpack: items, weight, clothing.

signal changed

const SLOTS := 18
const COMFORT_WEIGHT := 9.0     # barely noticeable up to here
const MAX_WEIGHT := 28.0        # nothing more fits above this

var items: Array[Dictionary] = []
var locked := false             # backpack lock (for multiplayer)


func total_weight() -> float:
	var w := 0.0
	for it in items:
		w += ItemDefs.weight(it)
	return w


func can_add(item: Dictionary) -> bool:
	return items.size() < SLOTS and total_weight() + ItemDefs.weight(item) <= MAX_WEIGHT


func add(item: Dictionary) -> bool:
	if not can_add(item):
		return false
	items.append(item)
	changed.emit()
	return true


func remove(item: Dictionary) -> void:
	items.erase(item)
	changed.emit()


func find_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		if ItemDefs.def(it["id"])["kind"] == kind:
			out.append(it)
	return out


## Total warmth from worn clothing (wet clothing barely warms)
func warmth() -> float:
	var w := 0.0
	for it in items:
		if it.get("equipped", false):
			var d := ItemDefs.def(it["id"])
			w += d.get("warmth", 0.0) * (0.3 if it.get("wet", false) and not ItemDefs.has_prop(it, "wasserfest") else 1.0)
	return w


func toggle_equip(item: Dictionary) -> void:
	var d := ItemDefs.def(item["id"])
	if not d.has("slot"):
		return
	if not item["equipped"]:
		for other in items:
			if other != item and other.get("equipped", false) and ItemDefs.def(other["id"]).get("slot") == d["slot"]:
				other["equipped"] = false
	item["equipped"] = not item["equipped"]
	changed.emit()


## Everything that isn't waterproof gets wet. Returns the affected names.
func soak() -> Array[String]:
	var hit: Array[String] = []
	for it in items:
		if not it["wet"] and not ItemDefs.has_prop(it, "wasserfest"):
			it["wet"] = true
			if ItemDefs.has_prop(it, "elektrisch"):
				it["condition"] = minf(it["condition"], 0.2)
			hit.append(ItemDefs.def(it["id"])["name"])
	if not hit.is_empty():
		changed.emit()
	return hit
