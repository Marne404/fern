class_name DayCycle
extends RefCounted
## Times of day. The biomes define how the world looks by day; the clock bends that look towards dawn,
## morning, golden hour, dusk and a short, moonlit night. The sun keeps each biome's own direction (its
## composition) around midday and swings ±55° over the day; it rises and sets along that path.

## Real minutes for a whole day. The night passes quicker than the day (a fifth of the cycle).
var day_minutes := 36.0
## Hour of the day (0..24)
var hour := 7.0
## 0 = runs, else fixed: 1 morning, 2 midday, 3 golden hour, 4 dusk, 5 night
var fixed := 0

const SUNRISE := 5.6
const SUNSET := 19.6
const FIXED_HOURS := [0.0, 7.2, 12.5, 17.6, 19.95, 23.0]

# Key moods. Colors are targets the biome's own colors are pulled towards (by the weight *_w).
#   sun: tint of the sun/moon light, e: light energy factor, zen/hor: sky, amb: ambient factor + tint,
#   fog: haze color, cloud/shade: cloud color and cloud shadow color, exp: exposure factor,
#   stars, mist (valley fog), flies (fireflies)
const KEYS := [
	[0.0, {"sun": Color(0.55, 0.68, 1.0), "e": 0.32, "zen": Color(0.03, 0.055, 0.15), "zen_w": 0.94, "hor": Color(0.11, 0.17, 0.33), "hor_w": 0.9,
		"amb": 0.6, "amb_c": Color(0.4, 0.52, 0.95), "amb_w": 0.85, "fog": Color(0.1, 0.15, 0.3), "fog_w": 0.9,
		"cloud": Color(0.34, 0.4, 0.58), "shade": Color(0.1, 0.13, 0.24), "exp": 1.15, "stars": 1.0, "mist": 0.35, "flies": 1.0, "glow": 0.0}],
	[4.6, "night"],
	[5.25, {"sun": Color(0.9, 0.6, 0.62), "e": 0.0, "zen": Color(0.16, 0.2, 0.44), "zen_w": 0.8, "hor": Color(0.96, 0.66, 0.58), "hor_w": 0.8,
		"amb": 0.65, "amb_c": Color(0.72, 0.64, 0.86), "amb_w": 0.55, "fog": Color(0.66, 0.6, 0.72), "fog_w": 0.72,
		"cloud": Color(0.98, 0.72, 0.72), "shade": Color(0.42, 0.38, 0.6), "exp": 1.15, "stars": 0.35, "mist": 1.0, "flies": 0.25, "glow": 0.2}],
	[6.1, {"sun": Color(1.0, 0.56, 0.4), "e": 0.62, "zen": Color(0.3, 0.42, 0.74), "zen_w": 0.6, "hor": Color(1.0, 0.74, 0.56), "hor_w": 0.75,
		"amb": 0.78, "amb_c": Color(0.92, 0.74, 0.74), "amb_w": 0.4, "fog": Color(0.96, 0.8, 0.72), "fog_w": 0.6,
		"cloud": Color(1.0, 0.8, 0.7), "shade": Color(0.62, 0.5, 0.66), "exp": 1.05, "stars": 0.0, "mist": 1.0, "flies": 0.0, "glow": 0.8}],
	[7.6, {"sun": Color(1.0, 0.87, 0.72), "e": 0.9, "zen": Color(0.36, 0.6, 0.92), "zen_w": 0.2, "hor": Color(0.97, 0.92, 0.86), "hor_w": 0.35,
		"amb": 0.92, "amb_c": Color(0.95, 0.9, 0.88), "amb_w": 0.2, "fog": Color(0.92, 0.92, 0.94), "fog_w": 0.35,
		"cloud": Color(1.0, 0.97, 0.93), "shade": Color(0.66, 0.7, 0.84), "exp": 1.0, "stars": 0.0, "mist": 0.75, "flies": 0.0, "glow": 0.5}],
	[9.8, "day"],
	[15.4, "day"],
	[17.6, {"sun": Color(1.0, 0.72, 0.44), "e": 1.0, "zen": Color(0.3, 0.5, 0.86), "zen_w": 0.3, "hor": Color(1.0, 0.8, 0.55), "hor_w": 0.7,
		"amb": 0.85, "amb_c": Color(1.0, 0.82, 0.6), "amb_w": 0.45, "fog": Color(1.0, 0.84, 0.62), "fog_w": 0.6,
		"cloud": Color(1.0, 0.87, 0.68), "shade": Color(0.72, 0.58, 0.68), "exp": 1.0, "stars": 0.0, "mist": 0.0, "flies": 0.0, "glow": 1.0}],
	[19.25, {"sun": Color(1.0, 0.5, 0.32), "e": 0.58, "zen": Color(0.26, 0.33, 0.64), "zen_w": 0.6, "hor": Color(1.0, 0.56, 0.42), "hor_w": 0.8,
		"amb": 0.68, "amb_c": Color(0.95, 0.62, 0.62), "amb_w": 0.45, "fog": Color(0.95, 0.63, 0.52), "fog_w": 0.7,
		"cloud": Color(1.0, 0.64, 0.52), "shade": Color(0.5, 0.4, 0.62), "exp": 1.05, "stars": 0.0, "mist": 0.0, "flies": 0.35, "glow": 1.0}],
	[20.05, {"sun": Color(0.7, 0.6, 0.9), "e": 0.0, "zen": Color(0.1, 0.14, 0.34), "zen_w": 0.86, "hor": Color(0.56, 0.42, 0.58), "hor_w": 0.86,
		"amb": 0.55, "amb_c": Color(0.52, 0.52, 0.86), "amb_w": 0.6, "fog": Color(0.36, 0.36, 0.56), "fog_w": 0.8,
		"cloud": Color(0.58, 0.46, 0.62), "shade": Color(0.22, 0.2, 0.36), "exp": 1.2, "stars": 0.55, "mist": 0.1, "flies": 1.0, "glow": 0.3}],
	[21.0, "night"],
	[24.0, "night"],
]


