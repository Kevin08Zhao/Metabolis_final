"""Build the four D-19 particles with the fixed resource silhouettes."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageColor


CANVAS_SIZE = 16
SHAPE_SIZE = 8
SHAPES = {
    "particle_nutrient.png": (
        (
            "...##...",
            "..####..",
            ".######.",
            "########",
            "########",
            ".######.",
            "..####..",
            "...##...",
        ),
        "#E2953A",
    ),
    "particle_material.png": (
        (
            "........",
            ".######.",
            ".######.",
            ".######.",
            ".######.",
            ".#####..",
            ".####...",
            "........",
        ),
        "#BE6E87",
    ),
    "particle_signal.png": (
        (
            "...##...",
            "..####..",
            "..####..",
            ".######.",
            ".######.",
            "########",
            "########",
            "........",
        ),
        "#404586",
    ),
    "particle_waste.png": (
        (
            "..####..",
            ".##..##.",
            "##....##",
            "##....##",
            "##....##",
            "##....##",
            ".##..##.",
            "..####..",
        ),
        "#514854",
    ),
}


def build(repo_root: Path) -> list[Path]:
    outputs: list[Path] = []
    offset = (CANVAS_SIZE - SHAPE_SIZE) // 2
    for filename, (rows, color_hex) in SHAPES.items():
        path = repo_root / "art" / "particles" / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        output = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
        color = ImageColor.getrgb(color_hex) + (255,)
        for y, row in enumerate(rows):
            for x, pixel in enumerate(row):
                if pixel == "#":
                    output.putpixel((offset + x, offset + y), color)
        output.save(path, format="PNG", optimize=False, compress_level=9)
        outputs.append(path)
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    for output in build(args.repo_root.resolve()):
        print(output.relative_to(args.repo_root.resolve()).as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
