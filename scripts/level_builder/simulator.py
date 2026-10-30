import math

import numpy as np

from models import PlayerState


def advance_player(
    player: PlayerState,
    delta: float,
) -> None:

    direction = player.direction.to_vector()

    player.position = (
        player.position[0] + direction[0] * player.speed * delta,
        player.position[1] + direction[1] * player.speed * delta,
    )


def advance_to(
    player: PlayerState,
    current_time: float,
    target_time: float,
) -> float:

    delta = target_time - current_time

    if delta < 0:
        raise ValueError(
            "Cannot advance player backwards in time."
        )

    advance_player(player, delta)

    return target_time


def sample_segment(
    player: PlayerState,
    start_time: float,
    end_time: float,
    step: float,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Sample the straight path the player follows between two times.

    Returns (times, positions, speeds) without modifying the player.
    """

    count = max(1, math.ceil((end_time - start_time) / step))
    times = np.linspace(start_time, end_time, count + 1)
    direction = np.array(player.direction.to_vector(), dtype=float)
    offsets = (times - start_time)[:, None] * direction * player.speed
    positions = np.array(player.position, dtype=float) + offsets
    speeds = np.full(times.shape, player.speed)

    return times, positions, speeds
