extends Node
## Voice (autoload "Voice"): local microphone test for the future voice chat.
## Reads the microphone, measures the level, decides when you "transmit" (push to talk, always on or voice
## activation) and drives the scout's mouth. Nothing is sent anywhere yet.

signal transmitting_changed(on: bool)

enum Mode { PUSH_TO_TALK, ALWAYS_ON, VOICE_ACTIVATION }
const MODE_NAMES := ["Push to talk", "Always on", "Voice activation"]
const BUS := "Mic"
const PTT_KEY := KEY_T

## Current level in dB (-80 = silence) and 0..1 for meters (-60 dB .. -6 dB)
var level_db := -80.0
var level := 0.0
## Share of the energy in the voice band (0..1)
var voice_share := 0.0
var transmitting := false
## Mouth opening for lip sync (0..1)
var mouth := 0.0
var active := false
## Test helper: force a level instead of the microphone (dB), NAN = off
var fake_db := NAN

var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _hold := 0.0
var _jitter := 0.0
var _mouth_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(func(k):
		if k in ["voice_enabled", "voice_device", "voice_monitor"]:
			_apply())
	_apply.call_deferred()


## Names of the input devices ("Default" first)
func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func _apply() -> void:
	var want: bool = Settings.values.get("voice_enabled", false)
	if want and not active:
		_start()
	elif not want and active:
		_stop()
	if active:
		var dev: String = Settings.values.get("voice_device", "Default")
		if dev in devices() and AudioServer.input_device != dev:
			AudioServer.input_device = dev
		var idx := AudioServer.get_bus_index(BUS)
		AudioServer.set_bus_mute(idx, not Settings.values.get("voice_monitor", false))


func _start() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new(), 0)
		var sa := AudioEffectSpectrumAnalyzer.new()
		sa.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(idx, sa, 1)
	_capture = AudioServer.get_bus_effect(idx, 0)
	_spectrum = AudioServer.get_bus_effect_instance(idx, 1)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)
	_player.play()
	active = true


func _stop() -> void:
	if _player:
		_player.stop()
		_player.queue_free()
		_player = null
	active = false
	level_db = -80.0
	level = 0.0
	_set_transmitting(false)


func _process(delta: float) -> void:
	if active or not is_nan(fake_db):
		_measure()
	var mode: int = Settings.values.get("voice_mode", Mode.VOICE_ACTIVATION)
	var thr: float = Settings.values.get("voice_threshold", -38.0)
	var key := Input.is_action_pressed("talk")
	var on := gate(mode, level_db, voice_share, thr, key, delta)
	_set_transmitting(on and (active or not is_nan(fake_db)))
	# lip sync: compressed level with a little syllable jitter, fast attack, slower release
	_jitter -= delta
	if _jitter <= 0.0:
		_jitter = randf_range(0.06, 0.14)
		_mouth_target = clampf(level * 1.4, 0.0, 1.0) * randf_range(0.65, 1.0) if transmitting else 0.0
	var k := 1.0 - exp(-delta / (0.025 if _mouth_target > mouth else 0.09))
	mouth = lerpf(mouth, _mouth_target, k)


func _measure() -> void:
	if not is_nan(fake_db):
		level_db = fake_db
		voice_share = 0.8
	elif _capture:
		var n := _capture.get_frames_available()
		if n > 0:
			var buf := _capture.get_buffer(n)
			var sum := 0.0
			for f in buf:
				sum += (f.x * f.x + f.y * f.y) * 0.5
			var rms := sqrt(sum / buf.size())
			level_db = maxf(linear_to_db(rms), -80.0) if rms > 0.0 else -80.0
		if _spectrum:
			var voice_e := _spectrum.get_magnitude_for_frequency_range(250.0, 3400.0).length()
			var all_e := _spectrum.get_magnitude_for_frequency_range(60.0, 8000.0).length()
			voice_share = clampf(voice_e / maxf(all_e, 1e-6), 0.0, 1.0)
	level = clampf(inverse_lerp(-60.0, -6.0, level_db), 0.0, 1.0)


## Decides whether you are transmitting (pure apart from the hold timer)
func gate(mode: int, db: float, share: float, threshold: float, key_held: bool, delta: float) -> bool:
	match mode:
		Mode.PUSH_TO_TALK:
			return key_held
		Mode.ALWAYS_ON:
			return true
		_:
			if db > threshold and share > 0.35:
				_hold = 0.35
				return true
			if transmitting and db > threshold - 6.0:
				_hold = 0.35
				return true
			_hold = maxf(_hold - delta, 0.0)
			return _hold > 0.0


func _set_transmitting(on: bool) -> void:
	if on != transmitting:
		transmitting = on
		transmitting_changed.emit(on)
