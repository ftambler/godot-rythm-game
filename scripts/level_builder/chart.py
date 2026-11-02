import json
from dataclasses import dataclass, field
from pathlib import Path

from models import Action, InputEvent


EVENT_TYPES = {
    "orb": Action.ONE,
    "wall": Action.TWO,
}


@dataclass
class Chart:
    """Timing of a level before any positions are decided.

    Times are seconds from the level start (after songStart).
    """

    music: str
    song_start: float
    song_duration: float
    bpm: float | None = None
    difficulty: str | None = None
    start_speed_level: int = 1
    inputs: list[InputEvent] = field(default_factory=list)
    speed_changes: dict[float, int] = field(default_factory=dict)


def chart_to_dict(chart: Chart) -> dict:
    action_names = {action: name for name, action in EVENT_TYPES.items()}

    return {
        "music": chart.music,
        "songStart": chart.song_start,
        "songDuration": chart.song_duration,
        "bpm": chart.bpm,
        "difficulty": chart.difficulty,
        "startSpeed": chart.start_speed_level,
        "events": [
            {"time": event.time, "type": action_names[event.action]}
            for event in chart.inputs
        ],
        "speedChanges": [
            {"time": time, "speed": speed}
            for time, speed in sorted(chart.speed_changes.items())
        ],
    }


def save_chart(chart: Chart, path: str | Path) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with open(path, "w", encoding="utf-8") as file:
        json.dump(chart_to_dict(chart), file, indent=2)

    print(f"Chart saved to {path}")
    return path


def load_chart(path: str | Path) -> Chart:
    with open(path, "r", encoding="utf-8") as file:
        data = json.load(file)

    inputs = [
        InputEvent(time=float(event["time"]), action=EVENT_TYPES[event["type"]])
        for event in data.get("events", [])
    ]
    inputs.sort(key=lambda event: event.time)

    return Chart(
        music=data["music"],
        song_start=float(data.get("songStart", 0.0)),
        song_duration=float(data["songDuration"]),
        bpm=data.get("bpm"),
        difficulty=data.get("difficulty"),
        start_speed_level=int(data.get("startSpeed", 1)),
        inputs=inputs,
        speed_changes={
            float(change["time"]): int(change["speed"])
            for change in data.get("speedChanges", [])
        },
    )
