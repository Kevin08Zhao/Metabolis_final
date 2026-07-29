"""Quantize the fourteen accepted D-13b PixelLab card illustrations."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from pixellab_fetch import parse_gpl, quantize_and_binarize


def build(repo_root: Path) -> list[Path]:
    palette = parse_gpl(repo_root / "art" / "palette.gpl")
    outputs: list[Path] = []
    for path in sorted((repo_root / "art" / "candidates" / "d13b").glob("card_*.png")):
        with Image.open(path) as source:
            output, _ = quantize_and_binarize(
                source,
                palette,
                alpha_threshold=128,
                distance_threshold=12.0,
            )
        output.save(path, format="PNG", optimize=False, compress_level=9)
        outputs.append(path)
    if len(outputs) != 14:
        raise ValueError(f"D-13b requires 14 cards, found {len(outputs)}")
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
