# Project Context for an LLM

This repository is a Godot 4 rhythm-action prototype built around directional movement, shield timing, and timed obstacle spawning. The project has moved beyond the initial placeholder stage: it now includes multiple object types, a speed system, area-based orb detection, and a level JSON format that drives runtime behavior.

This document reflects the current project state as implemented in the codebase, not the earlier conceptual plan.

---

## 1. High-level gameplay loop

The current gameplay loop is:

- The player is a `CharacterBody2D` moving continuously in one of 8 directions.
- Direction is represented by `PlayerDirection.Direction` with values:
  - `UP`
  - `UP_RIGHT`
  - `RIGHT`
  - `DOWN_RIGHT`
  - `DOWN`
  - `DOWN_LEFT`
  - `LEFT`
  - `UP_LEFT`
- The player has a directional shield controlled by the keys mapped in `project.godot`.
- Walls spawn over time from JSON-defined `objects` entries and are instantiated by `LevelManager`.
- When the player collides with a wall, `ShieldEvaluator` decides whether the shield match is:
  - `MISS`
  - `HALF`
  - `FULL`
- The player direction changes after a collision through `PlayerBounce.get_bounce(...)`.
- Score and accuracy are tracked by `ScoreHandler`.
- Orbs and speed triggers are active object types that can also be spawned from level data.

The project is best understood as a rhythm-based collision timing game with directional shield evaluation rather than a classic platformer or puzzle game.

---

## 2. Current project structure

Top-level structure:

- `project.godot` — Godot config and input mapping
- `Game.tscn` — root game scene
- `levels/` — level definitions, including `test.json`
- `scenes/` — scene files for runtime objects
- `scripts/` — gameplay logic and editor-side tools
- `GODOT PLAN.txt` — earlier design notes, some of which are aspirational and not fully implemented

Important runtime folders:

- `scripts/Game.gd` — main bootstrap and level loading
- `scripts/level/` — level parsing, data models, spawn logic
- `scripts/player/` — movement, shield, bounce, speed, evaluation
- `scripts/world/` — wall, orb, speed trigger objects
- `scripts/scoring/` — score and HUD logic
- `scripts/level_builder/` — Python generator for procedural level authoring

---

## 3. Core runtime architecture

### Root game scene

`Game.tscn` currently contains:

- `Player` (from `scenes/Player.tscn`)
- `ScoreHandler`
- `HUD` canvas layer
- `Camera2D`
- `Walls` container
- `Orbs` container
- `SpeedTriggers` container
- `LevelManager`

This is the current runtime root used by `project.godot` as the main scene.

### Initialization flow

The runtime flow is:

1. `Game.gd::_ready()` connects signals:
   - `player.hit_registered` -> `score_handler.handle_hit`
   - `score_handler.score_updated` -> `update_hud`
   - `player.object_hit` -> `level_manager.object_hit`
2. `Game.gd::_load_level()` loads `res://levels/test.json`
3. `LevelLoader.load_level(...)` parses the JSON and returns a `LevelData`
4. `player` position and direction are assigned from loaded level data
5. `LevelManager.start_level(level)` initializes the spawn/despawn queues
6. `_process(delta)` begins spawning active objects over time

The runtime is strongly time-driven and uses `songStart`, `songDuration`, and per-object `start` / `end` timing.

---

## 4. Current level data contract

The active level JSON is in `levels/test.json` and has the following current structure:

```json
{
  "music": "test.ogg",
  "songStart": 0.0,
  "songDuration": 5.0,
  "player": {
	"position": [0.0, 0.0],
	"direction": [0, 1],
	"speed": 1
  },
  "objects": [
	{
	  "type": "walls",
	  "position": [0, 200],
	  "start": 0,
	  "end": 50.0,
	  "groupId": 1,
	  "wallType": "HORIZONTAL"
	},
	{
	  "type": "walls",
	  "position": [0, -250],
	  "start": 1.0,
	  "end": 50,
	  "groupId": 2,
	  "wallType": "HORIZONTAL"
	},
	{
	  "type": "orb",
	  "position": [0, 100],
	  "start": 0,
	  "end": 50.0,
	  "groupId": 3
	},
	{
	  "type": "speed_trigger",
	  "position": [0, 150],
	  "start": 1.5,
	  "end": 5.0,
	  "groupId": 4,
	  "speed": 1
	}
  ]
}
```

### Meaning of fields

