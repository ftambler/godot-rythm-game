import random
from dataclasses import dataclass

import numpy as np

from bounce import get_bounce
from config import (
    LEVEL_END_BUFFER,
    MAX_LAYOUT_ATTEMPTS,
    OBJECT_CLEARANCE,
    OBJECT_SPAWN_LEAD,
    SIMULATION_STEP,
    SPEED_LEVELS,
)
from models import (
    Action,
    InputEvent,
    Level,
    LevelObject,
    PlayerState,
    WallType,
)
from simulator import advance_to, sample_segment

# How many previous travel directions the wall choice tries to avoid.
RECENT_DIRECTIONS = 3


@dataclass
class TimelineEvent:
    time: float
    kind: str  # "orb", "wall" or "speed"
    speed_level: int | None = None


@dataclass
class ChunkLayout:
    """Objects and player path from one wall up to (not including) the next."""

    objects: list[LevelObject]
    object_positions: np.ndarray
    object_hit_times: np.ndarray
    object_spawn_times: np.ndarray
    sample_times: np.ndarray
    sample_positions: np.ndarray
    sample_speeds: np.ndarray
    end_player: PlayerState


def copy_player(player: PlayerState) -> PlayerState:
    return PlayerState(
        position=player.position,
        direction=player.direction,
        speed=player.speed,
    )


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
    seed: int | None = None,
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

    # Speed changes are given in song time, like the beats.
    level_speed_changes = {
        beat_time - song_start: speed
        for beat_time, speed in (speed_changes or {}).items()
    }

    return generate_level(
        inputs=inputs,
        music=music,
        song_start=song_start,
        song_duration=song_duration,
        initial_player=initial_player,
        speed_changes=level_speed_changes,
        seed=seed,
    )


def build_timeline(
    inputs: list[InputEvent],
    speed_changes: dict[float, int] | None,
    song_duration: float,
) -> list[TimelineEvent]:
    timeline = []

    for event in inputs:
        if event.time > song_duration:
            continue

        kind = "orb" if event.action == Action.ONE else "wall"
        timeline.append(TimelineEvent(time=event.time, kind=kind))

    for time, speed_level in (speed_changes or {}).items():
        if speed_level not in SPEED_LEVELS:
            raise ValueError(
                f"Unknown speed level {speed_level}. "
                f"Valid levels: {sorted(SPEED_LEVELS)}"
            )

        if 0.0 <= time <= song_duration:
            timeline.append(
                TimelineEvent(time=time, kind="speed", speed_level=int(speed_level))
            )

    timeline.sort(key=lambda event: event.time)
    return move_speed_events_into_gaps(timeline, song_duration)


def move_speed_events_into_gaps(
    timeline: list[TimelineEvent],
    song_duration: float,
) -> list[TimelineEvent]:
    """Keep speed triggers off other objects, so they aren't drawn underneath.

    A speed change that lands on (or right next to) an orb or wall is moved
    to the middle of the nearest gap that is long enough, preferring the gap
    before it so the new speed starts just ahead of that beat.
    """

    # Time it takes to cover the clearance distance at the slowest speed.
    separation = OBJECT_CLEARANCE / min(SPEED_LEVELS.values())
    hit_times = [event.time for event in timeline if event.kind != "speed"]
    boundaries = [0.0] + hit_times + [song_duration]

    for event in timeline:
        if event.kind != "speed":
            continue
        if all(abs(event.time - hit_time) >= separation for hit_time in hit_times):
            continue

        gaps = [
            (start + end) / 2
            for start, end in zip(boundaries, boundaries[1:])
            if end - start >= 2 * separation
        ]
        if gaps:
            event.time = min(
                gaps,
                key=lambda middle: (abs(middle - event.time), middle > event.time),
            )

    timeline.sort(key=lambda event: event.time)
    return timeline


def split_into_chunks(timeline: list[TimelineEvent]) -> list[list[TimelineEvent]]:
    """Split the timeline at every wall, since walls are the only choices."""

    chunks: list[list[TimelineEvent]] = [[]]

    for event in timeline:
        if event.kind == "wall":
            chunks.append([])
        chunks[-1].append(event)

    return chunks


def simulate_chunk(
    events: list[TimelineEvent],
    start_time: float,
    end_time: float,
    start_player: PlayerState,
    wall_type: WallType | None,
    group_id: int,
    level_end: float,
) -> ChunkLayout:
    player = copy_player(start_player)
    current_time = start_time

    objects: list[LevelObject] = []
    hit_times: list[float] = []
    sample_times, sample_positions, sample_speeds = [], [], []

    def sample_until(target_time: float) -> float:
        times, positions, speeds = sample_segment(
            player, current_time, target_time, SIMULATION_STEP
        )
        sample_times.append(times)
        sample_positions.append(positions)
        sample_speeds.append(speeds)
        return advance_to(player, current_time, target_time)

    for event in events:
        current_time = sample_until(event.time)

        position = (
            round(player.position[0], 3),
            round(player.position[1], 3),
        )
        spawn_time = max(0.0, event.time - OBJECT_SPAWN_LEAD)

        if event.kind == "wall":
            objects.append(
                LevelObject(
                    type="walls",
                    position=position,
                    wall_type=wall_type,
                    start=spawn_time,
                    end=level_end,
                    group_id=group_id,
                )
            )
            player.direction = get_bounce(player.direction, wall_type)

        elif event.kind == "orb":
            objects.append(
                LevelObject(
                    type="orb",
                    position=position,
                    start=spawn_time,
                    end=level_end,
                    group_id=group_id + 1,
                )
            )

        elif event.kind == "speed":
            objects.append(
                LevelObject(
                    type="speed_trigger",
                    position=position,
                    start=spawn_time,
                    end=level_end,
                    group_id=group_id + 1,
                    speed=event.speed_level,
                )
            )
            player.speed = SPEED_LEVELS[event.speed_level]

        hit_times.append(event.time)

    current_time = sample_until(end_time)

    return ChunkLayout(
        objects=objects,
        object_positions=np.array([obj.position for obj in objects], dtype=float).reshape(-1, 2),
        object_hit_times=np.array(hit_times, dtype=float),
        object_spawn_times=np.array([obj.start for obj in objects], dtype=float),
        sample_times=np.concatenate(sample_times),
        sample_positions=np.concatenate(sample_positions),
        sample_speeds=np.concatenate(sample_speeds),
        end_player=player,
    )


