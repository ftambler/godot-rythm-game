class_name ShieldVisual
extends Node2D

## Thick cyan arc drawn facing +X. Its parent PlayerShield already owns the
## gameplay direction, rotation and visibility; this node only draws and flashes.

var _flash_color := Palette.CYAN
var _flash_strength := 0.0:
	set(value):
		_flash_strength = value
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	var player := owner as Player
	if player:
		player.hit_registered.connect(_on_hit_registered)


func _draw() -> void:
	var half_arc := Palette.SHIELD_ARC * 0.5
	var color := Palette.CYAN.lerp(_flash_color, _flash_strength)
	NeonDraw.glow_arc(self, Palette.SHIELD_RADIUS, -half_arc, half_arc, color, Palette.SHIELD_WIDTH)
	# Thin bright inner edge so the arc reads as a solid band rather than a line.
	draw_arc(Vector2.ZERO, Palette.SHIELD_RADIUS - Palette.SHIELD_WIDTH * 0.5 + 0.75, -half_arc, half_arc, 24, color.lightened(0.6), 1.5, true)


func _on_hit_registered(result: HitResult.Type) -> void:
	if not is_visible_in_tree():
		return
	_flash_color = Palette.hit_result_color(result)
	if _tween:
		_tween.kill()
	_flash_strength = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "_flash_strength", 0.0, Palette.FLASH_DURATION)
