#!/usr/bin/env python3
"""Read-only validator for Metabolis animation sprite-sheet metadata pairs."""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "frame_size",
    "frame_count",
    "frame_durations_ms",
    "loop",
    "trigger_event",
    "fallback_frame_index",
    "palette_checked",
}
ANIMATION_STEM = re.compile(r"^[a-z0-9]+_[a-z0-9]+_[a-z0-9]+$")
EVENT_SIGNAL = re.compile(r"^signal ([a-z][a-z0-9_]*)\(", re.MULTILINE)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


@dataclass(frozen=True)
class Issue:
    severity: str
    code: str
    file: str
    message: str

    def as_dict(self) -> dict[str, str]:
        return {
            "severity": self.severity,
            "code": self.code,
            "file": self.file,
            "message": self.message,
        }


def load_event_names(event_api: Path) -> set[str]:
    text = event_api.read_text(encoding="utf-8")
    names = set(EVENT_SIGNAL.findall(text))
    if not names:
        raise ValueError(f"no signal declarations found in {event_api}")
    return names


def parse_png_header(payload: bytes) -> tuple[int, int, bool]:
    if len(payload) < 33 or payload[:8] != PNG_SIGNATURE:
        raise ValueError("not a valid PNG signature/header")
    length = struct.unpack(">I", payload[8:12])[0]
    if payload[12:16] != b"IHDR" or length != 13:
        raise ValueError("PNG does not begin with a canonical IHDR chunk")
    width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", payload[16:29]
    )
    if width < 1 or height < 1:
        raise ValueError("PNG dimensions must be positive")
    if bit_depth != 8 or compression != 0 or filtering != 0 or interlace not in (0, 1):
        raise ValueError("unsupported PNG header parameters")
    return width, height, color_type in (4, 6)


def _is_positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_metadata(
    metadata: Any,
    file_label: str,
    event_names: set[str],
    png_info: tuple[int, int, bool] | None,
) -> list[Issue]:
    issues: list[Issue] = []
    if not isinstance(metadata, dict):
        return [Issue("ERROR", "META_NOT_OBJECT", file_label, "top-level JSON value must be an object")]

    keys = set(metadata)
    for field in sorted(REQUIRED_FIELDS - keys):
        issues.append(Issue("ERROR", "MISSING_FIELD", file_label, f"required field is missing: {field}"))
    for field in sorted(keys - REQUIRED_FIELDS):
        issues.append(Issue("ERROR", "UNKNOWN_FIELD", file_label, f"field is outside the D-18 contract: {field}"))
    if REQUIRED_FIELDS - keys:
        return issues

    frame_size = metadata["frame_size"]
    if (
        not isinstance(frame_size, dict)
        or set(frame_size) != {"width", "height"}
        or not _is_positive_int(frame_size.get("width"))
        or not _is_positive_int(frame_size.get("height"))
    ):
        issues.append(
            Issue(
                "ERROR",
                "INVALID_FRAME_SIZE",
                file_label,
                "frame_size must contain only positive integer width and height",
            )
        )

    frame_count = metadata["frame_count"]
    if not _is_positive_int(frame_count):
        issues.append(Issue("ERROR", "INVALID_FRAME_COUNT", file_label, "frame_count must be a positive integer"))

    durations = metadata["frame_durations_ms"]
    if not isinstance(durations, list) or not all(_is_positive_int(value) for value in durations):
        issues.append(
            Issue(
                "ERROR",
                "INVALID_DURATIONS",
                file_label,
                "frame_durations_ms must be an array of positive integer milliseconds",
            )
        )
    elif _is_positive_int(frame_count) and len(durations) != frame_count:
        issues.append(
            Issue(
                "ERROR",
                "DURATION_COUNT_MISMATCH",
                file_label,
                f"duration count {len(durations)} does not equal frame_count {frame_count}",
            )
        )

    if not isinstance(metadata["loop"], bool):
        issues.append(Issue("ERROR", "INVALID_LOOP", file_label, "loop must be a JSON boolean"))

    event_name = metadata["trigger_event"]
    if not isinstance(event_name, str) or event_name not in event_names:
        issues.append(
            Issue(
                "ERROR",
                "UNKNOWN_TRIGGER_EVENT",
                file_label,
                f"trigger_event must match a signal in docs/EVENT_API.md: {event_name!r}",
            )
        )

    fallback = metadata["fallback_frame_index"]
    if (
        not isinstance(fallback, int)
        or isinstance(fallback, bool)
        or fallback < 0
        or (_is_positive_int(frame_count) and fallback >= frame_count)
    ):
        issues.append(
            Issue(
                "ERROR",
                "INVALID_FALLBACK_INDEX",
                file_label,
                "fallback_frame_index must be a zero-based index inside the sheet",
            )
        )

    if metadata["palette_checked"] is not True:
        issues.append(
            Issue(
                "ERROR",
                "PALETTE_NOT_CHECKED",
                file_label,
                "palette_checked must be true before an animation can pass",
            )
        )

    if png_info is not None and isinstance(frame_size, dict) and _is_positive_int(frame_count):
        png_width, png_height, has_alpha = png_info
        fw = frame_size.get("width")
        fh = frame_size.get("height")
        if _is_positive_int(fw) and _is_positive_int(fh):
            expected_width = fw * frame_count
            if png_width != expected_width or png_height != fh:
                issues.append(
                    Issue(
                        "ERROR",
                        "SHEET_DIMENSION_MISMATCH",
                        file_label,
                        f"PNG is {png_width}x{png_height}; expected {expected_width}x{fh}",
                    )
                )
        if not has_alpha:
            issues.append(
                Issue(
                    "ERROR",
                    "PNG_MISSING_ALPHA",
                    file_label,
                    "PNG color type has no alpha channel; RGBA or grayscale+alpha is required",
                )
            )
    return issues


