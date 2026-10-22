class_name OrbVisual
extends Node2D

## Filled core, a solid inner ring and a slowly rotating dashed outer ring.
## Animation is visual only; the Orb's Area2D and position never change.

const PULSE_SPEED := 3.0       # radians per second of the core pulse
const RING_SPIN_SPEED := 0.9   # radians per second of the dashed ring
const DASH_COUNT := 4
const DASH_FILL := 0.55        # fraction of each dash slot that is drawn

var _time := 0.0


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Palette.APPEAR_DURATION)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)

	draw_circle(Vector2.ZERO, Palette.ORB_CORE_RADIUS + 4.0, Color(Palette.CYAN, 0.08 + 0.06 * pulse))
	draw_circle(Vector2.ZERO, Palette.ORB_CORE_RADIUS, Palette.WHITE.lerp(Palette.CYAN, 0.35 - 0.25 * pulse))
	draw_arc(Vector2.ZERO, Palette.ORB_RING_RADIUS, 0.0, TAU, 32, Palette.CYAN, 1.5, true)

	var slot := TAU / DASH_COUNT
	var spin := _time * RING_SPIN_SPEED
	for i in DASH_COUNT:
		var start := spin + slot * i
		draw_arc(Vector2.ZERO, Palette.ORB_OUTER_RADIUS, start, start + slot * DASH_FILL, 8, Color(Palette.CYAN, 0.55), 1.5, true)
