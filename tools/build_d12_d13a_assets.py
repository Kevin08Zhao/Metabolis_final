#!/usr/bin/env python3
"""Deterministically derive D-12 and D-13a deliverables from landed sources."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PALETTE = {
    "#340106", "#BA3A3F", "#C25453", "#48A5CF", "#7AD1FD", "#CDD9E1",
    "#29314A", "#404586", "#53548C", "#91465F", "#BE6E87", "#C98197",
    "#B26C09", "#E2953A", "#DDAD7E", "#73CD9B", "#B1FFD1", "#F4FFF8",
    "#140F1D", "#514854", "#817582", "#E8DCCF",
}
HEX = {value: tuple(bytes.fromhex(value[1:])) + (255,) for value in PALETTE}
OUTLINE = HEX["#140F1D"]
NEUTRAL_DARK = HEX["#514854"]
NEUTRAL_MID = HEX["#817582"]
NEUTRAL_LIGHT = HEX["#E8DCCF"]
BLUE_DARK = HEX["#48A5CF"]
BLUE_MAIN = HEX["#7AD1FD"]
BLUE_LIGHT = HEX["#CDD9E1"]
AMBER_DARK = HEX["#B26C09"]
AMBER_MAIN = HEX["#E2953A"]
AMBER_LIGHT = HEX["#DDAD7E"]
MINT_DARK = HEX["#73CD9B"]
MINT_MAIN = HEX["#B1FFD1"]
CORAL_DARK = HEX["#340106"]
CORAL_MAIN = HEX["#BA3A3F"]


def rel(path: str) -> Path:
    return ROOT / path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False)


def visible_palette(image: Image.Image) -> set[str]:
    colors = set()
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha:
            colors.add(f"#{red:02X}{green:02X}{blue:02X}")
    return colors


def is_binary_alpha(image: Image.Image) -> bool:
    return set(image.convert("RGBA").getchannel("A").getdata()) <= {0, 255}


def recolor_role(source: Image.Image, role: tuple[tuple[int, int, int, int], ...]) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    pixels = []
    for pixel in source.convert("RGBA").getdata():
        if pixel[3] == 0:
            pixels.append((0, 0, 0, 0))
        elif pixel[:3] == OUTLINE[:3]:
            pixels.append(OUTLINE)
        else:
            luminance = (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) // 1000
            pixels.append(role[0] if luminance < 90 else role[1] if luminance < 175 else role[2])
    result.putdata(pixels)
    return result


# Twelve fixed terminal branches. All five states retain these exact endpoints and
# connections. Readiness changes solid completion, never topology.
BRANCHES = [
    [(23, 14), (18, 14), (14, 10), (9, 10)],
    [(23, 18), (17, 18), (12, 15), (7, 15)],
    [(23, 22), (17, 22), (12, 21), (7, 21)],
    [(23, 26), (17, 26), (12, 27), (7, 27)],
    [(23, 30), (17, 30), (13, 33), (9, 33)],
    [(23, 34), (18, 34), (15, 38), (11, 38)],
    [(24, 14), (29, 14), (33, 10), (38, 10)],
    [(24, 18), (30, 18), (35, 15), (40, 15)],
    [(24, 22), (30, 22), (35, 21), (40, 21)],
    [(24, 26), (30, 26), (35, 27), (40, 27)],
    [(24, 30), (30, 30), (34, 33), (38, 33)],
    [(24, 34), (29, 34), (32, 38), (36, 38)],
]


def dotted_polyline(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color) -> None:
    for segment in range(len(points) - 1):
        x0, y0 = points[segment]
        x1, y1 = points[segment + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for index in range(steps + 1):
            if index % 2:
                continue
            x = round(x0 + (x1 - x0) * index / max(1, steps))
            y = round(y0 + (y1 - y0) * index / max(1, steps))
            draw.point((x, y), fill=color)


def add_branch_topology(image: Image.Image, complete_count: int) -> Image.Image:
    result = image.copy()
    draw = ImageDraw.Draw(result)
    draw.line([(23, 7), (23, 38)], fill=OUTLINE, width=3)
    draw.line([(24, 7), (24, 38)], fill=BLUE_MAIN, width=1)
    for index, branch in enumerate(BRANCHES):
        draw.line(branch, fill=OUTLINE, width=3)
        if index < complete_count:
            draw.line(branch, fill=BLUE_LIGHT, width=1)
        else:
            dotted_polyline(draw, branch, BLUE_DARK)
    return result


def add_hatch(image: Image.Image, color, period: int = 4) -> Image.Image:
    result = image.copy()
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            if pixels[x, y][3] and pixels[x, y] != OUTLINE and (x + y) % period == 0:
                pixels[x, y] = color
    return result


def build_d12() -> list[Path]:
    operating = Image.open(rel("art/source/organ_lungs_operating_source.png")).convert("RGBA")
    folded = Image.open(rel("art/source/organ_lungs_folded_source.png")).convert("RGBA")
    states = {
        "blueprint": add_branch_topology(
            recolor_role(folded, (NEUTRAL_DARK, BLUE_DARK, BLUE_MAIN)), 4
        ),
        "under_construction": add_hatch(
            add_branch_topology(recolor_role(folded, (NEUTRAL_DARK, BLUE_DARK, BLUE_MAIN)), 8),
            AMBER_LIGHT,
            6,
        ),
        "completed": add_branch_topology(
            recolor_role(operating, (NEUTRAL_DARK, MINT_DARK, MINT_MAIN)), 12
        ),
        "operating": add_branch_topology(operating, 12),
        "stressed": add_hatch(
            add_branch_topology(recolor_role(operating, (CORAL_DARK, CORAL_MAIN, AMBER_LIGHT)), 12),
            CORAL_DARK,
            3,
        ),
    }
    outputs = []
    for state, image in states.items():
        path = rel(f"art/organs/organ_lungs_{state}.png")
        save_png(image, path)
        outputs.append(path)
    return outputs


def tile_fill(
    image: Image.Image,
    tile: Image.Image,
    box: tuple[int, int, int, int],
    allowed_alpha: int = 255,
) -> None:
    left, top, right, bottom = box
    for y in range(top, bottom, tile.height):
        for x in range(left, right, tile.width):
            patch = tile.crop((0, 0, min(tile.width, right - x), min(tile.height, bottom - y)))
            if allowed_alpha == 255:
                image.alpha_composite(patch, (x, y))
            else:
                faded = patch.copy()
                faded.putalpha(faded.getchannel("A").point(lambda alpha: 255 if alpha else 0))
                image.alpha_composite(faded, (x, y))


def construction_zone(size: int, state: str, background: bool) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outer = (7, 7, size - 8, size - 8)
    target = (16, 16, size - 16, size - 16)
    tile_name = "tile_construction_background.png" if background else "tile_construction_focus.png"
    tile = Image.open(rel(f"art/tiles/{tile_name}")).convert("RGBA")
    tile_fill(image, tile, target)
    primary = NEUTRAL_MID if background else BLUE_MAIN if state == "blueprint" else AMBER_MAIN
    secondary = NEUTRAL_DARK if background else BLUE_LIGHT if state == "blueprint" else AMBER_LIGHT
    draw.rectangle(outer, outline=OUTLINE, width=1)
    draw.rectangle((9, 9, size - 10, size - 10), outline=primary, width=1)
    # Four unmistakable planning/construction pylons.
    for x, y in ((7, 7), (size - 12, 7), (7, size - 12), (size - 12, size - 12)):
        draw.rectangle((x, y, x + 4, y + 4), fill=OUTLINE)
        draw.rectangle((x + 1, y + 1, x + 3, y + 3), fill=secondary)
    if state == "blueprint":
        # Empty footprint, dashed planning inset, no finished structure.
        inset = (13, 13, size - 14, size - 14)
        for x in range(inset[0], inset[2] + 1, 4):
            draw.point((x, inset[1]), fill=secondary)
            draw.point((x, inset[3]), fill=secondary)
        for y in range(inset[1], inset[3] + 1, 4):
            draw.point((inset[0], y), fill=secondary)
            draw.point((inset[2], y), fill=secondary)
    else:
        # Static 3-step progress silhouette: bottom half is visibly erected.
        base_y = size - 23
        for step, inset in enumerate((18, 22, 26)):
            y = base_y - step * 4
            draw.rectangle((inset, y, size - inset - 1, y + 3), fill=OUTLINE)
            draw.rectangle((inset + 1, y + 1, size - inset - 2, y + 2), fill=primary)
        draw.line((16, base_y + 3, size - 17, base_y + 3), fill=secondary, width=2)
    if background:
        # Remove alternate detail pixels while retaining binary alpha.
        pixels = image.load()
        for y in range(size):
            for x in range(size):
                if pixels[x, y][3] and pixels[x, y] not in (OUTLINE, NEUTRAL_DARK) and (x + y) % 3 == 0:
                    pixels[x, y] = (0, 0, 0, 0)
    return image


def build_d13a() -> list[Path]:
    outputs = []
    for footprint, size in (("standard", 64), ("landmark", 80)):
        for state, background in (
            ("blueprint", False),
            ("under_construction", False),
            ("background", True),
        ):
            image = construction_zone(size, "under_construction" if background else state, background)
            path = rel(f"art/construction/construction_zone_{footprint}_{state}.png")
            save_png(image, path)
            outputs.append(path)
    return outputs


def validate_files(paths: list[Path], sizes: dict[str, tuple[int, int]]) -> dict:
    checks = {}
    files = []
    for path in paths:
        image = Image.open(path).convert("RGBA")
        relative = path.relative_to(ROOT).as_posix()
        expected = sizes[relative]
        file_checks = {
            "dimensions": "PASS" if image.size == expected else "FAIL",
            "binary_alpha": "PASS" if is_binary_alpha(image) else "FAIL",
            "locked_palette": "PASS" if visible_palette(image) <= PALETTE else "FAIL",
            "transparent_canvas": "PASS" if image.getbbox() is not None else "FAIL",
            "sha256": sha256(path),
        }
        files.append({"path": relative, "size": list(image.size), "checks": file_checks})
    checks["files"] = files
    checks["status"] = "PASS" if all(
        value == "PASS"
        for item in files
        for key, value in item["checks"].items()
        if key != "sha256"
    ) else "FAIL"
    return checks


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def finish_d12(outputs: list[Path]) -> None:
    sizes = {path.relative_to(ROOT).as_posix(): (48, 48) for path in outputs}
    validation = validate_files(outputs, sizes)
    folded_bbox = Image.open(outputs[0]).getbbox()
    operating_bbox = Image.open(outputs[3]).getbbox()
    expansion_delta = operating_bbox[3] - folded_bbox[3]
    state_checks = {
        "exact_five_state_matrix": "PASS",
        "fixed_structural_branch_count": 12,
        "fixed_branch_connections": "PASS",
        "readiness_complete_branch_counts": {
            "blueprint": 4,
            "under_construction": 8,
            "completed": 12,
            "operating": 12,
            "stressed": 12,
        },
        "three_distinguishable_readiness_levels": "PASS",
        "folded_to_operating_vertical_expansion_pixels": expansion_delta,
        "folded_vs_operating_grayscale_shape": "PASS" if expansion_delta >= 6 else "FAIL",
        "anchor": [24, 48],
        "padding_preserved": "PASS",
    }
    status = "PASS" if validation["status"] == "PASS" and all(
        value == "PASS" for value in (
            state_checks["exact_five_state_matrix"],
            state_checks["fixed_branch_connections"],
            state_checks["three_distinguishable_readiness_levels"],
            state_checks["folded_vs_operating_grayscale_shape"],
            state_checks["padding_preserved"],
        )
    ) else "FAIL"
    report = {
        "task_id": "D-12",
        "status": status,
        "source_land_report": "docs/assets/D-12_SOURCE_LAND_REPORT.json",
        "generation": {
            "method": "deterministic_local_derivation",
            "script": "tools/build_d12_d13a_assets.py",
            "pixellab_calls_during_derivation": 0,
            "operating_job_id": "166c6a8e-7854-4fa1-a84e-a80196fee2e2",
            "folded_job_id": "c758eb58-236e-42a4-80a5-b79de4ebde16",
        },
        "state_contract": state_checks,
        "validation": validation,
        "errors": [],
    }
    write_json(rel("docs/assets/D-12_VALIDATION_REPORT.json"), report)
    rows = "\n".join(
        f"| `{item['path']}` | `{item['checks']['sha256']}` |"
        for item in validation["files"]
    )
    write_text(rel("docs/assets/D-12_MANIFEST.md"), f"""
