class_name MusicDirector
extends Node
## Background music: every biome has its own playlist; situations (obstacle, resting, water)
## override it. Tracks change randomly without short repeats, with a soft crossfade,
## and are loaded in the background. Loudness per track measured in advance (MusicTracks).
## Music: AlkaKrab – Fantasy Ambient, Desert, Fantasy RPG Vol. 2, Fairytale Magical Fantasy (royalty-free for games).

signal track_started(title: String, context: String)

const FADE := 6.0
const BIOME_SETTLE := 5.0       # a new biome must persist this long before the music changes
const SITUATION_SETTLE := 1.5   # situations react faster
const SITUATION_HOLD := 12.0    # tension music keeps playing for a while after the obstacle

const STINGERS := {
	"kollaps": ["res://assets/music/fantasy_rpg/mp3/Death.mp3", -10.0],
	"geschafft": ["res://assets/music/fantasy_rpg/mp3/Victory.mp3", -11.0],
	"seltsam": ["res://assets/music/fantasy_rpg/mp3/Strange.mp3", -10.0],
}

var bus_idx := -1
var _players: Array[AudioStreamPlayer] = []
var _tweens: Array[Tween] = [null, null]
var _active := 0
var _current := ""
var _context := "menu"          # what is playing right now: "menu", "biom:3", "spannung", …
var _biome := -1
var _pending_biome := -1
var _biome_time := 0.0
var _situation := ""
var _pending_situation := ""
var _situation_time := 0.0
var _situation_hold := 0.0
var _recent: Array[String] = []
var _gap := 0.5
var _rng := RandomNumberGenerator.new()
var _stinger: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _loading := ""
var _load_fade := 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "Music")
		AudioServer.set_bus_send(bus_idx, "Master")
	# create the low-pass (underwater) only once – the bus survives a scene reload
	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		AudioServer.add_bus_effect(bus_idx, AudioEffectLowPassFilter.new())
	_lowpass = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectLowPassFilter
	_lowpass.cutoff_hz = 20000.0
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = "Music"
	add_child(_stinger)
	_apply_volume()
	Settings.changed.connect(_on_setting)


func _on_setting(k: String) -> void:
	if k in ["music_volume", "music"]:
		_apply_volume()


## Softer for a while (the scout plays the harmonica)
var _duck := 0.0
var _duck_t := 0.0


func duck(db: float, seconds: float) -> void:
	_duck = db
	_duck_t = seconds


func _apply_volume() -> void:
	var v: float = Settings.values.get("music_volume", 0.7)
	var on: bool = Settings.values.get("music", true)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(v, 0.0001)) - 4.0 - _duck_now)
	AudioServer.set_bus_mute(bus_idx, not on or v <= 0.001)


# ================================================================ Control from outside

func set_menu() -> void:
	_biome = -1
	_situation = ""
	_pending_situation = ""
	_switch("menu", 3.0)


## Journey start: play the start biome's music right away
func start_biome(biome: int) -> void:
	_biome = biome
	_pending_biome = -1
	_situation = ""
	_pending_situation = ""
	_switch(_wanted_context(), 4.0)


## Biome under the player's feet (reported every frame)
func set_biome(biome: int) -> void:
	if biome == _biome:
		_pending_biome = -1
		return
	if biome != _pending_biome:
		_pending_biome = biome
		_biome_time = 0.0


## Situation: "" (none), "spannung" (tension), "ruhe" (calm), "wasser" (water)
func set_situation(s: String) -> void:
	if s == "spannung":
		_situation_hold = SITUATION_HOLD
	if s != _pending_situation:
		_pending_situation = s
		_situation_time = 0.0


func stinger(kind: String) -> void:
	if not STINGERS.has(kind):
		return
	var s: Array = STINGERS[kind]
	if not ResourceLoader.exists(s[0]):
		return
	_stinger.stream = load(s[0])
	_stinger.volume_db = s[1]
	_stinger.play()


## 0 = above water, 1 = fully underwater: music sounds muffled
func set_underwater(amount: float) -> void:
	_lowpass.cutoff_hz = lerpf(20000.0, 500.0, clampf(amount, 0.0, 1.0))


func now_playing() -> String:
	return _current


func context() -> String:
	return _context


# ================================================================ Flow

func _wanted_context() -> String:
	if _situation != "":
		return _situation
	if _biome < 0:
		return "menu"
	return "biom:%d" % _biome


