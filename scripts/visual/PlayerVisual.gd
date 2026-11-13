class_name PlayerVisual
extends Node2D

## Solid cyan ball for the player. Flashes the hit-result color whenever the
## player registers a hit (wall bounce or orb press).
## Purely visual: never scales or rotates, so it can't misrepresent the hitbox or direction.

var _flash_color := Palette.CYAN
var _flash_strength := 0.0:
	set(value):
		_flash_strength = value
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	var player := owner as Player
	if player == null:
		return
	player.hit_registered.connect(_on_hit_registered)


func _draw() -> void:
	var radius := Palette.PLAYER_SIZE * 0.5
	var accent := Palette.CYAN.lerp(_flash_color, _flash_strength)

	draw_circle(Vector2.ZERO, radius + Palette.GLOW_FAR_WIDTH * 0.5, Color(accent, accent.a * Palette.GLOW_FAR_ALPHA))
	draw_circle(Vector2.ZERO, radius + Palette.GLOW_NEAR_WIDTH * 0.5, Color(accent, accent.a * Palette.GLOW_NEAR_ALPHA))
	draw_circle(Vector2.ZERO, radius, accent)
	draw_arc(Vector2.ZERO, radius - Palette.OUTLINE_WIDTH * 0.5, 0.0, TAU, 32, accent.lightened(0.55), Palette.OUTLINE_WIDTH, true)


func _on_hit_registered(result: HitResult.Type) -> void:
	_flash_color = Palette.hit_result_color(result)
	if _tween:
		_tween.kill()
	_flash_strength = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "_flash_strength", 0.0, Palette.FLASH_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
