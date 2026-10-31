from pathlib import Path

LEVEL_NAME = "test"
LEVEL_DURATION = 5.0
SONG_START = 0.0
START_POSITION = (0.0, 0.0)
START_DIRECTION = "DOWN_RIGHT"
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

# Minimum distance (px) the player path must keep from any object it is not
# currently hitting. Walls are 80px long, so this keeps their ends clear too.
OBJECT_CLEARANCE = 80.0
# Time step (s) used to sample the player path when checking for overlaps.
SIMULATION_STEP = 1 / 60
# How many rejected wall choices the generator tries before giving up.
MAX_LAYOUT_ATTEMPTS = 5000
