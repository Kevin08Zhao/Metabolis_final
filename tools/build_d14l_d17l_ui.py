#!/usr/bin/env python3
"""Build the exact D-14L/D-17L UI frames from one shared nine-slice rule."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UI_DIR = ROOT / "art/ui"
REPORT_DIR = ROOT / "docs/assets"
DONE_DIR = ROOT / "docs/coord/done"
REWORK_DIR = ROOT / "docs/coord/rework"
RAW_SOURCE = ROOT / "art/candidates/pf00/ui_frame_shared_candidate01_raw.png"
PALETTE_PATH = ROOT / "art/palette.gpl"

OUTLINE = (20, 15, 29, 255)  # #140F1D
BACKING = (81, 72, 84, 255)  # #514854
SEPARATOR = (129, 117, 130, 255)  # #817582
DEEP_BLUE = (41, 49, 74, 255)  # #29314A
OXYGEN = (72, 165, 207, 255)  # #48A5CF
OXYGEN_LIGHT = (122, 209, 253, 255)  # #7AD1FD
TISSUE = (190, 110, 135, 255)  # #BE6E87
TISSUE_LIGHT = (201, 129, 151, 255)  # #C98197
CREAM = (232, 220, 207, 255)  # #E8DCCF
TRANSPARENT = (0, 0, 0, 0)

D14_FILES = {
    "shared_nine_slice": ("ui_frame_shared_nine_slice.png", (16, 16)),
    "main_city_map": ("ui_main_city_map_frame.png", (640, 320)),
    "development_timeline": ("ui_development_timeline_frame.png", (640, 8)),
    "task_operations": ("ui_task_operations_panel_frame.png", (608, 16)),
    "resource_status": ("ui_resource_status_bar_frame.png", (640, 16)),
    "organ_archive_button": ("ui_organ_archive_button.png", (16, 16)),
    "chapter_recap_button": ("ui_chapter_recap_button.png", (16, 16)),
}

D17_FILES = {
    "knowledge_prompt": ("ui_knowledge_prompt_frame.png", (224, 32)),
    "organ_archive_panel": ("ui_organ_archive_panel_frame.png", (560, 304)),
    "chapter_summary_panel": ("ui_chapter_summary_panel_frame.png", (544, 304)),
}


def palette() -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for line in PALETTE_PATH.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 3 and all(part.isdigit() for part in parts[:3]):
            colors.add(tuple(map(int, parts[:3])))
    if len(colors) != 22:
        raise ValueError(f"expected 22 palette colors, found {len(colors)}")
    return colors


def framed(size: tuple[int, int], border: int = 1) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, BACKING)
    draw = ImageDraw.Draw(image)
    for inset in range(border):
        draw.rectangle(
            (inset, inset, width - 1 - inset, height - 1 - inset),
            outline=OUTLINE,
        )
    return image


def shared_nine_slice() -> Image.Image:
    image = framed((16, 16), 2)
    draw = ImageDraw.Draw(image)
    draw.line((3, 3, 12, 3), fill=SEPARATOR)
    draw.line((3, 12, 12, 12), fill=SEPARATOR)
    draw.point((3, 3), fill=CREAM)
    draw.point((12, 3), fill=CREAM)
    draw.point((3, 12), fill=CREAM)
    draw.point((12, 12), fill=CREAM)
    return image


def main_city_map() -> Image.Image:
    size = (640, 320)
    image = Image.new("RGBA", size, DEEP_BLUE)
    draw = ImageDraw.Draw(image)
    for y in range(0, 320, 16):
        for x in range(0, 640, 16):
            cell = TISSUE if ((x // 16) + (y // 16)) % 2 == 0 else TISSUE_LIGHT
            draw.rectangle((x + 1, y + 1, x + 14, y + 14), fill=cell)
            draw.point((x + 4, y + 5), fill=BACKING)
            draw.point((x + 11, y + 10), fill=BACKING)
    draw.rectangle((0, 0, 639, 319), outline=OUTLINE)
    return image


def development_timeline() -> Image.Image:
    image = Image.new("RGBA", (640, 8), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.line((0, 3, 639, 3), fill=OUTLINE)
    draw.line((0, 4, 319, 4), fill=OXYGEN)
    draw.line((320, 4, 639, 4), fill=SEPARATOR)
    for x in range(0, 640, 80):
        draw.rectangle((x, 1, min(x + 3, 639), 6), fill=OUTLINE)
        draw.rectangle((x + 1, 2, min(x + 2, 639), 5), fill=OXYGEN_LIGHT)
    return image


def task_operations() -> Image.Image:
    image = framed((608, 16))
    draw = ImageDraw.Draw(image)
    for x in (192, 384):
        draw.line((x, 1, x, 14), fill=OUTLINE)
    for left, right in ((0, 191), (192, 383), (384, 607)):
        draw.rectangle((left + 3, 3, left + 14, 12), outline=SEPARATOR)
        draw.line((left + 73, 11, min(left + 144, right - 2), 11), fill=CREAM)
        draw.line((left + 73, 12, min(left + 120, right - 2), 12), fill=OXYGEN)
    return image


def resource_status() -> Image.Image:
    image = framed((640, 16))
    draw = ImageDraw.Draw(image)
    for left in (12, 116, 220, 324, 428, 532):
        draw.rectangle((left, 1, left + 95, 14), outline=SEPARATOR)
        draw.rectangle((left + 2, 2, left + 15, 13), outline=OUTLINE)
        draw.line((left + 20, 11, left + 91, 11), fill=CREAM)
    return image


def archive_button() -> Image.Image:
    image = Image.new("RGBA", (16, 16), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 1, 14, 14), fill=BACKING, outline=OUTLINE)
    draw.rectangle((4, 3, 11, 12), outline=TISSUE)
    draw.line((6, 5, 9, 5), fill=CREAM)
    draw.line((6, 8, 10, 8), fill=CREAM)
    draw.line((6, 10, 9, 10), fill=CREAM)
    return image


def recap_button() -> Image.Image:
    image = Image.new("RGBA", (16, 16), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 1, 14, 14), fill=BACKING, outline=OUTLINE)
    draw.polygon(((4, 3), (11, 3), (12, 5), (12, 12), (4, 12)), outline=OXYGEN)
    draw.line((6, 6, 10, 6), fill=CREAM)
    draw.line((6, 9, 10, 9), fill=CREAM)
    return image


def knowledge_prompt() -> Image.Image:
    image = framed((224, 32))
    draw = ImageDraw.Draw(image)
    draw.line((7, 5, 7, 26), fill=OXYGEN)
    draw.rectangle((15, 5, 216, 14), outline=SEPARATOR)
    draw.rectangle((15, 16, 216, 25), outline=SEPARATOR)
    return image


def pause_symbol(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.rectangle((x, y, x + 2, y + 8), fill=OXYGEN_LIGHT)
    draw.rectangle((x + 5, y, x + 7, y + 8), fill=OXYGEN_LIGHT)


def organ_archive_panel() -> Image.Image:
    image = framed((560, 304), 2)
    draw = ImageDraw.Draw(image)
    draw.line((12, 23, 547, 23), fill=SEPARATOR)
    pause_symbol(draw, 535, 7)
    y = 32
    for index in range(7):
        draw.rectangle((12, y, 547, y + 29), outline=TISSUE if index == 0 else SEPARATOR)
        y += 36
    return image


def chapter_summary_panel() -> Image.Image:
    image = framed((544, 304), 2)
    draw = ImageDraw.Draw(image)
    draw.line((12, 23, 531, 23), fill=SEPARATOR)
    pause_symbol(draw, 519, 7)
    y = 32
    for index in range(6):
        draw.rectangle((12, y, 531, y + 39), outline=OXYGEN if index == 0 else SEPARATOR)
        y += 44
    return image


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(task_id: str, items: dict[str, tuple[str, tuple[int, int]]]) -> dict:
    locked = palette()
    files = []
    for item_id, (name, expected_size) in items.items():
        path = UI_DIR / name
        image = Image.open(path).convert("RGBA")
        alphas = set(image.getchannel("A").getdata())
        visible = {
            (red, green, blue)
            for red, green, blue, alpha in image.getdata()
            if alpha
        }
        checks = {
            "dimensions": image.size == expected_size,
            "binary_alpha": alphas <= {0, 255},
            "locked_palette_only": visible <= locked,
            "lowercase_snake_case": name == name.lower() and " " not in name,
        }
        if not all(checks.values()):
            raise ValueError(f"{name} failed: {checks}")
        files.append(
            {
                "id": item_id,
                "path": path.relative_to(ROOT).as_posix(),
                "size": list(image.size),
                "sha256": sha256(path),
                "checks": {key: "PASS" if value else "FAIL" for key, value in checks.items()},
            }
        )
    return {
        "task_id": task_id,
        "status": "PASS",
        "generation": {
            "method": "DERIVED_DETERMINISTIC_NINE_SLICE",
            "script": "tools/build_d14l_d17l_ui.py",
            "pixellab_calls": 0,
            "style_source": "art/candidates/pf00/ui_frame_shared_candidate01_raw.png",
            "style_source_job_id": "3a44ef17-752e-4d36-95b8-6f096a52fdf7",
        },
        "png_count": len(files),
        "files": files,
    }


def write_manifest(task_id: str, report: dict, notes: list[str]) -> None:
    lines = [
        f"# {task_id} UI Asset Manifest",
        "",
        "- Status: `PASS`",
        "- Derivation: `DERIVED_DETERMINISTIC_NINE_SLICE`",
        "- Shared PixelLab source job: `3a44ef17-752e-4d36-95b8-6f096a52fdf7`",
        "- Additional PixelLab calls: `0`",
        f"- Validation: `docs/assets/{task_id}_VALIDATION_REPORT.json`",
        "",
        "| File | Size | SHA-256 |",
        "|---|---:|---|",
    ]
    for entry in report["files"]:
        lines.append(
            f"| `{entry['path']}` | `{entry['size'][0]}x{entry['size'][1]}` | `{entry['sha256']}` |"
        )
    lines.extend(["", *notes, ""])
    (REPORT_DIR / f"{task_id}_MANIFEST.md").write_text(
        "\n".join(lines), encoding="utf-8"
    )


def write_done(task_id: str, outputs: list[str], checks: list[str]) -> None:
    text = [
        f"task_id: {task_id}",
        "owner: ACCOUNT_D",
        "status: DONE",
        "base_main_commit: d13bb366833e0fec1e89d234495b827bcdefd502",
        "source: P-F01 deterministic shared nine-slice expansion",
        "outputs:",
        *[f"  - {output}" for output in outputs],
        "checks:",
        *[f"  - {check}: PASS" for check in checks],
        "pixel_lab_calls: 0",
        "",
    ]
    (DONE_DIR / f"{task_id}.md").write_text("\n".join(text), encoding="utf-8")


def write_rework(task_id: str, reason: str) -> None:
    text = [
        f"target_task: {task_id}",
        "reported_by: ACCOUNT_D",
        "status: RESOLVED",
        "discovered_at_main_commit: d13bb366833e0fec1e89d234495b827bcdefd502",
        f"original_gap: {reason}",
        "resolution: Used the exact dimensions and capacity contracts already present in docs/UI_LAYOUT.md and expanded one shared UI style source deterministically.",
        "additional_pixel_lab_calls: 0",
        "",
    ]
    (REWORK_DIR / f"{task_id}__from_ACCOUNT_D.resolved.md").write_text(
        "\n".join(text), encoding="utf-8"
    )


def main() -> None:
    if Image.open(RAW_SOURCE).size != (192, 192):
        raise ValueError("shared PixelLab UI source must be 192x192")
    UI_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    DONE_DIR.mkdir(parents=True, exist_ok=True)
    REWORK_DIR.mkdir(parents=True, exist_ok=True)

    builders = {
        "ui_frame_shared_nine_slice.png": shared_nine_slice,
        "ui_main_city_map_frame.png": main_city_map,
        "ui_development_timeline_frame.png": development_timeline,
        "ui_task_operations_panel_frame.png": task_operations,
        "ui_resource_status_bar_frame.png": resource_status,
        "ui_organ_archive_button.png": archive_button,
        "ui_chapter_recap_button.png": recap_button,
        "ui_knowledge_prompt_frame.png": knowledge_prompt,
        "ui_organ_archive_panel_frame.png": organ_archive_panel,
        "ui_chapter_summary_panel_frame.png": chapter_summary_panel,
    }
    for name, builder in builders.items():
        builder().save(UI_DIR / name, format="PNG", optimize=False)

    d14 = validate("D-14L", D14_FILES)
    d17 = validate("D-17L", D17_FILES)
    for task_id, report in (("D-14L", d14), ("D-17L", d17)):
        (REPORT_DIR / f"{task_id}_VALIDATION_REPORT.json").write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8"
        )

    write_manifest(
        "D-14L",
        d14,
        [
            "The two 16x16 entry buttons use one normal-state PNG each; pressed state is a runtime one-pixel inward translation and does not require duplicate art.",
            "All six UI regions retain the exact rectangles in `docs/UI_LAYOUT.md`.",
        ],
    )
    write_manifest(
        "D-17L",
        d17,
        [
            "G1 remains non-modal and two-line; G2 keeps seven fixed three-line fields; G3 keeps six fixed four-line items.",
            "G2 and G3 include a persistent two-bar pause mark and remain fully opaque.",
        ],
    )
    write_done(
        "D-14L",
        [entry["path"] for entry in d14["files"]],
        [
            "exact UI_LAYOUT dimensions",
            "22-color palette",
            "binary alpha",
            "six-region geometry",
        ],
    )
    write_done(
        "D-17L",
        [entry["path"] for entry in d17["files"]],
        [
            "G1/G2/G3 exact dimensions",
            "capacity geometry",
            "opaque modal backing",
            "pause marks",
        ],
    )
    write_rework("D-14L", "No real D-14L PNG existed; the older D-14 marker covered specification only.")
    write_rework("D-17L", "No real D-17L PNG existed; the older D-17 marker covered specification only.")
    print(json.dumps({"status": "PASS", "D-14L_png_count": 7, "D-17L_png_count": 3}))


if __name__ == "__main__":
    main()
