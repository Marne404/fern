class_name BiomeDefs
extends RefCounted
## All biomes as data: terrain shape, colors, atmosphere and scatter layers.
##
## Scatter layers ("layers"):
##     kind      grass | detail | cluster | tree | rock | path_stones
##     models    model names from assets/nature
##     styles    list of material styles (picked at random); region_styles for region patches
##     density   instances per 1000 m² (grass/detail/cluster/path_stones)
##     spacing   grid size in m for tree/rock (at most one object per cell), chance = probability
##     dist      [min, max] distance to the path center; falloff [d0, d1, factor] thins out towards the outside
##     scale     [min, max]; squash = Vector3 for rocks; sink = sinking relative to size
##     grove     [frequency, threshold] groves/clearings via noise
##     near      only in near chunks (grass, small stuff)
##     collide   "trunk" (radius) | "rock"

const NAMES := ["Autumn Meadow", "Forest Trail", "Desert Valley", "Blossom Grove", "Spring Meadow", "Red Maple Wood", "Mountain Pines", "Deadwood Bog",
	"Sunset Coast", "Cliff Lands", "Glowing Forest", "Lake Country", "Lavender Hills", "Birch Wood", "Heather Highlands"]

const GRASS := ["Grass_Common_Tall", "Grass_Common_Short", "Grass_Wispy_Tall", "Grass_Wispy_Short"]
const SHORT_GRASS := ["Grass_Common_Short", "Grass_Wispy_Short"]
const COMMON := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"]
const PINES := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const TWISTED := ["TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "TwistedTree_4", "TwistedTree_5"]
const DEAD := ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const PEBBLES := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_4", "Pebble_Round_5",
	"RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3"]
const PAVING := ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3", "RockPath_Round_Thin",
	"RockPath_Round_Wide", "Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3"]
const FLOWERS := ["Flower_3_Group", "Flower_3_Single", "Flower_4_Single"]
const PLANTS := ["Plant_1", "Plant_1_Big", "Plant_7", "Plant_7_Big"]
# Pro kit
const BIRCHES := ["Birch_1", "Birch_2", "Birch_3", "Birch_4", "Birch_5"]
const CHERRIES := ["CherryBlossom_1", "CherryBlossom_2", "CherryBlossom_3", "CherryBlossom_4", "CherryBlossom_5"]
const GIANT_PINES := ["GiantPine_1", "GiantPine_2", "GiantPine_3", "GiantPine_4", "GiantPine_5"]
const TALL := ["TallThick_1", "TallThick_2", "TallThick_3", "TallThick_4", "TallThick_5"]
const BIG_ROCKS := ["Rock_Big_1", "Rock_Big_2"]
const HEDGE := ["Bush_Long_1", "Bush_Long_2"]
const WILDFLOWERS := ["Flower_1_Group", "Flower_2_Group", "Flower_7_Group", "Flower_1_Single", "Flower_2_Single", "Flower_7_Single"]


static func all() -> Array[Dictionary]:
	return [meadow(), forest(), desert(), blossom(), spring(), maple(), alpine(), bog(), coast(), cliffs(), glow(), lakes(),
		lavender(), birch_wood(), highlands()]


# ================================================================ Style building blocks

static func leaves(dark: Color, light: Color, extra := {}) -> Dictionary:
	var d := {"color_dark": dark, "color_light": light, "translucency": 0.8}
	d.merge(extra, true)
	return d


static func tree_style(dark: Color, light: Color, bark := {}, stiffness := 5.0, extra := {}) -> Dictionary:
	return {"leaves": leaves(dark, light, extra), "bark": bark, "stiffness": stiffness}


static func birch_bark() -> Dictionary:
	return {"desaturate": 1.0, "tint": Color(1.4, 1.28, 1.08), "brightness": 1.8, "birch_marks": 1.0, "normal_strength": 0.6}


static func rock_style(flat: Color, moss := 0.4, triplanar := false, extra := {}) -> Dictionary:
	var r := {"moss_amount": moss, "moss_color": Color(0.5, 0.66, 0.18), "brightness": 1.15, "top_light": 0.5,
		"flatten": 0.6, "flat_color": flat.lerp(Color(0.8, 0.8, 0.8), 0.35)}
	if triplanar:
		r["triplanar"] = 1.0
		r["triplanar_scale"] = 0.09
	r.merge(extra, true)
	return {"rock": r}


static func terrain(values: Dictionary) -> Dictionary:
	var t := {
		"path_width": 3.2, "valley_width": 16.0, "valley_ramp": 55.0, "valley_height": 16.0,
		"undulation": 1.2, "path_depth": 0.18, "roughness": 0.0,
		"grass_dark": Color(0.3, 0.52, 0.08), "grass_light": Color(0.5, 0.7, 0.14),
		"region_dark": Color(0.78, 0.46, 0.12), "region_light": Color(0.9, 0.62, 0.2),
		"slope_color": Color(0.5, 0.55, 0.62), "path_color": Color(0.74, 0.63, 0.38),
		"crack": 0.8, "ripple": 0.0,
		"ponds": 0.0, "pond_size": Vector2(9.0, 18.0),
		"water_shallow": Color(0.35, 0.78, 0.72), "water_deep": Color(0.08, 0.32, 0.5),
		"snow": 0.0, "snow_color": Color(0.93, 0.96, 1.0),
		"terraces": 0.0,
		"far_height": 50.0, "dunes": 0.0,
		"litter": 0.0, "litter_color": Color(0.6, 0.45, 0.25),
		"obstacles": ["river", "fallen_tree", "cliff"],
		# chance of a brook beside the path per 700 m
		"brooks": 0.5,
		# terrain variety: scree on steep flanks, erosion gullies, hummocky meadows (0..1)
		"scree": 0.0, "gullies": 0.0, "hummocks": 0.0,
	}
	t.merge(values, true)
	# linearize colors once (vertex colors reach the shader without conversion)
	for k in t:
		if t[k] is Color and not k.begins_with("water"):
			t[k] = (t[k] as Color).srgb_to_linear()
	return t


static func atmosphere(values: Dictionary) -> Dictionary:
	var a := {
		"sun_dir": Vector3(0.45, -0.55, 0.7), "sun_color": Color(1.0, 0.93, 0.8), "sun_energy": 1.8,
		"ambient_energy": 0.42, "ambient_color": Color(0.6, 0.78, 0.5),
		"fog_color": Color(0.8, 0.9, 0.95), "fog_density": 0.0018, "fog_sun_scatter": 0.25,
		"volumetric": 0.0, "exposure": 0.92, "saturation": 1.08,
		"zenith_color": Color(0.26, 0.62, 0.93), "horizon_color": Color(0.78, 0.92, 0.98),
		"cloud_coverage": 0.5, "cirrus_amount": 0.8, "cloud_shadow": Color(0.62, 0.72, 0.88),
		"particles": "motes", "particle_color": Color(1.0, 0.95, 0.7), "butterflies": 4,
		"mountain_color": Color(0.46, 0.56, 0.5), "mountain_shadow": Color(0.36, 0.44, 0.56),
		"mountain_snow": 0.25, "mountain_scale": 1.0, "birds": true, "temperature": 16.0, "rainbow": 0.0, "sun_glow": 0.35,
		"gusts": 0.5, "dust": 0.0,
		# how much the biome follows the clock by day (1 = fully) and how much morning mist gathers in it
		"clock": 1.0, "mist_amount": 1.0,
		# how often showers come (0 = never)
		"rain": 1.0,
		# sunbeams through the tree crowns (0 = none)
		"shafts": 0.0,
		# deer at the edge of the woods
		"deer": false,
		# waterfalls on the backdrop mountains
		"falls": 0.0,
		# color grading: tint of the shadows and highlights, warmth (−1 cool … 1 warm), contrast
		"grade_shadow": Color(0.35, 0.55, 0.75), "grade_high": Color(1.0, 0.86, 0.62), "grade_warm": 0.0, "grade_contrast": 0.25,
		# the biome's own small effects (BiomeFx): {name: strength}
		"fx": {},
	}
	a.merge(values, true)
	return a


static func blades(height: float, root: Color, tip: Color, tip2: Color) -> Dictionary:
	return {"height": height, "root": root, "tip": tip, "tip2": tip2}


## Giant tree as a landmark: rare, huge, visible from afar
static func hero_tree(models: Array, style: Dictionary, scale: Vector2) -> Dictionary:
	return {"kind": "tree", "models": models, "styles": [style], "spacing": 320.0, "chance": 0.6, "dist": [24.0, 110.0],
		"scale": [scale.x, scale.y], "radius": 14.0, "collide": "trunk", "trunk": 0.3}


# Common layers ----------------------------------------------------------

static func grass_layer(palette: Array, region_palette: Array, density := 2400.0, scale := Vector2(0.45, 0.8), models := GRASS) -> Dictionary:
	return {"kind": "grass", "models": models, "density": density, "dist": [0.0, 90.0], "falloff": [5.0, 50.0, 0.3],
		"scale": [scale.x, scale.y], "palette": palette, "region_palette": region_palette, "near": true}


static func pebble_layer(style: Dictionary, density := 30.0) -> Dictionary:
	return {"kind": "detail", "models": PEBBLES, "styles": [style], "density": density, "dist": [0.0, 5.5],
		"scale": [1.0, 2.2], "small_scale_models": "RockPath", "sink": 0.02, "tilt": 1.0, "shadows": false, "vis": 55.0, "near": true}


static func small_rock_layer(style: Dictionary, density := 3.0, dist := [2.0, 12.0]) -> Dictionary:
	return {"kind": "detail", "models": ROCKS, "styles": [style], "density": density, "dist": dist,
		"scale": [0.15, 0.45], "sink": 0.1, "tilt": 0.6, "shadows": false, "vis": 80.0, "near": true, "on_path": false}


## Loose stones on scree slopes
static func scree_layer(style: Dictionary, density := 60.0) -> Dictionary:
	return {"kind": "detail", "models": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_2", "Pebble_Round_4"],
		"styles": [style], "density": density, "dist": [5.0, 110.0], "slope": [0.18, 0.64], "scale": [0.12, 0.42],
		"sink": 0.08, "tilt": 1.0, "shadows": false, "vis": 100.0, "near": true, "calm": true}


## Big lone boulders the glaciers left behind, mossy on top
static func erratic_layer(style: Dictionary, spacing := 110.0) -> Dictionary:
	return {"kind": "rock", "models": ROCKS, "styles": [style], "spacing": spacing, "chance": 0.45, "dist": [16.0, 170.0],
		"scale": [3.4, 6.2], "squash": Vector3(1.25, 0.95, 1.1), "sink": 0.24, "radius": 6.0, "collide": "rock", "calm": true}


static func cluster_layer(models: Array, density: float, dist: Array, count: int, radius: float, scale: Array, shadows := false, style := {}) -> Dictionary:
	return {"kind": "cluster", "models": models, "styles": [style], "density": density, "dist": dist, "count": count,
		"radius": radius, "scale": scale, "shadows": shadows, "vis": 60.0, "near": true, "tilt": 0.8}


## A layer thinned out in some patches (keeps its index and scatter otherwise)
static func thinned(layer: Dictionary, thin: Dictionary) -> Dictionary:
	layer["thin"] = thin
	return layer


## Real birches of the Pro kit: the kit's white bark, only a little warmer
static func birch_style(dark: Color, light: Color, extra := {}) -> Dictionary:
	var e := {"translucency": 1.0}
	e.merge(extra, true)
	return tree_style(dark, light, {"tint": Color(1.06, 1.02, 0.96), "brightness": 1.95, "ao_strength": 0.45, "desaturate": 0.3}, 4.5, e)


## Hedgerows: lines of long bushes parallel to the path, with gaps (fields between them)
static func hedge_layer(style: Dictionary, row_spacing := 18.0, dist := [7.0, 90.0]) -> Dictionary:
	return {"kind": "rows", "models": HEDGE, "styles": [style], "row_spacing": row_spacing, "step": 1.25,
		"dist": dist, "scale": [1.15, 1.6], "shadows": true, "vis": 150.0, "near": true}


## Shelf fungi on the trunks near the path
static func oyster_layer(chance := 0.25) -> Dictionary:
	return {"kind": "detail", "models": ["Mushroom_Oyster"], "styles": [{}], "density": 0.0, "on_trunks": chance,
		"scale": [0.35, 0.55], "shadows": false, "vis": 60.0, "near": true}


# ================================================================ 1 Autumn Meadow

