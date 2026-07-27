# Grid and Pixel Baseline

This document locks the grid, coordinates, footprints, spacing, and pixel rendering rules for the main game view. These values are the single baseline for implementation and art acceptance.

## Reference canvas and rendering

- The fixed reference canvas is `640 x 360` pixels.
- The internal canvas renders at `1x`. The default display uses an integer `2x` scale and a `1280 x 720` output window.
- Stretch mode is `canvas_items`, aspect mode is `keep`, and scale mode is `integer`.
- Texture filtering is `Nearest` and mipmaps are disabled. One native asset pixel maps to one pixel on the reference canvas.
- The map, organs, and UI use integer pixel coordinates. Half-pixel positions, non-integer node scales, and interpolated filtering are not allowed.

## Reserved top UI area

The fixed top UI area is `Rect2(0, 0, 640, 40)`, covering canvas rows `y = 0..39` with a height of `40` pixels. Its fixed vertical layout is:

| Content | Area | Height |
|---|---|---:|
| Resource status bar | `Rect2(0, 0, 640, 12)` | `12` pixels |
| Development timeline | `Rect2(0, 12, 640, 12)` | `12` pixels |
| Task panel | `Rect2(0, 24, 640, 16)` | `16` pixels |

The three areas total `12 + 12 + 16 = 40` pixels and remain visible together. No additional reserved height is needed and the playable region loses `0` rows.

## Map grid

- Each tile is a `16 x 16` pixel square.
- The playable region is `40` columns by `20` rows, for `800` tiles.
- Its fixed bounds are `Rect2(0, 40, 640, 320)`, or `x = 0..639` and `y = 40..359`.
- Grid coordinates are zero-based: `column = 0..39` and `row = 0..19`.

## Organ footprints and anchors

Buildable organs use only these two named fixed footprints:

| Footprint | Objects | Tile size | Reference pixel size | `2x` display size |
|---|---|---:|---:|---:|
| Standard building | Vascular hub, neural hub | `2 x 2` | `32 x 32` | `64 x 64` |
| Landmark organ | Placenta, heart, brain, paired lungs as one object | `3 x 3` | `48 x 48` | `96 x 96` |

The sprite anchor is the bottom-center point of the footprint rectangle. Grid coordinates always store the footprint's top-left tile, not the tile containing the anchor. Therefore, the local anchor is `(16, 32)` for a `2 x 2` sprite and `(24, 48)` for a `3 x 3` sprite.

Background organs that are not part of build decisions occupy no grid slots. The smallest standard building still contains `32 x 32` native pixels and appears as `64 x 64` screen pixels at the default scale. Each native pixel becomes `2 x 2` screen pixels, so outlines and internal identifying features remain legible. Landmark organs appear at `96 x 96` screen pixels and receive stronger visual prominence.

## Candidate slot spacing

For one build decision, the edges of any two candidate footprint rectangles must be separated by at least one complete tile: `16` reference pixels or `32` screen pixels at the default scale. This rule applies horizontally and vertically. Candidate highlights, selection frames, and organ sprites must not enter the empty spacing tile.

Validate four simultaneous candidate slots against the largest `3 x 3` footprint. Even when all four slots are arranged horizontally, three spacing tiles keep their footprints, highlights, and selection areas disjoint.

## World and grid coordinates

The world origin is the top-left reference-canvas point `(0, 0)`. For a grid top-left coordinate `(column, row)`, the world pixel coordinate `(world_x, world_y)` is:

```text
world_x = column * 16
world_y = 40 + row * 16
```

For a world point inside the playable region, the reverse conversion is:

```text
column = floor(world_x / 16)
row = floor((world_y - 40) / 16)
```

For an organ footprint of `width_tiles x height_tiles`, the bottom-center world anchor is:

```text
anchor_x = column * 16 + width_tiles * 8
anchor_y = 40 + (row + height_tiles) * 16
```

## Acceptance calculation 1: map and resolution

A `16` pixel tile produces a map width of `40 * 16 = 640` pixels and a map height of `20 * 16 = 320` pixels. The top UI height is `12 + 12 + 16 = 40` pixels. The full canvas is therefore `640 x (320 + 40) = 640 x 360`, exactly matching the reference resolution with `0` unused pixels on either axis. The default integer `2x` output is `1280 x 720`, so the complete map and top UI fit on one screen.

## Acceptance calculation 2: four candidate slots

Four maximum `3 x 3` footprints arranged horizontally with three one-tile gaps require `4 * 3 + 3 * 1 = 15` tiles, or `15 * 16 = 240` reference pixels. The playable width is `40 * 16 = 640` reference pixels, so `240 <= 640`. At integer `2x` scale, `480 <= 1280`; four simultaneous candidate slots do not overlap.
