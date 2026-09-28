class_name AssetLibrary
extends RefCounted
## Loads the kit's glTF models and replaces their materials with the stylized shaders.
## Every combination of model and style is created only once.

const DIR := "res://assets/nature/"

var foliage_shader: Shader = preload("res://shaders/foliage.gdshader")
var grass_shader: Shader = preload("res://shaders/grass_clump.gdshader")
var bark_shader: Shader = preload("res://shaders/bark.gdshader")
var rock_shader: Shader = preload("res://shaders/rock.gdshader")
var paint_noise: Texture2D = preload("res://assets/paint_noise.tres")

## Pro kit model (family or full name) → free kit model with a similar role
const FALLBACK := {
	"Birch": "CommonTree_2", "CherryBlossom": "TwistedTree_1", "GiantPine": "Pine_4", "TallThick": "CommonTree_4",
	"Rock_Big": "Rock_Medium_1", "Rock_Medium_4": "Rock_Medium_2", "Bush_Large": "Bush_Common",
	"Bush_Large_Flowers": "Bush_Common_Flowers", "Bush_Long": "Bush_Common", "Plant_2": "Plant_1", "Plant_2_Big": "Plant_1_Big",
	"Plant_3": "Plant_7", "Plant_4": "Plant_1", "Plant_5": "Plant_7", "Plant_6": "Plant_1",
	"Flower_1_Group": "Flower_3_Group", "Flower_1_Single": "Flower_3_Single", "Flower_2_Group": "Flower_4_Group",
	"Flower_2_Single": "Flower_4_Single", "Flower_6": "Clover_1", "Flower_6_2": "Clover_2", "Flower_7_Group": "Flower_3_Group",
	"Flower_7_Single": "Flower_3_Single", "Grass_Wheat": "Grass_Wispy_Tall", "Grass_Wide_Short": "Grass_Common_Short",
	"Grass_Wide_Tall": "Grass_Common_Tall", "Mushroom_RedCap": "Mushroom_Common", "Mushroom_Oyster": "Mushroom_Laetiporus",
	"Fern": "Fern_1", "Petal": "Petal_1",
}

var _raw := {}
var _styled := {}
var _tex := {}


var _aniso: Shader


## Foliage shader with anisotropic filtering (when the optimization is turned off)
func _aniso_foliage() -> Shader:
	if _aniso == null:
		var body := FileAccess.get_file_as_string("res://shaders/foliage_body.gdshaderinc")
		body = body.replace("uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;",
			"uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;")
		var head := foliage_shader.code.replace('#include "res://shaders/foliage_body.gdshaderinc"', body)
		_aniso = Shader.new()
		_aniso.code = head
	return _aniso


## Discard styled meshes (after a material optimization changed)
func clear_styled() -> void:
	_styled.clear()


var _white_tex: ImageTexture