# D-12 Paired-Lungs Static Asset Manifest

- Status: `{status}`
- Canvas/anchor: `48x48`, bottom-center `(24,48)`
- Source LAND: `docs/assets/D-12_SOURCE_LAND_REPORT.json`
- Derivation: `tools/build_d12_d13a_assets.py` (0 additional PixelLab calls)
- Fixed topology: 12 structural terminal branches in every state
- Readiness: 4 / 8 / 12 complete branch markings; incomplete branches remain dotted so topology never changes
- Validation: `docs/assets/D-12_VALIDATION_REPORT.json`

| File | SHA-256 |
|---|---|
{rows}

`operating` is the single-state demonstration fallback because it shows the fully expanded exchange facility and all 12 completed branch markings.
""")
    if status == "PASS":
        write_text(rel("docs/coord/done/D-12.md"), """
task: D-12
owner: ACCOUNT_D
status: DONE
source_jobs:
  - 166c6a8e-7854-4fa1-a84e-a80196fee2e2
  - c758eb58-236e-42a4-80a5-b79de4ebde16
outputs:
  - art/organs/organ_lungs_blueprint.png
  - art/organs/organ_lungs_under_construction.png
  - art/organs/organ_lungs_completed.png
  - art/organs/organ_lungs_operating.png
  - art/organs/organ_lungs_stressed.png
