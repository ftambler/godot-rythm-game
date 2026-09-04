from dataclasses import dataclass, field
from enum import Enum

from directions import Direction

WALL_ROTATIONS = [
    "HORIZONTAL",
    "VERTICAL",
    "DIAGONAL_DOWN",
    "DIAGONAL_UP",
]

class WallType(Enum):
    HORIZONTAL = 0
    VERTICAL = 1
    DIAGONAL_DOWN = 2
    DIAGONAL_UP = 3


class Action(Enum):
    ONE = "Action_One"
    TWO = "Action_Two"


@dataclass
class InputEvent:
    time: float
    action: Action


@dataclass
class PlayerState:
    position: tuple[float, float]
    direction: Direction
    speed: float


@dataclass
class LevelObject:
    type: str
    position: tuple[float, float]
    start: float
    end: float
    group_id: int | None = None
    wall_type: str | None = None
    rotation: float | None = None


@dataclass
class Level:
    music: str
    song_start: float
    song_duration: float
    player: PlayerState
    objects: list[LevelObject] = field(default_factory=list)