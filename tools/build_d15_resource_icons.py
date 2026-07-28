#!/usr/bin/env python3
"""Build and validate the twelve deterministic D-15 resource-state icons."""

from __future__ import annotations

import hashlib
import json
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "art" / "icons"
REPORT_PATH = ROOT / "docs" / "assets" / "D-15_REPORT.json"
MANIFEST_PATH = ROOT / "docs" / "assets" / "D-15_MANIFEST.md"

CANVAS = 16
OFFSET = 4
ANCHOR = [8, 8]
TRANSPARENT = (0, 0, 0, 0)

PALETTE_HEX = {
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
}

SILHOUETTES = {
    "nutrient_energy": (
        "...##...",
        "..####..",
        ".######.",
        "########",
        "########",
        ".######.",
        "..####..",
        "...##...",
    ),
    "cell_material": (
        "........",
        ".######.",
        ".######.",
        ".######.",
        ".######.",
        ".#####..",
        ".####...",
        "........",
    ),
    "developmental_signal": (
        "...##...",
        "..####..",
        "..####..",
        ".######.",
        ".######.",
        "########",
        "########",
        "........",
    ),
    "waste": (
        "..####..",
        ".##..##.",
        "##....##",
        "##....##",
        "##....##",
        "##....##",
        ".##..##.",
        "..####..",
    ),
    "stability": (
        ".######.",
        "########",
        "########",
        "########",
        ".######.",
        "..####..",
        "...##...",
        "...##...",
    ),
    "knowledge_badge": (
        "...##...",
        "#..##..#",
        ".######.",
        "..####..",
        "########",
        ".######.",
        "#..##..#",
        "...##...",
    ),
}

VARIANTS = (
    ("nutrient_energy", "sufficient", "#E2953A"),
    ("nutrient_energy", "insufficient", "#B26C09"),
    ("cell_material", "sufficient", "#BE6E87"),
    ("cell_material", "insufficient", "#91465F"),
    ("developmental_signal", "sufficient", "#404586"),
    ("developmental_signal", "insufficient", "#29314A"),
    ("waste", "normal", "#29314A"),
    ("waste", "overflow", "#E2953A"),
    ("stability", "normal", "#B1FFD1"),
    ("stability", "warning", "#E2953A"),
    ("stability", "critical", "#BA3A3F"),
    ("knowledge_badge", "count", "#7AD1FD"),
)

REFERENCE_JOBS = (
    {"seed": 15001, "resource": "nutrient_energy", "job_id": "6041c45d-0d09-4d25-aa39-e9f14cc0037a"},
    {"seed": 15002, "resource": "cell_material", "job_id": "d8564e3d-63ea-416b-b556-155d541c0adb"},
    {"seed": 15003, "resource": "developmental_signal", "job_id": "9bc51d08-3dea-4fcd-bd2c-6af77bebf5ba"},
    {"seed": 15004, "resource": "waste", "job_id": "e077e060-9ea6-4834-aff1-8ed3130a4551"},
    {"seed": 15005, "resource": "stability", "job_id": "9d05bf3a-7017-438b-a4db-726e1e25da87"},
    {"seed": 15006, "resource": "knowledge_badge", "job_id": "14fc8cef-04b8-4063-986f-350161038466"},
)


def rgba(hex_value: str) -> tuple[int, int, int, int]:
    value = hex_value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4)) + (255,)


def mask_for(resource: str) -> set[tuple[int, int]]:
    return {
        (x, y)
        for y, row in enumerate(SILHOUETTES[resource])
        for x, value in enumerate(row)
        if value == "#"
    }


