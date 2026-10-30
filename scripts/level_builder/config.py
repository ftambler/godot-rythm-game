from pathlib import Path

LEVEL_NAME = "test"
LEVEL_DURATION = 5.0
SONG_START = 0.0
START_POSITION = (0.0, 0.0)
START_DIRECTION = "DOWN_RIGHT"
START_SPEED = 500.0
DEFAULT_BPM = 120.0
LEVEL_END_BUFFER = 3.0
OBJECT_SPAWN_LEAD = 0.75
OUTPUT_DIRECTORY = Path(__file__).parent
PREDICT_TIME = 1

# Runtime speed levels (PlayerSpeed.Type in Godot) -> pixels per second.
SPEED_LEVELS = {
    1: 500.0,
    2: 700.0,
    3: 900.0,
}

# Minimum distance (px) the player path must keep from any object it is not
# currently hitting. Walls are 80px long, so this keeps their ends clear too.
OBJECT_CLEARANCE = 80.0
# Time step (s) used to sample the player path when checking for overlaps.
SIMULATION_STEP = 1 / 60
# How many rejected wall choices the generator tries before giving up.
MAX_LAYOUT_ATTEMPTS = 5000
