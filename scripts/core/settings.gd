extends Node
## Quality and game settings (autoload "Settings").
## Applies viewport/renderer settings itself; environment, light and world
## react via the `changed` signal.

signal changed(key: String)

const PATH := "user://settings.cfg"
const PRESET_NAMES := ["Low", "Medium", "High", "Ultra", "Extreme"]

const PRESETS := {
	"Low": {"render_scale": 0.67, "aa": 1, "shadows": 1, "ssao": false, "volumetric": false, "glow": false, "sun_shafts": false, "lod": 6.0, "grass_blades": 0, "film_look": false, "ssil": false, "dof": false,
		"view_distance": 4, "veg_density": 0.45, "grass_distance": 35.0, "blade_range": 1.0, "shadow_range": 1.0, "impostor_distance": 140.0},
	"Medium": {"render_scale": 0.85, "aa": 1, "shadows": 2, "ssao": true, "volumetric": false, "glow": true, "sun_shafts": true, "lod": 4.0, "grass_blades": 0, "film_look": false, "ssil": false, "dof": false,
		"view_distance": 5, "veg_density": 0.6, "grass_distance": 45.0, "blade_range": 1.0, "shadow_range": 1.0, "impostor_distance": 160.0},
	"High": {"render_scale": 1.0, "aa": 2, "shadows": 3, "ssao": true, "volumetric": true, "glow": true, "sun_shafts": true, "lod": 2.0, "grass_blades": 1, "film_look": true, "ssil": false, "dof": false,
		"view_distance": 7, "veg_density": 1.0, "grass_distance": 65.0, "blade_range": 1.0, "shadow_range": 1.0, "impostor_distance": 180.0},
	"Ultra": {"render_scale": 1.0, "aa": 3, "shadows": 4, "ssao": true, "volumetric": true, "glow": true, "sun_shafts": true, "lod": 1.0, "grass_blades": 3, "film_look": true, "ssil": true, "dof": true,
		"view_distance": 9, "veg_density": 1.3, "grass_distance": 85.0, "blade_range": 1.0, "shadow_range": 1.0, "impostor_distance": 240.0},
	# for strong GPUs: everything further away and denser
	"Extreme": {"render_scale": 1.0, "aa": 3, "shadows": 4, "ssao": true, "volumetric": true, "glow": true, "sun_shafts": true, "lod": 0.5, "grass_blades": 3, "film_look": true, "ssil": true, "dof": true,
		"view_distance": 16, "veg_density": 1.7, "grass_distance": 150.0, "blade_range": 1.6, "shadow_range": 1.8, "impostor_distance": 320.0},
}

# aa: 0 off, 1 FXAA, 2 MSAA 2×, 3 MSAA 4×, 4 TAA
# shadows: 0 off, 1 low, 2 medium, 3 high, 4 ultra
var values := {
	"preset": "Medium",
	"render_scale": 0.8,
	"dynamic_res": false,
	"target_fps": 45,
	"aa": 2,
	"shadows": 2,
	"ssao": true,
	"volumetric": false,
	"glow": true,
	"sun_shafts": true,
	"lod": 4.0,
	"grass_blades": 0,
	"film_look": false,
	"outlines": false,
	"ssil": false,
	"dof": false,
	"view_distance": 5,
	"veg_density": 0.7,
	"grass_distance": 50.0,
	"blade_range": 1.0,         # multiplier for the grass blade carpet radius
	"shadow_range": 1.0,        # multiplier for the sun shadow distance
	"upscaler": 0,              # below 100 % resolution: 0 FSR 1, 1 FSR 2 (temporal), 2 bilinear
	"fps_limit": 0,
	"vsync": true,
	"fov": 70.0,
	"mouse_sens": 1.0,
	"wind_fx": true,
	"particles": true,
	"footprints": true,
	"fullscreen": false,
	"show_fps": false,
	"last_seed": 1,
	# Performance optimizations (all can be turned off, default: on)
	"opt_cells": true,          # batch plants in small cells (more precise culling)
	"opt_far_batch": true,      # distant chunks: one batch per chunk
	"opt_opaque_grass": true,   # grass tufts without alpha test
	"opt_small_noshadow": true, # pebbles, mushrooms, small stones without shadows
	"opt_far_trees": true,      # distant trees with thinned-out leaf cards
	"opt_shafts_16": true,      # sun shafts with 16 instead of 24 samples
	"opt_shadow_filter": true,  # Ultra: shadow filter "medium" instead of "high"
	"opt_blade_budget": true,   # build grass blade tiles with a time budget
	"opt_foliage_noaniso": true, # leaf masks without anisotropic filtering
	"opt_music_thread": true,   # load music in the background
	"opt_tree_shadow_lod": true, # trees farther than 45 m cast shadows with their simplified far crown
	"opt_tree_lod": true,       # trees farther than 75 m are drawn with the simplified far crown
	"impostors": true,          # distant trees as pre-rendered billboards (baked in the background)
	"impostor_distance": 180.0, # from here on trees hand over to their impostors (never inside the shadows)
	"music": true,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"time_of_day": 0,           # 0 day cycle, 1 morning, 2 midday, 3 golden hour, 4 dusk, 5 night
	"day_minutes": 36.0,        # real minutes for a whole day
	"weather": 0,               # 0 changing, 1 always fair, 2 always rain
	"scout": {},                # look of your scout (see Scout.DEFAULT_LOOK)
	"third_person": false,
	"emote_wheel": [],          # 8 emote ids for the wheel (empty = Scout.DEFAULT_WHEEL)
	"emote_camera": true,       # first person: show the emote from behind while it plays
	"voice_enabled": false,     # local microphone test (nothing is sent)
	"voice_device": "Default",
	"voice_mode": 2,            # 0 push to talk (T), 1 always on, 2 voice activation
	"voice_threshold": -38.0,   # dB for voice activation
	"voice_monitor": false,     # hear your own microphone
	"voice_lipsync": true,      # your scout's mouth follows your voice
}