def validate_pair(metadata_path: Path, png_path: Path, root: Path, event_names: set[str]) -> list[Issue]:
    label = metadata_path.relative_to(root).as_posix()
    issues: list[Issue] = []
    if not ANIMATION_STEM.fullmatch(metadata_path.stem):
        issues.append(
            Issue(
                "ERROR",
                "INVALID_FILENAME",
                label,
                "stem must match {subject}_{action}_{state} in lowercase snake_case",
            )
        )
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return issues + [Issue("ERROR", "INVALID_JSON", label, str(exc))]

    png_info: tuple[int, int, bool] | None = None
    if not png_path.is_file():
        issues.append(Issue("ERROR", "MISSING_PNG", label, f"same-stem PNG is missing: {png_path.name}"))
    else:
        try:
            png_info = parse_png_header(png_path.read_bytes())
        except (OSError, ValueError) as exc:
            issues.append(Issue("ERROR", "INVALID_PNG", png_path.relative_to(root).as_posix(), str(exc)))
    issues.extend(validate_metadata(metadata, label, event_names, png_info))
    return issues


def scan(animation_dir: Path, event_api: Path) -> dict[str, Any]:
    animation_dir = animation_dir.resolve()
    root = animation_dir.parent.resolve()
    event_names = load_event_names(event_api.resolve())
    metadata_files = sorted(animation_dir.rglob("*.json")) if animation_dir.is_dir() else []
    png_files = sorted(animation_dir.rglob("*.png")) if animation_dir.is_dir() else []
    issues: list[Issue] = []

    metadata_stems = {path.with_suffix("").resolve() for path in metadata_files}
    for metadata_path in metadata_files:
        issues.extend(validate_pair(metadata_path, metadata_path.with_suffix(".png"), root, event_names))
    for png_path in png_files:
        if png_path.with_suffix("").resolve() not in metadata_stems:
            issues.append(
                Issue(
                    "ERROR",
                    "MISSING_METADATA",
                    png_path.relative_to(root).as_posix(),
                    f"same-stem JSON is missing: {png_path.with_suffix('.json').name}",
                )
            )

    grouped = {
        severity: [issue.as_dict() for issue in issues if issue.severity == severity]
        for severity in ("ERROR", "WARNING", "INFO")
    }
    return {
        "status": "FAIL" if grouped["ERROR"] else "PASS",
        "animation_dir": animation_dir.as_posix(),
        "event_api": event_api.resolve().as_posix(),
        "event_name_count": len(event_names),
        "metadata_count": len(metadata_files),
        "png_count": len(png_files),
        "pair_count": len(metadata_stems & {path.with_suffix("").resolve() for path in png_files}),
        "issues": grouped,
    }


