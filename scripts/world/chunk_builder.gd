class_name ChunkBuilder
extends RefCounted
## Creates a chunk's raw data (runs in worker threads, creates no nodes/resources).
## Result: terrain arrays, path texture bytes, instance buffers per mesh key, collision data.

const SIZE := 64.0
static var opt_cells := true
static var opt_far_batch := true
static var opt_far_trees := true
const SKIRT := 3.0

var gen: WorldGen
var coord: Vector2i
var lod: int
var veg: float
var corner: Vector2
var spacing: float
var n: int                              # vertices per side
var heights := PackedFloat32Array()     # (n+2)² including border for normals
var rows := {}                           # z (rounded to 0.5 m) -> row data
var rng := RandomNumberGenerator.new()
var instances := {}                      # key -> PackedFloat32Array
var counts := {}
var trunks: Array = []                   # [Vector3 local, radius, height]
var rocks: Array = []                    # [key, Transform3D local]
var blockers: Array[Vector3] = []        # x, z (local), radius
var clearings: Array[Vector3] = []       # find spots: x, z (local), radius
var rock_disks: Array[Vector3] = []      # footprints of large rocks: x, z (local), radius – nothing grows there
var crowns := PackedFloat32Array()       # colorful tree crowns that drop leaves/blossoms: x, y, z (world), radius, r, g, b


static func layer_key(biome: int, layer: int, style: int, model: String) -> String:
	return "%d/%d/%d/%s" % [biome, layer, style, model]


func _init(p_gen: WorldGen, p_coord: Vector2i, p_lod: int, p_veg: float) -> void:
	gen = p_gen
	coord = p_coord
	lod = p_lod
	veg = p_veg
	corner = Vector2(coord.x * SIZE, coord.y * SIZE)
	# lod 0 near, 1 far, 2 very far (coarse terrain and trees only)
	spacing = [2.0, 8.0, 16.0][lod] as float
	n = int(SIZE / spacing) + 1


func build() -> Dictionary:
	_build_heights()
	var result := _build_terrain()
	result["path_image"] = _build_path_image()
	_scatter()
	result["instances"] = instances
	result["counts"] = counts
	result["trunks"] = trunks
	result["rocks"] = rocks
	result["water"] = _water()
	var disks := PackedVector3Array()
	for d in rock_disks:
		disks.append(Vector3(d.x + corner.x, d.y + corner.y, d.z))
	result["rock_disks"] = disks
	result["crowns"] = crowns
	if lod == 0:
		result["collision"] = _collision_heights()
	return result


# ================================================================ Rows & heights

func row_at(z: float) -> Dictionary:
	var key := roundi(z * 2.0)
	if not rows.has(key):
		rows[key] = gen.row(key * 0.5)
	return rows[key]


func _build_heights() -> void:
	var m := n + 2
	heights.resize(m * m)
	for j in m:
		var z := corner.y + (j - 1) * spacing
		var r := gen.row(z)
		rows[roundi(z * 2.0)] = r
		for i in m:
			var x := corner.x + (i - 1) * spacing
			heights[j * m + i] = gen.height_in_row(x, r)


