#!/usr/bin/env python3
"""Build the 8-second, 8-FPS layered Metabolis title animation."""

from __future__ import annotations

import argparse
import hashlib
import io
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
    "05_vehicle_unloaded_cargo",
    "05_vehicle_truck",
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
TRUCK_GROUND_START = (0.0, 168.0)
TRUCK_GROUND_END = (319.0, 84.7)
TRUCK_REAR_WHEEL = (30.0, 43.0)
TRUCK_FRONT_WHEEL = (64.0, 37.0)
TRUCK_STOP_REAR_X = 82.0
TRUCK_STOP_SCALE = 0.9
TRUCK_MIN_SCALE = 0.35
TRUCK_MAX_SCALE = 1.15
CARGO_PLACEMENT_BBOX = (121, 99, 144, 110)
ROAD_DASH_START = (0.0, 172.0)
ROAD_DASH_END = (319.0, 85.21)
ROAD_DASH_LENGTH_X = 14
ROAD_DASH_PERIOD_X = 28
ROAD_UPPER_GROUND_START = (0.0, 92.0)
ROAD_UPPER_GROUND_END = (319.0, 75.58)

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


def road_dash_y(x: float) -> float:
    """Return the continuous center-dash guide at a source-image x coordinate."""
    progress = (x - ROAD_DASH_START[0]) / (
        ROAD_DASH_END[0] - ROAD_DASH_START[0]
    )
    return ROAD_DASH_START[1] + progress * (
        ROAD_DASH_END[1] - ROAD_DASH_START[1]
    )


def road_upper_ground_y(x: float) -> float:
    """Return the upper ground boundary at a source-image x coordinate."""
    progress = (x - ROAD_UPPER_GROUND_START[0]) / (
        ROAD_UPPER_GROUND_END[0] - ROAD_UPPER_GROUND_START[0]
    )
    return ROAD_UPPER_GROUND_START[1] + progress * (
        ROAD_UPPER_GROUND_END[1] - ROAD_UPPER_GROUND_START[1]
    )


def redraw_road_upper_ground(image: Image.Image) -> Image.Image:
    """Extend the upper roadside ground to its perspective-correct boundary."""
    result = image.convert("RGBA").copy()
    pixels = result.load()
    for x in range(WIDTH):
        top_y = round(road_upper_ground_y(x))
        road_y = round(road_upper_y(x))
        for y in range(top_y, road_y):
            pixels[x, y] = TISSUE
    return result


def redraw_road_center_dashes(image: Image.Image) -> Image.Image:
    """Replace the baked center dashes with one deterministic perspective line."""
    result = image.convert("RGBA").copy()
    pixels = result.load()

    # The terrain keyframe contains no cream-colored object other than the old
    # center dashes. Clear both its ordinary cream pixels and its single bright
    # highlight before drawing the new line, making repeated rebuilds idempotent.
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if pixels[x, y] in {CREAM, MINT_LIGHT}:
                pixels[x, y] = NEUTRAL_DARK

    for start_x in range(
        int(ROAD_DASH_START[0]),
        int(ROAD_DASH_END[0]) + 1,
        ROAD_DASH_PERIOD_X,
    ):
        end_x = min(start_x + ROAD_DASH_LENGTH_X, int(ROAD_DASH_END[0]))
        for x in range(start_x, end_x + 1):
            pixels[x, round(road_dash_y(x))] = CREAM
    return result


def build_terrain_frames(static: Path) -> list[Image.Image]:
    day = redraw_road_center_dashes(
        redraw_road_upper_ground(
            Image.open(static / "terrain_road_afternoon.png")
        )
    )
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


def normalize_pixel_asset(
    image: Image.Image,
    palette: set[tuple[int, int, int]],
) -> Image.Image:
    """Snap a PixelLab asset to the locked palette and binary transparency."""
    result = Image.new("RGBA", image.size, TRANSPARENT)
    nearest: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    normalized: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in flattened(image.convert("RGBA")):
        if alpha < 128:
            normalized.append(TRANSPARENT)
            continue
        source = (red, green, blue)
        target = nearest.get(source)
        if target is None:
            target = min(
                palette,
                key=lambda color: sum(
                    (source[channel] - color[channel]) ** 2
                    for channel in range(3)
                ),
            )
            nearest[source] = target
        normalized.append((*target, 255))
    result.putdata(normalized)
    return result


