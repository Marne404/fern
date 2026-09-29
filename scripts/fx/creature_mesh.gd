class_name CreatureMesh
extends RefCounted
## Builds animal parts in the scout's toon style: Mesh3 shapes colored per vertex (a callable gets the
## normal and the position in the part's own space, so coats can have a darker back, a pale belly, spots or
## a white rump), merged into one mesh per animated node, drawn with the scout's toon material.
## Alpha of the vertex color: 1 plain, 0.5 soft (fur), 0 glossy (eyes, beaks, noses) – like the items.

const FUR := 0.5
const GLOSS := 0.0
const PLAIN := 1.0

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


## Adds a mesh. color: Color, or Callable(normal: Vector3, pos: Vector3) -> Color (in the mesh's own space)
func add(m: ArrayMesh, color, xf := Transform3D.IDENTITY, flag := FUR) -> void:
	var arr := m.surface_get_arrays(0)
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in vs.size():
		verts.append(xf * vs[i])
		norms.append((nb * ns[i]).normalized())
		var c: Color = (color as Callable).call(ns[i], vs[i]) if color is Callable else color
		var lc := c.srgb_to_linear()
		lc.a = flag
		cols.append(lc)
	for i in arr[Mesh.ARRAY_INDEX]:
		idx.append(base + i)


func commit() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, ItemModels.material())
	return m


## A MeshInstance3D with the merged parts, added to parent (no shadow for tiny creatures)
func instance(parent: Node3D, name := "Mesh", shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit()
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## An eye: dark glossy ball with a small white catch light (looking along -Z of xf)
func eye(r: float, xf: Transform3D, iris := Color("241a14")) -> void:
	add(Mesh3.blob(Vector3(r, r, r * 0.8), 2.0, 8, 12), iris, xf, GLOSS)
	add(Mesh3.blob(Vector3(r, r, r) * 0.28, 2.0, 5, 8), Color("fffdf6"), xf * Transform3D(Basis(), Vector3(r * 0.35, r * 0.4, -r * 0.62)), PLAIN)