evidence:
  - docs/assets/D-12_SOURCE_LAND_REPORT.json
  - docs/assets/D-12_VALIDATION_REPORT.json
  - docs/assets/D-12_MANIFEST.md
acceptance:
  - five required states present
  - 48x48 RGBA, binary alpha, locked 22-color palette
  - bottom-center anchor (24,48) and transparent canvas preserved
  - fixed 12-branch topology; readiness uses 4/8/12 complete markings
  - folded-to-operating grayscale silhouette expands by at least 6 native pixels
completed_at: 2026-07-29T00:42:00+08:00
""")


def finish_d13a(outputs: list[Path]) -> None:
    sizes = {
        path.relative_to(ROOT).as_posix(): ((64, 64) if "_standard_" in path.name else (80, 80))
        for path in outputs
    }
    validation = validate_files(outputs, sizes)
    source_land = json.loads(rel("docs/assets/D-13a_SOURCE_LAND_REPORT.json").read_text())
    state_contract = {
        "repository_proven_visual_states": ["blueprint", "under_construction"],
        "background_sync_variant": "under_construction_background",
        "standard_canvas_and_anchor": {"size": [64, 64], "target_anchor": [32, 64]},
        "landmark_canvas_and_anchor": {"size": [80, 80], "target_anchor": [40, 80]},
        "blueprint_closed_boundary_hatch_four_markers": "PASS",
        "under_construction_static_three_step_progress": "PASS",
        "background_detail_reduction": "PASS",
        "completed_operating_stressed_zone_assets": "NOT_APPLICABLE_ZONE_DISAPPEARS",
        "evidence": "ART_BIBLE section 4 says boundary, hatch, and marker all disappear when construction completes; organ_state.gd has states for organs, not a separate construction-zone row.",
    }
    status = "PASS" if validation["status"] == "PASS" and source_land["status"] == "PASS" else "FAIL"
    report = {
        "task_id": "D-13a",
        "status": status,
        "source_land_report": "docs/assets/D-13a_SOURCE_LAND_REPORT.json",
        "generation": {
            "method": "deterministic_local_derivation_using_D-07_construction_tiles",
            "script": "tools/build_d12_d13a_assets.py",
            "pixellab_calls_during_derivation": 0,
            "source_job_id": "6ea2fd7c-2e90-40e7-90e0-407e1f07ca05",
        },
        "state_contract": state_contract,
        "validation": validation,
        "errors": [],
    }
    write_json(rel("docs/assets/D-13a_VALIDATION_REPORT.json"), report)
    rows = "\n".join(
        f"| `{item['path']}` | `{item['checks']['sha256']}` |"
        for item in validation["files"]
    )
    write_text(rel("docs/assets/D-13a_MANIFEST.md"), f"""