def truck_ground_y(x: float) -> float:
    progress = (x - TRUCK_GROUND_START[0]) / (
        TRUCK_GROUND_END[0] - TRUCK_GROUND_START[0]
    )
    return TRUCK_GROUND_START[1] + progress * (
        TRUCK_GROUND_END[1] - TRUCK_GROUND_START[1]
    )


def truck_rear_x_for_frame(frame: int) -> float | None:
    if frame <= 13:
        return -12.0 + (TRUCK_STOP_REAR_X + 12.0) * interval(frame, 0, 13)
    if frame <= 22:
        return TRUCK_STOP_REAR_X
    if frame <= 38:
        return TRUCK_STOP_REAR_X + (340.0 - TRUCK_STOP_REAR_X) * interval(
            frame,
            23,
            38,
        )
    return None


def truck_scale(rear_x: float) -> float:
    distance = VANISHING_POINT[0] - rear_x
    stop_distance = VANISHING_POINT[0] - TRUCK_STOP_REAR_X
    projected = TRUCK_STOP_SCALE * distance / stop_distance
    return max(TRUCK_MIN_SCALE, min(TRUCK_MAX_SCALE, projected))


def truck_unload_progress(frame: int) -> float:
    if frame < 12:
        return 0.0
    if frame <= 16:
        return interval(frame, 12, 16)
    return 1.0


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


def align_truck_wheels(
    image: Image.Image,
) -> tuple[Image.Image, tuple[float, float], tuple[float, float]]:
    """Shear the sprite so both visible wheel bottoms share the road guide."""
    source_slope = (
        (TRUCK_FRONT_WHEEL[1] - TRUCK_REAR_WHEEL[1])
        / (TRUCK_FRONT_WHEEL[0] - TRUCK_REAR_WHEEL[0])
    )
    guide_slope = (
        (TRUCK_GROUND_END[1] - TRUCK_GROUND_START[1])
        / (TRUCK_GROUND_END[0] - TRUCK_GROUND_START[0])
    )
    shear = guide_slope - source_slope
    margin = 4
    result = Image.new(
        "RGBA",
        (image.width, image.height + margin * 2),
        TRANSPARENT,
    )
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel[3] == 0:
                continue
            target_y = round(
                y + shear * (x - TRUCK_REAR_WHEEL[0])
            ) + margin
            if 0 <= target_y < result.height:
                result.putpixel((x, target_y), pixel)
    rear = (TRUCK_REAR_WHEEL[0], TRUCK_REAR_WHEEL[1] + margin)
    front = (
        TRUCK_FRONT_WHEEL[0],
        round(
            TRUCK_FRONT_WHEEL[1]
            + shear * (TRUCK_FRONT_WHEEL[0] - TRUCK_REAR_WHEEL[0])
        )
        + margin,
    )
    return result, rear, front


def paste_truck_on_guide(
    canvas: Image.Image,
    sprite: Image.Image,
    rear_anchor: tuple[float, float],
    front_anchor: tuple[float, float],
    rear_x: float,
    scale: float,
) -> None:
    width = max(1, round(sprite.width * scale))
    height = max(1, round(sprite.height * scale))
    resized = sprite.resize((width, height), Image.Resampling.NEAREST)
    local_rear = (
        round(rear_anchor[0] * scale),
        round(rear_anchor[1] * scale),
    )
    local_front = (
        round(front_anchor[0] * scale),
        round(front_anchor[1] * scale),
    )
    rear_screen = (
        round(rear_x),
        round(truck_ground_y(rear_x)),
    )
    front_screen_x = rear_screen[0] + local_front[0] - local_rear[0]
    desired_front_y = round(truck_ground_y(front_screen_x))
    current_front_y = rear_screen[1] + local_front[1] - local_rear[1]
    correction = desired_front_y - current_front_y
    if correction != 0 and local_front[0] != local_rear[0]:
        corrected = Image.new(
            "RGBA",
            (resized.width, resized.height + 6),
            TRANSPARENT,
        )
        for y in range(resized.height):
            for x in range(resized.width):
                pixel = resized.getpixel((x, y))
                if pixel[3] == 0:
                    continue
                offset = round(
                    correction
                    * (x - local_rear[0])
                    / (local_front[0] - local_rear[0])
                )
                corrected.putpixel((x, y + offset + 3), pixel)
        resized = corrected
        local_rear = (local_rear[0], local_rear[1] + 3)
    destination = (
        rear_screen[0] - local_rear[0],
        rear_screen[1] - local_rear[1],
    )
    canvas.alpha_composite(resized, destination)


