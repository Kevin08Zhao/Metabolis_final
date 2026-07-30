#!/usr/bin/env python3
"""Build the Metabolis pixel bitmap font.

The repository owns no third-party font binaries. This generator draws every
printable ASCII glyph from an explicit pixel grid, packs them into one atlas,
and emits a BMFont `.fnt` descriptor that Godot imports as a `FontFile`.

Vertical metrics, in font units at native size:

    row 0  ---------------------------------  ascender top
    ...
    row 7  ---------------------------------  baseline  (base=7)
    row 9  ---------------------------------  descender bottom
    lineHeight = 10

Capitals and digits are 7 rows tall and sit directly on the baseline.
Lowercase x-height glyphs are 5 rows tall and carry `yoffset=2`. Lowercase
ascenders use the full 7 rows. Descenders extend two rows past the baseline.

The atlas is pure white with binary alpha, so a Label's `font_color` and
`font_outline_color` fully control the rendered color. That keeps the font off
the art palette contract in `art/palette.gpl`, which governs pixel art rather
than UI theme colors.

Rebuild:

    python tools/build_pixel_font.py --repo-root .
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


FONT_NAME = "MetabolisPixel"
NATIVE_SIZE = 10
LINE_HEIGHT = 10
BASELINE = 7
ATLAS_PADDING = 1

OUTPUT_ROOT = Path("art/fonts")
ATLAS_NAME = "metabolis_pixel_font.png"
DESCRIPTOR_NAME = "metabolis_pixel_font.fnt"
REPORT_PATH = Path("docs/assets/PIXEL_FONT_QA.json")

# Space is the one glyph with no pixels; it only advances the pen.
SPACE_ADVANCE = 4
# Gap inserted after every drawn glyph to produce the xadvance.
LETTER_GAP = 1


def cap(rows: list[str]) -> tuple[int, list[str]]:
    """A glyph whose bottom row rests on the baseline."""
    return 0, rows


def xheight(rows: list[str]) -> tuple[int, list[str]]:
    """A lowercase glyph with no ascender and no descender."""
    return 2, rows


def descender(rows: list[str]) -> tuple[int, list[str]]:
    """A lowercase glyph starting at x-height and dropping below the baseline."""
    return 2, rows


GLYPHS: dict[str, tuple[int, list[str]]] = {
    # ------------------------------------------------------------------
    # Uppercase
    # ------------------------------------------------------------------
    "A": cap([".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"]),
    "B": cap(["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."]),
    "C": cap([".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."]),
    "D": cap(["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."]),
    "E": cap(["#####", "#....", "#....", "####.", "#....", "#....", "#####"]),
    "F": cap(["#####", "#....", "#....", "####.", "#....", "#....", "#...."]),
    "G": cap([".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."]),
    "H": cap(["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"]),
    "I": cap(["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"]),
    "J": cap(["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."]),
    "K": cap(["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"]),
    "L": cap(["#....", "#....", "#....", "#....", "#....", "#....", "#####"]),
    "M": cap(["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"]),
    "N": cap(["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"]),
    "O": cap([".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."]),
    "P": cap(["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."]),
    "Q": cap([".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"]),
    "R": cap(["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"]),
    "S": cap([".####", "#....", "#....", ".###.", "....#", "....#", "####."]),
    "T": cap(["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."]),
    "U": cap(["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."]),
    "V": cap(["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."]),
    "W": cap(["#...#", "#...#", "#...#", "#...#", "#.#.#", "##.##", "#...#"]),
    "X": cap(["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"]),
    "Y": cap(["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."]),
    "Z": cap(["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"]),
    # ------------------------------------------------------------------
    # Digits
    # ------------------------------------------------------------------
    "0": cap([".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."]),
    "1": cap([".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"]),
    "2": cap([".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"]),
    "3": cap(["####.", "....#", "....#", ".###.", "....#", "....#", "####."]),
    "4": cap(["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."]),
    "5": cap(["#####", "#....", "####.", "....#", "....#", "#...#", ".###."]),
    "6": cap([".###.", "#...#", "#....", "####.", "#...#", "#...#", ".###."]),
    "7": cap(["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."]),
    "8": cap([".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."]),
    "9": cap([".###.", "#...#", "#...#", ".####", "....#", "#...#", ".###."]),
    # ------------------------------------------------------------------
    # Lowercase
    # ------------------------------------------------------------------
    "a": xheight([".###.", "....#", ".####", "#...#", ".####"]),
    "b": cap(["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."]),
    "c": xheight([".###.", "#....", "#....", "#....", ".###."]),
    "d": cap(["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"]),
    "e": xheight([".###.", "#...#", "#####", "#....", ".###."]),
    "f": cap(["..##", ".#..", "####", ".#..", ".#..", ".#..", ".#.."]),
    "g": descender([".####", "#...#", "#...#", ".####", "....#", "#...#", ".###."]),
    "h": cap(["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#"]),
    "i": cap([".#.", "...", "##.", ".#.", ".#.", ".#.", "###"]),
    "j": cap(["..#.", "....", "..#.", "..#.", "..#.", "..#.", "..#.", "#.#.", ".##."]),
    "k": cap(["#....", "#....", "#..#.", "#.#..", "##...", "#.#..", "#..#."]),
    "l": cap(["##.", ".#.", ".#.", ".#.", ".#.", ".#.", "###"]),
    "m": xheight(["##.#.", "#.#.#", "#.#.#", "#.#.#", "#.#.#"]),
    "n": xheight(["####.", "#...#", "#...#", "#...#", "#...#"]),
    "o": xheight([".###.", "#...#", "#...#", "#...#", ".###."]),
    "p": descender(["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."]),
    "q": descender([".####", "#...#", "#...#", ".####", "....#", "....#", "....#"]),
    "r": xheight(["#.##", "##..", "#...", "#...", "#..."]),
    "s": xheight([".####", "#....", ".###.", "....#", "####."]),
    "t": cap([".#..", ".#..", "####", ".#..", ".#..", ".#..", "..##"]),
    "u": xheight(["#...#", "#...#", "#...#", "#...#", ".####"]),
    "v": xheight(["#...#", "#...#", "#...#", ".#.#.", "..#.."]),
    "w": xheight(["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."]),
    "x": xheight(["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]),
    "y": descender(["#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."]),
    "z": xheight(["#####", "...#.", "..#..", ".#...", "#####"]),
    # ------------------------------------------------------------------
    # Punctuation and symbols
    # ------------------------------------------------------------------
    "!": cap(["#", "#", "#", "#", "#", ".", "#"]),
    '"': (0, ["#.#", "#.#"]),
    "#": (1, [".#.#.", "#####", ".#.#.", "#####", ".#.#."]),
    "$": (0, ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."]),
    "%": cap(["##..#", "##.#.", "...#.", "..#..", ".#...", "#..##", "...##"]),
    "&": cap([".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"]),
    "'": (0, ["#", "#"]),
    "(": cap([".#", "#.", "#.", "#.", "#.", "#.", ".#"]),
    ")": cap(["#.", ".#", ".#", ".#", ".#", ".#", "#."]),
    "*": (1, [".#.#.", "..#..", "#####", "..#..", ".#.#."]),
    "+": (2, ["..#..", "..#..", "#####", "..#..", "..#.."]),
    ",": (6, [".#", "#."]),
    "-": (4, ["###"]),
    ".": (6, ["#"]),
    "/": cap(["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."]),
    ":": (3, ["#", ".", ".", ".", "#"]),
    ";": (3, [".#", "..", "..", "..", ".#", "#."]),
    "<": (2, ["..#", ".#.", "#..", ".#.", "..#"]),
    "=": (3, ["####", "....", "####"]),
    ">": (2, ["#..", ".#.", "..#", ".#.", "#.."]),
    "?": cap([".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."]),
    "@": cap([".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."]),
    "[": cap(["##", "#.", "#.", "#.", "#.", "#.", "##"]),
    "\\": cap(["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"]),
    "]": cap(["##", ".#", ".#", ".#", ".#", ".#", "##"]),
    "^": (0, [".#.", "#.#"]),
    "_": (8, ["#####"]),
    "`": (0, ["#.", ".#"]),
    "{": cap([".##", ".#.", ".#.", "#..", ".#.", ".#.", ".##"]),
    "|": cap(["#", "#", "#", "#", "#", "#", "#"]),
    "}": cap(["##.", ".#.", ".#.", "..#", ".#.", ".#.", "##."]),
    "~": (3, [".#..#", "#.##."]),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_glyphs() -> None:
    """Reject glyph art that would silently render wrong."""
    for character, (yoffset, rows) in GLYPHS.items():
        if not rows:
            raise ValueError(f"Glyph {character!r} has no rows.")
        widths = {len(row) for row in rows}
        if len(widths) != 1:
            raise ValueError(
                f"Glyph {character!r} has ragged rows: {sorted(widths)}."
            )
        illegal = set("".join(rows)) - {"#", "."}
        if illegal:
            raise ValueError(
                f"Glyph {character!r} uses characters other than '#' and '.': "
                f"{sorted(illegal)}."
            )
        bottom = yoffset + len(rows)
        if bottom > LINE_HEIGHT:
            raise ValueError(
                f"Glyph {character!r} ends at row {bottom}, past lineHeight "
                f"{LINE_HEIGHT}."
            )
        if not any("#" in row for row in rows):
            raise ValueError(f"Glyph {character!r} is blank.")

    expected = {chr(code) for code in range(33, 127)}
    missing = sorted(expected - set(GLYPHS))
    if missing:
        raise ValueError(f"Missing printable ASCII glyphs: {missing}")


def layout(characters: list[str]) -> tuple[int, int, dict[str, tuple[int, int]]]:
    """Pack glyphs into a near-square atlas on a fixed row height."""
    cell_height = max(len(GLYPHS[character][1]) for character in characters)
    columns = 16
    rows_needed = (len(characters) + columns - 1) // columns
    column_width = max(len(GLYPHS[character][1][0]) for character in characters)

    width = columns * (column_width + ATLAS_PADDING) + ATLAS_PADDING
    height = rows_needed * (cell_height + ATLAS_PADDING) + ATLAS_PADDING

    positions: dict[str, tuple[int, int]] = {}
    for index, character in enumerate(characters):
        column = index % columns
        row = index // columns
        x = ATLAS_PADDING + column * (column_width + ATLAS_PADDING)
        y = ATLAS_PADDING + row * (cell_height + ATLAS_PADDING)
        positions[character] = (x, y)
    return width, height, positions


def build_atlas(characters: list[str]) -> tuple[Image.Image, dict[str, dict[str, int]]]:
    width, height, positions = layout(characters)
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = atlas.load()

    records: dict[str, dict[str, int]] = {}
    for character in characters:
        yoffset, rows = GLYPHS[character]
        origin_x, origin_y = positions[character]
        glyph_width = len(rows[0])
        for row_index, row in enumerate(rows):
            for column_index, cell in enumerate(row):
                if cell == "#":
                    pixels[origin_x + column_index, origin_y + row_index] = (
                        255,
                        255,
                        255,
                        255,
                    )
        records[character] = {
            "x": origin_x,
            "y": origin_y,
            "width": glyph_width,
            "height": len(rows),
            "xoffset": 0,
            "yoffset": yoffset,
            "xadvance": glyph_width + LETTER_GAP,
        }
    return atlas, records


def write_descriptor(
    path: Path,
    records: dict[str, dict[str, int]],
    atlas_size: tuple[int, int],
) -> None:
    lines = [
        'info face="{name}" size={size} bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0".format(
            name=FONT_NAME, size=NATIVE_SIZE
        ),
        "common lineHeight={line} base={base} scaleW={width} scaleH={height} "
        "pages=1 packed=0".format(
            line=LINE_HEIGHT,
            base=BASELINE,
            width=atlas_size[0],
            height=atlas_size[1],
        ),
        'page id=0 file="{file}"'.format(file=ATLAS_NAME),
        "chars count={count}".format(count=len(records) + 1),
        # Space carries no pixels, so it is emitted directly rather than drawn.
        "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 "
        "xadvance={advance} page=0 chnl=15".format(advance=SPACE_ADVANCE),
    ]
    for character in sorted(records, key=ord):
        record = records[character]
        lines.append(
            "char id={id} x={x} y={y} width={width} height={height} "
            "xoffset={xoffset} yoffset={yoffset} xadvance={xadvance} "
            "page=0 chnl=15".format(id=ord(character), **record)
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def measure(text: str, records: dict[str, dict[str, int]]) -> int:
    """Advance width of a string at native size, matching Godot's layout."""
    total = 0
    for character in text:
        if character == " ":
            total += SPACE_ADVANCE
        elif character in records:
            total += records[character]["xadvance"]
    return total


