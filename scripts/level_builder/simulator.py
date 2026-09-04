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