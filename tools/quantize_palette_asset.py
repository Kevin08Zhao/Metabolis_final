"""Quantize explicitly named repository PNGs to the locked palette."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from pixellab_fetch import parse_gpl, quantize_and_binarize


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.repo_root.resolve()
    palette = parse_gpl(root / "art" / "palette.gpl")
    for relative in args.paths:
        target = (root / relative).resolve()
        target.relative_to(root)
        if target.suffix.lower() != ".png":
            raise ValueError(f"Only PNG files are supported: {relative}")
        with Image.open(target) as source:
            output, _ = quantize_and_binarize(
                source,
                palette,
                alpha_threshold=128,
                distance_threshold=12.0,
            )
        output.save(target, format="PNG", optimize=False, compress_level=9)
        print(target.relative_to(root).as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
