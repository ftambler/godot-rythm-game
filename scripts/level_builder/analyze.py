"""Build a chart from a song using beat tracking and onset strength."""

import bisect
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from chart import Chart
from models import Action, InputEvent

SAMPLE_RATE = 22050
HOP_LENGTH = 512
# Onset envelope peaks trail the actual attack by about this much (seconds);
# measured with the synthetic click track in test_analyze.py.
ONSET_LATENCY = 0.026
# Seconds around a grid point to look for the attack peak.
PEAK_WINDOW = 0.05
# Beats on each side used to judge how strong a hit is compared to its context.
LOCAL_WINDOW_BEATS = 16
# Mel bands (out of 128) treated as "low end" (kicks, bass, snare body).
LOW_BAND_MELS = 12
# Below this share of the median loudness the song counts as silent.
SILENCE_RATIO = 0.25
BEATS_PER_BAR = 4
# Speed sections shorter than this are merged into their neighbours.
MIN_SECTION_BARS = 4
# Songs whose loudness varies less than this (relative) get no speed changes.
MIN_DYNAMIC_RANGE = 0.15
# Minimum beats between two walls, so wall clusters don't overlap.
MIN_WALL_GAP_BEATS = 0.5
# Most orbs in a row before one becomes a wall (keeps the path from going straight forever).
MAX_ORB_RUN = 4
# Never place two events closer than this (seconds), whatever the tempo.
MIN_REACTION_TIME = 0.1
# Grid point weights by position inside the beat: on-beat hits are favoured.
ON_BEAT_WEIGHT = 1.0
HALF_BEAT_WEIGHT = 0.85
OFF_BEAT_WEIGHT = 0.7


@dataclass(frozen=True)
class DifficultySettings:
    subdivisions: int     # grid points per beat
    density: float        # target events per beat (more in loud parts, fewer in quiet ones)
    min_gap_beats: float  # minimum beats between two events
    max_gap_beats: float  # fill silences longer than this (unless the song is silent)
    wall_fraction: float  # share of events that become walls
    max_speed_level: int


DIFFICULTIES = {
    "easy": DifficultySettings(
        subdivisions=2, density=0.75, min_gap_beats=1,
        max_gap_beats=2, wall_fraction=0.3, max_speed_level=2,
    ),
    "normal": DifficultySettings(
        subdivisions=4, density=1.25, min_gap_beats=0.5,
        max_gap_beats=1.5, wall_fraction=0.4, max_speed_level=3,
    ),
    "hard": DifficultySettings(
        subdivisions=4, density=1.6, min_gap_beats=0.25,
        max_gap_beats=1, wall_fraction=0.45, max_speed_level=3,
    ),
}


@dataclass
class GridPoint:
    time: float
    strength: float      # 0-1 rank of the hit among its neighbours, weighted by position
    low_strength: float  # same, for the low end only
    loudness_rank: float # 0 = quietest part of the song, 1 = loudest
    silent: bool


def analyze_song(
    audio_path: str | Path,
    difficulty: str = "normal",
    song_start: float = 0.0,
    duration: float | None = None,
    bpm_hint: float | None = None,
) -> Chart:
    import librosa

    if difficulty not in DIFFICULTIES:
        raise ValueError(f"Unknown difficulty '{difficulty}'. Use one of {sorted(DIFFICULTIES)}.")
    settings = DIFFICULTIES[difficulty]

    audio_path = Path(audio_path)
    y, sr = librosa.load(
        audio_path,
        sr=SAMPLE_RATE,
        mono=True,
        offset=song_start,
        duration=duration,
    )
    song_duration = len(y) / sr

    onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=HOP_LENGTH)
    low_env = librosa.onset.onset_strength_multi(
        y=y,
        sr=sr,
        hop_length=HOP_LENGTH,
        channels=[0, LOW_BAND_MELS],
    )[0]
    rms = librosa.feature.rms(y=y, hop_length=HOP_LENGTH)[0]

    # The median envelope (librosa's default for beat tracking) locks onto the
    # tempo more reliably; the mean one above is better for judging hit strength.
    beat_env = librosa.onset.onset_strength(
        y=y, sr=sr, hop_length=HOP_LENGTH, aggregate=np.median
    )
    tempo, beat_frames = librosa.beat.beat_track(
        onset_envelope=beat_env,
        sr=sr,
        hop_length=HOP_LENGTH,
        start_bpm=bpm_hint or 120.0,
        # Keep beats in quiet intros/outros; silent parts are skipped later.
        trim=False,
    )
    beat_times = librosa.frames_to_time(beat_frames, sr=sr, hop_length=HOP_LENGTH) - ONSET_LATENCY
    beat_times = beat_times[beat_times >= 0]

    if len(beat_times) < 2:
        raise RuntimeError(f"Could not find a beat in {audio_path}.")

    # The tempo estimate is coarsely binned and single beat gaps are rounded
    # to whole frames, so average the gaps (ignoring tracking glitches).
    intervals = np.diff(beat_times)
    typical = float(np.median(intervals))
    steady = intervals[np.abs(intervals - typical) < 0.25 * typical]
    bpm = 60.0 / float(steady.mean())

    frame_times = librosa.frames_to_time(np.arange(len(onset_env)), sr=sr, hop_length=HOP_LENGTH) - ONSET_LATENCY
    grid = build_grid(beat_times, settings.subdivisions, frame_times, onset_env, low_env, rms)

    times = select_events(grid, settings, beat_duration=60.0 / bpm)
    inputs = classify_events(grid, times, settings.wall_fraction, beat_duration=60.0 / bpm)
    start_speed_level, speed_changes = find_speed_sections(
        beat_times, frame_times, rms, settings.max_speed_level
    )

    return Chart(
        music=audio_path.name,
        song_start=song_start,
        song_duration=round(song_duration, 3),
        bpm=round(bpm, 2),
        difficulty=difficulty,
        start_speed_level=start_speed_level,
        inputs=inputs,
        speed_changes=speed_changes,
    )


