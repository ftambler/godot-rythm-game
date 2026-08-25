class_name Wall
extends StaticBody2D


enum WallRotation {
	HORIZONTAL,
	VERTICAL,
	DIAGONAL_DOWN,
	DIAGONAL_UP
}

@export var wall_rotation: WallRotation = WallRotation.VERTICAL
