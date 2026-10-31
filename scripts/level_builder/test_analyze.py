import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from analyze import MAX_ORB_RUN, MIN_REACTION_TIME, MIN_WALL_GAP_BEATS, analyze_song, merge_short_sections
from chart import load_chart, save_chart
from models import Action

try:
    import soundfile
except ImportError:  # pragma: no cover - analysis needs librosa + soundfile
    soundfile = None


SAMPLE_RATE = 22050
BPM = 120.0
QUIET_SECONDS = 24.0
LOUD_SECONDS = 24.0


def write_test_song(path: Path) -> None:
    """Kick on every beat, hi-hat on every off-beat; second half much louder."""

    rng = np.random.default_rng(0)
    total = QUIET_SECONDS + LOUD_SECONDS
    audio = np.zeros(int(total * SAMPLE_RATE))
    beat = 60.0 / BPM

    kick_t = np.arange(int(0.15 * SAMPLE_RATE)) / SAMPLE_RATE
    kick = np.sin(2 * np.pi * 60 * kick_t) * np.exp(-kick_t * 30)
    hat = rng.uniform(-1, 1, int(0.04 * SAMPLE_RATE)) * np.exp(-np.arange(int(0.04 * SAMPLE_RATE)) / 150)

    time = 0.5
    while time < total - 0.5:
        gain = 0.25 if time < QUIET_SECONDS else 1.0
        for offset, sound, level in ((0.0, kick, 1.0), (beat / 2, hat, 0.3)):
            start = int((time + offset) * SAMPLE_RATE)
            audio[start:start + len(sound)] += sound * level * gain
        time += beat

    soundfile.write(path, audio / np.abs(audio).max() * 0.9, SAMPLE_RATE)


@unittest.skipIf(soundfile is None, "librosa/soundfile not installed")
class AnalyzeSongTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp_dir = TemporaryDirectory()
        cls.song_path = Path(cls.temp_dir.name) / "song.wav"
        write_test_song(cls.song_path)
        cls.charts = {
            difficulty: analyze_song(cls.song_path, difficulty)
            for difficulty in ("easy", "normal", "hard")
        }

    @classmethod
    def tearDownClass(cls):
        cls.temp_dir.cleanup()

    def test_detects_tempo(self):
        for chart in self.charts.values():
            self.assertAlmostEqual(chart.bpm, BPM, delta=2.0)

    def test_events_land_on_the_half_beat_grid(self):
        half_beat = 60.0 / BPM / 2
        for chart in self.charts.values():
            for event in chart.inputs:
                steps = round((event.time - 0.5) / half_beat)
                error = event.time - (0.5 + steps * half_beat)
                self.assertLess(abs(error), 0.02, f"{event.time} is {error * 1000:.0f}ms off the grid")

    def test_harder_difficulties_have_more_events(self):
        counts = [len(self.charts[d].inputs) for d in ("easy", "normal", "hard")]
        self.assertLess(counts[0], counts[1])
        self.assertLessEqual(counts[1], counts[2])

    def test_events_keep_minimum_gap_and_mix_types(self):
        for chart in self.charts.values():
            times = [event.time for event in chart.inputs]
            self.assertTrue(all(b - a >= MIN_REACTION_TIME - 1e-6 for a, b in zip(times, times[1:])))

            actions = [event.action for event in chart.inputs]
            self.assertIn(Action.ONE, actions)
            self.assertIn(Action.TWO, actions)

            wall_times = [event.time for event in chart.inputs if event.action == Action.TWO]
            min_wall_gap = MIN_WALL_GAP_BEATS * 60.0 / chart.bpm
            self.assertTrue(all(b - a >= min_wall_gap - 1e-3 for a, b in zip(wall_times, wall_times[1:])))

            orb_run = 0
            for action in actions:
                orb_run = orb_run + 1 if action == Action.ONE else 0
                self.assertLessEqual(orb_run, MAX_ORB_RUN)

    def test_loud_section_speeds_up(self):
        chart = self.charts["normal"]
        self.assertEqual(chart.start_speed_level, 1)
        self.assertTrue(chart.speed_changes)

        first_change_time, first_level = min(chart.speed_changes.items())
        self.assertGreater(first_level, 1)
        self.assertAlmostEqual(first_change_time, QUIET_SECONDS, delta=4.0)

    def test_chart_round_trip(self):
        chart = self.charts["normal"]
        path = save_chart(chart, Path(self.temp_dir.name) / "song.chart.json")
        loaded = load_chart(path)

        self.assertEqual(loaded.music, "song.wav")
        self.assertEqual(loaded.inputs, chart.inputs)
        self.assertEqual(loaded.speed_changes, chart.speed_changes)
        self.assertEqual(loaded.start_speed_level, chart.start_speed_level)


class MergeShortSectionsTests(unittest.TestCase):
    def test_short_sections_join_a_neighbour(self):
        levels = [1] * 8 + [3] * 2 + [1] * 8 + [2] * 8
        self.assertEqual(merge_short_sections(levels, 8), [1] * 18 + [2] * 8)

    def test_single_section_is_unchanged(self):
        self.assertEqual(merge_short_sections([2] * 5, 8), [2] * 5)


if __name__ == "__main__":
    unittest.main()
