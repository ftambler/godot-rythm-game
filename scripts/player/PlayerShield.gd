class_name PlayerShield
extends Node2D


var direction: PlayerDirection.Direction = PlayerDirection.Direction.RIGHT
var active: bool = false

func _process(_delta: float) -> void:
	update_direction()
	update_visual()

func update_visual() -> void:
	visible = active

	if not active:
		return

	var direction_vector := PlayerDirection.to_vector(direction)

	rotation = direction_vector.angle()
	
func update_direction() -> void:
	var x := Input.get_axis("shield_left", "shield_right")
	var y := Input.get_axis("shield_up", "shield_down")

	if x == 0 and y == 0:
		active = false
		return

	active = true

	match Vector2(x, y):
		Vector2(0, -1):
			direction = PlayerDirection.Direction.UP

		Vector2(1, -1):
			direction = PlayerDirection.Direction.UP_RIGHT

		Vector2(1, 0):
			direction = PlayerDirection.Direction.RIGHT

		Vector2(1, 1):
			direction = PlayerDirection.Direction.DOWN_RIGHT

		Vector2(0, 1):
			direction = PlayerDirection.Direction.DOWN

		Vector2(-1, 1):
			direction = PlayerDirection.Direction.DOWN_LEFT

		Vector2(-1, 0):
			direction = PlayerDirection.Direction.LEFT

		Vector2(-1, -1):
			direction = PlayerDirection.Direction.UP_LEFT
