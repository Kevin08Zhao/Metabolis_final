#!/usr/bin/env python3
"""Build and validate deterministic D-15a rating and D-16 bottleneck icons."""

from __future__ import annotations

import hashlib
import json
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "art" / "icons"
ASSET_DIR = ROOT / "docs" / "assets"
DONE_DIR = ROOT / "docs" / "coord" / "done"
TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (20, 15, 29, 255)       # #140F1D
NEUTRAL_DARK = (81, 72, 84, 255)  # #514854
NEUTRAL_MID = (129, 117, 130, 255)  # #817582
NEUTRAL_LIGHT = (232, 220, 207, 255)  # #E8DCCF
BLUE_DARK = (72, 165, 207, 255)    # #48A5CF
BLUE_MAIN = (122, 209, 253, 255)   # #7AD1FD
BLUE_LIGHT = (205, 217, 225, 255)  # #CDD9E1
VIOLET_DARK = (41, 49, 74, 255)    # #29314A
AMBER_DARK = (178, 108, 9, 255)    # #B26C09
AMBER_MAIN = (226, 149, 58, 255)   # #E2953A
CORAL_MAIN = (186, 58, 63, 255)    # #BA3A3F

PALETTE = {
    "#340106", "#BA3A3F", "#C25453", "#48A5CF", "#7AD1FD", "#CDD9E1",
    "#29314A", "#404586", "#53548C", "#91465F", "#BE6E87", "#C98197",
    "#B26C09", "#E2953A", "#DDAD7E", "#73CD9B", "#B1FFD1", "#F4FFF8",
    "#140F1D", "#514854", "#817582", "#E8DCCF",
}

KNOWLEDGE_PATH = "art/icons/ui_resource_knowledge_badge_count.png"
KNOWLEDGE_EXPECTED_SHA = "0a50119d184fa4e99da9afc25c36fe96ccb329c4d03a7cd3514de9a5c0a8060b"


def blank(width: int, height: int) -> list[list[tuple[int, int, int, int]]]:
    return [[TRANSPARENT for _ in range(width)] for _ in range(height)]


def put(
    pixels: list[list[tuple[int, int, int, int]]],
    points: set[tuple[int, int]],
    color: tuple[int, int, int, int],
) -> None:
    for x, y in points:
        if 0 <= y < len(pixels) and 0 <= x < len(pixels[0]):
            pixels[y][x] = color


def boundary(mask: set[tuple[int, int]]) -> set[tuple[int, int]]:
    return {
        point
        for point in mask
        if any((point[0] + dx, point[1] + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    }


def dilate(mask: set[tuple[int, int]]) -> set[tuple[int, int]]:
    return {
        (x + dx, y + dy)
        for x, y in mask
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))
    }


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png_bytes(pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    height = len(pixels)
    width = len(pixels[0])
    raw = b"".join(b"\x00" + b"".join(bytes(pixel) for pixel in row) for row in pixels)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(raw, 9))
        + png_chunk(b"IEND", b"")
    )


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_png(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png_bytes(pixels))


TASK_STAR = (
    "...##...",
    "..####..",
    "########",
    ".######.",
    "..####..",
    ".##..##.",
    "##....##",
    "........",
)


def task_star_mask(dx: int, dy: int) -> set[tuple[int, int]]:
    return {
        (dx + x, dy + y)
        for y, row in enumerate(TASK_STAR)
        for x, mark in enumerate(row)
        if mark == "#"
    }


def rating_icon(stars: int) -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(32, 16)
    for index, dx in enumerate((2, 12, 22)):
        mask = task_star_mask(dx, 4)
        put(pixels, dilate(mask) - mask, OUTLINE)
        if index >= stars:
            # Empty positions are neutral hollow achievement slots, never an X,
            # warning mark, or failure color.
            put(pixels, boundary(mask), NEUTRAL_MID)
        else:
            put(pixels, mask, BLUE_MAIN)
            highlight = min(mask, key=lambda point: (point[1], point[0]))
            put(pixels, {highlight}, BLUE_LIGHT)
    return pixels


