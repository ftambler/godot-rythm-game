from directions import Direction
from models import WallType


def get_bounce(
    direction: Direction,
    wall_type: WallType,
) -> Direction:

    match wall_type:
        case WallType.HORIZONTAL:
            return horizontal(direction)

        case WallType.VERTICAL:
            return vertical(direction)

        case WallType.DIAGONAL_DOWN:
            return diagonal_down(direction)

        case WallType.DIAGONAL_UP:
            return diagonal_up(direction)

    return direction


def diagonal_up(direction: Direction) -> Direction:

    match direction:
        case Direction.UP:
            return Direction.RIGHT

        case Direction.RIGHT:
            return Direction.UP

        case Direction.LEFT:
            return Direction.DOWN

        case Direction.DOWN:
            return Direction.LEFT

        case Direction.UP_LEFT:
            return Direction.DOWN_RIGHT

        case Direction.DOWN_RIGHT:
            return Direction.UP_LEFT

    return direction


def diagonal_down(direction: Direction) -> Direction:

    match direction:
        case Direction.UP:
            return Direction.LEFT

        case Direction.LEFT:
            return Direction.UP

        case Direction.RIGHT:
            return Direction.DOWN

        case Direction.DOWN:
            return Direction.RIGHT

        case Direction.UP_RIGHT:
            return Direction.DOWN_LEFT

        case Direction.DOWN_LEFT:
            return Direction.UP_RIGHT

    return direction


def vertical(direction: Direction) -> Direction:

    match direction:
        case Direction.LEFT:
            return Direction.RIGHT

        case Direction.RIGHT:
            return Direction.LEFT

        case Direction.UP_LEFT:
            return Direction.UP_RIGHT

        case Direction.UP_RIGHT:
            return Direction.UP_LEFT

        case Direction.DOWN_LEFT:
            return Direction.DOWN_RIGHT

        case Direction.DOWN_RIGHT:
            return Direction.DOWN_LEFT

    return direction


def horizontal(direction: Direction) -> Direction:

    match direction:
        case Direction.UP:
            return Direction.DOWN

        case Direction.DOWN:
            return Direction.UP

        case Direction.UP_RIGHT:
            return Direction.DOWN_RIGHT

        case Direction.DOWN_RIGHT:
            return Direction.UP_RIGHT

        case Direction.UP_LEFT:
            return Direction.DOWN_LEFT

        case Direction.DOWN_LEFT:
            return Direction.UP_LEFT

    return direction