def peak_near(env: np.ndarray, frame_times: np.ndarray, time: float) -> float:
    start = bisect.bisect_left(frame_times, time - PEAK_WINDOW)
    end = bisect.bisect_right(frame_times, time + PEAK_WINDOW)
    return float(env[start:end].max()) if end > start else 0.0


def rank_in_context(values: np.ndarray, points_per_side: int) -> np.ndarray:
    """Share of neighbouring values each value beats (0 = weakest, 1 = strongest).

    Ranking instead of comparing raw strengths keeps heavily compressed
    songs, where every hit is about as loud, from flattening out.
    """

    result = np.zeros_like(values)
    for i in range(len(values)):
        window = values[max(0, i - points_per_side): i + points_per_side + 1]
        result[i] = float((window < values[i]).mean())
    return result


def build_grid(
    beat_times: np.ndarray,
    subdivisions: int,
    frame_times: np.ndarray,
    onset_env: np.ndarray,
    low_env: np.ndarray,
    rms: np.ndarray,
) -> list[GridPoint]:
    times, weights = [], []

    for beat, next_beat in zip(beat_times[:-1], beat_times[1:]):
        step = (next_beat - beat) / subdivisions
        for k in range(subdivisions):
            times.append(beat + k * step)
            if k == 0:
                weights.append(ON_BEAT_WEIGHT)
            elif k * 2 == subdivisions:
                weights.append(HALF_BEAT_WEIGHT)
            else:
                weights.append(OFF_BEAT_WEIGHT)
    times.append(beat_times[-1])
    weights.append(ON_BEAT_WEIGHT)

    weights = np.array(weights)
    raw = np.array([peak_near(onset_env, frame_times, t) for t in times]) * weights
    raw_low = np.array([peak_near(low_env, frame_times, t) for t in times]) * weights
    loudness = np.array([peak_near(rms, frame_times, t) for t in times])

    context = LOCAL_WINDOW_BEATS * subdivisions
    strength = rank_in_context(raw, context)
    low_strength = rank_in_context(raw_low, context)

    silence_level = SILENCE_RATIO * float(np.median(rms))
    loudness_rank = loudness.argsort().argsort() / max(1, len(loudness) - 1)

    return [
        GridPoint(
            time=float(times[i]),
            strength=float(strength[i]),
            low_strength=float(low_strength[i]),
            loudness_rank=float(loudness_rank[i]),
            silent=bool(loudness[i] < silence_level),
        )
        for i in range(len(times))
    ]


def fits(selected: list[float], time: float, min_gap: float) -> bool:
    index = bisect.bisect_left(selected, time)
    if index > 0 and time - selected[index - 1] < min_gap:
        return False
    if index < len(selected) and selected[index] - time < min_gap:
        return False
    return True