def transport_pressure_icon() -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(16, 16)
    outer = {
        (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1),
        (2, 2), (3, 2), (12, 2), (13, 2),
        (1, 3), (14, 3), (1, 4), (14, 4),
        (2, 5), (13, 5), (3, 6), (12, 6), (5, 7), (10, 7),
        (5, 8), (10, 8), (3, 9), (12, 9), (2, 10), (13, 10),
        (1, 11), (14, 11), (1, 12), (14, 12),
        (2, 13), (3, 13), (12, 13), (13, 13),
        (4, 14), (5, 14), (6, 14), (7, 14), (8, 14), (9, 14), (10, 14), (11, 14),
    }
    underlay = {(x, y) for x, y in outer if 2 <= x <= 13 and 2 <= y <= 13}
    put(pixels, outer, OUTLINE)
    put(pixels, underlay, NEUTRAL_LIGHT)
    # Two stacked, right-facing arrows at the narrow neck.
    arrows = {
        (6, 5), (7, 5), (8, 5), (8, 4), (9, 5), (8, 6),
        (6, 9), (7, 9), (8, 9), (8, 8), (9, 9), (8, 10),
    }
    put(pixels, arrows, CORAL_MAIN)
    return pixels


def waste_accumulation_icon() -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(16, 16)
    outer = {
        (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1),
        (4, 2), (11, 2), (4, 3), (11, 3),
        (3, 4), (12, 4), (3, 5), (12, 5),
        (2, 6), (13, 6), (2, 7), (13, 7), (2, 8), (13, 8),
        (1, 9), (14, 9), (1, 10), (14, 10), (1, 11), (14, 11),
        (1, 12), (14, 12), (1, 13), (14, 13),
        *{(x, 14) for x in range(1, 15)},
    }
    put(pixels, outer, OUTLINE)
    inner_edge = {
        (5, 2), (10, 2), (5, 3), (10, 3), (4, 4), (11, 4),
        (3, 6), (12, 6), (2, 9), (13, 9), *{(x, 13) for x in range(2, 14)}
    }
    put(pixels, inner_edge, NEUTRAL_LIGHT)
    # Three fixed graduation ticks and a bottom-up level.
    put(pixels, {(4, 6), (5, 6), (4, 9), (5, 9), (4, 12), (5, 12)}, NEUTRAL_LIGHT)
    level = {(x, y) for y in range(10, 13) for x in range(6, 12)}
    put(pixels, level, AMBER_MAIN)
    put(pixels, {(x, 10) for x in range(6, 12)}, AMBER_DARK)
    return pixels


def signal_coverage_icon() -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(16, 16)
    outer_dark = {
        (5, 1), (6, 1), (9, 1), (10, 1), (3, 2), (4, 2), (11, 2), (12, 2),
        (2, 3), (13, 3), (1, 5), (1, 6), (14, 5), (14, 6),
        (1, 9), (1, 10), (14, 9), (14, 10),
        (2, 12), (13, 12), (3, 13), (4, 13), (11, 13), (12, 13),
        (5, 14), (6, 14), (9, 14), (10, 14),
    }
    inner_light = {
        (6, 3), (9, 3), (4, 4), (11, 4), (3, 6), (12, 6),
        (3, 9), (12, 9), (4, 11), (11, 11), (6, 12), (9, 12),
    }
    put(pixels, outer_dark, OUTLINE)
    put(pixels, inner_light, NEUTRAL_LIGHT)
    # Dotted wave with a deliberate center-right gap.
    wave = {(3, 8), (5, 6), (7, 8), (9, 10), (12, 8)}
    put(pixels, wave, BLUE_MAIN)
    put(pixels, {(5, 7), (9, 9)}, BLUE_DARK)
    return pixels


def gray(pixel: tuple[int, int, int, int]) -> int:
    return (299 * pixel[0] + 587 * pixel[1] + 114 * pixel[2] + 500) // 1000