def build_vehicle_frames(
    static: Path,
    palette: set[tuple[int, int, int]],
) -> list[Image.Image]:
    loaded_source = normalize_pixel_asset(
        Image.open(static / "vehicle_truck_loaded_pixellab.png"),
        palette,
    )
    empty_source = normalize_pixel_asset(
        Image.open(static / "vehicle_truck_empty_pixellab.png"),
        palette,
    )
    loaded, rear_anchor, front_anchor = align_truck_wheels(loaded_source)
    empty, empty_rear_anchor, empty_front_anchor = align_truck_wheels(empty_source)
    if (
        rear_anchor != empty_rear_anchor
        or front_anchor != empty_front_anchor
        or loaded.size != empty.size
    ):
        raise RuntimeError("Loaded and empty PixelLab truck variants are misaligned.")
    frames: list[Image.Image] = []
    for frame in range(FRAME_COUNT):
        image = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
        rear_x = truck_rear_x_for_frame(frame)
        if rear_x is not None:
            truck = ordered_blend(
                loaded,
                empty,
                truck_unload_progress(frame),
                phase=5,
            )
            paste_truck_on_guide(
                image,
                truck,
                rear_anchor,
                front_anchor,
                rear_x,
                truck_scale(rear_x),
            )
        frames.append(image)
    return frames


