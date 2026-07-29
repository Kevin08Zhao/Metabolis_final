from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_d26_d27_audio as builder


class D26D27AudioBuilderTests(unittest.TestCase):
    def test_outputs_have_exact_contract_format_and_duration(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            outputs = builder.build_all(Path(directory))
            self.assertEqual(len(outputs), len(builder.EXPECTED_DURATION_MS))
            for output in outputs:
                with wave.open(str(output), "rb") as stream:
                    self.assertEqual(stream.getnchannels(), 1)
                    self.assertEqual(stream.getsampwidth(), 2)
                    self.assertEqual(stream.getframerate(), builder.RATE)
                    expected_frames = builder.sample_count(
                        builder.EXPECTED_DURATION_MS[output.name]
                    )
                    self.assertEqual(stream.getnframes(), expected_frames)

    def test_generation_is_byte_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as left, tempfile.TemporaryDirectory() as right:
            left_outputs = builder.build_all(Path(left))
            right_outputs = builder.build_all(Path(right))
            left_hashes = {
                output.name: hashlib.sha256(output.read_bytes()).hexdigest()
                for output in left_outputs
            }
            right_hashes = {
                output.name: hashlib.sha256(output.read_bytes()).hexdigest()
                for output in right_outputs
            }
            self.assertEqual(left_hashes, right_hashes)


if __name__ == "__main__":
    unittest.main()
