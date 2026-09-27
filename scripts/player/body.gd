class_name Body
extends RefCounted
## Body state: only Fit → Exhausted → Weak → Collapsed is visible.
## Hunger, thirst, tiredness, temperature, wetness and load act in the background
## on maximum stamina and recovery.

enum State { FIT, TIRED, WEAK, COLLAPSED }
const STATE_NAMES := ["Fit", "Exhausted", "Weak", "Collapsed"]
const STATE_COLORS := [Color(0.45, 0.85, 0.35), Color(0.98, 0.82, 0.25), Color(1.0, 0.55, 0.2), Color(0.95, 0.25, 0.2)]

# consumption per second (game time): full → hungry in ~40 min, thirst ~25 min, tiredness ~70 min
const HUNGER_RATE := 100.0 / 2400.0
const THIRST_RATE := 100.0 / 1500.0
const FATIGUE_RATE := 100.0 / 4200.0

var stamina := 100.0
var food := 85.0        # 100 = full
var water := 85.0       # 100 = not thirsty
var rest := 90.0        # 100 = well rested
var health := 100.0     # injuries
var wet := 0.0          # 0..1, dries slowly
var feel_temp := 18.0   # felt temperature °C
var state := State.FIT
## Timers from items: warming drinks, sunscreen
var warm_bonus_t := 0.0
var heat_protect_t := 0.0
## Multipliers set by the owner each frame: climbing effort (stick, boots), rest recovery (harmonica)
var climb_factor := 1.0
var rest_bonus := 1.0


## Upper stamina limit from all background factors
func max_stamina() -> float:
	var f := 1.0
	f *= _factor(food, 25.0)
	f *= _factor(water, 25.0)
	f *= _factor(rest, 20.0)
	f *= lerpf(0.55, 1.0, health / 100.0)
	f *= 1.0 - comfort_penalty() * 0.45
	return clampf(100.0 * f, 8.0, 100.0)


func _factor(v: float, threshold: float) -> float:
	return 1.0 if v >= threshold else lerpf(0.15, 1.0, v / threshold)


## 0 = pleasant, 1 = very cold or very hot
func comfort_penalty() -> float:
	if feel_temp < 12.0:
		return clampf((12.0 - feel_temp) / 14.0, 0.0, 1.0)
	if feel_temp > 27.0:
		return clampf((feel_temp - 27.0) / 12.0, 0.0, 1.0)
	return 0.0


func temp_word() -> String:
	if feel_temp < 2.0: return "freezing"
	if feel_temp < 12.0: return "cold"
	if feel_temp < 17.0: return "cool"
	if feel_temp <= 27.0: return "pleasant"
	if feel_temp <= 33.0: return "warm"
	return "hot"


## Main update. effort: 0 standing, 1 walking, 2 running, 3 swimming; load = luggage in kg
func update(delta: float, effort: int, climb: float, load: float, air_temp: float, clothing: float, resting: bool) -> void:
	if state == State.COLLAPSED:
		return
	var busy: float = [0.6, 1.0, 1.8, 2.0][effort]
	var heat := clampf((air_temp - 24.0) / 10.0, 0.0, 1.5)
	food = maxf(food - HUNGER_RATE * busy * delta, 0.0)
	water = maxf(water - THIRST_RATE * (busy + heat) * delta, 0.0)
	rest = maxf(rest - FATIGUE_RATE * (0.3 if resting else busy) * delta, 0.0)
	wet = maxf(wet - delta / (70.0 + maxf(10.0 - air_temp, 0.0) * 8.0), 0.0)
	# felt temperature: air + clothing + movement - wetness
	var target: float = air_temp + clothing + [0.0, 2.0, 5.0, -4.0][effort] - wet * 10.0
	warm_bonus_t = maxf(warm_bonus_t - delta, 0.0)
	heat_protect_t = maxf(heat_protect_t - delta, 0.0)
	if warm_bonus_t > 0.0:
		target += 6.0
	if heat_protect_t > 0.0 and target > 24.0:
		target = 24.0 + (target - 24.0) * 0.5
	feel_temp = lerpf(feel_temp, target, 1.0 - exp(-delta / 20.0))

	var load_over := maxf(load - Inventory.COMFORT_WEIGHT, 0.0)
	var mx := max_stamina()
	var change := 0.0
	match effort:
		0: change = 10.0 if not resting else 18.0 * rest_bonus
		1: change = 2.6 - load_over * 0.45 - climb * climb_factor * 2.2 * (1.0 + load_over * 0.08)
		2: change = -11.0 - load_over * 0.6
		3: change = -3.5 - load_over * 0.4
	change *= 1.0 - comfort_penalty() * 0.5 if change > 0.0 else 1.0
	stamina = clampf(stamina + change * delta, 0.0, mx)
	_update_state(mx)


func _update_state(mx: float) -> void:
	var r := stamina / 100.0
	var s := State.FIT
	if stamina <= 0.0:
		s = State.COLLAPSED
	elif r < 0.25:
		s = State.WEAK
	elif r < 0.55:
		s = State.TIRED
	# recovery needs some distance to the thresholds
	if s < state:
		var limits := [0.0, 0.62, 0.32]
		if r < limits[state]:
			s = state
	state = s


func spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)


func recover_from_collapse() -> void:
	stamina = minf(30.0, max_stamina())
	state = State.WEAK


## Hints the player should feel (symbol texts for the HUD)
func needs() -> Array[String]:
	var out: Array[String] = []
	if food < 25.0: out.append("Hungry")
	if water < 25.0: out.append("Thirsty")
	if rest < 20.0: out.append("Tired")
	if feel_temp < 12.0: out.append("Cold")
	if feel_temp > 27.0: out.append("Hot")
	if wet > 0.3: out.append("Wet")
	if health < 60.0: out.append("Injured")
	return out
