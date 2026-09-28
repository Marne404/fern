class_name Weather
extends RefCounted
## Changing weather: fair → clouding over → a shower → clearing up (with a rainbow when the sun is up) → fair.
## The ground stays wet for a while afterwards. How often it rains depends on the biome ("rain" in the
## atmosphere: 0 in the desert, often in the highlands). Setting: changing / always fair / always rainy.

enum { FAIR, BUILDING, RAIN, CLEARING, AFTER, FOG }
const BUILD_TIME := 45.0
const CLEAR_TIME := 35.0
const AFTER_TIME := 80.0

var state := FAIR
var mode := 0              # 0 changing, 1 always fair, 2 always rain
var rain := 0.0            # current rain intensity 0..1
var clouds := 0.0          # how overcast 0..1
var wet := 0.0             # wetness of the ground 0..1
var rainbow := 0.0
var fog := 0.0             # fog day 0..1
var snow_share := 0.0      # how much of the precipitation falls as snow (the biome decides)
var snow_cover := 0.0      # snow lying on the ground 0..1
var flash := 0.0           # heat lightning: brightness of the current flash
var flash_dir := Vector2(0, -1)
var _flash_t := 6.0
var _flash_seq: Array = [] # upcoming flicker times of the current flash
var _t := 0.0
var _dur := 0.0
var _strength := 0.8
## seconds (scaled by the biome's rain chance) until the next shower starts to build up
var next_shower := 300.0
## seconds (scaled by the biome's fog chance) until the next fog day
var next_fog := 600.0


func reset() -> void:
	state = FAIR
	rain = 0.0
	clouds = 0.0
	wet = 0.0
	rainbow = 0.0
	fog = 0.0
	snow_cover = 0.0
	# the first shower comes after a while, not right at the start
	next_shower = randf_range(300.0, 540.0)
	next_fog = randf_range(420.0, 900.0)


## chance: the biome's rain factor (0 = never); fog_chance: how often fog days come; share: the part that
## falls as snow. Returns true when a shower begins (for a message).
func advance(dt: float, chance: float, fog_chance := 0.0, share := 0.0) -> bool:
	var began := false
	_t += dt
	snow_share = move_toward(snow_share, share, dt / 20.0)
	if mode == 1:
		state = FAIR
	elif mode == 2 and state in [FAIR, AFTER, CLEARING]:
		_enter(BUILDING)
	# in the desert a shower dissolves
	if chance <= 0.0 and state in [BUILDING, RAIN]:
		_enter(CLEARING)
	match state:
		FAIR:
			next_shower -= dt * chance
			next_fog -= dt * fog_chance
			if next_shower <= 0.0 and mode == 0:
				_enter(BUILDING)
			elif next_fog <= 0.0 and mode == 0:
				_enter(FOG)
				_dur = randf_range(240.0, 480.0)
		FOG:
			if _t >= _dur or fog_chance <= 0.0:
				_enter(FAIR)
				next_fog = randf_range(900.0, 1800.0)
				next_shower = maxf(next_shower, 120.0)
		BUILDING:
			if _t >= BUILD_TIME:
				_enter(RAIN)
				_strength = 1.0 if mode == 2 else randf_range(0.45, 1.0)
				_dur = randf_range(70.0, 160.0)
				began = true
		RAIN:
			if _t >= _dur and mode != 2:
				_enter(CLEARING)
		CLEARING:
			if _t >= CLEAR_TIME:
				_enter(AFTER)
		AFTER:
			if _t >= AFTER_TIME:
				_enter(FAIR)
				next_shower = randf_range(420.0, 900.0)
	var target_clouds: float = {FAIR: 0.0, BUILDING: clampf(_t / BUILD_TIME, 0.0, 1.0), RAIN: 1.0,
		CLEARING: lerpf(1.0, 0.25, clampf(_t / CLEAR_TIME, 0.0, 1.0)), AFTER: lerpf(0.25, 0.0, clampf(_t / AFTER_TIME, 0.0, 1.0)), FOG: 0.2}[state]
	fog = move_toward(fog, 1.0 if state == FOG else 0.0, dt / 40.0)
	clouds = move_toward(clouds, target_clouds, dt / 20.0)
	var target_rain := _strength if state == RAIN else 0.0
	rain = move_toward(rain, target_rain, dt / (6.0 if target_rain > rain else 10.0))
	# the ground soaks up quickly and dries slowly; snow settles and melts over a few minutes
	var rain_part := rain * (1.0 - snow_share)
	var snow_part := rain * snow_share
	if rain_part > 0.05:
		wet = minf(wet + dt * rain_part / 35.0, 1.0)
	elif fog > 0.3:
		wet = move_toward(wet, 0.35, dt / 120.0)
	else:
		wet = maxf(wet - dt / 170.0, 0.0)
	if snow_part > 0.05:
		snow_cover = minf(snow_cover + dt * snow_part / 50.0, 1.0)
	else:
		snow_cover = maxf(snow_cover - dt / (240.0 if share > 0.5 else 120.0), 0.0)
	var rb := 0.0
	if snow_share > 0.5:
		rb = 0.0
	elif state == AFTER:
		rb = sin(clampf(_t / AFTER_TIME, 0.0, 1.0) * PI)
	elif state == CLEARING:
		rb = clampf(_t / CLEAR_TIME, 0.0, 1.0) * 0.4
	rainbow = move_toward(rainbow, rb, dt / 8.0)
	return began


