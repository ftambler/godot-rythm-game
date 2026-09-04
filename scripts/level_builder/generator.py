import random

from bounce import get_bounce
from models import (
    Action,
    InputEvent,
    Level,
    LevelObject,
    PlayerState,
    WallType,
)
from simulator import advance_to


def get_valid_wall_types(direction) -> list[WallType]:

    valid = []

    for wall_type in WallType:

        bounced_direction = get_bounce(
            direction,
            wall_type,
        )

        if bounced_direction != direction:
            valid.append(wall_type)

    return valid


def generate_level(
    inputs: list[InputEvent],
    music: str,
    song_start: float,
    song_duration: float,
    initial_player: PlayerState,
) -> Level:

    player = PlayerState(
        position=initial_player.position,
        direction=initial_player.direction,
        speed=initial_player.speed,
    )

    level = Level(
        music=music,
        song_start=song_start,
        song_duration=song_duration,
        player=PlayerState(
            position=player.position,
            direction=player.direction,
            speed=player.speed,
        ),
    )

    current_time = 0.0
    group_id = 1

    for event in inputs:

        if event.time > song_duration:
            break

        current_time = advance_to(
            player,
            current_time,
            event.time,
        )

        if event.action == Action.ONE:
            level.objects.append(
                LevelObject(
                    type="orb",
                    position=player.position,
                    start=event.time,
                    end=song_duration,
                    group_id=group_id,
                )
            )

        elif event.action == Action.TWO:

            valid_wall_types = get_valid_wall_types(
                player.direction
            )

            if not valid_wall_types:
                raise RuntimeError(
                    f"No valid wall type for "
                    f"{player.direction.name}"
                )

            wall_type = random.choice(valid_wall_types)

            level.objects.append(
                LevelObject(
                    type="walls",
                    position=player.position,
                    wall_type=wall_type,
                    start=event.time,
                    end=song_duration,
                    group_id=group_id,
                )
            )

            player.direction = get_bounce(
                player.direction,
                wall_type,
            )

            group_id += 1

    return level