import json

from models import Level, LevelObject


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
            "speed": level.player.speed,
        },
        "objects": [
            object_to_dict(obj)
            for obj in level.objects
        ],
    }


def save_level(
    level_json: dict,
    level_name: str,
) -> None:

    filename = f"{level_name}.json"

    with open(filename, "w", encoding="utf-8") as file:
        json.dump(
            level_json,
            file,
            indent=2,
        )

    print(f"Level saved to {filename}")