def build_unloaded_cargo_frames(
    static: Path,
    palette: set[tuple[int, int, int]],
) -> list[Image.Image]:
    cargo = normalize_pixel_asset(
        Image.open(static / "unloaded_cargo_option2_pixellab.png"),
        palette,
    )
    if cargo.getchannel("A").getbbox() != CARGO_PLACEMENT_BBOX:
        raise RuntimeError(
            "PixelLab cargo bbox changed: "
            f"{cargo.getchannel('A').getbbox()} != {CARGO_PLACEMENT_BBOX}."
        )
    transparent = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    return [
        ordered_blend(
            transparent,
            cargo,
            cargo_visibility_for_frame(frame),
            phase=3,
        )
        for frame in range(FRAME_COUNT)
    ]


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
    if layer == "02_terrain":
        endpoint_pixels = [
            frame.getpixel(
                (
                    round(point[0]),
                    round(point[1]),
                )
            )
            for frame in frames
            for point in (ROAD_DASH_START, ROAD_DASH_END)
        ]
        dash_pixels = [
            (x, y)
            for y in range(HEIGHT)
            for x in range(WIDTH)
            if frames[0].getpixel((x, y)) == CREAM
        ]
        maximum_deviation = max(
            (abs(y - road_dash_y(x)) for x, y in dash_pixels),
            default=float("inf"),
        )
        result["road_dash_guide"] = {
            "start": list(ROAD_DASH_START),
            "end": list(ROAD_DASH_END),
        }
        result["road_dash_endpoint_pixels_present"] = all(
            pixel == CREAM for pixel in endpoint_pixels
        )
        result["road_dash_maximum_raster_deviation_pixels"] = round(
            maximum_deviation,
            3,
        )
        result["road_dash_follows_guide"] = maximum_deviation <= 0.5
        upper_ground_pixels = [
            (
                x,
                min(
                    y
                    for y in range(HEIGHT)
                    if frames[0].getpixel((x, y))[3] == 255
                ),
            )
            for x in range(WIDTH)
        ]
        upper_ground_maximum_deviation = max(
            abs(y - road_upper_ground_y(x)) for x, y in upper_ground_pixels
        )
        result["road_upper_ground_guide"] = {
            "start": list(ROAD_UPPER_GROUND_START),
            "end": list(ROAD_UPPER_GROUND_END),
        }
        result["road_upper_ground_endpoint_pixels_present"] = all(
            frames[0].getpixel((round(x), round(y)))[3] == 255
            for x, y in (ROAD_UPPER_GROUND_START, ROAD_UPPER_GROUND_END)
        )
        result["road_upper_ground_maximum_raster_deviation_pixels"] = round(
            upper_ground_maximum_deviation,
            3,
        )
        result["road_upper_ground_follows_guide"] = (
            upper_ground_maximum_deviation <= 0.5
        )
    if layer == "05_vehicle_truck":
        deviations: list[float] = []
        scales: list[float] = []
        for frame in range(FRAME_COUNT):
            rear_x = truck_rear_x_for_frame(frame)
            if rear_x is None:
                continue
            scale = truck_scale(rear_x)
            rear_local = (
                round(TRUCK_REAR_WHEEL[0] * scale),
                round((TRUCK_REAR_WHEEL[1] + 4) * scale),
            )
            guide_slope = (
                (TRUCK_GROUND_END[1] - TRUCK_GROUND_START[1])
                / (TRUCK_GROUND_END[0] - TRUCK_GROUND_START[0])
            )
            source_slope = (
                (TRUCK_FRONT_WHEEL[1] - TRUCK_REAR_WHEEL[1])
                / (TRUCK_FRONT_WHEEL[0] - TRUCK_REAR_WHEEL[0])
            )
            aligned_front_y = (
                round(
                    TRUCK_FRONT_WHEEL[1]
                    + (guide_slope - source_slope)
                    * (TRUCK_FRONT_WHEEL[0] - TRUCK_REAR_WHEEL[0])
                )
                + 4
            )
            front_local = (
                round(TRUCK_FRONT_WHEEL[0] * scale),
                round(aligned_front_y * scale),
            )
            rear_screen = (
                round(rear_x),
                round(truck_ground_y(rear_x)),
            )
            front_screen = (
                rear_screen[0] + front_local[0] - rear_local[0],
                round(
                    truck_ground_y(
                        rear_screen[0] + front_local[0] - rear_local[0]
                    )
                ),
            )
            deviations.extend(
                [
                    abs(rear_screen[1] - truck_ground_y(rear_screen[0])),
                    abs(front_screen[1] - truck_ground_y(front_screen[0])),
                ]
            )
            scales.append(scale)
        result["truck_ground_guide"] = {
            "start": list(TRUCK_GROUND_START),
            "end": list(TRUCK_GROUND_END),
        }
        result["wheel_bottom_maximum_raster_deviation_pixels"] = round(
            max(deviations),
            3,
        )
        result["wheels_follow_ground_guide"] = max(deviations) <= 1.0
        result["minimum_scale"] = round(min(scales), 4)
        result["maximum_scale"] = round(max(scales), 4)
        result["maximum_scale_delta_per_frame"] = round(
            max(
                abs(scales[index] - scales[index - 1])
                for index in range(1, len(scales))
            ),
            4,
        )
    if layer == "05_vehicle_unloaded_cargo":
        delivered_bbox = frames[16].getchannel("A").getbbox()
        result["delivered_bbox"] = list(delivered_bbox) if delivered_bbox else None
        result["matches_locked_placement"] = delivered_bbox == CARGO_PLACEMENT_BBOX
    return result


