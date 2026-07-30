#!/usr/bin/env python3
"""Build the 8-second, 8-FPS layered Metabolis title animation."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


WIDTH, HEIGHT = 320, 180
FPS = 8
FRAME_COUNT = 64
DURATION_SECONDS = 8

STATIC_ROOT = Path("art/previews/title_layers_static")
OUTPUT_ROOT = Path("art/animations/title_layers")
REPORT_PATH = Path("docs/assets/TITLE_LAYER_ANIMATION_QA.json")
SPEC_PATH = Path("docs/TITLE_INTRO_ANIMATION_SPEC.md")

LAYER_ORDER = [
    "01_sky",
    "02_terrain",
    "03_main_building",
    "04_small_buildings",
    "05_vehicle_cargo",
    "06_roadside_props",
]

OUTLINE = (20, 15, 29, 255)
NEUTRAL_DARK = (81, 72, 84, 255)
NEUTRAL_MID = (129, 117, 130, 255)
CREAM = (232, 220, 207, 255)
CORAL_DARK = (52, 1, 6, 255)
CORAL = (186, 58, 63, 255)
CORAL_LIGHT = (194, 84, 83, 255)
BLUE_DARK = (41, 49, 74, 255)
BLUE = (64, 69, 134, 255)
BLUE_LIGHT = (83, 84, 140, 255)
TISSUE_DARK = (145, 70, 95, 255)
TISSUE = (190, 110, 135, 255)
TISSUE_LIGHT = (201, 129, 151, 255)
AMBER_DARK = (178, 108, 9, 255)
AMBER = (226, 149, 58, 255)
AMBER_LIGHT = (221, 173, 126, 255)
MINT_DARK = (115, 205, 155, 255)
MINT = (177, 255, 209, 255)
MINT_LIGHT = (244, 255, 248, 255)
OXYGEN = (72, 165, 207, 255)
OXYGEN_LIGHT = (205, 217, 225, 255)
TRANSPARENT = (0, 0, 0, 0)

VANISHING_POINT = (1088.0 / 3.0, 220.0 / 3.0)
TRUCK_STOP = (145.0, 121.0)

BAYER_8 = (
    (0, 32, 8, 40, 2, 34, 10, 42),
    (48, 16, 56, 24, 50, 18, 58, 26),
    (12, 44, 4, 36, 14, 46, 6, 38),
    (60, 28, 52, 20, 62, 30, 54, 22),
    (3, 35, 11, 43, 1, 33, 9, 41),
    (51, 19, 59, 27, 49, 17, 57, 25),
    (15, 47, 7, 39, 13, 45, 5, 37),
    (63, 31, 55, 23, 61, 29, 53, 21),
)


def flattened(image: Image.Image) -> list[tuple[int, int, int, int]]:
    pixels = (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )
    return list(pixels)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def interval(frame: int, start: int, end: int) -> float:
    if end <= start:
        return 1.0 if frame >= end else 0.0
    return smoothstep((frame - start) / (end - start))


def night_factor(frame: int) -> float:
    if frame < 16:
        return 0.0
    if frame < 36:
        return interval(frame, 16, 36)
    if frame < 56:
        return 1.0
    return 1.0 - 0.65 * interval(frame, 56, 63)


def ordered_blend(
    first: Image.Image,
    second: Image.Image,
    progress: float,
    phase: int = 0,
) -> Image.Image:
    if progress <= 0.0:
        return first.copy()
    if progress >= 1.0:
        return second.copy()
    left = flattened(first.convert("RGBA"))
    right = flattened(second.convert("RGBA"))
    output: list[tuple[int, int, int, int]] = []
    for index, (a, b) in enumerate(zip(left, right)):
        x = index % first.width
        y = index // first.width
        threshold = (BAYER_8[(y + phase) % 8][(x + phase) % 8] + 0.5) / 64.0
        output.append(b if progress >= threshold else a)
    image = Image.new("RGBA", first.size, TRANSPARENT)
    image.putdata(output)
    return image


def draw_cloud(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    body: tuple[int, int, int, int],
    highlight: tuple[int, int, int, int],
    shadow: tuple[int, int, int, int],
) -> None:
    draw.rectangle((x + 2, y + 4, x + 28, y + 7), fill=body)
    draw.rectangle((x + 7, y + 2, x + 24, y + 7), fill=body)
    draw.rectangle((x + 12, y, x + 19, y + 7), fill=body)
    draw.rectangle((x + 9, y + 2, x + 18, y + 3), fill=highlight)
    draw.rectangle((x + 5, y + 7, x + 25, y + 7), fill=shadow)
    draw.point((x, y + 6), fill=body)
    draw.point((x + 30, y + 6), fill=body)


def draw_sun(draw: ImageDraw.ImageDraw, center: tuple[int, int]) -> None:
    x, y = center
    rows = {
        -4: (-1, 1),
        -3: (-3, 3),
        -2: (-4, 4),
        -1: (-4, 4),
        0: (-4, 4),
        1: (-4, 4),
        2: (-3, 3),
        3: (-2, 2),
    }
    for dy, (left, right) in rows.items():
        draw.line((x + left, y + dy, x + right, y + dy), fill=AMBER)
    draw.rectangle((x - 2, y - 2, x, y), fill=CREAM)
    draw.line((x + 2, y + 1, x + 3, y + 1), fill=AMBER_DARK)
    draw.line((x + 1, y + 3, x + 2, y + 3), fill=AMBER_DARK)


def draw_moon(draw: ImageDraw.ImageDraw, center: tuple[int, int]) -> None:
    x, y = center
    rows = {
        -4: (-1, 1),
        -3: (-3, 2),
        -2: (-4, 2),
        -1: (-4, 2),
        0: (-4, 2),
        1: (-3, 2),
        2: (-2, 2),
        3: (-1, 1),
    }
    for dy, (left, right) in rows.items():
        draw.line((x + left, y + dy, x + right, y + dy), fill=OXYGEN_LIGHT)
    draw.rectangle((x, y - 4, x + 4, y), fill=TRANSPARENT)
    draw.rectangle((x + 1, y + 1, x + 4, y + 2), fill=TRANSPARENT)


def sky_background(frame: int) -> Image.Image:
    # Large ordered-dither fills read as visual noise at 8 FPS.  The project
    # palette is intentionally compact, so the sky advances through clear,
    # held palette states like a traditional pixel-art time lapse.
    if frame < 20:
        color = AMBER_LIGHT
    elif frame < 26:
        color = TISSUE_LIGHT
    elif frame < 30:
        color = BLUE_LIGHT
    elif frame < 34:
        color = BLUE
    elif frame < 56:
        color = BLUE_DARK
    elif frame < 59:
        color = BLUE
    elif frame < 62:
        color = BLUE_LIGHT
    else:
        color = TISSUE_LIGHT
    return Image.new("RGBA", (WIDTH, HEIGHT), color)


def build_sky_frame(frame: int) -> Image.Image:
    image = sky_background(frame)
    factor = night_factor(frame)
    cloud_day = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    cloud_night = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    day_draw = ImageDraw.Draw(cloud_day)
    night_draw = ImageDraw.Draw(cloud_night)
    cloud_positions = [
        (28 + frame // 8, 24 + (1 if 20 <= frame % 32 < 28 else 0)),
        (168 + frame // 10, 42 - (1 if 8 <= frame % 32 < 16 else 0)),
    ]
    for x, y in cloud_positions:
        draw_cloud(day_draw, x, y, CREAM, MINT_LIGHT, OXYGEN_LIGHT)
        draw_cloud(night_draw, x, y, BLUE, BLUE_LIGHT, BLUE_DARK)
    image.alpha_composite(ordered_blend(cloud_day, cloud_night, factor))

    draw = ImageDraw.Draw(image)
    if frame <= 23:
        progress = interval(frame, 0, 23)
        sun_x = round(278 + 52 * progress)
        sun_y = round(44 + 29 * progress * progress)
        if sun_x < WIDTH + 5:
            draw_sun(draw, (sun_x, sun_y))

    if frame >= 23:
        if frame < 38:
            progress = interval(frame, 23, 38)
            moon_x = round(-8 + 66 * progress)
            moon_y = round(70 - 18 * progress)
        elif frame < 56:
            progress = interval(frame, 38, 55)
            moon_x = round(58 + 24 * progress)
            moon_y = round(52 - 6 * progress)
        else:
            progress = interval(frame, 56, 63)
            moon_x = round(82 + 28 * progress)
            moon_y = round(46 + 18 * progress)
        moon_layer = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
        draw_moon(ImageDraw.Draw(moon_layer), (moon_x, moon_y))
        image.alpha_composite(
            ordered_blend(
                Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT),
                moon_layer,
                min(1.0, factor / 0.45),
            )
        )

    stars = [
        (8, 18, OXYGEN_LIGHT, 0.20),
        (72, 34, BLUE_LIGHT, 0.55),
        (103, 20, OXYGEN_LIGHT, 0.35),
        (151, 13, BLUE_LIGHT, 0.72),
        (202, 29, OXYGEN_LIGHT, 0.42),
        (251, 16, OXYGEN_LIGHT, 0.28),
        (289, 52, BLUE_LIGHT, 0.66),
        (311, 38, OXYGEN_LIGHT, 0.48),
    ]
    draw = ImageDraw.Draw(image)
    for x, y, color, threshold in stars:
        if factor >= threshold:
            draw.point((x, y), fill=color)
    return image


def recolor(
    image: Image.Image,
    mapping: dict[tuple[int, int, int, int], tuple[int, int, int, int]],
) -> Image.Image:
    result = Image.new("RGBA", image.size, TRANSPARENT)
    result.putdata([mapping.get(pixel, pixel) for pixel in flattened(image.convert("RGBA"))])
    return result


def build_terrain_frames(static: Path) -> list[Image.Image]:
    day = Image.open(static / "terrain_road_afternoon.png").convert("RGBA")
    dusk = recolor(
        day,
        {
            NEUTRAL_DARK: BLUE_DARK,
            TISSUE: TISSUE_DARK,
            MINT_LIGHT: OXYGEN_LIGHT,
        },
    )
    late_dusk = recolor(
        day,
        {
            NEUTRAL_DARK: BLUE_DARK,
            TISSUE: TISSUE_DARK,
            MINT_LIGHT: OXYGEN_LIGHT,
            BLUE_DARK: OUTLINE,
        },
    )
    night = recolor(
        day,
        {
            NEUTRAL_DARK: OUTLINE,
            TISSUE: TISSUE_DARK,
            MINT_LIGHT: OXYGEN_LIGHT,
            BLUE_DARK: OUTLINE,
        },
    )
    frames: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        if frame < 24:
            current = day
        elif frame < 30:
            current = dusk
        elif frame < 36:
            current = late_dusk
        elif frame < 56:
            current = night
        elif frame < 60:
            current = late_dusk
        else:
            current = dusk
        frames.append(current.copy())
    return frames


def progressive_build(
    construction: Image.Image,
    complete: Image.Image,
    progress: float,
    region: tuple[int, int, int, int],
) -> Image.Image:
    if progress <= 0.0:
        return construction.copy()
    if progress >= 1.0:
        return complete.copy()
    left, top, right, bottom = region
    source = construction.convert("RGBA")
    target = complete.convert("RGBA")
    output = source.copy()
    output_pixels = output.load()
    source_pixels = source.load()
    target_pixels = target.load()
    height = max(1, bottom - top - 1)
    for y in range(top, bottom):
        vertical = (bottom - 1 - y) / height
        for x in range(left, right):
            spatial = (BAYER_8[y % 8][x % 8] + 0.5) / 64.0
            threshold = 0.72 * vertical + 0.28 * spatial
            output_pixels[x, y] = (
                target_pixels[x, y] if progress >= threshold else source_pixels[x, y]
            )
    return output


WINDOWS = [
    (78, 79, 86, 85),
    (91, 79, 100, 86),
    (90, 88, 100, 95),
    (76, 89, 87, 96),
]


def illuminate_windows(image: Image.Image, active: set[int]) -> Image.Image:
    result = image.copy().convert("RGBA")
    pixels = result.load()
    window_colors = {AMBER, MINT_DARK, MINT}
    for index in active:
        left, top, right, bottom = WINDOWS[index]
        for y in range(top, bottom):
            for x in range(left, right):
                if pixels[x, y] in window_colors:
                    pixels[x, y] = MINT_LIGHT
    return result


def main_window_activity(frame: int) -> set[int]:
    if 44 <= frame <= 51:
        return {(frame - 44) // 2}
    if frame in (52, 55):
        return {0, 1, 2, 3}
    return set()


def build_main_frames(static: Path) -> list[Image.Image]:
    construction = Image.open(static / "building_main_construction.png").convert("RGBA")
    complete = Image.open(static / "building_main_complete.png").convert("RGBA")
    frames: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        built = progressive_build(
            construction,
            complete,
            interval(frame, 18, 40),
            (40, 50, 152, 113),
        )
        frames.append(illuminate_windows(built, main_window_activity(frame)))
    return frames


def build_small_frames(static: Path) -> list[Image.Image]:
    construction = Image.open(static / "building_small_construction.png").convert("RGBA")
    complete = Image.open(static / "building_small_complete.png").convert("RGBA")
    regions = [
        (180, 68, 207, 103),
        (207, 68, 234, 103),
        (234, 68, 261, 103),
    ]
    timings = [(22, 34), (28, 40), (34, 46)]
    frames: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        current = construction.copy()
        for region, (start, end) in zip(regions, timings):
            current = progressive_build(
                current,
                complete,
                interval(frame, start, end),
                region,
            )
        frames.append(current)
    return frames


def quadratic_bezier(
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    progress: float,
) -> tuple[float, float]:
    inverse = 1.0 - progress
    x = inverse * inverse * start[0] + 2 * inverse * progress * control[0] + progress * progress * end[0]
    y = inverse * inverse * start[1] + 2 * inverse * progress * control[1] + progress * progress * end[1]
    return x, y


def truck_scale(center: tuple[float, float]) -> float:
    vx, vy = VANISHING_POINT
    stop_distance = math.hypot(TRUCK_STOP[0] - vx, TRUCK_STOP[1] - vy)
    distance = math.hypot(center[0] - vx, center[1] - vy)
    ratio = max(0.15, min(1.8, distance / stop_distance))
    return 0.65 + 0.35 * ratio


def truck_center_for_frame(frame: int) -> tuple[float, float] | None:
    if frame <= 13:
        return quadratic_bezier(
            (-15.0, 171.0),
            (58.0, 163.0),
            TRUCK_STOP,
            interval(frame, 0, 13),
        )
    if frame <= 22:
        return TRUCK_STOP
    if frame <= 38:
        return quadratic_bezier(
            TRUCK_STOP,
            (232.0, 108.0),
            (338.0, 80.0),
            interval(frame, 23, 38),
        )
    return None


def cargo_visibility_for_frame(frame: int) -> float:
    if frame < 12:
        return 0.0
    if frame < 16:
        return interval(frame, 12, 16)
    if frame < 29:
        return 1.0
    if frame <= 43:
        return 1.0 - interval(frame, 29, 43)
    return 0.0


def paste_center(
    canvas: Image.Image,
    sprite: Image.Image,
    center: tuple[float, float],
    scale: float = 1.0,
) -> None:
    width = max(1, round(sprite.width * scale))
    height = max(1, round(sprite.height * scale))
    resized = sprite.resize((width, height), Image.Resampling.NEAREST)
    x = round(center[0] - width / 2)
    y = round(center[1] - height / 2)
    canvas.alpha_composite(resized, (x, y))


def build_vehicle_frames(static: Path) -> list[Image.Image]:
    source = Image.open(static / "vehicle_truck_arrival.png").convert("RGBA")
    truck = source.crop((124, 108, 174, 134))
    cargo = source.crop((153, 92, 167, 107))
    frames: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        image = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
        center = truck_center_for_frame(frame)
        if center is not None:
            paste_center(image, truck, center, truck_scale(center))

        cargo_visibility = cargo_visibility_for_frame(frame)
        if cargo_visibility > 0.0:
            cargo_layer = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
            cargo_layer.alpha_composite(cargo, (153, 92))
            image.alpha_composite(
                ordered_blend(
                    Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT),
                    cargo_layer,
                    cargo_visibility,
                    phase=3,
                )
            )
        frames.append(image)
    return frames


def green_components(image: Image.Image) -> list[list[tuple[int, int]]]:
    green = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if image.getpixel((x, y)) in {MINT_DARK, MINT}
    }
    components: list[list[tuple[int, int]]] = []
    seen: set[tuple[int, int]] = set()
    for point in sorted(green):
        if point in seen:
            continue
        queue: deque[tuple[int, int]] = deque([point])
        seen.add(point)
        component: list[tuple[int, int]] = []
        while queue:
            x, y = queue.popleft()
            component.append((x, y))
            for nx in range(x - 1, x + 2):
                for ny in range(y - 1, y + 2):
                    neighbor = (nx, ny)
                    if neighbor in green and neighbor not in seen:
                        seen.add(neighbor)
                        queue.append(neighbor)
        components.append(component)
    return components


def sway_grass(image: Image.Image, frame: int) -> Image.Image:
    result = image.copy().convert("RGBA")
    pixels = result.load()
    components = green_components(result)
    samples: list[tuple[list[tuple[int, int]], dict[tuple[int, int], tuple[int, int, int, int]]]] = []
    for component in components:
        colors = {point: pixels[point[0], point[1]] for point in component}
        samples.append((component, colors))
        for x, y in component:
            pixels[x, y] = TRANSPARENT
    for component, colors in samples:
        min_x = min(x for x, _ in component)
        min_y = min(y for _, y in component)
        anchor_y = max(y for _, y in component)
        height = max(1, anchor_y - min_y)
        wave = math.sin(2.0 * math.pi * frame / 16.0 + min_x * 0.11)
        for x, y in component:
            influence = (anchor_y - y) / height
            shifted_x = x + round(2.0 * wave * influence)
            if 0 <= shifted_x < WIDTH:
                pixels[shifted_x, y] = colors[(x, y)]
    return result


def build_prop_frames(static: Path) -> list[Image.Image]:
    day = Image.open(static / "prop_roadside_day.png").convert("RGBA")
    night = Image.open(static / "prop_roadside_night.png").convert("RGBA")
    return [
        sway_grass(ordered_blend(day, night, night_factor(frame)), frame)
        for frame in range(FRAME_COUNT)
    ]


def road_upper_y(x: int) -> float:
    return 130.0 - 50.0 * x / 320.0


def building_road_clearance(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    minimum = float("inf")
    for x in range(WIDTH):
        visible = [y for y in range(HEIGHT) if alpha.getpixel((x, y)) >= 128]
        if visible:
            minimum = min(minimum, road_upper_y(x) - max(visible))
    return minimum


def load_palette(path: Path) -> set[tuple[int, int, int]]:
    colors: set[tuple[int, int, int]] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 3 and all(part.isdigit() for part in parts[:3]):
            colors.add(tuple(int(part) for part in parts[:3]))
    if len(colors) != 22:
        raise RuntimeError(f"Expected 22 palette colors, found {len(colors)}")
    return colors


def validate_layer_frames(
    layer: str,
    frames: list[Image.Image],
    palette: set[tuple[int, int, int]],
) -> dict[str, object]:
    visible_colors = {
        pixel[:3]
        for frame in frames
        for pixel in flattened(frame.convert("RGBA"))
        if pixel[3] == 255
    }
    alpha_values = {
        pixel[3]
        for frame in frames
        for pixel in flattened(frame.convert("RGBA"))
    }
    nonempty = [index for index, frame in enumerate(frames) if frame.getchannel("A").getbbox()]
    result: dict[str, object] = {
        "frame_count": len(frames),
        "all_320x180": all(frame.size == (WIDTH, HEIGHT) for frame in frames),
        "locked_palette": visible_colors <= palette,
        "binary_alpha": alpha_values <= {0, 255},
        "visible_color_count": len(visible_colors),
        "nonempty_frame_count": len(nonempty),
        "first_nonempty_frame": nonempty[0] if nonempty else None,
        "last_nonempty_frame": nonempty[-1] if nonempty else None,
    }
    if layer in {"03_main_building", "04_small_buildings"}:
        clearances = [building_road_clearance(frame) for frame in frames]
        result["minimum_road_clearance_pixels"] = round(min(clearances), 3)
        result["never_intersects_road"] = min(clearances) > 0.0
    if layer == "01_sky":
        result["all_frames_opaque"] = all(
            frame.getchannel("A").getextrema() == (255, 255) for frame in frames
        )
    return result


def portable_path(path: Path, repo_root: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def save_frames(
    root: Path,
    layer: str,
    frames: list[Image.Image],
    repo_root: Path,
) -> list[dict[str, str]]:
    directory = root / layer
    directory.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, str]] = []
    for index, frame in enumerate(frames):
        path = directory / f"frame_{index:03d}.png"
        frame.save(path, optimize=True)
        records.append({"path": portable_path(path, repo_root), "sha256": sha256(path)})
    return records


def composite_frames(layers: dict[str, list[Image.Image]]) -> list[Image.Image]:
    output: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        image = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
        for layer in LAYER_ORDER:
            image.alpha_composite(layers[layer][frame])
        output.append(image)
    return output


def save_preview(composites: list[Image.Image], preview_root: Path) -> dict[str, str]:
    gif_path = preview_root / "metabolis_title_layer_animation.gif"
    gif_frames = [
        frame.convert("P", palette=Image.Palette.ADAPTIVE, colors=64, dither=Image.Dither.NONE)
        for frame in composites
    ]
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=125,
        loop=0,
        optimize=False,
    )

    selected = [0, 8, 16, 24, 32, 40, 48, 56]
    sheet = Image.new("RGBA", (WIDTH * 4, (HEIGHT + 14) * 2), OUTLINE)
    draw = ImageDraw.Draw(sheet)
    for index, frame_index in enumerate(selected):
        column = index % 4
        row = index // 4
        x = column * WIDTH
        y = row * (HEIGHT + 14)
        draw.text((x + 4, y + 2), f"{frame_index / FPS:.0f}s", fill=MINT_LIGHT)
        sheet.alpha_composite(composites[frame_index], (x, y + 14))
    sheet_path = preview_root / "metabolis_title_layer_animation_contact.png"
    sheet.save(sheet_path, optimize=True)
    return {"gif": gif_path.as_posix(), "contact_sheet": sheet_path.as_posix()}


def sky_palette_state(frame: int) -> str:
    if frame < 20:
        return "afternoon_amber"
    if frame < 26:
        return "dusk_tissue"
    if frame < 30:
        return "dusk_blue_light"
    if frame < 34:
        return "night_blue"
    if frame < 56:
        return "night_blue_dark"
    if frame < 59:
        return "dawn_blue"
    if frame < 62:
        return "dawn_blue_light"
    return "dawn_tissue"


def terrain_palette_state(frame: int) -> str:
    if frame < 24:
        return "day"
    if frame < 30:
        return "dusk"
    if frame < 36:
        return "late_dusk"
    if frame < 56:
        return "night"
    if frame < 60:
        return "late_dusk"
    return "dusk"


def truck_phase(frame: int) -> str:
    if frame <= 13:
        return "arriving"
    if frame <= 22:
        return "unloading"
    if frame <= 38:
        return "departing"
    return "absent"


def cargo_phase(frame: int) -> str:
    if frame < 12:
        return "absent"
    if frame < 16:
        return "appearing"
    if frame < 29:
        return "delivered"
    if frame <= 43:
        return "consumed"
    return "absent"


def ui_phase(frame: int) -> str:
    if frame < 42:
        return "hidden"
    if frame < 46:
        return "title_entering"
    if frame < 52:
        return "title_and_subtitle_entering"
    if frame < 60:
        return "menu_entering"
    return "interactive"


def sky_objects(frame: int) -> dict[str, object]:
    objects: dict[str, object] = {
        "clouds": [
            [
                28 + frame // 8,
                24 + (1 if 20 <= frame % 32 < 28 else 0),
            ],
            [
                168 + frame // 10,
                42 - (1 if 8 <= frame % 32 < 16 else 0),
            ],
        ],
    }
    if frame <= 23:
        progress = interval(frame, 0, 23)
        objects["sun"] = [
            round(278 + 52 * progress),
            round(44 + 29 * progress * progress),
        ]
    if frame >= 23:
        if frame < 38:
            progress = interval(frame, 23, 38)
            moon = [
                round(-8 + 66 * progress),
                round(70 - 18 * progress),
            ]
        elif frame < 56:
            progress = interval(frame, 38, 55)
            moon = [
                round(58 + 24 * progress),
                round(52 - 6 * progress),
            ]
        else:
            progress = interval(frame, 56, 63)
            moon = [
                round(82 + 28 * progress),
                round(46 + 18 * progress),
            ]
        objects["moon"] = moon
    return objects


def make_frame_contract(frame: int) -> dict[str, object]:
    center = truck_center_for_frame(frame)
    main_progress = interval(frame, 18, 40)
    small_progress = [
        interval(frame, 22, 34),
        interval(frame, 28, 40),
        interval(frame, 34, 46),
    ]
    return {
        "frame": frame,
        "time_seconds": round(frame / FPS, 3),
        "01_sky": {
            "palette_state": sky_palette_state(frame),
            "objects": sky_objects(frame),
        },
        "02_terrain": {
            "palette_state": terrain_palette_state(frame),
            "road_geometry": "locked",
        },
        "03_main_building": {
            "build_progress": round(main_progress, 4),
            "active_windows": sorted(main_window_activity(frame)),
            "footprint": "locked",
        },
        "04_small_buildings": {
            "build_progress": [round(value, 4) for value in small_progress],
            "footprints": "locked",
        },
        "05_vehicle_cargo": {
            "truck_phase": truck_phase(frame),
            "truck_center": (
                [round(center[0], 3), round(center[1], 3)]
                if center is not None
                else None
            ),
            "truck_scale": round(truck_scale(center), 4) if center is not None else None,
            "cargo_phase": cargo_phase(frame),
            "cargo_anchor": [160, 99],
            "cargo_visibility": round(cargo_visibility_for_frame(frame), 4),
        },
        "06_roadside_props": {
            "night_factor": round(night_factor(frame), 4),
            "grass_sway_phase_radians": round(2.0 * math.pi * frame / 16.0, 4),
            "anchors": "locked",
        },
        "godot_ui": {
            "phase": ui_phase(frame),
            "image_layer": False,
        },
    }


def percent(value: float) -> str:
    return f"{round(value * 100):d}%"


def write_spec(repo_root: Path, contracts: list[dict[str, object]]) -> Path:
    rows: list[str] = []
    for contract in contracts:
        frame = int(contract["frame"])
        sky = contract["01_sky"]
        terrain = contract["02_terrain"]
        main = contract["03_main_building"]
        small = contract["04_small_buildings"]
        vehicle = contract["05_vehicle_cargo"]
        props = contract["06_roadside_props"]
        ui = contract["godot_ui"]
        center = vehicle["truck_center"]
        truck = "—"
        if center is not None:
            truck = (
                f"{vehicle['truck_phase']} "
                f"({center[0]:.1f},{center[1]:.1f}) "
                f"s={vehicle['truck_scale']:.3f}"
            )
        small_values = "/".join(percent(value) for value in small["build_progress"])
        windows = ",".join(str(value) for value in main["active_windows"]) or "—"
        rows.append(
            "| {frame:02d} | {time:.3f} | {sky} | {terrain} | {main} / {windows} | "
            "{small} | {truck} | {cargo} {cargo_visibility} | {night} | {ui} |".format(
                frame=frame,
                time=float(contract["time_seconds"]),
                sky=sky["palette_state"],
                terrain=terrain["palette_state"],
                main=percent(main["build_progress"]),
                windows=windows,
                small=small_values,
                truck=truck,
                cargo=vehicle["cargo_phase"],
                cargo_visibility=percent(vehicle["cargo_visibility"]),
                night=percent(props["night_factor"]),
                ui=ui["phase"],
            )
        )

    lines = [
        "# Metabolis Opening Animation Specification",
        "",
        "This is the normative handoff for editing the title animation in another",
        "Codex task, Godot session, or art workflow. `MUST` rules are compatibility",
        "requirements; changing a `LOCKED` value requires updating this document,",
        "`art/animations/title_layers/manifest.json`, and the QA report together.",
        "",
        "## Source of truth",
        "",
        "- Human-readable contract: this file.",
        "- Machine-readable per-frame contract and SHA-256 hashes:",
        "  `art/animations/title_layers/manifest.json`.",
        "- Deterministic generator: `tools/build_title_layer_animation.py`.",
        "- PixelLab-approved keyframes: `art/previews/title_layers_static/`.",
        "- Godot playback: `src/ui/title_intro.gd` and `src/ui/title.tscn`.",
        "- QA: `docs/assets/TITLE_LAYER_ANIMATION_QA.json`.",
        "",
        "Rebuild command:",
        "",
        "```bash",
        "python tools/build_title_layer_animation.py \\",
        "  --repo-root . \\",
        "  --preview-root art/previews/title_layers_animation",
        "```",
        "",
        "## Global contract",
        "",
        "| Property | Required value |",
        "|---|---|",
        "| Canvas | `320 × 180` pixels |",
        "| Duration | `8.000 s` |",
        "| Frame rate | `8 FPS` |",
        "| Frames per layer | `64`, numbered `000–063` |",
        "| File pattern | `frame_%03d.png` |",
        "| Color | Only the 22 colors in `art/palette.gpl` |",
        "| Alpha | Binary only: `0` or `255` |",
        "| Sampling | Nearest-neighbor; integer source coordinates |",
        "| Vanishing point | `(1088/3, 220/3) = (362.6667, 73.3333)` |",
        "| Road upper edge | `(0,130) → (320,80)` |",
        "| Road lower edge | `(160,200) → (320,100)` |",
        "| Embedded text | Forbidden; title and menu are native Godot UI |",
        "",
        "Layer order is back-to-front and MUST remain:",
        "",
        "1. `01_sky` — opaque full-canvas sky and celestial objects.",
        "2. `02_terrain` — road and surrounding ground; geometry is locked.",
        "3. `03_main_building` — main perspective building, no road intersection.",
        "4. `04_small_buildings` — exactly three perspective buildings.",
        "5. `05_vehicle_cargo` — transient truck and delivered cargo.",
        "6. `06_roadside_props` — lamps and grass anchored to road edges.",
        "",
        "## Locked geometry",
        "",
        "- Main-building projection quad: `(40,45)`, `(150,54.6591)`,",
        "  `(150,98.8182)`, `(40,112)`.",
        "- Small-building projection quad: `(180,69)`, `(260,70.8978)`,",
        "  `(260,87.1971)`, `(180,98)`.",
        "- Main building minimum road clearance: `> 0 px`; current QA minimum",
        "  is `9.438 px`.",
        "- Small buildings minimum road clearance: `> 0 px`; current QA minimum",
        "  is `2.625 px`.",
        "- Cargo anchor: `(160,99)`.",
        "- Truck arrival Bézier: `(-15,171) → control (58,163) → (145,121)`.",
        "- Truck departure Bézier: `(145,121) → control (232,108) → (338,80)`.",
        "- Truck scale:",
        "  `0.65 + 0.35 × clamp(distance_to_VP / stop_distance, 0.15, 1.8)`.",
        "",
        "## Layer-specific editing rules",
        "",
        "### 01_sky",
        "",
        "- MUST be opaque in every frame.",
        "- Cloud silhouettes remain consistent; only integer drift is allowed.",
        "- Do not introduce horizontal bands or full-screen ordered dithering.",
        "- Sun, moon, and stars remain small secondary elements.",
        "",
        "### 02_terrain",
        "",
        "- Road edges and center dashes MUST not move between frames.",
        "- Day/night changes are palette swaps, not geometry changes.",
        "- The off-canvas vanishing point MUST remain shared with all buildings.",
        "",
        "### 03_main_building",
        "",
        "- Footprint and perspective quad are locked for all 64 frames.",
        "- Construction reveals bottom-to-top during frames `18–40`.",
        "- Window indices are `0=upper-left`, `1=upper-right`,",
        "  `2=lower-right`, `3=lower-left`.",
        "- Frames `44–55` create the four-chamber heartbeat metaphor.",
        "",
        "### 04_small_buildings",
        "",
        "- Exactly three buildings; their footprints and perspective are locked.",
        "- Build intervals: A `22–34`, B `28–40`, C `34–46`.",
        "- The three bases may differ in height but MUST remain above the road.",
        "",
        "### 05_vehicle_cargo",
        "",
        "- Truck faces and travels toward the upper-right vanishing direction.",
        "- Arrival `0–13`; unload stop `14–22`; departure `23–38`; absent `39–63`.",
        "- Cargo appears `12–16`, stays through `28`, fades `29–43`, then is absent.",
        "- Truck and cargo are allowed to be fully transparent when absent.",
        "",
        "### 06_roadside_props",
        "",
        "- Lamp and grass bottom anchors are locked to the two road edges.",
        "- Grass sway changes pixels above each anchor; anchors do not move.",
        "- Lamps are off by day, on at night, and dim during dawn.",
        "",
        "## Godot title and menu contract",
        "",
        "The title and menu are not image layers. Godot draws them from native",
        "`Label`, `Button`, `StyleBoxFlat`, and font resources.",
        "",
        "- Title begins at frame `42` (`5.250 s`).",
        "- Subtitle begins at frame `46` (`5.750 s`).",
        "- Menu begins at frame `52` (`6.500 s`).",
        "- Menu becomes interactive at frame `60` (`7.500 s`).",
        "- Accept, cancel, or select input may skip to frame `63`.",
        "",
        "## Per-frame contract",
        "",
        "`Main` is build progress followed by active window indices. `Small` lists",
        "A/B/C build progress. Truck coordinates are sprite centers. `Cargo` and",
        "`Night` are visibility/intensity. Exact cloud, sun, moon, grass phase,",
        "file paths, and SHA-256 values are stored in the machine-readable manifest.",
        "",
        "| F | Time | Sky | Terrain | Main / windows | Small A/B/C | Truck | Cargo | Night | UI |",
        "|---:|---:|---|---|---|---|---|---|---:|---|",
        *rows,
        "",
        "## Required validation after edits",
        "",
        "1. Run the rebuild command.",
        "2. Confirm QA status is `PASS` and total PNG count is `384`.",
        "3. Confirm all images are RGBA `320×180`, palette-locked, binary-alpha.",
        "4. Confirm both building layers report `never_intersects_road: true`.",
        "5. Run:",
        "   `/opt/homebrew/bin/godot --headless --path src --editor --quit`.",
        "6. Run the gameplay entry regression test.",
        "7. Review the Godot recording at frames `0`, `32`, `42`, `46`, `52`,",
        "   `60`, and `63` before publishing.",
        "",
        "Do not hand-edit generated hashes. Rebuild them from the generator.",
    ]
    spec_path = repo_root / SPEC_PATH
    spec_path.parent.mkdir(parents=True, exist_ok=True)
    spec_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return spec_path


def build(repo_root: Path, preview_root: Path) -> dict[str, object]:
    static = repo_root / STATIC_ROOT
    output = repo_root / OUTPUT_ROOT
    palette = load_palette(repo_root / "art/palette.gpl")

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    layers = {
        "01_sky": [build_sky_frame(frame) for frame in range(FRAME_COUNT)],
        "02_terrain": build_terrain_frames(static),
        "03_main_building": build_main_frames(static),
        "04_small_buildings": build_small_frames(static),
        "05_vehicle_cargo": build_vehicle_frames(static),
        "06_roadside_props": build_prop_frames(static),
    }

    checks = {
        layer: validate_layer_frames(layer, frames, palette)
        for layer, frames in layers.items()
    }
    for layer, result in checks.items():
        required = [
            result["frame_count"] == FRAME_COUNT,
            result["all_320x180"],
            result["locked_palette"],
            result["binary_alpha"],
        ]
        if layer in {"03_main_building", "04_small_buildings"}:
            required.append(result["never_intersects_road"])
        if layer == "01_sky":
            required.append(result["all_frames_opaque"])
        if not all(required):
            raise RuntimeError(f"Validation failed for {layer}: {result}")

    files = {
        layer: save_frames(output, layer, frames, repo_root)
        for layer, frames in layers.items()
    }
    composites = composite_frames(layers)
    preview_root.mkdir(parents=True, exist_ok=True)
    preview_files = save_preview(composites, preview_root)
    preview = {
        name: portable_path(Path(path), repo_root)
        for name, path in preview_files.items()
    }
    frame_contract = [make_frame_contract(frame) for frame in range(FRAME_COUNT)]

    manifest = {
        "canvas": {"width": WIDTH, "height": HEIGHT},
        "fps": FPS,
        "duration_seconds": DURATION_SECONDS,
        "frame_count_per_layer": FRAME_COUNT,
        "file_pattern": "frame_%03d.png",
        "layer_order": LAYER_ORDER,
        "timeline": [
            {"frames": [0, 13], "event": "truck enters from lower-left and approaches main building"},
            {"frames": [12, 16], "event": "cargo appears at fixed unload anchor (160,99)"},
            {"frames": [16, 36], "event": "afternoon transitions through dusk to night"},
            {"frames": [18, 40], "event": "main building completes bottom-to-top"},
            {"frames": [22, 46], "event": "three small buildings complete sequentially"},
            {"frames": [23, 38], "event": "truck departs toward the off-canvas vanishing point"},
            {"frames": [29, 43], "event": "delivered cargo is consumed"},
            {"frames": [44, 55], "event": "four main-building windows perform chamber pulse sequence"},
            {"frames": [56, 63], "event": "dawn begins and roadside lamps turn down"},
        ],
        "truck_scale_formula": "scale = 0.65 + 0.35 * clamp(distance_to_vanishing_point / stop_distance, 0.15, 1.8)",
        "source_keyframes": STATIC_ROOT.as_posix(),
        "specification": SPEC_PATH.as_posix(),
        "frame_contract": frame_contract,
        "checks": checks,
        "files": files,
        "preview": preview,
    }
    manifest_path = output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    spec_path = write_spec(repo_root, frame_contract)

    report = {
        "status": "PASS",
        "total_png_frames": sum(len(records) for records in files.values()),
        "expected_png_frames": len(LAYER_ORDER) * FRAME_COUNT,
        "output": OUTPUT_ROOT.as_posix(),
        "manifest": manifest_path.relative_to(repo_root).as_posix(),
        "manifest_sha256": sha256(manifest_path),
        "specification": spec_path.relative_to(repo_root).as_posix(),
        "specification_sha256": sha256(spec_path),
        "checks": checks,
        "preview": preview,
    }
    report_path = repo_root / REPORT_PATH
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--preview-root",
        type=Path,
        default=Path("/private/tmp"),
    )
    args = parser.parse_args()
    report = build(args.repo_root.resolve(), args.preview_root.resolve())
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
