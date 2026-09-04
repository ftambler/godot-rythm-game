from directions import Direction
from models import WallType


def get_required_shield(
    direction: Direction,
    wall_type: WallType,
) -> Direction:
    """
    Returns the shield direction required to successfully
    interact with this wall.

    TODO:
    Mirror ShieldEvaluator.gd once its implementation is provided.
    """
    raise NotImplementedError