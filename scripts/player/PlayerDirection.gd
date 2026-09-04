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

static func from_vector(vector: Vector2) -> Direction:
	match vector:
		Vector2(0, -1):
			return Direction.UP

		Vector2(1, -1):
			return Direction.UP_RIGHT

		Vector2(1, 0):
			return Direction.RIGHT

		Vector2(1, 1):
			return Direction.DOWN_RIGHT

		Vector2(0, 1):
			return Direction.DOWN

		Vector2(-1, 1):
			return Direction.DOWN_LEFT

		Vector2(-1, 0):
			return Direction.LEFT

		Vector2(-1, -1):
			return Direction.UP_LEFT

	push_error("Invalid player direction: " + str(vector))
	return Direction.DOWN

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
