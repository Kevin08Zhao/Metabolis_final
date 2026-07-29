#!/usr/bin/env python3
"""Remove PixelLab road-tile ground so roads blend across system maps."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    return parser.parse_args()


def is_road_pixel(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return False
    cyan_edge = green > red + 15 and blue > red + 15
    raspberry_surface = (
        red < 230
        and red > green + 25
        and blue >= green - 5
    )
    dark_outline = red < 130 and green < 135 and blue < 165
    neutral_lane_mark = max(red, green, blue) - min(red, green, blue) < 18 and red < 215
    return cyan_edge or raspberry_surface or dark_outline or neutral_lane_mark


def main() -> None:
    args = parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    for index in range(18):
        source_path = args.source / f"tile_city_road_wide_{index:02d}.png"
        target_path = (
            args.destination / f"tile_city_road_transparent_{index:02d}.png"
        )
        image = Image.open(source_path).convert("RGBA")
        image.putdata(
            [
                pixel if is_road_pixel(pixel) else (pixel[0], pixel[1], pixel[2], 0)
                for pixel in image.get_flattened_data()
            ]
        )
        image.save(target_path)


if __name__ == "__main__":
    main()
