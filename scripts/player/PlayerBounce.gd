class_name PlayerBounce
extends RefCounted


static func get_bounce(
	movement_direction: PlayerDirection.Direction,
	wall_rotation: Wall.WallRotation
) -> PlayerDirection.Direction:

	match wall_rotation:
		Wall.WallRotation.HORIZONTAL:
			return horizontal(movement_direction)

		Wall.WallRotation.VERTICAL:
			return vertical(movement_direction)

		Wall.WallRotation.DIAGONAL_DOWN:
			return diagonal_down(movement_direction)

		Wall.WallRotation.DIAGONAL_UP:
			return diagonal_up(movement_direction)

	return movement_direction

static func diagonal_up(
	direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match direction:
		PlayerDirection.Direction.UP:
			return PlayerDirection.Direction.RIGHT

		PlayerDirection.Direction.RIGHT:
			return PlayerDirection.Direction.UP

		PlayerDirection.Direction.LEFT:
			return PlayerDirection.Direction.DOWN

		PlayerDirection.Direction.DOWN:
			return PlayerDirection.Direction.LEFT

		PlayerDirection.Direction.UP_LEFT:
			return PlayerDirection.Direction.DOWN_RIGHT

		PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.UP_LEFT

	return direction

static func diagonal_down(
	direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match direction:
		PlayerDirection.Direction.UP:
			return PlayerDirection.Direction.LEFT

		PlayerDirection.Direction.LEFT:
			return PlayerDirection.Direction.UP

		PlayerDirection.Direction.RIGHT:
			return PlayerDirection.Direction.DOWN

		PlayerDirection.Direction.DOWN:
			return PlayerDirection.Direction.RIGHT

		PlayerDirection.Direction.UP_RIGHT:
			return PlayerDirection.Direction.DOWN_LEFT

		PlayerDirection.Direction.DOWN_LEFT:
			return PlayerDirection.Direction.UP_RIGHT

	return direction

static func vertical(
	direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match direction:
		PlayerDirection.Direction.LEFT:
			return PlayerDirection.Direction.RIGHT

		PlayerDirection.Direction.RIGHT:
			return PlayerDirection.Direction.LEFT

		PlayerDirection.Direction.UP_LEFT:
			return PlayerDirection.Direction.UP_RIGHT

		PlayerDirection.Direction.UP_RIGHT:
			return PlayerDirection.Direction.UP_LEFT

		PlayerDirection.Direction.DOWN_LEFT:
			return PlayerDirection.Direction.DOWN_RIGHT

		PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.DOWN_LEFT

	return direction

static func horizontal(
	direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match direction:
		PlayerDirection.Direction.UP:
			return PlayerDirection.Direction.DOWN

		PlayerDirection.Direction.DOWN:
			return PlayerDirection.Direction.UP

		PlayerDirection.Direction.UP_RIGHT:
			return PlayerDirection.Direction.DOWN_RIGHT

		PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.UP_RIGHT

		PlayerDirection.Direction.UP_LEFT:
			return PlayerDirection.Direction.DOWN_LEFT

		PlayerDirection.Direction.DOWN_LEFT:
			return PlayerDirection.Direction.UP_LEFT

	return direction
