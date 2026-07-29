#!/usr/bin/env python3
"""Crop transparent padding and integer-scale pixel art onto a fixed canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--scale", type=int, default=1)
    parser.add_argument("--canvas-width", type=int, required=True)
    parser.add_argument("--canvas-height", type=int, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.scale < 1:
        raise ValueError("Scale must be a positive integer.")
    source = Image.open(args.input).convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Source sprite is fully transparent.")

    sprite = source.crop(bounds)
    sprite = sprite.resize(
        (sprite.width * args.scale, sprite.height * args.scale),
        Image.Resampling.NEAREST,
    )
    if sprite.width > args.canvas_width or sprite.height > args.canvas_height:
        raise ValueError("Scaled sprite does not fit the requested canvas.")

    result = Image.new(
        "RGBA",
        (args.canvas_width, args.canvas_height),
        (0, 0, 0, 0),
    )
    left = (args.canvas_width - sprite.width) // 2
    top = args.canvas_height - sprite.height
    result.alpha_composite(sprite, (left, top))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output, optimize=False)


if __name__ == "__main__":
    main()