## Height on the actually rendered triangle surface (local coordinates 0..64)
func surface_height(lx: float, lz: float) -> float:
	var m := n + 2
	var fx := clampf(lx / spacing, 0.0, n - 1.001)
	var fz := clampf(lz / spacing, 0.0, n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var b := (iz + 1) * m + ix + 1
	var h00 := heights[b]
	var h10 := heights[b + 1]
	var h01 := heights[b + m]
	var h11 := heights[b + m + 1]
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func surface_normal(lx: float, lz: float) -> Vector3:
	var e := spacing * 0.5
	var hx := surface_height(lx + e, lz) - surface_height(lx - e, lz)
	var hz := surface_height(lx, lz + e) - surface_height(lx, lz - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


# ================================================================ Terrain mesh

func _build_terrain() -> Dictionary:
	var m := n + 2
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	var custom2 := PackedFloat32Array()
	var count := n * n + 4 * n
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	custom0.resize(count * 4)
	custom1.resize(count * 4)
	custom2.resize(count * 4)
	for j in n:
		var z := corner.y + j * spacing
		var r: Dictionary = rows[roundi(z * 2.0)]
		var ta: Dictionary = r["a"]
		var tb: Dictionary = r["b"]
		var t: float = r["t"]
		var path_col: Color = (ta["path_color"] as Color).lerp(tb["path_color"], t)
		var crack := lerpf(ta["crack"], tb["crack"], t)
		var ripple := lerpf(ta["ripple"], tb["ripple"], t)
		var litter := lerpf(ta["litter"], tb["litter"], t)
		var litter_col: Color = (ta["litter_color"] as Color).lerp(tb["litter_color"], t)
		for i in n:
			var x := corner.x + i * spacing
			var hb := (j + 1) * m + i + 1
			var nrm := Vector3(heights[hb - 1] - heights[hb + 1], 2.0 * spacing, heights[hb - m] - heights[hb + m]).normalized()
			var v := j * n + i
			verts[v] = Vector3(i * spacing, heights[hb], j * spacing)
			normals[v] = nrm
			var col := gen.ground_color(x, z, r, 1.0 - nrm.y, heights[hb] - r["elev"])
			var wl := _pond_level(x, r)
			if wl > -INF:
				# shore and lake bed: sandy-muddy, darker towards the water
				# narrow, light sand rim instead of a wide mud band on flat meadows
				var under := smoothstep(wl + 0.22, wl - 0.1, heights[hb])
				col = col.lerp(Color(0.72, 0.66, 0.46).srgb_to_linear(), under * 0.75)
				col = col.lerp(Color(0.2, 0.26, 0.2).srgb_to_linear(), smoothstep(wl - 0.3, wl - 1.5, heights[hb]))
			colors[v] = col
			custom0[v * 4] = path_col.r
			custom0[v * 4 + 1] = path_col.g
			custom0[v * 4 + 2] = path_col.b
			custom0[v * 4 + 3] = crack
			custom1[v * 4] = ripple
			# height above the nearest water (wet shore band) and whether it is the sea (swash)
			var wa := gen.water_in_row(x, r, 1.4)
			custom1[v * 4 + 1] = clampf(heights[hb] - wa, -1.0, 4.0) if wa > -INF else 4.0
			custom1[v * 4 + 2] = 1.0 if wa > -INF and r["coast"] > 0.01 and wa == r["sea"] else 0.0
			custom2[v * 4] = litter_col.r
			custom2[v * 4 + 1] = litter_col.g
			custom2[v * 4 + 2] = litter_col.b
			custom2[v * 4 + 3] = litter
	# skirt along the edges against gaps between LOD levels
	var edges := [[0, 1, 0], [n * (n - 1), 1, 0], [0, n, 1], [n - 1, n, 1]]
	var v2 := n * n
	var skirt_idx := PackedInt32Array()
	for e in edges:
		var start: int = e[0]
		var step: int = e[1]
		var first := v2
		for k in n:
			var src := start + k * step
			verts[v2] = verts[src] - Vector3(0, SKIRT, 0)
			normals[v2] = normals[src]
			colors[v2] = colors[src]
			for c in 4:
				custom0[v2 * 4 + c] = custom0[src * 4 + c]
				custom1[v2 * 4 + c] = custom1[src * 4 + c]
				custom2[v2 * 4 + c] = custom2[src * 4 + c]
			v2 += 1
		for k in n - 1:
			var a := start + k * step
			var b := start + (k + 1) * step
			var sa := first + k
			var sb := first + k + 1
			skirt_idx.append_array([a, b, sa, b, sb, sa])
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var q := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[q] = a; idx[q + 1] = a + 1; idx[q + 2] = a + n
			idx[q + 3] = a + 1; idx[q + 4] = a + n + 1; idx[q + 5] = a + n
			q += 6
	idx.append_array(skirt_idx)
	return {"verts": verts, "normals": normals, "colors": colors, "custom0": custom0, "custom1": custom1, "custom2": custom2, "indices": idx}


## Path mask: 1 m (near) or 4 m (far) per texel, 65 or 17 texels wide
func _build_path_image() -> Dictionary:
	var res: int = [65, 17, 9][lod]
	var step := SIZE / (res - 1)
	var bytes := PackedByteArray()
	bytes.resize(res * res)
	for j in res:
		var z := corner.y + j * step
		var r := row_at(z)
		for i in res:
			var x := corner.x + i * step
			var pv := gen.path_value(gen.offset_in_row(x, r), r["half_w"])
			bytes[j * res + i] = int(pv * 255.0)
	return {"res": res, "bytes": bytes}


## Water level nearby (including shore zone) or -INF
func _pond_level(x: float, r: Dictionary) -> float:
	var wl := gen.water_in_row(x, r, 1.4)
	# the sea doesn't count here (cliff foot shouldn't be colored like a lake shore)
	if r["coast"] > 0.01 and wl == r["sea"]:
		return -INF
	return wl


func _below_sea(lx: float, lz: float, r: Dictionary) -> bool:
	return r["coast"] > 0.0 and surface_height(lx, lz) < r["sea"] + 0.6


## Is the local point under water (with a safety margin)?
func _wet(lx: float, lz: float, margin: float) -> bool:
	var r := row_at(corner.y + lz)
	if r["ponds"].is_empty() and r["rivers"].is_empty() and r["pools"].is_empty():
		return false
	var wl := _pond_level(corner.x + lx, r)
	return wl > -INF and surface_height(lx, lz) < wl + margin


## Ponds whose center lies in this chunk
func _water() -> Array:
	var out := []
	var k0 := floori(-(corner.y + SIZE) / WorldGen.POND_CELL) - 1
	var k1 := floori(-corner.y / WorldGen.POND_CELL) + 1
	var bodies: Array[Vector4] = []
	for k in range(k0, k1 + 1):
		bodies.append(gen.pond(k))
	for o in gen.obstacles_near(corner.y + SIZE * 0.5):
		if o["type"] == "cliff":
			bodies.append(o["pool"])
	for p in bodies:
		if p.z <= 0.0:
			continue
		if p.x >= corner.x and p.x < corner.x + SIZE and p.y >= corner.y and p.y < corner.y + SIZE:
			var bb := gen.biome_blend(p.y)
			var ta: Dictionary = gen.biomes[int(bb.x)]["terrain"]
			var tb: Dictionary = gen.biomes[int(bb.y)]["terrain"]
			out.append({"pos": Vector3(p.x - corner.x, p.w, p.y - corner.y), "radius": p.z,
				"shallow": (ta["water_shallow"] as Color).lerp(tb["water_shallow"], bb.z),
				"deep": (ta["water_deep"] as Color).lerp(tb["water_deep"], bb.z)})
	return out


func _collision_heights() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(65 * 65)
	for j in 65:
		for i in 65:
			out[j * 65 + i] = surface_height(i, j)
	return out


# ================================================================ Scattering

func _find_clearings() -> void:
	var k0 := floori(-(corner.y + SIZE) / PoiManager.CELL) - 1
	var k1 := floori(-corner.y / PoiManager.CELL) + 1
	for k in range(maxi(k0, 0), k1 + 1):
		var p := PoiManager.plan(gen, k)
		if p.is_empty():
			continue
		var lx: float = p["x"] - corner.x
		var lz: float = p["z"] - corner.y
		if lx > -4.0 and lz > -4.0 and lx < SIZE + 4.0 and lz < SIZE + 4.0:
			var r := 1.4 if p["type"] == "schild" else 2.6
			clearings.append(Vector3(lx, lz, r))
			blockers.append(Vector3(lx, lz, r + 1.0))


func _in_rock(lx: float, lz: float) -> bool:
	for c in rock_disks:
		if (c.x - lx) * (c.x - lx) + (c.y - lz) * (c.y - lz) < c.z * c.z:
			return true
	return false


func _find_landmarks() -> void:
	var k0 := floori(-(corner.y + SIZE) / LandmarkManager.CELL) - 1
	var k1 := floori(-corner.y / LandmarkManager.CELL) + 1
	for k in range(maxi(k0, 1), k1 + 1):
		var p := LandmarkManager.plan(gen, k)
		if p.is_empty():
			continue
		var lx: float = p["x"] - corner.x
		var lz: float = p["z"] - corner.y
		if lx > -14.0 and lz > -14.0 and lx < SIZE + 14.0 and lz < SIZE + 14.0:
			clearings.append(Vector3(lx, lz, 9.5))
			blockers.append(Vector3(lx, lz, 11.0))


func _in_clearing(lx: float, lz: float) -> bool:
	for c in clearings:
		if (c.x - lx) * (c.x - lx) + (c.y - lz) * (c.y - lz) < c.z * c.z:
			return true
	return false


## Reeds and shore plants around ponds
func _scatter_shores() -> void:
	if lod != 0:
		return
	var seen := {}
	for key in rows:
		for p in rows[key]["ponds"]:
			seen[p] = true
		for p in rows[key]["pools"]:
			seen[p] = true
	for p in seen:
		var pond: Vector4 = p
		rng.seed = hash([gen.seed_value, int(pond.x), int(pond.y), 31])
		var n := int(TAU * pond.z * 2.2 * veg)
		for i in n:
			var a := rng.randf() * TAU
			var er := gen.water_radius(pond, pond.x + cos(a), pond.y + sin(a))
			var d := er * rng.randf_range(0.82, 1.12)
			var lx := pond.x + cos(a) * d - corner.x
			var lz := pond.y + sin(a) * d - corner.y
			if lx < 0.0 or lz < 0.0 or lx >= SIZE or lz >= SIZE:
				continue
			var h := surface_height(lx, lz)
			if h > pond.w + 0.45 or h < pond.w - 0.7 or _in_rock(lx, lz):
				continue
			var reed := rng.randf() < 0.75
			var model: String = "Grass_Wispy_Tall" if reed else ["Plant_1", "Plant_1_Big", "Fern_1"][rng.randi() % 3]
			var scale: float = rng.randf_range(0.8, 1.4) if reed else (rng.randf_range(0.25, 0.35) if model == "Fern_1" else rng.randf_range(0.6, 1.0))
			var col := Color(0.22, 0.42, 0.12).lerp(Color(0.55, 0.62, 0.2), rng.randf()).srgb_to_linear()
			col.a = rng.randf()
			_add("shore/" + model, _ground_xf(lx, lz, scale, 0.3, 0.0), col)


func _scatter() -> void:
	_find_clearings()
	_find_landmarks()
	_scatter_shores()
	# Which biomes occur in this chunk?
	var present := {}
	for z in [corner.y, corner.y + SIZE * 0.5, corner.y + SIZE]:
		var bb := gen.biome_blend(z)
		present[int(bb.x)] = true
		present[int(bb.y)] = true
	# large objects first, so trees avoid rocks
	var passes := [["rock"], ["tree"], ["grass", "detail", "cluster", "path_stones", "rows"]]
	if lod == 2:
		passes = [["rock"], ["tree"]]
	for pass_kind in passes:
		for b in present:
			var layers: Array = gen.biomes[b]["layers"]
			for li in layers.size():
				var layer: Dictionary = layers[li]
				if not pass_kind.has(layer["kind"]):
					continue
				if layer.get("near", false) and lod != 0:
					continue
				_scatter_layer(b, li, layer)


func _biome_weight(b: int, r: Dictionary) -> float:
	var bb: Vector3 = r["blend"]
	var w := 0.0
	if int(bb.x) == b:
		w += 1.0 - bb.z
	if int(bb.y) == b:
		w += bb.z
	return w


func _scatter_layer(b: int, li: int, layer: Dictionary) -> void:
	var kind: String = layer["kind"]
	if kind == "tree" or kind == "rock":
		_scatter_grid(b, li, layer)
		return
	if kind == "rows":
		_scatter_rows(b, li, layer)
		return
	var density: float = layer.get("density", 0.0)
	if density <= 0.0:
		if layer.has("on_trunks"):
			_scatter_on_trunks(b, li, layer)
		return
	rng.seed = hash([gen.seed_value, coord.x, coord.y, b, li])
	var mult := veg if kind != "path_stones" else 1.0
	var total := int(density / 1000.0 * SIZE * SIZE * mult)
	var dist: Array = layer.get("dist", [0.0, 1000.0])
	var falloff: Array = layer.get("falloff", [])
	var grove: Array = layer.get("grove", [])
	for k in total:
		var lx := rng.randf() * SIZE
		var lz := rng.randf() * SIZE
		var x := corner.x + lx
		var z := corner.y + lz
		var r := row_at(z)
		if rng.randf() > _biome_weight(b, r):
			continue
		var off := gen.offset_in_row(x, r)
		var d := absf(off)
		var half_w: float = r["half_w"]
		var pv := gen.path_value(off, half_w)
		if kind == "path_stones":
			if pv < 0.35:
				continue
			var gap: Array = layer["gap"]
			if sin(z * gap[0]) + sin(z * 0.23) * 0.6 < gap[1]:
				continue
		else:
			if d < dist[0] or d > dist[1]:
				continue
			if not falloff.is_empty() and rng.randf() > lerpf(1.0, falloff[2], smoothstep(falloff[0], falloff[1], d)):
				continue
			if not grove.is_empty() and gen.region(x * grove[0] / 0.012, z * grove[0] / 0.012) < 0.5 + grove[1] * 0.5 + (rng.randf() - 0.5) * 0.3:
				continue
			if kind == "grass":
				if pv > 0.36 + rng.randf() * 0.12:
					continue
			elif pv > 0.3:
				continue
		if _wet(lx, lz, 0.05) or _in_clearing(lx, lz) or _below_sea(lx, lz, r) or _in_rock(lx, lz):
			continue
		if kind != "path_stones" and surface_normal(lx, lz).y < 0.62:
			continue
		match kind:
			"grass":
				_place_grass(b, li, layer, lx, lz, x, z, pv)
			"cluster":
				_place_cluster(b, li, layer, lx, lz)
			_:
				_place_simple(b, li, layer, lx, lz, x, z)


## Plants in lines parallel to the path (lavender fields): row_spacing between the rows, step along them.
## Fields come in patches (region noise), rows start at dist[0] and end at dist[1] beside the path.
func _scatter_rows(b: int, li: int, layer: Dictionary) -> void:
	rng.seed = hash([gen.seed_value, coord.x, coord.y, b, li, 7])
	var row_spacing: float = layer["row_spacing"]
	var step: float = layer["step"]
	var dist: Array = layer["dist"]
	var sc: Array = layer["scale"]
	var models: Array = layer["models"]
	var z := ceilf(corner.y / step) * step
	while z < corner.y + SIZE:
		var r := row_at(z)
		var w := _biome_weight(b, r)
		if w > 0.02:
			for side: float in [-1.0, 1.0]:
				var off: float = dist[0] + row_spacing * 0.5
				while off < dist[1]:
					var here := off
					off += row_spacing
					if rng.randf() > w or rng.randf() > lerpf(0.55, 1.0, clampf(veg, 0.0, 1.0)):
						continue
					var x: float = r["px"] + side * here / r["inv_len"] + rng.randf_range(-0.1, 0.1)
					var lx := x - corner.x
					var lz := z - corner.y + rng.randf_range(-0.15, 0.15)
					if lx < 0.0 or lx >= SIZE or lz < 0.0 or lz >= SIZE:
						continue
					# fields in patches, a few bushes missing
					if gen.region(x * 0.6 + 300.0, z * 0.6) < 0.42 or rng.randf() < 0.06:
						continue
					if gen.path_value(gen.offset_in_row(x, r), r["half_w"]) > 0.2:
						continue
					if _wet(lx, lz, 0.1) or _in_clearing(lx, lz) or _in_rock(lx, lz) or _below_sea(lx, lz, r) or surface_normal(lx, lz).y < 0.8:
						continue
					var model: String = models[rng.randi() % models.size()]
					var xf := _ground_xf(lx, lz, rng.randf_range(sc[0], sc[1]), 0.4, 0.0)
					_add(layer_key(b, li, 0, model), xf, Color(0, 0, 0, rng.randf()))
		z += step


func _pick_style(layer: Dictionary, x: float, z: float) -> int:
	var styles: Array = layer.get("styles", [{}])
	var region_styles: Array = layer.get("region_styles", [])
	if not region_styles.is_empty() and gen.region(x, z) > 0.55:
		return styles.size() + rng.randi() % region_styles.size()
	return rng.randi() % styles.size()


## Instances are batched in sub-cells: smaller batches = more precise frustum culling,
## LOD per cell and view distances that don't depend on the chunk size.
static func cell_size(model: String) -> float:
	if not opt_cells:
		return SIZE
	return 32.0 if (model.contains("Tree") or model.begins_with("Pine") or model.begins_with("Rock_Medium")) else 16.0


func _add(base_key: String, xf: Transform3D, custom: Color) -> void:
	# distant chunks: one batch per chunk (fewer draw calls, fine culling isn't worth it there)
	var cs := SIZE if (lod != 0 and opt_far_batch) else cell_size(base_key.get_slice("/", base_key.get_slice_count("/") - 1))
	var cx := clampi(int(xf.origin.x / cs), 0, int(SIZE / cs) - 1)
	var cz := clampi(int(xf.origin.z / cs), 0, int(SIZE / cs) - 1)
	var key := "%s#%d_%d" % [base_key, cx, cz]
	if not instances.has(key):
		instances[key] = PackedFloat32Array()
		counts[key] = 0
	var b := xf.basis
	var o := xf.origin
	var arr: PackedFloat32Array = instances[key]
	arr.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
		custom.r, custom.g, custom.b, custom.a])
	instances[key] = arr
	counts[key] += 1


