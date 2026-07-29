#!/usr/bin/env python3
"""Extract a PixelLab path archive into stable Metabolis asset names."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from zipfile import ZipFile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument(
        "--stem",
        default="tile_vessel_cohesive",
        help="Stable output filename stem.",
    )
    return parser.parse_args()


def source_index(name: str) -> int:
    match = re.search(r"_(\d+)\.png$", name)
    if match is None:
        raise ValueError(f"Unexpected PixelLab path filename: {name}")
    return int(match.group(1))


def main() -> None:
    args = parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.archive) as archive:
        png_names = sorted(
            (name for name in archive.namelist() if name.endswith(".png")),
            key=source_index,
        )
        if len(png_names) != 18:
            raise ValueError(f"Expected 18 path tiles, found {len(png_names)}.")
        for source_name in png_names:
            index = source_index(source_name)
            target = args.destination / f"{args.stem}_{index:02d}.png"
            target.write_bytes(archive.read(source_name))


if __name__ == "__main__":
    main()
