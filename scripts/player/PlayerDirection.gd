class_name PlayerDirection
extends RefCounted


enum Direction {
	UP,
	UP_RIGHT,
	RIGHT,
	DOWN_RIGHT,
	DOWN,
	DOWN_LEFT,
	LEFT,
	UP_LEFT
}


static func to_vector(direction: Direction) -> Vector2:
	match direction:
		Direction.UP:
			return Vector2.UP

		Direction.UP_RIGHT:
			return Vector2(1, -1).normalized()

		Direction.RIGHT:
			return Vector2.RIGHT

		Direction.DOWN_RIGHT:
			return Vector2(1, 1).normalized()

		Direction.DOWN:
			return Vector2.DOWN

		Direction.DOWN_LEFT:
			return Vector2(-1, 1).normalized()

		Direction.LEFT:
			return Vector2.LEFT

		Direction.UP_LEFT:
			return Vector2(-1, -1).normalized()

	return Vector2.ZERO