static func meadow() -> Dictionary:
	var green := tree_style(Color(0.28, 0.55, 0.08), Color(0.72, 0.93, 0.28), {"tint": Color(0.95, 0.85, 0.8)})
	var orange := tree_style(Color(0.85, 0.3, 0.06), Color(1.0, 0.68, 0.2), birch_bark(), 4.5, {"translucency": 0.9})
	var red := tree_style(Color(0.72, 0.12, 0.04), Color(0.98, 0.42, 0.12), birch_bark(), 4.5, {"translucency": 0.9})
	var yellow := tree_style(Color(0.85, 0.52, 0.08), Color(1.0, 0.82, 0.3), birch_bark(), 4.5, {"translucency": 0.9})
	var maple_style := tree_style(Color(0.62, 0.1, 0.05), Color(0.95, 0.35, 0.12), {"tint": Color(0.9, 0.88, 0.85)}, 7.0)
	var bush := {"leaves": leaves(Color(0.2, 0.45, 0.08), Color(0.5, 0.8, 0.18), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var bush_autumn := {"leaves": leaves(Color(0.7, 0.25, 0.05), Color(0.98, 0.6, 0.15), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var rock := rock_style(Color(0.62, 0.64, 0.6))
	var cliff := rock_style(Color(0.64, 0.66, 0.62), 0.5, true)
	var birch_gold := birch_style(Color(0.78, 0.5, 0.06), Color(1.0, 0.85, 0.28))
	var birch_orange := birch_style(Color(0.84, 0.3, 0.05), Color(1.0, 0.64, 0.2))
	var birch_late := birch_style(Color(0.5, 0.56, 0.1), Color(0.92, 0.9, 0.36))
	var lone_amber := tree_style(Color(0.8, 0.36, 0.06), Color(1.0, 0.7, 0.26), {"tint": Color(0.95, 0.85, 0.78)}, 6.0, {"translucency": 0.9})
	var lone_rust := tree_style(Color(0.62, 0.18, 0.05), Color(0.96, 0.46, 0.16), {"tint": Color(0.95, 0.85, 0.78)}, 6.0, {"translucency": 0.9})
	var hedge := {"leaves": leaves(Color(0.16, 0.34, 0.06), Color(0.58, 0.7, 0.18), {"sphere_normals": 0.8}), "stiffness": 7.0}
	var stubble := [Color(0.94, 0.8, 0.42), Color(0.88, 0.72, 0.34), Color(0.98, 0.86, 0.5), Color(0.84, 0.66, 0.3)]
	var asters := cluster_layer(WILDFLOWERS, 0.8, [2.5, 30.0], 7, 1.8, [0.4, 0.7])
	asters["tints"] = [Color(0.62, 0.45, 1.0), Color(0.75, 0.55, 1.0), Color(1.0, 0.86, 0.2), Color(1.0, 0.95, 0.85)]
	var bracken := cluster_layer(["Fern_2"], 0.9, [3.0, 40.0], 3, 2.0, [0.22, 0.34], true, {"plant": {"texture_tint": Color(1.35, 0.72, 0.32)}})
	bracken["patch"] = [1, 3]
	var agarics := cluster_layer(["Mushroom_RedCap"], 0.7, [2.5, 30.0], 3, 0.8, [0.35, 0.6])
	agarics["patch"] = [1]
	var hedges := hedge_layer(hedge, 27.0)
	hedges["patch"] = [2]
	return {
		"name": NAMES[0],
		"under_bush": {"dark": Color(0.45, 0.4, 0.08), "light": Color(0.9, 0.7, 0.2)},
		# meadow as before · golden birch stands · hedged stubble fields · wide meadows with lone trees
		"patches": [{"name": "meadow", "share": 0.42}, {"name": "birch stand", "share": 0.22},
			{"name": "hedge fields", "share": 0.2}, {"name": "lone trees", "share": 0.16}],
		"blades": blades(0.5, Color(0.16, 0.32, 0.05), Color(0.55, 0.82, 0.18), Color(0.98, 0.6, 0.16)),
		"terrain": terrain({"scree": 0, "gullies": 0.4, "hummocks": 0.8, "brooks": 0.6, "litter": 0.55, "litter_color": Color(0.92, 0.5, 0.16), "far_height": 60.0, "ponds": 0.3, "terraces": 7.0, "valley_height": 20.0,
			"obstacles": ["river", "fallen_tree", "cliff", "stile"]}),
		"atmosphere": atmosphere({"fx": {"gossamer": 1.0}, "grade_shadow": Color(0.42, 0.45, 0.72), "grade_high": Color(1.0, 0.82, 0.55), "grade_warm": 0.35, "deer": true, "shafts": 0.35, "mountain_color": Color(0.52, 0.56, 0.44), "mountain_snow": 0.2, "particles": "leaves", "particle_color": Color(1.0, 0.5, 0.12), "butterflies": 10, "gusts": 0.85}),
		"layers": [
			thinned(grass_layer([Color(0.42, 0.74, 0.1), Color(0.34, 0.64, 0.08), Color(0.55, 0.8, 0.14), Color(0.48, 0.72, 0.12)],
				[Color(0.98, 0.55, 0.14), Color(0.95, 0.35, 0.1), Color(1.0, 0.75, 0.25), Color(0.85, 0.22, 0.08), Color(0.7, 0.85, 0.2)]), {2: 0.45}),
			{"kind": "tree", "models": COMMON, "styles": [green], "region_styles": [orange, orange, red, yellow],
				"spacing": 8.0, "chance": 0.85, "dist": [6.0, 400.0], "falloff": [12.0, 160.0, 0.6], "grove": [0.022, -0.05],
				"scale": [1.1, 1.8], "radius": 2.8, "collide": "trunk", "trunk": 0.3, "thin": {1: 0.3, 2: 0.25, 3: 0.12}},
			hero_tree(["CommonTree_1", "CommonTree_3"], green, Vector2(4.0, 5.0)),
			{"kind": "tree", "models": TWISTED, "styles": [maple_style], "spacing": 45.0, "chance": 0.35, "region_only": true,
				"dist": [14.0, 400.0], "scale": [0.55, 0.75], "radius": 5.0, "collide": "trunk", "trunk": 0.5, "thin": {1: 0.2, 2: 0.3}},
			{"kind": "rock", "models": ROCKS, "styles": [cliff], "spacing": 40.0, "chance": 0.3, "dist": [15.0, 70.0],
				"scale": [2.5, 5.0], "squash": Vector3(1.3, 1.0, 1.1), "sink": 0.18, "radius": 6.0, "collide": "rock"},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 26.0, "chance": 0.3, "dist": [6.0, 45.0],
				"scale": [1.1, 2.6], "sink": 0.15, "radius": 2.5, "collide": "rock"},
			{"kind": "detail", "models": ["Bush_Common", "Bush_Common_Flowers"], "styles": [bush], "region_styles": [bush_autumn],
				"density": 2.5, "dist": [4.0, 26.0], "scale": [0.9, 1.6], "shadows": true, "vis": 110.0, "near": true, "tilt": 0.3},
			cluster_layer(FLOWERS, 0.9, [2.5, 26.0], 6, 1.8, [0.45, 0.75]),
			cluster_layer(["Clover_1", "Clover_2"], 0.5, [2.5, 26.0], 7, 1.5, [0.6, 1.0]),
			cluster_layer(["Fern_1"], 0.45, [3.0, 30.0], 1, 1.0, [0.28, 0.38], true),
			cluster_layer(PLANTS, 0.3, [2.5, 26.0], 3, 1.2, [0.6, 1.0]),
			cluster_layer(["Mushroom_Common"], 0.6, [2.0, 5.0], 4, 0.5, [0.9, 1.6]),
			pebble_layer(rock_style(Color(0.7, 0.71, 0.68), 0.0, false, {"top_light": 0.3})),
			small_rock_layer(rock),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			erratic_layer(rock_style(Color(0.66, 0.67, 0.64), 0.7), 150.0),
			# round 12: birch stands, hedged stubble fields, lone trees
			{"kind": "tree", "models": BIRCHES, "styles": [birch_gold, birch_gold, birch_orange, birch_late], "spacing": 6.5, "chance": 0.8,
				"dist": [5.5, 400.0], "patch": [1], "scale": [0.6, 0.95], "radius": 2.2, "collide": "trunk", "trunk": 0.2},
			hedges,
			{"kind": "grass", "models": ["Grass_Wheat", "Grass_Wheat", "Grass_Wispy_Short"], "density": 1100.0, "dist": [5.0, 95.0],
				"scale": [0.32, 0.5], "palette": stubble, "region_palette": stubble, "near": true, "patch": [2]},
			{"kind": "tree", "models": TALL, "styles": [lone_amber, lone_amber, lone_rust], "spacing": 42.0, "chance": 0.75,
				"dist": [9.0, 400.0], "patch": [3], "scale": [0.72, 1.0], "radius": 4.0, "collide": "trunk", "trunk": 0.35},
			asters,
			bracken,
			agarics,
			oyster_layer(0.2),
		],
	}


# ================================================================ 2 Forest Trail

static func forest() -> Dictionary:
	var pine := tree_style(Color(0.12, 0.36, 0.08), Color(0.42, 0.72, 0.16), {"tint": Color(1.0, 0.82, 0.72), "brightness": 1.05}, 7.0,
		{"sphere_normals": 0.55, "translucency": 0.6})
	var broad := tree_style(Color(0.2, 0.48, 0.06), Color(0.62, 0.88, 0.22), {"tint": Color(1.0, 0.85, 0.75)}, 6.0)
	var autumn := tree_style(Color(0.85, 0.32, 0.08), Color(1.0, 0.6, 0.25), {"desaturate": 0.8, "brightness": 1.5, "tint": Color(1.1, 1.08, 1.0)}, 7.0, {"translucency": 1.0})
	var rock := rock_style(Color(0.74, 0.75, 0.72), 0.35)
	var cliff := rock_style(Color(0.74, 0.75, 0.72), 0.45, true)
	var giant := tree_style(Color(0.07, 0.28, 0.12), Color(0.34, 0.6, 0.22), {"tint": Color(1.0, 0.84, 0.74), "brightness": 1.0}, 9.0,
		{"sphere_normals": 0.5, "translucency": 0.5})
	var giant_blue := tree_style(Color(0.06, 0.25, 0.16), Color(0.3, 0.56, 0.3), {"tint": Color(1.0, 0.84, 0.74), "brightness": 1.0}, 9.0,
		{"sphere_normals": 0.5, "translucency": 0.5})
	var undergrowth := {"leaves": leaves(Color(0.12, 0.34, 0.06), Color(0.46, 0.74, 0.18), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var mossy := rock_style(Color(0.7, 0.72, 0.68), 0.75, true, {"triplanar_scale": 0.08})
	var ferns := cluster_layer(["Fern_2"], 14.0, [2.3, 45.0], 7, 3.2, [0.4, 0.62], true)
	ferns["patch"] = [2]
	var blue_plants := cluster_layer(["Plant_2", "Plant_2_Big"], 0.8, [2.5, 35.0], 3, 1.4, [0.6, 1.0], true)
	blue_plants["patch"] = [2]
	var glade := cluster_layer(WILDFLOWERS, 5.0, [2.5, 45.0], 10, 2.8, [0.45, 0.75])
	glade["tints"] = [Color(1.0, 1.0, 0.95), Color(1.0, 0.88, 0.25), Color(0.7, 0.55, 1.0)]
	glade["patch"] = [3]
	var glade_bush := {"kind": "detail", "models": ["Bush_Large_Flowers", "Bush_Common_Flowers"], "styles": [undergrowth], "density": 1.6,
		"dist": [5.0, 40.0], "scale": [0.7, 1.1], "shadows": true, "vis": 130.0, "near": true, "tilt": 0.3, "patch": [3]}
	var agarics := cluster_layer(["Mushroom_RedCap"], 0.5, [2.2, 14.0], 3, 0.7, [0.3, 0.55])
	return {
		"name": NAMES[1],
		# forest as before · old growth with giant pines · fern hollow · sunny clearing
		"patches": [{"name": "forest", "share": 0.4}, {"name": "old growth", "share": 0.25},
			{"name": "fern hollow", "share": 0.2}, {"name": "clearing", "share": 0.15}],
		"blades": blades(0.4, Color(0.1, 0.28, 0.05), Color(0.5, 0.8, 0.18), Color(0.78, 0.8, 0.25)),
		"terrain": terrain({"scree": 0, "gullies": 0.4, "hummocks": 0.2, "brooks": 0.8, "litter": 0.6, "litter_color": Color(0.55, 0.38, 0.2), "far_height": 55.0, "obstacles": ["fallen_tree", "fallen_tree", "river", "mud"], "ponds": 0.3, "path_width": 2.8, "valley_width": 12.0, "valley_ramp": 70.0, "valley_height": 12.0, "undulation": 1.4,
			"grass_dark": Color(0.3, 0.54, 0.1), "grass_light": Color(0.55, 0.74, 0.18),
			"region_dark": Color(0.55, 0.62, 0.18), "region_light": Color(0.7, 0.72, 0.28),
			"path_color": Color(0.78, 0.68, 0.42), "slope_color": Color(0.42, 0.52, 0.2), "crack": 0.9}),
		"atmosphere": atmosphere({"grade_shadow": Color(0.3, 0.55, 0.62), "grade_high": Color(0.98, 0.92, 0.66), "grade_warm": 0.05, "falls": 0.6, "deer": true, "shafts": 0.9, "rain": 1.1, "temperature": 15.0, "mountain_color": Color(0.32, 0.46, 0.38), "mountain_snow": 0.15, "mountain_scale": 0.9, "sun_dir": Vector3(-0.35, -0.6, 0.72), "sun_color": Color(1.0, 0.93, 0.78), "sun_energy": 1.7,
			"ambient_energy": 0.7, "ambient_color": Color(0.62, 0.78, 0.45), "fog_color": Color(0.84, 0.92, 0.9),
			"fog_density": 0.003, "fog_sun_scatter": 0.3, "volumetric": 0.007, "exposure": 0.9,
			"zenith_color": Color(0.3, 0.62, 0.9), "horizon_color": Color(0.82, 0.93, 0.97), "cloud_coverage": 0.54,
			"cirrus_amount": 0.4, "particles": "motes", "butterflies": 5}),
		"layers": [
			thinned(grass_layer([Color(0.55, 0.86, 0.2), Color(0.45, 0.78, 0.16), Color(0.7, 0.92, 0.3), Color(0.62, 0.86, 0.24)],
				[Color(0.92, 0.72, 0.25), Color(0.85, 0.6, 0.2), Color(0.8, 0.82, 0.3)], 2000.0), {2: 0.35}),
			{"kind": "tree", "models": PINES, "styles": [pine], "spacing": 7.5, "chance": 0.8, "dist": [5.5, 400.0],
				"falloff": [20.0, 120.0, 0.55], "scale": [1.5, 2.3], "radius": 3.0, "collide": "trunk", "trunk": 0.35,
				"thin": {1: 0.45, 2: 0.7, 3: 0.08}},
			{"kind": "tree", "models": COMMON, "styles": [broad], "spacing": 13.0, "chance": 0.6, "dist": [5.5, 300.0],
				"scale": [1.2, 1.8], "radius": 3.0, "collide": "trunk", "trunk": 0.3, "thin": {1: 0.3, 2: 0.7, 3: 0.08}},
			hero_tree(["Pine_4", "Pine_2"], pine, Vector2(4.2, 5.0)),
			{"kind": "tree", "models": ["TwistedTree_2"], "styles": [autumn], "spacing": 160.0, "chance": 0.5, "dist": [7.0, 25.0],
				"scale": [0.5, 0.6], "radius": 5.0, "collide": "trunk", "trunk": 0.5},
			{"kind": "rock", "models": ROCKS, "styles": [cliff, rock], "spacing": 28.0, "chance": 0.35, "dist": [6.0, 40.0],
				"scale": [1.2, 3.2], "squash": Vector3(1.3, 0.9, 1.1), "sink": 0.2, "radius": 3.0, "collide": "rock"},
			cluster_layer(["Fern_1"], 1.0, [2.5, 30.0], 2, 1.5, [0.28, 0.42], true),
			cluster_layer(["Clover_1", "Clover_2"], 0.9, [2.5, 22.0], 10, 1.6, [0.7, 1.1]),
			cluster_layer(["Plant_1", "Plant_1_Big", "Plant_7_Big"], 0.7, [2.5, 22.0], 2, 1.2, [0.5, 0.9], true),
			cluster_layer(["Flower_3_Group", "Flower_3_Single"], 0.4, [2.5, 20.0], 4, 1.4, [0.45, 0.7]),
			cluster_layer(["Mushroom_Common"], 0.8, [2.0, 8.0], 5, 0.6, [0.9, 1.7]),
			{"kind": "detail", "models": ["Mushroom_Laetiporus"], "styles": [{}], "density": 0.0, "on_trunks": 0.35,
				"scale": [0.6, 0.9], "shadows": false, "vis": 60.0, "near": true},
			pebble_layer(rock_style(Color(0.74, 0.75, 0.72), 0.0, false, {"top_light": 0.3}), 22.0),
			small_rock_layer(rock),
			# round 12: giant pines, fern hollows, clearings
			{"kind": "tree", "models": GIANT_PINES, "styles": [giant, giant, giant_blue], "spacing": 11.0, "chance": 0.75,
				"dist": [7.0, 400.0], "patch": [1], "scale": [1.3, 1.9], "radius": 4.5, "collide": "trunk", "trunk": 0.42},
			{"kind": "tree", "models": GIANT_PINES, "styles": [giant], "spacing": 55.0, "chance": 0.55,
				"dist": [9.0, 400.0], "patch": [0, 2], "scale": [1.4, 2.0], "radius": 4.5, "collide": "trunk", "trunk": 0.42},
			{"kind": "rock", "models": BIG_ROCKS, "styles": [mossy], "spacing": 34.0, "chance": 0.45, "dist": [7.0, 60.0],
				"patch": [1, 2], "scale": [0.8, 1.5], "sink": 0.2, "radius": 5.0, "collide": "rock"},
			ferns,
			blue_plants,
			glade,
			glade_bush,
			{"kind": "detail", "models": ["Bush_Large", "Bush_Long_1", "Bush_Long_2"], "styles": [undergrowth], "density": 1.4,
				"dist": [4.5, 22.0], "scale": [0.7, 1.15], "shadows": true, "vis": 120.0, "near": true, "tilt": 0.3},
			agarics,
			oyster_layer(0.18),
		],
	}


# ================================================================ 3 Desert Valley

static func desert() -> Dictionary:
	var mesa := rock_style(Color(0.86, 0.6, 0.3), 0.0, true, {"triplanar_scale": 0.05, "tint": Color(1.05, 0.9, 0.72), "brightness": 1.25,
		"top_light": 0.35, "flatten": 0.65})
	mesa["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
	var sandstone := rock_style(Color(0.86, 0.6, 0.3), 0.0, false, {"tint": Color(1.05, 0.92, 0.78), "brightness": 1.2, "flatten": 0.4})
	sandstone["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
	var dead := {"bark": {"tint": Color(0.62, 0.6, 0.6), "brightness": 0.95, "desaturate": 0.7, "ao_strength": 0.5}, "stiffness": 14.0}
	var dry := [Color(0.95, 0.78, 0.3), Color(0.88, 0.66, 0.22), Color(0.98, 0.85, 0.4), Color(0.9, 0.42, 0.12), Color(0.8, 0.62, 0.25)]
	var butte := rock_style(Color(0.9, 0.62, 0.32), 0.0, true, {"triplanar_scale": 0.035, "tint": Color(1.06, 0.9, 0.72), "brightness": 1.25,
		"top_light": 0.4, "flatten": 0.7})
	butte["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
	var boulder := rock_style(Color(0.9, 0.64, 0.34), 0.0, false, {"tint": Color(1.06, 0.92, 0.76), "brightness": 1.22, "flatten": 0.45})
	boulder["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
	var paving := rock_style(Color(0.86, 0.72, 0.52), 0.0, false, {"top_light": 0.3, "flatten": 0.5, "tint": Color(1.04, 0.96, 0.86)})
	paving["rock"]["texture"] = "PathRocks_Desert_Diffuse.png"
	var hardy := cluster_layer(["Plant_3", "Plant_4", "Plant_5", "Plant_4"], 1.4, [3.0, 30.0], 3, 1.2, [0.5, 0.85], true,
		{"plant": {"texture_tint": Color(1.35, 0.72, 0.4)}})
	hardy["patch"] = [1]
	var wash_grass := {"kind": "grass", "models": ["Grass_Wide_Short", "Grass_Wide_Tall", "Grass_Wispy_Short"], "density": 420.0,
		"dist": [3.0, 60.0], "scale": [0.4, 0.75], "palette": dry, "region_palette": dry, "near": true, "patch": [2]}
	var wash_pebbles := {"kind": "detail", "models": PEBBLES, "styles": [boulder], "density": 26.0, "dist": [4.0, 40.0], "patch": [2],
		"scale": [0.6, 1.6], "small_scale_models": "RockPath", "sink": 0.03, "tilt": 1.0, "shadows": false, "vis": 55.0, "near": true}
	return {
		"name": NAMES[2],
		# dunes as before · rock garden · dry wash · mesa field
		"patches": [{"name": "dunes", "share": 0.4}, {"name": "rock garden", "share": 0.25},
			{"name": "dry wash", "share": 0.2}, {"name": "mesa field", "share": 0.15}],
		"blades": blades(0.0, Color(0.5, 0.4, 0.2), Color(0.9, 0.75, 0.35), Color(0.9, 0.6, 0.25)),
		"terrain": terrain({"brooks": 0.0, "litter": 0.0, "litter_color": Color(0.6, 0.5, 0.3), "far_height": 8.0, "dunes": 1.0, "obstacles": ["fallen_tree", "cliff"], "terraces": 0.0, "path_width": 2.2, "path_depth": 0.05, "valley_width": 30.0, "valley_ramp": 70.0, "valley_height": 4.0,
			"undulation": 1.6, "grass_dark": Color(0.86, 0.68, 0.36), "grass_light": Color(0.95, 0.8, 0.46),
			"region_dark": Color(0.84, 0.66, 0.34), "region_light": Color(0.92, 0.76, 0.44),
			"path_color": Color(0.84, 0.68, 0.38), "slope_color": Color(0.86, 0.66, 0.36), "crack": 0.7, "ripple": 1.0}),
		"atmosphere": atmosphere({"fx": {"heat_haze": 1.0}, "grade_shadow": Color(0.52, 0.42, 0.7), "grade_high": Color(1.0, 0.84, 0.6), "grade_warm": 0.45, "grade_contrast": 0.32, "rain": 0.0, "clock": 1.0, "mist_amount": 0.1, "temperature": 34.0, "mountain_color": Color(0.86, 0.6, 0.42), "mountain_shadow": Color(0.7, 0.5, 0.48), "mountain_snow": 0.0, "mountain_scale": 0.7, "birds": false, "sun_dir": Vector3(0.3, -0.85, -0.5), "sun_color": Color(1.0, 0.93, 0.8), "sun_energy": 1.8,
			"ambient_energy": 0.55, "ambient_color": Color(0.95, 0.78, 0.55), "fog_color": Color(0.96, 0.9, 0.78),
			"fog_density": 0.0035, "fog_sun_scatter": 0.3, "saturation": 1.05,
			"zenith_color": Color(0.42, 0.7, 0.92), "horizon_color": Color(0.9, 0.93, 0.92), "cloud_coverage": 0.56,
			"cirrus_amount": 0.5, "cloud_shadow": Color(0.72, 0.76, 0.86), "particles": "sand", "particle_color": Color(1.0, 0.85, 0.6), "butterflies": 0, "gusts": 1.0, "dust": 1.0}),
		"layers": [
			{"kind": "grass", "models": ["Grass_Wispy_Short", "Grass_Wispy_Tall", "Grass_Common_Short"], "density": 160.0,
				"dist": [2.5, 60.0], "falloff": [5.0, 40.0, 0.3], "grove": [0.09, 0.2], "scale": [0.5, 1.0], "palette": dry, "region_palette": dry, "near": true},
			{"kind": "rock", "models": ROCKS, "styles": [mesa], "spacing": 40.0, "chance": 0.45, "dist": [30.0, 110.0],
				"scale": [2.5, 5.5], "grow_with_dist": true, "squash": Vector3(1.5, 0.9, 1.3), "sink": 0.25, "radius": 14.0, "collide": "rock"},
			{"kind": "tree", "models": DEAD, "styles": [dead], "spacing": 17.0, "chance": 0.35, "dist": [5.0, 40.0],
				"scale": [0.7, 1.15], "radius": 4.0, "collide": "trunk", "trunk": 0.3},
			{"kind": "detail", "models": ROCKS, "styles": [sandstone], "density": 1.5, "dist": [3.0, 26.0], "scale": [0.25, 0.8],
				"sink": 0.25, "tilt": 0.7, "shadows": true, "vis": 110.0, "near": true},
			cluster_layer(["Fern_1"], 0.08, [3.0, 20.0], 1, 0.5, [0.18, 0.26], true),
			cluster_layer(["Plant_1_Big", "Plant_1"], 0.12, [3.0, 20.0], 2, 0.8, [0.5, 0.8], true),
			{"kind": "path_stones", "models": PAVING, "styles": [paving],
				"density": 520.0, "gap": [0.09, -0.3], "scale": [0.9, 1.3], "shadows": false, "vis": 70.0, "near": true},
			# round 12: buttes, rock gardens, dry washes, mesa fields
			{"kind": "rock", "models": BIG_ROCKS, "styles": [butte], "spacing": 70.0, "chance": 0.5, "dist": [70.0, 230.0],
				"scale": [3.0, 5.5], "grow_with_dist": true, "squash": Vector3(1.3, 1.25, 1.2), "sink": 0.2, "radius": 18.0, "collide": "rock"},
			{"kind": "rock", "models": ["Rock_Big_1", "Rock_Big_2", "Rock_Medium_4"], "styles": [boulder], "spacing": 16.0, "chance": 0.55,
				"dist": [5.0, 45.0], "patch": [1], "scale": [0.7, 1.5], "sink": 0.15, "radius": 4.0, "collide": "rock"},
			hardy,
			{"kind": "tree", "models": DEAD, "styles": [dead], "spacing": 9.0, "chance": 0.55, "dist": [5.0, 60.0], "patch": [2],
				"scale": [0.75, 1.2], "radius": 3.5, "collide": "trunk", "trunk": 0.3},
			wash_grass,
			wash_pebbles,
			{"kind": "rock", "models": BIG_ROCKS, "styles": [butte], "spacing": 30.0, "chance": 0.6, "dist": [18.0, 90.0], "patch": [3],
				"scale": [2.2, 3.6], "squash": Vector3(1.5, 0.85, 1.4), "sink": 0.2, "radius": 12.0, "collide": "rock"},
		],
	}


# ================================================================ 4 Blossom Grove

static func blossom() -> Dictionary:
	var pink := tree_style(Color(0.8, 0.45, 0.72), Color(1.0, 0.8, 0.93), {"tint": Color(0.9, 0.78, 0.75)}, 6.0, {"translucency": 1.0})
	var lilac := tree_style(Color(0.58, 0.45, 0.85), Color(0.88, 0.8, 1.0), {"tint": Color(0.9, 0.78, 0.75)}, 6.0, {"translucency": 1.0})
	var white := tree_style(Color(0.85, 0.75, 0.8), Color(1.0, 0.97, 0.97), birch_bark(), 5.0, {"translucency": 1.0})
	var rock := rock_style(Color(0.72, 0.72, 0.74), 0.3)
	var cherry_bark := {"tint": Color(0.92, 0.8, 0.78), "brightness": 0.95}
	var sakura := tree_style(Color(0.88, 0.5, 0.72), Color(1.0, 0.86, 0.95), cherry_bark, 6.0, {"translucency": 1.1})
	var sakura_white := tree_style(Color(0.9, 0.78, 0.86), Color(1.0, 0.98, 0.99), cherry_bark, 6.0, {"translucency": 1.1})
	var meadow_flowers := cluster_layer(WILDFLOWERS, 5.0, [2.5, 50.0], 12, 3.0, [0.45, 0.75])
	meadow_flowers["tints"] = [Color(1.0, 0.7, 0.86), Color(1.0, 0.98, 0.98), Color(1.0, 0.55, 0.78), Color(0.95, 0.8, 1.0)]
	meadow_flowers["patch"] = [3]
	var orchard_bush := {"kind": "detail", "models": ["Bush_Large_Flowers", "Bush_Common_Flowers"],
		"styles": [{"leaves": leaves(Color(0.25, 0.5, 0.12), Color(0.58, 0.84, 0.26), {"sphere_normals": 0.85}), "stiffness": 6.0}],
		"density": 1.6, "dist": [4.0, 40.0], "scale": [0.6, 1.0], "shadows": true, "vis": 120.0, "near": true, "tilt": 0.3, "patch": [2]}
	return {
		"name": NAMES[3],
		# cherry grove as before · cherry avenue · white orchard · blossom meadow
		"patches": [{"name": "cherry grove", "share": 0.4}, {"name": "cherry avenue", "share": 0.25},
			{"name": "white orchard", "share": 0.2}, {"name": "blossom meadow", "share": 0.15}],
		"blades": blades(0.45, Color(0.15, 0.35, 0.08), Color(0.6, 0.88, 0.28), Color(0.78, 0.86, 0.5)),
		"terrain": terrain({"scree": 0, "gullies": 0.3, "hummocks": 0.6, "brooks": 0.75, "litter": 0.6, "litter_color": Color(1.0, 0.72, 0.82), "far_height": 45.0, "ponds": 0.45, "terraces": 5.0, "water_shallow": Color(0.5, 0.85, 0.85), "valley_width": 18.0, "valley_height": 12.0, "undulation": 1.0,
			"grass_dark": Color(0.36, 0.6, 0.16), "grass_light": Color(0.58, 0.78, 0.26),
			"region_dark": Color(0.62, 0.62, 0.3), "region_light": Color(0.76, 0.74, 0.4),
			"path_color": Color(0.82, 0.74, 0.56), "crack": 0.3}),
		"atmosphere": atmosphere({"fx": {"petal_gust": 1.0}, "grade_shadow": Color(0.52, 0.45, 0.78), "grade_high": Color(1.0, 0.88, 0.84), "grade_warm": 0.1, "falls": 0.5, "deer": true, "shafts": 0.6, "rainbow": 0.6, "temperature": 19.0, "mountain_color": Color(0.64, 0.6, 0.74), "mountain_shadow": Color(0.55, 0.52, 0.7), "mountain_snow": 0.3, "sun_dir": Vector3(0.5, -0.5, 0.6), "sun_color": Color(1.0, 0.92, 0.88), "sun_energy": 1.7,
			"ambient_energy": 0.55, "ambient_color": Color(0.8, 0.7, 0.85), "fog_color": Color(0.95, 0.88, 0.95),
			"fog_density": 0.0024, "fog_sun_scatter": 0.35, "zenith_color": Color(0.35, 0.6, 0.95),
			"horizon_color": Color(0.94, 0.88, 0.96), "cloud_coverage": 0.52, "particles": "petals",
			"particle_color": Color(1.0, 0.75, 0.9), "butterflies": 14}),
		"layers": [
			grass_layer([Color(0.5, 0.8, 0.2), Color(0.42, 0.72, 0.16), Color(0.62, 0.86, 0.3)],
				[Color(0.55, 0.82, 0.25), Color(0.62, 0.86, 0.3), Color(0.95, 0.78, 0.9)], 2200.0),
			# (the real cherries replace the recolored twisted trees in the same places)
			{"kind": "tree", "models": CHERRIES, "styles": [sakura, sakura, lilac], "spacing": 22.0, "chance": 0.65, "dist": [7.0, 400.0],
				"falloff": [14.0, 140.0, 0.5], "grove": [0.02, -0.05], "scale": [0.6, 0.85], "radius": 5.0, "collide": "trunk", "trunk": 0.3,
				"thin": {3: 0.12}},
			hero_tree(["CherryBlossom_1", "CherryBlossom_3"], sakura, Vector2(1.3, 1.5)),
			{"kind": "tree", "models": COMMON, "styles": [white, pink], "spacing": 16.0, "chance": 0.45, "dist": [6.0, 300.0],
				"scale": [0.9, 1.3], "radius": 2.6, "collide": "trunk", "trunk": 0.28, "thin": {2: 0.3, 3: 0.1}},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 34.0, "chance": 0.25, "dist": [6.0, 40.0],
				"scale": [1.0, 2.2], "sink": 0.15, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"], 1.8, [2.5, 30.0], 7, 2.0, [0.45, 0.75]),
			cluster_layer(["Clover_1", "Clover_2"], 0.6, [2.5, 26.0], 8, 1.5, [0.6, 1.0]),
			{"kind": "detail", "models": ["Bush_Common_Flowers"], "styles": [{"leaves": leaves(Color(0.25, 0.5, 0.12), Color(0.55, 0.82, 0.25), {"sphere_normals": 0.85}), "stiffness": 6.0}],
				"density": 2.0, "dist": [4.0, 24.0], "scale": [0.9, 1.5], "shadows": true, "vis": 110.0, "near": true, "tilt": 0.3},
			pebble_layer(rock_style(Color(0.76, 0.75, 0.74), 0.0, false, {"top_light": 0.3}), 18.0),
			# round 12: cherry avenue, white orchard, blossom meadow
			{"kind": "tree", "models": CHERRIES, "styles": [sakura, sakura, sakura_white], "spacing": 9.0, "chance": 0.9,
				"dist": [5.5, 9.5], "patch": [1], "scale": [0.55, 0.75], "radius": 3.0, "collide": "trunk", "trunk": 0.3},
			{"kind": "tree", "models": CHERRIES, "styles": [sakura_white], "spacing": 12.0, "chance": 0.95,
				"dist": [7.0, 120.0], "patch": [2], "scale": [0.45, 0.62], "radius": 4.0, "collide": "trunk", "trunk": 0.3},
			orchard_bush,
			meadow_flowers,
		],
	}


# ================================================================ 5 Spring Meadow

static func spring() -> Dictionary:
	var oak := tree_style(Color(0.2, 0.46, 0.06), Color(0.62, 0.9, 0.24), {"tint": Color(0.95, 0.85, 0.8)}, 6.0, {"translucency": 0.9})
	var fresh := tree_style(Color(0.35, 0.62, 0.1), Color(0.78, 0.96, 0.4), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 1.0})
	var bloom := tree_style(Color(0.74, 0.5, 0.66), Color(1.0, 0.9, 0.95), birch_bark(), 6.0, {"translucency": 1.0})
	var bush := {"leaves": leaves(Color(0.2, 0.48, 0.08), Color(0.55, 0.85, 0.2), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var rock := rock_style(Color(0.72, 0.74, 0.7), 0.55)
	var tints := [Color(1.0, 1.0, 1.0), Color(1.0, 0.88, 0.25), Color(0.45, 0.65, 1.0), Color(1.0, 0.55, 0.75),
		Color(0.7, 0.45, 1.0), Color(1.0, 0.45, 0.25)]
	var tall := tree_style(Color(0.2, 0.48, 0.07), Color(0.66, 0.92, 0.3), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 1.0})
	var fruit := tree_style(Color(0.9, 0.72, 0.8), Color(1.0, 0.97, 0.97), {"tint": Color(0.92, 0.8, 0.78)}, 6.0, {"translucency": 1.1})
	var hawthorn := {"leaves": leaves(Color(0.14, 0.38, 0.06), Color(0.5, 0.8, 0.2), {"sphere_normals": 0.8}), "stiffness": 7.0}
	var carpet := {"kind": "cluster", "models": ["Flower_1_Group", "Flower_2_Group", "Flower_7_Group", "Flower_1_Single", "Flower_7_Single"],
		"styles": [{}], "density": 3.2, "dist": [2.5, 70.0], "count": 40, "radius": 5.0, "scale": [0.5, 0.85], "tints": tints,
		"vis": 80.0, "near": true, "tilt": 0.8, "patch": [1]}
	var daisies := {"kind": "cluster", "models": ["Flower_6", "Flower_6_2"], "styles": [{}], "density": 3.0, "dist": [2.2, 60.0],
		"count": 14, "radius": 2.5, "scale": [0.7, 1.1], "vis": 55.0, "near": true, "tilt": 0.9, "patch": [1, 3]}
	var hedges := hedge_layer(hawthorn, 30.0)
	hedges["patch"] = [3]
	return {
		"name": NAMES[4],
		# meadow as before · flower carpet · spring orchard · hedged pasture
		"patches": [{"name": "meadow", "share": 0.35}, {"name": "flower carpet", "share": 0.25},
			{"name": "spring orchard", "share": 0.2}, {"name": "hedged pasture", "share": 0.2}],
		"blades": blades(0.55, Color(0.12, 0.34, 0.05), Color(0.52, 0.86, 0.16), Color(0.85, 0.92, 0.3)),
		"terrain": terrain({"scree": 0, "gullies": 0.5, "hummocks": 1.0, "brooks": 0.9, "litter": 0.25, "litter_color": Color(0.98, 0.96, 0.88), "far_height": 40.0, "obstacles": ["river", "fallen_tree", "cliff", "stile"], "valley_width": 34.0, "valley_ramp": 110.0, "valley_height": 22.0, "undulation": 2.4,
			"grass_dark": Color(0.26, 0.54, 0.1), "grass_light": Color(0.5, 0.76, 0.16),
			"region_dark": Color(0.42, 0.64, 0.12), "region_light": Color(0.66, 0.8, 0.2),
			"slope_color": Color(0.4, 0.58, 0.18), "path_color": Color(0.78, 0.68, 0.46), "crack": 0.4,
			"ponds": 0.55, "pond_size": Vector2(10.0, 22.0),
			"water_shallow": Color(0.42, 0.86, 0.74), "water_deep": Color(0.1, 0.42, 0.55)}),
		"atmosphere": atmosphere({"fx": {"dandelion": 1.0}, "grade_shadow": Color(0.32, 0.55, 0.78), "grade_high": Color(1.0, 0.96, 0.72), "grade_warm": 0.0, "falls": 0.7, "deer": true, "rainbow": 0.8, "temperature": 19.0, "sun_dir": Vector3(-0.4, -0.6, 0.62), "sun_color": Color(1.0, 0.95, 0.84), "sun_energy": 1.9,
			"ambient_energy": 0.48, "ambient_color": Color(0.62, 0.8, 0.55),
			"zenith_color": Color(0.16, 0.5, 0.95), "horizon_color": Color(0.76, 0.9, 1.0), "cloud_coverage": 0.47,
			"cirrus_amount": 0.7, "fog_color": Color(0.8, 0.9, 0.98), "fog_density": 0.0012, "saturation": 1.12,
			"particles": "motes", "particle_color": Color(1.0, 1.0, 0.85), "butterflies": 16,
			"mountain_color": Color(0.46, 0.6, 0.56), "mountain_shadow": Color(0.4, 0.5, 0.64), "mountain_snow": 0.45, "mountain_scale": 1.25}),
		"layers": [
			grass_layer([Color(0.42, 0.76, 0.12), Color(0.34, 0.66, 0.1), Color(0.56, 0.84, 0.18), Color(0.48, 0.8, 0.14)],
				[Color(0.62, 0.86, 0.2), Color(0.9, 0.9, 0.35), Color(0.5, 0.8, 0.16)], 2400.0, Vector2(0.28, 0.52), SHORT_GRASS + ["Grass_Common_Tall"]),
			{"kind": "tree", "models": COMMON, "styles": [oak, oak, fresh], "spacing": 24.0, "chance": 0.6, "dist": [9.0, 400.0],
				"falloff": [20.0, 160.0, 0.6], "grove": [0.026, -0.2], "scale": [1.5, 2.3], "radius": 4.0, "collide": "trunk", "trunk": 0.35,
				"thin": {1: 0.4, 2: 0.3, 3: 0.35}},
			hero_tree(["CommonTree_1", "CommonTree_2"], oak, Vector2(4.2, 5.2)),
			{"kind": "tree", "models": ["TwistedTree_1", "TwistedTree_4"], "styles": [bloom], "spacing": 70.0, "chance": 0.5, "dist": [10.0, 200.0],
				"scale": [0.45, 0.6], "radius": 5.0, "collide": "trunk", "trunk": 0.45, "thin": {1: 0.3}},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 42.0, "chance": 0.25, "dist": [8.0, 60.0],
				"scale": [1.0, 2.6], "sink": 0.2, "radius": 3.0, "collide": "rock"},
			{"kind": "detail", "models": ["Bush_Common", "Bush_Common_Flowers", "Bush_Common_Flowers"], "styles": [bush], "density": 3.5,
				"dist": [4.0, 45.0], "scale": [1.0, 1.9], "shadows": true, "vis": 130.0, "near": true, "tilt": 0.3},
			# flower fields: each group one color, dense carpets
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single", "Flower_3_Group"], "styles": [{}], "density": 2.6,
				"dist": [2.5, 60.0], "count": 34, "radius": 4.5, "scale": [0.55, 0.9], "tints": tints, "vis": 75.0, "near": true, "tilt": 0.8},
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single"], "styles": [{}], "density": 5.0,
				"dist": [2.2, 40.0], "count": 3, "radius": 1.0, "scale": [0.5, 0.8], "tints": tints, "vis": 60.0, "near": true, "tilt": 0.8},
			cluster_layer(["Clover_1", "Clover_2"], 1.4, [2.5, 30.0], 10, 1.8, [0.6, 1.0]),
			cluster_layer(["Fern_1"], 0.25, [4.0, 30.0], 1, 0.8, [0.26, 0.36], true),
			pebble_layer(rock_style(Color(0.74, 0.74, 0.72), 0.0, false, {"top_light": 0.3}), 16.0),
			small_rock_layer(rock, 1.5),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			erratic_layer(rock_style(Color(0.7, 0.7, 0.68), 0.7), 130.0),
			# round 12: tall trees on the edges, flower carpets, spring orchards, hedged pastures
			{"kind": "tree", "models": TALL, "styles": [tall], "spacing": 34.0, "chance": 0.6, "dist": [14.0, 400.0],
				"grove": [0.03, 0.1], "scale": [0.72, 1.0], "radius": 4.0, "collide": "trunk", "trunk": 0.35, "thin": {1: 0.3}},
			carpet,
			daisies,
			{"kind": "tree", "models": CHERRIES, "styles": [fruit], "spacing": 13.0, "chance": 0.9, "dist": [7.0, 110.0], "patch": [2],
				"scale": [0.38, 0.5], "radius": 3.5, "collide": "trunk", "trunk": 0.25},
			hedges,
			{"kind": "detail", "models": ["Bush_Large_Flowers"], "styles": [hawthorn], "density": 0.9, "dist": [5.0, 60.0], "patch": [3],
				"scale": [0.7, 1.0], "shadows": true, "vis": 130.0, "near": true, "tilt": 0.3},
		],
	}


# ================================================================ 6 Red Maple Wood

static func maple() -> Dictionary:
	var maple_style := tree_style(Color(0.62, 0.08, 0.04), Color(0.98, 0.32, 0.1), {"tint": Color(0.92, 0.88, 0.85)}, 7.0, {"translucency": 1.0})
	var orange := tree_style(Color(0.85, 0.35, 0.05), Color(1.0, 0.7, 0.22), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 0.9})
	var rock := rock_style(Color(0.66, 0.64, 0.6), 0.2)
	var gold := tree_style(Color(0.82, 0.52, 0.06), Color(1.0, 0.84, 0.3), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 1.0})
	var birch_orange := birch_style(Color(0.86, 0.34, 0.05), Color(1.0, 0.66, 0.22))
	var crimson_bush := {"leaves": leaves(Color(0.52, 0.06, 0.04), Color(0.95, 0.3, 0.1), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var amber_bush := {"leaves": leaves(Color(0.72, 0.3, 0.04), Color(1.0, 0.62, 0.18), {"sphere_normals": 0.85}), "stiffness": 6.0}
	var mossy := rock_style(Color(0.62, 0.62, 0.56), 0.85, true, {"triplanar_scale": 0.08, "moss_color": Color(0.46, 0.6, 0.16)})
	var rust_ferns := cluster_layer(["Fern_2"], 2.2, [3.0, 40.0], 3, 2.0, [0.3, 0.46], true, {"plant": {"texture_tint": Color(1.4, 0.62, 0.3)}})
	rust_ferns["patch"] = [2]
	var clearing_flowers := cluster_layer(WILDFLOWERS, 2.2, [2.5, 40.0], 8, 2.4, [0.45, 0.7])
	clearing_flowers["tints"] = [Color(1.0, 0.72, 0.2), Color(0.7, 0.5, 1.0), Color(1.0, 0.9, 0.6)]
	clearing_flowers["patch"] = [1]
	return {
		"name": NAMES[5],
		"under_bush": {"dark": Color(0.62, 0.14, 0.05), "light": Color(0.98, 0.5, 0.16)},
		# deep maple wood as before · golden clearing · mossy boulders · red understory
		"patches": [{"name": "deep maple", "share": 0.4}, {"name": "golden clearing", "share": 0.25},
			{"name": "mossy boulders", "share": 0.2}, {"name": "red understory", "share": 0.15}],
		"blades": blades(0.45, Color(0.3, 0.22, 0.06), Color(0.95, 0.55, 0.15), Color(0.9, 0.25, 0.08)),
		"terrain": terrain({"scree": 0, "gullies": 0.4, "hummocks": 0.3, "brooks": 0.6, "litter": 0.7, "litter_color": Color(0.9, 0.22, 0.12), "far_height": 60.0, "valley_width": 13.0, "valley_height": 14.0, "undulation": 1.3,
			"grass_dark": Color(0.62, 0.42, 0.12), "grass_light": Color(0.78, 0.56, 0.18),
			"region_dark": Color(0.7, 0.28, 0.1), "region_light": Color(0.86, 0.42, 0.14),
			"path_color": Color(0.72, 0.58, 0.38), "slope_color": Color(0.55, 0.42, 0.24), "crack": 0.6}),
		"atmosphere": atmosphere({"fx": {"samara": 1.0}, "grade_shadow": Color(0.45, 0.38, 0.62), "grade_high": Color(1.0, 0.78, 0.5), "grade_warm": 0.5, "falls": 0.4, "deer": true, "shafts": 0.8, "temperature": 13.0, "mountain_color": Color(0.72, 0.52, 0.42), "mountain_shadow": Color(0.56, 0.46, 0.52), "mountain_snow": 0.15, "sun_dir": Vector3(0.6, -0.42, 0.65), "sun_color": Color(1.0, 0.82, 0.6), "sun_energy": 1.8,
			"ambient_energy": 0.5, "ambient_color": Color(0.9, 0.7, 0.5), "fog_color": Color(0.98, 0.85, 0.7),
			"fog_density": 0.0028, "fog_sun_scatter": 0.45, "volumetric": 0.004,
			"zenith_color": Color(0.32, 0.58, 0.9), "horizon_color": Color(0.98, 0.9, 0.8), "cloud_coverage": 0.5,
			"particles": "leaves", "particle_color": Color(0.95, 0.25, 0.08), "butterflies": 3, "gusts": 0.85}),
		"layers": [
			grass_layer([Color(0.95, 0.5, 0.12), Color(0.9, 0.3, 0.08), Color(1.0, 0.7, 0.22), Color(0.6, 0.72, 0.18)],
				[Color(0.85, 0.2, 0.06), Color(0.98, 0.6, 0.15)], 2000.0),
			{"kind": "tree", "models": TWISTED, "styles": [maple_style], "spacing": 16.0, "chance": 0.7, "dist": [7.0, 400.0],
				"falloff": [18.0, 140.0, 0.55], "scale": [0.5, 0.75], "radius": 5.0, "collide": "trunk", "trunk": 0.5, "thin": {1: 0.25}},
			hero_tree(["TwistedTree_2", "TwistedTree_5"], maple_style, Vector2(1.5, 1.9)),
			{"kind": "tree", "models": COMMON, "styles": [orange], "spacing": 12.0, "chance": 0.55, "dist": [5.5, 300.0],
				"scale": [1.0, 1.5], "radius": 2.6, "collide": "trunk", "trunk": 0.28, "thin": {1: 0.3}},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 30.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.6], "sink": 0.15, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Mushroom_Common"], 1.0, [2.0, 10.0], 5, 0.6, [0.9, 1.7]),
			cluster_layer(["Fern_1"], 0.4, [3.0, 24.0], 1, 1.0, [0.28, 0.38], true,
				{"plant": {"texture_tint": Color(1.3, 0.7, 0.3)}}),
			cluster_layer(PLANTS, 0.4, [2.5, 20.0], 3, 1.2, [0.6, 1.0]),
			pebble_layer(rock_style(Color(0.7, 0.68, 0.64), 0.0, false, {"top_light": 0.3}), 22.0),
			# round 12: golden clearings, mossy boulders, red understory
			{"kind": "tree", "models": TALL, "styles": [gold], "spacing": 16.0, "chance": 0.7, "dist": [7.0, 300.0], "patch": [1],
				"scale": [0.7, 0.95], "radius": 4.0, "collide": "trunk", "trunk": 0.35},
			{"kind": "tree", "models": BIRCHES, "styles": [birch_orange], "spacing": 9.0, "chance": 0.6, "dist": [6.0, 300.0], "patch": [1],
				"scale": [0.6, 0.85], "radius": 2.2, "collide": "trunk", "trunk": 0.2},
			clearing_flowers,
			{"kind": "rock", "models": ["Rock_Big_1", "Rock_Big_2", "Rock_Medium_4"], "styles": [mossy], "spacing": 18.0, "chance": 0.55,
				"dist": [6.0, 60.0], "patch": [2], "scale": [0.7, 1.5], "sink": 0.2, "radius": 4.5, "collide": "rock"},
			rust_ferns,
			{"kind": "detail", "models": ["Bush_Large", "Bush_Long_1", "Bush_Long_2", "Bush_Large"], "styles": [crimson_bush], "region_styles": [amber_bush],
				"density": 16.0, "dist": [3.5, 40.0], "patch": [3], "scale": [0.75, 1.25], "shadows": true, "vis": 120.0, "near": true, "tilt": 0.3},
			{"kind": "detail", "models": ["Bush_Large", "Bush_Long_1"], "styles": [crimson_bush], "region_styles": [amber_bush],
				"density": 1.2, "dist": [4.5, 22.0], "scale": [0.6, 1.0], "shadows": true, "vis": 120.0, "near": true, "tilt": 0.3},
			cluster_layer(["Mushroom_RedCap"], 0.5, [2.2, 14.0], 3, 0.7, [0.3, 0.55]),
			oyster_layer(0.2),
		],
	}


# ================================================================ 7 Mountain Pines

static func alpine() -> Dictionary:
	var pine := tree_style(Color(0.06, 0.26, 0.1), Color(0.3, 0.58, 0.2), {"tint": Color(0.9, 0.78, 0.7)}, 8.0, {"sphere_normals": 0.55, "translucency": 0.5})
	var pine_light := tree_style(Color(0.1, 0.34, 0.12), Color(0.42, 0.68, 0.24), {"tint": Color(0.9, 0.78, 0.7)}, 8.0, {"sphere_normals": 0.55, "translucency": 0.6})
	var cliff := rock_style(Color(0.74, 0.76, 0.8), 0.55, true, {"triplanar_scale": 0.07, "moss_color": Color(0.94, 0.96, 1.0), "top_light": 0.5})
	var rock := rock_style(Color(0.78, 0.79, 0.8), 0.35)
	var tints := [Color(0.3, 0.45, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(0.75, 0.45, 1.0), Color(0.35, 0.55, 1.0)]
	var giant := tree_style(Color(0.05, 0.22, 0.1), Color(0.26, 0.52, 0.2), {"tint": Color(0.9, 0.78, 0.7)}, 9.0, {"sphere_normals": 0.5, "translucency": 0.45})
	var granite := rock_style(Color(0.76, 0.77, 0.8), 0.35, true, {"triplanar_scale": 0.07, "moss_color": Color(0.94, 0.96, 1.0), "top_light": 0.5})
	var alpine := {"kind": "cluster", "models": ["Flower_1_Group", "Flower_2_Group", "Flower_7_Group", "Flower_2_Single", "Flower_7_Single"],
		"styles": [{}], "density": 4.2, "dist": [2.5, 70.0], "count": 30, "radius": 4.0, "scale": [0.36, 0.56], "tints": tints,
		"vis": 75.0, "near": true, "tilt": 0.9, "patch": [1]}
	var edelweiss := {"kind": "cluster", "models": ["Flower_6", "Flower_6_2"], "styles": [{}], "density": 2.4, "dist": [2.2, 60.0],
		"count": 10, "radius": 2.0, "scale": [0.6, 0.9], "vis": 55.0, "near": true, "tilt": 0.9, "patch": [1, 2]}
	return {
		"name": NAMES[6],
		# pine forest as before · alpine meadow · rock field · giant grove
		"patches": [{"name": "pine forest", "share": 0.4}, {"name": "alpine meadow", "share": 0.25},
			{"name": "rock field", "share": 0.2}, {"name": "giant grove", "share": 0.15}],
		"blades": blades(0.3, Color(0.1, 0.3, 0.08), Color(0.45, 0.75, 0.2), Color(0.7, 0.78, 0.3)),
		"terrain": terrain({"scree": 1.0, "gullies": 0.8, "hummocks": 0, "brooks": 0.85, "litter": 0.7, "litter_color": Color(0.66, 0.36, 0.2), "far_height": 120.0, "obstacles": ["cliff", "cliff", "river", "boulders"], "valley_width": 16.0, "valley_ramp": 80.0, "valley_height": 58.0, "undulation": 1.6, "roughness": 1.2,
			"grass_dark": Color(0.24, 0.48, 0.14), "grass_light": Color(0.44, 0.66, 0.2),
			"region_dark": Color(0.36, 0.56, 0.18), "region_light": Color(0.56, 0.7, 0.26),
			"slope_color": Color(0.56, 0.58, 0.6), "path_color": Color(0.7, 0.6, 0.44), "crack": 0.3,
			"snow": 22.0, "ponds": 0.75, "terraces": 9.0, "pond_size": Vector2(14.0, 30.0),
			"water_shallow": Color(0.3, 0.84, 0.86), "water_deep": Color(0.04, 0.32, 0.58)}),
		"atmosphere": atmosphere({"fx": {"crystal_motes": 1.0}, "grade_shadow": Color(0.3, 0.48, 0.82), "grade_high": Color(0.96, 0.94, 0.88), "grade_warm": -0.2, "grade_contrast": 0.3, "falls": 1.0, "deer": true, "shafts": 0.85, "rain": 1.2, "temperature": 5.0, "sun_dir": Vector3(-0.5, -0.55, 0.65), "sun_color": Color(1.0, 0.97, 0.92), "sun_energy": 1.95,
			"ambient_energy": 0.5, "ambient_color": Color(0.6, 0.72, 0.9), "fog_color": Color(0.78, 0.88, 0.98),
			"fog_density": 0.0014, "saturation": 1.12, "zenith_color": Color(0.12, 0.42, 0.9), "horizon_color": Color(0.8, 0.9, 1.0),
			"cloud_coverage": 0.46, "cirrus_amount": 0.95, "particles": "motes", "butterflies": 4,
			"mountain_color": Color(0.56, 0.62, 0.72), "mountain_shadow": Color(0.4, 0.48, 0.66), "mountain_snow": 0.75, "mountain_scale": 1.7}),
		"layers": [
			grass_layer([Color(0.36, 0.66, 0.14), Color(0.46, 0.72, 0.2), Color(0.3, 0.58, 0.12), Color(0.52, 0.76, 0.22)],
				[Color(0.62, 0.74, 0.28), Color(0.46, 0.68, 0.2)], 2200.0, Vector2(0.35, 0.65)),
			{"kind": "tree", "models": PINES, "styles": [pine, pine, pine_light], "spacing": 10.0, "chance": 0.65, "dist": [8.0, 400.0],
				"falloff": [20.0, 150.0, 0.6], "grove": [0.02, -0.15], "scale": [1.4, 2.4], "radius": 3.0, "collide": "trunk", "trunk": 0.35,
				"thin": {1: 0.15, 2: 0.4, 3: 0.35}},
			{"kind": "rock", "models": ROCKS, "styles": [cliff], "spacing": 30.0, "chance": 0.6, "dist": [14.0, 110.0],
				"scale": [3.5, 9.0], "grow_with_dist": true, "squash": Vector3(1.3, 1.25, 1.1), "sink": 0.2, "radius": 8.0, "collide": "rock"},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 18.0, "chance": 0.4, "dist": [5.0, 45.0],
				"scale": [0.8, 2.2], "sink": 0.15, "radius": 2.0, "collide": "rock"},
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single"], "styles": [{}], "density": 2.2,
				"dist": [2.5, 45.0], "count": 20, "radius": 3.5, "scale": [0.3, 0.5], "tints": tints, "vis": 70.0, "near": true, "tilt": 0.9},
			cluster_layer(["Plant_7", "Plant_7_Big"], 0.8, [2.5, 25.0], 4, 1.2, [0.7, 1.1]),
			cluster_layer(["Clover_1", "Clover_2"], 0.6, [2.5, 25.0], 8, 1.4, [0.5, 0.9]),
			pebble_layer(rock_style(Color(0.76, 0.77, 0.78), 0.0, false, {"top_light": 0.3}), 45.0),
			small_rock_layer(rock, 9.0, [2.0, 24.0]),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			scree_layer(rock_style(Color(0.7, 0.7, 0.72), 0.1), 70.0),
			# round 12: lone giants, outcrops, alpine meadows, rock fields, giant groves
			{"kind": "tree", "models": GIANT_PINES, "styles": [giant], "spacing": 70.0, "chance": 0.5, "dist": [10.0, 400.0],
				"scale": [1.5, 2.1], "radius": 5.0, "collide": "trunk", "trunk": 0.45},
			{"kind": "rock", "models": BIG_ROCKS, "styles": [granite], "spacing": 60.0, "chance": 0.45, "dist": [9.0, 90.0],
				"scale": [1.0, 2.0], "sink": 0.2, "radius": 7.0, "collide": "rock"},
			alpine,
			edelweiss,
			{"kind": "rock", "models": ["Rock_Big_1", "Rock_Big_2", "Rock_Medium_4", "Rock_Medium_2"], "styles": [granite], "spacing": 12.0,
				"chance": 0.6, "dist": [5.0, 80.0], "patch": [2], "scale": [0.5, 1.3], "sink": 0.18, "radius": 3.5, "collide": "rock"},
			{"kind": "tree", "models": GIANT_PINES, "styles": [giant, pine_light], "spacing": 14.0, "chance": 0.75, "dist": [8.0, 400.0],
				"patch": [3], "scale": [1.4, 1.9], "radius": 4.5, "collide": "trunk", "trunk": 0.45},
		],
	}


# ================================================================ 8 Deadwood Bog

static func bog() -> Dictionary:
	var dead := {"bark": {"tint": Color(0.78, 0.76, 0.72), "brightness": 1.55, "desaturate": 0.75, "ao_strength": 0.5}, "stiffness": 14.0}
	var twisted := tree_style(Color(0.16, 0.32, 0.1), Color(0.42, 0.56, 0.2), {"tint": Color(0.8, 0.78, 0.74)}, 7.0, {"translucency": 0.6})
	var rock := rock_style(Color(0.52, 0.56, 0.5), 0.7)
	var silver := {"bark": {"tint": Color(0.86, 0.86, 0.84), "brightness": 2.1, "desaturate": 0.9, "ao_strength": 0.4}, "stiffness": 14.0}
	var carr := birch_style(Color(0.46, 0.54, 0.12), Color(0.82, 0.86, 0.36), {"translucency": 0.9})
	var sedge := [Color(0.5, 0.52, 0.2), Color(0.58, 0.56, 0.24), Color(0.44, 0.48, 0.18), Color(0.66, 0.6, 0.3)]
	var fern_island := cluster_layer(["Fern_2"], 9.0, [2.5, 45.0], 5, 2.6, [0.42, 0.62], true)
	fern_island["patch"] = [2]
	var fern_plants := cluster_layer(["Plant_2", "Plant_2_Big"], 1.0, [2.5, 40.0], 3, 1.4, [0.6, 1.0], true)
	fern_plants["patch"] = [2]
	return {
		"name": NAMES[7],
		"under_bush": {"dark": Color(0.22, 0.3, 0.1), "light": Color(0.52, 0.58, 0.22)},
		# open bog as before · drowned forest · fern island · birch carr
		"patches": [{"name": "open bog", "share": 0.4}, {"name": "drowned forest", "share": 0.25},
			{"name": "fern island", "share": 0.2}, {"name": "birch carr", "share": 0.15}],
		"blades": blades(0.6, Color(0.14, 0.2, 0.06), Color(0.48, 0.58, 0.2), Color(0.6, 0.52, 0.22)),
		"terrain": terrain({"scree": 0, "gullies": 0.2, "hummocks": 0.8, "brooks": 0.0, "litter": 0.5, "litter_color": Color(0.36, 0.28, 0.16), "far_height": 18.0, "obstacles": ["fallen_tree", "river", "mud", "mud"], "ponds": 0.9, "pond_size": Vector2(12.0, 28.0), "water_shallow": Color(0.36, 0.5, 0.36), "water_deep": Color(0.12, 0.2, 0.16), "valley_width": 20.0, "valley_height": 6.0, "undulation": 0.8, "path_depth": 0.1,
			"grass_dark": Color(0.26, 0.36, 0.12), "grass_light": Color(0.4, 0.48, 0.18),
			"region_dark": Color(0.3, 0.3, 0.16), "region_light": Color(0.42, 0.4, 0.22),
			"slope_color": Color(0.34, 0.36, 0.2), "path_color": Color(0.5, 0.44, 0.3), "crack": 0.2}),
		"atmosphere": atmosphere({"fx": {"wisps": 1.0}, "grade_shadow": Color(0.3, 0.45, 0.45), "grade_high": Color(0.9, 0.92, 0.78), "grade_warm": -0.25, "grade_contrast": 0.18, "shafts": 0.4, "rain": 1.3, "mist_amount": 1.3, "temperature": 10.0, "mountain_color": Color(0.45, 0.5, 0.48), "mountain_shadow": Color(0.45, 0.5, 0.52), "mountain_snow": 0.0, "mountain_scale": 0.6, "birds": false, "sun_dir": Vector3(0.3, -0.35, 0.85), "sun_color": Color(0.95, 0.9, 0.78), "sun_energy": 1.3,
			"ambient_energy": 0.6, "ambient_color": Color(0.6, 0.66, 0.6), "fog_color": Color(0.7, 0.76, 0.72),
			"fog_density": 0.009, "fog_sun_scatter": 0.3, "volumetric": 0.012, "saturation": 0.95,
			"zenith_color": Color(0.45, 0.6, 0.72), "horizon_color": Color(0.78, 0.84, 0.82), "cloud_coverage": 0.38,
			"cirrus_amount": 0.2, "cloud_shadow": Color(0.6, 0.64, 0.7), "particles": "motes",
			"particle_color": Color(0.8, 1.0, 0.5), "butterflies": 0}),
		"layers": [
			thinned(grass_layer([Color(0.4, 0.55, 0.16), Color(0.5, 0.6, 0.2), Color(0.35, 0.48, 0.14)],
				[Color(0.62, 0.55, 0.25), Color(0.45, 0.4, 0.18)], 2300.0, Vector2(0.5, 0.95)), {2: 0.3}),
			{"kind": "tree", "models": DEAD, "styles": [dead], "spacing": 12.0, "chance": 0.5, "dist": [5.0, 300.0],
				"scale": [0.8, 1.3], "radius": 3.5, "collide": "trunk", "trunk": 0.3},
			{"kind": "tree", "models": TWISTED, "styles": [twisted], "spacing": 30.0, "chance": 0.5, "dist": [10.0, 400.0],
				"scale": [0.4, 0.6], "radius": 5.0, "collide": "trunk", "trunk": 0.45},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 30.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.4], "sink": 0.3, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Fern_1"], 1.2, [2.5, 30.0], 2, 1.5, [0.3, 0.45], true),
			cluster_layer(["Mushroom_Common", "Mushroom_Laetiporus"], 1.0, [2.0, 12.0], 4, 0.8, [0.9, 1.6]),
			cluster_layer(["Plant_1_Big", "Plant_1"], 0.6, [2.5, 20.0], 2, 1.2, [0.6, 1.0], true),
			pebble_layer(rock_style(Color(0.6, 0.62, 0.58), 0.3, false, {"top_light": 0.2}), 12.0),
			# round 12: drowned forest, fern islands, birch carr, sedge
			{"kind": "tree", "models": DEAD, "styles": [silver], "spacing": 7.0, "chance": 0.7, "dist": [5.0, 300.0], "patch": [1],
				"scale": [0.75, 1.25], "radius": 3.0, "collide": "trunk", "trunk": 0.3},
			{"kind": "rock", "models": ["Rock_Medium_4", "Rock_Medium_2"], "styles": [rock_style(Color(0.5, 0.54, 0.48), 0.9)], "spacing": 16.0,
				"chance": 0.45, "dist": [5.0, 50.0], "patch": [1], "scale": [0.5, 1.1], "sink": 0.3, "radius": 2.5, "collide": "rock"},
			fern_island,
			fern_plants,
			{"kind": "tree", "models": BIRCHES, "styles": [carr], "spacing": 8.0, "chance": 0.65, "dist": [5.0, 300.0], "patch": [3],
				"scale": [0.5, 0.75], "radius": 2.0, "collide": "trunk", "trunk": 0.18},
			{"kind": "grass", "models": ["Grass_Wide_Tall", "Grass_Wide_Short"], "density": 70.0, "dist": [3.0, 60.0],
				"scale": [0.45, 0.8], "palette": sedge, "region_palette": sedge, "near": true, "thin": {2: 0.2}},
			oyster_layer(0.3),
			cluster_layer(["Mushroom_RedCap"], 0.35, [2.5, 20.0], 3, 0.7, [0.3, 0.5]),
		],
	}


# ================================================================ 9 Sunset Coast

static func coast() -> Dictionary:
	var green := tree_style(Color(0.3, 0.5, 0.1), Color(0.85, 0.85, 0.3), {"tint": Color(0.95, 0.82, 0.75)}, 6.0, {"translucency": 1.0})
	var pine := tree_style(Color(0.12, 0.3, 0.12), Color(0.5, 0.62, 0.22), {"tint": Color(0.95, 0.82, 0.75)}, 8.0, {"sphere_normals": 0.55})
	var cliff := rock_style(Color(0.52, 0.58, 0.72), 0.45, true, {"moss_color": Color(0.55, 0.62, 0.2), "top_light": 0.5})
	var stack := rock_style(Color(0.4, 0.46, 0.62), 0.3, true, {"moss_color": Color(0.5, 0.58, 0.2), "top_light": 0.6, "triplanar_scale": 0.05})
	var windswept := tree_style(Color(0.26, 0.44, 0.1), Color(0.82, 0.82, 0.3), {"tint": Color(0.95, 0.82, 0.75)}, 7.0, {"translucency": 1.0})
	var gorse := {"leaves": leaves(Color(0.2, 0.36, 0.08), Color(0.52, 0.66, 0.16), {"sphere_normals": 0.8}), "stiffness": 7.0}
	var marram := [Color(0.82, 0.78, 0.46), Color(0.74, 0.72, 0.4), Color(0.88, 0.84, 0.56), Color(0.66, 0.7, 0.34)]
	var thrift := {"kind": "cluster", "models": ["Flower_6", "Flower_6_2", "Flower_6"], "styles": [{}], "density": 4.0, "dist": [2.5, 60.0],
		"count": 16, "radius": 3.0, "scale": [0.8, 1.2], "tints": [Color(1.0, 0.55, 0.78), Color(1.0, 0.7, 0.86), Color(0.95, 0.45, 0.7)],
		"vis": 60.0, "near": true, "tilt": 0.9, "patch": [3]}
	return {
		"name": NAMES[8],
		# cliff meadow as before · windswept belt · dune grass · thrift slope
		"patches": [{"name": "cliff meadow", "share": 0.4}, {"name": "windswept", "share": 0.25},
			{"name": "dune grass", "share": 0.2}, {"name": "thrift slope", "share": 0.15}],
		"blades": blades(0.55, Color(0.2, 0.34, 0.08), Color(0.72, 0.85, 0.22), Color(1.0, 0.8, 0.35)),
		"terrain": terrain({"brooks": 0.0, "litter": 0.0, "litter_color": Color(0.6, 0.5, 0.3), "far_height": 45.0, "obstacles": ["fallen_tree"], "coast": 1.0, "terraces": 6.0, "valley_width": 14.0, "valley_ramp": 60.0, "valley_height": 16.0,
			"undulation": 1.4, "grass_dark": Color(0.36, 0.5, 0.12), "grass_light": Color(0.62, 0.7, 0.2),
			"region_dark": Color(0.6, 0.6, 0.2), "region_light": Color(0.76, 0.7, 0.3),
			"slope_color": Color(0.5, 0.52, 0.66), "path_color": Color(0.78, 0.66, 0.46), "crack": 0.5,
			"water_shallow": Color(0.3, 0.7, 0.72), "water_deep": Color(0.06, 0.24, 0.42)}),
		"atmosphere": atmosphere({"fx": {"gulls": 1.0}, "grade_shadow": Color(0.42, 0.4, 0.75), "grade_high": Color(1.0, 0.78, 0.55), "grade_warm": 0.5, "rain": 0.8, "clock": 0.35, "mist_amount": 0.5, "sun_dir": Vector3(-0.5, -0.17, 0.85), "sun_color": Color(1.0, 0.7, 0.42), "sun_energy": 1.7,
			"ambient_energy": 0.55, "ambient_color": Color(0.75, 0.58, 0.7), "fog_color": Color(1.0, 0.78, 0.6),
			"fog_density": 0.0032, "fog_sun_scatter": 0.6, "saturation": 1.14, "exposure": 0.95,
			"zenith_color": Color(0.3, 0.38, 0.72), "horizon_color": Color(1.0, 0.76, 0.5), "cloud_coverage": 0.5,
			"cirrus_amount": 0.8, "cloud_shadow": Color(0.72, 0.5, 0.62), "sun_glow": 1.0,
			"particles": "motes", "particle_color": Color(1.0, 0.85, 0.55), "butterflies": 4, "temperature": 17.0,
			"mountain_color": Color(0.52, 0.45, 0.62), "mountain_shadow": Color(0.42, 0.36, 0.55), "mountain_snow": 0.2}),
		"layers": [
			grass_layer([Color(0.55, 0.78, 0.18), Color(0.7, 0.82, 0.22), Color(0.48, 0.72, 0.15)],
				[Color(0.95, 0.78, 0.3), Color(0.85, 0.7, 0.25)], 2400.0, Vector2(0.45, 0.85)),
			{"kind": "tree", "models": COMMON, "styles": [green], "spacing": 14.0, "chance": 0.6, "dist": [7.0, 400.0], "side": -1.0,
				"grove": [0.025, -0.1], "scale": [1.2, 1.9], "radius": 3.0, "collide": "trunk", "trunk": 0.3, "thin": {2: 0.25, 3: 0.5}},
			{"kind": "tree", "models": PINES, "styles": [pine], "spacing": 22.0, "chance": 0.4, "dist": [9.0, 30.0], "side": 1.0,
				"scale": [1.2, 1.8], "radius": 3.0, "collide": "trunk", "trunk": 0.35},
			# sea stacks in the ocean
			# sea stacks in the ocean: in loose groups of very different sizes, a few small ones near the shore
			{"kind": "rock", "models": ROCKS, "styles": [stack], "spacing": 38.0, "chance": 0.55, "dist": [70.0, 320.0], "side": 1.0,
				"grove": [0.02, 0.15], "scale": [2.5, 13.0], "squash": Vector3(0.9, 2.4, 0.9), "sink": 0.05, "radius": 8.0},
			{"kind": "rock", "models": ROCKS, "styles": [stack], "spacing": 26.0, "chance": 0.25, "dist": [40.0, 110.0], "side": 1.0,
				"scale": [1.2, 3.5], "squash": Vector3(1.1, 1.3, 1.0), "sink": 0.2, "radius": 3.0},
			{"kind": "rock", "models": ROCKS, "styles": [cliff], "spacing": 30.0, "chance": 0.4, "dist": [8.0, 50.0],
				"scale": [1.2, 3.0], "sink": 0.2, "radius": 3.0, "collide": "rock"},
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single"], "styles": [{}], "density": 2.0, "dist": [2.5, 40.0],
				"count": 18, "radius": 3.5, "scale": [0.45, 0.75], "tints": [Color(1.0, 0.95, 0.5), Color(1.0, 1.0, 1.0), Color(1.0, 0.6, 0.4)],
				"vis": 70.0, "near": true, "tilt": 0.8},
			cluster_layer(["Bush_Common_Flowers"], 0.6, [4.0, 30.0], 2, 2.0, [1.0, 1.6], true,
				{"leaves": leaves(Color(0.25, 0.45, 0.1), Color(0.65, 0.8, 0.25), {"sphere_normals": 0.85}), "stiffness": 6.0}),
			pebble_layer(rock_style(Color(0.72, 0.72, 0.76), 0.0, false, {"top_light": 0.3}), 20.0),
			# round 12: bigger sea stacks, gorse, windswept belts, marram dunes, sea thrift
			{"kind": "rock", "models": BIG_ROCKS, "styles": [stack], "spacing": 55.0, "chance": 0.45, "dist": [80.0, 300.0], "side": 1.0,
				"scale": [2.0, 5.0], "squash": Vector3(1.0, 2.0, 1.0), "sink": 0.05, "radius": 12.0},
			{"kind": "detail", "models": HEDGE + ["Bush_Large_Flowers"], "styles": [gorse], "density": 1.4, "dist": [5.0, 45.0], "side": -1.0,
				"scale": [0.8, 1.2], "shadows": true, "vis": 120.0, "near": true, "tilt": 0.3},
			{"kind": "tree", "models": TALL + ["Pine_2", "Pine_4"], "styles": [windswept], "spacing": 9.0, "chance": 0.75, "dist": [7.0, 200.0],
				"side": -1.0, "patch": [1], "scale": [0.6, 0.85], "lean": [0.1, 0.22], "radius": 3.5, "collide": "trunk", "trunk": 0.3},
			{"kind": "grass", "models": ["Grass_Wide_Tall", "Grass_Wide_Short", "Grass_Wispy_Tall"], "density": 700.0, "dist": [3.0, 70.0],
				"scale": [0.5, 0.85], "palette": marram, "region_palette": marram, "near": true, "patch": [2]},
			thrift,
		],
	}


# ================================================================ 10 Cliff Lands

static func cliffs() -> Dictionary:
	var round_tree := tree_style(Color(0.24, 0.52, 0.08), Color(0.7, 0.95, 0.3), {"tint": Color(0.95, 0.85, 0.8)}, 6.0,
		{"translucency": 0.9, "sphere_normals": 0.9})
	var deep := tree_style(Color(0.12, 0.38, 0.08), Color(0.45, 0.78, 0.2), {"tint": Color(0.95, 0.85, 0.8)}, 6.0, {"sphere_normals": 0.9})
	var rock := rock_style(Color(0.58, 0.63, 0.72), 0.55, false, {"moss_color": Color(0.5, 0.72, 0.2)})
	var terrace := rock_style(Color(0.58, 0.63, 0.74), 0.7, true, {"triplanar_scale": 0.06, "moss_color": Color(0.48, 0.72, 0.18), "top_light": 0.55})
	var slender := tree_style(Color(0.18, 0.5, 0.07), Color(0.64, 0.94, 0.28), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 1.0})
	var blooms := {"kind": "cluster", "models": WILDFLOWERS + ["Flower_6"], "styles": [{}], "density": 4.5, "dist": [2.5, 60.0], "count": 30,
		"radius": 4.0, "scale": [0.55, 0.9], "tints": [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 0.65, 1.0)],
		"vis": 75.0, "near": true, "tilt": 0.8, "patch": [3]}
	var boulder_ferns := cluster_layer(["Fern_2"], 3.5, [3.0, 50.0], 3, 2.0, [0.3, 0.46], true)
	boulder_ferns["patch"] = [1]
	return {
		"name": NAMES[9],
		# terrace meadow as before · boulder field · tall grove · flower terrace
		"patches": [{"name": "terrace meadow", "share": 0.4}, {"name": "boulder field", "share": 0.25},
			{"name": "tall grove", "share": 0.2}, {"name": "flower terrace", "share": 0.15}],
		"blades": blades(0.75, Color(0.14, 0.36, 0.05), Color(0.62, 0.9, 0.2), Color(0.9, 0.95, 0.35)),
		"terrain": terrain({"scree": 0.8, "gullies": 0.6, "hummocks": 0.2, "brooks": 0.5, "litter": 0.2, "litter_color": Color(0.7, 0.55, 0.3), "far_height": 85.0, "obstacles": ["cliff", "cliff", "river", "boulders"], "terraces": 9.0, "valley_width": 22.0, "valley_ramp": 85.0, "valley_height": 38.0, "undulation": 1.4,
			"grass_dark": Color(0.3, 0.56, 0.1), "grass_light": Color(0.55, 0.78, 0.16),
			"region_dark": Color(0.45, 0.66, 0.12), "region_light": Color(0.68, 0.82, 0.22),
			"slope_color": Color(0.54, 0.6, 0.7), "path_color": Color(0.78, 0.7, 0.5), "crack": 0.4, "ponds": 0.4}),
		"atmosphere": atmosphere({"fx": {"swallows": 1.0}, "grade_shadow": Color(0.35, 0.5, 0.78), "grade_high": Color(1.0, 0.9, 0.72), "grade_warm": 0.1, "falls": 0.9, "shafts": 0.5, "sun_dir": Vector3(-0.35, -0.62, 0.7), "sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 1.9,
			"ambient_energy": 0.5, "ambient_color": Color(0.6, 0.75, 0.9), "zenith_color": Color(0.14, 0.45, 0.92),
			"horizon_color": Color(0.74, 0.88, 1.0), "cloud_coverage": 0.44, "cirrus_amount": 0.7, "fog_density": 0.0022,
			"saturation": 1.12, "rainbow": 0.5, "particles": "motes", "butterflies": 10, "temperature": 18.0,
			"mountain_color": Color(0.5, 0.6, 0.72), "mountain_shadow": Color(0.38, 0.46, 0.66), "mountain_snow": 0.55, "mountain_scale": 1.4}),
		"layers": [
			thinned(grass_layer([Color(0.5, 0.82, 0.16), Color(0.42, 0.74, 0.12), Color(0.62, 0.88, 0.22)],
				[Color(0.75, 0.9, 0.25), Color(0.55, 0.82, 0.18)], 2800.0, Vector2(0.55, 1.0)), {3: 0.35}),
			{"kind": "tree", "models": COMMON, "styles": [round_tree, round_tree, deep], "spacing": 8.0, "chance": 0.85, "dist": [7.0, 400.0],
				"grove": [0.02, 0.05], "scale": [1.3, 2.1], "radius": 3.0, "collide": "trunk", "trunk": 0.32, "thin": {1: 0.3, 2: 0.35, 3: 0.2}},
			hero_tree(["CommonTree_1", "CommonTree_3"], round_tree, Vector2(4.5, 5.5)),
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 26.0, "chance": 0.35, "dist": [6.0, 60.0],
				"scale": [1.2, 3.4], "sink": 0.2, "radius": 3.0, "collide": "rock"},
			{"kind": "detail", "models": ["Bush_Common", "Bush_Common_Flowers"], "styles": [{"leaves": leaves(Color(0.2, 0.48, 0.08), Color(0.6, 0.88, 0.22), {"sphere_normals": 0.9}), "stiffness": 6.0}],
				"density": 3.0, "dist": [4.0, 40.0], "scale": [1.0, 1.8], "shadows": true, "vis": 130.0, "near": true, "tilt": 0.3},
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single", "Flower_3_Group"], "styles": [{}], "density": 2.5,
				"dist": [2.5, 45.0], "count": 24, "radius": 4.0, "scale": [0.45, 0.8],
				"tints": [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 0.65, 1.0)], "vis": 75.0, "near": true, "tilt": 0.8},
			pebble_layer(rock_style(Color(0.74, 0.76, 0.8), 0.0, false, {"top_light": 0.3}), 18.0),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			scree_layer(rock_style(Color(0.72, 0.7, 0.66), 0.1), 50.0),
			# round 12: terrace rocks, tall trees on the ridges, boulder fields, tall groves, flower terraces
			{"kind": "rock", "models": BIG_ROCKS, "styles": [terrace], "spacing": 48.0, "chance": 0.5, "dist": [10.0, 110.0],
				"scale": [1.2, 2.6], "grow_with_dist": true, "sink": 0.2, "radius": 8.0, "collide": "rock"},
			{"kind": "tree", "models": TALL, "styles": [slender], "spacing": 30.0, "chance": 0.5, "dist": [12.0, 400.0],
				"scale": [0.75, 1.05], "radius": 4.0, "collide": "trunk", "trunk": 0.35},
			{"kind": "rock", "models": ["Rock_Big_1", "Rock_Big_2", "Rock_Medium_4", "Rock_Medium_1"], "styles": [terrace], "spacing": 13.0,
				"chance": 0.6, "dist": [5.0, 80.0], "patch": [1], "scale": [0.5, 1.4], "sink": 0.18, "radius": 3.5, "collide": "rock"},
			boulder_ferns,
			{"kind": "tree", "models": TALL, "styles": [slender, round_tree], "spacing": 10.0, "chance": 0.8, "dist": [7.0, 400.0],
				"patch": [2], "scale": [0.7, 1.0], "radius": 3.5, "collide": "trunk", "trunk": 0.33},
			blooms,
		],
	}