func _ground_xf(lx: float, lz: float, scale: float, tilt: float, sink: float) -> Transform3D:
	var bas := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		var up := Vector3.UP.slerp(surface_normal(lx, lz), tilt).normalized()
		bas = Basis(Quaternion(Vector3.UP, up)) * bas
	bas = bas.scaled(Vector3.ONE * scale)
	return Transform3D(bas, Vector3(lx, surface_height(lx, lz) - sink * scale, lz))


func _place_grass(b: int, li: int, layer: Dictionary, lx: float, lz: float, x: float, z: float, pv: float) -> void:
	var models: Array = layer["models"]
	var model: String = models[rng.randi() % models.size()]
	var palette: Array = layer["palette"]
	var region_palette: Array = layer["region_palette"]
	var reg := gen.region(x, z)
	var col: Color
	if reg > 0.45 and rng.randf() < smoothstep(0.45, 0.75, reg):
		col = region_palette[rng.randi() % region_palette.size()]
	else:
		col = palette[rng.randi() % palette.size()]
	col = col.lightened(rng.randf_range(-0.06, 0.07)).srgb_to_linear()
	col.a = rng.randf()
	var sc: Array = layer["scale"]
	var s := rng.randf_range(sc[0], sc[1]) * lerpf(0.75, 1.0, smoothstep(0.2, 0.0, pv))
	_add(layer_key(b, li, 0, model), _ground_xf(lx, lz, s, 0.8, 0.02), col)


