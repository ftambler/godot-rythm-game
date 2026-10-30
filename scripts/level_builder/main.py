import argparse
import time
from pathlib import Path

try:
    import keyboard
except ImportError:  # pragma: no cover - optional for non-recording mode
    keyboard = None

from analyze import DIFFICULTIES, analyze_song
from config import (
    LEVEL_DURATION,
    LEVEL_NAME,
    SONG_START,
    START_DIRECTION,
    START_POSITION,
    START_SPEED,
    PREDICT_TIME,
    SPEED_LEVELS,
)
from chart import Chart, load_chart, save_chart
from directions import Direction
from generator import generate_beat_events, generate_level, generate_level_from_bpm
from models import Action, InputEvent, PlayerState
from serializer import build_json, save_level
from visualizer import visualize_level


KEY_MAP = {
    "f": Action.ONE,
    "j": Action.TWO,
}


def record_inputs(duration: float) -> list[InputEvent]:
    if keyboard is None:
        raise RuntimeError(
            "Live input recording requires the 'keyboard' package. "
            "Use BPM mode instead: python main.py --bpm 120 --duration 8 --pattern orb wall"
        )

    inputs = []

    start_time = time.time()
    end_time = start_time + duration

    def on_key_event(event):
        if event.event_type != keyboard.KEY_DOWN:
            return

        action = KEY_MAP.get(event.name)
        if action is None:
            return

        relative_time = max(time.time() - start_time - PREDICT_TIME, 0)
        inputs.append(
            InputEvent(
                time=round(relative_time, 3),
                action=action,
            )
        )

    keyboard.hook(on_key_event)

    try:
        while time.time() < end_time:
            time.sleep(1 / 240)
    finally:
        keyboard.unhook_all()

    return inputs


LEVELS_DIRECTORY = Path(__file__).resolve().parents[2] / "levels"
AUDIO_DIRECTORY = Path(__file__).resolve().parents[2] / "audio"
CHARTS_DIRECTORY = Path(__file__).resolve().parent / "charts"


def start_player(speed: float = START_SPEED) -> PlayerState:
    return PlayerState(
        position=START_POSITION,
        direction=Direction[START_DIRECTION],
        speed=speed,
    )


def save_level_files(level, level_name: str) -> Path:
    json_path = save_level(build_json(level), level_name, output_dir=LEVELS_DIRECTORY)
    preview_path = json_path.with_suffix(".png")
    visualize_level(json_path, preview_path)
    return json_path


def build_level_from_bpm(
    level_name: str,
    duration: float,
    bpm: float,
    pattern: list[str] | None = None,
    speed_changes: dict[float, int] | None = None,
    seed: int | None = None,
):
    level = generate_level_from_bpm(
        music=f"{level_name}.mp3",
        song_start=SONG_START,
        song_duration=duration,
        bpm=bpm,
        initial_player=start_player(),
        pattern=pattern,
        speed_changes=speed_changes,
        seed=seed,
    )

    save_level_files(level, level_name)
    return level


def build_level_from_chart(
    chart: Chart,
    level_name: str,
    extra_speed_changes: dict[float, int] | None = None,
    seed: int | None = None,
):
    level = generate_level(
        inputs=chart.inputs,
        music=chart.music,
        song_start=chart.song_start,
        song_duration=chart.song_duration,
        initial_player=start_player(SPEED_LEVELS[chart.start_speed_level]),
        speed_changes={**chart.speed_changes, **(extra_speed_changes or {})},
        seed=seed,
    )

    save_level_files(level, level_name)
    return level


def resolve_audio_path(value: str) -> Path:
    path = Path(value)
    if not path.exists() and (AUDIO_DIRECTORY / value).exists():
        path = AUDIO_DIRECTORY / value
    if not path.exists():
        raise FileNotFoundError(f"Audio file not found: {value}")
    return path


def main():
    parser = argparse.ArgumentParser(description="Build a rhythm level from a song, a chart, input or BPM timing.")
    parser.add_argument("--analyze", metavar="AUDIO", default=None, help="Analyze a song (path, or file name inside audio/) and build a level from it.")
    parser.add_argument("--chart", metavar="CHART", default=None, help="Build a level from a saved (possibly hand-edited) chart JSON.")
    parser.add_argument("--difficulty", choices=sorted(DIFFICULTIES), default="normal", help="Event density for --analyze.")
    parser.add_argument("--bpm", type=float, default=None, help="BPM mode: build a beat-driven level. With --analyze: tempo hint for beat tracking.")
    parser.add_argument("--pattern", nargs="*", default=["orb", "wall"], help="Beat event pattern for BPM mode.")
    parser.add_argument("--duration", type=float, default=None, help=f"Level duration in seconds (default: whole song for --analyze, {LEVEL_DURATION} otherwise).")
    parser.add_argument("--name", default=None, help=f"Output level name without extension (default: audio/chart name, or {LEVEL_NAME}).")
    parser.add_argument("--speed-change", nargs=2, action="append", default=[], help="Time in seconds and speed level (1-3), e.g. --speed-change 4.0 2")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for wall choices, to reproduce a layout.")
    args = parser.parse_args()

    speed_changes = {}
    for time_value, speed_value in args.speed_change:
        speed_changes[float(time_value)] = int(speed_value)

    if args.analyze is not None:
        audio_path = resolve_audio_path(args.analyze)
        level_name = args.name or audio_path.stem
        chart = analyze_song(
            audio_path,
            difficulty=args.difficulty,
            song_start=SONG_START,
            duration=args.duration,
            bpm_hint=args.bpm,
        )
        print(
            f"Detected {chart.bpm} BPM, {len(chart.inputs)} events, "
            f"{len(chart.speed_changes)} speed changes."
        )
        save_chart(chart, CHARTS_DIRECTORY / f"{level_name}.chart.json")
        build_level_from_chart(chart, level_name, speed_changes, args.seed)
        return

    if args.chart is not None:
        chart_path = Path(args.chart)
        level_name = args.name or chart_path.name.removesuffix(".json").removesuffix(".chart")
        build_level_from_chart(load_chart(chart_path), level_name, speed_changes, args.seed)
        return

    level_name = args.name or LEVEL_NAME
    duration = args.duration if args.duration is not None else LEVEL_DURATION

    if args.bpm is not None:
        build_level_from_bpm(
            level_name=level_name,
            duration=duration,
            bpm=args.bpm,
            pattern=args.pattern,
            speed_changes=speed_changes,
            seed=args.seed,
        )
        return

    level = generate_level(
        inputs=record_inputs(duration),
        music=f"{level_name}.mp3",
        song_start=SONG_START,
        song_duration=duration,
        initial_player=start_player(),
        speed_changes=speed_changes,
        seed=args.seed,
    )
    save_level_files(level, level_name)


if __name__ == "__main__":
    main()