# ================================================================ 11 Glowing Forest

static func glow() -> Dictionary:
	var teal := tree_style(Color(0.08, 0.36, 0.4), Color(0.45, 0.92, 0.78), {"tint": Color(0.7, 0.72, 0.9)}, 7.0, {"translucency": 1.2})
	var violet := tree_style(Color(0.3, 0.2, 0.5), Color(0.9, 0.62, 0.9), {"tint": Color(0.7, 0.72, 0.9)}, 7.0, {"translucency": 1.2})
	var shroom := {"mushroom_tint": Color(0.42, 0.62, 0.85), "mushroom_glow": Color(0.12, 0.45, 0.6)}
	var rock := rock_style(Color(0.42, 0.45, 0.6), 0.5, false, {"moss_color": Color(0.2, 0.55, 0.55)})
	var shroom_violet := {"mushroom_tint": Color(0.72, 0.5, 0.95), "mushroom_glow": Color(0.42, 0.18, 0.6)}
	var shroom_teal := {"mushroom_tint": Color(0.4, 0.85, 0.85), "mushroom_glow": Color(0.1, 0.5, 0.5)}
	var crystal := tree_style(Color(0.12, 0.34, 0.42), Color(0.55, 0.95, 0.9), {"tint": Color(0.7, 0.72, 0.9)}, 9.0,
		{"translucency": 1.2, "sphere_normals": 0.5, "glow": 0.12})
	var glow_rock := rock_style(Color(0.46, 0.5, 0.68), 0.8, true, {"moss_color": Color(0.25, 0.75, 0.7), "triplanar_scale": 0.07})
	var glow_plants := cluster_layer(["Plant_2", "Plant_2_Big", "Plant_4", "Plant_2"], 3.0, [2.5, 45.0], 5, 2.0, [0.6, 1.0], false,
		{"plant": {"glow": 0.55}})
	glow_plants["patch"] = [2]
	var glade_flowers := cluster_layer(WILDFLOWERS, 3.5, [2.5, 45.0], 12, 2.8, [0.45, 0.75])
	glade_flowers["tints"] = [Color(0.4, 0.9, 1.0), Color(0.8, 0.5, 1.0), Color(0.55, 0.6, 1.0)]
	glade_flowers["patch"] = [2]
	var ring := {"kind": "cluster", "models": ["Mushroom_Common", "Mushroom_RedCap", "Mushroom_Common"], "styles": [shroom_violet], "density": 0.9,
		"dist": [5.0, 40.0], "count": 22, "radius": 3.2, "ring": true, "scale": [0.9, 1.6], "shadows": false, "vis": 80.0, "near": true, "tilt": 0.8,
		"patch": [1]}
	var ring_teal := ring.duplicate()
	ring_teal["styles"] = [shroom_teal]
	ring_teal["radius"] = 2.2
	return {
		"name": NAMES[10],
		# deep wood as before · mushroom ring · blue glade · crystal grove
		"patches": [{"name": "deep wood", "share": 0.4}, {"name": "mushroom ring", "share": 0.2},
			{"name": "blue glade", "share": 0.25}, {"name": "crystal grove", "share": 0.15}],
		"blades": blades(0.5, Color(0.04, 0.16, 0.2), Color(0.25, 0.7, 0.65), Color(0.45, 0.5, 0.95)),
		"terrain": terrain({"scree": 0, "gullies": 0.3, "hummocks": 0.3, "brooks": 0.4, "litter": 0.45, "litter_color": Color(0.3, 0.75, 0.72), "far_height": 50.0, "valley_width": 14.0, "valley_height": 12.0, "undulation": 1.3, "ponds": 0.5,
			"grass_dark": Color(0.14, 0.34, 0.34), "grass_light": Color(0.3, 0.58, 0.52),
			"region_dark": Color(0.2, 0.2, 0.38), "region_light": Color(0.3, 0.3, 0.5),
			"slope_color": Color(0.38, 0.4, 0.55), "path_color": Color(0.66, 0.6, 0.66), "crack": 0.2,
			"water_shallow": Color(0.18, 0.55, 0.7), "water_deep": Color(0.04, 0.12, 0.3)}),
		"atmosphere": atmosphere({"fx": {"spores": 1.0}, "grade_shadow": Color(0.3, 0.35, 0.8), "grade_high": Color(0.8, 1.0, 0.92), "grade_warm": -0.3, "grade_contrast": 0.3, "shafts": 0.35, "rain": 0.7, "clock": 0.3, "mist_amount": 1.0, "sun_dir": Vector3(0.4, -0.2, 0.9), "sun_color": Color(1.0, 0.7, 0.75), "sun_energy": 1.45,
			"ambient_energy": 0.6, "ambient_color": Color(0.5, 0.55, 0.85), "fog_color": Color(0.55, 0.5, 0.8),
			"fog_density": 0.004, "fog_sun_scatter": 0.5, "volumetric": 0.008, "saturation": 1.05, "exposure": 1.0,
			"zenith_color": Color(0.16, 0.2, 0.48), "horizon_color": Color(0.95, 0.62, 0.7), "cloud_coverage": 0.55,
			"cirrus_amount": 0.4, "cloud_shadow": Color(0.35, 0.3, 0.55), "sun_glow": 0.8,
			"particles": "fireflies", "particle_color": Color(0.6, 1.0, 0.5), "butterflies": 0, "birds": false, "temperature": 13.0,
			"mountain_color": Color(0.25, 0.25, 0.45), "mountain_shadow": Color(0.18, 0.18, 0.38), "mountain_snow": 0.0}),
		"layers": [
			thinned(grass_layer([Color(0.2, 0.62, 0.6), Color(0.15, 0.5, 0.55), Color(0.3, 0.7, 0.65)],
				[Color(0.45, 0.45, 0.9), Color(0.35, 0.6, 0.85)], 2200.0, Vector2(0.45, 0.9)), {1: 0.3, 2: 0.55}),
			{"kind": "tree", "models": TWISTED, "styles": [teal, teal, violet], "spacing": 13.0, "chance": 0.75, "dist": [6.0, 400.0],
				"scale": [0.5, 0.8], "radius": 5.0, "collide": "trunk", "trunk": 0.45, "thin": {1: 0.25, 2: 0.15, 3: 0.4}},
			hero_tree(["TwistedTree_3", "TwistedTree_1"], teal, Vector2(1.6, 2.0)),
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 30.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.4], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Mushroom_Common", "Mushroom_Common", "Mushroom_Laetiporus"], 2.2, [2.0, 25.0], 6, 1.2, [0.8, 1.5], false, shroom),
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single"], "styles": [{}], "density": 2.0, "dist": [2.5, 35.0],
				"count": 12, "radius": 2.5, "scale": [0.45, 0.75], "tints": [Color(0.4, 0.9, 1.0), Color(0.8, 0.5, 1.0)],
				"vis": 70.0, "near": true, "tilt": 0.8},
			cluster_layer(["Fern_1"], 1.0, [2.5, 30.0], 2, 1.5, [0.3, 0.45], true, {"plant": {"texture_tint": Color(0.5, 1.0, 1.1)}}),
			# round 12: glowing shelves and caps, mushroom rings, blue glades, crystal groves
			{"kind": "detail", "models": ["Mushroom_Oyster"], "styles": [shroom_teal], "density": 0.0, "on_trunks": 0.45,
				"scale": [0.35, 0.6], "shadows": false, "vis": 70.0, "near": true},
			cluster_layer(["Mushroom_RedCap"], 1.2, [2.2, 25.0], 4, 0.9, [0.35, 0.6], false, shroom_violet),
			ring,
			ring_teal,
			glow_plants,
			glade_flowers,
			{"kind": "tree", "models": GIANT_PINES, "styles": [crystal], "spacing": 13.0, "chance": 0.75, "dist": [7.0, 400.0],
				"patch": [3], "scale": [1.2, 1.7], "radius": 4.5, "collide": "trunk", "trunk": 0.42},
			{"kind": "rock", "models": BIG_ROCKS + ["Rock_Medium_4"], "styles": [glow_rock], "spacing": 20.0, "chance": 0.5, "dist": [6.0, 60.0],
				"patch": [3], "scale": [0.6, 1.3], "sink": 0.2, "radius": 4.0, "collide": "rock"},
		],
	}