def self_test(event_names: set[str]) -> dict[str, Any]:
    valid = {
        "frame_size": {"width": 48, "height": 48},
        "frame_count": 4,
        "frame_durations_ms": [120, 80, 200, 400],
        "loop": True,
        "trigger_event": "system_observation_started",
        "fallback_frame_index": 0,
        "palette_checked": True,
    }
    valid_png = (192, 48, True)
    cases: dict[str, list[Issue]] = {}
    cases["valid"] = validate_metadata(valid, "memory/heart_pump_active.json", event_names, valid_png)

    missing = dict(valid)
    del missing["loop"]
    cases["missing_field"] = validate_metadata(missing, "memory/missing_field.json", event_names, valid_png)

    wrong_count = dict(valid)
    wrong_count["frame_count"] = 3
    cases["wrong_frame_count"] = validate_metadata(
        wrong_count, "memory/wrong_frame_count.json", event_names, valid_png
    )

    wrong_event = dict(valid)
    wrong_event["trigger_event"] = "event_that_does_not_exist"
    cases["unknown_event"] = validate_metadata(wrong_event, "memory/unknown_event.json", event_names, valid_png)

    expected_codes = {
        "missing_field": "MISSING_FIELD",
        "wrong_frame_count": "SHEET_DIMENSION_MISMATCH",
        "unknown_event": "UNKNOWN_TRIGGER_EVENT",
    }
    checks = {
        "valid_example_passes": not cases["valid"],
        **{
            f"{name}_is_reported": any(issue.code == code for issue in cases[name])
            for name, code in expected_codes.items()
        },
    }
    return {
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "observed_codes": {
            name: sorted({issue.code for issue in issues})
            for name, issues in cases.items()
        },
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("animation_dir", nargs="?", default="anim", help="animation directory to scan")
    parser.add_argument("--event-api", default="docs/EVENT_API.md", help="EVENT_API markdown path")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--self-test", action="store_true", help="run read-only in-memory contract tests too")
    return parser.parse_args(argv)


def print_text(report: dict[str, Any]) -> None:
    print(
        f"{report['status']}: {report['pair_count']} pair(s), "
        f"{report['metadata_count']} JSON, {report['png_count']} PNG, "
        f"{report['event_name_count']} allowed event(s)"
    )
    for severity in ("ERROR", "WARNING", "INFO"):
        issues = report["issues"][severity]
        print(f"{severity} ({len(issues)})")
        for issue in issues:
            print(f"  [{issue['code']}] {issue['file']}: {issue['message']}")
    if "self_test" in report:
        print(f"SELF_TEST: {report['self_test']['status']}")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        report = scan(Path(args.animation_dir), Path(args.event_api))
        if args.self_test:
            report["self_test"] = self_test(load_event_names(Path(args.event_api)))
            if report["self_test"]["status"] != "PASS":
                report["status"] = "FAIL"
    except (OSError, ValueError) as exc:
        report = {
            "status": "BLOCKED",
            "issues": {
                "ERROR": [
                    Issue("ERROR", "VALIDATOR_BLOCKED", str(args.animation_dir), str(exc)).as_dict()
                ],
                "WARNING": [],
                "INFO": [],
            },
        }
    if args.format == "json":
        print(json.dumps(report, indent=2))
    else:
        print_text(report)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
