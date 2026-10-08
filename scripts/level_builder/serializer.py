import json
from pathlib import Path

from models import Level, LevelObject


VALID_SPEEDS = {
    500.0: 1,
    700.0: 2,
    900.0: 3,
}


def player_speed_to_runtime_index(speed: float) -> int:
    if speed is None:
        return 1

    nearest_speed = min(
        VALID_SPEEDS,
        key=lambda candidate: abs(candidate - float(speed)),
    )
    return VALID_SPEEDS[nearest_speed]


def object_to_dict(obj: LevelObject) -> dict:

    result = {
        "type": obj.type,
        "position": [
            obj.position[0],
            obj.position[1],
        ],
        "start": obj.start,
        "end": obj.end,
    }

    if obj.group_id is not None:
        result["groupId"] = obj.group_id

    if obj.wall_type is not None:
        result["wallType"] = obj.wall_type.name

    if obj.rotation is not None:
        result["rotation"] = obj.rotation

    if obj.speed is not None:
        result["speed"] = obj.speed

    return result


def build_json(level: Level) -> dict:

    return {
        "music": level.music,
        "songStart": level.song_start,
        "songDuration": level.song_duration,
        "player": {
            "position": [
                level.player.position[0],
                level.player.position[1],
            ],
            "direction": list(
                level.player.direction.to_vector()
            ),
            "speed": player_speed_to_runtime_index(level.player.speed),
        },
        "objects": [
            object_to_dict(obj)
            for obj in level.objects
        ],
    }


def save_level(
    level_json: dict,
    level_name: str,
    output_dir: str | Path | None = None,
) -> None:

    output_dir = Path(output_dir) if output_dir is not None else Path.cwd()
    filename = output_dir / f"{level_name}.json"

    with open(filename, "w", encoding="utf-8") as file:
        json.dump(
            level_json,
            file,
            indent=2,
        )

    print(f"Level saved to {filename}")
    return filename