Top-level:
- `music`: song asset name
- `songStart`: starting offset of the level timing
- `songDuration`: total level duration
- `player`: initial player state
- `objects`: all timed objects to spawn

Player state:
- `position`: `[x, y]` starting position
- `direction`: vector direction such as `[0, 1]` for down
- `speed`: speed enum index, currently using `1`, `2`, or `3` instead of a raw float

Object entries:
- `type`: object class, including `walls`, `orb`, `speed_trigger`
- `position`: `[x, y]`
- `start`: spawn time
- `end`: despawn time
- `groupId`: optional grouping metadata
- `wallType`: valid values include `HORIZONTAL`, `VERTICAL`, `DIAGONAL_DOWN`, `DIAGONAL_UP`
- `speed`: used for `speed_trigger` to set the player speed type

This is the actual runtime contract the game uses today.

---

## 5. Important runtime systems

### `scripts/Game.gd`

This is the main scene controller.

Key behavior:

- loads the level JSON from `res://levels/test.json`
- assigns player position and direction from the level
- sets `player.speed_type` from level data
- starts the level manager
- updates HUD labels with current score and accuracy

Important current implementation detail:

```gdscript
player.position = level.player_position
player.movement_direction = PlayerDirection.from_vector(level.player_direction)
player.speed_type = level.player_speed
```

This means the actual data flow is now `JSON -> LevelData -> Player properties`, rather than storing a raw float speed value directly.

### `scripts/level/level_loader.gd`

This file converts JSON into runtime `LevelData` and `LevelObjectData` instances.

Current parsing behavior:

- `player_speed` is parsed as a `PlayerSpeed.Type` enum using:

```gdscript
level.player_speed = PlayerSpeed.Type.values()[int(player_data["speed"]) - 1]
```

- `wallType` is parsed into `Wall.WallRotation`
- `speed_trigger` objects are parsed when a `speed` field exists

This loader is important because it is the file that translates numeric JSON values into actual enum-driven game behavior.

### `scripts/level/level_data.gd`

Defines the level container used by runtime logic:

```gdscript
class_name LevelData

var music: String
var song_start: float
var song_duration: float

var player_position: Vector2
var player_direction: Vector2
var player_speed: PlayerSpeed.Type

var objects: Array[LevelObjectData] = []
```

Note that the current runtime stores a `PlayerSpeed.Type` value instead of a raw float.

### `scripts/level/level_object_data.gd`

This is the object-level runtime model:

```gdscript
class_name LevelObjectData

var type: String
var position: Vector2
var start: float
var end: float
var group_id: int
var wall_type: Wall.WallRotation
var speed_type: PlayerSpeed.Type
```

This class is where `walls`, `orb`, and `speed_trigger` are represented internally.

### `scripts/level/level_manager.gd`

This is the spawner / lifecycle manager.

Current responsibilities:

- maintain `spawn_queue` and `despawn_queue`
- advance `level_time`
- spawn wall, orb, and speed-trigger objects as their `start` times are reached
- remove objects when `end` is reached
- maintain `active_objects` dictionary

Current spawn logic:

```gdscript
match data.type:
	"walls":
		object = WALL_SCENE.instantiate()
		var wall: Wall = object
		wall.wall_rotation = data.wall_type
		walls.add_child(object)

	"orb":
		object = ORB_SCENE.instantiate()
		orbs.add_child(object)

	"speed_trigger":
		object = SPEED_TRIGGER_SCENE.instantiate()
		var speed_trigger: SpeedTrigger = object
		speed_trigger.speed_type = data.speed_type
		speed_triggers.add_child(object)
```

Important implementation detail: `object_hit(...)` in `LevelManager` currently does not despawn objects on hit; it simply returns early.

---

## 6. Player and movement system

### `scripts/player/Player.gd`

This is the main player controller.

Current fields:

```gdscript
@export var speed_type: PlayerSpeed.Type = PlayerSpeed.Type.SPEED_2

var speed: float:
	get:
		return PlayerSpeed.get_value(speed_type)
```

This is crucial: the player does not use a raw float variable directly. Instead, it derives speed from a `PlayerSpeed.Type` enum.

Movement behavior:

- `_physics_process(delta)` calls `move_player(delta)`
- `move_player(delta)` converts `movement_direction` to a vector and moves by `velocity * delta`
- a `KinematicCollision2D` result triggers `handle_collision(...)`

Orb interaction:

- `hit_orb()` checks `orb_detector.get_overlapping_areas()`
- if the overlapping area is an `Orb`, it emits `HitResult.Type.FULL` and calls `object_hit.emit(area)`
- if no orb is found, it emits `HitResult.Type.MISS`

