class_name TreeKinds
extends RefCounted
## What the world needs to know about each tree family of the kit: how the crown is shaped when placed,
## whether a twin tree or a bush may grow next to it, and where its crown sits (falling leaves).
## Models are named "<Family>_<n>", e.g. "Birch_3".

const KINDS := {
	# squash: scale of the placed tree (wider, rounder crowns); twin: a second tree right next to it in dense groves;
	# bush: often a bush at its base; crown_h / crown_r: crown center height and radius at scale 1 (leaf fall)
	"CommonTree": {"squash": Vector3(1.34, 0.88, 1.34), "twin": true, "bush": true, "crown_h": 7.8, "crown_r": 2.2},
	"TwistedTree": {"squash": Vector3(1.34, 0.88, 1.34), "twin": false, "bush": true, "crown_h": 16.5, "crown_r": 5.0},
	"Birch": {"squash": Vector3(1.12, 0.96, 1.12), "twin": false, "bush": false, "crown_h": 13.0, "crown_r": 3.6},
	"CherryBlossom": {"squash": Vector3(1.1, 0.92, 1.1), "twin": false, "bush": true, "crown_h": 13.0, "crown_r": 6.0},
	"TallThick": {"squash": Vector3(1.05, 1.0, 1.05), "twin": false, "bush": true, "crown_h": 14.0, "crown_r": 4.0},
	"GiantPine": {"squash": Vector3.ONE, "twin": false, "bush": false, "crown_h": 14.0, "crown_r": 5.5},
	"Pine": {"squash": Vector3.ONE, "twin": false, "bush": false, "crown_h": 6.0, "crown_r": 2.2},
	"DeadTree": {"squash": Vector3.ONE, "twin": false, "bush": false, "crown_h": 6.0, "crown_r": 2.0},
}


static func family(model: String) -> String:
	var i := model.rfind("_")
	return model.substr(0, i) if i > 0 else model


static func of(model: String) -> Dictionary:
	return KINDS.get(family(model.trim_suffix("@far")), {})


static func is_tree(model: String) -> bool:
	return KINDS.has(family(model.trim_suffix("@far")))