func _playlist(ctx: String) -> Array:
	if ctx.begins_with("biom:"):
		return MusicTracks.BIOMES[int(ctx.get_slice(":", 1)) % MusicTracks.BIOMES.size()]
	return MusicTracks.SITUATIONS.get(ctx, MusicTracks.SITUATIONS["menu"])


var _duck_now := 0.0


func _process(delta: float) -> void:
	_duck_t = maxf(_duck_t - delta, 0.0)
	var want := _duck if _duck_t > 0.0 else 0.0
	if absf(want - _duck_now) > 0.01:
		_duck_now = move_toward(_duck_now, want, delta * 12.0)
		_apply_volume()
	_poll_loading()
	_situation_hold = maxf(_situation_hold - delta, 0.0)
	var changed := false
	if _pending_biome >= 0:
		_biome_time += delta
		if _biome_time > BIOME_SETTLE:
			_biome = _pending_biome
			_pending_biome = -1
			changed = true
	if _pending_situation != _situation:
		_situation_time += delta
		# tension fades out after the obstacle before it ends
		var leaving_tension := _situation == "spannung" and _situation_hold > 0.0
		if _situation_time > SITUATION_SETTLE and not leaving_tension:
			_situation = _pending_situation
			changed = true
	if changed:
		var ctx := _wanted_context()
		if ctx != _context:
			_switch(ctx, 3.0 if ctx == "spannung" else 5.0)
	if _current == "":
		_gap -= delta
		if _gap <= 0.0 and _loading == "":
			_switch(_wanted_context(), 2.5)
		return
	var p := _players[_active]
	var length: float = MusicTracks.TRACKS[_current][2]
	if not p.playing or p.get_playback_position() > length - FADE:
		# fade out, short breather (longer in calm moments), then the next track
		_fade_out(_active, FADE)
		_current = ""
		_gap = _rng.randf_range(1.5, 4.0) if _context == "spannung" else _rng.randf_range(3.0, 9.0)


func _switch(ctx: String, fade: float) -> void:
	_context = ctx
	var list := _playlist(ctx)
	if list.has(_current) and ctx != "spannung" and _loading == "":
		return   # the current track already fits
	var pool: Array = list.filter(func(t): return not _recent.has(t) and t != _current)
	if pool.is_empty():
		pool = list.filter(func(t): return t != _current)
	if pool.is_empty():
		pool = list
	var t: String = pool[_rng.randi() % pool.size()]
	_recent.append(t)
	if _recent.size() > 10:
		_recent.pop_front()
	_crossfade_to(t, fade)


func _crossfade_to(title: String, fade: float) -> void:
	var path: String = MusicTracks.TRACKS[title][0]
	if not ResourceLoader.exists(path):
		# music isn't part of the public source code (license) – play silently without it
		_gap = 60.0
		return
	if ResourceLoader.has_cached(path) or not Settings.values.get("opt_music_thread", true):
		_loading = ""
		_start_track(title, fade)
		return
	ResourceLoader.load_threaded_request(path)
	_loading = title
	_load_fade = fade


func _poll_loading() -> void:
	if _loading == "":
		return
	var path: String = MusicTracks.TRACKS[_loading][0]
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var t := _loading
		_loading = ""
		_start_track(t, _load_fade)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_warning("Could not load music: " + path)
		_loading = ""


func _start_track(title: String, fade: float) -> void:
	var info: Array = MusicTracks.TRACKS[title]
	var path: String = info[0]
	var stream: AudioStream
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		stream = ResourceLoader.load_threaded_get(path)
	else:
		stream = load(path)
	if stream == null:
		push_warning("Music missing: " + path)
		return
	if "loop" in stream:
		stream.set("loop", false)
	var old := _active
	_active = 1 - _active
	var p := _players[_active]
	if _tweens[_active]:
		_tweens[_active].kill()
	p.stream = stream
	p.volume_db = -60.0
	p.play()
	# tension music a bit more restrained: accompany, don't dominate
	var target: float = float(info[1]) - (3.0 if _context == "spannung" else 0.0)
	_tweens[_active] = create_tween()
	_tweens[_active].tween_property(p, "volume_db", target, fade).set_trans(Tween.TRANS_SINE)
	_fade_out(old, fade)
	_current = title
	track_started.emit(title, _context)


func _fade_out(idx: int, fade: float) -> void:
	var p := _players[idx]
	if not p.playing:
		return
	if _tweens[idx]:
		_tweens[idx].kill()
	_tweens[idx] = create_tween()
	_tweens[idx].tween_property(p, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
	_tweens[idx].tween_callback(p.stop)