This is an important update from the earlier prototype: orb interaction is now a real mechanic, connected to an `Area2D` detector.

### `scripts/player/PlayerSpeed.gd`

This file defines the speed ladder:

```gdscript
enum Type {
	SPEED_1,
	SPEED_2,
	SPEED_3
}

const VALUES := {
	Type.SPEED_1: 150.0,
	Type.SPEED_2: 300.0,
	Type.SPEED_3: 450.0
}
```

This is the project’s actual speed model. A JSON `speed` of `1`, `2`, or `3` maps to the values above.

### `scripts/player/PlayerDirection.gd`

This remains the central direction utility. It defines the 8-direction enum and conversion functions:

- `from_vector(vector: Vector2) -> Direction`
- `to_vector(direction: Direction) -> Vector2`

It is used for both movement and shield direction logic.

---

## 7. Shield and collision evaluation

### `scripts/player/PlayerShield.gd`

The shield system reads axis input from:

- `shield_up`
- `shield_down`
- `shield_left`
- `shield_right`

It computes a direction vector from the pressed axes and toggles `active` when movement is present.

Important behavior:

```gdscript
if x == 0 and y == 0:
	active = false
	return

active = true
```

Then it maps the `Vector2(x, y)` to one of the enum directions.

### `scripts/player/ShieldEvaluator.gd`

This is the core determination of hit quality.

The function:

```gdscript
static func evaluate(
	wall_rotation: Wall.WallRotation,
	movement_direction: PlayerDirection.Direction,
	shield_direction: PlayerDirection.Direction,
	shield_active: bool
) -> HitResult.Type
```

The evaluator:

- instantly returns `MISS` if the shield is inactive
- checks the expected directional response for the wall type + movement vector
- returns `FULL` on exact match
- returns `HALF` for adjacent/nearby directions
- otherwise returns `MISS`

The half-shield code uses enum distance:

```gdscript
var difference: int = abs(expected_direction - actual_direction)
return difference == 1 or difference == 7
```

This means the shield system is intentionally tolerant to close directional offsets.

### `scripts/player/PlayerBounce.gd`

This file defines the bounce response after collision based on the wall orientation. It mirrors the wall types:

- `horizontal(...)`
- `vertical(...)`
- `diagonal_down(...)`
- `diagonal_up(...)`

This is the main logic that redirects the player after a wall hit.

---

## 8. World object types

### `scripts/world/Wall.gd`

Defines wall rotation and visual orientation.

```gdscript
enum WallRotation {
	HORIZONTAL,
	VERTICAL,
	DIAGONAL_DOWN,
	DIAGONAL_UP
}
```

Rotation is applied in `_apply_rotation()`:

- `HORIZONTAL` -> `0.0`
- `VERTICAL` -> `PI / 2.0`
- `DIAGONAL_DOWN` -> `PI / 4.0`
- `DIAGONAL_UP` -> `-PI / 4.0`

### `scripts/world/Orb.gd`

This is the orb object logic.

State:

```gdscript
var player_inside := false
```

Signals:

- `body_entered` -> `_on_body_entered`
- `body_exited` -> `_on_body_exited`

If the player is inside the orb area, `player_inside` becomes true. This is used by the orb detector flow in `Player.gd`.

### `scripts/world/SpeedTrigger.gd`

This is a timed speed-changing object.

Current fields:

```gdscript
@export var speed_type: PlayerSpeed.Type = PlayerSpeed.Type.SPEED_2
```

On body entry:

```gdscript
if body is Player:
	body.speed_type = speed_type
```

The label text is set to `str(speed_type + 1)`, so the visible number is effectively `1`, `2`, or `3` for the speed tier.

---

## 9. Score and HUD system

### `scripts/scoring/HitResult.gd`

Defines the scoring categories:

```gdscript
enum Type {
	MISS,
	HALF,
	FULL
}
```

Scoring values:

- `MISS` -> `0`
- `HALF` -> `50`
- `FULL` -> `100`

Accuracy values:

- `MISS` -> `0.0`
- `HALF` -> `0.5`
- `FULL` -> `1.0`

### `scripts/scoring/ScoreHandler.gd`

Responsible for running totals:

- `total_hits`
- `score`
- `accuracy`
- `score_updated` signal

`handle_hit(result)` increments totals and emits the updated score and accuracy.

`get_accuracy()` returns:

