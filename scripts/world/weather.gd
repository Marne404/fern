class_name Weather
extends RefCounted
## Changing weather: fair → clouding over → a shower → clearing up (with a rainbow when the sun is up) → fair.
## The ground stays wet for a while afterwards. How often it rains depends on the biome ("rain" in the
## atmosphere: 0 in the desert, often in the highlands). Setting: changing / always fair / always rainy.

enum { FAIR, BUILDING, RAIN, CLEARING, AFTER }
const BUILD_TIME := 45.0
const CLEAR_TIME := 35.0
const AFTER_TIME := 80.0

var state := FAIR
var mode := 0              # 0 changing, 1 always fair, 2 always rain
var rain := 0.0            # current rain intensity 0..1
var clouds := 0.0          # how overcast 0..1
var wet := 0.0             # wetness of the ground 0..1
var rainbow := 0.0
var _t := 0.0
var _dur := 0.0
var _strength := 0.8
## seconds (scaled by the biome's rain chance) until the next shower starts to build up
var next_shower := 300.0


func reset() -> void:
	state = FAIR
	rain = 0.0
	clouds = 0.0
	wet = 0.0
	rainbow = 0.0
	# the first shower comes after a while, not right at the start
	next_shower = randf_range(300.0, 540.0)


## chance: the biome's rain factor (0 = never). Returns true when a shower begins (for a message).
func advance(dt: float, chance: float) -> bool:
	var began := false
	_t += dt
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
			if next_shower <= 0.0 and mode == 0:
				_enter(BUILDING)
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
		CLEARING: lerpf(1.0, 0.25, clampf(_t / CLEAR_TIME, 0.0, 1.0)), AFTER: lerpf(0.25, 0.0, clampf(_t / AFTER_TIME, 0.0, 1.0))}[state]
	clouds = move_toward(clouds, target_clouds, dt / 20.0)
	var target_rain := _strength if state == RAIN else 0.0
	rain = move_toward(rain, target_rain, dt / (6.0 if target_rain > rain else 10.0))
	# the ground soaks up quickly and dries slowly
	if rain > 0.05:
		wet = minf(wet + dt * rain / 35.0, 1.0)
	else:
		wet = maxf(wet - dt / 170.0, 0.0)
	var rb := 0.0
	if state == AFTER:
		rb = sin(clampf(_t / AFTER_TIME, 0.0, 1.0) * PI)
	elif state == CLEARING:
		rb = clampf(_t / CLEAR_TIME, 0.0, 1.0) * 0.4
	rainbow = move_toward(rainbow, rb, dt / 8.0)
	return began


func _enter(s: int) -> void:
	state = s
	_t = 0.0


func is_raining() -> bool:
	return rain > 0.08


## The (time-of-day-adjusted) atmosphere bent to the weather: grayer, more clouds, weaker sun.
func apply(c: Dictionary) -> Dictionary:
	c["overcast"] = clouds
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
	o["rain"] = rain
	o["wet"] = wet
	return o


static func _gray(col: Color, amount: float, dark: float) -> Color:
	var l := col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	return col.lerp(Color(l * 0.96, l, l * 1.08) * dark, amount)
