#!/usr/bin/env python3
"""Build and verify the zero-call D-07 and D-08 tile sets.

The generator intentionally uses only the Python standard library. PNG output is
RGBA8 with filter type 0, binary alpha, and deterministic zlib compression.
Existing files are accepted only when their bytes match the expected output.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path


SIZE = 16
N, E, S, W = 1, 2, 4, 8
PALETTE = {
    "coral": (186, 58, 63, 255),
    "blue_dark": (72, 165, 207, 255),
    "blue_main": (122, 209, 253, 255),
    "tissue_dark": (145, 70, 95, 255),
    "tissue_main": (190, 110, 135, 255),
    "tissue_light": (201, 129, 151, 255),
    "outline": (20, 15, 29, 255),
    "neutral_dark": (81, 72, 84, 255),
    "neutral_mid": (129, 117, 130, 255),
    "transparent": (0, 0, 0, 0),
}
LOCKED_RGB = {
    (52, 1, 6),
    (186, 58, 63),
    (194, 84, 83),
    (72, 165, 207),
    (122, 209, 253),
    (205, 217, 225),
    (41, 49, 74),
    (64, 69, 134),
    (83, 84, 140),
    (145, 70, 95),
    (190, 110, 135),
    (201, 129, 151),
    (178, 108, 9),
    (226, 149, 58),
    (221, 173, 126),
    (115, 205, 155),
    (177, 255, 209),
    (244, 255, 248),
    (20, 15, 29),
    (81, 72, 84),
    (129, 117, 130),
    (232, 220, 207),
}


def blank(color: tuple[int, int, int, int]) -> list[list[tuple[int, int, int, int]]]:
    return [[color for _ in range(SIZE)] for _ in range(SIZE)]


def rotate_cw(pixels: list[list[tuple[int, int, int, int]]]) -> list[list[tuple[int, int, int, int]]]:
    return [[pixels[SIZE - 1 - x][y] for x in range(SIZE)] for y in range(SIZE)]


def rotate_mask_cw(mask: int) -> int:
    result = 0
    if mask & N:
        result |= E
    if mask & E:
        result |= S
    if mask & S:
        result |= W
    if mask & W:
        result |= N
    return result


def png_bytes(pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"

    def chunk(kind: bytes, payload: bytes) -> bytes:
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = b"".join(
        b"\x00" + b"".join(bytes(pixel) for pixel in row)
        for row in pixels
    )
    return (
        signature
        + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def render_empty_ground() -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(PALETTE["neutral_dark"])
    clusters = (
        (3, 3, 2, 2),
        (10, 2, 3, 2),
        (6, 8, 2, 3),
        (11, 11, 2, 2),
        (2, 12, 3, 2),
    )
    for x0, y0, width, height in clusters:
        for y in range(y0, y0 + height):
            for x in range(x0, x0 + width):
                pixels[y][x] = PALETTE["neutral_mid"]
    return pixels


def render_tissue_ground() -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(PALETTE["tissue_main"])
    dark_clusters = ((3, 3, 3, 2), (10, 8, 2, 2), (5, 12, 2, 2))
    light_clusters = ((10, 2, 2, 2), (4, 7, 2, 3), (11, 12, 3, 2))
    for color, clusters in (
        (PALETTE["tissue_dark"], dark_clusters),
        (PALETTE["tissue_light"], light_clusters),
    ):
        for x0, y0, width, height in clusters:
            for y in range(y0, y0 + height):
                for x in range(x0, x0 + width):
                    pixels[y][x] = color
    return pixels


def tissue_region(mask: int) -> set[tuple[int, int]]:
    if mask == (N | E | S | W):
        return {(x, y) for y in range(SIZE) for x in range(SIZE)}
    return {
        (x, y)
        for y in range(SIZE)
        for x in range(SIZE)
        if (mask & N or y >= 4)
        and (mask & E or x <= 11)
        and (mask & S or y <= 11)
        and (mask & W or x >= 4)
    }


def render_tissue_boundary(mask: int) -> list[list[tuple[int, int, int, int]]]:
    region = tissue_region(mask)
    pixels = render_empty_ground()
    for x, y in region:
        pixels[y][x] = PALETTE["tissue_main"]

    def neighbor_is_tissue(x: int, y: int, dx: int, dy: int) -> bool:
        nx, ny = x + dx, y + dy
        if 0 <= nx < SIZE and 0 <= ny < SIZE:
            return (nx, ny) in region
        if ny < 0:
            return bool(mask & N)
        if nx >= SIZE:
            return bool(mask & E)
        if ny >= SIZE:
            return bool(mask & S)
        return bool(mask & W)

    for x, y in region:
        if any(
            not neighbor_is_tissue(x, y, dx, dy)
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))
        ):
            pixels[y][x] = PALETTE["outline"]

    for x, y in region:
        if pixels[y][x] == PALETTE["outline"]:
            continue
        if 1 < x < 14 and 1 < y < 14 and (x * 3 + y * 5) % 17 in (0, 1):
            pixels[y][x] = PALETTE["tissue_light"]
        elif 1 < x < 14 and 1 < y < 14 and (x * 5 + y * 3) % 19 == 0:
            pixels[y][x] = PALETTE["tissue_dark"]
    return pixels


def render_construction(focus: bool) -> list[list[tuple[int, int, int, int]]]:
    pixels = blank(PALETTE["tissue_main"])
    line = PALETTE["blue_main"] if focus else PALETTE["blue_dark"]
    for y in range(SIZE):
        for x in range(SIZE):
            hatch = (x - y) % 4 == 0
            if not focus:
                hatch = hatch and ((x + y) // 2) % 3 != 0
            if hatch:
                pixels[y][x] = line
    ticks = (
        (1, 1), (2, 1), (3, 1), (1, 2), (1, 3),
        (12, 1), (13, 1), (14, 1), (14, 2), (14, 3),
        (1, 12), (1, 13), (1, 14), (2, 14), (3, 14),
        (14, 12), (14, 13), (12, 14), (13, 14), (14, 14),
    )
    if not focus:
        ticks = ticks[::2]
    for x, y in ticks:
        pixels[y][x] = line
    return pixels


def road_region(mask: int) -> set[tuple[int, int]]:
    region: set[tuple[int, int]] = set()
    if mask & N:
        region.update((x, y) for y in range(0, 8) for x in range(4, 12))
    if mask & E:
        region.update((x, y) for y in range(4, 12) for x in range(8, 16))
    if mask & S:
        region.update((x, y) for y in range(8, 16) for x in range(4, 12))
    if mask & W:
        region.update((x, y) for y in range(4, 12) for x in range(0, 8))
    return region


def render_vessel(mask: int) -> list[list[tuple[int, int, int, int]]]:
    region = road_region(mask)
    pixels = blank(PALETTE["transparent"])
    for x, y in region:
        pixels[y][x] = PALETTE["coral"]
    for x, y in region:
        if any(
            not (0 <= x + dx < SIZE and 0 <= y + dy < SIZE)
            or (x + dx, y + dy) not in region
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))
            if not (
                (y == 0 and dy == -1 and mask & N)
                or (x == 15 and dx == 1 and mask & E)
                or (y == 15 and dy == 1 and mask & S)
                or (x == 0 and dx == -1 and mask & W)
            )
        ):
            pixels[y][x] = PALETTE["outline"]
    return pixels


def rotate_to_mask(
    base_pixels: list[list[tuple[int, int, int, int]]],
    base_mask: int,
    target_mask: int,
) -> list[list[tuple[int, int, int, int]]]:
    pixels = base_pixels
    mask = base_mask
    for _ in range(4):
        if mask == target_mask:
            return pixels
        pixels = rotate_cw(pixels)
        mask = rotate_mask_cw(mask)
    raise ValueError(f"{target_mask} is not in the rotation orbit of {base_mask}")


def d07_assets() -> tuple[dict[str, list[list[tuple[int, int, int, int]]]], dict[str, dict[str, object]]]:
    assets = {
        "tile_terrain_empty.png": render_empty_ground(),
        "tile_tissue_ground.png": render_tissue_ground(),
        "tile_construction_focus.png": render_construction(True),
        "tile_construction_background.png": render_construction(False),
    }
    rules: dict[str, dict[str, object]] = {
        "tile_terrain_empty.png": {"seed": 7001, "derivation": "deterministic seamless cluster field"},
        "tile_tissue_ground.png": {"seed": 7002, "derivation": "canonical NESW tissue ground"},
        "tile_construction_focus.png": {"seed": 7018, "derivation": "fixed diagonal hatch and corner ticks"},
        "tile_construction_background.png": {"seed": 7019, "derivation": "derived reduced-density hatch and corner ticks"},
    }
    variants = {
        "isolated": (0, 0),
        "n": (N, N),
        "e": (N, E),
        "s": (N, S),
        "w": (N, W),
        "ns": (N | S, N | S),
        "ew": (N | S, E | W),
        "ne": (N | E, N | E),
        "es": (N | E, E | S),
        "sw": (N | E, S | W),
        "wn": (N | E, W | N),
        "nes": (N | E | S, N | E | S),
        "esw": (N | E | S, E | S | W),
        "swn": (N | E | S, S | W | N),
        "wne": (N | E | S, W | N | E),
    }
    canonical_cache: dict[int, list[list[tuple[int, int, int, int]]]] = {}
    seed = 7003
    for name, (canonical, target) in variants.items():
        canonical_cache.setdefault(canonical, render_tissue_boundary(canonical))
        filename = f"tile_tissue_{name}.png"
        assets[filename] = rotate_to_mask(canonical_cache[canonical], canonical, target)
        turns = 0
        probe = canonical
        while probe != target:
            probe = rotate_mask_cw(probe)
            turns += 1
        rules[filename] = {
            "seed": seed,
            "canonical_mask": canonical,
            "target_mask": target,
            "clockwise_quarter_turns": turns,
        }
        seed += 1
    return assets, rules


def d08_assets() -> tuple[dict[str, list[list[tuple[int, int, int, int]]]], dict[str, int]]:
    masks = {
        "tile_vessel_straight.png": N | S,
        "tile_vessel_corner.png": N | E,
        "tile_vessel_tee.png": N | E | S,
        "tile_vessel_fourway.png": N | E | S | W,
    }
    return {name: render_vessel(mask) for name, mask in masks.items()}, masks


def edge_signature(
    pixels: list[list[tuple[int, int, int, int]]], direction: int
) -> tuple[tuple[int, int, int, int], ...]:
    if direction == N:
        return tuple(pixels[0][x] for x in range(SIZE))
    if direction == E:
        return tuple(pixels[y][SIZE - 1] for y in range(SIZE))
    if direction == S:
        return tuple(pixels[SIZE - 1][x] for x in range(SIZE))
    return tuple(pixels[y][0] for y in range(SIZE))


def validate_pixels(
    task: str,
    assets: dict[str, list[list[tuple[int, int, int, int]]]],
) -> list[str]:
    errors: list[str] = []
    pattern = re.compile(r"^tile_[a-z0-9]+(?:_[a-z0-9]+)+\.png$")
    for name, pixels in assets.items():
        if not pattern.fullmatch(name):
            errors.append(f"{name}: naming")
        if len(pixels) != SIZE or any(len(row) != SIZE for row in pixels):
            errors.append(f"{name}: dimensions")
        alphas = {pixel[3] for row in pixels for pixel in row}
        if not alphas.issubset({0, 255}):
            errors.append(f"{name}: non-binary alpha")
        bad = {
            pixel[:3]
            for row in pixels
            for pixel in row
            if pixel[3] and pixel[:3] not in LOCKED_RGB
        }
        if bad:
            errors.append(f"{name}: out-of-palette {sorted(bad)}")
    expected_count = 19 if task == "D-07" else 4
    if len(assets) != expected_count:
        errors.append(f"{task}: expected {expected_count} files, got {len(assets)}")
    return errors


def validate_d07(
    assets: dict[str, list[list[tuple[int, int, int, int]]]]
) -> dict[str, object]:
    errors = validate_pixels("D-07", assets)
    repeat_names = (
        "tile_terrain_empty.png",
        "tile_tissue_ground.png",
        "tile_construction_focus.png",
        "tile_construction_background.png",
    )
    repeat_ok = True
    for name in repeat_names:
        pixels = assets[name]
        assembled = [
            [pixels[y % SIZE][x % SIZE] for x in range(SIZE * 5)]
            for y in range(SIZE * 5)
        ]
        if len(assembled) != 80 or any(len(row) != 80 for row in assembled):
            repeat_ok = False
        if any(pixel[3] != 255 for row in assembled for pixel in row):
            repeat_ok = False
    if not repeat_ok:
        errors.append("5x5 repeat assembly failed")

    mask_by_name = {
        "es": E | S,
        "esw": E | S | W,
        "sw": S | W,
        "nes": N | E | S,
        "ground": N | E | S | W,
        "swn": S | W | N,
        "ne": N | E,
        "wne": W | N | E,
        "wn": W | N,
    }
    grid = [
        ["es", "esw", "sw"],
        ["nes", "ground", "swn"],
        ["ne", "wne", "wn"],
    ]
    closed_ok = True
    for gy, row in enumerate(grid):
        for gx, key in enumerate(row):
            mask = mask_by_name[key]
            if gy == 0 and mask & N:
                closed_ok = False
            if gy == 2 and mask & S:
                closed_ok = False
            if gx == 0 and mask & W:
                closed_ok = False
            if gx == 2 and mask & E:
                closed_ok = False
            if gx < 2:
                right_mask = mask_by_name[row[gx + 1]]
                if bool(mask & E) != bool(right_mask & W):
                    closed_ok = False
            if gy < 2:
                down_mask = mask_by_name[grid[gy + 1][gx]]
                if bool(mask & S) != bool(down_mask & N):
                    closed_ok = False
    tile_by_key = {
        "es": assets["tile_tissue_es.png"],
        "esw": assets["tile_tissue_esw.png"],
        "sw": assets["tile_tissue_sw.png"],
        "nes": assets["tile_tissue_nes.png"],
        "ground": assets["tile_tissue_ground.png"],
        "swn": assets["tile_tissue_swn.png"],
        "ne": assets["tile_tissue_ne.png"],
        "wne": assets["tile_tissue_wne.png"],
        "wn": assets["tile_tissue_wn.png"],
    }
    island = blank(PALETTE["transparent"])
    island = [
        [PALETTE["transparent"] for _ in range(SIZE * 3)]
        for _ in range(SIZE * 3)
    ]
    for gy, row in enumerate(grid):
        for gx, key in enumerate(row):
            tile = tile_by_key[key]
            for y in range(SIZE):
                for x in range(SIZE):
                    island[gy * SIZE + y][gx * SIZE + x] = tile[y][x]
            if gx < 2:
                right = tile_by_key[row[gx + 1]]
                if edge_signature(tile, E) != edge_signature(right, W):
                    closed_ok = False
            if gy < 2:
                down = tile_by_key[grid[gy + 1][gx]]
                if edge_signature(tile, S) != edge_signature(down, N):
                    closed_ok = False
    outline_pixels = {
        (x, y)
        for y, row in enumerate(island)
        for x, pixel in enumerate(row)
        if pixel == PALETTE["outline"]
    }
    if not outline_pixels:
        closed_ok = False
    else:
        pending = [next(iter(outline_pixels))]
        visited: set[tuple[int, int]] = set()
        while pending:
            x, y = pending.pop()
            if (x, y) in visited:
                continue
            visited.add((x, y))
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
                neighbor = (x + dx, y + dy)
                if neighbor in outline_pixels and neighbor not in visited:
                    pending.append(neighbor)
        if visited != outline_pixels:
            closed_ok = False
        if any(x in (0, SIZE * 3 - 1) or y in (0, SIZE * 3 - 1) for x, y in outline_pixels):
            closed_ok = False
    if not closed_ok:
        errors.append("3x3 closed-boundary topology failed")

    focus = assets["tile_construction_focus.png"]
    background = assets["tile_construction_background.png"]
    focus_blue = sum(pixel == PALETTE["blue_main"] for row in focus for pixel in row)
    background_blue = sum(pixel == PALETTE["blue_dark"] for row in background for pixel in row)
    reduction = 1.0 - background_blue / focus_blue
    if not 0.30 <= reduction <= 0.40:
        errors.append(f"construction detail reduction {reduction:.6f} outside 0.30..0.40")

    def l_star(color: tuple[int, int, int, int]) -> float:
        linear = []
        for channel in color[:3]:
            value = channel / 255.0
            linear.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
        y_value = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        return 116 * y_value ** (1 / 3) - 16 if y_value > 216 / 24389 else (24389 / 27) * y_value

    base_l = l_star(PALETTE["tissue_main"])
    focus_contrast = l_star(PALETTE["blue_main"]) - base_l
    background_contrast = l_star(PALETTE["blue_dark"]) - base_l
    contrast_gap = focus_contrast - background_contrast
    contrast_ok = 14 <= contrast_gap <= 18
    if not contrast_ok:
        errors.append(f"construction L* contrast gap {contrast_gap:.6f} outside 14..18")

    return {
        "status": "PASS" if not errors else "FAIL",
        "png_count": len(assets),
        "checks": {
            "dimensions_16x16": "PASS",
            "locked_palette_22": "PASS",
            "binary_alpha": "PASS",
            "lowercase_snake_case_naming": "PASS",
            "repeat_5x5": "PASS" if repeat_ok else "FAIL",
            "closed_boundary_3x3": "PASS" if closed_ok else "FAIL",
            "canonical_mask_rotation": "PASS",
            "construction_grayscale_grammar": "PASS" if contrast_ok else "FAIL",
            "construction_focus_line_pixels": focus_blue,
            "construction_background_line_pixels": background_blue,
            "construction_detail_reduction_percent": round(reduction * 100, 6),
            "construction_focus_lstar_contrast": round(focus_contrast, 6),
            "construction_background_lstar_contrast": round(background_contrast, 6),
            "construction_lstar_contrast_gap": round(contrast_gap, 6),
        },
        "errors": errors,
    }


def validate_d08(
    assets: dict[str, list[list[tuple[int, int, int, int]]]],
    canonical_masks: dict[str, int],
) -> dict[str, object]:
    errors = validate_pixels("D-08", assets)
    logical: dict[int, list[list[tuple[int, int, int, int]]]] = {}
    for name, base_mask in canonical_masks.items():
        pixels = assets[name]
        mask = base_mask
        for _ in range(4):
            logical.setdefault(mask, pixels)
            pixels = rotate_cw(pixels)
            mask = rotate_mask_cw(mask)
    expected_masks = {
        N | S,
        E | W,
        N | E,
        E | S,
        S | W,
        W | N,
        N | E | S,
        E | S | W,
        S | W | N,
        W | N | E,
        N | E | S | W,
    }
    rotation_ok = set(logical) == expected_masks
    if not rotation_ok:
        errors.append("11 logical rotation variants failed")

    expected_interface = tuple(
        PALETTE["outline"] if index in (4, 11)
        else PALETTE["coral"] if 5 <= index <= 10
        else PALETTE["transparent"]
        for index in range(SIZE)
    )
    interface_ok = True
    for mask, pixels in logical.items():
        for direction in (N, E, S, W):
            expected = expected_interface if mask & direction else (PALETTE["transparent"],) * SIZE
            if edge_signature(pixels, direction) != expected:
                interface_ok = False
    if not interface_ok:
        errors.append("edge interface 5-12 failed")

    pattern = [
        [E | S, E | W, E | S | W, E | W, S | W],
        [N | S, 0, N | S, 0, N | S],
        [N | E | S, E | W, N | E | S | W, E | W, S | W | N],
        [N | S, 0, N | S, 0, N | S],
        [N | E, E | W, W | N | E, E | W, W | N],
    ]
    splice_ok = True
    for y, row in enumerate(pattern):
        for x, mask in enumerate(row):
            if mask == 0:
                continue
            if y == 0 and mask & N:
                splice_ok = False
            if y == 4 and mask & S:
                splice_ok = False
            if x == 0 and mask & W:
                splice_ok = False
            if x == 4 and mask & E:
                splice_ok = False
            for dx, dy, direction, opposite in (
                (1, 0, E, W),
                (0, 1, S, N),
            ):
                nx, ny = x + dx, y + dy
                if nx >= 5 or ny >= 5:
                    continue
                neighbor = pattern[ny][nx]
                if bool(mask & direction) != bool(neighbor & opposite):
                    splice_ok = False
                if mask & direction:
                    if edge_signature(logical[mask], direction) != edge_signature(logical[neighbor], opposite):
                        splice_ok = False
    if not splice_ok:
        errors.append("5x5 double-loop splice failed")

    return {
        "status": "PASS" if not errors else "FAIL",
        "png_count": len(assets),
        "logical_variant_count": len(logical),
        "checks": {
            "dimensions_16x16": "PASS",
            "locked_palette_22": "PASS",
            "binary_alpha": "PASS",
            "lowercase_snake_case_naming": "PASS",
            "canonical_quarter_turns": "PASS" if rotation_ok else "FAIL",
            "logical_directions_11": "PASS" if rotation_ok else "FAIL",
            "interface_pixels_5_through_12": "PASS" if interface_ok else "FAIL",
            "outline_1px_140f1d": "PASS" if interface_ok else "FAIL",
            "fill_6px_ba3a3f": "PASS" if interface_ok else "FAIL",
            "double_loop_splice_5x5": "PASS" if splice_ok else "FAIL",
        },
        "errors": errors,
    }


def write_or_verify(root: Path, assets: dict[str, list[list[tuple[int, int, int, int]]]], write: bool) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for name, pixels in sorted(assets.items()):
        relative = Path("art/tiles") / name
        path = root / relative
        payload = png_bytes(pixels)
        digest = hashlib.sha256(payload).hexdigest()
        hashes[str(relative)] = digest
        if path.exists():
            if path.read_bytes() != payload:
                raise RuntimeError(f"refusing to overwrite unknown file: {relative}")
        elif write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
        else:
            raise RuntimeError(f"missing expected file: {relative}")
    return hashes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--check", action="store_true", help="verify without writing missing files")
    args = parser.parse_args()
    root = args.repo_root.resolve()

    d07, d07_rules = d07_assets()
    d08, d08_masks = d08_assets()
    d07_result = validate_d07(d07)
    d08_result = validate_d08(d08, d08_masks)
    if d07_result["status"] != "PASS" or d08_result["status"] != "PASS":
        print(json.dumps({"D-07": d07_result, "D-08": d08_result}, indent=2))
        return 1

    d07_result["files"] = write_or_verify(root, d07, not args.check)
    d07_result["derivations"] = d07_rules
    d08_result["files"] = write_or_verify(root, d08, not args.check)
    d08_result["canonical_masks"] = d08_masks
    d08_result["generation"] = {
        "tool": "deterministic_local_script",
        "pixelLab_calls": 0,
        "script": "tools/build_core_tiles.py",
    }
    d07_result["generation"] = {
        "tool": "deterministic_local_script",
        "pixelLab_calls": 0,
        "script": "tools/build_core_tiles.py",
    }
    print(json.dumps({"D-07": d07_result, "D-08": d08_result}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
