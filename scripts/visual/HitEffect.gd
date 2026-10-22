class_name HitEffect
extends Node2D

## Short-lived world-space effect: an expanding ring, plus an optional fading
## bar that echoes a wall which has just been despawned. Frees itself when done.

const RING_FROM := 6.0
const RING_TO := 22.0

var color := Palette.CYAN
var bar_length := 0.0  # 0 disables the bar
var ring_offset := Vector2.ZERO

var _progress := 0.0:
	set(value):
		_progress = value
		queue_redraw()


static func spawn_ring(parent: Node, at: Vector2, ring_color: Color) -> void:
	var effect := HitEffect.new()
	effect.color = ring_color
	parent.add_child(effect)
	effect.global_position = at


static func spawn_wall(parent: Node, wall_transform: Transform2D, contact: Vector2, ring_color: Color) -> void:
	var effect := HitEffect.new()
	effect.color = ring_color
	effect.bar_length = Palette.WALL_LENGTH
	parent.add_child(effect)
	effect.global_transform = wall_transform
	effect.ring_offset = effect.to_local(contact)


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, Palette.EFFECT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _draw() -> void:
	var fade := 1.0 - _progress

	if bar_length > 0.0:
		var half := bar_length * 0.5
		var width := Palette.WALL_THICKNESS * (1.0 + _progress)
		draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), Color(color, 0.18 * fade), width + Palette.GLOW_NEAR_WIDTH, true)
		draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), Color(color, 0.7 * fade), width * 0.5, true)

	var radius := lerpf(RING_FROM, RING_TO, _progress)
	draw_arc(ring_offset, radius, 0.0, TAU, 32, Color(color, 0.85 * fade), 2.0 * fade + 0.5, true)
