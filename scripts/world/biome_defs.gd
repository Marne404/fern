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


static func cluster_layer(models: Array, density: float, dist: Array, count: int, radius: float, scale: Array, shadows := false, style := {}) -> Dictionary:
	return {"kind": "cluster", "models": models, "styles": [style], "density": density, "dist": dist, "count": count,
		"radius": radius, "scale": scale, "shadows": shadows, "vis": 60.0, "near": true, "tilt": 0.8}


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
	return {
		"name": NAMES[0],
		"blades": blades(0.5, Color(0.16, 0.32, 0.05), Color(0.55, 0.82, 0.18), Color(0.98, 0.6, 0.16)),
		"terrain": terrain({"litter": 0.55, "litter_color": Color(0.92, 0.5, 0.16), "far_height": 60.0, "ponds": 0.3, "terraces": 7.0, "valley_height": 20.0}),
		"atmosphere": atmosphere({"mountain_color": Color(0.52, 0.56, 0.44), "mountain_snow": 0.2, "particles": "leaves", "particle_color": Color(1.0, 0.5, 0.12), "butterflies": 10, "gusts": 0.85}),
		"layers": [
			grass_layer([Color(0.42, 0.74, 0.1), Color(0.34, 0.64, 0.08), Color(0.55, 0.8, 0.14), Color(0.48, 0.72, 0.12)],
				[Color(0.98, 0.55, 0.14), Color(0.95, 0.35, 0.1), Color(1.0, 0.75, 0.25), Color(0.85, 0.22, 0.08), Color(0.7, 0.85, 0.2)]),
			{"kind": "tree", "models": COMMON, "styles": [green], "region_styles": [orange, orange, red, yellow],
				"spacing": 8.0, "chance": 0.85, "dist": [6.0, 400.0], "falloff": [12.0, 160.0, 0.6], "grove": [0.022, -0.05],
				"scale": [1.1, 1.8], "radius": 2.8, "collide": "trunk", "trunk": 0.3},
			hero_tree(["CommonTree_1", "CommonTree_3"], green, Vector2(4.0, 5.0)),
			{"kind": "tree", "models": TWISTED, "styles": [maple_style], "spacing": 45.0, "chance": 0.35, "region_only": true,
				"dist": [14.0, 400.0], "scale": [0.55, 0.75], "radius": 5.0, "collide": "trunk", "trunk": 0.5},
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
	return {
		"name": NAMES[1],
		"blades": blades(0.4, Color(0.1, 0.28, 0.05), Color(0.5, 0.8, 0.18), Color(0.78, 0.8, 0.25)),
		"terrain": terrain({"litter": 0.6, "litter_color": Color(0.55, 0.38, 0.2), "far_height": 55.0, "obstacles": ["fallen_tree", "fallen_tree", "river"], "ponds": 0.3, "path_width": 2.8, "valley_width": 12.0, "valley_ramp": 70.0, "valley_height": 12.0, "undulation": 1.4,
			"grass_dark": Color(0.3, 0.54, 0.1), "grass_light": Color(0.55, 0.74, 0.18),
			"region_dark": Color(0.55, 0.62, 0.18), "region_light": Color(0.7, 0.72, 0.28),
			"path_color": Color(0.78, 0.68, 0.42), "slope_color": Color(0.42, 0.52, 0.2), "crack": 0.9}),
		"atmosphere": atmosphere({"temperature": 15.0, "mountain_color": Color(0.32, 0.46, 0.38), "mountain_snow": 0.15, "mountain_scale": 0.9, "sun_dir": Vector3(-0.35, -0.6, 0.72), "sun_color": Color(1.0, 0.93, 0.78), "sun_energy": 1.7,
			"ambient_energy": 0.7, "ambient_color": Color(0.62, 0.78, 0.45), "fog_color": Color(0.84, 0.92, 0.9),
			"fog_density": 0.003, "fog_sun_scatter": 0.3, "volumetric": 0.007, "exposure": 0.9,
			"zenith_color": Color(0.3, 0.62, 0.9), "horizon_color": Color(0.82, 0.93, 0.97), "cloud_coverage": 0.54,
			"cirrus_amount": 0.4, "particles": "motes", "butterflies": 5}),
		"layers": [
			grass_layer([Color(0.55, 0.86, 0.2), Color(0.45, 0.78, 0.16), Color(0.7, 0.92, 0.3), Color(0.62, 0.86, 0.24)],
				[Color(0.92, 0.72, 0.25), Color(0.85, 0.6, 0.2), Color(0.8, 0.82, 0.3)], 2000.0),
			{"kind": "tree", "models": PINES, "styles": [pine], "spacing": 7.5, "chance": 0.8, "dist": [5.5, 400.0],
				"falloff": [20.0, 120.0, 0.55], "scale": [1.5, 2.3], "radius": 3.0, "collide": "trunk", "trunk": 0.35},
			{"kind": "tree", "models": COMMON, "styles": [broad], "spacing": 13.0, "chance": 0.6, "dist": [5.5, 300.0],
				"scale": [1.2, 1.8], "radius": 3.0, "collide": "trunk", "trunk": 0.3},
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
	return {
		"name": NAMES[2],
		"blades": blades(0.0, Color(0.5, 0.4, 0.2), Color(0.9, 0.75, 0.35), Color(0.9, 0.6, 0.25)),
		"terrain": terrain({"litter": 0.0, "litter_color": Color(0.6, 0.5, 0.3), "far_height": 8.0, "dunes": 1.0, "obstacles": ["fallen_tree", "cliff"], "terraces": 0.0, "path_width": 2.2, "path_depth": 0.05, "valley_width": 30.0, "valley_ramp": 70.0, "valley_height": 4.0,
			"undulation": 1.6, "grass_dark": Color(0.86, 0.68, 0.36), "grass_light": Color(0.95, 0.8, 0.46),
			"region_dark": Color(0.84, 0.66, 0.34), "region_light": Color(0.92, 0.76, 0.44),
			"path_color": Color(0.84, 0.68, 0.38), "slope_color": Color(0.86, 0.66, 0.36), "crack": 0.7, "ripple": 1.0}),
		"atmosphere": atmosphere({"temperature": 34.0, "mountain_color": Color(0.86, 0.6, 0.42), "mountain_shadow": Color(0.7, 0.5, 0.48), "mountain_snow": 0.0, "mountain_scale": 0.7, "birds": false, "sun_dir": Vector3(0.3, -0.85, -0.5), "sun_color": Color(1.0, 0.93, 0.8), "sun_energy": 1.8,
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
			{"kind": "path_stones", "models": PAVING, "styles": [rock_style(Color(0.7, 0.7, 0.68), 0.0, false, {"top_light": 0.3, "flatten": 0.5})],
				"density": 520.0, "gap": [0.09, -0.3], "scale": [0.9, 1.3], "shadows": false, "vis": 70.0, "near": true},
		],
	}


# ================================================================ 4 Blossom Grove

static func blossom() -> Dictionary:
	var pink := tree_style(Color(0.8, 0.45, 0.72), Color(1.0, 0.8, 0.93), {"tint": Color(0.9, 0.78, 0.75)}, 6.0, {"translucency": 1.0})
	var lilac := tree_style(Color(0.58, 0.45, 0.85), Color(0.88, 0.8, 1.0), {"tint": Color(0.9, 0.78, 0.75)}, 6.0, {"translucency": 1.0})
	var white := tree_style(Color(0.85, 0.75, 0.8), Color(1.0, 0.97, 0.97), birch_bark(), 5.0, {"translucency": 1.0})
	var rock := rock_style(Color(0.72, 0.72, 0.74), 0.3)
	return {
		"name": NAMES[3],
		"blades": blades(0.45, Color(0.15, 0.35, 0.08), Color(0.6, 0.88, 0.28), Color(0.78, 0.86, 0.5)),
		"terrain": terrain({"litter": 0.6, "litter_color": Color(1.0, 0.72, 0.82), "far_height": 45.0, "ponds": 0.45, "terraces": 5.0, "water_shallow": Color(0.5, 0.85, 0.85), "valley_width": 18.0, "valley_height": 12.0, "undulation": 1.0,
			"grass_dark": Color(0.36, 0.6, 0.16), "grass_light": Color(0.58, 0.78, 0.26),
			"region_dark": Color(0.62, 0.62, 0.3), "region_light": Color(0.76, 0.74, 0.4),
			"path_color": Color(0.82, 0.74, 0.56), "crack": 0.3}),
		"atmosphere": atmosphere({"rainbow": 0.6, "temperature": 19.0, "mountain_color": Color(0.64, 0.6, 0.74), "mountain_shadow": Color(0.55, 0.52, 0.7), "mountain_snow": 0.3, "sun_dir": Vector3(0.5, -0.5, 0.6), "sun_color": Color(1.0, 0.92, 0.88), "sun_energy": 1.7,
			"ambient_energy": 0.55, "ambient_color": Color(0.8, 0.7, 0.85), "fog_color": Color(0.95, 0.88, 0.95),
			"fog_density": 0.0024, "fog_sun_scatter": 0.35, "zenith_color": Color(0.35, 0.6, 0.95),
			"horizon_color": Color(0.94, 0.88, 0.96), "cloud_coverage": 0.52, "particles": "petals",
			"particle_color": Color(1.0, 0.75, 0.9), "butterflies": 14}),
		"layers": [
			grass_layer([Color(0.5, 0.8, 0.2), Color(0.42, 0.72, 0.16), Color(0.62, 0.86, 0.3)],
				[Color(0.55, 0.82, 0.25), Color(0.62, 0.86, 0.3), Color(0.95, 0.78, 0.9)], 2200.0),
			{"kind": "tree", "models": TWISTED, "styles": [pink, pink, lilac], "spacing": 22.0, "chance": 0.65, "dist": [7.0, 400.0],
				"falloff": [14.0, 140.0, 0.5], "grove": [0.02, -0.05], "scale": [0.45, 0.65], "radius": 5.0, "collide": "trunk", "trunk": 0.45},
			hero_tree(["TwistedTree_1", "TwistedTree_3"], pink, Vector2(1.5, 1.9)),
			{"kind": "tree", "models": COMMON, "styles": [white, pink], "spacing": 16.0, "chance": 0.45, "dist": [6.0, 300.0],
				"scale": [0.9, 1.3], "radius": 2.6, "collide": "trunk", "trunk": 0.28},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 34.0, "chance": 0.25, "dist": [6.0, 40.0],
				"scale": [1.0, 2.2], "sink": 0.15, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single"], 1.8, [2.5, 30.0], 7, 2.0, [0.45, 0.75]),
			cluster_layer(["Clover_1", "Clover_2"], 0.6, [2.5, 26.0], 8, 1.5, [0.6, 1.0]),
			{"kind": "detail", "models": ["Bush_Common_Flowers"], "styles": [{"leaves": leaves(Color(0.25, 0.5, 0.12), Color(0.55, 0.82, 0.25), {"sphere_normals": 0.85}), "stiffness": 6.0}],
				"density": 2.0, "dist": [4.0, 24.0], "scale": [0.9, 1.5], "shadows": true, "vis": 110.0, "near": true, "tilt": 0.3},
			pebble_layer(rock_style(Color(0.76, 0.75, 0.74), 0.0, false, {"top_light": 0.3}), 18.0),
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
	return {
		"name": NAMES[4],
		"blades": blades(0.55, Color(0.12, 0.34, 0.05), Color(0.52, 0.86, 0.16), Color(0.85, 0.92, 0.3)),
		"terrain": terrain({"litter": 0.25, "litter_color": Color(0.98, 0.96, 0.88), "far_height": 40.0, "valley_width": 34.0, "valley_ramp": 110.0, "valley_height": 22.0, "undulation": 2.4,
			"grass_dark": Color(0.26, 0.54, 0.1), "grass_light": Color(0.5, 0.76, 0.16),
			"region_dark": Color(0.42, 0.64, 0.12), "region_light": Color(0.66, 0.8, 0.2),
			"slope_color": Color(0.4, 0.58, 0.18), "path_color": Color(0.78, 0.68, 0.46), "crack": 0.4,
			"ponds": 0.55, "pond_size": Vector2(10.0, 22.0),
			"water_shallow": Color(0.42, 0.86, 0.74), "water_deep": Color(0.1, 0.42, 0.55)}),
		"atmosphere": atmosphere({"rainbow": 0.8, "temperature": 19.0, "sun_dir": Vector3(-0.4, -0.6, 0.62), "sun_color": Color(1.0, 0.95, 0.84), "sun_energy": 1.9,
			"ambient_energy": 0.48, "ambient_color": Color(0.62, 0.8, 0.55),
			"zenith_color": Color(0.16, 0.5, 0.95), "horizon_color": Color(0.76, 0.9, 1.0), "cloud_coverage": 0.47,
			"cirrus_amount": 0.7, "fog_color": Color(0.8, 0.9, 0.98), "fog_density": 0.0012, "saturation": 1.12,
			"particles": "motes", "particle_color": Color(1.0, 1.0, 0.85), "butterflies": 16,
			"mountain_color": Color(0.46, 0.6, 0.56), "mountain_shadow": Color(0.4, 0.5, 0.64), "mountain_snow": 0.45, "mountain_scale": 1.25}),
		"layers": [
			grass_layer([Color(0.42, 0.76, 0.12), Color(0.34, 0.66, 0.1), Color(0.56, 0.84, 0.18), Color(0.48, 0.8, 0.14)],
				[Color(0.62, 0.86, 0.2), Color(0.9, 0.9, 0.35), Color(0.5, 0.8, 0.16)], 2400.0, Vector2(0.28, 0.52), SHORT_GRASS + ["Grass_Common_Tall"]),
			{"kind": "tree", "models": COMMON, "styles": [oak, oak, fresh], "spacing": 24.0, "chance": 0.6, "dist": [9.0, 400.0],
				"falloff": [20.0, 160.0, 0.6], "grove": [0.026, -0.2], "scale": [1.5, 2.3], "radius": 4.0, "collide": "trunk", "trunk": 0.35},
			hero_tree(["CommonTree_1", "CommonTree_2"], oak, Vector2(4.2, 5.2)),
			{"kind": "tree", "models": ["TwistedTree_1", "TwistedTree_4"], "styles": [bloom], "spacing": 70.0, "chance": 0.5, "dist": [10.0, 200.0],
				"scale": [0.45, 0.6], "radius": 5.0, "collide": "trunk", "trunk": 0.45},
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
		],
	}


# ================================================================ 6 Red Maple Wood

static func maple() -> Dictionary:
	var maple_style := tree_style(Color(0.62, 0.08, 0.04), Color(0.98, 0.32, 0.1), {"tint": Color(0.92, 0.88, 0.85)}, 7.0, {"translucency": 1.0})
	var orange := tree_style(Color(0.85, 0.35, 0.05), Color(1.0, 0.7, 0.22), {"tint": Color(0.95, 0.85, 0.8)}, 5.0, {"translucency": 0.9})
	var rock := rock_style(Color(0.66, 0.64, 0.6), 0.2)
	return {
		"name": NAMES[5],
		"blades": blades(0.45, Color(0.3, 0.22, 0.06), Color(0.95, 0.55, 0.15), Color(0.9, 0.25, 0.08)),
		"terrain": terrain({"litter": 0.7, "litter_color": Color(0.9, 0.22, 0.12), "far_height": 60.0, "valley_width": 13.0, "valley_height": 14.0, "undulation": 1.3,
			"grass_dark": Color(0.62, 0.42, 0.12), "grass_light": Color(0.78, 0.56, 0.18),
			"region_dark": Color(0.7, 0.28, 0.1), "region_light": Color(0.86, 0.42, 0.14),
			"path_color": Color(0.72, 0.58, 0.38), "slope_color": Color(0.55, 0.42, 0.24), "crack": 0.6}),
		"atmosphere": atmosphere({"temperature": 13.0, "mountain_color": Color(0.72, 0.52, 0.42), "mountain_shadow": Color(0.56, 0.46, 0.52), "mountain_snow": 0.15, "sun_dir": Vector3(0.6, -0.42, 0.65), "sun_color": Color(1.0, 0.82, 0.6), "sun_energy": 1.8,
			"ambient_energy": 0.5, "ambient_color": Color(0.9, 0.7, 0.5), "fog_color": Color(0.98, 0.85, 0.7),
			"fog_density": 0.0028, "fog_sun_scatter": 0.45, "volumetric": 0.004,
			"zenith_color": Color(0.32, 0.58, 0.9), "horizon_color": Color(0.98, 0.9, 0.8), "cloud_coverage": 0.5,
			"particles": "leaves", "particle_color": Color(0.95, 0.25, 0.08), "butterflies": 3, "gusts": 0.85}),
		"layers": [
			grass_layer([Color(0.95, 0.5, 0.12), Color(0.9, 0.3, 0.08), Color(1.0, 0.7, 0.22), Color(0.6, 0.72, 0.18)],
				[Color(0.85, 0.2, 0.06), Color(0.98, 0.6, 0.15)], 2000.0),
			{"kind": "tree", "models": TWISTED, "styles": [maple_style], "spacing": 16.0, "chance": 0.7, "dist": [7.0, 400.0],
				"falloff": [18.0, 140.0, 0.55], "scale": [0.5, 0.75], "radius": 5.0, "collide": "trunk", "trunk": 0.5},
			hero_tree(["TwistedTree_2", "TwistedTree_5"], maple_style, Vector2(1.5, 1.9)),
			{"kind": "tree", "models": COMMON, "styles": [orange], "spacing": 12.0, "chance": 0.55, "dist": [5.5, 300.0],
				"scale": [1.0, 1.5], "radius": 2.6, "collide": "trunk", "trunk": 0.28},
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 30.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.6], "sink": 0.15, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Mushroom_Common"], 1.0, [2.0, 10.0], 5, 0.6, [0.9, 1.7]),
			cluster_layer(["Fern_1"], 0.4, [3.0, 24.0], 1, 1.0, [0.28, 0.38], true,
				{"plant": {"texture_tint": Color(1.3, 0.7, 0.3)}}),
			cluster_layer(PLANTS, 0.4, [2.5, 20.0], 3, 1.2, [0.6, 1.0]),
			pebble_layer(rock_style(Color(0.7, 0.68, 0.64), 0.0, false, {"top_light": 0.3}), 22.0),
		],
	}


# ================================================================ 7 Mountain Pines

static func alpine() -> Dictionary:
	var pine := tree_style(Color(0.06, 0.26, 0.1), Color(0.3, 0.58, 0.2), {"tint": Color(0.9, 0.78, 0.7)}, 8.0, {"sphere_normals": 0.55, "translucency": 0.5})
	var pine_light := tree_style(Color(0.1, 0.34, 0.12), Color(0.42, 0.68, 0.24), {"tint": Color(0.9, 0.78, 0.7)}, 8.0, {"sphere_normals": 0.55, "translucency": 0.6})
	var cliff := rock_style(Color(0.74, 0.76, 0.8), 0.55, true, {"triplanar_scale": 0.07, "moss_color": Color(0.94, 0.96, 1.0), "top_light": 0.5})
	var rock := rock_style(Color(0.78, 0.79, 0.8), 0.35)
	var tints := [Color(0.3, 0.45, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(0.75, 0.45, 1.0), Color(0.35, 0.55, 1.0)]
	return {
		"name": NAMES[6],
		"blades": blades(0.3, Color(0.1, 0.3, 0.08), Color(0.45, 0.75, 0.2), Color(0.7, 0.78, 0.3)),
		"terrain": terrain({"litter": 0.7, "litter_color": Color(0.66, 0.36, 0.2), "far_height": 120.0, "obstacles": ["cliff", "cliff", "river"], "valley_width": 16.0, "valley_ramp": 80.0, "valley_height": 58.0, "undulation": 1.6, "roughness": 1.2,
			"grass_dark": Color(0.24, 0.48, 0.14), "grass_light": Color(0.44, 0.66, 0.2),
			"region_dark": Color(0.36, 0.56, 0.18), "region_light": Color(0.56, 0.7, 0.26),
			"slope_color": Color(0.56, 0.58, 0.6), "path_color": Color(0.7, 0.6, 0.44), "crack": 0.3,
			"snow": 22.0, "ponds": 0.75, "terraces": 9.0, "pond_size": Vector2(14.0, 30.0),
			"water_shallow": Color(0.3, 0.84, 0.86), "water_deep": Color(0.04, 0.32, 0.58)}),
		"atmosphere": atmosphere({"temperature": 5.0, "sun_dir": Vector3(-0.5, -0.55, 0.65), "sun_color": Color(1.0, 0.97, 0.92), "sun_energy": 1.95,
			"ambient_energy": 0.5, "ambient_color": Color(0.6, 0.72, 0.9), "fog_color": Color(0.78, 0.88, 0.98),
			"fog_density": 0.0014, "saturation": 1.12, "zenith_color": Color(0.12, 0.42, 0.9), "horizon_color": Color(0.8, 0.9, 1.0),
			"cloud_coverage": 0.46, "cirrus_amount": 0.95, "particles": "motes", "butterflies": 4,
			"mountain_color": Color(0.56, 0.62, 0.72), "mountain_shadow": Color(0.4, 0.48, 0.66), "mountain_snow": 0.75, "mountain_scale": 1.7}),
		"layers": [
			grass_layer([Color(0.36, 0.66, 0.14), Color(0.46, 0.72, 0.2), Color(0.3, 0.58, 0.12), Color(0.52, 0.76, 0.22)],
				[Color(0.62, 0.74, 0.28), Color(0.46, 0.68, 0.2)], 2200.0, Vector2(0.35, 0.65)),
			{"kind": "tree", "models": PINES, "styles": [pine, pine, pine_light], "spacing": 10.0, "chance": 0.65, "dist": [8.0, 400.0],
				"falloff": [20.0, 150.0, 0.6], "grove": [0.02, -0.15], "scale": [1.4, 2.4], "radius": 3.0, "collide": "trunk", "trunk": 0.35},
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
		],
	}


# ================================================================ 8 Deadwood Bog

static func bog() -> Dictionary:
	var dead := {"bark": {"tint": Color(0.7, 0.68, 0.64), "brightness": 0.9, "desaturate": 0.6, "ao_strength": 0.6}, "stiffness": 14.0}
	var twisted := tree_style(Color(0.16, 0.32, 0.1), Color(0.42, 0.56, 0.2), {"tint": Color(0.8, 0.78, 0.74)}, 7.0, {"translucency": 0.6})
	var rock := rock_style(Color(0.52, 0.56, 0.5), 0.7)
	return {
		"name": NAMES[7],
		"blades": blades(0.6, Color(0.14, 0.2, 0.06), Color(0.48, 0.58, 0.2), Color(0.6, 0.52, 0.22)),
		"terrain": terrain({"litter": 0.5, "litter_color": Color(0.36, 0.28, 0.16), "far_height": 18.0, "obstacles": ["fallen_tree", "river"], "ponds": 0.9, "pond_size": Vector2(12.0, 28.0), "water_shallow": Color(0.36, 0.5, 0.36), "water_deep": Color(0.12, 0.2, 0.16), "valley_width": 20.0, "valley_height": 6.0, "undulation": 0.8, "path_depth": 0.1,
			"grass_dark": Color(0.26, 0.36, 0.12), "grass_light": Color(0.4, 0.48, 0.18),
			"region_dark": Color(0.3, 0.3, 0.16), "region_light": Color(0.42, 0.4, 0.22),
			"slope_color": Color(0.34, 0.36, 0.2), "path_color": Color(0.5, 0.44, 0.3), "crack": 0.2}),
		"atmosphere": atmosphere({"temperature": 10.0, "mountain_color": Color(0.45, 0.5, 0.48), "mountain_shadow": Color(0.45, 0.5, 0.52), "mountain_snow": 0.0, "mountain_scale": 0.6, "birds": false, "sun_dir": Vector3(0.3, -0.35, 0.85), "sun_color": Color(0.95, 0.9, 0.78), "sun_energy": 1.3,
			"ambient_energy": 0.6, "ambient_color": Color(0.6, 0.66, 0.6), "fog_color": Color(0.7, 0.76, 0.72),
			"fog_density": 0.009, "fog_sun_scatter": 0.3, "volumetric": 0.012, "saturation": 0.95,
			"zenith_color": Color(0.45, 0.6, 0.72), "horizon_color": Color(0.78, 0.84, 0.82), "cloud_coverage": 0.38,
			"cirrus_amount": 0.2, "cloud_shadow": Color(0.6, 0.64, 0.7), "particles": "motes",
			"particle_color": Color(0.8, 1.0, 0.5), "butterflies": 0}),
		"layers": [
			grass_layer([Color(0.4, 0.55, 0.16), Color(0.5, 0.6, 0.2), Color(0.35, 0.48, 0.14)],
				[Color(0.62, 0.55, 0.25), Color(0.45, 0.4, 0.18)], 2300.0, Vector2(0.5, 0.95)),
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
		],
	}


# ================================================================ 9 Sunset Coast

static func coast() -> Dictionary:
	var green := tree_style(Color(0.3, 0.5, 0.1), Color(0.85, 0.85, 0.3), {"tint": Color(0.95, 0.82, 0.75)}, 6.0, {"translucency": 1.0})
	var pine := tree_style(Color(0.12, 0.3, 0.12), Color(0.5, 0.62, 0.22), {"tint": Color(0.95, 0.82, 0.75)}, 8.0, {"sphere_normals": 0.55})
	var cliff := rock_style(Color(0.52, 0.58, 0.72), 0.45, true, {"moss_color": Color(0.55, 0.62, 0.2), "top_light": 0.5})
	var stack := rock_style(Color(0.4, 0.46, 0.62), 0.3, true, {"moss_color": Color(0.5, 0.58, 0.2), "top_light": 0.6, "triplanar_scale": 0.05})
	return {
		"name": NAMES[8],
		"blades": blades(0.55, Color(0.2, 0.34, 0.08), Color(0.72, 0.85, 0.22), Color(1.0, 0.8, 0.35)),
		"terrain": terrain({"litter": 0.0, "litter_color": Color(0.6, 0.5, 0.3), "far_height": 45.0, "obstacles": ["fallen_tree"], "coast": 1.0, "terraces": 6.0, "valley_width": 14.0, "valley_ramp": 60.0, "valley_height": 16.0,
			"undulation": 1.4, "grass_dark": Color(0.36, 0.5, 0.12), "grass_light": Color(0.62, 0.7, 0.2),
			"region_dark": Color(0.6, 0.6, 0.2), "region_light": Color(0.76, 0.7, 0.3),
			"slope_color": Color(0.5, 0.52, 0.66), "path_color": Color(0.78, 0.66, 0.46), "crack": 0.5,
			"water_shallow": Color(0.3, 0.7, 0.72), "water_deep": Color(0.06, 0.24, 0.42)}),
		"atmosphere": atmosphere({"sun_dir": Vector3(-0.5, -0.17, 0.85), "sun_color": Color(1.0, 0.7, 0.42), "sun_energy": 1.7,
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
				"grove": [0.025, -0.1], "scale": [1.2, 1.9], "radius": 3.0, "collide": "trunk", "trunk": 0.3},
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
		],
	}


# ================================================================ 10 Cliff Lands

static func cliffs() -> Dictionary:
	var round_tree := tree_style(Color(0.24, 0.52, 0.08), Color(0.7, 0.95, 0.3), {"tint": Color(0.95, 0.85, 0.8)}, 6.0,
		{"translucency": 0.9, "sphere_normals": 0.9})
	var deep := tree_style(Color(0.12, 0.38, 0.08), Color(0.45, 0.78, 0.2), {"tint": Color(0.95, 0.85, 0.8)}, 6.0, {"sphere_normals": 0.9})
	var rock := rock_style(Color(0.58, 0.63, 0.72), 0.55, false, {"moss_color": Color(0.5, 0.72, 0.2)})
	return {
		"name": NAMES[9],
		"blades": blades(0.75, Color(0.14, 0.36, 0.05), Color(0.62, 0.9, 0.2), Color(0.9, 0.95, 0.35)),
		"terrain": terrain({"litter": 0.2, "litter_color": Color(0.7, 0.55, 0.3), "far_height": 85.0, "obstacles": ["cliff", "cliff", "river"], "terraces": 9.0, "valley_width": 22.0, "valley_ramp": 85.0, "valley_height": 38.0, "undulation": 1.4,
			"grass_dark": Color(0.3, 0.56, 0.1), "grass_light": Color(0.55, 0.78, 0.16),
			"region_dark": Color(0.45, 0.66, 0.12), "region_light": Color(0.68, 0.82, 0.22),
			"slope_color": Color(0.54, 0.6, 0.7), "path_color": Color(0.78, 0.7, 0.5), "crack": 0.4, "ponds": 0.4}),
		"atmosphere": atmosphere({"sun_dir": Vector3(-0.35, -0.62, 0.7), "sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 1.9,
			"ambient_energy": 0.5, "ambient_color": Color(0.6, 0.75, 0.9), "zenith_color": Color(0.14, 0.45, 0.92),
			"horizon_color": Color(0.74, 0.88, 1.0), "cloud_coverage": 0.44, "cirrus_amount": 0.7, "fog_density": 0.0022,
			"saturation": 1.12, "rainbow": 0.5, "particles": "motes", "butterflies": 10, "temperature": 18.0,
			"mountain_color": Color(0.5, 0.6, 0.72), "mountain_shadow": Color(0.38, 0.46, 0.66), "mountain_snow": 0.55, "mountain_scale": 1.4}),
		"layers": [
			grass_layer([Color(0.5, 0.82, 0.16), Color(0.42, 0.74, 0.12), Color(0.62, 0.88, 0.22)],
				[Color(0.75, 0.9, 0.25), Color(0.55, 0.82, 0.18)], 2800.0, Vector2(0.55, 1.0)),
			{"kind": "tree", "models": COMMON, "styles": [round_tree, round_tree, deep], "spacing": 8.0, "chance": 0.85, "dist": [7.0, 400.0],
				"grove": [0.02, 0.05], "scale": [1.3, 2.1], "radius": 3.0, "collide": "trunk", "trunk": 0.32},
			hero_tree(["CommonTree_1", "CommonTree_3"], round_tree, Vector2(4.5, 5.5)),
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 26.0, "chance": 0.35, "dist": [6.0, 60.0],
				"scale": [1.2, 3.4], "sink": 0.2, "radius": 3.0, "collide": "rock"},
			{"kind": "detail", "models": ["Bush_Common", "Bush_Common_Flowers"], "styles": [{"leaves": leaves(Color(0.2, 0.48, 0.08), Color(0.6, 0.88, 0.22), {"sphere_normals": 0.9}), "stiffness": 6.0}],
				"density": 3.0, "dist": [4.0, 40.0], "scale": [1.0, 1.8], "shadows": true, "vis": 130.0, "near": true, "tilt": 0.3},
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single", "Flower_3_Group"], "styles": [{}], "density": 2.5,
				"dist": [2.5, 45.0], "count": 24, "radius": 4.0, "scale": [0.45, 0.8],
				"tints": [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 0.65, 1.0)], "vis": 75.0, "near": true, "tilt": 0.8},
			pebble_layer(rock_style(Color(0.74, 0.76, 0.8), 0.0, false, {"top_light": 0.3}), 18.0),
		],
	}


# ================================================================ 11 Glowing Forest

static func glow() -> Dictionary:
	var teal := tree_style(Color(0.08, 0.36, 0.4), Color(0.45, 0.92, 0.78), {"tint": Color(0.7, 0.72, 0.9)}, 7.0, {"translucency": 1.2})
	var violet := tree_style(Color(0.3, 0.2, 0.5), Color(0.9, 0.62, 0.9), {"tint": Color(0.7, 0.72, 0.9)}, 7.0, {"translucency": 1.2})
	var shroom := {"mushroom_tint": Color(0.42, 0.62, 0.85), "mushroom_glow": Color(0.12, 0.45, 0.6)}
	var rock := rock_style(Color(0.42, 0.45, 0.6), 0.5, false, {"moss_color": Color(0.2, 0.55, 0.55)})
	return {
		"name": NAMES[10],
		"blades": blades(0.5, Color(0.04, 0.16, 0.2), Color(0.25, 0.7, 0.65), Color(0.45, 0.5, 0.95)),
		"terrain": terrain({"litter": 0.45, "litter_color": Color(0.3, 0.75, 0.72), "far_height": 50.0, "valley_width": 14.0, "valley_height": 12.0, "undulation": 1.3, "ponds": 0.5,
			"grass_dark": Color(0.14, 0.34, 0.34), "grass_light": Color(0.3, 0.58, 0.52),
			"region_dark": Color(0.2, 0.2, 0.38), "region_light": Color(0.3, 0.3, 0.5),
			"slope_color": Color(0.38, 0.4, 0.55), "path_color": Color(0.66, 0.6, 0.66), "crack": 0.2,
			"water_shallow": Color(0.18, 0.55, 0.7), "water_deep": Color(0.04, 0.12, 0.3)}),
		"atmosphere": atmosphere({"sun_dir": Vector3(0.4, -0.2, 0.9), "sun_color": Color(1.0, 0.7, 0.75), "sun_energy": 1.45,
			"ambient_energy": 0.6, "ambient_color": Color(0.5, 0.55, 0.85), "fog_color": Color(0.55, 0.5, 0.8),
			"fog_density": 0.004, "fog_sun_scatter": 0.5, "volumetric": 0.008, "saturation": 1.05, "exposure": 1.0,
			"zenith_color": Color(0.16, 0.2, 0.48), "horizon_color": Color(0.95, 0.62, 0.7), "cloud_coverage": 0.55,
			"cirrus_amount": 0.4, "cloud_shadow": Color(0.35, 0.3, 0.55), "sun_glow": 0.8,
			"particles": "fireflies", "particle_color": Color(0.6, 1.0, 0.5), "butterflies": 0, "birds": false, "temperature": 13.0,
			"mountain_color": Color(0.25, 0.25, 0.45), "mountain_shadow": Color(0.18, 0.18, 0.38), "mountain_snow": 0.0}),
		"layers": [
			grass_layer([Color(0.2, 0.62, 0.6), Color(0.15, 0.5, 0.55), Color(0.3, 0.7, 0.65)],
				[Color(0.45, 0.45, 0.9), Color(0.35, 0.6, 0.85)], 2200.0, Vector2(0.45, 0.9)),
			{"kind": "tree", "models": TWISTED, "styles": [teal, teal, violet], "spacing": 13.0, "chance": 0.75, "dist": [6.0, 400.0],
				"scale": [0.5, 0.8], "radius": 5.0, "collide": "trunk", "trunk": 0.45},
			hero_tree(["TwistedTree_3", "TwistedTree_1"], teal, Vector2(1.6, 2.0)),
			{"kind": "rock", "models": ROCKS, "styles": [rock], "spacing": 30.0, "chance": 0.3, "dist": [6.0, 40.0],
				"scale": [1.0, 2.4], "sink": 0.2, "radius": 2.5, "collide": "rock"},
			cluster_layer(["Mushroom_Common", "Mushroom_Common", "Mushroom_Laetiporus"], 2.2, [2.0, 25.0], 6, 1.2, [0.8, 1.5], false, shroom),
			{"kind": "cluster", "models": ["Flower_3_Single", "Flower_4_Single"], "styles": [{}], "density": 2.0, "dist": [2.5, 35.0],
				"count": 12, "radius": 2.5, "scale": [0.45, 0.75], "tints": [Color(0.4, 0.9, 1.0), Color(0.8, 0.5, 1.0)],
				"vis": 70.0, "near": true, "tilt": 0.8},
			cluster_layer(["Fern_1"], 1.0, [2.5, 30.0], 2, 1.5, [0.3, 0.45], true, {"plant": {"texture_tint": Color(0.5, 1.0, 1.1)}}),
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
		"terrain": terrain({"litter": 0.3, "litter_color": Color(0.78, 0.62, 0.3), "far_height": 30.0, "obstacles": ["river", "river", "fallen_tree"], "valley_width": 30.0, "valley_ramp": 90.0, "valley_height": 10.0, "undulation": 1.2,
			"ponds": 1.0, "pond_size": Vector2(22.0, 42.0),
			"grass_dark": Color(0.3, 0.52, 0.12), "grass_light": Color(0.52, 0.72, 0.2),
			"region_dark": Color(0.45, 0.6, 0.18), "region_light": Color(0.62, 0.74, 0.26),
			"path_color": Color(0.76, 0.68, 0.5), "crack": 0.3,
			"water_shallow": Color(0.4, 0.82, 0.8), "water_deep": Color(0.08, 0.35, 0.52)}),
		"atmosphere": atmosphere({"sun_dir": Vector3(0.45, -0.45, 0.75), "sun_color": Color(1.0, 0.92, 0.82), "sun_energy": 1.7,
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
		"terrain": terrain({"litter": 0.1, "litter_color": Color(0.6, 0.46, 0.8), "far_height": 40.0, "obstacles": ["fallen_tree"],
			"valley_width": 30.0, "valley_ramp": 110.0, "valley_height": 14.0, "undulation": 1.8,
			"grass_dark": Color(0.42, 0.52, 0.16), "grass_light": Color(0.68, 0.7, 0.3),
			"region_dark": Color(0.5, 0.46, 0.4), "region_light": Color(0.66, 0.6, 0.36),
			"slope_color": Color(0.8, 0.74, 0.62), "path_color": Color(0.9, 0.84, 0.68), "crack": 0.6}),
		"atmosphere": atmosphere({"sun_dir": Vector3(0.55, -0.5, 0.65), "sun_color": Color(1.0, 0.9, 0.74), "sun_energy": 1.9,
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
		"terrain": terrain({"litter": 0.55, "litter_color": Color(0.96, 0.78, 0.22), "far_height": 45.0,
			"obstacles": ["fallen_tree", "river", "fallen_tree"], "ponds": 0.25, "path_width": 2.8,
			"valley_width": 14.0, "valley_ramp": 70.0, "valley_height": 12.0, "undulation": 1.3,
			"grass_dark": Color(0.36, 0.52, 0.12), "grass_light": Color(0.62, 0.72, 0.2),
			"region_dark": Color(0.62, 0.6, 0.18), "region_light": Color(0.78, 0.7, 0.28),
			"path_color": Color(0.72, 0.62, 0.44), "slope_color": Color(0.5, 0.52, 0.3), "crack": 0.5}),
		"atmosphere": atmosphere({"sun_dir": Vector3(-0.4, -0.55, 0.72), "sun_color": Color(1.0, 0.94, 0.82), "sun_energy": 1.8,
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
		"terrain": terrain({"litter": 0.0, "litter_color": Color(0.5, 0.4, 0.3), "far_height": 70.0, "obstacles": ["river", "cliff"],
			"ponds": 0.45, "pond_size": Vector2(10.0, 22.0), "water_shallow": Color(0.42, 0.6, 0.62), "water_deep": Color(0.1, 0.22, 0.3),
			"valley_width": 40.0, "valley_ramp": 140.0, "valley_height": 24.0, "undulation": 2.6, "roughness": 0.6,
			"grass_dark": Color(0.36, 0.42, 0.2), "grass_light": Color(0.56, 0.58, 0.3),
			"region_dark": Color(0.46, 0.32, 0.42), "region_light": Color(0.6, 0.44, 0.52),
			"slope_color": Color(0.56, 0.56, 0.54), "path_color": Color(0.62, 0.56, 0.46), "crack": 0.3}),
		"atmosphere": atmosphere({"sun_dir": Vector3(0.3, -0.38, 0.8), "sun_color": Color(0.96, 0.93, 0.9), "sun_energy": 1.35,
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
		],
	}