func _place_simple(b: int, li: int, layer: Dictionary, lx: float, lz: float, x: float, z: float) -> void:
	var models: Array = layer["models"]
	var model: String = models[rng.randi() % models.size()]
	var sc: Array = layer["scale"]
	var s := rng.randf_range(sc[0], sc[1])
	if layer.has("small_scale_models") and model.begins_with(layer["small_scale_models"]):
		s *= 0.3
	var xf := _ground_xf(lx, lz, s, layer.get("tilt", 0.0), layer.get("sink", 0.0))
	_add(layer_key(b, li, _pick_style(layer, x, z), model), xf, Color(0, 0, 0, rng.randf()))


func _place_cluster(b: int, li: int, layer: Dictionary, lx: float, lz: float) -> void:
	var models: Array = layer["models"]
	var sc: Array = layer["scale"]
	var radius: float = layer["radius"]
	var tint := Color(0, 0, 0, 0)
	var tints: Array = layer.get("tints", [])
	if not tints.is_empty():
		tint = (tints[rng.randi() % tints.size()] as Color).srgb_to_linear()
		tint.a = 1.0
	for k in int(layer["count"]):
		var a := rng.randf() * TAU
		var dd := sqrt(rng.randf()) * radius
		var px := lx + cos(a) * dd
		var pz := lz + sin(a) * dd
		if px < 0.0 or pz < 0.0 or px > SIZE or pz > SIZE:
			continue
		var r := row_at(corner.y + pz)
		if gen.path_value(gen.offset_in_row(corner.x + px, r), r["half_w"]) > 0.3 or _wet(px, pz, 0.05) or _in_clearing(px, pz) or _in_rock(px, pz):
			continue
		var model: String = models[rng.randi() % models.size()]
		var xf := _ground_xf(px, pz, rng.randf_range(sc[0], sc[1]), layer.get("tilt", 0.8), 0.0)
		_add(layer_key(b, li, 0, model), xf, tint if tint.a > 0.0 else Color(0, 0, 0, rng.randf()))