func _white() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(4, 4, true, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		img.generate_mipmaps()
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


func texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load(DIR + file)
	return _tex[file]


## Original mesh from the glTF scene
func raw_mesh(model: String) -> ArrayMesh:
	if _raw.has(model):
		return _raw[model]
	if model.begins_with("Proc_"):
		_raw[model] = ProcPlants.build(model)
		return _raw[model]
	var file := model
	if not ResourceLoader.exists(DIR + file + ".gltf"):
		# Pro kit models are not in git: a fresh clone uses the nearest free model instead
		file = FALLBACK.get(TreeKinds.family(model), FALLBACK.get(model, "Bush_Common"))
	var scene: PackedScene = load(DIR + file + ".gltf")
	var inst := scene.instantiate()
	var mi := _find_mesh_instance(inst)
	var mesh: ArrayMesh = mi.mesh
	inst.free()
	_raw[model] = mesh
	return mesh


func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh_instance(c)
		if r:
			return r
	return null


## Mesh with style. style: { "leaves": {...}, "bark": {...}, "rock": {...}, "grass": {...}, "plant": {...} }
## Model name with "@far": distant variant with thinned-out, enlarged leaf cards.
func mesh(model: String, style: Dictionary = {}) -> ArrayMesh:
	var key := model + "|" + str(style)
	if _styled.has(key):
		return _styled[key]
	var far := model.ends_with("@far")
	var base_model := model.trim_suffix("@far")
	var src := raw_mesh(base_model)
	var m := _without_leaf_lods(src, far)
	m.resource_name = base_model
	var aabb := src.get_aabb()
	for s in m.get_surface_count():
		var orig := src.surface_get_material(s)
		var mat_name := orig.resource_name if orig else ""
		m.surface_set_material(s, _make_material(src, s, mat_name, style, aabb))
	_styled[key] = m
	return m


## The automatic LOD throws away whole leaf cards – distant trees would be bare.
## So leaf surfaces get no LOD levels; the bark keeps its own.
## far = true: only ~40 % of the cards, but 1.55× larger (for distant chunks).
func _without_leaf_lods(src: ArrayMesh, far: bool) -> ArrayMesh:
	var surfaces: Array = src.get("_surfaces").duplicate(true)
	for s in surfaces.size():
		var mat: Material = src.surface_get_material(s)
		var name := mat.resource_name if mat else ""
		if name.begins_with("Leaves") and not name == "Leaves":
			surfaces[s]["lods"] = []
			if far:
				_thin_cards(surfaces[s], src, s)
	var m := ArrayMesh.new()
	m.set("_surfaces", surfaces)
	return m


func _thin_cards(surf: Dictionary, src: ArrayMesh, s: int) -> void:
	var arrays := src.surface_get_arrays(s)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out_idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var scaled := {}
	var i := 0
	while i + 5 < idx.size():
		var quad := [idx[i], idx[i + 1], idx[i + 2], idx[i + 3], idx[i + 4], idx[i + 5]]
		i += 6
		if rng.randf() > 0.4:
			continue
		var uniq := {}
		for v in quad:
			uniq[v] = true
		var c := Vector3.ZERO
		for v in uniq:
			c += verts[v]
		c /= uniq.size()
		for v in uniq:
			if not scaled.has(v):
				verts[v] = c + (verts[v] - c) * 1.55
				scaled[v] = true
		out_idx.append_array(quad)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = out_idx
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var thin: Dictionary = tmp.get("_surfaces")[0]
	for k in thin:
		if k != "material" and k != "name":
			surf[k] = thin[k]
	surf["lods"] = []


## Points of the convex hull of the lower trunk (bark up to ~3 m or 35 % of the height).
## Only the outermost point per angle and height bin → few points, accurate shape.
var _hulls := {}


func trunk_hull(model: String) -> PackedVector3Array:
	if _hulls.has(model):
		return _hulls[model]
	var src := raw_mesh(model)
	var height: float = src.get_aabb().end.y
	var limit := minf(3.2, height * 0.35)
	var bins := {}
	for s in src.get_surface_count():
		var mat := src.surface_get_material(s)
		if mat == null or not mat.resource_name.begins_with("Bark"):
			continue
		var verts: PackedVector3Array = src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y > limit or v.y < -0.3:
				continue
			var key := Vector2i(int((atan2(v.z, v.x) + PI) / TAU * 12.0), int(v.y / limit * 4.0))
			var r := Vector2(v.x, v.z).length()
			if not bins.has(key) or r > bins[key][0]:
				bins[key] = [r, v]
	var pts := PackedVector3Array()
	for k in bins:
		pts.append(bins[k][1])
	if pts.size() < 4:
		pts = PackedVector3Array([Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(0, 0, 0.3), Vector3(0, limit, 0)])
	_hulls[model] = pts
	return pts


func _surface_aabb(src: ArrayMesh, s: int) -> AABB:
	var verts: PackedVector3Array = src.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box


func _make_material(src: ArrayMesh, s: int, mat_name: String, style: Dictionary, aabb: AABB) -> Material:
	var height: float = max(aabb.end.y, 0.5)
	if mat_name.begins_with("Bark"):
		var st: Dictionary = style.get("bark", {})
		var mat := ShaderMaterial.new()
		mat.shader = bark_shader
		var bark_file: String = {"Bark_Birch": "Bark_BirchTree", "Bark_Pine": "Bark_PineTree"}.get(mat_name, mat_name)
		mat.set_shader_parameter("albedo_tex", texture(bark_file + ".png"))
		mat.set_shader_parameter("normal_tex", texture(bark_file + "_Normal.png"))
		mat.set_shader_parameter("object_height", height)
		mat.set_shader_parameter("stiffness", style.get("stiffness", 4.0))
		for k in st:
			mat.set_shader_parameter(k, st[k])
		return mat

	if mat_name in ["Rocks", "PathRocks"]:
		var st: Dictionary = style.get("rock", {})
		var mat := ShaderMaterial.new()
		mat.shader = rock_shader
		mat.set_shader_parameter("albedo_tex", texture(st.get("texture", mat_name + ("_Diffuse.png"))))
		mat.set_shader_parameter("paint_noise", paint_noise)
		for k in st:
			if k != "texture":
				mat.set_shader_parameter(k, st[k])
		return mat

	if mat_name == "Proc":
		# procedural plants: colors from the vertices, wind and light like the other plants
		var st: Dictionary = style.get("plant", {})
		var pm := ShaderMaterial.new()
		pm.shader = foliage_shader
		pm.set_shader_parameter("mode", 3)
		pm.set_shader_parameter("albedo_tex", _white())
		pm.set_shader_parameter("object_height", height)
		pm.set_shader_parameter("alpha_cut", 0.05)
		pm.set_shader_parameter("stiffness", st.get("stiffness", 2.5))
		pm.set_shader_parameter("flutter", 0.03)
		pm.set_shader_parameter("translucency", 0.45)
		pm.set_shader_parameter("wrap", 0.5)
		for k in st:
			if k != "stiffness":
				pm.set_shader_parameter(k, st[k])
		return pm

	if mat_name == "Mushrooms":
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = texture("Mushrooms.png")
		mat.albedo_color = style.get("mushroom_tint", Color(1.25, 0.98, 0.72))
		if style.has("mushroom_glow"):
			mat.emission_enabled = true
			mat.emission = style["mushroom_glow"]
			mat.emission_energy_multiplier = 0.7
			mat.emission_texture = texture("Mushrooms.png")
		mat.roughness = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat

	var mat := ShaderMaterial.new()
	mat.shader = foliage_shader
	mat.set_shader_parameter("object_height", height)
	mat.set_shader_parameter("stiffness", style.get("stiffness", 4.0))
	if not Settings.values["opt_foliage_noaniso"]:
		mat.shader = _aniso_foliage()
	if mat_name == "Grass":
		mat.shader = grass_shader if Settings.values["opt_opaque_grass"] else foliage_shader
		var st: Dictionary = style.get("grass", {})
		mat.set_shader_parameter("mode", 1)
		mat.set_shader_parameter("albedo_tex", texture("Grass.png"))
		mat.set_shader_parameter("alpha_cut", 0.0)
		mat.set_shader_parameter("stiffness", st.get("stiffness", 3.5))
		mat.set_shader_parameter("flutter", 0.04)
		mat.set_shader_parameter("translucency", 0.35)
		mat.set_shader_parameter("ground_normal", 0.6)
		mat.set_shader_parameter("wrap", 0.5)
		mat.set_shader_parameter("near_fade", 1.6)
		return mat

	var tex_file: String = {
		"Leaves_NormalTree": "Leaves_NormalTree_C.png",
		"Leaves_TwistedTree": "Leaves_TwistedTree_C.png",
		"Leaves_Pine": "Leaf_Pine_C.png",
		"Leaves_Birch": "Leaves_Birch_C.png",
		"Leaves_CherryBlossom": "Leaves_CherryBlossom_C.png",
		"Leaves_GiantPine": "Leaves_GiantPine_C.png",
		"Leaves_TallThick": "Leaves_TallThick_C.png",
		"Leaves": "Leaves.png",
		"Flowers": "Flowers.png",
	}.get(mat_name, "Leaves.png")
	mat.set_shader_parameter("albedo_tex", texture(tex_file))

	if mat_name in ["Leaves", "Flowers"]:
		var st: Dictionary = style.get("plant", {})
		mat.set_shader_parameter("mode", 2)
		mat.set_shader_parameter("instance_tint", mat_name == "Flowers")
		mat.set_shader_parameter("texture_color_mix", 1.0)
		mat.set_shader_parameter("alpha_cut", 0.5)
		mat.set_shader_parameter("stiffness", st.get("stiffness", 2.5))
		mat.set_shader_parameter("flutter", 0.03)
		mat.set_shader_parameter("translucency", 0.5)
		mat.set_shader_parameter("wrap", 0.5)
		for k in st:
			if k != "stiffness":
				mat.set_shader_parameter(k, st[k])
		return mat

	# tree crown or bush
	var st: Dictionary = style.get("leaves", {})
	var crown := _surface_aabb(src, s)
	mat.set_shader_parameter("mode", 0)
	mat.set_shader_parameter("crown_center", crown.get_center())
	mat.set_shader_parameter("crown_extent", crown.size * 0.5)
	mat.set_shader_parameter("alpha_cut", 0.5)
	mat.set_shader_parameter("flutter", 0.06)
	for k in st:
		mat.set_shader_parameter(k, st[k])
	return mat
