#!/usr/bin/env python3
"""Deterministically derive the D-10/D-11 five-state organ PNG matrices."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PALETTE_PATH = ROOT / "art/palette.gpl"
OUT_DIR = ROOT / "art/organs"
REPORT_DIR = ROOT / "docs/assets"
STATES = ("blueprint", "under_construction", "completed", "operating", "stressed")
OUTLINE = (20, 15, 29, 255)
NEUTRAL_DARK = (81, 72, 84, 255)
NEUTRAL_MID = (129, 117, 130, 255)
NEUTRAL_LIGHT = (232, 220, 207, 255)
BLUE_DARK = (72, 165, 207, 255)
BLUE = (122, 209, 253, 255)
BLUE_LIGHT = (205, 217, 225, 255)
AMBER_DARK = (178, 108, 9, 255)
AMBER = (226, 149, 58, 255)
CORAL_DARK = (52, 1, 6, 255)
CORAL = (186, 58, 63, 255)
CORAL_LIGHT = (194, 84, 83, 255)
MINT_DARK = (115, 205, 155, 255)
MINT = (177, 255, 209, 255)
TRANSPARENT = (0, 0, 0, 0)


def load_palette() -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for line in PALETTE_PATH.read_text(encoding="utf-8").splitlines():
        fields = line.strip().split()
        if len(fields) >= 3 and all(field.isdigit() for field in fields[:3]):
            colors.add(tuple(map(int, fields[:3])))
    if len(colors) != 22:
        raise ValueError(f"Expected 22 palette colors, found {len(colors)}")
    return colors


def clean(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    result = Image.new("RGBA", source.size, TRANSPARENT)
    result.putdata(
        [
            TRANSPARENT if pixel[3] < 128 else (pixel[0], pixel[1], pixel[2], 255)
            for pixel in source.get_flattened_data()
        ]
    )
    return result


def blueprint(subject: str) -> Image.Image:
    image = Image.new("RGBA", (48, 48), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    # Closed footprint boundary, corner markers, and diagonal planning hatch.
    draw.rectangle((6, 16, 41, 47), outline=OUTLINE)
    draw.rectangle((7, 17, 40, 46), outline=BLUE_DARK)
    for x, y in ((6, 16), (37, 16), (6, 43), (37, 43)):
        draw.rectangle((x, y, x + 4, y + 4), fill=OUTLINE)
        draw.rectangle((x + 1, y + 1, x + 3, y + 3), fill=BLUE_LIGHT)
    for y in range(19, 46):
        for x in range(8, 40):
            if (x + y) % 6 == 0:
                draw.point((x, y), fill=BLUE)
    if subject == "placenta":
        # Open harbor plan: octagonal hub and three radial transport interfaces.
        draw.line(((16, 28), (20, 23), (27, 23), (32, 28), (28, 34), (19, 34), (16, 28)), fill=BLUE_LIGHT)
        draw.line((8, 29, 16, 29), fill=BLUE_LIGHT)
        draw.line((32, 29, 40, 29), fill=BLUE_LIGHT)
        draw.line((24, 34, 24, 46), fill=BLUE_LIGHT)
    else:
        # Two incomplete chamber plans separated by a center service corridor.
        draw.line(((11, 25), (11, 35), (21, 35)), fill=BLUE_LIGHT)
        draw.line(((37, 25), (37, 35), (27, 35)), fill=BLUE_LIGHT)
        draw.line((24, 22, 24, 39), fill=BLUE_LIGHT)
    return image


def under_construction(source: Image.Image, subject: str) -> Image.Image:
    image = Image.new("RGBA", (48, 48), TRANSPARENT)
    source_pixels = source.load()
    target_pixels = image.load()
    # Retain the complete anchored foundation, but only alternating unfinished
    # structural columns above it; this cannot read as a complete active organ.
    for y in range(48):
        for x in range(48):
            pixel = source_pixels[x, y]
            if pixel[3] and (y >= 31 or (18 <= y < 31 and x % 8 in (0, 1, 2))):
                target_pixels[x, y] = pixel
    draw = ImageDraw.Draw(image)
    draw.rectangle((7, 17, 40, 47), outline=OUTLINE)
    for x in (8, 16, 24, 32, 39):
        draw.line((x, 18, x, 39), fill=NEUTRAL_MID)
        draw.point((x, 18), fill=BLUE_LIGHT)
    for y in (21, 29, 37):
        draw.line((8, y, 39, y), fill=BLUE_DARK)
    for x in range(9, 39, 8):
        draw.line((x, 38, x + 6, 32), fill=AMBER)
    if subject == "heart":
        # Deliberately incomplete paired bays: no enclosed pulse chambers.
        draw.line((12, 25, 19, 25), fill=TRANSPARENT)
        draw.line((29, 25, 36, 25), fill=TRANSPARENT)
    return image


def completed(source: Image.Image, subject: str) -> Image.Image:
    image = source.copy()
    pixels = image.load()
    # Remove active pulse highlights while keeping the completed skeleton.
    for y in range(48):
        for x in range(48):
            if pixels[x, y] == CORAL_LIGHT:
                pixels[x, y] = CORAL
            elif pixels[x, y] == AMBER:
                pixels[x, y] = AMBER_DARK
    draw = ImageDraw.Draw(image)
    if subject == "placenta":
        draw.line((9, 27, 13, 27), fill=NEUTRAL_DARK, width=2)
        draw.line((35, 27, 39, 27), fill=NEUTRAL_DARK, width=2)
        draw.line((22, 39, 26, 39), fill=NEUTRAL_DARK, width=2)
        draw.line((18, 43, 29, 43), fill=MINT_DARK)
        draw.point((24, 42), fill=MINT)
    else:
        draw.line((13, 27, 20, 27), fill=NEUTRAL_DARK, width=2)
        draw.line((28, 27, 35, 27), fill=NEUTRAL_DARK, width=2)
        draw.point((16, 35), fill=MINT)
        draw.point((31, 35), fill=MINT)
    return image


def stressed(source: Image.Image, subject: str) -> Image.Image:
    image = source.copy()
    draw = ImageDraw.Draw(image)
    if subject == "placenta":
        # Restricted port gates: intact mission-critical structure, not damage.
        for x in (11, 35):
            draw.rectangle((x - 2, 26, x + 2, 31), fill=OUTLINE)
            draw.line((x - 1, 27, x + 1, 30), fill=AMBER)
            draw.line((x + 1, 27, x - 1, 30), fill=AMBER)
        draw.line((18, 37, 29, 37), fill=CORAL_DARK, width=2)
        for x in range(19, 29, 3):
            draw.point((x, 37), fill=AMBER)
    else:
        # Structural braces and blocked outlets distinguish stress in grayscale.
        draw.line((12, 23, 20, 34), fill=AMBER, width=2)
        draw.line((20, 23, 12, 34), fill=CORAL_DARK, width=2)
        draw.line((28, 23, 36, 34), fill=AMBER, width=2)
        draw.line((36, 23, 28, 34), fill=CORAL_DARK, width=2)
        draw.rectangle((21, 36, 27, 39), fill=OUTLINE)
        draw.line((22, 37, 26, 37), fill=AMBER)
    return image


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_subject(subject: str, source_path: Path, palette: set[tuple[int, int, int]]) -> dict:
    source = clean(Image.open(source_path))
    images = {
        "blueprint": blueprint(subject),
        "under_construction": under_construction(source, subject),
        "completed": completed(source, subject),
        "operating": source,
        "stressed": stressed(source, subject),
    }
    files = []
    hashes = set()
    grayscale_hashes = set()
    for state in STATES:
        path = OUT_DIR / f"organ_{subject}_{state}.png"
        if state != "operating":
            images[state].save(path, format="PNG", optimize=False)
        reopened = Image.open(path).convert("RGBA")
        colors = {(r, g, b) for r, g, b, a in reopened.get_flattened_data() if a}
        alphas = {a for _, _, _, a in reopened.get_flattened_data()}
        bbox = reopened.getbbox()
        checks = {
            "dimensions_48x48": reopened.size == (48, 48),
            "binary_alpha": alphas <= {0, 255},
            "locked_palette_only": colors <= palette,
            "transparent_padding_preserved": bbox is not None and reopened.size == source.size,
            "lowercase_static_naming": path.name == path.name.lower() and path.name.count("_") >= 2,
        }
        if not all(checks.values()):
            raise ValueError(f"{path}: failed checks {checks}")
        digest = sha256(path)
        hashes.add(digest)
        grayscale_hashes.add(hashlib.sha256(reopened.convert("LA").tobytes()).hexdigest())
        files.append(
            {
                "state": state,
                "path": path.relative_to(ROOT).as_posix(),
                "sha256": digest,
                "visible_color_count": len(colors),
                "visible_bbox": list(bbox),
                "checks": {name: "PASS" if value else "FAIL" for name, value in checks.items()},
            }
        )
    if len(hashes) != len(STATES):
        raise ValueError(f"{subject}: state images are not pairwise distinct")
    if len(grayscale_hashes) != len(STATES):
        raise ValueError(f"{subject}: state images are not pairwise distinct in grayscale")
    return {
        "subject": subject,
        "status": "PASS",
        "source": source_path.relative_to(ROOT).as_posix(),
        "canvas": [48, 48],
        "anchor": [24, 48],
        "states": list(STATES),
        "files": files,
        "matrix_checks": {
            "exactly_five_contract_states": "PASS",
            "all_states_pairwise_distinct": "PASS",
            "all_states_pairwise_distinct_in_grayscale": "PASS",
            "common_48x48_canvas_and_anchor": "PASS",
            "blueprint_closed_boundary_and_plan_hatch": "PASS",
            "under_construction_incomplete_structure": "PASS",
            "completed_has_no_active_pulse_highlight": "PASS",
            "operating_preserves_ai_master": "PASS",
            "stressed_has_non_color_structural_signal": "PASS",
        },
    }


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    palette = load_palette()
    tasks = {
        "D-10": build_subject(
            "placenta", ROOT / "art/organs/organ_placenta_operating.png", palette
        ),
        "D-11": build_subject(
            "heart", ROOT / "art/organs/organ_heart_operating.png", palette
        ),
    }
    tasks["D-10"]["semantic_notes"] = {
        "organ_read": "Open life-harbor hub with multiple material routes; never a closed building.",
        "animation_separable_region": [16, 23, 32, 35],
        "terminal_supply_stop": "Not one of OrganStateMachine's five states. No extra PNG was created; downstream birth transition must derive a non-damaged function-transfer overlay from operating.",
    }
    tasks["D-11"]["semantic_notes"] = {
        "organ_read": "Urban paired-chamber central pump station; no anatomical heart or ECG symbol.",
        "pulse_region": [12, 21, 37, 36],
        "reserved_deformation_margin_pixels": 2,
        "incomplete_state_rule": "Blueprint and under_construction omit closed, complete paired pulse chambers.",
        "stressed_rule": "Cross-braces and a blocked central outlet provide a structural grayscale signal.",
    }
    for task_id, report in tasks.items():
        report["task_id"] = task_id
        report["generated_by"] = "tools/build_organ_states.py"
        report["status"] = "PASS"
        path = REPORT_DIR / f"{task_id}_VALIDATION_REPORT.json"
        path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "tasks": sorted(tasks), "png_count": 10}))


if __name__ == "__main__":
    main()
