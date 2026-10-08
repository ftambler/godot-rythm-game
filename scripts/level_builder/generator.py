import random

from bounce import get_bounce
from config import LEVEL_END_BUFFER, OBJECT_SPAWN_LEAD
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


def generate_beat_events(
    duration: float,
    bpm: float,
    start_time: float = 0.0,
) -> list[float]:
    if duration <= 0 or bpm <= 0:
        return []

    beat_duration = 60.0 / bpm
    times = []
    current_time = start_time

    while current_time <= duration + 1e-9:
        times.append(round(current_time, 3))
        current_time += beat_duration

    return times


def generate_level_from_bpm(
    music: str,
    song_start: float,
    song_duration: float,
    bpm: float,
    initial_player: PlayerState,
    pattern: list[str] | None = None,
    speed_changes: dict[float, int] | None = None,
) -> Level:
    if bpm <= 0:
        raise ValueError("bpm must be greater than zero.")
    if pattern is None:
        pattern = ["orb", "wall"]

    beat_times = generate_beat_events(
        duration=song_duration,
        bpm=bpm,
        start_time=song_start,
    )

    inputs: list[InputEvent] = []
    for i, beat_time in enumerate(beat_times):
        event_type = pattern[i % len(pattern)]

        if event_type == "orb":
            inputs.append(InputEvent(time=beat_time - song_start, action=Action.ONE))
        elif event_type == "wall":
            inputs.append(InputEvent(time=beat_time - song_start, action=Action.TWO))

    level = generate_level(
        inputs=inputs,
        music=music,
        song_start=song_start,
        song_duration=song_duration,
        initial_player=initial_player,
    )

    speed_changes = speed_changes or {}
    current_group_id = max(
        (obj.group_id for obj in level.objects if obj.group_id is not None),
        default=0,
    ) + 1

    for beat_time, speed in sorted(speed_changes.items()):
        if beat_time < song_start or beat_time > song_start + song_duration:
            continue

        level.objects.append(
            LevelObject(
                type="speed_trigger",
                position=level.player.position,
                start=max(0.0, (beat_time - song_start) - OBJECT_SPAWN_LEAD),
                end=level.song_duration,
                group_id=current_group_id,
                speed=int(speed),
            )
        )
        current_group_id += 1

    return level


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
        song_duration=song_duration + LEVEL_END_BUFFER,
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
                    start=max(0.0, event.time - OBJECT_SPAWN_LEAD),
                    end=level.song_duration,
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
                    start=max(0.0, event.time - OBJECT_SPAWN_LEAD),
                    end=level.song_duration,
                    group_id=group_id,
                )
            )

            player.direction = get_bounce(
                player.direction,
                wall_type,
            )

            group_id += 1

    level.player = PlayerState(
        position=initial_player.position,
        direction=initial_player.direction,
        speed=initial_player.speed,
    )

    return level