- `1.0` when `total_hits == 0`
- otherwise `accuracy / total_hits`

This behavior is intentional in the current implementation and has the effect of treating an empty session as perfect until a hit is recorded.

### `scripts/scoring/HUD.gd`

Simple UI wiring:

- `update_score(score: int)`
- `update_accuracy(accuracy: float)`

The display is formatted as a percentage with one decimal place.

---

## 10. Scene files and object layout

### `scenes/Player.tscn`

Contains:

- `Player` root `CharacterBody2D`
- `CollisionShape2D`
- `Sprite2D`
- `Shield` node with `PlayerShield.gd`
- `OrbDetector` `Area2D` with collision mask `2`
- a visible player body `ColorRect`

The orb detector is notable because it allows the player to detect nearby orb objects explicitly.

### `scenes/Wall.tscn`

Contains:

- root `StaticBody2D`
- wall rotation script
- `ColorRect` visual
- `CollisionShape2D`

### `scenes/Orb.tscn`

Contains:

- root `Area2D`
- collision layer `2`
- `ColorRect` visual
- `CollisionShape2D`

### `scenes/SpeedTrigger.tscn`

Contains:

- root `Area2D`
- `ColorRect` visual
- `CollisionShape2D`
- `Label` for displaying the speed value

Selected object types are intentionally simple visual placeholders, but the object logic is real and active.

---

## 11. Python level generator

The `scripts/level_builder/` folder still contains the earlier procedural generator pipeline for authoring custom level files.

Relevant files:

- `main.py` — records input events and outputs a level file
- `config.py` — level constants and defaults
- `models.py` — data classes for the generator
- `directions.py` — 8-direction enum
- `bounce.py` — bounce rules used to generate wall behavior
- `generator.py` — creates level objects from input events
- `simulator.py` — advances the player over time
- `serializer.py` — writes JSON in the expected runtime format

Current generator behavior:

- `Action.ONE` creates an `orb`
- `Action.TWO` creates a wall with a valid wall type based on the current direction
- the player direction is updated after each generated wall by the same bounce logic used in the runtime

This tool is still useful for synthesizing JSON levels, but the runtime also supports manually authored level files directly.

---

## 12. Important caveats for AI work

This project has some implementation details that are worth knowing before making changes:

1. The runtime is now enum-driven for speed.
   - The JSON speed field is a small integer (`1`, `2`, `3`), not a raw float.
   - The runtime maps it to `PlayerSpeed.Type` values.

2. Orb logic is partly implemented but not fully matured.
   - `Player.hit_orb()` exists and checks `OrbDetector` overlap.
   - `Orb.gd` exists and tracks whether the player is inside the area.
   - The current design is functional but still minimal.

3. Speed triggers are a real object type.
   - They modify `player.speed_type` when entered.
   - They are represented as `speed_trigger` in JSON and spawn via `LevelManager`.

4. The `LevelManager` does not currently despawn objects on `object_hit`.
   - The method `object_hit(object: Node)` returns early instead of removing the object from `active_objects`.
   - This is probably intentional for a prototype, but it matters when modifying hit behavior.

5. The earlier `GODOT PLAN.txt` is aspirational and does not fully match the current codebase.
   - Some planned scenes and systems exist in notes, but the actual project already diverged from that plan.

6. Visuals remain placeholder-heavy.
   - Most object visuals are simple rectangles, not final art assets.

---

## 13. Recommended files to read first

If another AI needs to understand the project quickly, the most relevant files are:

1. `project.godot`
2. `scripts/Game.gd`
3. `scripts/level/level_loader.gd`
4. `scripts/level/level_manager.gd`
5. `scripts/player/Player.gd`
6. `scripts/player/PlayerShield.gd`
7. `scripts/player/ShieldEvaluator.gd`
8. `scripts/player/PlayerBounce.gd`
9. `scripts/player/PlayerSpeed.gd`
10. `levels/test.json`

These files capture the current real gameplay behavior and the active data contracts.

---

## 14. Summary

The project is currently a compact Godot rhythm/shield timing prototype with the following implemented pieces:

- 8-direction player movement
- wall collision and bounce logic
- shield-based scoring with `MISS` / `HALF` / `FULL`
- score and accuracy HUD
- timed object spawning from JSON
- orb interaction via detector areas
- speed-changing trigger objects
- enum-based speed system
- Python-level generation tooling for authoring JSON content

This is no longer just a static prototype concept; it already contains a working gameplay loop and a data-driven level system that matches the current code.