def build(repo_root: Path) -> dict[str, object]:
    validate_glyphs()
    characters = sorted(GLYPHS, key=ord)
    atlas, records = build_atlas(characters)

    output = repo_root / OUTPUT_ROOT
    output.mkdir(parents=True, exist_ok=True)
    atlas_path = output / ATLAS_NAME
    atlas.save(atlas_path, optimize=True)
    descriptor_path = output / DESCRIPTOR_NAME
    write_descriptor(descriptor_path, records, atlas.size)

    samples = {
        "METABOLIS": measure("METABOLIS", records),
        "BIRTH OF THE CITY OF LIFE": measure("BIRTH OF THE CITY OF LIFE", records),
        "Continue": measure("Continue", records),
        "New Game": measure("New Game", records),
        "Chapter Select": measure("Chapter Select", records),
        "Body-System City Builder": measure("Body-System City Builder", records),
    }

    report = {
        "status": "PASS",
        "font_name": FONT_NAME,
        "native_size": NATIVE_SIZE,
        "line_height": LINE_HEIGHT,
        "baseline": BASELINE,
        "glyph_count": len(records) + 1,
        "covers_printable_ascii": True,
        "atlas": {
            "path": (OUTPUT_ROOT / ATLAS_NAME).as_posix(),
            "width": atlas.size[0],
            "height": atlas.size[1],
            "sha256": sha256(atlas_path),
        },
        "descriptor": {
            "path": (OUTPUT_ROOT / DESCRIPTOR_NAME).as_posix(),
            "sha256": sha256(descriptor_path),
        },
        "advance_width_at_native_size": samples,
    }
    report_path = repo_root / REPORT_PATH
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    report = build(args.repo_root.resolve())
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
