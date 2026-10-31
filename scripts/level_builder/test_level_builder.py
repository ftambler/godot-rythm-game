import math
import re
import sys
import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import OBJECT_CLEARANCE, OBJECT_DESPAWN_DELAY, OBJECT_SPAWN_LEAD, SPEED_LEVELS
from directions import Direction
from generator import generate_beat_events, generate_level, generate_level_from_bpm
from models import Action, InputEvent, PlayerState
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

    def test_objects_only_live_around_their_beat(self):
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
        for obj in level.objects:
            self.assertLess(obj.start, obj.end)
            self.assertLessEqual(obj.end, level.song_duration)
            if obj.start > 0:
                self.assertAlmostEqual(obj.end - obj.start, OBJECT_SPAWN_LEAD + OBJECT_DESPAWN_DELAY)

    def test_bpm_levels_never_stack_objects(self):
        for seed in range(20):
            for pattern in (["orb", "wall"], ["wall"], ["orb", "wall", "wall"]):
                level = generate_level_from_bpm(
                    music="test.mp3",
                    song_start=0.0,
                    song_duration=30.0,
                    bpm=120.0,
                    initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
                    pattern=pattern,
                    speed_changes={8.0: 2, 16.0: 3, 24.0: 1},
                    seed=seed,
                )

                # Objects on screen at the same time must not overlap.
                objects = level.objects
                for i, a in enumerate(objects):
                    for b in objects[i + 1:]:
                        if max(a.start, b.start) >= min(a.end, b.end):
                            continue
                        self.assertGreaterEqual(
                            math.dist(a.position, b.position),
                            OBJECT_CLEARANCE,
                            f"seed={seed} pattern={pattern}: objects at {a.position} and {b.position} overlap",
                        )

    def test_speed_changes_move_later_objects(self):
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=3.0,
            bpm=60.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.RIGHT, speed=SPEED_LEVELS[1]),
            pattern=["orb"],
            speed_changes={1.0: 3},
        )

        orbs = [obj.position for obj in level.objects if obj.type == "orb"]
        triggers = [obj for obj in level.objects if obj.type == "speed_trigger"]

        # The change at t=1 lands on an orb, so it moves to the middle of the
        # gap before it (t=0.5) instead of hiding under the orb.
        slow, fast = SPEED_LEVELS[1], SPEED_LEVELS[3]
        trigger_x = slow * 0.5
        first_x = trigger_x + fast * 0.5
        self.assertEqual(orbs, [(0.0, 0.0), (first_x, 0.0), (first_x + fast, 0.0), (first_x + 2 * fast, 0.0)])
        self.assertEqual(len(triggers), 1)
        self.assertEqual(triggers[0].position, (trigger_x, 0.0))
        self.assertEqual(triggers[0].speed, 3)

    def test_recorded_inputs_respect_speed_changes(self):
        level = generate_level(
            inputs=[
                InputEvent(time=1.0, action=Action.ONE),
                InputEvent(time=2.0, action=Action.ONE),
            ],
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.RIGHT, speed=SPEED_LEVELS[1]),
            speed_changes={0.5: 2},
        )

        orbs = [obj.position for obj in level.objects if obj.type == "orb"]
        first_x = SPEED_LEVELS[1] * 0.5 + SPEED_LEVELS[2] * 0.5
        self.assertEqual(orbs, [(first_x, 0.0), (first_x + SPEED_LEVELS[2], 0.0)])

    def test_diagonal_movement_matches_game_speed(self):
        level = generate_level(
            inputs=[InputEvent(time=1.0, action=Action.ONE)],
            music="test.mp3",
            song_start=0.0,
            song_duration=1.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=SPEED_LEVELS[1]),
        )

        # Godot normalizes diagonal directions, so one second covers `speed` pixels.
        self.assertAlmostEqual(math.hypot(*level.objects[0].position), SPEED_LEVELS[1], delta=0.01)

    def test_speed_levels_match_godot(self):
        source = (Path(__file__).resolve().parents[1] / "player" / "PlayerSpeed.gd").read_text(encoding="utf-8")
        godot_speeds = {
            int(level): float(value)
            for level, value in re.findall(r"Type\.SPEED_(\d+):\s*([\d.]+)", source)
        }
        self.assertEqual(godot_speeds, SPEED_LEVELS)

    def test_same_seed_gives_same_layout(self):
        def build(seed):
            return generate_level_from_bpm(
                music="test.mp3",
                song_start=0.0,
                song_duration=10.0,
                bpm=120.0,
                initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
                pattern=["orb", "wall"],
                seed=seed,
            )

        self.assertEqual(build_json(build(7)), build_json(build(7)))

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