def select_events(
    grid: list[GridPoint],
    settings: DifficultySettings,
    beat_duration: float,
) -> list[float]:
    selected: list[float] = []
    min_gap = max(settings.min_gap_beats * beat_duration, MIN_REACTION_TIME)

    # Strongest hits first, so the min gap never drops a strong hit for a weak one.
    # Loud parts of the song keep more of their hits, quiet parts fewer.
    for point in sorted(grid, key=lambda p: p.strength, reverse=True):
        keep_share = settings.density / settings.subdivisions * (0.7 + 0.6 * point.loudness_rank)
        if point.silent or point.strength < 1.0 - keep_share:
            continue
        if fits(selected, point.time, min_gap):
            bisect.insort(selected, point.time)

    # Fill long empty stretches with the best hit available inside them.
    max_gap = settings.max_gap_beats * beat_duration
    candidates = sorted(
        (p for p in grid if not p.silent),
        key=lambda p: p.strength,
        reverse=True,
    )
    for point in candidates:
        index = bisect.bisect_left(selected, point.time)
        previous_time = selected[index - 1] if index > 0 else None
        next_time = selected[index] if index < len(selected) else None
        in_long_gap = (
            previous_time is not None
            and next_time is not None
            and next_time - previous_time > max_gap
        )
        if in_long_gap and fits(selected, point.time, min_gap):
            bisect.insort(selected, point.time)

    return selected


def classify_events(
    grid: list[GridPoint],
    times: list[float],
    wall_fraction: float,
    beat_duration: float,
) -> list[InputEvent]:
    by_time = {point.time: point for point in grid}
    points = [by_time[time] for time in times]

    # Walls are 80px long: closer than this they would overlap each other.
    min_wall_gap = MIN_WALL_GAP_BEATS * beat_duration
    wall_times: list[float] = []

    def add_wall(time: float) -> bool:
        if not fits(wall_times, time, min_wall_gap):
            return False
        bisect.insort(wall_times, time)
        return True

    # Punchiest low-end hits first; a hit too close to a stronger wall stays an orb.
    wall_count = round(len(points) * wall_fraction)
    for point in sorted(points, key=lambda p: p.low_strength, reverse=True):
        if len(wall_times) >= wall_count:
            break
        add_wall(point.time)

    # Long runs of orbs are long straight lines; turn the punchiest orb of an
    # over-long run that has room for it into a wall.
    run: list[GridPoint] = []
    for point in points:
        if point.time in wall_times:
            run = []
            continue
        run.append(point)
        if len(run) > MAX_ORB_RUN:
            for candidate in sorted(run, key=lambda p: p.low_strength, reverse=True):
                if add_wall(candidate.time):
                    run = run[run.index(candidate) + 1:]
                    break

    return [
        InputEvent(
            time=round(point.time, 3),
            action=Action.TWO if point.time in wall_times else Action.ONE,
        )
        for point in points
    ]


def find_speed_sections(
    beat_times: np.ndarray,
    frame_times: np.ndarray,
    rms: np.ndarray,
    max_speed_level: int,
) -> tuple[int, dict[float, int]]:
    """Map loudness per bar to speed levels: louder sections play faster."""

    bar_starts = beat_times[::BEATS_PER_BAR]
    bar_ends = list(bar_starts[1:]) + [frame_times[-1]]

    bar_energy = []
    for start, end in zip(bar_starts, bar_ends):
        mask = (frame_times >= start) & (frame_times < end)
        bar_energy.append(float(rms[mask].mean()) if mask.any() else 0.0)
    bar_energy = np.array(bar_energy)

    silence_level = SILENCE_RATIO * float(np.median(rms))
    audible = bar_energy[bar_energy >= silence_level]
    if len(audible) == 0:
        return 1, {}

    quiet, loud = np.percentile(audible, [10, 90])
    if loud <= 0 or (loud - quiet) / loud < MIN_DYNAMIC_RANGE:
        return 1, {}

    # Three equal-width loudness bands, so a song that is half quiet and half
    # loud maps to slow and fast instead of being split into thirds.
    low_cut = quiet + (loud - quiet) / 3
    high_cut = quiet + 2 * (loud - quiet) / 3
    levels = [
        min(max_speed_level, 1 + int(energy > low_cut) + int(energy > high_cut))
        for energy in bar_energy
    ]
    levels = merge_short_sections(levels, MIN_SECTION_BARS)

    speed_changes = {}
    for i in range(1, len(levels)):
        if levels[i] != levels[i - 1]:
            speed_changes[round(float(bar_starts[i]), 3)] = levels[i]

    return levels[0] if levels else 1, speed_changes


def merge_short_sections(levels: list[int], min_length: int) -> list[int]:
    levels = list(levels)

    changed = True
    while changed:
        changed = False
        runs = []
        start = 0
        for i in range(1, len(levels) + 1):
            if i == len(levels) or levels[i] != levels[start]:
                runs.append((start, i))
                start = i

        if len(runs) < 2:
            break

        for index, (start, end) in enumerate(runs):
            if end - start >= min_length:
                continue
            neighbour = runs[index - 1] if index > 0 else runs[index + 1]
            levels[start:end] = [levels[neighbour[0]]] * (end - start)
            changed = True
            break

    return levels

