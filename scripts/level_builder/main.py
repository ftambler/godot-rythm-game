import time

import keyboard

from config import (
    LEVEL_DURATION,
    LEVEL_NAME,
    SONG_START,
    START_DIRECTION,
    START_POSITION,
    START_SPEED,
    PREDICT_TIME
)
from directions import Direction
from generator import generate_level
from models import Action, InputEvent, PlayerState
from serializer import build_json, save_level


KEY_MAP = {
    "f": Action.ONE,
    "j": Action.TWO,
}


def record_inputs(duration: float) -> list[InputEvent]:

    inputs = []

    start_time = time.time()
    end_time = start_time + duration

    def on_key_event(event):

        if event.event_type != keyboard.KEY_DOWN:
            return

        action = KEY_MAP.get(event.name)

        if action is None:
            return

        relative_time = max(time.time() - start_time - PREDICT_TIME, 0)

        inputs.append(
            InputEvent(
                time=round(relative_time, 3),
                action=action,
            )
        )

    keyboard.hook(on_key_event)

    try:
        while time.time() < end_time:
            time.sleep(1 / 240)

    finally:
        keyboard.unhook_all()

    return inputs


def main():

    inputs = record_inputs(
        LEVEL_DURATION
    )

    # print(inputs)

    player = PlayerState(
        position=START_POSITION,
        direction=Direction[START_DIRECTION],
        speed=START_SPEED,
    )

    level = generate_level(
        inputs=inputs,
        music=f"{LEVEL_NAME}.ogg",
        song_start=SONG_START,
        song_duration=LEVEL_DURATION,
        initial_player=player,
    )

    level_json = build_json(level)

    save_level(
        level_json,
        LEVEL_NAME,
    )


if __name__ == "__main__":
    main()