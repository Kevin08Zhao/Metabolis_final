#!/usr/bin/env python3
"""Recolor generated pixel art into the Metabolis cohesive coral palette."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CORAL_RAMP = (
    (34, "#28152F"),
    (58, "#522044"),
    (82, "#7F285A"),
    (106, "#A93670"),
    (130, "#CB4E82"),
    (154, "#E66C96"),
    (178, "#F486A0"),
    (202, "#FBA3A4"),
    (226, "#FFC1B6"),
    (256, "#FFE4D7"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    return parser.parse_args()


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def luminance(red: int, green: int, blue: int) -> int:
    return round(0.2126 * red + 0.7152 * green + 0.0722 * blue)


def remap(pixel: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return pixel
    lightness = luminance(red, green, blue)
    for upper_bound, color in CORAL_RAMP:
        if lightness < upper_bound:
            target = hex_rgb(color)
            return (*target, alpha)
    raise AssertionError("The final palette ramp must cover every luminance.")


def main() -> None:
    args = parse_args()
    source = Image.open(args.input).convert("RGBA")
    result = Image.new("RGBA", source.size)
    result.putdata([remap(pixel) for pixel in source.get_flattened_data()])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output, optimize=False)


if __name__ == "__main__":
    main()
