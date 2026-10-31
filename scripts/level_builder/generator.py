import random
from dataclasses import dataclass

import numpy as np

from bounce import get_bounce
from config import (
    LEVEL_END_BUFFER,
    OBJECT_DESPAWN_DELAY,
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

# Seconds of already placed path re-checked together with each new chunk:
# enough to cover every object that can still be on screen.
CONFLICT_LOOKBACK = max(OBJECT_SPAWN_LEAD, OBJECT_DESPAWN_DELAY) + 0.25
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
    object_end_times: np.ndarray
    sample_times: np.ndarray
    sample_positions: np.ndarray
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
    sample_times, sample_positions = [], []

    def sample_until(target_time: float) -> float:
        times, positions = sample_segment(
            player, current_time, target_time, SIMULATION_STEP
        )
        sample_times.append(times)
        sample_positions.append(positions)
        return advance_to(player, current_time, target_time)

    for event in events:
        current_time = sample_until(event.time)

        position = (
            round(player.position[0], 3),
            round(player.position[1], 3),
        )
        spawn_time = max(0.0, event.time - OBJECT_SPAWN_LEAD)
        # Gone shortly after its beat, so a missed orb doesn't linger and the
        # path is free to cross this spot again later.
        despawn_time = min(level_end, event.time + OBJECT_DESPAWN_DELAY)

        if event.kind == "wall":
            objects.append(
                LevelObject(
                    type="walls",
                    position=position,
                    wall_type=wall_type,
                    start=spawn_time,
                    end=despawn_time,
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
                    end=despawn_time,
                    group_id=group_id + 1,
                )
            )

        elif event.kind == "speed":
            objects.append(
                LevelObject(
                    type="speed_trigger",
                    position=position,
                    start=spawn_time,
                    end=despawn_time,
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
        object_end_times=np.array([obj.end for obj in objects], dtype=float),
        sample_times=np.concatenate(sample_times),
        sample_positions=np.concatenate(sample_positions),
        end_player=player,
    )


def path_touches_objects(
    times: np.ndarray,
    positions: np.ndarray,
    object_positions: np.ndarray,
    object_hit_times: np.ndarray,
    object_spawn_times: np.ndarray,
    object_end_times: np.ndarray,
) -> bool:
    """Whether the path comes near a visible object other than when hitting it.

    Being near an object is fine during the one continuous visit in which the
    player hits it (approaching, touching, leaving). Coming back to it later,
    or passing it before its hit while it's on screen, is a collision.
    """

    if len(times) == 0 or len(object_positions) == 0:
        return False

    distances = np.linalg.norm(
        positions[:, None, :] - object_positions[None, :, :],
        axis=2,
    )
    visible = (
        (times[:, None] >= object_spawn_times[None, :])
        & (times[:, None] <= object_end_times[None, :])
    )
    near = (distances < OBJECT_CLEARANCE) & visible

    # Number each stretch of consecutive "near" / "not near" samples per object.
    changes = np.diff(near.astype(np.int8), axis=0) != 0
    visit_ids = np.vstack([
        np.zeros((1, near.shape[1]), dtype=np.int64),
        np.cumsum(changes, axis=0),
    ])

    # The visit that contains the hit is allowed, if the hit is in these samples.
    covered = (object_hit_times >= times[0]) & (object_hit_times <= times[-1])
    hit_indices = np.clip(np.searchsorted(times, object_hit_times), 0, len(times) - 1)
    hit_visits = visit_ids[hit_indices, np.arange(near.shape[1])]
    hitting_visit = (visit_ids == hit_visits[None, :]) & covered[None, :]

    return bool(np.any(near & ~hitting_visit))


def objects_overlap_on_screen(candidate: ChunkLayout, recent: list[ChunkLayout]) -> bool:
    """Whether a new object sits on another one while both are visible.

    Quick back-to-back hits are next to each other by nature and allowed.
    """

    if len(candidate.object_positions) == 0:
        return False

    others = recent + [candidate]
    positions = np.concatenate([chunk.object_positions for chunk in others])
    hits = np.concatenate([chunk.object_hit_times for chunk in others])
    spawns = np.concatenate([chunk.object_spawn_times for chunk in others])
    ends = np.concatenate([chunk.object_end_times for chunk in others])

    distances = np.linalg.norm(
        candidate.object_positions[:, None, :] - positions[None, :, :],
        axis=2,
    )
    both_visible = (
        np.maximum(candidate.object_spawn_times[:, None], spawns[None, :])
        < np.minimum(candidate.object_end_times[:, None], ends[None, :])
    )
    back_to_back = (
        np.abs(candidate.object_hit_times[:, None] - hits[None, :])
        < OBJECT_CLEARANCE / min(SPEED_LEVELS.values())
    )

    return bool(np.any((distances < OBJECT_CLEARANCE) & both_visible & ~back_to_back))


def has_conflict(candidate: ChunkLayout, placed: list[ChunkLayout]) -> bool:
    """Whether the candidate's path or objects collide with what is on screen.

    Objects only exist from OBJECT_SPAWN_LEAD before their beat until
    OBJECT_DESPAWN_DELAY after it, so only the last stretch of the level can
    interact with the candidate.
    """

    window_start = candidate.sample_times[0] - CONFLICT_LOOKBACK
    recent = [candidate]
    for chunk in reversed(placed):
        if chunk.sample_times[-1] < window_start:
            break
        recent.insert(0, chunk)

    if objects_overlap_on_screen(candidate, recent[:-1]):
        return True

    # Whole chunks only: cutting one would hide the hit of an object the player
    # is still moving away from, making that look like a second visit.
    return path_touches_objects(
        np.concatenate([chunk.sample_times for chunk in recent]),
        np.concatenate([chunk.sample_positions for chunk in recent]),
        np.concatenate([chunk.object_positions for chunk in recent]),
        np.concatenate([chunk.object_hit_times for chunk in recent]),
        np.concatenate([chunk.object_spawn_times for chunk in recent]),
        np.concatenate([chunk.object_end_times for chunk in recent]),
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
