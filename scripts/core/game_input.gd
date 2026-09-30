extends Node
## Input for keyboard + mouse and game controllers (autoload "GameInput").
## All game actions are created here in code: keyboard keys (physical, layout independent), mouse buttons and
## controller buttons. Sticks are read directly (deadzone and response curve). The device used last decides the
## button glyphs and hints; a connected controller is picked up automatically.

signal device_changed(pad: bool)

const STICK_DEAD := 0.16
const TRIGGER_DEAD := 0.35

## action -> [keyboard keys / mouse buttons, joypad buttons, joypad trigger axis (-1 = none)]
const ACTIONS := {
	"jump": [[KEY_SPACE], [JOY_BUTTON_A], -1],
	"crouch": [[KEY_CTRL], [JOY_BUTTON_B], -1],
	"sprint": [[KEY_SHIFT], [JOY_BUTTON_LEFT_STICK], -1],
	"use": [[KEY_E], [JOY_BUTTON_X], -1],
	"use_hand": [[KEY_F], [JOY_BUTTON_RIGHT_SHOULDER], -1],
	"hand_next": [[KEY_X], [JOY_BUTTON_DPAD_RIGHT], -1],
	"hand_prev": [[KEY_Z], [JOY_BUTTON_DPAD_LEFT], -1],
	"hand_stow": [[KEY_H], [JOY_BUTTON_DPAD_DOWN], -1],
	"rest": [[KEY_R], [JOY_BUTTON_DPAD_UP], -1],
	"backpack": [[KEY_TAB], [JOY_BUTTON_Y], -1],
	"emotes": [[KEY_G], [JOY_BUTTON_LEFT_SHOULDER], -1],
	"view": [[KEY_V], [JOY_BUTTON_RIGHT_STICK], -1],
	"zoom": [[MOUSE_BUTTON_RIGHT], [], JOY_AXIS_TRIGGER_LEFT],
	"untie": [[KEY_Q], [], JOY_AXIS_TRIGGER_RIGHT],
	"pause": [[KEY_ESCAPE], [JOY_BUTTON_START], -1],
	"talk": [[KEY_T], [JOY_BUTTON_BACK], -1],
}

## true: the last input came from a controller
var using_pad := false
## joypad device that was used last (-1 = none)
var pad_device := -1
## > 0: something (the emote wheel) uses the right stick, the camera must not turn
var block_look := 0
## sprint / crouch latched by a controller click (toggle mode)
var _pad_sprint := false
var _pad_crouch := false
var _still_t := 0.0
var _fake_axes := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_actions()
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		if connected and pad_device < 0:
			pad_device = device
		elif not connected and device == pad_device:
			var pads := Input.get_connected_joypads()
			pad_device = pads[0] if not pads.is_empty() else -1
			if pad_device < 0 and using_pad:
				_set_pad(false))
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		pad_device = pads[0]


func _define_actions() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a, 0.3)
		var d: Array = ACTIONS[a]
		for k in d[0]:
			# small numbers are mouse buttons, the rest keys
			if k > 10:
				var e := InputEventKey.new()
				e.physical_keycode = k
				InputMap.action_add_event(a, e)
			else:
				var m := InputEventMouseButton.new()
				m.button_index = k
				InputMap.action_add_event(a, m)
		for b in d[1]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			j.device = -1
			InputMap.action_add_event(a, j)
		if int(d[2]) >= 0:
			var jm := InputEventJoypadMotion.new()
			jm.axis = d[2]
			jm.axis_value = 1.0
			jm.device = -1
			InputMap.action_add_event(a, jm)
	# menus: the D-pad and the left stick already move the focus (Godot defaults); B goes back
	for ui in ["ui_cancel"]:
		var has_b := false
		for e in InputMap.action_get_events(ui):
			if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B:
				has_b = true
		if not has_b:
			var jb := InputEventJoypadButton.new()
			jb.button_index = JOY_BUTTON_B
			jb.device = -1
			InputMap.action_add_event(ui, jb)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		pad_device = event.device
		_set_pad(true)
		if event.button_index == JOY_BUTTON_LEFT_STICK:
			_pad_sprint = not _pad_sprint if Settings.values.get("pad_sprint_toggle", true) else _pad_sprint
		elif event.button_index == JOY_BUTTON_B and Settings.values.get("pad_crouch_toggle", true):
			_pad_crouch = not _pad_crouch
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.45:
		pad_device = event.device
		_set_pad(true)
	elif event is InputEventKey and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseMotion and event.relative.length() > 6.0:
		_set_pad(false)


func _set_pad(on: bool) -> void:
	if on == using_pad:
		return
	using_pad = on
	if not on:
		_pad_sprint = false
		_pad_crouch = false
	device_changed.emit(on)


