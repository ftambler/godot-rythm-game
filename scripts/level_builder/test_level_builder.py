import math
import re
import sys
import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bounce import get_bounce
from config import (
    OBJECT_CLEARANCE,
    OBJECT_DESPAWN_DELAY,
    OBJECT_SPAWN_LEAD,
    PLAYER_RADIUS,
    PLAYER_SAFE_MARGIN,
    SPEED_LEVELS,
    WALL_THICKNESS,
)
from directions import Direction
from generator import (
    WALL_AXES,
    generate_beat_events,
    generate_level,
    generate_level_from_bpm,
    get_turn,
    get_valid_wall_types,
    get_wall_position,
)
from main import DIAGONAL_DIRECTIONS, pick_start_direction
from models import Action, InputEvent, PlayerState, WallType
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
            if obj.type == "black_hole":
                continue
            self.assertLessEqual(obj.end, level.song_duration)
            if obj.start > 0:
                self.assertAlmostEqual(obj.end - obj.start, OBJECT_SPAWN_LEAD + OBJECT_DESPAWN_DELAY)

    def test_black_hole_sits_at_the_end_of_the_path(self):
        level = generate_level_from_bpm(
            music="test.mp3",
            song_start=0.0,
            song_duration=2.0,
            bpm=60.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
            pattern=["orb"],
        )

        black_holes = [obj for obj in level.objects if obj.type == "black_hole"]
        self.assertEqual(len(black_holes), 1)
        # Only orbs, so the path is a straight line for the whole level.
        self.assertAlmostEqual(math.hypot(*black_holes[0].position), 500.0 * level.song_duration, delta=0.01)

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

    def test_collision_sizes_match_godot(self):
        scenes = Path(__file__).resolve().parents[2] / "scenes" / "game"

        def body_collision(scene):
            """Shape resource text and scale of the scene's own CollisionShape2D."""
            text = (scenes / scene).read_text(encoding="utf-8")
            node = re.search(r'\[node name="CollisionShape2D"[^\]]*parent="\."[^\]]*\]([^\[]*)', text).group(1)
            shape_id = re.search(r'shape = SubResource\("([^"]+)"\)', node).group(1)
            shape = re.search(rf'\[sub_resource [^\]]*id="{shape_id}"\]([^\[]*)', text).group(1)
            scale = re.search(r"scale = Vector2\(([\d.]+), ([\d.]+)\)", node)
            return shape, float(scale.group(1)), float(scale.group(2))

        # Shapes without a size use Godot's defaults: radius 10, or 20x20.
        shape, scale, _ = body_collision("Player.tscn")
        radius = re.search(r"radius = ([\d.]+)", shape)
        self.assertAlmostEqual((float(radius.group(1)) if radius else 10.0) * scale, PLAYER_RADIUS)

        shape, _, scale = body_collision("Wall.tscn")
        size = re.search(r"size = Vector2\(([\d.]+), ([\d.]+)\)", shape)
        self.assertAlmostEqual((float(size.group(2)) if size else 20.0) * scale, WALL_THICKNESS)

        # PLAYER_SAFE_MARGIN assumes the player keeps the default safe_margin.
        self.assertNotIn("safe_margin", (scenes / "Player.tscn").read_text(encoding="utf-8"))

    def test_walls_are_placed_where_the_player_touches_them(self):
        contact = PLAYER_RADIUS + PLAYER_SAFE_MARGIN + WALL_THICKNESS / 2

        # Moving down onto a floor puts the wall below the player's center.
        self.assertEqual(
            get_wall_position((100.0, 200.0), Direction.DOWN_RIGHT, WallType.HORIZONTAL),
            (100.0, round(200.0 + contact, 3)),
        )
        self.assertEqual(
            get_wall_position((100.0, 200.0), Direction.UP_LEFT, WallType.VERTICAL),
            (round(100.0 - contact, 3), 200.0),
        )

        for direction in Direction:
            for wall_type in get_valid_wall_types(direction):
                wall_x, wall_y = get_wall_position((0.0, 0.0), direction, wall_type)
                axis_x, axis_y = WALL_AXES[wall_type]
                move_x, move_y = direction.unit_vector()

                # Straight ahead of the center by `contact`, measured across the wall.
                self.assertAlmostEqual(abs(wall_y * axis_x - wall_x * axis_y), contact, places=2)
                self.assertAlmostEqual(wall_x * axis_x + wall_y * axis_y, 0.0, places=2)
                self.assertGreater(wall_x * move_x + wall_y * move_y, 0.0)

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

    def build_turns(self, seed, music="test.mp3"):
        level = generate_level_from_bpm(
            music=music,
            song_start=0.0,
            song_duration=60.0,
            bpm=120.0,
            initial_player=PlayerState(position=(0.0, 0.0), direction=Direction.DOWN_RIGHT, speed=500.0),
            pattern=["orb", "wall"],
            seed=seed,
        )

        direction, turns = Direction.DOWN_RIGHT, []
        for wall in sorted((obj for obj in level.objects if obj.type == "walls"), key=lambda obj: obj.start):
            new_direction = get_bounce(direction, wall.wall_type)
            turns.append(get_turn(direction, new_direction))
            direction = new_direction
        return turns

    def test_path_mixes_loops_and_zigzags(self):
        turns = self.build_turns(seed=3)
        pairs = list(zip(turns, turns[1:]))

        # Both ways round, and both repeated turns (loops) and alternating
        # ones (zig-zags), instead of circling the same way the whole level.
        self.assertIn(1, turns)
        self.assertIn(-1, turns)
        self.assertGreater(sum(a == b for a, b in pairs), len(pairs) // 5)
        self.assertGreater(sum(a == -b for a, b in pairs), len(pairs) // 5)

    def test_seeds_give_different_paths(self):
        paths = {tuple(self.build_turns(seed)) for seed in range(5)}
        self.assertEqual(len(paths), 5)

    def test_same_seed_gives_each_song_its_own_path(self):
        self.assertNotEqual(self.build_turns(1, "a.mp3"), self.build_turns(1, "b.mp3"))

    def test_default_start_direction_is_a_reproducible_diagonal(self):
        directions = {pick_start_direction(None, seed, "test.mp3") for seed in range(20)}
        self.assertEqual(directions, set(DIAGONAL_DIRECTIONS))
        self.assertEqual(pick_start_direction(None, 4, "test.mp3"), pick_start_direction(None, 4, "test.mp3"))
        self.assertEqual(pick_start_direction("UP", 4, "test.mp3"), Direction.UP)

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
