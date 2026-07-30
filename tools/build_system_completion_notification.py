#!/usr/bin/env python3
"""Build the compact runtime notification frame from its PixelLab source."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (
    ROOT
    / "art"
    / "candidates"
    / "system_completion_notification"
    / "ui_system_completion_notification_candidate01_raw.png"
)
OUTPUT = ROOT / "art" / "ui" / "ui_system_completion_notification.png"

PALETTE = (
    "#340106",
    "#BA3A3F",
    "#C25453",
    "#48A5CF",
    "#7AD1FD",
    "#CDD9E1",
    "#29314A",
    "#404586",
    "#53548C",
    "#91465F",
    "#BE6E87",
    "#C98197",
    "#B26C09",
    "#E2953A",
    "#DDAD7E",
    "#73CD9B",
    "#B1FFD1",
    "#F4FFF8",
    "#140F1D",
    "#514854",
    "#817582",
    "#E8DCCF",
)


def _rgb(hex_color: str) -> tuple[int, int, int]:
    return tuple(bytes.fromhex(hex_color.removeprefix("#")))  # type: ignore[return-value]


LOCKED_RGB = tuple(_rgb(color) for color in PALETTE)


def _nearest_locked_color(
    color: tuple[int, int, int],
) -> tuple[int, int, int]:
    return min(
        LOCKED_RGB,
        key=lambda candidate: sum(
            (channel - locked_channel) ** 2
            for channel, locked_channel in zip(color, candidate)
        ),
    )


def _quantize_locked_palette(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    pixels = []
    for red, green, blue, alpha in source.getdata():
        if alpha == 0:
            pixels.append((0, 0, 0, 0))
            continue
        rgb = (red, green, blue)
        locked = cache.setdefault(rgb, _nearest_locked_color(rgb))
        pixels.append((*locked, 255))
    output.putdata(pixels)
    return output


def build() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (384, 192):
        raise ValueError(f"Unexpected PixelLab source size: {source.size}")

    # PixelLab's UI model repeats an unadorned center band. Remove only that
    # repeat: the complete icon well remains in rows 12..95 and the generated
    # mint completion rail remains in rows 168..179. No resampling is used.
    compact = Image.new("RGBA", (384, 96), (0, 0, 0, 0))
    compact.paste(source.crop((0, 12, 384, 96)), (0, 0))
    compact.paste(source.crop((0, 168, 384, 180)), (0, 84))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    _quantize_locked_palette(compact).save(OUTPUT)
    print(OUTPUT.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    build()
