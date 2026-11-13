from pathlib import Path

LEVEL_NAME = "test"
LEVEL_DURATION = 5.0
SONG_START = 0.0
START_POSITION = (0.0, 0.0)
# None: a random diagonal, picked with --seed. Diagonal headings only meet
# horizontal/vertical walls (one-key shields); straight ones (UP, RIGHT...)
# only meet diagonal walls, which need two-key diagonal shields and are harder.
START_DIRECTION = None
START_SPEED = 600.0
DEFAULT_BPM = 120.0
LEVEL_END_BUFFER = 3.0
# Seconds before its beat an object appears; about half a screen ahead at speed 1.
OBJECT_SPAWN_LEAD = 1.0
# Seconds after its beat an object is removed (if the player didn't already clear it).
OBJECT_DESPAWN_DELAY = 0.5
OUTPUT_DIRECTORY = Path(__file__).parent
PREDICT_TIME = 1

# Runtime speed levels (PlayerSpeed.Type in Godot) -> pixels per second.
# Must match scripts/player/PlayerSpeed.gd (test_level_builder checks this).
SPEED_LEVELS = {
    1: 600.0,
    2: 800.0,
    3: 1000.0,
}

# Collision sizes (px) in scenes/game/Player.tscn and Wall.tscn (test_level_builder
# checks them). The game bounces as soon as the two shapes touch, not when the
# player's center reaches the wall, so walls are placed that much further out.
PLAYER_RADIUS = 1.0
WALL_THICKNESS = 2.0
# CharacterBody2D.safe_margin (Godot's default): the player stops this short of a wall.
PLAYER_SAFE_MARGIN = 0.08

# Minimum distance (px) the player path must keep from any object it is not
# currently hitting. Walls are 80px long, so this keeps their ends clear too.
OBJECT_CLEARANCE = 80.0
# Time step (s) used to sample the player path when checking for overlaps.
SIMULATION_STEP = 1 / 60
# How many rejected wall choices the generator tries before giving up.
MAX_LAYOUT_ATTEMPTS = 5000