## Trees and rocks: at most one object per grid cell, cells in world coordinates
func _scatter_grid(b: int, li: int, layer: Dictionary) -> void:
	var cell: float = layer["spacing"]
	var chance: float = layer["chance"] * (lerpf(0.6, 1.0, clampf(veg, 0.0, 1.0)) if layer["kind"] == "tree" else 1.0)
	var dist: Array = layer["dist"]
	var falloff: Array = layer.get("falloff", [])
	var grove: Array = layer.get("grove", [])
	var models: Array = layer["models"]
	var sc: Array = layer["scale"]
	var radius: float = layer.get("radius", 2.0)
	var is_rock: bool = layer["kind"] == "rock"
	# rocks from neighboring chunks reach over: record their footprint too
	var margin := 26.0 if is_rock else 0.0
	var c0 := Vector2i(floori((corner.x - margin) / cell), floori((corner.y - margin) / cell))
	var c1 := Vector2i(floori((corner.x + SIZE + margin) / cell), floori((corner.y + SIZE + margin) / cell))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			rng.seed = hash([gen.seed_value, b, li, cx, cz])
			var x := (cx + rng.randf()) * cell
			var z := (cz + rng.randf()) * cell
			var roll := rng.randf()
			var lx := x - corner.x
			var lz := z - corner.y
			var outside := lx < 0.0 or lz < 0.0 or lx >= SIZE or lz >= SIZE
			if outside and not is_rock:
				continue
			if roll > chance:
				continue
			var r := row_at(z)
			if rng.randf() > _biome_weight(b, r):
				continue
			var soff := gen.offset_in_row(x, r)
			var d := absf(soff)
			if d < dist[0] or d > dist[1] or d < radius * 0.5 + r["half_w"] + 1.5:
				continue
			if layer.has("side") and soff * layer["side"] < 0.0:
				continue
			if not falloff.is_empty() and rng.randf() > lerpf(1.0, falloff[2], smoothstep(falloff[0], falloff[1], d)):
				continue
			if not grove.is_empty() and gen.region(x * grove[0] / 0.012, z * grove[0] / 0.012) < 0.5 + grove[1] * 0.5:
				continue
			# grove structure: trees stand in groups with open meadows in between (like in Genshin)
			var gv := gen.grove(x, z) if layer["kind"] == "tree" else 1.0
			if layer["kind"] == "tree" and rng.randf() > lerpf(0.18, 1.0, gv):
				continue
			if layer.get("region_only", false) and gen.region(x, z) < 0.55:
				continue
			if outside:
				# only remember the footprint (same random sequence as in the neighboring chunk)
				rng.randi()
				var so := rng.randf_range(sc[0], sc[1])
				if layer.get("grow_with_dist", false):
					so *= lerpf(0.8, 1.5, clampf((d - dist[0]) / (dist[1] - dist[0]), 0.0, 1.0))
				if not _rock_ground_ok(x, z, so, layer):
					continue
				var sqo: Vector3 = layer.get("squash", Vector3.ONE)
				rock_disks.append(Vector3(lx, lz, 1.35 * so * maxf(sqo.x, sqo.z)))
				continue
			if _blocked(lx, lz, radius):
				continue
			if layer["kind"] == "tree" and (_wet(lx, lz, 0.6) or surface_normal(lx, lz).y < 0.72 or _below_sea(lx, lz, r)):
				continue
			blockers.append(Vector3(lx, lz, radius))
			var model: String = models[rng.randi() % models.size()]
			var s := rng.randf_range(sc[0], sc[1])
			if layer.get("grow_with_dist", false):
				s *= lerpf(0.8, 1.5, clampf((d - dist[0]) / (dist[1] - dist[0]), 0.0, 1.0))
			var style := _pick_style(layer, x, z)
			var key := layer_key(b, li, style, model)
			if layer["kind"] == "rock":
				if not _rock_ground_ok(x, z, s, layer):
					blockers.pop_back()
					continue
				var xf := _rock_xf(lx, lz, s, layer)
				_add(key, xf, Color(0, 0, 0, rng.randf()))
				var sq: Vector3 = layer.get("squash", Vector3.ONE)
				rock_disks.append(Vector3(lx, lz, 1.35 * s * maxf(sq.x, sq.z)))
				if lod == 0 and layer.get("collide", "") == "rock":
					rocks.append([model, xf])
			else:
				var xf2 := _ground_xf(lx, lz, s, 0.0, 0.03)
				var tkey := key + "@far" if (lod != 0 and opt_far_trees) else key
				# wider, rounder crowns; often a bush at the base of broadleaf trees
				if model.begins_with("CommonTree") or model.begins_with("TwistedTree"):
					xf2.basis = xf2.basis.scaled(Vector3(1.34, 0.88, 1.34))
					# in the core of a grove: a second tree right next to it – connected canopies
					if gv > 0.8 and rng.randf() < 0.7 and model.begins_with("CommonTree"):
						var na := rng.randf() * TAU
						var nx := lx + cos(na) * 3.2 * s
						var nz := lz + sin(na) * 3.2 * s
						var nr := row_at(corner.y + nz)
						if nx > 0.0 and nz > 0.0 and nx < SIZE and nz < SIZE and not _wet(nx, nz, 0.6) \
								and absf(gen.offset_in_row(corner.x + nx, nr)) > nr["half_w"] + 3.0 and surface_normal(nx, nz).y > 0.8:
							var xf3 := _ground_xf(nx, nz, s * rng.randf_range(0.8, 1.05), 0.0, 0.03)
							xf3.basis = xf3.basis.scaled(Vector3(1.34, 0.88, 1.34))
							_add(tkey, xf3, Color(0, 0, 0, rng.randf_range(0.05, 1.0)))
							_add_crown(layer, style, model, xf3)
							if lod == 0 and layer.get("collide", "") == "trunk":
								trunks.append([xf3.origin, layer.get("trunk", 0.3) * s, 4.0 * s, xf3, model])
					if lod == 0 and rng.randf() < 0.55:
						var ba := rng.randf() * TAU
						var bx := lx + cos(ba) * 1.2 * s
						var bz := lz + sin(ba) * 1.2 * s
						if bx > 0.0 and bz > 0.0 and bx < SIZE and bz < SIZE:
							_add("under/Bush_Common", _ground_xf(bx, bz, rng.randf_range(1.2, 2.0), 0.3, 0.05), Color(0, 0, 0, rng.randf()))
				# distant chunks: trees with thinned-out, larger leaf cards
				tkey = key + "@far" if (lod != 0 and opt_far_trees) else key
				_add(tkey, xf2, Color(0, 0, 0, rng.randf_range(0.05, 1.0)))
				_add_crown(layer, style, model, xf2)
				if lod == 0 and layer.get("collide", "") == "trunk":
					trunks.append([xf2.origin, layer.get("trunk", 0.3) * s, 4.0 * s, xf2, model])


