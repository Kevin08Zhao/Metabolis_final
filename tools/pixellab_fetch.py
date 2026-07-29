#!/usr/bin/env python3
"""Deterministically land PixelLab PNG results from a committed fetch plan.

The script deliberately does not call PixelLab. A generation task records the
real MCP response in a fetch plan, and this script retrieves and validates that
response without spending generation units.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import io
import json
import math
import re
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

try:
    from PIL import Image, UnidentifiedImageError
except ImportError as exc:  # pragma: no cover - exercised by dependency failure
    raise SystemExit(
        "Pillow is required. Install it with: python -m pip install 'Pillow>=10,<13'"
    ) from exc


SCRIPT_ID = "tools/pixellab_fetch.py"
REPORT_VERSION = 1
MAX_SOURCE_BYTES = 25 * 1024 * 1024
STATIC_PNG_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+){2,}\.png$")
D06_STYLE_MASTER_TARGET = "art/reference/style_master.png"
D29_TITLE_BACKGROUND_TARGET = "art/backgrounds/background_title.png"
TASK_ID_RE = re.compile(r"^[A-Z]-[0-9]{2}[A-Za-z]?$")
MANIFEST_MARKER = "<!-- generated-by: tools/pixellab_fetch.py -->"


class LandError(RuntimeError):
    """A validation or landing failure that is safe to report to the user."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(data: Any) -> bytes:
    return json.dumps(
        data, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LandError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise LandError(f"{path} must contain a JSON object")
    return value


def safe_repo_path(repo_root: Path, value: str, *, suffix: str | None = None) -> Path:
    if not isinstance(value, str) or not value:
        raise LandError("path must be a non-empty repository-relative string")
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise LandError(f"unsafe repository path: {value}")
    target = (repo_root / relative).resolve(strict=False)
    root = repo_root.resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise LandError(f"path escapes repository root: {value}") from exc
    if suffix is not None and target.suffix.lower() != suffix.lower():
        raise LandError(f"{value} must end in {suffix}")
    return target


def relative_posix(repo_root: Path, path: Path) -> str:
    return path.resolve(strict=False).relative_to(repo_root.resolve()).as_posix()


def require_directory(relative_path: str, directory: str) -> None:
    if not relative_path.startswith(f"{directory}/"):
        raise LandError(f"{relative_path} must be inside {directory}/")


def valid_static_png_name(relative_path: str, file_name: str) -> bool:
    return bool(STATIC_PNG_RE.fullmatch(file_name)) or (
        relative_path in (D06_STYLE_MASTER_TARGET, D29_TITLE_BACKGROUND_TARGET)
    )


def parse_gpl(path: Path) -> list[tuple[int, int, int]]:
    colors: list[tuple[int, int, int]] = []
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        match = re.match(r"^\s*(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})(?:\s|$)", line)
        if not match:
            continue
        color = tuple(int(group) for group in match.groups())
        if any(channel > 255 for channel in color):
            raise LandError(f"invalid GPL channel at {path}:{line_number}")
        colors.append(color)  # type: ignore[arg-type]
    if len(colors) != 22:
        raise LandError(f"locked palette must contain exactly 22 colors; found {len(colors)}")
    if len(set(colors)) != 22:
        raise LandError("locked palette contains duplicate colors")
    return colors


def flattened_pixels(image: Image.Image) -> Any:
    return (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )


def srgb_channel_to_linear(channel: int) -> float:
    value = channel / 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def rgb_to_lab(color: tuple[int, int, int]) -> tuple[float, float, float]:
    red, green, blue = (srgb_channel_to_linear(channel) for channel in color)
    x = (red * 0.4124564 + green * 0.3575761 + blue * 0.1804375) / 0.95047
    y = (red * 0.2126729 + green * 0.7151522 + blue * 0.0721750)
    z = (red * 0.0193339 + green * 0.1191920 + blue * 0.9503041) / 1.08883

    def pivot(value: float) -> float:
        delta = 6 / 29
        return value ** (1 / 3) if value > delta**3 else value / (3 * delta**2) + 4 / 29

    fx, fy, fz = pivot(x), pivot(y), pivot(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def nearest_palette_color(
    rgb: tuple[int, int, int],
    palette: list[tuple[int, int, int]],
    palette_lab: list[tuple[float, float, float]],
) -> tuple[tuple[int, int, int], float]:
    source = rgb_to_lab(rgb)
    distances = [
        math.sqrt(sum((left - right) ** 2 for left, right in zip(source, target)))
        for target in palette_lab
    ]
    index = min(range(len(distances)), key=distances.__getitem__)
    return palette[index], distances[index]


def quantize_and_binarize(
    image: Image.Image,
    palette: list[tuple[int, int, int]],
    *,
    alpha_threshold: int,
    distance_threshold: float,
) -> tuple[Image.Image, dict[str, Any]]:
    if not 0 <= alpha_threshold <= 255:
        raise LandError("alpha_threshold must be between 0 and 255")
    if distance_threshold < 0:
        raise LandError("palette_distance_threshold must be non-negative")

    rgba = image.convert("RGBA")
    palette_set = set(palette)
    palette_lab = [rgb_to_lab(color) for color in palette]
    cache: dict[tuple[int, int, int], tuple[tuple[int, int, int], float]] = {}
    output: list[tuple[int, int, int, int]] = []
    visible_before = 0
    out_of_palette_before = 0
    over_threshold = 0
    partially_transparent_before = 0

    for red, green, blue, alpha in flattened_pixels(rgba):
        rgb = (red, green, blue)
        if alpha not in (0, 255):
            partially_transparent_before += 1
        if alpha > 0:
            visible_before += 1
            if rgb not in palette_set:
                out_of_palette_before += 1
            if rgb not in cache:
                cache[rgb] = nearest_palette_color(rgb, palette, palette_lab)
            mapped, distance = cache[rgb]
            if distance > distance_threshold:
                over_threshold += 1
        else:
            mapped = palette[0]

        if alpha >= alpha_threshold:
            if rgb not in cache:
                cache[rgb] = nearest_palette_color(rgb, palette, palette_lab)
            mapped = cache[rgb][0]
            output.append((*mapped, 255))
        else:
            output.append((0, 0, 0, 0))

    result = Image.new("RGBA", rgba.size)
    result.putdata(output)
    visible_after = sum(1 for pixel in output if pixel[3] == 255)
    transparent_after = len(output) - visible_after
    output_colors = {pixel[:3] for pixel in output if pixel[3] == 255}
    out_of_palette_after = len(
        [pixel for pixel in output if pixel[3] == 255 and pixel[:3] not in palette_set]
    )
    percent = 0.0 if visible_before == 0 else over_threshold * 100.0 / visible_before
    metrics = {
        "locked_palette_color_count": len(palette),
        "visible_pixels_before": visible_before,
        "visible_pixels_after": visible_after,
        "out_of_palette_pixels_before": out_of_palette_before,
        "out_of_palette_pixels_after": out_of_palette_after,
        "visible_output_color_count": len(output_colors),
        "palette_distance_metric": "CIE76 Delta E",
        "palette_distance_threshold": distance_threshold,
        "over_threshold_pixels": over_threshold,
        "over_threshold_percent": round(percent, 6),
        "alpha_threshold": alpha_threshold,
        "partially_transparent_pixels_before": partially_transparent_before,
        "partially_transparent_pixels_after": 0,
        "opaque_pixels_after": visible_after,
        "transparent_pixels_after": transparent_after,
    }
    return result, metrics


def tiled_paste(
    output: Image.Image,
    tile: Image.Image,
    box: tuple[int, int, int, int],
) -> None:
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    if width == 0 or height == 0:
        return
    if tile.width == 0 or tile.height == 0:
        raise LandError("nine_slice source region is empty")
    for y in range(top, bottom, tile.height):
        for x in range(left, right, tile.width):
            piece = tile.crop((0, 0, min(tile.width, right - x), min(tile.height, bottom - y)))
            output.paste(piece, (x, y), piece)


def nine_slice_tile(
    image: Image.Image,
    *,
    width: int,
    height: int,
    left: int,
    right: int,
    top: int,
    bottom: int,
) -> Image.Image:
    values = (width, height, left, right, top, bottom)
    if any(not isinstance(value, int) for value in values):
        raise LandError("nine_slice dimensions and borders must be integers")
    if min(values) < 0:
        raise LandError("nine_slice dimensions and borders must be non-negative")
    if width == 0 or height == 0:
        raise LandError("nine_slice target dimensions must be positive")
    if left + right > image.width or top + bottom > image.height:
        raise LandError("nine_slice borders exceed source dimensions")
    if width < left + right or height < top + bottom:
        raise LandError("nine_slice target is smaller than fixed borders")

    source_x = (0, left, image.width - right, image.width)
    source_y = (0, top, image.height - bottom, image.height)
    target_x = (0, left, width - right, width)
    target_y = (0, top, height - bottom, height)
    output = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for row in range(3):
        for column in range(3):
            source = image.crop(
                (
                    source_x[column],
                    source_y[row],
                    source_x[column + 1],
                    source_y[row + 1],
                )
            )
            tiled_paste(
                output,
                source,
                (
                    target_x[column],
                    target_y[row],
                    target_x[column + 1],
                    target_y[row + 1],
                ),
            )
    return output


def apply_operations(image: Image.Image, operations: Any) -> tuple[Image.Image, list[dict[str, Any]]]:
    if operations is None:
        return image, []
    if not isinstance(operations, list):
        raise LandError("operations must be an array")
    applied: list[dict[str, Any]] = []
    result = image
    for index, operation in enumerate(operations):
        if not isinstance(operation, dict):
            raise LandError(f"operation {index} must be an object")
        kind = operation.get("kind")
        if kind == "integer_scale":
            factor = operation.get("factor")
            if not isinstance(factor, int) or factor < 1:
                raise LandError("integer_scale.factor must be a positive integer")
            result = result.resize(
                (result.width * factor, result.height * factor),
                resample=Image.Resampling.NEAREST,
            )
            applied.append({"kind": kind, "factor": factor})
        elif kind == "crop":
            values = [operation.get(name) for name in ("x", "y", "width", "height")]
            if any(not isinstance(value, int) for value in values):
                raise LandError("crop x, y, width, and height must be integers")
            x, y, width, height = values
            if x < 0 or y < 0 or width <= 0 or height <= 0:
                raise LandError("crop coordinates must be non-negative and size positive")
            if x + width > result.width or y + height > result.height:
                raise LandError("crop rectangle exceeds image bounds")
            result = result.crop((x, y, x + width, y + height))
            applied.append(
                {"kind": kind, "x": x, "y": y, "width": width, "height": height}
            )
        elif kind == "nine_slice":
            borders = operation.get("borders")
            if not isinstance(borders, dict):
                raise LandError("nine_slice.borders must be an object")
            width, height = operation.get("width"), operation.get("height")
            result = nine_slice_tile(
                result,
                width=width,
                height=height,
                left=borders.get("left"),
                right=borders.get("right"),
                top=borders.get("top"),
                bottom=borders.get("bottom"),
            )
            applied.append(
                {
                    "kind": kind,
                    "mode": "tile",
                    "width": width,
                    "height": height,
                    "borders": {
                        name: borders.get(name) for name in ("left", "right", "top", "bottom")
                    },
                }
            )
        else:
            raise LandError(
                f"operation {index} uses forbidden or unknown kind {kind!r}; "
                "allowed: integer_scale, crop, nine_slice"
            )
    return result, applied


def sanitized_source(source: Any) -> dict[str, Any]:
    if not isinstance(source, dict):
        return {"kind": "invalid"}
    kind = source.get("kind")
    if kind == "url":
        value = source.get("url")
        if isinstance(value, str):
            parsed = urllib.parse.urlsplit(value)
            clean = urllib.parse.urlunsplit(
                (parsed.scheme, parsed.netloc, parsed.path, "", "")
            )
            return {"kind": kind, "url": clean}
    if kind == "base64":
        value = source.get("data", source.get("base64"))
        if isinstance(value, str):
            payload = value.split(",", 1)[-1] if value.startswith("data:") else value
            return {
                "kind": kind,
                "encoded_characters": len(payload),
                "encoded_sha256": sha256_bytes(payload.encode("ascii", errors="ignore")),
            }
    return {"kind": kind}


def fetch_source(source: Any, *, timeout: float) -> tuple[bytes, dict[str, Any]]:
    if not isinstance(source, dict):
        raise LandError("source must be an object")
    kind = source.get("kind")
    if kind == "base64":
        encoded = source.get("data", source.get("base64"))
        if not isinstance(encoded, str) or not encoded:
            raise LandError("base64 source requires non-empty data or base64")
        if encoded.startswith("data:"):
            header, separator, encoded = encoded.partition(",")
            if not separator or ";base64" not in header:
                raise LandError("only base64 data URLs are accepted")
        try:
            payload = base64.b64decode(encoded, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise LandError(f"invalid base64 source: {exc}") from exc
        final_url = None
    elif kind == "url":
        url = source.get("url")
        if not isinstance(url, str) or not url:
            raise LandError("url source requires a non-empty url")
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or not parsed.netloc:
            raise LandError("source URL must be an absolute HTTPS URL")
        request = urllib.request.Request(
            url, headers={"User-Agent": "Metabolis-PixelLab-Lander/1"}
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                final_url = response.geturl()
                if urllib.parse.urlsplit(final_url).scheme != "https":
                    raise LandError("source redirected away from HTTPS")
                payload = response.read(MAX_SOURCE_BYTES + 1)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise LandError(f"download failed: {exc}") from exc
    else:
        raise LandError("source.kind must be url or base64")

    if not payload:
        raise LandError("source returned zero bytes")
    if len(payload) > MAX_SOURCE_BYTES:
        raise LandError(f"source exceeds {MAX_SOURCE_BYTES} byte limit")
    return payload, {
        "status": "downloaded",
        "bytes": len(payload),
        "sha256": sha256_bytes(payload),
        "final_url": urllib.parse.urlunsplit(
            (*urllib.parse.urlsplit(final_url)[:3], "", "")
        )
        if final_url
        else None,
    }


def encode_png(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=False, compress_level=9)
    return output.getvalue()


def safe_write_png(
    target: Path,
    payload: bytes,
    *,
    expected_existing_sha256: str | None,
) -> str:
    if target.exists():
        existing = target.read_bytes()
        existing_hash = sha256_bytes(existing)
        incoming_hash = sha256_bytes(payload)
        if existing_hash == incoming_hash:
            return "unchanged_identical"
        if not expected_existing_sha256 or existing_hash != expected_existing_sha256:
            raise LandError(
                f"refusing to overwrite unknown existing file {target}; "
                "provide matching expected_existing_sha256"
            )
        disposition = "replaced_known_hash"
    else:
        disposition = "created"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.tmp")
    temporary.write_bytes(payload)
    temporary.replace(target)
    return disposition


def safe_write_managed_json(target: Path, data: dict[str, Any]) -> str:
    if target.exists():
        try:
            existing = json.loads(target.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise LandError(f"refusing to overwrite unknown report {target}") from exc
        if existing.get("generated_by") != SCRIPT_ID:
            raise LandError(f"refusing to overwrite unknown report {target}")
        disposition = "updated_managed"
    else:
        disposition = "created"
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    target.write_text(payload, encoding="utf-8")
    return disposition


def safe_write_managed_manifest(target: Path, text: str) -> str:
    if target.exists() and not target.read_text(encoding="utf-8").startswith(MANIFEST_MARKER):
        raise LandError(f"refusing to overwrite unknown manifest {target}")
    disposition = "updated_managed" if target.exists() else "created"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")
    return disposition


def expected_dimensions(item: dict[str, Any]) -> tuple[int, int] | None:
    expected = item.get("expected_size")
    if expected is None:
        return None
    if not isinstance(expected, dict):
        raise LandError("expected_size must be an object")
    width, height = expected.get("width"), expected.get("height")
    if not isinstance(width, int) or not isinstance(height, int) or min(width, height) <= 0:
        raise LandError("expected_size width and height must be positive integers")
    return width, height


def normalized_generation(item: dict[str, Any]) -> dict[str, Any]:
    generation = item.get("generation", {})
    if not isinstance(generation, dict):
        raise LandError("generation must be an object")
    allowed = {
        "tool",
        "job_id",
        "asset_id",
        "seed",
        "usage",
        "cost",
        "create_response",
        "status_response",
    }
    return {key: generation[key] for key in allowed if key in generation}


def process_item(
    item: Any,
    *,
    repo_root: Path,
    palette: list[tuple[int, int, int]],
    default_distance_threshold: float,
    default_max_over_threshold_percent: float,
    timeout: float,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "status": "FAIL",
        "source": sanitized_source(item.get("source") if isinstance(item, dict) else None),
        "download": {"status": "not_attempted"},
        "dimensions": {"status": "not_checked"},
        "transparency": {"status": "not_checked"},
        "palette": {
            "status": "not_checked",
            "locked_palette_color_count": len(palette),
        },
        "naming": {"status": "not_checked"},
    }
    try:
        if not isinstance(item, dict):
            raise LandError("item must be an object")
        item_id = item.get("id")
        if not isinstance(item_id, str) or not item_id:
            raise LandError("item.id must be a non-empty string")
        result["id"] = item_id
        target_value = item.get("target")
        target = safe_repo_path(repo_root, target_value, suffix=".png")
        target_relative = relative_posix(repo_root, target)
        require_directory(target_relative, "art")
        result["target"] = target_relative
        name_ok = valid_static_png_name(target_relative, target.name)
        result["naming"] = {
            "status": "PASS" if name_ok else "FAIL",
            "file_name": target.name,
            "rule": (
                "{category}_{subject}_{variant}.png in lowercase snake_case; "
                "D-06 additionally permits the exact v3.1 path "
                "art/reference/style_master.png"
            ),
        }
        if not name_ok:
            raise LandError(f"target file name violates CONTEXT.md: {target.name}")

        result["generation"] = normalized_generation(item)
        payload, download = fetch_source(item.get("source"), timeout=timeout)
        result["download"] = download
        try:
            with Image.open(io.BytesIO(payload)) as source_image:
                source_image.load()
                decoded = source_image.convert("RGBA")
        except (UnidentifiedImageError, OSError) as exc:
            raise LandError(f"downloaded source is not a readable image: {exc}") from exc

        source_size = {"width": decoded.width, "height": decoded.height}
        distance_threshold = float(
            item.get("palette_distance_threshold", default_distance_threshold)
        )
        max_over = float(
            item.get(
                "max_over_threshold_percent", default_max_over_threshold_percent
            )
        )
        quantized, metrics = quantize_and_binarize(
            decoded,
            palette,
            alpha_threshold=int(item.get("alpha_threshold", 128)),
            distance_threshold=distance_threshold,
        )
        transformed, operations = apply_operations(quantized, item.get("operations"))
        transformed_pixels = list(flattened_pixels(transformed))
        output_visible = [pixel for pixel in transformed_pixels if pixel[3] == 255]
        metrics["visible_pixels_after"] = len(output_visible)
        metrics["transparent_pixels_after"] = len(transformed_pixels) - len(output_visible)
        metrics["opaque_pixels_after"] = len(output_visible)
        metrics["partially_transparent_pixels_after"] = sum(
            pixel[3] not in (0, 255) for pixel in transformed_pixels
        )
        metrics["visible_output_color_count"] = len(
            {pixel[:3] for pixel in output_visible}
        )
        metrics["out_of_palette_pixels_after"] = sum(
            pixel[:3] not in set(palette) for pixel in output_visible
        )
        expected = expected_dimensions(item)
        size_ok = expected is None or transformed.size == expected
        result["dimensions"] = {
            "status": "PASS" if size_ok else "FAIL",
            "source": source_size,
            "output": {"width": transformed.width, "height": transformed.height},
            "expected": {"width": expected[0], "height": expected[1]}
            if expected
            else None,
            "operations": operations,
        }
        result["transparency"] = {
            "status": "PASS"
            if metrics["partially_transparent_pixels_after"] == 0
            else "FAIL",
            "alpha_threshold": metrics["alpha_threshold"],
            "partially_transparent_pixels_before": metrics[
                "partially_transparent_pixels_before"
            ],
            "partially_transparent_pixels_after": metrics[
                "partially_transparent_pixels_after"
            ],
            "opaque_pixels_after": metrics["opaque_pixels_after"],
            "transparent_pixels_after": metrics["transparent_pixels_after"],
        }
        threshold_ok = metrics["over_threshold_percent"] <= max_over
        palette_ok = (
            metrics["locked_palette_color_count"] == 22
            and metrics["out_of_palette_pixels_after"] == 0
            and threshold_ok
        )
        result["palette"] = {
            "status": "PASS" if palette_ok else "FAIL",
            **{
                key: value
                for key, value in metrics.items()
                if key
                not in {
                    "alpha_threshold",
                    "partially_transparent_pixels_before",
                    "partially_transparent_pixels_after",
                    "opaque_pixels_after",
                    "transparent_pixels_after",
                }
            },
            "max_over_threshold_percent": max_over,
        }
        if not size_ok:
            raise LandError(
                f"output is {transformed.width}x{transformed.height}, expected "
                f"{expected[0]}x{expected[1]}"
            )
        if not palette_ok:
            raise LandError(
                "palette validation failed: "
                f"{metrics['over_threshold_percent']}% exceeds {max_over}%"
            )
        png = encode_png(transformed)
        disposition = safe_write_png(
            target,
            png,
            expected_existing_sha256=item.get("expected_existing_sha256"),
        )
        result["output"] = {
            "status": disposition,
            "bytes": len(png),
            "sha256": sha256_bytes(png),
        }
        result["status"] = "PASS"
    except (LandError, OSError, ValueError, TypeError) as exc:
        if str(exc).startswith("download failed:"):
            result["download"] = {"status": "FAIL", "error": str(exc)}
        result["error"] = {"type": type(exc).__name__, "message": str(exc)}
    return result


def manifest_usage(generation: Any) -> str:
    if not isinstance(generation, dict):
        return "UNREPORTED"
    usage = generation.get("usage")
    if isinstance(usage, dict):
        for key in ("generation_units", "generations", "actual_generation_units"):
            if key in usage:
                return str(usage[key])
    for key in ("cost", "actual_generation_units"):
        if key in generation:
            return str(generation[key])
    return "UNREPORTED"


def render_manifest(
    task_id: str,
    plan_path: str,
    plan_sha256: str,
    report_path: str,
    items: list[dict[str, Any]],
) -> str:
    lines = [
        MANIFEST_MARKER,
        f"# {task_id} PixelLab landing manifest",
        "",
        f"- Fetch plan: `{plan_path}`",
        f"- Fetch plan SHA-256: `{plan_sha256}`",
        f"- Landing report: `{report_path}`",
        "- Palette: `art/palette.gpl` (22 locked colors)",
        "",
        "| Item | Target | Status | Tool | Real ID | Actual usage | Source | Output SHA-256 |",
        "|---|---|---|---|---|---:|---|---|",
    ]
    for item in items:
        generation = item.get("generation", {})
        tool = generation.get("tool", "UNREPORTED") if isinstance(generation, dict) else "UNREPORTED"
        real_id = (
            generation.get("job_id", generation.get("asset_id", "UNREPORTED"))
            if isinstance(generation, dict)
            else "UNREPORTED"
        )
        source = item.get("source", {})
        source_text = source.get("url", source.get("kind", "UNREPORTED"))
        output_sha = item.get("output", {}).get("sha256", "—")
        lines.append(
            f"| `{item.get('id', 'UNREPORTED')}` | `{item.get('target', '—')}` | "
            f"{item.get('status', 'FAIL')} | `{tool}` | `{real_id}` | "
            f"{manifest_usage(generation)} | `{source_text}` | `{output_sha}` |"
        )
    lines.extend(
        [
            "",
            "The committed fetch plan is the source of truth for full raw create/status "
            "responses and any base64 payload. This manifest never fabricates missing fields.",
            "",
        ]
    )
    return "\n".join(lines)


def append_paths_file(path: Path | None, values: Iterable[str]) -> None:
    if path is None:
        return
    existing = set()
    if path.exists():
        existing.update(line.strip() for line in path.read_text(encoding="utf-8").splitlines())
    existing.update(value for value in values if value)
    path.write_text("\n".join(sorted(existing)) + "\n", encoding="utf-8")


def land_plan(
    plan_path: Path,
    *,
    repo_root: Path,
    paths_file: Path | None,
    timeout: float,
) -> tuple[bool, dict[str, Any]]:
    plan = read_json(plan_path)
    plan_relative = relative_posix(repo_root, plan_path)
    require_directory(plan_relative, "fetch_plans")
    if plan_path.suffix.lower() != ".json":
        raise LandError("fetch plan must be a JSON file")
    task_id = plan.get("task_id")
    if not isinstance(task_id, str) or not TASK_ID_RE.fullmatch(task_id):
        raise LandError("task_id must look like D-06, D-05a, or D-14L")
    items = plan.get("items")
    if not isinstance(items, list) or not items:
        raise LandError("fetch plan must contain at least one item")

    palette_value = plan.get("palette", "art/palette.gpl")
    if palette_value != "art/palette.gpl":
        raise LandError("fetch plan must use the locked art/palette.gpl")
    palette_path = safe_repo_path(repo_root, palette_value, suffix=".gpl")
    palette = parse_gpl(palette_path)
    plan_sha = sha256_bytes(plan_path.read_bytes())
    default_threshold = float(plan.get("palette_distance_threshold", 12.0))
    default_max_over = float(plan.get("max_over_threshold_percent", 100.0))
    item_results = [
        process_item(
            item,
            repo_root=repo_root,
            palette=palette,
            default_distance_threshold=default_threshold,
            default_max_over_threshold_percent=default_max_over,
            timeout=timeout,
        )
        for item in items
    ]
    success_count = sum(item["status"] == "PASS" for item in item_results)
    failure_count = len(item_results) - success_count
    report_target = safe_repo_path(
        repo_root,
        plan.get("report", f"docs/assets/{task_id}_LAND_REPORT.json"),
        suffix=".json",
    )
    manifest_target = safe_repo_path(
        repo_root,
        plan.get("manifest", f"docs/assets/{task_id}_MANIFEST.md"),
        suffix=".md",
    )
    require_directory(relative_posix(repo_root, report_target), "docs/assets")
    require_directory(relative_posix(repo_root, manifest_target), "docs/assets")
    report = {
        "generated_by": SCRIPT_ID,
        "report_version": REPORT_VERSION,
        "generated_at": utc_now(),
        "task_id": task_id,
        "status": "PASS" if failure_count == 0 else "FAIL",
        "plan": {
            "path": plan_relative,
            "sha256": plan_sha,
        },
        "palette": {
            "path": relative_posix(repo_root, palette_path),
            "color_count": len(palette),
            "status": "PASS" if len(palette) == 22 else "FAIL",
        },
        "summary": {
            "item_count": len(item_results),
            "success_count": success_count,
            "failure_count": failure_count,
        },
        "items": item_results,
    }
    safe_write_managed_json(report_target, report)
    manifest = render_manifest(
        task_id,
        plan_relative,
        plan_sha,
        relative_posix(repo_root, report_target),
        item_results,
    )
    safe_write_managed_manifest(manifest_target, manifest)
    successful_targets = [
        item["target"] for item in item_results if item["status"] == "PASS"
    ]
    append_paths_file(
        paths_file,
        [
            *successful_targets,
            relative_posix(repo_root, report_target),
            relative_posix(repo_root, manifest_target),
        ],
    )
    return failure_count == 0, report


def create_palette_strip(
    palette_path: Path,
    output_path: Path,
    *,
    block_size: int,
) -> dict[str, Any]:
    if block_size < 1 or not isinstance(block_size, int):
        raise LandError("block_size must be a positive integer")
    colors = parse_gpl(palette_path)
    image = Image.new("RGBA", (len(colors) * block_size, block_size), (0, 0, 0, 0))
    for index, color in enumerate(colors):
        tile = Image.new("RGBA", (block_size, block_size), (*color, 255))
        image.paste(tile, (index * block_size, 0))
    payload = encode_png(image)
    disposition = safe_write_png(
        output_path, payload, expected_existing_sha256=None
    )
    return {
        "status": disposition,
        "color_count": len(colors),
        "block_size": block_size,
        "width": image.width,
        "height": image.height,
        "sha256": sha256_bytes(payload),
    }


def build_self_test_source() -> str:
    image = Image.new("RGBA", (3, 2))
    image.putdata(
        [
            (186, 58, 63, 255),
            (121, 208, 252, 200),
            (2, 3, 4, 0),
            (225, 148, 57, 64),
            (177, 255, 209, 255),
            (81, 72, 84, 255),
        ]
    )
    return base64.b64encode(encode_png(image)).decode("ascii")


def run_self_test(
    repo_root: Path,
    *,
    evidence_target: Path,
    workflow_path: Path,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="metabolis_d05a_") as temp_name:
        temp_root = Path(temp_name)
        (temp_root / "art").mkdir(parents=True)
        shutil.copyfile(repo_root / "art/palette.gpl", temp_root / "art/palette.gpl")
        plan_path = temp_root / "fetch_plans/D-05a_self_test.json"
        plan_path.parent.mkdir(parents=True)
        plan = {
            "task_id": "D-05a",
            "palette": "art/palette.gpl",
            "report": "docs/assets/D-05a_SELF_TEST_LAND_REPORT.json",
            "manifest": "docs/assets/D-05a_SELF_TEST_MANIFEST.md",
            "palette_distance_threshold": 12.0,
            "max_over_threshold_percent": 0.0,
            "items": [
                {
                    "id": "valid_base64_small_image",
                    "target": "art/reference/reference_pipeline_valid.png",
                    "source": {"kind": "base64", "data": build_self_test_source()},
                    "generation": {
                        "tool": "synthetic_self_test_fixture",
                        "job_id": "NOT_APPLICABLE",
                        "usage": {"generation_units": 0},
                    },
                    "expected_size": {"width": 6, "height": 4},
                    "operations": [{"kind": "integer_scale", "factor": 2}],
                    "alpha_threshold": 128,
                },
                {
                    "id": "deliberate_failed_url",
                    "target": "art/reference/reference_pipeline_failed.png",
                    "source": {
                        "kind": "url",
                        "url": "https://127.0.0.1:9/intentionally-unreachable.png",
                    },
                    "generation": {
                        "tool": "synthetic_self_test_fixture",
                        "job_id": "NOT_APPLICABLE",
                        "usage": {"generation_units": 0},
                    },
                    "expected_size": {"width": 1, "height": 1},
                },
            ],
        }
        plan_path.write_text(
            json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        paths_file = temp_root / ".pixellab_land_paths"
        land_ok, report = land_plan(
            plan_path,
            repo_root=temp_root,
            paths_file=paths_file,
            timeout=1.0,
        )
        valid, failed = report["items"]
        valid_output = temp_root / valid["target"]
        done_marker = temp_root / "docs/coord/done/D-05a.md"
        workflow_text = workflow_path.read_text(encoding="utf-8")
        operation_fixture = Image.new("RGBA", (3, 3))
        operation_palette = parse_gpl(temp_root / "art/palette.gpl")
        operation_fixture.putdata(
            [(*operation_palette[index], 255) for index in range(9)]
        )
        nine_sliced, _ = apply_operations(
            operation_fixture,
            [
                {
                    "kind": "nine_slice",
                    "width": 7,
                    "height": 5,
                    "borders": {"left": 1, "right": 1, "top": 1, "bottom": 1},
                },
                {"kind": "crop", "x": 1, "y": 1, "width": 5, "height": 3},
            ],
        )
        unknown_target = temp_root / "art/reference/reference_unknown_existing.png"
        unknown_target.parent.mkdir(parents=True, exist_ok=True)
        unknown_target.write_bytes(b"unknown-existing-file")
        overwrite_was_rejected = False
        try:
            safe_write_png(
                unknown_target,
                encode_png(Image.new("RGBA", (1, 1), (*operation_palette[0], 255))),
                expected_existing_sha256=None,
            )
        except LandError:
            overwrite_was_rejected = True
        strip_path = repo_root / "art/reference/palette_strip.png"
        with Image.open(strip_path) as strip_image:
            strip_rgba = strip_image.convert("RGBA")
            strip_colors = {
                pixel[:3] for pixel in flattened_pixels(strip_rgba) if pixel[3] == 255
            }
        workflow_checks = {
            "permissions_only_contents_write": (
                "permissions:\n  contents: write" in workflow_text
                and "pull-requests:" not in workflow_text
                and "actions:" not in workflow_text
            ),
            "failed_land_step_is_deferred": "continue-on-error: true" in workflow_text,
            "final_failure_step_exists": "exit 1" in workflow_text
            and "steps.land.outputs.status" in workflow_text,
            "done_paths_rejected": "docs/coord/done/" in workflow_text,
        }
        checks = {
            "mixed_plan_returns_failure": not land_ok and report["status"] == "FAIL",
            "successful_item_still_landed": valid["status"] == "PASS" and valid_output.exists(),
            "failed_item_reported": failed["status"] == "FAIL"
            and failed["download"]["status"] == "FAIL"
            and "download failed" in failed["error"]["message"],
            "no_done_marker_created": not done_marker.exists(),
            "palette_has_exactly_22_colors": report["palette"]["color_count"] == 22,
            "output_has_binary_alpha": valid["transparency"][
                "partially_transparent_pixels_after"
            ]
            == 0,
            "output_has_no_visible_out_of_palette_pixels": valid["palette"][
                "out_of_palette_pixels_after"
            ]
            == 0,
            "crop_and_nine_slice_are_pixel_exact": nine_sliced.size == (5, 3)
            and all(pixel[3] in (0, 255) for pixel in flattened_pixels(nine_sliced)),
            "unknown_existing_file_is_not_overwritten": overwrite_was_rejected
            and unknown_target.read_bytes() == b"unknown-existing-file",
            "palette_strip_has_22_ordered_blocks": strip_rgba.size == (352, 16)
            and len(strip_colors) == 22
            and all(
                strip_rgba.getpixel((index * 16, 0))[:3] == color
                for index, color in enumerate(operation_palette)
            ),
            "d06_v3_1_style_master_exact_path_is_allowed": valid_static_png_name(
                "art/reference/style_master.png", "style_master.png"
            )
            and not valid_static_png_name(
                "art/reference/other_master.png", "other_master.png"
            ),
            "workflow_will_end_red_after_commit": all(workflow_checks.values()),
        }
        if not all(checks.values()):
            failed_checks = [name for name, passed in checks.items() if not passed]
            raise LandError(f"self-test failed: {', '.join(failed_checks)}")
        evidence = {
            "generated_by": SCRIPT_ID,
            "report_version": REPORT_VERSION,
            "generated_at": utc_now(),
            "task_id": "D-05a",
            "status": "PASS",
            "generation_units_used": 0,
            "palette_color_count": report["palette"]["color_count"],
            "scenario": {
                "items": 2,
                "valid_small_image_source": "base64",
                "deliberate_failure_source": failed["source"]["url"],
                "land_command_expected_exit_code": 1,
                "workflow_expected_conclusion": "failure (red)",
            },
            "checks": checks,
            "workflow_static_checks": workflow_checks,
            "valid_item_report": valid,
            "failed_item_report": failed,
        }
    safe_write_managed_json(evidence_target, evidence)
    return evidence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    land = subparsers.add_parser("land", help="retrieve and land one fetch plan")
    land.add_argument("plan", type=Path)
    land.add_argument("--repo-root", type=Path, default=Path.cwd())
    land.add_argument("--paths-file", type=Path)
    land.add_argument("--timeout", type=float, default=30.0)

    strip = subparsers.add_parser("palette-strip", help="create the 22-block palette strip")
    strip.add_argument("--palette", type=Path, default=Path("art/palette.gpl"))
    strip.add_argument("--output", type=Path, default=Path("art/reference/palette_strip.png"))
    strip.add_argument("--block-size", type=int, default=16)

    self_test = subparsers.add_parser(
        "self-test", help="run the required success-plus-failure mixed test"
    )
    self_test.add_argument("--repo-root", type=Path, default=Path.cwd())
    self_test.add_argument(
        "--evidence",
        type=Path,
        default=Path("docs/assets/D-05a_SELF_TEST_REPORT.json"),
    )
    self_test.add_argument(
        "--workflow",
        type=Path,
        default=Path(".github/workflows/pixellab_land.yml"),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "land":
            root = args.repo_root.resolve()
            plan = args.plan if args.plan.is_absolute() else root / args.plan
            paths = args.paths_file
            if paths is not None and not paths.is_absolute():
                paths = root / paths
            ok, report = land_plan(
                plan.resolve(),
                repo_root=root,
                paths_file=paths,
                timeout=args.timeout,
            )
            print(json.dumps(report["summary"], sort_keys=True))
            return 0 if ok else 1
        if args.command == "palette-strip":
            result = create_palette_strip(
                args.palette.resolve(),
                args.output.resolve(),
                block_size=args.block_size,
            )
            print(json.dumps(result, sort_keys=True))
            return 0
        if args.command == "self-test":
            root = args.repo_root.resolve()
            evidence = args.evidence if args.evidence.is_absolute() else root / args.evidence
            workflow = args.workflow if args.workflow.is_absolute() else root / args.workflow
            result = run_self_test(
                root,
                evidence_target=evidence.resolve(),
                workflow_path=workflow.resolve(),
            )
            print(json.dumps({"status": result["status"], "checks": result["checks"]}))
            return 0
        raise LandError(f"unsupported command {args.command}")
    except (LandError, OSError, ValueError, TypeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
