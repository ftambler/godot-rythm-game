class_name PlayerAura
extends Node2D

## Pulsing red glow around the player when health is low.
## Fades in below LOW_HEALTH and gets stronger the closer health gets to 0.

const LOW_HEALTH := 50
const RADIUS := 60.0
const PULSE_SPEED := 6.0
const FADE_SPEED := 2.5  # higher = reaches the target intensity faster

var _target_intensity := 0.0
var _intensity := 0.0  # eased toward the target so changes never snap
var _time := 0.0
var _gradient_texture: GradientTexture2D


func set_health(health: int) -> void:
	var danger := clampf(1.0 - float(health) / LOW_HEALTH, 0.0, 1.0)
	# Start already clearly visible, then ramp up toward 0 health.
	_target_intensity = 0.0 if danger == 0.0 else lerpf(0.5, 1.0, danger)


func _ready() -> void:
	visible = false
	# Radial gradient: red in the middle fading smoothly to transparent at the edge.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(Palette.DANGER, 1.0),
		Color(Palette.DANGER, 0.6),
		Color(Palette.DANGER, 0.0),
	])
	_gradient_texture = GradientTexture2D.new()
	_gradient_texture.gradient = gradient
	_gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	_gradient_texture.fill_from = Vector2(0.5, 0.5)
	_gradient_texture.fill_to = Vector2(1.0, 0.5)
	_gradient_texture.width = 128
	_gradient_texture.height = 128


func _process(delta: float) -> void:
	_time += delta
	_intensity = lerpf(_intensity, _target_intensity, 1.0 - exp(-FADE_SPEED * delta))
	visible = _intensity > 0.01
	queue_redraw()


func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(_time * PULSE_SPEED)
	var radius := RADIUS * (0.9 + 0.1 * pulse)
	var rect := Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
	draw_texture_rect(_gradient_texture, rect, false, Color(1, 1, 1, _intensity * pulse))