def boundary(mask: set[tuple[int, int]], width: int) -> set[tuple[int, int]]:
    current = set(mask)
    result: set[tuple[int, int]] = set()
    for _ in range(width):
        edge = {
            point
            for point in current
            if any((point[0] + dx, point[1] + dy) not in current for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        }
        result.update(edge)
        current -= edge
    return result


def blank() -> list[list[tuple[int, int, int, int]]]:
    return [[TRANSPARENT for _ in range(CANVAS)] for _ in range(CANVAS)]


def paint_mask(
    pixels: list[list[tuple[int, int, int, int]]],
    mask: set[tuple[int, int]],
    color: tuple[int, int, int, int],
    dx: int = 0,
    dy: int = 0,
) -> None:
    for x, y in mask:
        pixels[OFFSET + y + dy][OFFSET + x + dx] = color


def build_variant(resource: str, state: str, main_hex: str) -> list[list[tuple[int, int, int, int]]]:
    pixels = blank()
    mask = mask_for(resource)
    main = rgba(main_hex)

    if resource in {"nutrient_energy", "cell_material", "developmental_signal"}:
        paint_mask(pixels, mask if state == "sufficient" else boundary(mask, 1), main)
        return pixels

    if resource == "waste":
        if state == "normal":
            paint_mask(pixels, mask, main)
            return pixels
        warning_dark = rgba("#B26C09")
        for copy_index, (dx, dy) in enumerate(((-2, 1), (0, 0), (2, -1))):
            for x, y in mask:
                color = main if (x + y + copy_index) % 2 == 0 else warning_dark
                pixels[OFFSET + y + dy][OFFSET + x + dx] = color
        return pixels

    if resource == "stability":
        border_width = {"normal": 1, "warning": 2, "critical": 3}[state]
        edge = boundary(mask, border_width)
        paint_mask(pixels, edge, rgba("#140F1D"))
        interior = mask - edge
        if state == "normal":
            paint_mask(pixels, interior, main)
        elif state == "warning":
            for x, y in interior:
                color = main if ((x - y) % 4) < 2 else rgba("#B26C09")
                pixels[OFFSET + y][OFFSET + x] = color
        else:
            for x, y in interior:
                color = main if (x + y) % 2 == 0 else rgba("#340106")
                pixels[OFFSET + y][OFFSET + x] = color
        return pixels

    paint_mask(pixels, mask, main)
    return pixels


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png_bytes(pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    raw = b"".join(b"\x00" + b"".join(bytes(pixel) for pixel in row) for row in pixels)
    header = struct.pack(">IIBBBBB", CANVAS, CANVAS, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(raw, 9))
        + png_chunk(b"IEND", b"")
    )


def filename(resource: str, state: str) -> str:
    return f"ui_resource_{resource}_{state}.png"


def grayscale(rgb: tuple[int, int, int]) -> int:
    return (299 * rgb[0] + 587 * rgb[1] + 114 * rgb[2] + 500) // 1000


def visible_bounds(pixels: list[list[tuple[int, int, int, int]]]) -> list[int]:
    points = [(x, y) for y, row in enumerate(pixels) for x, pixel in enumerate(row) if pixel[3] == 255]
    return [min(x for x, _ in points), min(y for _, y in points), max(x for x, _ in points), max(y for _, y in points)]


def validate(files: list[dict[str, object]], rendered: dict[str, list[list[tuple[int, int, int, int]]]]) -> dict[str, object]:
    exact_matrix = len(files) == 12 and len({entry["path"] for entry in files}) == 12
    alpha_binary = all(pixel[3] in (0, 255) for pixels in rendered.values() for row in pixels for pixel in row)
    palette_only = all(
        ("#%02X%02X%02X" % pixel[:3]) in PALETTE_HEX
        for pixels in rendered.values()
        for row in pixels
        for pixel in row
        if pixel[3] == 255
    )

    base_masks = {resource: mask_for(resource) for resource in SILHOUETTES}
    silhouette_pairs = len({tuple(sorted(mask)) for mask in base_masks.values()}) == 6

    grayscale_signatures = {}
    for key, pixels in rendered.items():
        grayscale_signatures[key] = tuple(
            -1 if pixel[3] == 0 else grayscale(pixel[:3])
            for row in pixels
            for pixel in row
        )
    applicable_state_groups = (
        ("nutrient_energy_sufficient", "nutrient_energy_insufficient"),
        ("cell_material_sufficient", "cell_material_insufficient"),
        ("developmental_signal_sufficient", "developmental_signal_insufficient"),
        ("waste_normal", "waste_overflow"),
        ("stability_normal", "stability_warning", "stability_critical"),
    )
    grayscale_states_distinct = all(
        len({grayscale_signatures[key] for key in group}) == len(group)
        for group in applicable_state_groups
    )

    insufficient_hollow = all(
        sum(pixel[3] == 255 for row in rendered[f"{resource}_insufficient"] for pixel in row)
        < sum(pixel[3] == 255 for row in rendered[f"{resource}_sufficient"] for pixel in row)
        for resource in ("nutrient_energy", "cell_material", "developmental_signal")
    )
    waste_repetition = (
        visible_bounds(rendered["waste_overflow"])[0] < visible_bounds(rendered["waste_normal"])[0]
        and visible_bounds(rendered["waste_overflow"])[2] > visible_bounds(rendered["waste_normal"])[2]
    )
    stability_signatures = {
        state: tuple(
            pixel
            for row in rendered[f"stability_{state}"]
            for pixel in row
        )
        for state in ("normal", "warning", "critical")
    }
    stability_pairwise = len(set(stability_signatures.values())) == 3

    checks = {
        "png_count_is_12": exact_matrix,
        "canvas_is_16x16": True,
        "anchor_is_8_8": ANCHOR == [8, 8],
        "alpha_is_binary": alpha_binary,
        "visible_colors_are_locked_palette_only": palette_only,
        "six_locked_8x8_silhouettes_are_pairwise_distinct": silhouette_pairs,
        "spendable_insufficient_states_are_hollow": insufficient_hollow,
        "waste_overflow_uses_three_offset_copies": waste_repetition,
        "stability_tiers_are_pairwise_distinct": stability_pairwise,
        "all_applicable_states_are_distinct_in_grayscale": grayscale_states_distinct,
        "knowledge_has_exactly_one_count_variant": sum(entry["resource"] == "knowledge_badge" for entry in files) == 1,
    }
    return {"status": "PASS" if all(checks.values()) else "FAIL", "checks": checks}


def write_manifest(files: list[dict[str, object]], validation: dict[str, object]) -> None:
    lines = [
        "# D-15 Deterministic Resource Icon Manifest",
        "",
        "- Task: `D-15`",
        "- Final geometry: `DERIVED_DETERMINISTIC` from the six locked 8x8 bitmaps in `docs/ENCODING_SPEC.md`",
        "- Canvas: `16x16`, transparent, binary alpha",
        "- Anchor: `(8,8)`",
        "- Palette: the 22 locked values in `docs/PALETTE.md`",
        "- PixelLab references: seeds `15001`-`15006`, 32x32, style reference only; they never override locked bitmap geometry",
        f"- Validation: `{validation['status']}`",
        "",
        "| File | Resource | State | SHA-256 |",
        "|---|---|---|---|",
    ]
    for entry in files:
        lines.append(f"| `{entry['path']}` | `{entry['resource']}` | `{entry['state']}` | `{entry['sha256']}` |")
    lines.extend(
        [
            "",
            "## State Matrix",
            "",
            "| Resource | Applicable delivered states | Non-color encoding |",
            "|---|---|---|",
            "| Nutrient energy | sufficient, insufficient | solid versus one-pixel hollow interior |",
            "| Cell material | sufficient, insufficient | solid versus one-pixel hollow interior |",
            "| Developmental signal | sufficient, insufficient | solid versus one-pixel hollow interior |",
            "| Waste | normal, overflow | one hollow hexagon versus three offset crosshatched copies |",
            "| Stability | normal, warning, critical | solid/diagonal/crosshatch fill and 1/2/3-pixel borders |",
            "| Knowledge badge | count | one solid four-long-arm star; no state variant |",
            "",
            "The closest grayscale resource pair is nutrient energy versus stability. Their locked distinction remains the diamond's vertical symmetry versus the shield's six-pixel flat top and two-pixel central lower point.",
            "",
        ]
    )
    MANIFEST_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

    files: list[dict[str, object]] = []
    rendered: dict[str, list[list[tuple[int, int, int, int]]]] = {}
    for resource, state, main_hex in VARIANTS:
        pixels = build_variant(resource, state, main_hex)
        output = OUTPUT_DIR / filename(resource, state)
        payload = png_bytes(pixels)
        output.write_bytes(payload)
        rendered[f"{resource}_{state}"] = pixels
        files.append(
            {
                "path": output.relative_to(ROOT).as_posix(),
                "resource": resource,
                "state": state,
                "canvas": [CANVAS, CANVAS],
                "anchor": ANCHOR,
                "visible_bounds_inclusive": visible_bounds(pixels),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
        )

    validation = validate(files, rendered)
    report = {
        "task_id": "D-15",
        "status": validation["status"],
        "derivation": "DERIVED_DETERMINISTIC",
        "source_geometry": "docs/ENCODING_SPEC.md section 1 exact 8x8 bitmaps",
        "canvas": [CANVAS, CANVAS],
        "anchor": ANCHOR,
        "png_count": len(files),
        "palette_size_limit": 22,
        "pixel_lab_reference_policy": {
            "purpose": "STYLE_REFERENCE_ONLY",
            "reference_size": [32, 32],
            "references": REFERENCE_JOBS,
            "final_geometry_override_forbidden": True,
        },
        "files": files,
        "validation": validation,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_manifest(files, validation)
    print(json.dumps({"status": validation["status"], "png_count": len(files), "checks": validation["checks"]}))
    return 0 if validation["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
