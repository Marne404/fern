class_name WorldItem
extends RigidBody3D
## An item lying in the world. Can be picked up, thrown and damaged.

signal broke(item: Dictionary)

const LAYER := 2

var item: Dictionary
var gen: WorldGen
var world_ref: ChunkManager
var _was_wet := false


static func create(p_item: Dictionary) -> WorldItem:
	var w := WorldItem.new()
	w.item = p_item
	return w


func _ready() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1
	mass = maxf(ItemDefs.def(item["id"])["weight"], 0.1)
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var mi := MeshInstance3D.new()
	mi.mesh = ItemDefs.make_mesh(item["id"])
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mi.mesh.get_aabb().size.max(Vector3(0.06, 0.06, 0.06))
	cs.shape = box
	add_child(cs)
	body_entered.connect(_on_hit)


func _on_hit(_body: Node) -> void:
	# hard landing damages fragile things
	var speed := linear_velocity.length()
	if speed > 6.5 and ItemDefs.has_prop(item, "zerbrechlich") and item["condition"] > 0.0:
		item["condition"] = maxf(item["condition"] - (speed - 5.0) * 0.12, 0.0)
		if item["condition"] < 0.35:
			broke.emit(item)


func _physics_process(_delta: float) -> void:
	if world_ref == null:
		return
	var w := world_ref.local_to_world(global_position)
	var wl := world_ref.gen.water_level(w.x, w.z)
	if wl > -INF and w.y < wl:
		if not _was_wet:
			_was_wet = true
			if not ItemDefs.has_prop(item, "wasserfest"):
				item["wet"] = true
		# floating things drift to the surface
		if ItemDefs.has_prop(item, "schwimmt"):
			apply_central_force(Vector3.UP * mass * 14.0 * clampf((wl - w.y) * 4.0, 0.0, 1.5))
			linear_velocity *= 0.97
		else:
			linear_velocity *= 0.9
