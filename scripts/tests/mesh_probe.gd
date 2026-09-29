extends SceneTree
## Prints surfaces, triangles, LOD levels and connected islands (≈ blades) of kit models.
## godot --headless --path . -s scripts/tests/mesh_probe.gd -- Grass_Wispy_Tall,Flower_1_Group

func _init() -> void:
	for model in OS.get_cmdline_user_args()[0].split(","):
		var inst := (load("res://assets/nature/%s.gltf" % model) as PackedScene).instantiate()
		var m: ArrayMesh = (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		inst.free()
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var mat := m.surface_get_material(s)
			var lods: Array = m.get("_surfaces")[s].get("lods", [])
			var lod_tris := []
			for i in range(0, lods.size(), 2):
				lod_tris.append((lods[i + 1] as PackedByteArray).size() / 12 if lods[i + 1] is PackedByteArray else "?")
			print("%s s%d mat=%s verts=%d tris=%d lods=%s aabb=%s islands=%d" % [model, s, mat.resource_name if mat else "-", verts.size(), idx.size() / 3, lod_tris, m.get_aabb().size, _islands(idx, verts.size())])
	quit()


func _islands(idx: PackedInt32Array, n: int) -> int:
	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	for i in range(0, idx.size(), 3):
		var a := _find(parent, idx[i])
		for k in [1, 2]:
			var b := _find(parent, idx[i + k])
			if a != b:
				parent[b] = a
	var roots := {}
	for i in idx:
		roots[_find(parent, i)] = true
	return roots.size()


func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i