def path_touches_objects(
    times: np.ndarray,
    positions: np.ndarray,
    speeds: np.ndarray,
    object_positions: np.ndarray,
    object_hit_times: np.ndarray,
    object_spawn_times: np.ndarray,
) -> bool:
    if len(times) == 0 or len(object_positions) == 0:
        return False

    distances = np.linalg.norm(
        positions[:, None, :] - object_positions[None, :, :],
        axis=2,
    )
    visible = times[:, None] >= object_spawn_times[None, :]
    # Around its own hit time the player is supposed to be next to the object.
    passing = (
        np.abs(times[:, None] - object_hit_times[None, :]) * speeds[:, None]
        < OBJECT_CLEARANCE * 1.01
    )

    return bool(np.any((distances < OBJECT_CLEARANCE) & visible & ~passing))


def has_conflict(candidate: ChunkLayout, placed: list[ChunkLayout]) -> bool:
    if placed:
        old_positions = np.concatenate([chunk.object_positions for chunk in placed])
        old_hit_times = np.concatenate([chunk.object_hit_times for chunk in placed])
        old_spawn_times = np.concatenate([chunk.object_spawn_times for chunk in placed])

        # The new path must not run into anything placed earlier.
        if path_touches_objects(
            candidate.sample_times,
            candidate.sample_positions,
            candidate.sample_speeds,
            old_positions,
            old_hit_times,
            old_spawn_times,
        ):
            return True

    # The new objects must not sit on any part of the path while visible.
    all_chunks = placed + [candidate]
    return path_touches_objects(
        np.concatenate([chunk.sample_times for chunk in all_chunks]),
        np.concatenate([chunk.sample_positions for chunk in all_chunks]),
        np.concatenate([chunk.sample_speeds for chunk in all_chunks]),
        candidate.object_positions,
        candidate.object_hit_times,
        candidate.object_spawn_times,
    )


def layout_chunks(
    chunks: list[list[TimelineEvent]],
    initial_player: PlayerState,
    level_end: float,
    rng: random.Random,
) -> list[ChunkLayout]:
    """Pick a wall type for every wall so no object overlaps the player path.

    Depth-first search: when no wall type works for a chunk, go back and try
    a different wall type for the previous one.
    """

    placed: list[ChunkLayout] = []
    remaining_options: list[list[WallType | None]] = []
    rejected = 0

    while len(placed) < len(chunks):
        index = len(placed)
        start_player = placed[-1].end_player if placed else initial_player
        start_time = chunks[index][0].time if index > 0 else 0.0
        end_time = chunks[index + 1][0].time if index + 1 < len(chunks) else level_end

        if len(remaining_options) == index:
            if index == 0:
                options = [None]
            else:
                options = get_valid_wall_types(start_player.direction)
                rng.shuffle(options)
                # Options are popped from the end: try directions not used
                # recently first, so the path doesn't zig-zag back and forth.
                recent = {chunk.end_player.direction for chunk in placed[-RECENT_DIRECTIONS:]}
                options.sort(key=lambda wall_type: get_bounce(start_player.direction, wall_type) not in recent)
            remaining_options.append(options)

        layout = None
        while remaining_options[index] and layout is None:
            candidate = simulate_chunk(
                events=chunks[index],
                start_time=start_time,
                end_time=end_time,
                start_player=start_player,
                wall_type=remaining_options[index].pop(),
                group_id=index,
                level_end=level_end,
            )

            if has_conflict(candidate, placed):
                rejected += 1
            else:
                layout = candidate

        if layout is not None:
            placed.append(layout)
            continue

        remaining_options.pop()
        if not placed or rejected >= MAX_LAYOUT_ATTEMPTS:
            raise RuntimeError(
                f"Could not place objects without overlaps around "
                f"t={start_time:.2f}s. Try another --seed, sparser events "
                f"or a smaller OBJECT_CLEARANCE."
            )
        placed.pop()

    return placed


def generate_level(
    inputs: list[InputEvent],
    music: str,
    song_start: float,
    song_duration: float,
    initial_player: PlayerState,
    speed_changes: dict[float, int] | None = None,
    seed: int | None = None,
) -> Level:

    level = Level(
        music=music,
        song_start=song_start,
        song_duration=song_duration + LEVEL_END_BUFFER,
        player=copy_player(initial_player),
    )

    timeline = build_timeline(inputs, speed_changes, song_duration)
    chunks = split_into_chunks(timeline)
    layouts = layout_chunks(
        chunks,
        initial_player,
        level.song_duration,
        random.Random(seed),
    )

    for layout in layouts:
        level.objects.extend(layout.objects)

    return level