## Remember the crown if the tree has colorful leaves or blossoms (leaves fall from it later)
func _add_crown(layer: Dictionary, style: int, model: String, xf: Transform3D) -> void:
	if lod != 0:
		return
	var st: Array = layer.get("styles", [{}]) + layer.get("region_styles", [])
	var lv: Dictionary = (st[style] as Dictionary).get("leaves", {}) if style < st.size() else {}
	if lv.is_empty():
		return
	var light: Color = lv["color_light"]
	if light.r < light.g * 0.95:
		return
	var sc := xf.basis.get_scale()
	var twisted := model.begins_with("TwistedTree")
	var h := 16.5 if twisted else 7.8
	var rad := 5.0 if twisted else 2.2
	var c := (lv["color_dark"] as Color).lerp(light, 0.55)
	crowns.append_array([corner.x + xf.origin.x, xf.origin.y + h * 0.7 * sc.y, corner.y + xf.origin.z, rad * sc.x * 0.8, c.r, c.g, c.b])


func _blocked(lx: float, lz: float, radius: float) -> bool:
	for bl in blockers:
		var dx := bl.x - lx
		var dz := bl.y - lz
		var lim := (bl.z + radius) * 0.7
		if dx * dx + dz * dz < lim * lim:
			return true
	return false


## Rocks only where the ground below is reasonably flat (no rocks sticking out over edges).
## World coordinates, so neighboring chunks get the same result.
func _rock_ground_ok(x: float, z: float, s: float, layer: Dictionary) -> bool:
	var squash: Vector3 = layer.get("squash", Vector3.ONE)
	var rr := s * 1.3 * maxf(squash.x, squash.z)
	var lo := INF
	var hi := -INF
	for a in 8:
		var ang := a * TAU / 8.0
		for f in [0.5, 1.0]:
			var h := gen.height(x + cos(ang) * rr * f, z + sin(ang) * rr * f)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	# large rocks may have a bit more slope, they sink in deeper then
	return hi - lo < maxf(s * squash.y * 0.55, 0.8)


