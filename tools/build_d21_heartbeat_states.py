#!/usr/bin/env python3
"""Build and validate the D-21 stability-driven heartbeat state variants."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image


SOURCE_SHEET = Path("anim/heart_pump_active.png")
PALETTE = Path("art/palette.gpl")
REPORT = Path("docs/assets/D-21_VALIDATION_REPORT.json")
BALANCE = Path("docs/BALANCE.json")
FRAME_SIZE = (48, 48)
FRAME_COUNT = 4

STATE_CONFIG: dict[str, dict[str, Any]] = {
    "stable": {
        "durations": [420, 120, 100, 360],
        "fallback": 0,
        "source_indices": [0, 1, 2, 3],
    },
    "strained": {
        "durations": [140, 60, 80, 160],
        "fallback": 2,
        "source_indices": [0, 1, 2, 3],
    },
    "critical": {
        "durations": [680, 200, 220, 700],
        "fallback": 1,
        "source_indices": [0, 1, 1, 0],
    },
}


def flattened(image: Image.Image) -> list[tuple[int, int, int, int]]:
    pixels = (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )
    return list(pixels)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_palette(path: Path) -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*(\d+)\s+(\d+)\s+(\d+)(?:\s|$)", line)
        if match:
            colors.add(tuple(int(value) for value in match.groups()))
    if len(colors) != 22:
        raise ValueError(f"expected 22 locked palette colors, found {len(colors)}")
    return colors


def split_frames(sheet: Image.Image) -> list[Image.Image]:
    expected_size = (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1])
    if sheet.size != expected_size:
        raise ValueError(
            f"{SOURCE_SHEET} must be {expected_size[0]}x{expected_size[1]}"
        )
    return [
        sheet.crop(
            (
                index * FRAME_SIZE[0],
                0,
                (index + 1) * FRAME_SIZE[0],
                FRAME_SIZE[1],
            )
        )
        for index in range(FRAME_COUNT)
    ]


def metadata_for(state: str) -> dict[str, Any]:
    config = STATE_CONFIG[state]
    return {
        "frame_size": {"width": FRAME_SIZE[0], "height": FRAME_SIZE[1]},
        "frame_count": FRAME_COUNT,
        "frame_durations_ms": config["durations"],
        "loop": True,
        "trigger_event": "stability_band_changed",
        "fallback_frame_index": config["fallback"],
        "palette_checked": True,
    }


def build(repo_root: Path) -> dict[str, Any]:
    source_path = repo_root / SOURCE_SHEET
    palette = load_palette(repo_root / PALETTE)
    source_sheet = Image.open(source_path).convert("RGBA")
    source_frames = split_frames(source_sheet)
    balance = json.loads((repo_root / BALANCE).read_text(encoding="utf-8"))
    stability_thresholds = balance["operations"]["thresholds"]["stability"]
    expected_thresholds = {
        "stable_enter": 75.0,
        "stable_exit": 65.0,
        "strained_recover": 70.0,
        "critical_enter": 30.0,
        "critical_recover": 40.0,
        "hysteresis": 5.0,
    }

    outputs: dict[str, dict[str, Any]] = {}
    fallback_pixels: list[tuple[tuple[int, int, int, int], ...]] = []
    for state, config in STATE_CONFIG.items():
        stem = f"heart_pump_{state}"
        png_relative = Path("anim") / f"{stem}.png"
        json_relative = Path("anim") / f"{stem}.json"
        png_path = repo_root / png_relative
        json_path = repo_root / json_relative

        if state in ("stable", "strained"):
            shutil.copyfile(source_path, png_path)
        else:
            sheet = Image.new(
                "RGBA", (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1])
            )
            for output_index, source_index in enumerate(config["source_indices"]):
                sheet.paste(source_frames[source_index], (output_index * FRAME_SIZE[0], 0))
            sheet.save(png_path, format="PNG", optimize=False)

        metadata = metadata_for(state)
        json_path.write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        landed_sheet = Image.open(png_path).convert("RGBA")
        landed_frames = split_frames(landed_sheet)
        fallback_pixels.append(
            tuple(flattened(landed_frames[config["fallback"]]))
        )
        visible_out_of_palette = sum(
            pixel[3] == 255 and pixel[:3] not in palette
            for pixel in flattened(landed_sheet)
        )
        partial_alpha = sum(
            pixel[3] not in (0, 255) for pixel in flattened(landed_sheet)
        )
        outputs[state] = {
            "png": png_relative.as_posix(),
            "json": json_relative.as_posix(),
            "source_frame_indices": config["source_indices"],
            "frame_durations_ms": config["durations"],
            "total_loop_ms": sum(config["durations"]),
            "fallback_frame_index": config["fallback"],
            "png_sha256": sha256(png_path),
            "json_sha256": sha256(json_path),
            "out_of_palette_pixels": visible_out_of_palette,
            "partially_transparent_pixels": partial_alpha,
        }

    stable_pixels = flattened(
        Image.open(repo_root / "anim/heart_pump_stable.png").convert("RGBA")
    )
    strained_pixels = flattened(
        Image.open(repo_root / "anim/heart_pump_strained.png").convert("RGBA")
    )
    source_pixels = flattened(source_sheet)
    critical_frames = split_frames(
        Image.open(repo_root / "anim/heart_pump_critical.png").convert("RGBA")
    )
    checks = {
        "stable_sheet_reuses_d20_exactly": stable_pixels == source_pixels,
        "strained_sheet_reuses_d20_exactly": strained_pixels == source_pixels,
        "critical_uses_only_relaxed_and_shallow_contraction": (
            flattened(critical_frames[0]) == flattened(source_frames[0])
            and flattened(critical_frames[1]) == flattened(source_frames[1])
            and flattened(critical_frames[2]) == flattened(source_frames[1])
            and flattened(critical_frames[3]) == flattened(source_frames[0])
        ),
        "fallback_poses_are_pairwise_distinct": len(set(fallback_pixels)) == 3,
        "stable_is_slower_than_strained": (
            outputs["stable"]["total_loop_ms"]
            > outputs["strained"]["total_loop_ms"]
        ),
        "critical_is_slowest": (
            outputs["critical"]["total_loop_ms"]
            > outputs["stable"]["total_loop_ms"]
        ),
        "strained_timing_is_non_uniform": (
            len(set(STATE_CONFIG["strained"]["durations"])) == FRAME_COUNT
        ),
        "all_outputs_use_locked_palette": all(
            output["out_of_palette_pixels"] == 0 for output in outputs.values()
        ),
        "all_outputs_use_binary_alpha": all(
            output["partially_transparent_pixels"] == 0
            for output in outputs.values()
        ),
        "table_e4_thresholds_match_balance": (
            stability_thresholds == expected_thresholds
        ),
        "no_pixellab_generation_required": True,
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise ValueError(f"D-21 validation failed: {', '.join(failed)}")

    report: dict[str, Any] = {
        "task_id": "D-21",
        "status": "PASS",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "generated_by": "tools/build_d21_heartbeat_states.py",
        "source": {
            "path": SOURCE_SHEET.as_posix(),
            "sha256": sha256(source_path),
        },
        "stability_thresholds": stability_thresholds,
        "reuse_decision": {
            "stable_and_strained": (
                "Share the complete D-20 sheet; timing alone distinguishes them."
            ),
            "critical": (
                "Reuse only the D-20 relaxed and shallow-contraction poses so the "
                "amplitude is smaller without generating or scaling any image."
            ),
        },
        "outputs": outputs,
        "checks": checks,
    }
    report_path = repo_root / REPORT
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    report = build(args.repo_root.resolve())
    print(
        json.dumps(
            {
                "status": report["status"],
                "states": sorted(report["outputs"]),
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