## Advance the clock (real seconds). Nights pass about three times as fast as days.
func advance(dt: float) -> void:
	if fixed != 0:
		hour = FIXED_HOURS[fixed]
		return
	var day_h := SUNSET - SUNRISE
	var night_h := 24.0 - day_h
	var total := day_minutes * 60.0
	var rate := day_h / (total * 0.8) if is_day() else night_h / (total * 0.2)
	hour = fmod(hour + dt * rate, 24.0)


func is_day() -> bool:
	return hour >= SUNRISE and hour < SUNSET


## Next morning (after sleeping through the evening or night) or a nap of an hour and a half
func sleep() -> void:
	if fixed != 0:
		return
	if hour >= 18.0 or hour < SUNRISE:
		hour = 6.4
	else:
		hour += 1.5


## Mood at the current hour: the key values blended
func mood() -> Dictionary:
	var prev: Array = KEYS[0]
	for i in range(1, KEYS.size()):
		var k: Array = KEYS[i]
		if hour <= k[0]:
			var t := smoothstep(0.0, 1.0, (hour - prev[0]) / maxf(k[0] - prev[0], 0.001))
			return _mix(_key(prev[1]), _key(k[1]), t)
		prev = k
	return _key(KEYS[0][1])


func _key(v) -> Dictionary:
	if v is Dictionary:
		return v
	if v == "night":
		return KEYS[0][1]
	# "day": no change
	return {"sun": Color.WHITE, "e": 1.0, "zen": Color.WHITE, "zen_w": 0.0, "hor": Color.WHITE, "hor_w": 0.0, "amb": 1.0,
		"amb_c": Color.WHITE, "amb_w": 0.0, "fog": Color.WHITE, "fog_w": 0.0, "cloud": Color.WHITE, "shade": Color(0.62, 0.72, 0.88),
		"exp": 1.0, "stars": 0.0, "mist": 0.0, "flies": 0.0, "glow": 0.0}


func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		if a[k] is Color:
			out[k] = (a[k] as Color).lerp(b[k], t)
		else:
			out[k] = lerpf(a[k], b[k], t)
	return out


## Direction the light travels (like the biomes' sun_dir) and whether it is the moon
func light_dir(biome_dir: Vector3) -> Array:
	var d := biome_dir.normalized()
	var az := atan2(d.x, d.z)
	var el0 := asin(clampf(-d.y, 0.1, 1.0))
	# the light changes from sun to moon only where the mood has no direct light (20:03 and 5:15)
	var moon_time := hour >= 20.05 or hour < 5.25
	if not moon_time:
		var h := clampf(hour, SUNRISE, SUNSET)
		# rises from 0°, the biome's own height through the middle of the day, sets again
		var el: float
		if h < 9.8:
			el = lerpf(0.0, el0, smoothstep(SUNRISE, 9.8, h))
		elif h > 15.4:
			el = lerpf(el0, 0.0, smoothstep(15.4, SUNSET, h))
		else:
			el = el0
		el = maxf(el, 0.035)
		var a := az + (h - 12.5) / 7.0 * 0.95
		return [Vector3(sin(a) * cos(el), -sin(el), cos(a) * cos(el)), false]
	# the moon: high and a little behind you (opposite of the day's sun)
	var el_m := deg_to_rad(38.0)
	var am := az + PI * 0.82
	return [Vector3(sin(am) * cos(el_m), -sin(el_m), cos(am) * cos(el_m)), true]


