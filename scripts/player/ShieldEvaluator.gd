class_name ShieldEvaluator
extends RefCounted


static func evaluate(
	wall_rotation: Wall.WallRotation,
	movement_direction: PlayerDirection.Direction,
	shield_direction: PlayerDirection.Direction,
	shield_active: bool
) -> HitResult.Type:

	if not shield_active:
		return HitResult.Type.MISS

	var expected_direction := get_expected_shield_direction(
		wall_rotation,
		movement_direction
	)

	if shield_direction == expected_direction:
		return HitResult.Type.FULL

	if is_half_shield(expected_direction, shield_direction):
		return HitResult.Type.HALF

	return HitResult.Type.MISS


static func get_expected_shield_direction(
	wall_rotation: Wall.WallRotation,
	movement_direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match wall_rotation:
		Wall.WallRotation.HORIZONTAL:
			return get_horizontal_shield(movement_direction)

		Wall.WallRotation.VERTICAL:
			return get_vertical_shield(movement_direction)

		Wall.WallRotation.DIAGONAL_DOWN:
			return get_diagonal_down_shield(movement_direction)

		Wall.WallRotation.DIAGONAL_UP:
			return get_diagonal_up_shield(movement_direction)

	return movement_direction


static func get_horizontal_shield(
	movement_direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match movement_direction:
		PlayerDirection.Direction.UP, PlayerDirection.Direction.UP_LEFT, PlayerDirection.Direction.UP_RIGHT:
			return PlayerDirection.Direction.UP

		PlayerDirection.Direction.DOWN, PlayerDirection.Direction.DOWN_LEFT, PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.DOWN

	return movement_direction


static func get_vertical_shield(
	movement_direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match movement_direction:
		PlayerDirection.Direction.LEFT, PlayerDirection.Direction.UP_LEFT, PlayerDirection.Direction.DOWN_LEFT:
			return PlayerDirection.Direction.LEFT

		PlayerDirection.Direction.RIGHT, PlayerDirection.Direction.UP_RIGHT, PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.RIGHT

	return movement_direction


static func get_diagonal_down_shield(
	movement_direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match movement_direction:
		PlayerDirection.Direction.UP, PlayerDirection.Direction.UP_RIGHT, PlayerDirection.Direction.UP_LEFT:
			return PlayerDirection.Direction.UP_RIGHT

		PlayerDirection.Direction.RIGHT, PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.DOWN_RIGHT

		PlayerDirection.Direction.DOWN, PlayerDirection.Direction.DOWN_LEFT:
			return PlayerDirection.Direction.DOWN_LEFT

		PlayerDirection.Direction.LEFT:
			return PlayerDirection.Direction.UP_LEFT

	return movement_direction


static func get_diagonal_up_shield(
	movement_direction: PlayerDirection.Direction
) -> PlayerDirection.Direction:

	match movement_direction:
		PlayerDirection.Direction.UP, PlayerDirection.Direction.UP_LEFT:
			return PlayerDirection.Direction.UP_LEFT

		PlayerDirection.Direction.UP_RIGHT, PlayerDirection.Direction.RIGHT:
			return PlayerDirection.Direction.UP_RIGHT

		PlayerDirection.Direction.DOWN, PlayerDirection.Direction.DOWN_RIGHT:
			return PlayerDirection.Direction.DOWN_RIGHT

		PlayerDirection.Direction.DOWN_LEFT, PlayerDirection.Direction.LEFT:
			return PlayerDirection.Direction.DOWN_LEFT

	return movement_direction


static func is_half_shield(
	expected_direction: PlayerDirection.Direction,
	actual_direction: PlayerDirection.Direction
) -> bool:

	var difference: int = abs(expected_direction - actual_direction)

	return difference == 1 or difference == 7