# ================================================================ 12 Lake Country

static func lakes() -> Dictionary:
	var birch := tree_style(Color(0.35, 0.6, 0.12), Color(0.85, 0.95, 0.4), birch_bark(), 4.5, {"translucency": 1.0})
	var willow := tree_style(Color(0.2, 0.45, 0.12), Color(0.6, 0.82, 0.3), {"tint": Color(0.9, 0.85, 0.8)}, 5.0)
	var rock := rock_style(Color(0.62, 0.66, 0.72), 0.5)
	return {
		"name": NAMES[11],
		"blades": blades(0.55, Color(0.14, 0.34, 0.08), Color(0.6, 0.85, 0.24), Color(0.8, 0.88, 0.4)),
		"terrain": terrain({"scree": 0, "gullies": 0.3, "hummocks": 0.7, "brooks": 0.8, "litter": 0.3, "litter_color": Color(0.78, 0.62, 0.3), "far_height": 30.0, "obstacles": ["river", "river", "fallen_tree"], "valley_width": 30.0, "valley_ramp": 90.0, "valley_height": 10.0, "undulation": 1.2,
			"ponds": 1.0, "pond_size": Vector2(22.0, 42.0),
			"grass_dark": Color(0.3, 0.52, 0.12), "grass_light": Color(0.52, 0.72, 0.2),
			"region_dark": Color(0.45, 0.6, 0.18), "region_light": Color(0.62, 0.74, 0.26),
			"path_color": Color(0.76, 0.68, 0.5), "crack": 0.3,
			"water_shallow": Color(0.4, 0.82, 0.8), "water_deep": Color(0.08, 0.35, 0.52)}),
		"atmosphere": atmosphere({"grade_shadow": Color(0.3, 0.55, 0.8), "grade_high": Color(0.98, 0.94, 0.8), "grade_warm": -0.05, "falls": 0.8, "deer": true, "shafts": 0.35, "mist_amount": 1.2, "sun_dir": Vector3(0.45, -0.45, 0.75), "sun_color": Color(1.0, 0.92, 0.82), "sun_energy": 1.7,
			"ambient_energy": 0.55, "ambient_color": Color(0.65, 0.78, 0.85), "fog_color": Color(0.85, 0.92, 0.98),
			"fog_density": 0.0025, "volumetric": 0.003, "saturation": 1.08, "zenith_color": Color(0.3, 0.58, 0.92),
			"horizon_color": Color(0.85, 0.93, 1.0), "cloud_coverage": 0.5, "particles": "motes", "butterflies": 8,
			"temperature": 16.0, "mountain_color": Color(0.5, 0.62, 0.7), "mountain_snow": 0.4}),
		"layers": [
			grass_layer([Color(0.5, 0.78, 0.18), Color(0.42, 0.7, 0.14), Color(0.6, 0.84, 0.22)],
				[Color(0.8, 0.85, 0.35), Color(0.6, 0.8, 0.2)], 2400.0),
			{"kind": "tree", "models": COMMON, "styles": [birch, birch, willow], "spacing": 11.0, "chance": 0.7, "dist": [7.0, 400.0],
				"grove": [0.024, -0.1], "scale": [1.1, 1.7], "radius": 2.8, "collide": "trunk", "trunk": 0.28},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 34.0, "chance": 0.3, "dist": [6.0, 50.0],
				"scale": [1.0, 2.6], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Flower_3_Group", "Flower_3_Single"], 1.0, [2.5, 30.0], 6, 1.8, [0.45, 0.75]),
			cluster_layer(["Clover_1", "Clover_2"], 0.8, [2.5, 25.0], 8, 1.5, [0.6, 1.0]),
			pebble_layer(rock_style(Color(0.74, 0.74, 0.74), 0.0, false, {"top_light": 0.3}), 18.0),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			erratic_layer(rock_style(Color(0.64, 0.68, 0.72), 0.7), 140.0),
		],
	}


