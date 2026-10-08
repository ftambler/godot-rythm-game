import sys
import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent))

from directions import Direction
from generator import generate_beat_events, generate_level_from_bpm
from models import PlayerState
from serializer import build_json
from visualizer import visualize_level


class LevelBuilderPhysicsTests(unittest.TestCase):
    def test_generate_beat_events_returns_beat_times(self):
        events = generate_beat_events(duration=2.0, bpm=60.0)
        self.assertEqual(events, [0.0, 1.0, 2.0])

    def test_generate_level_from_bpm_builds_objects(self):
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            bpm=60.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
            pattern=["orb", "wall"],
        )

        self.assertEqual(level.music, "test.mp3")
        self.assertGreater(len(level.objects), 0)
        self.assertTrue(any(obj.type == "orb" for obj in level.objects))
        self.assertTrue(any(obj.type == "walls" for obj in level.objects))

    def test_build_json_serializes_runtime_speed_enum(self):
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            bpm=60.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=300.0),
            pattern=["orb"],
        )

        payload = build_json(level)
        self.assertEqual(payload["player"]["speed"], 1)

    def test_generate_level_keeps_initial_player_state(self):
        initial_player = PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0)
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            bpm=60.0,
            initial_player=initial_player,
            pattern=["orb", "wall"],
        )

        self.assertEqual(level.player.position, (0.0, 0.0))
        self.assertEqual(level.player.direction, Direction.DOWN_RIGHT)
        self.assertEqual(level.player.speed, 500.0)

    def test_generated_objects_remain_visible_through_finish_buffer(self):
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            bpm=60.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
            pattern=["orb", "wall"],
        )

        self.assertTrue(level.objects)
        self.assertEqual(level.song_duration, 5.0)
        payload = build_json(level)
        self.assertEqual(payload["songDuration"], 5.0)
        self.assertTrue(all(obj.end == level.song_duration for obj in level.objects))

    def test_visualizer_inverts_y_axis_to_match_game_coordinates(self):
        with TemporaryDirectory() as temp_dir:
            level_path = Path(temp_dir) / "preview_level.json"
            level_path.write_text(json.dumps({
                "music": "test.mp3",
                "songStart": 0.0,
                "songDuration": 2.0,
                "player": {"position": [0.0, 0.0], "direction": [1, 1], "speed": 1},
                "objects": [{"type": "orb", "position": [100.0, 50.0], "start": 0.0, "end": 2.0, "groupId": 1}],
            }), encoding="utf-8")

            output_path = Path(temp_dir) / "preview.png"
            ax = visualize_level(level_path, output_path)

            self.assertIsNotNone(ax)
            self.assertTrue(ax.yaxis_inverted())
            self.assertTrue(output_path.exists())


if __name__ == "__main__":
    unittest.main()