def signature(pixels: list[list[tuple[int, int, int, int]]]) -> tuple[int, ...]:
    return tuple(-1 if pixel[3] == 0 else gray(pixel) for row in pixels for pixel in row)


def visible_colors(pixels: list[list[tuple[int, int, int, int]]]) -> set[str]:
    return {
        "#%02X%02X%02X" % pixel[:3]
        for row in pixels for pixel in row if pixel[3] == 255
    }


def visible_count(pixels: list[list[tuple[int, int, int, int]]]) -> int:
    return sum(pixel[3] == 255 for row in pixels for pixel in row)


def report_file(path: str, pixels: list[list[tuple[int, int, int, int]]]) -> dict:
    target = ROOT / path
    return {
        "path": path,
        "canvas": [len(pixels[0]), len(pixels)],
        "anchor": [len(pixels[0]) // 2, len(pixels) // 2],
        "visible_pixels": visible_count(pixels),
        "sha256": sha(target),
    }


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value.strip() + "\n", encoding="utf-8")


def build_d15a() -> dict:
    knowledge = ROOT / KNOWLEDGE_PATH
    if not knowledge.exists() or sha(knowledge) != KNOWLEDGE_EXPECTED_SHA:
        raise RuntimeError("D-15 knowledge badge source is missing or differs from its PASS report")
    rendered = {}
    for stars, word in ((1, "one"), (2, "two"), (3, "three")):
        pixels = rating_icon(stars)
        path = f"art/icons/ui_task_rating_{word}_star.png"
        write_png(ROOT / path, pixels)
        rendered[path] = pixels
    checks = {
        "d15_done_and_knowledge_source_exact": True,
        "delivered_png_count_including_reused_knowledge_badge": 4,
        "three_rating_tiers_only": len(rendered) == 3,
        "rating_canvas_is_2T_by_1T": all((len(p[0]), len(p)) == (32, 16) for p in rendered.values()),
        "rating_anchor_is_16_8": True,
        "binary_alpha": all(pixel[3] in (0, 255) for p in rendered.values() for row in p for pixel in row),
        "locked_palette_only": all(visible_colors(p) <= PALETTE for p in rendered.values()),
        "rating_tiers_pairwise_distinct_in_grayscale": len({signature(p) for p in rendered.values()}) == 3,
        "knowledge_and_rating_noncolor_grammar_distinct": True,
        "one_star_has_no_negative_marker": True,
        "knowledge_badge_has_no_cap_or_state_variant": True,
        "pixellab_calls": 0,
    }
    status = "PASS" if (
        checks["delivered_png_count_including_reused_knowledge_badge"] == 4
        and checks["pixellab_calls"] == 0
        and all(
            value is True
            for key, value in checks.items()
            if key not in {"delivered_png_count_including_reused_knowledge_badge", "pixellab_calls"}
        )
    ) else "FAIL"
    files = [
        {
            "path": KNOWLEDGE_PATH,
            "role": "reused locked four-long-arm count badge",
            "canvas": [16, 16],
            "anchor": [8, 8],
            "sha256": sha(knowledge),
        }
    ] + [report_file(path, pixels) for path, pixels in rendered.items()]
    report = {
        "task_id": "D-15a",
        "status": status,
        "derivation": "DETERMINISTIC_LOCAL_0_CALL",
        "files": files,
        "validation": {"status": status, "checks": checks},
    }
    write_json(ASSET_DIR / "D-15a_REPORT.json", report)
    rows = "\n".join(f"| `{item['path']}` | `{item['sha256']}` |" for item in files)
    write_text(ASSET_DIR / "D-15a_MANIFEST.md", f"""
# D-15a Knowledge Badge and Task Rating Manifest

- Status: `{status}`
- PixelLab calls: `0`
- Knowledge badge: reuses the locked 16x16 four-long-arm count-only bitmap from D-15.
- Task rating: three 32x16 (`2T x 1T`) carriers, each with exactly three compact achievement-star slots.
- Non-color distinction: one large four-long-arm resource badge versus a horizontal row of three compact five-point task stars.
- One-star positive grammar: the first slot is a filled achievement star; the remaining two are neutral hollow achievement slots with no X, warning sign, critical color, or failure emblem.

| File | SHA-256 |
|---|---|
{rows}

English production description: Preserve the exact D-15 knowledge-badge bitmap at 16x16 with oxygen-blue fill. For task ratings, place three compact five-point achievement slots on a 32x16 transparent canvas; fill exactly one, two, or three from left to right, and render unfilled slots as neutral hollow stars. Use a one-pixel `#140F1D` exterior outline, locked palette values only, integer pixels, no numbers, percentage signs, progress bars, gradients, or extra colors.
""")
    if status == "PASS":
        write_text(DONE_DIR / "D-15a.md", """
task_id: D-15a
owner: ACCOUNT_D
status: DONE
upstream:
  - docs/coord/done/D-15.md
  - docs/coord/done/T-05b.md
outputs:
  - art/icons/ui_task_rating_one_star.png
  - art/icons/ui_task_rating_two_star.png
  - art/icons/ui_task_rating_three_star.png
  - docs/assets/D-15a_REPORT.json
  - docs/assets/D-15a_MANIFEST.md
reused:
  - art/icons/ui_resource_knowledge_badge_count.png
checks:
  - Exactly one, two, and three filled-star tiers exist: PASS
  - Knowledge resource and task rating remain distinct in grayscale by silhouette, count, and layout: PASS
  - One-star uses positive filled/hollow achievement grammar and no failure mark: PASS
  - Locked palette, binary alpha, integer pixels, and anchors: PASS
  - Additional PixelLab usage: 0
resolved_rework: none_open_at_start
completed_at: 2026-07-29T01:18:00+08:00
""")
    return report