# ================================================================ 13 Lavender Hills

static func lavender() -> Dictionary:
	var olive := tree_style(Color(0.36, 0.44, 0.28), Color(0.72, 0.78, 0.56), {"tint": Color(0.85, 0.8, 0.74)}, 6.0, {"translucency": 0.7})
	var pine := tree_style(Color(0.12, 0.3, 0.1), Color(0.36, 0.56, 0.2), {"tint": Color(0.9, 0.8, 0.7)}, 7.0, {"sphere_normals": 0.5})
	var rock := rock_style(Color(0.88, 0.84, 0.74), 0.15)
	var poppies := cluster_layer(["Flower_4_Group", "Flower_4_Single"], 0.9, [2.5, 30.0], 6, 1.6, [0.45, 0.7])
	poppies["tints"] = [Color(0.92, 0.14, 0.08), Color(0.96, 0.26, 0.1), Color(0.85, 0.1, 0.12)]
	var broom := {"leaves": leaves(Color(0.55, 0.5, 0.1), Color(1.0, 0.86, 0.2), {"sphere_normals": 0.85}), "stiffness": 6.0}
	return {
		"name": NAMES[12],
		"blades": blades(0.38, Color(0.26, 0.34, 0.1), Color(0.66, 0.74, 0.3), Color(0.9, 0.82, 0.45)),
		"terrain": terrain({"scree": 0.2, "gullies": 0.3, "hummocks": 0.5, "brooks": 0.35, "litter": 0.1, "litter_color": Color(0.6, 0.46, 0.8), "far_height": 40.0, "obstacles": ["stile", "stile", "fallen_tree"],
			"valley_width": 30.0, "valley_ramp": 110.0, "valley_height": 14.0, "undulation": 1.8,
			"grass_dark": Color(0.42, 0.52, 0.16), "grass_light": Color(0.68, 0.7, 0.3),
			"region_dark": Color(0.5, 0.46, 0.4), "region_light": Color(0.66, 0.6, 0.36),
			"slope_color": Color(0.8, 0.74, 0.62), "path_color": Color(0.9, 0.84, 0.68), "crack": 0.6}),
		"atmosphere": atmosphere({"grade_shadow": Color(0.52, 0.42, 0.78), "grade_high": Color(1.0, 0.86, 0.66), "grade_warm": 0.35, "deer": true, "rain": 0.5, "sun_dir": Vector3(0.55, -0.5, 0.65), "sun_color": Color(1.0, 0.9, 0.74), "sun_energy": 1.9,
			"ambient_energy": 0.5, "ambient_color": Color(0.85, 0.76, 0.82), "fog_color": Color(0.96, 0.89, 0.9),
			"fog_density": 0.002, "saturation": 1.1, "zenith_color": Color(0.3, 0.55, 0.92), "horizon_color": Color(0.98, 0.9, 0.88),
			"cloud_coverage": 0.3, "particles": "motes", "particle_color": Color(1.0, 0.9, 1.0), "butterflies": 14,
			"temperature": 25.0, "mountain_color": Color(0.62, 0.58, 0.74), "mountain_shadow": Color(0.5, 0.46, 0.68),
			"mountain_snow": 0.1, "sun_glow": 0.5}),
		"layers": [
			grass_layer([Color(0.56, 0.66, 0.32), Color(0.5, 0.6, 0.28), Color(0.64, 0.7, 0.38)],
				[Color(0.76, 0.74, 0.44), Color(0.68, 0.64, 0.36)], 900.0, Vector2(0.3, 0.52)),
			{"kind": "rows", "models": ["Proc_Lavender"], "styles": [{"plant": {"stiffness": 2.5}}], "row_spacing": 1.9, "step": 1.1,
				"dist": [4.5, 70.0], "scale": [0.95, 1.3], "shadows": true, "vis": 120.0, "near": true},
			{"kind": "tree", "models": TWISTED, "styles": [olive], "spacing": 28.0, "chance": 0.55, "dist": [8.0, 300.0],
				"scale": [0.42, 0.6], "radius": 4.0, "collide": "trunk", "trunk": 0.4},
			{"kind": "tree", "models": PINES, "styles": [pine], "spacing": 46.0, "chance": 0.35, "dist": [10.0, 300.0],
				"scale": [1.3, 1.9], "radius": 2.5, "collide": "trunk", "trunk": 0.3},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 34.0, "chance": 0.3, "dist": [6.0, 60.0],
				"scale": [1.0, 2.4], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			{"kind": "detail", "models": ["Bush_Common"], "styles": [broom], "density": 1.2, "dist": [5.0, 40.0],
				"scale": [0.8, 1.3], "shadows": true, "vis": 110.0, "near": true, "tilt": 0.3},
			poppies,
			pebble_layer(rock_style(Color(0.86, 0.83, 0.76), 0.0, false, {"top_light": 0.3}), 26.0),
			small_rock_layer(rock),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			erratic_layer(rock_style(Color(0.88, 0.84, 0.74), 0.3), 160.0),
		],
	}