def portable_path(path: Path, repo_root: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def pixel_digest(frame: Image.Image) -> str:
    """Content address a frame by its exact decoded pixels.

    Two frames that hash the same are byte-identical after decoding, so the
    playback side can point at one shared PNG instead of storing a copy.
    """
    header = f"{frame.mode}:{frame.width}x{frame.height}:".encode("utf-8")
    return hashlib.sha256(header + frame.tobytes()).hexdigest()


def save_frames(
    root: Path,
    layer: str,
    frames: list[Image.Image],
    repo_root: Path,
    existing_frame_bytes: dict[str, bytes],
) -> tuple[list[dict[str, object]], list[int]]:
    """Write only the distinct frames of one layer.

    Returns the on-disk records plus a 64-entry frame map. `frame_map[i]` is
    the frame number whose PNG must be shown at logical frame `i`; a frame is
    its own representative whenever it introduces new pixels. The map is
    therefore always non-decreasing-safe: `frame_map[i] <= i`.
    """
    directory = root / layer
    directory.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    representative_by_digest: dict[str, int] = {}
    record_by_representative: dict[int, dict[str, object]] = {}
    frame_map: list[int] = []
    for index, frame in enumerate(frames):
        digest = pixel_digest(frame)
        representative = representative_by_digest.get(digest)
        if representative is None:
            representative = index
            representative_by_digest[digest] = index
            path = directory / f"frame_{index:03d}.png"
            relative_key = f"{layer}/frame_{index:03d}.png"
            existing_bytes = existing_frame_bytes.get(relative_key)
            reused_existing = False
            if existing_bytes is not None:
                try:
                    existing_frame = Image.open(io.BytesIO(existing_bytes)).convert(
                        "RGBA"
                    )
                    reused_existing = (
                        existing_frame.size == frame.size
                        and existing_frame.tobytes() == frame.convert("RGBA").tobytes()
                    )
                except OSError:
                    reused_existing = False
            if reused_existing:
                path.write_bytes(existing_bytes)
            else:
                frame.save(path, optimize=True)
            record: dict[str, object] = {
                "path": portable_path(path, repo_root),
                "sha256": sha256(path),
                "frame": index,
                "used_by_frames": [],
            }
            records.append(record)
            record_by_representative[index] = record
        frame_map.append(representative)
        used_by = record_by_representative[representative]["used_by_frames"]
        assert isinstance(used_by, list)
        used_by.append(index)
    return records, frame_map


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
    if frame < 52:
        return "title_entering"
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
    rear_x = truck_rear_x_for_frame(frame)
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
        "05_vehicle_truck": {
            "truck_phase": truck_phase(frame),
            "rear_wheel": (
                [round(rear_x, 3), round(truck_ground_y(rear_x), 3)]
                if rear_x is not None
                else None
            ),
            "truck_scale": round(truck_scale(rear_x), 4) if rear_x is not None else None,
            "unload_progress": round(truck_unload_progress(frame), 4),
        },
        "05_vehicle_unloaded_cargo": {
            "cargo_phase": cargo_phase(frame),
            "cargo_bbox": list(CARGO_PLACEMENT_BBOX),
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


def write_spec(
    repo_root: Path,
    contracts: list[dict[str, object]],
    unique_frame_counts: dict[str, int],
) -> Path:
    total_unique = sum(unique_frame_counts.values())
    dedup_rows = [
        "| `{layer}` | `{unique}` | `{saved}` |".format(
            layer=layer,
            unique=unique_frame_counts[layer],
            saved=FRAME_COUNT - unique_frame_counts[layer],
        )
        for layer in LAYER_ORDER
    ]
    rows: list[str] = []
    for contract in contracts:
        frame = int(contract["frame"])
        sky = contract["01_sky"]
        terrain = contract["02_terrain"]
        main = contract["03_main_building"]
        small = contract["04_small_buildings"]
        vehicle = contract["05_vehicle_truck"]
        cargo = contract["05_vehicle_unloaded_cargo"]
        props = contract["06_roadside_props"]
        ui = contract["godot_ui"]
        rear_wheel = vehicle["rear_wheel"]
        truck = "—"
        if rear_wheel is not None:
            truck = (
                f"{vehicle['truck_phase']} "
                f"({rear_wheel[0]:.1f},{rear_wheel[1]:.1f}) "
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
                cargo=cargo["cargo_phase"],
                cargo_visibility=percent(cargo["cargo_visibility"]),
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
        "- Machine-readable per-frame contract, frame maps, and SHA-256 hashes:",
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
        "| Frames per layer | `64` logical frames, numbered `000–063` |",
        "| File pattern | `frame_%03d.png`, sparse — duplicates are not written |",
        f"| PNG files on disk | `{total_unique}` total across the seven layers |",
        "| Frame resolution | `frame_maps` in the manifest, see below |",
        "| Color | Only the 22 colors in `art/palette.gpl` |",
        "| Alpha | Binary only: `0` or `255` |",
        "| Sampling | Nearest-neighbor; integer source coordinates |",
        "| Vanishing point | `(1088/3, 220/3) = (362.6667, 73.3333)` |",
        "| Upper roadside ground edge | `(0,92) → (319,75.58)` |",
        "| Road upper edge | `(0,130) → (320,80)` |",
        "| Road lower edge | `(160,200) → (320,100)` |",
        "| Road center-dash guide | `(0,172) → (319,85.21)` |",
        "| Truck wheel-bottom guide | `(0,168) → (319,84.7)` |",
        "| Embedded text | Forbidden; title and menu are native Godot UI |",
        "",
        "Layer order is back-to-front and MUST remain:",
        "",
        "1. `01_sky` — opaque full-canvas sky and celestial objects.",
        "2. `02_terrain` — road and surrounding ground; geometry is locked.",
        "3. `03_main_building` — main perspective building, no road intersection.",
        "4. `04_small_buildings` — exactly three perspective buildings.",
        "5. `05_vehicle_unloaded_cargo` — independently timed delivered cargo.",
        "6. `05_vehicle_truck` — PixelLab loaded/empty truck animation.",
        "7. `06_roadside_props` — lamps and grass anchored to road edges.",
        "",
        "## Frame deduplication",
        "",
        "Every layer still has `64` logical frames, but identical frames share a",
        "single PNG. A layer directory is therefore sparse: a file exists only for",
        "the first frame that introduces new pixels.",
        "",
        "`manifest.json` carries the resolution table:",
        "",
        "```json",
        '"frame_maps": { "02_terrain": [0, 0, 0, ..., 24, 24, ...] }',
        "```",
        "",
        "- `frame_maps[layer][i]` is the frame number whose PNG renders logical",
        "  frame `i`.",
        "- `frame_maps[layer][i] <= i` MUST always hold; a map that points forward",
        "  is a build error.",
        "- Consumers MUST resolve through `frame_maps` and MUST NOT assume that",
        "  `frame_%03d.png` exists for every `i`.",
        "- Consumers SHOULD upload each distinct PNG to the GPU once and reuse the",
        "  texture handle for every logical frame that maps to it.",
        "- `src/ui/title_intro.gd` falls back to the identity map when the manifest",
        "  is missing or malformed, so a fully populated directory still plays.",
        "",
        "| Layer | Distinct PNGs | Duplicates removed |",
        "|---|---:|---:|",
        *dedup_rows,
        f"| **total** | **{total_unique}** | **{len(LAYER_ORDER) * FRAME_COUNT - total_unique}** |",
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
        "- Delivered-cargo bounding box: `(121,99) → (144,110)`.",
        "- Truck rear-wheel arrival: `x=-12 → 82`, frames `0–13`.",
        "- Truck rear-wheel departure: `x=82 → 340`, frames `23–38`.",
        "- Both visible wheel bottoms follow `(0,168) → (319,84.7)`.",
        "- Truck scale:",
        "  `clamp(0.35, 1.15, 0.9 × (VP.x - rear_x) / (VP.x - 82))`.",
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
        "- The upper roadside ground edge MUST pass through source coordinates",
        "  `(0,92)` and `(319,75.58)`; rasterized edge pixels may differ by at",
        "  most `0.5 px` vertically.",
        "- The continuous center-dash guide MUST pass through source coordinates",
        "  `(0,172)` and `(319,85.21)`; rasterized dash pixels may differ by at",
        "  most `0.5 px` vertically.",
        "- Exactly four distinct terrain PNGs are stored; the 64 logical frames",
        "  resolve to them through `manifest.json`'s `frame_maps`.",
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
        "### 05_vehicle_truck",
        "",
        "- Truck faces and travels toward the upper-right vanishing direction.",
        "- Arrival `0–13`; unload stop `14–22`; departure `23–38`; absent `39–63`.",
        "- The loaded and empty source sprites are PixelLab assets snapped to the",
        "  locked 22-color palette before frame generation.",
        "- The two visible wheel bottoms MUST stay within `1 px` of the locked",
        "  wheel-bottom guide in every visible frame.",
        "- Loaded-to-empty transition runs during frames `12–16`.",
        "- Truck is allowed to be fully transparent when absent.",
        "",
        "### 05_vehicle_unloaded_cargo",
        "",
        "- Cargo appears `12–16`, stays through `28`, fades `29–43`, then is absent.",
        "- Delivered pixels MUST remain inside `(121,99) → (144,110)`.",
        "- The two boxes use option 2 and preserve their shared vanishing point.",
        "- Cargo is allowed to be fully transparent when absent.",
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
        "- Only the native `Metabolis` title is shown; there is no subtitle.",
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
        f"2. Confirm QA status is `PASS` and total PNG count is `{total_unique}`,",
        f"   with `logical_frame_count` still `{len(LAYER_ORDER) * FRAME_COUNT}`.",
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


def load_published_layer_frames(
    output: Path,
    layer: str,
) -> list[Image.Image] | None:
    """Reuse a published sparse layer when the current task does not own it."""
    manifest_path = output / "manifest.json"
    if not manifest_path.is_file():
        return None
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        frame_map = manifest["frame_maps"][layer]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None
    if not isinstance(frame_map, list) or len(frame_map) != FRAME_COUNT:
        return None
    frames: list[Image.Image] = []
    for source_index in frame_map:
        if not isinstance(source_index, int):
            return None
        path = output / layer / f"frame_{source_index:03d}.png"
        if not path.is_file():
            return None
        frame = Image.open(path).convert("RGBA")
        if frame.size != (WIDTH, HEIGHT):
            return None
        frames.append(frame.copy())
    return frames


def build(repo_root: Path, preview_root: Path) -> dict[str, object]:
    static = repo_root / STATIC_ROOT
    output = repo_root / OUTPUT_ROOT
    palette = load_palette(repo_root / "art/palette.gpl")
    existing_frame_bytes = {
        path.relative_to(output).as_posix(): path.read_bytes()
        for path in output.glob("*/frame_*.png")
    }
    published_main = load_published_layer_frames(output, "03_main_building")
    published_small = load_published_layer_frames(output, "04_small_buildings")

    layers = {
        "01_sky": [build_sky_frame(frame) for frame in range(FRAME_COUNT)],
        "02_terrain": build_terrain_frames(static),
        "03_main_building": (
            published_main if published_main is not None else build_main_frames(static)
        ),
        "04_small_buildings": (
            published_small if published_small is not None else build_small_frames(static)
        ),
        "05_vehicle_truck": build_vehicle_frames(static, palette),
        "05_vehicle_unloaded_cargo": build_unloaded_cargo_frames(static, palette),
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
        if layer == "02_terrain":
            required.extend(
                [
                    result["road_dash_endpoint_pixels_present"],
                    result["road_dash_follows_guide"],
                    result["road_upper_ground_endpoint_pixels_present"],
                    result["road_upper_ground_follows_guide"],
                ]
            )
        if layer == "05_vehicle_truck":
            required.append(result["wheels_follow_ground_guide"])
        if layer == "05_vehicle_unloaded_cargo":
            required.append(result["matches_locked_placement"])
        if not all(required):
            raise RuntimeError(f"Validation failed for {layer}: {result}")

    # Keep the last known-good animation intact until every logical frame has
    # passed validation. Only then replace the sparse output tree, which also
    # removes representatives that became redundant after an edit.
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    saved = {
        layer: save_frames(
            output,
            layer,
            frames,
            repo_root,
            existing_frame_bytes,
        )
        for layer, frames in layers.items()
    }
    files = {layer: records for layer, (records, _) in saved.items()}
    frame_maps = {layer: frame_map for layer, (_, frame_map) in saved.items()}
    unique_frame_counts = {layer: len(records) for layer, records in files.items()}
    if unique_frame_counts["02_terrain"] != 4:
        raise RuntimeError(
            "02_terrain must resolve to exactly four distinct static images, "
            f"found {unique_frame_counts['02_terrain']}."
        )
    if unique_frame_counts["05_vehicle_truck"] > 32:
        raise RuntimeError(
            "05_vehicle_truck exceeds its 32-PNG sparse-frame budget: "
            f"{unique_frame_counts['05_vehicle_truck']}."
        )
    if unique_frame_counts["05_vehicle_unloaded_cargo"] > 17:
        raise RuntimeError(
            "05_vehicle_unloaded_cargo exceeds its 17-PNG sparse-frame budget: "
            f"{unique_frame_counts['05_vehicle_unloaded_cargo']}."
        )
    for layer, frame_map in frame_maps.items():
        if len(frame_map) != FRAME_COUNT:
            raise RuntimeError(f"Frame map for {layer} is not {FRAME_COUNT} entries.")
        if any(source > index for index, source in enumerate(frame_map)):
            raise RuntimeError(f"Frame map for {layer} points forward in time.")
        available = {record["frame"] for record in files[layer]}
        if not set(frame_map).issubset(available):
            raise RuntimeError(f"Frame map for {layer} references a missing PNG.")
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
        "deduplicated": True,
        "frame_map_contract": (
            "frame_maps[layer][i] is the frame number whose PNG must be shown at "
            "logical frame i. Identical frames share one file, so a layer "
            "directory is sparse and frame_maps[layer][i] <= i always holds."
        ),
        "frame_maps": frame_maps,
        "unique_frame_counts": unique_frame_counts,
        "road_center_dash_guide": {
            "start": list(ROAD_DASH_START),
            "end": list(ROAD_DASH_END),
            "equation": "y = 172 + (85.21 - 172) * x / 319",
        },
        "road_upper_ground_guide": {
            "start": list(ROAD_UPPER_GROUND_START),
            "end": list(ROAD_UPPER_GROUND_END),
            "equation": "y = 92 + (75.58 - 92) * x / 319",
        },
        "truck_wheel_bottom_guide": {
            "start": list(TRUCK_GROUND_START),
            "end": list(TRUCK_GROUND_END),
            "equation": "y = 168 + (84.7 - 168) * x / 319",
        },
        "layer_order": LAYER_ORDER,
        "timeline": [
            {"frames": [0, 13], "event": "truck enters from lower-left and approaches main building"},
            {"frames": [12, 16], "event": "option-2 cargo appears at bbox (121,99)-(144,110)"},
            {"frames": [16, 36], "event": "afternoon transitions through dusk to night"},
            {"frames": [18, 40], "event": "main building completes bottom-to-top"},
            {"frames": [22, 46], "event": "three small buildings complete sequentially"},
            {"frames": [23, 38], "event": "truck departs toward the off-canvas vanishing point"},
            {"frames": [29, 43], "event": "delivered cargo is consumed"},
            {"frames": [44, 55], "event": "four main-building windows perform chamber pulse sequence"},
            {"frames": [56, 63], "event": "dawn begins and roadside lamps turn down"},
        ],
        "truck_scale_formula": "scale = clamp(0.35, 1.15, 0.9 * (VP.x - rear_x) / (VP.x - 82))",
        "source_keyframes": STATIC_ROOT.as_posix(),
        "specification": SPEC_PATH.as_posix(),
        "frame_contract": frame_contract,
        "checks": checks,
        "files": files,
        "preview": preview,
    }
    manifest_path = output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    spec_path = write_spec(repo_root, frame_contract, unique_frame_counts)

    total_png_frames = sum(len(records) for records in files.values())
    logical_frames = len(LAYER_ORDER) * FRAME_COUNT
    report = {
        "status": "PASS",
        "total_png_frames": total_png_frames,
        "expected_png_frames": sum(unique_frame_counts.values()),
        "logical_frame_count": logical_frames,
        "unique_frame_counts": unique_frame_counts,
        "duplicate_frames_removed": logical_frames - total_png_frames,
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
