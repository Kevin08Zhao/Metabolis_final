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


class BuildD25HeartbeatAudioTests(unittest.TestCase):
    def test_builds_deterministic_safe_pcm_loop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.wav"
            second = Path(directory) / "second.wav"

            for output in (first, second):
                result = subprocess.run(
                    [sys.executable, str(BUILDER), "--output", str(output)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            self.assertEqual(
                hashlib.sha256(first.read_bytes()).hexdigest(),
                hashlib.sha256(second.read_bytes()).hexdigest(),
            )

            with wave.open(str(first), "rb") as stream:
                self.assertEqual(stream.getnchannels(), 1)
                self.assertEqual(stream.getsampwidth(), 2)
                self.assertEqual(stream.getframerate(), 48_000)
                self.assertEqual(stream.getnframes(), 48_000)
                samples = array("h", stream.readframes(stream.getnframes()))

            self.assertLessEqual(max(abs(sample) for sample in samples), 8_250)
            self.assertGreater(max(abs(sample) for sample in samples), 4_000)
            self.assertLess(abs(sum(samples) / len(samples)), 50)
            self.assertLessEqual(max(abs(sample) for sample in samples[:240]), 8)
            self.assertLessEqual(max(abs(sample) for sample in samples[-240:]), 8)


if __name__ == "__main__":
    unittest.main()