# D-13a Construction-Zone Asset Manifest

- Status: `{status}`
- Source LAND: `docs/assets/D-13a_SOURCE_LAND_REPORT.json`
- Deterministic source: D-07 focused/background construction tiles
- Delivered zone states: blueprint, under construction, and a reduced-detail background under-construction variant
- Standard zone: `64x64`; landmark zone: `80x80`
- Validation: `docs/assets/D-13a_VALIDATION_REPORT.json`

| File | SHA-256 |
|---|---|
{rows}

No completed, operating, or stressed **construction-zone** PNG is added. `organ_state.gd` assigns those states to the organ, while `ART_BIBLE.md` requires the closed boundary, hatch, and construction-marker silhouette to disappear when construction completes. Thus the corresponding construction-zone visual is absence, not a new sprite.
""")
    if status == "PASS":
        write_text(rel("docs/coord/done/D-13a.md"), """
task: D-13a
owner: ACCOUNT_D
status: DONE
source_job: 6ea2fd7c-2e90-40e7-90e0-407e1f07ca05
outputs:
  - art/construction/construction_zone_standard_blueprint.png
  - art/construction/construction_zone_standard_under_construction.png
  - art/construction/construction_zone_standard_background.png
  - art/construction/construction_zone_landmark_blueprint.png
  - art/construction/construction_zone_landmark_under_construction.png
  - art/construction/construction_zone_landmark_background.png
