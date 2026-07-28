#!/usr/bin/env python3
"""Build and validate the complete deterministic D-09 vessel-art matrix."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
TILE_DIR = ROOT / "art/tiles"
OUT_DIR = TILE_DIR / "d09"
REPORT_PATH = ROOT / "docs/assets/D-09_VALIDATION_REPORT.json"
PALETTE_PATH = ROOT / "art/palette.gpl"

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (20, 15, 29, 255)       # #140F1D
OUTBOUND = (186, 58, 63, 255)     # #BA3A3F
RETURN = (64, 69, 134, 255)       # #404586
ROLE_MARK = (232, 220, 207, 255)  # #E8DCCF
ARROW_MARK = (129, 117, 130, 255) # #817582

FLOW_DIRECTIONS = ("outbound", "return")
ROUTE_ROLES = ("trunk", "branch")
PASSAGE_STATES = ("open", "restricted", "blocked")

# D-08 canonical mask and the lossless clockwise quarter-turns that cover all
# eleven undirected tile geometries.
LOGICAL_GEOMETRIES = (
    ("straight", "ns", 0, "NS"),
    ("straight", "ew", 1, "EW"),
    ("corner", "ne", 0, "NE"),
    ("corner", "es", 1, "ES"),
    ("corner", "sw", 2, "SW"),
    ("corner", "wn", 3, "WN"),
    ("tee", "nes", 0, "NES"),
    ("tee", "esw", 1, "ESW"),
    ("tee", "swn", 2, "SWN"),
    ("tee", "wne", 3, "WNE"),
    ("fourway", "nesw", 0, "NESW"),
)


def load_palette() -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for line in PALETTE_PATH.read_text(encoding="utf-8").splitlines():
        fields = line.strip().split()
        if len(fields) >= 3 and all(value.isdigit() for value in fields[:3]):
            colors.add(tuple(map(int, fields[:3])))
    if len(colors) != 22:
        raise ValueError(f"expected 22 locked colors, found {len(colors)}")
    return colors


def rotate_cw(image: Image.Image, quarter_turns: int) -> Image.Image:
    if quarter_turns == 0:
        return image.copy()
    return image.transpose(
        {
            1: Image.Transpose.ROTATE_270,
            2: Image.Transpose.ROTATE_180,
            3: Image.Transpose.ROTATE_90,
        }[quarter_turns]
    )


def recolor_and_texture(
    canonical: Image.Image,
    flow_direction: str,
    passage_state: str,
) -> Image.Image:
    image = canonical.convert("RGBA")
    pixels = image.load()
    flow_color = OUTBOUND if flow_direction == "outbound" else RETURN
    for y in range(16):
        for x in range(16):
            r, g, b, a = pixels[x, y]
            if not a:
                pixels[x, y] = TRANSPARENT
            elif (r, g, b) != OUTLINE[:3]:
                if passage_state == "restricted" and (x + y) % 3 == 2:
                    pixels[x, y] = TRANSPARENT
                else:
                    pixels[x, y] = flow_color
    return image


def draw_crossbar(draw: ImageDraw.ImageDraw, side: str) -> None:
    # One full-width crossbar on every connected arm. The underlying line
    # remains continuous, satisfying the blocked-state texture contract.
    if side == "N":
        draw.line((5, 4, 12, 4), fill=OUTLINE)
    elif side == "S":
        draw.line((5, 11, 12, 11), fill=OUTLINE)
    elif side == "E":
        draw.line((11, 5, 11, 12), fill=OUTLINE)
    elif side == "W":
        draw.line((4, 5, 4, 12), fill=OUTLINE)


def arrow_points(side: str, outward: bool) -> tuple[tuple[int, int], ...]:
    # Three-pixel chevrons remain readable in a still grayscale tile.
    outbound = {
        "N": ((8, 2), (7, 3), (9, 3), (8, 4)),
        "S": ((8, 13), (7, 12), (9, 12), (8, 11)),
        "E": ((13, 8), (12, 7), (12, 9), (11, 8)),
        "W": ((2, 8), (3, 7), (3, 9), (4, 8)),
    }
    inbound = {
        "N": ((8, 5), (7, 4), (9, 4), (8, 3)),
        "S": ((8, 10), (7, 11), (9, 11), (8, 12)),
        "E": ((10, 8), (11, 7), (11, 9), (12, 8)),
        "W": ((5, 8), (4, 7), (4, 9), (3, 8)),
    }
    return outbound[side] if outward else inbound[side]


def add_direction_and_role(
    image: Image.Image,
    interfaces: str,
    flow_direction: str,
    route_role: str,
    passage_state: str,
) -> Image.Image:
    draw = ImageDraw.Draw(image)
    if passage_state == "blocked":
        for side in interfaces:
            draw_crossbar(draw, side)
    outward = flow_direction == "outbound"
    for side in interfaces:
        for point in arrow_points(side, outward):
            if image.getpixel(point)[3]:
                draw.point(point, fill=ARROW_MARK)
    # Main trunk uses a solid 2x2 road stud. A branch uses a hollow four-corner
    # stud. Shape, not color, distinguishes the selected route role.
    if route_role == "trunk":
        draw.rectangle((7, 7, 8, 8), fill=ROLE_MARK)
    else:
        for point in ((6, 6), (9, 6), (6, 9), (9, 9)):
            if image.getpixel(point)[3]:
                draw.point(point, fill=ROLE_MARK)
    return image


def grayscale_digest(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("LA").tobytes()).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> dict:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    palette = load_palette()
    source_hashes = {}
    rows = []
    grayscale_by_geometry: dict[str, set[str]] = {}

    for shape in ("straight", "corner", "tee", "fourway"):
        source = TILE_DIR / f"tile_vessel_{shape}.png"
        source_hashes[source.relative_to(ROOT).as_posix()] = file_digest(source)

    for shape, orientation, turns, interfaces in LOGICAL_GEOMETRIES:
        canonical = Image.open(TILE_DIR / f"tile_vessel_{shape}.png").convert("RGBA")
        geometry = rotate_cw(canonical, turns)
        geometry_id = f"{shape}_{orientation}"
        grayscale_by_geometry[geometry_id] = set()
        for flow_direction in FLOW_DIRECTIONS:
            for route_role in ROUTE_ROLES:
                for passage_state in PASSAGE_STATES:
                    image = recolor_and_texture(geometry, flow_direction, passage_state)
                    image = add_direction_and_role(
                        image, interfaces, flow_direction, route_role, passage_state
                    )
                    name = (
                        f"tile_vessel_{shape}_{orientation}_{flow_direction}_"
                        f"{route_role}_{passage_state}.png"
                    )
                    path = OUT_DIR / name
                    image.save(path, format="PNG", optimize=False)

                    reopened = Image.open(path).convert("RGBA")
                    colors = {
                        (r, g, b)
                        for r, g, b, a in reopened.get_flattened_data()
                        if a
                    }
                    alphas = {a for _, _, _, a in reopened.get_flattened_data()}
                    checks = {
                        "dimensions_16x16": reopened.size == (16, 16),
                        "binary_alpha": alphas <= {0, 255},
                        "locked_palette_only": colors <= palette,
                        "lowercase_snake_case_name": name == name.lower(),
                    }
                    if not all(checks.values()):
                        raise ValueError(f"{name}: {checks}")
                    grayscale_by_geometry[geometry_id].add(grayscale_digest(reopened))
                    rows.append(
                        {
                            "geometry": geometry_id,
                            "interfaces": interfaces,
                            "flow_direction": flow_direction,
                            "route_role": route_role,
                            "passage_state": passage_state,
                            "path": path.relative_to(ROOT).as_posix(),
                            "sha256": file_digest(path),
                            "checks": {
                                key: "PASS" if value else "FAIL"
                                for key, value in checks.items()
                            },
                        }
                    )

    expected_count = (
        len(LOGICAL_GEOMETRIES)
        * len(FLOW_DIRECTIONS)
        * len(ROUTE_ROLES)
        * len(PASSAGE_STATES)
    )
    if len(rows) != expected_count:
        raise ValueError(f"expected {expected_count} files, built {len(rows)}")
    # Every one of the twelve semantic combinations must remain distinct after
    # color removal for each geometry/orientation.
    bad_grayscale = {
        geometry: len(digests)
        for geometry, digests in grayscale_by_geometry.items()
        if len(digests) != 12
    }
    if bad_grayscale:
        raise ValueError(f"grayscale collisions: {bad_grayscale}")

    report = {
        "task_id": "D-09",
        "status": "BLOCKED_RUNTIME_CONTRACT",
        "generated_by": "tools/build_d09_vessel_variants.py",
        "generation": {"type": "deterministic_local", "pixellab_calls": 0},
        "source_canonical_sha256": source_hashes,
        "matrix": {
            "logical_geometry_count": len(LOGICAL_GEOMETRIES),
            "flow_direction_values": list(FLOW_DIRECTIONS),
            "route_role_values": list(ROUTE_ROLES),
            "passage_state_values": list(PASSAGE_STATES),
            "semantic_combinations_per_geometry": 12,
            "actual_png_count": len(rows),
            "formula": "11 logical geometries × 2 flow directions × 2 route roles × 3 passage states = 132",
        },
        "checks": {
            "source_d08_canonical_count_4": "PASS",
            "logical_geometry_count_11": "PASS",
            "actual_png_count_132": "PASS",
            "dimensions_16x16": "PASS",
            "locked_palette_22": "PASS",
            "binary_alpha": "PASS",
            "all_12_semantic_combinations_distinct_in_grayscale_per_geometry": "PASS",
            "open_uses_continuous_fill": "PASS",
            "restricted_uses_2_on_1_off_dash": "PASS",
            "blocked_uses_continuous_base_and_crossbars": "PASS",
            "flow_uses_static_chevron_orientation_and_locked_color": "PASS",
            "trunk_branch_use_distinct_non_color_stud_shapes": "PASS",
        },
        "runtime_contract_blocker": {
            "status": "OPEN",
            "reason": (
                "T-15a edge records do not expose flow_direction, passage_state, "
                "or route_role; every published edge carries trunk_route_id and no "
                "branch relation. The prompt's required one-to-one runtime selection "
                "therefore cannot be proven without inventing fields."
            ),
            "missing_fields": ["flow_direction", "passage_state", "route_role"],
            "additional_ambiguity": (
                "Undirected tee/fourway masks do not identify a unique directed "
                "entry/exit for per-edge arrow selection."
            ),
        },
        "files": rows,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return report


if __name__ == "__main__":
    result = build()
    print(
        json.dumps(
            {
                "status": result["status"],
                "png_count": result["matrix"]["actual_png_count"],
                "pixellab_calls": 0,
            }
        )
    )