func _process(delta: float) -> void:
	# a toggled sprint ends when you stop walking
	if _pad_sprint:
		_still_t = _still_t + delta if _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).length() < 0.2 else 0.0
		if _still_t > 0.35:
			_pad_sprint = false


# ================================================================ Reading

func _axis(axis: int) -> float:
	if _fake_axes.has(axis):
		return _fake_axes[axis]
	if pad_device < 0:
		return 0.0
	return Input.get_joy_axis(pad_device, axis)


## A stick with a round deadzone, rescaled to 0..1 beyond it
func _stick(ax: int, ay: int) -> Vector2:
	var v := Vector2(_axis(ax), _axis(ay))
	var l := v.length()
	if l < STICK_DEAD:
		return Vector2.ZERO
	return v / l * minf((l - STICK_DEAD) / (1.0 - STICK_DEAD), 1.0)


## Walking: x = right, y = forward; length 0..1 (keys give full length, the stick is analog)
func move_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	if v != Vector2.ZERO:
		return v.normalized()
	var s := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	return Vector2(s.x, -s.y)


## Right stick for looking: radians per second (sensitivity, invert, response curve); zero while blocked
func look_rate() -> Vector2:
	if block_look > 0:
		return Vector2.ZERO
	var s := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if s == Vector2.ZERO:
		return s
	var l := s.length()
	var curved := s / l * pow(l, 1.8)
	var sens: float = Settings.values.get("pad_look_sens", 1.0)
	var inv := -1.0 if Settings.values.get("pad_invert_y", false) else 1.0
	return Vector2(curved.x * 3.2, curved.y * 2.2 * inv) * sens


## Raw right stick (for the emote wheel and the scout editor)
func right_stick() -> Vector2:
	return _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


func sprint_held() -> bool:
	if Input.is_physical_key_pressed(KEY_SHIFT):
		return true
	return _pad_sprint or (not Settings.values.get("pad_sprint_toggle", true) and Input.is_joy_button_pressed(maxi(pad_device, 0), JOY_BUTTON_LEFT_STICK))


func crouch_held() -> bool:
	if Input.is_physical_key_pressed(KEY_CTRL):
		return true
	if not using_pad:
		return false
	if Settings.values.get("pad_crouch_toggle", true):
		return _pad_crouch
	return Input.is_joy_button_pressed(maxi(pad_device, 0), JOY_BUTTON_B)


## Stand up again (toggle crouch) – e.g. after jumping
func release_crouch() -> void:
	_pad_crouch = false


func rumble(weak: float, strong: float, seconds: float) -> void:
	if not using_pad or pad_device < 0 or not Settings.values.get("vibration", true):
		return
	Input.start_joy_vibration(pad_device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


# ================================================================ Glyphs

## "xbox" or "playstation" (setting, or guessed from the controller's name)
func pad_style() -> String:
	var s := int(Settings.values.get("button_style", 0))
	if s == 1:
		return "xbox"
	if s == 2:
		return "playstation"
	if pad_device >= 0:
		var n := Input.get_joy_name(pad_device).to_lower()
		if "ps" in n or "dualsense" in n or "dualshock" in n or "playstation" in n or "sony" in n:
			return "playstation"
	return "xbox"


const PAD_NAMES := {
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Menu",
		JOY_BUTTON_BACK: "View", JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←",
		JOY_BUTTON_DPAD_RIGHT: "D-pad →"},
	"playstation": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share", JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
		JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →"},
}
const TRIGGER_NAMES := {"xbox": {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"},
	"playstation": {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"}}
const KEY_NAMES := {MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_LEFT: "LMB", KEY_SPACE: "Space", KEY_CTRL: "Ctrl",
	KEY_SHIFT: "Shift", KEY_TAB: "Tab", KEY_ESCAPE: "Esc"}


## Short label of the button for an action on the current device ("E", "X", "Square", "LT" …)
func glyph(action: String, pad := -1) -> String:
	var d: Array = ACTIONS.get(action, [[], [], -1])
	var on_pad := using_pad if pad < 0 else pad == 1
	if on_pad:
		var st := pad_style()
		if not (d[1] as Array).is_empty():
			return PAD_NAMES[st].get(d[1][0], "?")
		if int(d[2]) >= 0:
			return TRIGGER_NAMES[st].get(int(d[2]), "?")
		return ""
	if (d[0] as Array).is_empty():
		return ""
	var k: int = d[0][0]
	if KEY_NAMES.has(k):
		return KEY_NAMES[k]
	return OS.get_keycode_string(k)


## test helper: pretend a stick is held
func fake_axis(axis: int, value: float) -> void:
	if absf(value) < 0.001:
		_fake_axes.erase(axis)
	else:
		_fake_axes[axis] = value
		_set_pad(true)
