class_name MicWidgets
extends RefCounted
## Small drawn widgets for the voice test: microphone badge (HUD) and level meter (settings).


## Round badge with a microphone symbol and level rings; visible while transmitting
class Badge extends Control:
	var _a := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var want := 1.0 if Voice.transmitting else 0.0
		_a = move_toward(_a, want, delta * 6.0)
		queue_redraw()

	func _draw() -> void:
		if _a <= 0.01:
			return
		var c := size * 0.5
		var lv := Voice.level
		draw_circle(c, 24.0, Color(0.13, 0.17, 0.12, 0.6 * _a))
		draw_arc(c, 24.0 + lv * 6.0, 0.0, TAU, 40, Color(0.62, 0.86, 0.3, 0.8 * _a * lv + 0.1 * _a), 3.0, true)
		draw_arc(c, 24.0, 0.0, TAU, 40, Color(0.98, 0.96, 0.9, 0.85 * _a), 2.5, true)
		var ink := Color(0.98, 0.96, 0.9, _a)
		# capsule + stand
		draw_rect(Rect2(c + Vector2(-5, -12), Vector2(10, 14)), ink, true)
		draw_circle(c + Vector2(0, -12), 5.0, ink)
		draw_circle(c + Vector2(0, 2), 5.0, ink)
		draw_arc(c + Vector2(0, 0), 9.0, 0.15, PI - 0.15, 16, ink, 2.5, true)
		draw_line(c + Vector2(0, 9), c + Vector2(0, 14), ink, 2.5)
		draw_line(c + Vector2(-5, 14), c + Vector2(5, 14), ink, 2.5)


## Horizontal level meter with the activation threshold marked
class Meter extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 26)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(size.x, 14))
		draw_rect(r, Color(1, 1, 1, 0.08), true)
		var lv := Voice.level
		var col := Color(0.62, 0.86, 0.3) if Voice.transmitting else Color(0.75, 0.75, 0.72)
		draw_rect(Rect2(r.position, Vector2(r.size.x * lv, r.size.y)), col, true)
		var thr: float = Settings.values.get("voice_threshold", -38.0)
		var tx := r.size.x * clampf(inverse_lerp(-60.0, -6.0, thr), 0.0, 1.0)
		draw_line(Vector2(tx, 2), Vector2(tx, 24), Color(0.95, 0.76, 0.19), 3.0)
		var font := get_theme_default_font()
		var text := "No microphone active" if not Voice.active else ("%.0f dB%s" % [Voice.level_db, "  · talking" if Voice.transmitting else ""])
		draw_string(font, Vector2(6, 19), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
