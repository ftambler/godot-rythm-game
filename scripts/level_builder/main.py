import argparse
import time
from pathlib import Path

try:
    import keyboard
except ImportError:  # pragma: no cover - optional for non-recording mode
    keyboard = None

from config import (
    DEFAULT_BPM,
    LEVEL_DURATION,
    LEVEL_NAME,
    SONG_START,
    START_DIRECTION,
    START_POSITION,
    START_SPEED,
    PREDICT_TIME,
)
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


def build_level_from_bpm(
    level_name: str,
    duration: float,
    bpm: float,
    pattern: list[str] | None = None,
    speed_changes: dict[float, int] | None = None,
):
    player = PlayerState(
        position=START_POSITION,
        direction=Direction[START_DIRECTION],
        speed=START_SPEED,
    )

    level = generate_level_from_bpm(
        music=f"{level_name}.mp3",
        song_start=SONG_START,
        song_duration=duration,
        bpm=bpm,
        initial_player=player,
        pattern=pattern,
        speed_changes=speed_changes,
    )

    output_dir = Path(__file__).resolve().parents[2] / "levels"
    json_path = save_level(build_json(level), level_name, output_dir=output_dir)
    preview_path = json_path.with_suffix(".png")
    visualize_level(json_path, preview_path)
    return level


def main():
    parser = argparse.ArgumentParser(description="Build a rhythm level from input or BPM timing.")
    parser.add_argument("--bpm", type=float, default=None, help="Build a beat-driven level using this BPM.")
    parser.add_argument("--pattern", nargs="*", default=["orb", "wall"], help="Beat event pattern for BPM mode.")
    parser.add_argument("--duration", type=float, default=LEVEL_DURATION, help="Level duration in seconds.")
    parser.add_argument("--name", default=LEVEL_NAME, help="Output level name without extension.")
    parser.add_argument("--speed-change", nargs=2, action="append", default=[], help="Beat time and speed value, e.g. --speed-change 1.0 2")
    args = parser.parse_args()

    speed_changes = {}
    for time_value, speed_value in args.speed_change:
        speed_changes[float(time_value)] = int(speed_value)

    if args.bpm is not None:
        build_level_from_bpm(
            level_name=args.name,
            duration=args.duration,
            bpm=args.bpm,
            pattern=args.pattern,
            speed_changes=speed_changes,
        )
        return

    inputs = record_inputs(args.duration)
    player = PlayerState(
        position=START_POSITION,
        direction=Direction[START_DIRECTION],
        speed=START_SPEED,
    )

    level = generate_level(
        inputs=inputs,
        music=f"{args.name}.mp3",
        song_start=SONG_START,
        song_duration=args.duration,
        initial_player=player,
    )

    output_dir = Path(__file__).resolve().parents[2] / "levels"
    json_path = save_level(build_json(level), args.name, output_dir=output_dir)
    preview_path = json_path.with_suffix(".png")
    visualize_level(json_path, preview_path)


if __name__ == "__main__":
    if DEFAULT_BPM:
        print(f"Beat generator ready. Example: python main.py --bpm {DEFAULT_BPM} --duration 16 --pattern orb wall wall")
    main()