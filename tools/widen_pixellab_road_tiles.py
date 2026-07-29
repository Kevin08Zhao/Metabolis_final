#!/usr/bin/env python3
"""Widen PixelLab road pixels without changing tile edges or pixel scale."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--radius", type=int, default=3)
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
    neutral_lane_mark = max(red, green, blue) - min(red, green, blue) < 18 and red < 210
    return cyan_edge or raspberry_surface or neutral_lane_mark


def widen(image: Image.Image, radius: int) -> Image.Image:
    source = image.convert("RGBA")
    width, height = source.size
    pixels = source.load()
    road_points = [
        (x, y)
        for y in range(height)
        for x in range(width)
        if is_road_pixel(pixels[x, y])
    ]
    result = source.copy()
    output = result.load()

    for y in range(height):
        for x in range(width):
            if is_road_pixel(pixels[x, y]):
                continue
            nearest: tuple[int, int] | None = None
            nearest_distance = radius * radius + 1
            for road_x, road_y in road_points:
                delta_x = road_x - x
                delta_y = road_y - y
                distance = delta_x * delta_x + delta_y * delta_y
                if distance <= radius * radius and distance < nearest_distance:
                    nearest = (road_x, road_y)
                    nearest_distance = distance
            if nearest is not None:
                output[x, y] = pixels[nearest[0], nearest[1]]
    return result


def main() -> None:
    args = parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    for index in range(18):
        source_path = args.source / f"tile_city_road_{index:02d}.png"
        target_path = args.destination / f"tile_city_road_wide_{index:02d}.png"
        widened = widen(Image.open(source_path), args.radius)
        widened.save(target_path)


if __name__ == "__main__":
    main()
