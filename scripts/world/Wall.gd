class_name Wall
extends StaticBody2D


enum WallRotation {
	HORIZONTAL,
	VERTICAL,
	DIAGONAL_DOWN,
	DIAGONAL_UP
}

var wall_rotation: WallRotation:
	set(value):
		wall_rotation = value
		_apply_rotation()


func _apply_rotation() -> void:
	match wall_rotation:
		WallRotation.HORIZONTAL:
			rotation = 0.0

		WallRotation.VERTICAL:
			rotation = PI / 2.0

		WallRotation.DIAGONAL_DOWN:
			rotation = PI / 4.0

		WallRotation.DIAGONAL_UP:
			rotation = -PI / 4.0
