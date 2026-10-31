import math
from enum import Enum


class Direction(Enum):
    UP = (0, -1)
    DOWN = (0, 1)
    LEFT = (-1, 0)
    RIGHT = (1, 0)

    UP_LEFT = (-1, -1)
    UP_RIGHT = (1, -1)
    DOWN_LEFT = (-1, 1)
    DOWN_RIGHT = (1, 1)

    def to_vector(self) -> tuple[int, int]:
        return self.value

    def unit_vector(self) -> tuple[float, float]:
        """Movement direction with length 1, like PlayerDirection.to_vector in Godot."""
        x, y = self.value
        length = math.hypot(x, y)
        return (x / length, y / length)