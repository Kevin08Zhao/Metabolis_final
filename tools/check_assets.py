#!/usr/bin/env python3
"""Read-only compliance checks for Metabolis art, animation, and audio assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

from PIL import Image


HEX_COLOR = re.compile(r"#[0-9A-Fa-f]{6}")
ASSET_NAME = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*\.[a-z0-9]+$")
EXACT_IMAGE_SIZES = {
    "art/backgrounds/background_title.png": (320, 180),
    "art/reference/palette_strip.png": (352, 16),
    "art/reference/style_master.png": (320, 180),
    "art/reference/style_master_preview_2x.png": (640, 360),
    "art/ui/ui_chapter_recap_button.png": (16, 16),
    "art/ui/ui_chapter_summary_panel_frame.png": (544, 304),
    "art/ui/ui_development_timeline_frame.png": (640, 8),
    "art/ui/ui_frame_shared_nine_slice.png": (16, 16),
    "art/ui/ui_knowledge_prompt_frame.png": (224, 32),
    "art/ui/ui_main_city_map_frame.png": (640, 320),
    "art/ui/ui_organ_archive_button.png": (16, 16),
    "art/ui/ui_organ_archive_panel_frame.png": (560, 304),
    "art/ui/ui_resource_status_bar_frame.png": (640, 16),
    "art/ui/ui_task_operations_panel_frame.png": (608, 16),
}


def load_palette(path: Path) -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for match in HEX_COLOR.finditer(path.read_text(encoding="utf-8")):
        value = match.group()[1:]
        colors.add(tuple(int(value[index : index + 2], 16) for index in (0, 2, 4)))
    return colors


def expected_image_size(relative: str) -> tuple[int, int] | None:
    if relative in EXACT_IMAGE_SIZES:
        return EXACT_IMAGE_SIZES[relative]
    if relative.startswith("art/tiles/"):
        return (16, 16)
    if relative.startswith("art/organs/"):
        return (48, 48)
    if relative.startswith("art/icons/ui_task_rating_"):
        return (32, 16)
    if relative.startswith("art/icons/"):
        return (16, 16)
    if relative.startswith("art/construction/construction_zone_landmark_"):
        return (80, 80)
    if relative.startswith("art/construction/construction_zone_standard_"):
        return (64, 64)
    return None


def audit(repo_root: Path) -> dict[str, Any]:
    palette = load_palette(repo_root / "art" / "palette.gpl")
    issues: dict[str, list[dict[str, str]]] = {
        "error": [],
        "warning": [],
        "info": [],
    }
    provenance_roots = (repo_root / "fetch_plans", repo_root / "docs" / "assets")
    provenance_files = [
        path
        for base in provenance_roots
        if base.exists()
        for path in base.rglob("*")
        if path.is_file() and path.suffix.lower() in {".json", ".md"}
    ]
    provenance_text = {
        path: path.read_text(encoding="utf-8", errors="replace")
        for path in provenance_files
    }
    provenance_enabled = any(base.exists() for base in provenance_roots)
    hashes: dict[str, list[str]] = {}
    scanned = 0
    for top_level in ("art", "anim"):
        directory = repo_root / top_level
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.png")):
            scanned += 1
            relative = path.relative_to(repo_root).as_posix()
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            hashes.setdefault(digest, []).append(relative)
            if provenance_enabled and not any(
                relative in content for content in provenance_text.values()
            ):
                issues["error"].append(
                    {
                        "code": "asset_provenance_missing",
                        "path": relative,
                        "message": "No fetch plan, manifest, or asset ledger references this file.",
                    }
                )
            if not ASSET_NAME.fullmatch(path.name):
                issues["error"].append(
                    {
                        "code": "invalid_asset_name",
                        "path": relative,
                        "message": "File name must use lowercase snake_case.",
                    }
                )
            with Image.open(path) as image:
                if "A" not in image.getbands() and "transparency" not in image.info:
                    issues["error"].append(
                        {
                            "code": "png_missing_alpha_channel",
                            "path": relative,
                            "message": "PNG must retain an explicit alpha channel.",
                        }
                    )
                rgba = image.convert("RGBA")
                alpha_values = {pixel[3] for pixel in rgba.get_flattened_data()}
                outside = sorted(
                    {
                        pixel[:3]
                        for pixel in rgba.get_flattened_data()
                        if pixel[3] and pixel[:3] not in palette
                    }
                )
                image_size = image.size
            source_only = relative.startswith(
                ("art/candidates/", "art/source/", "art/reference/candidates/")
            )
            if not source_only and not alpha_values.issubset({0, 255}):
                issues["error"].append(
                    {
                        "code": "png_partial_alpha",
                        "path": relative,
                        "message": "Production PNG alpha must be fully transparent or fully opaque.",
                    }
                )
            expected_size = expected_image_size(relative)
            if expected_size is not None and image_size != expected_size:
                issues["error"].append(
                    {
                        "code": "asset_dimension_mismatch",
                        "path": relative,
                        "message": (
                            f"Expected {expected_size[0]}x{expected_size[1]}, "
                            f"found {image_size[0]}x{image_size[1]}."
                        ),
                    }
                )
            if top_level == "anim":
                metadata_path = path.with_suffix(".json")
                if not metadata_path.is_file():
                    issues["error"].append(
                        {
                            "code": "animation_metadata_missing",
                            "path": relative,
                            "message": f"Missing paired metadata file {metadata_path.name}.",
                        }
                    )
                else:
                    try:
                        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
                        frame_size = metadata["frame_size"]
                        expected_size = (
                            int(frame_size["width"]) * int(metadata["frame_count"]),
                            int(frame_size["height"]),
                        )
                        if image_size != expected_size:
                            issues["error"].append(
                                {
                                    "code": "animation_sheet_size_mismatch",
                                    "path": relative,
                                    "message": (
                                        f"Expected {expected_size[0]}x{expected_size[1]} "
                                        f"from metadata, found {image_size[0]}x{image_size[1]}."
                                    ),
                                }
                            )
                    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
                        issues["error"].append(
                            {
                                "code": "animation_metadata_invalid",
                                "path": metadata_path.relative_to(repo_root).as_posix(),
                                "message": str(error),
                            }
                        )
            if outside:
                severity = "warning" if source_only else "error"
                issues[severity].append(
                    {
                        "code": (
                            "source_png_color_outside_palette"
                            if source_only
                            else "png_color_outside_palette"
                        ),
                        "path": relative,
                        "message": (
                            f"{len(outside)} opaque RGB values are outside the locked palette; "
                            + (
                                "this source-only file must be quantized before production use."
                                if source_only
                                else "production assets use exact matching with tolerance 0."
                            )
                        ),
                    }
                )
    event_api = repo_root / "docs" / "EVENT_API.md"
    event_names = (
        set(re.findall(r"\bsfx_[a-z0-9_]+\b", event_api.read_text(encoding="utf-8")))
        if event_api.is_file()
        else set()
    )
    audio_root = repo_root / "audio"
    if audio_root.exists():
        for path in sorted(audio_root.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in {".wav", ".ogg", ".mp3"}:
                continue
            scanned += 1
            relative = path.relative_to(repo_root).as_posix()
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            hashes.setdefault(digest, []).append(relative)
            if not ASSET_NAME.fullmatch(path.name):
                issues["error"].append(
                    {
                        "code": "invalid_asset_name",
                        "path": relative,
                        "message": "File name must use lowercase snake_case.",
                    }
                )
            if event_names and path.stem not in event_names:
                issues["error"].append(
                    {
                        "code": "audio_event_unknown",
                        "path": relative,
                        "message": "Audio file stem does not match an EVENT_API sound event.",
                    }
                )
            if provenance_enabled and not any(
                relative in content for content in provenance_text.values()
            ):
                issues["error"].append(
                    {
                        "code": "asset_provenance_missing",
                        "path": relative,
                        "message": "No fetch plan, manifest, or asset ledger references this file.",
                    }
                )
    for paths in sorted(hashes.values()):
        if len(paths) > 1:
            issues["warning"].append(
                {
                    "code": "duplicate_asset_content",
                    "path": paths[0],
                    "message": f"Byte-identical assets: {', '.join(paths)}",
                }
            )
    return {
        "status": "FAIL" if issues["error"] else "PASS",
        "summary": {"files_scanned": scanned, "errors": len(issues["error"])},
        "issues": issues,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--format", choices=("text", "json"), default="text")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = audit(args.repo_root.resolve())
    if args.format == "json":
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(report["status"])
        for severity in ("error", "warning", "info"):
            for issue in report["issues"][severity]:
                print(f"{severity.upper()}: {issue['path']}: {issue['message']}")
    return 1 if report["issues"]["error"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
