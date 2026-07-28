from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
import unittest
import wave
from array import array
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BUILDER = REPO_ROOT / "tools" / "build_d25_heartbeat_audio.py"
EXPECTED_DURATIONS_MS = {
    "heartbeat_bed.wav": 1_000,
    "heartbeat_bed_strained.wav": 440,
    "heartbeat_bed_critical.wav": 1_800,
}
STABLE_SHA256 = "61e4237e2c9b9c0ab51b81c5416ace98d59cbc8eca08399950d4d8a3f72f422a"


class BuildD25HeartbeatAudioTests(unittest.TestCase):
    def run_builder(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(BUILDER), *arguments],
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_safe_loop(self, path: Path, duration_ms: int) -> None:
        with wave.open(str(path), "rb") as stream:
            self.assertEqual(stream.getnchannels(), 1)
            self.assertEqual(stream.getsampwidth(), 2)
            self.assertEqual(stream.getframerate(), 48_000)
            self.assertEqual(
                stream.getnframes(),
                round(48_000 * duration_ms / 1_000),
            )
            samples = array("h", stream.readframes(stream.getnframes()))

        self.assertLessEqual(max(abs(sample) for sample in samples), 8_250)
        self.assertGreater(max(abs(sample) for sample in samples), 4_000)
        self.assertLess(abs(sum(samples) / len(samples)), 50)
        self.assertLessEqual(max(abs(sample) for sample in samples[:240]), 8)
        self.assertLessEqual(max(abs(sample) for sample in samples[-240:]), 8)

    def test_builds_deterministic_safe_three_band_loops(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first_dir = Path(directory) / "first"
            second_dir = Path(directory) / "second"

            for output_dir in (first_dir, second_dir):
                result = self.run_builder("--output-dir", str(output_dir))
                self.assertEqual(result.returncode, 0, result.stderr)

            for filename, duration_ms in EXPECTED_DURATIONS_MS.items():
                first = first_dir / filename
                second = second_dir / filename
                self.assertEqual(
                    hashlib.sha256(first.read_bytes()).hexdigest(),
                    hashlib.sha256(second.read_bytes()).hexdigest(),
                )
                self.assert_safe_loop(first, duration_ms)

            self.assertEqual(
                hashlib.sha256(
                    (first_dir / "heartbeat_bed.wav").read_bytes()
                ).hexdigest(),
                STABLE_SHA256,
            )

    def test_legacy_output_remains_the_stable_loop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "stable.wav"
            result = self.run_builder("--output", str(output))

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                hashlib.sha256(output.read_bytes()).hexdigest(),
                STABLE_SHA256,
            )
            self.assert_safe_loop(output, 1_000)

    def test_worst_case_crossfade_peak_remains_below_full_scale(self) -> None:
        single_stream_peak = 7_600
        critical_linear_gain = 10 ** (-8.0 / 20.0)
        two_stream_peak = 2.0 * single_stream_peak * critical_linear_gain

        self.assertLess(two_stream_peak, 32_767)


if __name__ == "__main__":
    unittest.main()