## Heat lightning on warm, clear evenings: silent double flickers in distant clouds.
## amount: the biome's heat lightning × how warm and clear it is × time of day (0 = none)
func advance_flash(dt: float, amount: float) -> void:
	flash = move_toward(flash, 0.0, dt * 9.0)
	if not _flash_seq.is_empty():
		_flash_seq[0] = float(_flash_seq[0]) - dt
		if float(_flash_seq[0]) <= 0.0:
			flash = randf_range(0.55, 1.0)
			_flash_seq.pop_front()
		return
	if amount <= 0.01:
		return
	_flash_t -= dt * amount
	if _flash_t <= 0.0:
		_flash_t = randf_range(4.0, 15.0)
		var a := randf_range(-2.4, 2.4)
		flash_dir = Vector2(sin(a), -cos(a))
		_flash_seq = [0.0, randf_range(0.08, 0.16)]
		if randf() < 0.5:
			_flash_seq.append(randf_range(0.25, 0.45))


func _enter(s: int) -> void:
	state = s
	_t = 0.0


func is_raining() -> bool:
	return rain > 0.08


## The (time-of-day-adjusted) atmosphere bent to the weather: grayer, more clouds, weaker sun.
func apply(c: Dictionary) -> Dictionary:
	c["overcast"] = maxf(clouds, fog * 0.5)
	c["snow"] = rain * snow_share
	c["snow_cover"] = snow_cover
	if fog > 0.001:
		_apply_fog(c)
	if clouds <= 0.001 and rainbow <= 0.001 and wet <= 0.001:
		c["rain"] = 0.0
		c["wet"] = 0.0
		return c
	var k := clouds
	var o := c
	o["cloud_coverage"] = lerpf(c["cloud_coverage"], 0.14, k)
	o["cirrus_amount"] = float(c["cirrus_amount"]) * (1.0 - k)
	o["sun_energy"] = float(c["sun_energy"]) * lerpf(1.0, 0.18, k)
	o["sun_glow"] = float(c["sun_glow"]) * lerpf(1.0, 0.3, k)
	o["zenith_color"] = _gray(c["zenith_color"], k * 0.75, 0.9)
	o["horizon_color"] = _gray(c["horizon_color"], k * 0.6, 0.95)
	o["fog_color"] = _gray(c["fog_color"], k * 0.6, 0.95)
	o["fog_density"] = float(c["fog_density"]) + k * 0.002
	o["cloud_color"] = _gray(c.get("cloud_color", Color.WHITE), k * 0.8, 0.82)
	o["cloud_shadow"] = _gray(c["cloud_shadow"], k * 0.7, 0.7)
	o["ambient_color"] = _gray(c["ambient_color"], k * 0.35, 1.0)
	o["ambient_energy"] = float(c["ambient_energy"]) * lerpf(1.0, 1.25, k)
	o["saturation"] = float(c.get("saturation", 1.0)) * lerpf(1.0, 0.88, k)
	# a rainbow needs the sun: not at night
	o["rainbow"] = maxf(float(c.get("rainbow", 0.0)), rainbow * (1.0 - float(c.get("night", 0.0))) * float(c.get("moon", 0.0) < 0.5) * 1.2)
	o["mist"] = float(c.get("mist", 0.0)) + wet * (1.0 - k) * 0.25
	o["temperature"] = float(c.get("temperature", 16.0)) - 3.0 * k
	o["rain"] = rain * (1.0 - snow_share)
	o["wet"] = wet
	return o


## A fog day: white valley fog all day, the far land fading, the sun a pale disc, colors muted
func _apply_fog(c: Dictionary) -> void:
	var f := fog
	var fc: Color = (c["fog_color"] as Color).lerp(Color(0.86, 0.88, 0.9), 0.5)
	c["fog_color"] = (c["fog_color"] as Color).lerp(fc, f)
	c["fog_density"] = float(c["fog_density"]) + f * 0.0075
	c["mist"] = maxf(float(c.get("mist", 0.0)), f * 0.95)
	c["sun_energy"] = float(c["sun_energy"]) * lerpf(1.0, 0.5, f)
	c["sun_glow"] = float(c["sun_glow"]) * lerpf(1.0, 1.6, f)
	c["horizon_color"] = (c["horizon_color"] as Color).lerp(fc, f * 0.8)
	c["zenith_color"] = _gray(c["zenith_color"], f * 0.5, 1.0)
	c["saturation"] = float(c.get("saturation", 1.0)) * lerpf(1.0, 0.9, f)
	c["ambient_energy"] = float(c["ambient_energy"]) * lerpf(1.0, 1.15, f)
	c["temperature"] = float(c.get("temperature", 16.0)) - 2.0 * f


static func _gray(col: Color, amount: float, dark: float) -> Color:
	var l := col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	return col.lerp(Color(l * 0.96, l, l * 1.08) * dark, amount)
