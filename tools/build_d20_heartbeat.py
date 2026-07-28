#!/usr/bin/env python3
"""Build and validate the D-20 heart-pump heartbeat sprite sheet."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


SOURCE = Path("art/organs/organ_heart_operating.png")
OUTPUT = Path("anim/heart_pump_active.png")
REPORT = Path("docs/assets/D-20_VALIDATION_REPORT.json")
PALETTE = Path("art/palette.gpl")
PULSE_BOX = (12, 21, 38, 37)
CANDIDATES = (
    Path("art/candidates/anim_heart_pulse_input.png"),
    Path("art/candidates/anim_heart_pulse_contraction.png"),
    Path("art/candidates/anim_heart_pulse_peak.png"),
    Path("art/candidates/anim_heart_pulse_contraction.png"),
)


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


def build(repo_root: Path) -> dict[str, object]:
    source_path = repo_root / SOURCE
    output_path = repo_root / OUTPUT
    report_path = repo_root / REPORT
    palette = load_palette(repo_root / PALETTE)

    source = Image.open(source_path).convert("RGBA")
    if source.size != (48, 48):
        raise ValueError(f"{SOURCE} must be 48x48, found {source.size}")
    source_crop = source.crop(PULSE_BOX)

    candidates = [
        Image.open(repo_root / relative).convert("RGBA") for relative in CANDIDATES
    ]
    if any(candidate.size != source_crop.size for candidate in candidates):
        raise ValueError("every D-20 candidate must match the 26x16 pulse region")
    if flattened(candidates[0]) != flattened(source_crop):
        raise ValueError("PixelLab input frame is not the exact D-11 pulse region")

    source_crop_pixels = source_crop.load()
    frames: list[Image.Image] = []
    changed_inside: list[int] = []
    for index, candidate in enumerate(candidates):
        frame = source.copy()
        candidate_pixels = candidate.load()
        if index > 0:
            for local_y in range(source_crop.height):
                for local_x in range(source_crop.width):
                    original = source_crop_pixels[local_x, local_y]
                    generated = candidate_pixels[local_x, local_y]
                    is_boundary = (
                        local_x in (0, source_crop.width - 1)
                        or local_y in (0, source_crop.height - 1)
                    )
                    if is_boundary or original[3] == 0 or generated[3] == 0:
                        landed = original
                    else:
                        landed = (generated[0], generated[1], generated[2], original[3])
                    frame.putpixel(
                        (PULSE_BOX[0] + local_x, PULSE_BOX[1] + local_y), landed
                    )
        frames.append(frame)
        changed_inside.append(
            sum(
                left != right
                for left, right in zip(
                    flattened(source_crop), flattened(frame.crop(PULSE_BOX))
                )
            )
        )

    distinct_poses = len({tuple(flattened(frame)) for frame in frames})
    if distinct_poses != 3 or any(value == 0 for value in changed_inside[1:]):
        raise ValueError("the heartbeat must contain relaxed, contraction, and peak poses")
    if changed_inside[2] != max(changed_inside):
        raise ValueError("the selected peak frame must have the greatest pulse deformation")

    sheet = Image.new("RGBA", (source.width * len(frames), source.height))
    for index, frame in enumerate(frames):
        sheet.paste(frame, (index * source.width, 0))

    output_pixels = flattened(sheet)
    out_of_palette = sum(
        pixel[3] == 255 and pixel[:3] not in palette for pixel in output_pixels
    )
    partial_alpha = sum(pixel[3] not in (0, 255) for pixel in output_pixels)

    source_pixels = flattened(source)
    outside_changes = 0
    boundary_changes = 0
    alpha_mask_changes = 0
    for frame in frames:
        pixels = flattened(frame)
        for y in range(source.height):
            for x in range(source.width):
                offset = y * source.width + x
                inside = (
                    PULSE_BOX[0] <= x < PULSE_BOX[2]
                    and PULSE_BOX[1] <= y < PULSE_BOX[3]
                )
                local_x = x - PULSE_BOX[0]
                local_y = y - PULSE_BOX[1]
                boundary = inside and (
                    local_x in (0, source_crop.width - 1)
                    or local_y in (0, source_crop.height - 1)
                )
                if not inside and pixels[offset] != source_pixels[offset]:
                    outside_changes += 1
                if boundary and pixels[offset] != source_pixels[offset]:
                    boundary_changes += 1
                if pixels[offset][3] != source_pixels[offset][3]:
                    alpha_mask_changes += 1

    checks = {
        "source_is_48x48": source.size == (48, 48),
        "frame_count_is_4": len(frames) == 4,
        "sheet_is_192x48": sheet.size == (192, 48),
        "input_frame_matches_d11": flattened(frames[0]) == source_pixels,
        "contains_three_distinct_poses": distinct_poses == 3,
        "relaxation_reverses_through_contraction_pose": (
            flattened(frames[1]) == flattened(frames[3])
        ),
        "peak_has_maximum_deformation": changed_inside[2] == max(changed_inside),
        "outside_pulse_region_is_static": outside_changes == 0,
        "pulse_boundary_is_static": boundary_changes == 0,
        "alpha_mask_is_preserved": alpha_mask_changes == 0,
        "uses_only_locked_palette": out_of_palette == 0,
        "uses_binary_alpha": partial_alpha == 0,
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise ValueError(f"D-20 validation failed: {', '.join(failed)}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=False)

    report: dict[str, object] = {
        "task_id": "D-20",
        "status": "PASS",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "generated_by": "tools/build_d20_heartbeat.py",
        "source": {
            "path": SOURCE.as_posix(),
            "sha256": sha256(source_path),
            "pulse_region_inclusive": {
                "x_min": 12,
                "y_min": 21,
                "x_max": 37,
                "y_max": 36,
            },
        },
        "selected_pixellab_response_indices": [0, 2, 3, 2],
        "frame_changed_pixels_inside_pulse_region": changed_inside,
        "frame_durations_ms": [320, 120, 80, 280],
        "checks": checks,
        "output": {
            "path": OUTPUT.as_posix(),
            "width": sheet.width,
            "height": sheet.height,
            "sha256": sha256(output_path),
        },
    }
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
    print(json.dumps({"status": report["status"], "output": report["output"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
