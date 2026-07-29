from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageColor


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_d19_particles as builder


class D19ParticleBuilderTests(unittest.TestCase):
    def test_outputs_match_fixed_transparent_silhouettes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            outputs = builder.build(Path(directory))
            self.assertEqual(len(outputs), len(builder.SHAPES))
            for output in outputs:
                rows, color_hex = builder.SHAPES[output.name]
                expected_color = ImageColor.getrgb(color_hex) + (255,)
                with Image.open(output) as source:
                    image = source.convert("RGBA")
                    self.assertEqual(
                        image.size,
                        (builder.CANVAS_SIZE, builder.CANVAS_SIZE),
                    )
                    for y in range(builder.CANVAS_SIZE):
                        for x in range(builder.CANVAS_SIZE):
                            shape_x = x - 4
                            shape_y = y - 4
                            expected = (
                                expected_color
                                if (
                                    0 <= shape_x < 8
                                    and 0 <= shape_y < 8
                                    and rows[shape_y][shape_x] == "#"
                                )
                                else (0, 0, 0, 0)
                            )
                            self.assertEqual(expected, image.getpixel((x, y)))

    def test_generation_is_byte_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as left, tempfile.TemporaryDirectory() as right:
            left_outputs = builder.build(Path(left))
            right_outputs = builder.build(Path(right))
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