## On scene reload: generate this world and start hiking right away
var next_seed := -1
var autostart := false

## Current dynamic scale (0..1, relative to render_scale)
var dynamic_factor := 1.0
## false = don't save changes (for test runs from the command line)
var persist := true
var _perf_start := 0
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_old_user_dir()
	if not _load():
		# First start: weaker GPUs get "Medium", others "High".
		var integrated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
		apply_preset("Medium" if integrated else "High", false)
	apply_all()


func get_value(key: String):
	return values[key]


## Seed from an input: a number stays a number, text ("Sunny Valley") is hashed into a number
static func parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t.is_valid_int():
		return absi(t.to_int()) % 2147483647
	if t == "":
		return 1
	return hash(t) & 0x7fffffff


func set_value(key: String, v, mark_custom := true) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	if mark_custom and PRESETS["High"].has(key):
		values["preset"] = "Custom"
	_apply(key)
	changed.emit(key)
	save()


func apply_preset(preset: String, emit := true) -> void:
	if not PRESETS.has(preset):
		return
	values["preset"] = preset
	for k in PRESETS[preset]:
		values[k] = PRESETS[preset][k]
	if emit:
		apply_all()
		for k in PRESETS[preset]:
			changed.emit(k)
		changed.emit("preset")
		save()


func apply_all() -> void:
	for k in values:
		_apply(k)


func _apply(key: String) -> void:
	var vp := get_viewport()
	match key:
		"render_scale", "dynamic_res", "upscaler":
			dynamic_factor = 1.0
			_apply_scale()
		"aa":
			var aa: int = values["aa"]
			vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = aa == 4
		"shadows", "opt_shadow_filter":
			var q: int = values["shadows"]
			var size: int = [1024, 2048, 2048, 4096, 4096][q]
			RenderingServer.directional_shadow_atlas_set_size(size, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(
				[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
				RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
				RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if values["opt_shadow_filter"] else RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
		"fps_limit":
			Engine.max_fps = values["fps_limit"]
		"lod":
			vp.mesh_lod_threshold = values["lod"]
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_scale() -> void:
	var vp := get_viewport()
	var s: float = values["render_scale"] * dynamic_factor
	vp.scaling_3d_scale = s
	# above 100 %: supersampling; below: the chosen upscaler (FSR 2 also smooths edges over time)
	var up: int = values["upscaler"]
	if s > 1.01 or s >= 0.99:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	else:
		vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_BILINEAR][up]
	vp.fsr_sharpness = 0.4


## Dynamic resolution: keeps the target frame rate by rendering smaller internally.
func _process(_delta: float) -> void:
	if not values["dynamic_res"]:
		return
	# measure real time (independent of Engine.time_scale and pause)
	var now := Time.get_ticks_msec()
	if _perf_start == 0:
		_perf_start = now
	_frames += 1
	var elapsed := (now - _perf_start) / 1000.0
	if elapsed < 1.5:
		return
	var fps := _frames / elapsed
	_perf_start = now
	_frames = 0
	var target: float = values["target_fps"]
	var f := dynamic_factor
	if fps < target * 0.92 and values["render_scale"] * f > 0.5:
		f -= 0.07
	elif fps > target * 1.25 and f < 1.0:
		f += 0.05
	f = clampf(f, 0.5 / maxf(values["render_scale"], 0.5), 1.0)
	if not is_equal_approx(f, dynamic_factor):
		dynamic_factor = f
		_apply_scale()


func shadow_params() -> Dictionary:
	var q: int = values["shadows"]
	return [
		{"enabled": false, "distance": 0.0, "splits": 2},
		{"enabled": true, "distance": 45.0, "splits": 2},
		{"enabled": true, "distance": 70.0, "splits": 4},
		{"enabled": true, "distance": 90.0, "splits": 4},
		{"enabled": true, "distance": 130.0, "splits": 4},
	][q].merged({"distance": [0.0, 45.0, 70.0, 90.0, 130.0][q] * float(values["shadow_range"])}, true)


func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.set_value("meta", "version", VERSION)
	cfg.save(PATH)


const VERSION := 2


## The game used to be called "Fernweh": take over settings and records from the old save folder once.
func _migrate_old_user_dir() -> void:
	var old_dir := OS.get_user_data_dir().get_base_dir().path_join("Fernweh")
	for f in ["settings.cfg", "records.cfg"]:
		var src := old_dir.path_join(f)
		if FileAccess.file_exists(src) and not FileAccess.file_exists("user://" + f):
			DirAccess.copy_absolute(src, OS.get_user_data_dir().path_join(f))


func _load() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	for k in values:
		values[k] = cfg.get_value("settings", k, values[k])
	# old German preset names
	var renamed := {"Niedrig": "Low", "Mittel": "Medium", "Hoch": "High", "Benutzerdefiniert": "Custom"}
	values["preset"] = renamed.get(values["preset"], values["preset"])
	# Version 2: dynamic resolution is off by default (one-time migration)
	if int(cfg.get_value("meta", "version", 1)) < 2:
		values["dynamic_res"] = false
		if persist:
			save()
	return true