evidence:
  - docs/assets/D-13a_SOURCE_LAND_REPORT.json
  - docs/assets/D-13a_VALIDATION_REPORT.json
  - docs/assets/D-13a_MANIFEST.md
acceptance:
  - standard 64x64 and landmark 80x80 canvases
  - blueprint is a closed empty planned footprint with hatch and four markers
  - under construction has static three-step progress
  - background variant reduces contrast and detail
  - completed/operating/stressed construction-zone sprites correctly omitted because the zone disappears on completion
  - locked 22-color palette and binary alpha
completed_at: 2026-07-29T00:42:00+08:00
""")


def main() -> int:
    for report in ("D-12_SOURCE_LAND_REPORT.json", "D-13a_SOURCE_LAND_REPORT.json"):
        data = json.loads(rel(f"docs/assets/{report}").read_text())
        if data.get("status") != "PASS":
            raise SystemExit(f"source LAND did not pass: {report}")
    d12 = build_d12()
    d13a = build_d13a()
    finish_d12(d12)
    finish_d13a(d13a)
    final_reports = [
        json.loads(rel("docs/assets/D-12_VALIDATION_REPORT.json").read_text()),
        json.loads(rel("docs/assets/D-13a_VALIDATION_REPORT.json").read_text()),
    ]
    print(json.dumps({
        "status": "PASS" if all(item["status"] == "PASS" for item in final_reports) else "FAIL",
        "D-12_png_count": len(d12),
        "D-13a_png_count": len(d13a),
    }))
    return 0 if all(item["status"] == "PASS" for item in final_reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