func _rock_xf(lx: float, lz: float, s: float, layer: Dictionary) -> Transform3D:
	var squash: Vector3 = layer.get("squash", Vector3.ONE)
	var bas := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12))
	bas = bas.scaled(squash * s)
	var rr := s * 1.1 * maxf(squash.x, squash.z)
	var lo := gen.height(corner.x + lx, corner.y + lz)
	var sum := lo
	for a in 6:
		var ang := a * TAU / 6.0
		var h := gen.height(corner.x + lx + cos(ang) * rr, corner.y + lz + sin(ang) * rr)
		lo = minf(lo, h)
		sum += h
	var y := lerpf(lo, sum / 7.0, 0.4)
	# Genshin-style boulders: well sunk in, look heavy
	return Transform3D(bas, Vector3(lx, y - (layer.get("sink", 0.2) + 0.08) * s * squash.y, lz))


func _scatter_on_trunks(b: int, li: int, layer: Dictionary) -> void:
	rng.seed = hash([gen.seed_value, coord.x, coord.y, b, li, 5])
	var chance: float = layer["on_trunks"]
	var model: String = layer["models"][0]
	var sc: Array = layer["scale"]
	for t in trunks:
		if rng.randf() > chance:
			continue
		var base: Vector3 = t[0]
		var r := row_at(corner.y + base.z)
		if absf(gen.offset_in_row(corner.x + base.x, r)) > 16.0:
			continue
		var ang := rng.randf() * TAU
		var rad: float = t[1] * 0.9
		var pos := base + Vector3(cos(ang) * rad, rng.randf_range(0.3, 1.3), sin(ang) * rad)
		var bas := Basis(Vector3.UP, -ang + PI * 0.5).scaled(Vector3.ONE * rng.randf_range(sc[0], sc[1]))
		_add(layer_key(b, li, 0, model), Transform3D(bas, pos), Color())