# ================================================================ 14 Birch Wood

static func birch_wood() -> Dictionary:
	var white_bark := birch_bark()
	white_bark["brightness"] = 3.6
	var birch := tree_style(Color(0.28, 0.52, 0.1), Color(0.72, 0.9, 0.3), white_bark, 4.5, {"translucency": 1.0})
	var golden := tree_style(Color(0.74, 0.56, 0.1), Color(1.0, 0.88, 0.36), white_bark, 4.5, {"translucency": 1.0})
	var rock := rock_style(Color(0.7, 0.72, 0.68), 0.55)
	var white_flowers := cluster_layer(["Flower_3_Group", "Flower_3_Single"], 0.8, [2.5, 26.0], 7, 1.6, [0.4, 0.65])
	white_flowers["tints"] = [Color(1.0, 1.0, 0.95), Color(0.96, 0.94, 1.0)]
	return {
		"name": NAMES[13],
		"blades": blades(0.45, Color(0.14, 0.3, 0.06), Color(0.6, 0.8, 0.2), Color(0.92, 0.86, 0.36)),
		"terrain": terrain({"scree": 0, "gullies": 0.4, "hummocks": 0.4, "brooks": 0.75, "litter": 0.55, "litter_color": Color(0.96, 0.78, 0.22), "far_height": 45.0,
			"obstacles": ["fallen_tree", "river", "mud"], "ponds": 0.25, "path_width": 2.8,
			"valley_width": 14.0, "valley_ramp": 70.0, "valley_height": 12.0, "undulation": 1.3,
			"grass_dark": Color(0.36, 0.52, 0.12), "grass_light": Color(0.62, 0.72, 0.2),
			"region_dark": Color(0.62, 0.6, 0.18), "region_light": Color(0.78, 0.7, 0.28),
			"path_color": Color(0.72, 0.62, 0.44), "slope_color": Color(0.5, 0.52, 0.3), "crack": 0.5}),
		"atmosphere": atmosphere({"grade_shadow": Color(0.35, 0.52, 0.55), "grade_high": Color(1.0, 0.92, 0.62), "grade_warm": 0.3, "deer": true, "shafts": 1.0, "sun_dir": Vector3(-0.4, -0.55, 0.72), "sun_color": Color(1.0, 0.94, 0.82), "sun_energy": 1.8,
			"ambient_energy": 0.6, "ambient_color": Color(0.7, 0.78, 0.6), "fog_color": Color(0.88, 0.92, 0.86),
			"fog_density": 0.0035, "fog_sun_scatter": 0.4, "volumetric": 0.008, "exposure": 0.92,
			"zenith_color": Color(0.34, 0.6, 0.9), "horizon_color": Color(0.9, 0.93, 0.9), "cloud_coverage": 0.45,
			"particles": "leaves", "particle_color": Color(1.0, 0.84, 0.28), "butterflies": 4, "temperature": 14.0,
			"mountain_color": Color(0.5, 0.56, 0.46), "mountain_snow": 0.2}),
		"layers": [
			grass_layer([Color(0.52, 0.78, 0.18), Color(0.44, 0.7, 0.14), Color(0.66, 0.84, 0.24)],
				[Color(0.9, 0.78, 0.28), Color(0.8, 0.82, 0.3)], 1800.0),
			{"kind": "tree", "models": COMMON, "styles": [birch], "region_styles": [golden], "spacing": 8.0, "chance": 0.8,
				"dist": [5.0, 400.0], "falloff": [20.0, 160.0, 0.55], "grove": [0.022, -0.2], "scale": [1.2, 2.0], "radius": 2.4, "collide": "trunk", "trunk": 0.26},
			hero_tree(["CommonTree_2", "CommonTree_4"], birch, Vector2(3.6, 4.4)),
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 32.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.4], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Fern_1"], 2.4, [2.5, 40.0], 4, 1.8, [0.3, 0.5]),
			white_flowers,
			cluster_layer(["Mushroom_Common"], 1.0, [2.0, 9.0], 5, 0.6, [0.9, 1.7]),
			cluster_layer(["Clover_1", "Clover_2"], 0.6, [2.5, 22.0], 8, 1.5, [0.6, 1.0]),
			pebble_layer(rock_style(Color(0.74, 0.74, 0.7), 0.0, false, {"top_light": 0.3}), 16.0),
			small_rock_layer(rock),
		],
	}


