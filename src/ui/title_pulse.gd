extends Node2D

## D-29's restrained three-second, two-pixel title pulse.

const PERIOD_SECONDS := 3.0
const BASE_RADIUS := 10.0
const EXPANSION_PIXELS := 2.0
const PULSE_COLOR := Color("#B1FFD1")

var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, PERIOD_SECONDS)
	queue_redraw()


func _draw() -> void:
	var phase := _elapsed / PERIOD_SECONDS
	var radius := int(BASE_RADIUS + roundf(sin(phase * PI) * EXPANSION_PIXELS))
	var half_radius := radius >> 1
	var points := PackedVector2Array([
		Vector2(0, -radius),
		Vector2(half_radius, -half_radius),
		Vector2(radius, 0),
		Vector2(half_radius, half_radius),
		Vector2(0, radius),
		Vector2(-half_radius, half_radius),
		Vector2(-radius, 0),
		Vector2(-half_radius, -half_radius),
		Vector2(0, -radius),
	])
	draw_polyline(points, PULSE_COLOR, 1.0, false)
	draw_rect(Rect2(-1, -1, 3, 3), PULSE_COLOR, false, 1.0)