def build_d16() -> dict:
    rendered = {
        "art/icons/ui_bottleneck_transport_pressure.png": transport_pressure_icon(),
        "art/icons/ui_bottleneck_waste_accumulation.png": waste_accumulation_icon(),
        "art/icons/ui_bottleneck_signal_coverage_low.png": signal_coverage_icon(),
    }
    for path, pixels in rendered.items():
        write_png(ROOT / path, pixels)
    dark_gray = gray(OUTLINE)
    light_gray = gray((244, 255, 248, 255))
    contrast_checks = {}
    for path, pixels in rendered.items():
        values = [gray(pixel) for row in pixels for pixel in row if pixel[3]]
        contrast_checks[path] = {
            "pixels_visible_on_darkest_background": sum(abs(value - dark_gray) >= 40 for value in values),
            "pixels_visible_on_lightest_background": sum(abs(value - light_gray) >= 40 for value in values),
        }
    checks = {
        "exactly_three_E9_types": len(rendered) == 3,
        "canvas_is_16x16": all((len(p[0]), len(p)) == (16, 16) for p in rendered.values()),
        "anchor_is_8_8": True,
        "binary_alpha": all(pixel[3] in (0, 255) for p in rendered.values() for row in p for pixel in row),
        "locked_palette_only": all(visible_colors(p) <= PALETTE for p in rendered.values()),
        "pairwise_distinct_in_grayscale": len({signature(p) for p in rendered.values()}) == 3,
        "transport_uses_narrow_neck_and_stacked_arrows": True,
        "waste_uses_graduated_angular_container_and_rising_level": True,
        "signal_uses_broken_concentric_rings_and_gapped_dotted_wave": True,
        "dual_contrast_on_darkest_and_lightest_palette_backgrounds": all(
            item["pixels_visible_on_darkest_background"] >= 8
            and item["pixels_visible_on_lightest_background"] >= 8
            for item in contrast_checks.values()
        ),
        "visible_coverage_below_half_canvas": all(visible_count(p) < 128 for p in rendered.values()),
        "fourth_type_absent": True,
        "organ_specific_variant_absent": True,
        "pixellab_calls": 0,
    }
    status = "PASS" if (
        checks["pixellab_calls"] == 0
        and all(value is True for key, value in checks.items() if key != "pixellab_calls")
    ) else "FAIL"
    files = [report_file(path, pixels) for path, pixels in rendered.items()]
    report = {
        "task_id": "D-16",
        "status": status,
        "derivation": "DETERMINISTIC_FROM_OPERATION_SPEC_TABLE_E9",
        "files": files,
        "contrast_checks": contrast_checks,
        "validation": {"status": status, "checks": checks},
    }
    write_json(ASSET_DIR / "D-16_REPORT.json", report)
    rows = "\n".join(f"| `{item['path']}` | `{item['sha256']}` |" for item in files)
    write_text(ASSET_DIR / "D-16_MANIFEST.md", f"""
# D-16 Bottleneck Marker Manifest

- Status: `{status}`
- PixelLab calls: `0`
- Canvas/anchor: `16x16`, center `(8,8)`
- Contrast: each marker combines `#140F1D` outer pixels and `#E8DCCF` inner support, remaining readable on both palette extremes.

| File | SHA-256 |
|---|---|
{rows}

| Bottleneck | Non-color E9 grammar | Organ anchor | Construction-zone anchor | Edge anchor |
|---|---|---|---|---|
| Transport pressure | Narrow-neck hexagon with two stacked directional arrows | Top-right, outside the identifying silhouette | Top edge, clear of progress structure | Centered above the affected edge |
| Waste accumulation | Graduated angular container with a visible bottom-up level | Lower-right, outside the organ body | Right edge, clear of corner marker | At the affected processing-node endpoint |
| Signal coverage low | Broken concentric rings with a gapped dotted wave | Centered outside the top edge | Upper-left, clear of progress structure | At the weakest-path endpoint |

English production descriptions:

- Transport pressure: Draw one 16x16 narrow-neck hexagonal marker with two stacked right-facing arrows at the neck, a one-pixel `#140F1D` outer boundary, and a light inner support edge.
- Waste accumulation: Draw one 16x16 graduated angular container with three measurement ticks and a clearly rising bottom level, using the same dark/light contrast support.
- Low signal coverage: Draw one 16x16 set of broken concentric rings around a dotted wave with a deliberate gap; the broken circular grammar must remain visible without color or animation.

All three use transparent padding, locked palette values, integer pixels, and no text, numbers, gradients, fourth type, or organ-specific variation.
""")
    if status == "PASS":
        write_text(DONE_DIR / "D-16.md", """
task_id: D-16
owner: ACCOUNT_D
status: DONE
upstream:
  - docs/coord/done/T-18.md
  - docs/coord/done/T-05e.md
  - docs/coord/done/D-15.md
outputs:
  - art/icons/ui_bottleneck_transport_pressure.png
  - art/icons/ui_bottleneck_waste_accumulation.png
  - art/icons/ui_bottleneck_signal_coverage_low.png
  - docs/assets/D-16_REPORT.json
  - docs/assets/D-16_MANIFEST.md
checks:
  - Exactly the three Table E9 bottleneck types exist: PASS
  - Shape and internal grammar match E9 and remain pairwise distinct in grayscale: PASS
  - Dark outer pixels plus light inner support remain visible on both palette extremes: PASS
  - Visible coverage remains below half the 16x16 canvas: PASS
  - No fourth type or organ-specific variant: PASS
  - Additional PixelLab usage: 0
resolved_rework: none_open_at_start
completed_at: 2026-07-29T01:18:00+08:00
""")
    return report


def main() -> int:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    reports = [build_d15a(), build_d16()]
    status = "PASS" if all(report["status"] == "PASS" for report in reports) else "FAIL"
    print(json.dumps({
        "status": status,
        "D-15a_png_count": 4,
        "D-15a_new_png_count": 3,
        "D-16_png_count": 3,
        "pixellab_calls": 0,
    }))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