# ================================================================ 15 Heather Highlands

static func highlands() -> Dictionary:
	var granite := rock_style(Color(0.66, 0.66, 0.68), 0.5)
	var crag := rock_style(Color(0.6, 0.6, 0.62), 0.55, true)
	var pine := tree_style(Color(0.1, 0.26, 0.12), Color(0.3, 0.5, 0.22), {"tint": Color(0.85, 0.78, 0.72)}, 7.0, {"sphere_normals": 0.5})
	return {
		"name": NAMES[14],
		"blades": blades(0.35, Color(0.22, 0.26, 0.1), Color(0.56, 0.6, 0.28), Color(0.74, 0.62, 0.4)),
		"terrain": terrain({"scree": 0.7, "gullies": 1.0, "hummocks": 0.9, "brooks": 0.9, "litter": 0.0, "litter_color": Color(0.5, 0.4, 0.3), "far_height": 70.0, "obstacles": ["boulders", "boulders", "mud", "river"],
			"ponds": 0.45, "pond_size": Vector2(10.0, 22.0), "water_shallow": Color(0.42, 0.6, 0.62), "water_deep": Color(0.1, 0.22, 0.3),
			"valley_width": 40.0, "valley_ramp": 140.0, "valley_height": 24.0, "undulation": 2.6, "roughness": 0.6,
			"grass_dark": Color(0.36, 0.42, 0.2), "grass_light": Color(0.56, 0.58, 0.3),
			"region_dark": Color(0.46, 0.32, 0.42), "region_light": Color(0.6, 0.44, 0.52),
			"slope_color": Color(0.56, 0.56, 0.54), "path_color": Color(0.62, 0.56, 0.46), "crack": 0.3}),
		"atmosphere": atmosphere({"grade_shadow": Color(0.35, 0.45, 0.62), "grade_high": Color(0.92, 0.92, 0.9), "grade_warm": -0.35, "grade_contrast": 0.15, "falls": 1.0, "deer": true, "rain": 1.8, "mist_amount": 1.4, "sun_dir": Vector3(0.3, -0.38, 0.8), "sun_color": Color(0.96, 0.93, 0.9), "sun_energy": 1.35,
			"ambient_energy": 0.62, "ambient_color": Color(0.6, 0.66, 0.76), "fog_color": Color(0.78, 0.82, 0.86),
			"fog_density": 0.0055, "fog_sun_scatter": 0.15, "volumetric": 0.009, "exposure": 0.96, "saturation": 0.96,
			"zenith_color": Color(0.44, 0.55, 0.7), "horizon_color": Color(0.8, 0.84, 0.88), "cloud_coverage": 0.78,
			"cirrus_amount": 0.2, "particles": "drizzle", "particle_color": Color(0.85, 0.9, 1.0), "butterflies": 0,
			"temperature": 9.0, "mountain_color": Color(0.44, 0.5, 0.56), "mountain_shadow": Color(0.36, 0.42, 0.52),
			"mountain_snow": 0.35, "gusts": 0.9, "rainbow": 0.5}),
		"layers": [
			grass_layer([Color(0.52, 0.6, 0.24), Color(0.46, 0.54, 0.2), Color(0.62, 0.62, 0.3)],
				[Color(0.66, 0.46, 0.56), Color(0.58, 0.4, 0.5), Color(0.72, 0.6, 0.4)], 1700.0, Vector2(0.4, 0.7)),
			cluster_layer(["Proc_Heather"], 3.4, [2.5, 70.0], 5, 2.2, [0.8, 1.35], true),
			{"kind": "rock", "models": ROCKS, "styles": [crag], "spacing": 42.0, "chance": 0.4, "dist": [14.0, 120.0],
				"scale": [3.0, 6.0], "squash": Vector3(1.4, 0.8, 1.2), "sink": 0.22, "radius": 6.0, "collide": "rock"},
			{"kind": "rock", "models": ROCKS, "styles": [granite], "spacing": 18.0, "chance": 0.45, "dist": [5.0, 90.0],
				"scale": [1.0, 3.0], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			{"kind": "tree", "models": PINES, "styles": [pine], "spacing": 60.0, "chance": 0.3, "dist": [12.0, 300.0],
				"scale": [1.2, 1.8], "radius": 2.5, "collide": "trunk", "trunk": 0.3},
			cluster_layer(["Fern_1"], 0.6, [3.0, 30.0], 2, 1.2, [0.3, 0.42], true),
			pebble_layer(rock_style(Color(0.66, 0.66, 0.66), 0.0, false, {"top_light": 0.3}), 20.0),
			small_rock_layer(granite, 5.0, [2.0, 16.0]),
			# (new layers go last: earlier layers keep their index and so the same scatter in every world)
			scree_layer(rock_style(Color(0.66, 0.66, 0.68), 0.2), 45.0), erratic_layer(rock_style(Color(0.62, 0.64, 0.62), 0.75), 90.0),
		],
	}