## How much of the night look there is (0 day … 1 night): fixed-mood biomes still get dark at night
func nightness() -> float:
	return clampf(float(mood()["zen_w"]) * 1.15 - 0.05, 0.0, 1.0)


## The biome's atmosphere bent to the time of day. clock = how strongly the biome follows the clock by day
## (1 normal, less for biomes with their own fixed mood like the Sunset Coast).
func apply(c: Dictionary) -> Dictionary:
	var m := mood()
	var out := c.duplicate()
	var aff: float = lerpf(float(c.get("clock", 1.0)), 1.0, nightness())
	var ld: Array = light_dir(c["sun_dir"])
	var moon: bool = ld[1]
	out["sun_dir"] = (c["sun_dir"] as Vector3).normalized().slerp(ld[0], aff if not moon else 1.0)
	var sun_c: Color = (c["sun_color"] as Color) * m["sun"] if not moon else m["sun"]
	out["sun_color"] = (c["sun_color"] as Color).lerp(sun_c, aff)
	out["sun_energy"] = lerpf(c["sun_energy"], float(c["sun_energy"]) * m["e"] * (0.85 if moon else 1.0), aff)
	out["zenith_color"] = (c["zenith_color"] as Color).lerp(m["zen"], m["zen_w"] * aff)
	out["horizon_color"] = (c["horizon_color"] as Color).lerp(m["hor"], m["hor_w"] * aff)
	out["ambient_energy"] = lerpf(c["ambient_energy"], float(c["ambient_energy"]) * m["amb"], aff)
	out["ambient_color"] = (c["ambient_color"] as Color).lerp(m["amb_c"], m["amb_w"] * aff)
	out["fog_color"] = (c["fog_color"] as Color).lerp(m["fog"], m["fog_w"] * aff)
	# the backdrop mountains take the sky's mood (dark blue at night, warm in the evening)
	if c.has("mountain_color"):
		out["mountain_color"] = (c["mountain_color"] as Color).lerp(m["hor"], m["hor_w"] * aff * 0.55)
		out["mountain_shadow"] = (c["mountain_shadow"] as Color).lerp(m["zen"], m["zen_w"] * aff * 0.6)
	out["cloud_color"] = Color.WHITE.lerp(m["cloud"], aff)
	out["cloud_shadow"] = (c["cloud_shadow"] as Color).lerp(m["shade"], clampf(m["zen_w"] + m["hor_w"] * 0.4, 0.0, 1.0) * aff)
	out["exposure"] = float(c["exposure"]) * lerpf(1.0, m["exp"], aff)
	out["sun_glow"] = float(c["sun_glow"]) * lerpf(1.0, 0.4 + m["glow"] * 1.2, aff)
	out["stars"] = m["stars"]
	out["moon"] = 1.0 if moon else 0.0
	out["mist"] = m["mist"] * float(c.get("mist_amount", 1.0))
	out["flies"] = m["flies"]
	out["night"] = nightness()
	# a rainbow needs the sun behind you and not too high or too low: gone at dusk and at night
	var sun_up := -(out["sun_dir"] as Vector3).normalized().y
	out["rainbow"] = float(c.get("rainbow", 0.0)) * (0.0 if moon else smoothstep(0.03, 0.15, sun_up)) * (1.0 - float(out["night"]))
	# color grading: warmer in the golden hours, cooler and bluer at night
	var night := float(out["night"])
	out["grade_warm"] = lerpf(float(c.get("grade_warm", 0.0)), 0.7, float(m["glow"]) * 0.6 * (1.0 - night))
	out["grade_warm"] = lerpf(float(out["grade_warm"]), -0.6, night)
	out["grade_shadow"] = (c.get("grade_shadow", Color(0.35, 0.55, 0.75)) as Color).lerp(Color(0.25, 0.32, 0.8), night * 0.7)
	out["grade_high"] = (c.get("grade_high", Color(1.0, 0.86, 0.62)) as Color).lerp(Color(1.0, 0.72, 0.45), float(m["glow"]) * 0.5 * (1.0 - night))
	# sunbeams: strongest with low morning and evening light, none from the moon
	out["shaft_time"] = 0.0 if moon else (0.55 + 0.6 * float(m["glow"])) * clampf(float(m["e"]) * 1.5, 0.0, 1.0)
	# nights are cool, misty mornings a little too (a sweater starts to make sense)
	out["temperature"] = float(c.get("temperature", 16.0)) - 6.0 * float(out["night"]) - 2.0 * float(m["mist"])
	return out
