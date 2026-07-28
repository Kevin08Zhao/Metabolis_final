# Metabolis: City of Life — Birth Pixel Asset Technical Specification

## 1. Size Specification

`T` is the tile edge locked by `GRID_BASELINE.md`: `T = 16` native pixels. This file must not define a second baseline. If violated, map and UI assets use different grid units and their edges do not align.

Every width and height includes transparent canvas area and is an integer multiple of `T`. If violated, Godot placement produces half-tile offsets, clipping, or seams.

| Asset category | Native canvas and derivation | Visible failure if violated |
|---|---|---|
| Terrain tile | `1T × 1T = 16 × 16 px` | Terrain tiling leaves gaps, overlap, or grid offsets. |
| Transport-network tile | `1T × 1T = 16 × 16 px` | Straight, corner, and crossing endpoints do not meet at tile edges. |
| Vascular or neural standard building | `2T × 2T = 32 × 32 px`, matching the standard-building footprint | The building occupies the wrong map cells and its collision area disagrees with the image. |
| Placenta landmark | `3T × 3T = 48 × 48 px`, matching the landmark footprint | Radial routes cannot connect to the locked landmark anchor. |
| Heart landmark | `3T × 3T = 48 × 48 px`, matching the landmark footprint | Pump interfaces land off grid or the heart has the wrong prominence. |
| Brain landmark | `3T × 3T = 48 × 48 px`, matching the landmark footprint | Neural routes connect outside the locked footprint. |
| Paired-lungs landmark | `3T × 3T = 48 × 48 px`, treating both lungs as one object | The pair is split across incompatible anchors or exceeds its build slot. |
| Organ construction zone | Add `1T` around the target footprint: standard `4T × 4T = 64 × 64 px`; landmark `5T × 5T = 80 × 80 px` | The construction indication cannot surround the footprint or jumps when replaced by the finished organ. |
| Candidate-slot marker | One marker is `1T × 1T = 16 × 16 px`; four markers occupy distinct anchor cells. Four maximum footprints plus three required gaps span `4 × 3T + 3 × 1T = 15T = 240 px`, within the `40T = 640 px` playfield | Four slots overlap, obscure one another, or cannot be selected separately. |
| Candidate-option card | `6T × 3T = 96 × 48 px` | Icons, state area, and margins do not share a grid. |
| UI icon | `1T × 1T = 16 × 16 px` | Icons vary in size or jump between baselines in the same control. |
| Six resource icons | Each is `1T × 1T = 16 × 16 px`; all six share the same canvas | Switching resources makes the icon frame jump and breaks quantity-row alignment. |

## 2. Anchor Rules

Anchor coordinates are measured from canvas top-left `(0,0)` and use integer native pixels only. If violated, camera motion or animation produces subpixel jitter.

| Asset category | Anchor | Visible failure if violated |
|---|---|---|
| Terrain and transport-network tiles | Top-left `(0,0)` | The tile shifts relative to its map cell and cannot join neighboring edges. |
| Standard building | Footprint bottom center `(16,32)` | Replacement, upgrade, or mirroring moves the base. |
| Placenta, heart, brain, and paired lungs | Footprint bottom center `(24,48)` | A landmark moves between construction and completion or connects off grid. |
| Organ construction zone | Same bottom-center world anchor as its target organ | The zone and finished organ cannot replace one another in place. |
| Candidate-slot marker | Canvas center `(8,8)` placed on the candidate anchor cell | The marker misses the candidate center and four-slot spacing becomes inconsistent. |
| Candidate-option card | Top-left `(0,0)` | Cards misalign in lists or jump while scrolling. |
| UI and resource icons | Canvas center `(8,8)` | Icons lean to one side inside buttons, counters, or prompts. |
| Animated asset | Every frame reuses its category’s anchor | The subject drifts even when all frame canvases have identical dimensions. |

Transparent padding is part of the anchor definition and must not be trimmed during export. If violated, poses and resource icons shift when switched.

## 3. Export Format

| Rule | Visible failure if violated |
|---|---|
| Deliver PNG with an alpha channel only. | Other formats introduce compression noise, lose transparency, or import differently in Godot. |
| Export at the native canvas dimensions in this file; never pre-scale. | Pixel blocks differ in size and remain blurred or misaligned after integer runtime scaling. |
| Keep the canvas background transparent; never fill transparent pixels with white, black, or a palette background color. | A rectangle appears around the asset and hides tiles behind it. |
| Disable anti-aliasing, edge feathering, semi-transparent outlines, and resampling. | Blended edge pixels create dirty borders under nearest-neighbor scaling. |
| Preserve transparent padding and canvas bounds; never auto-trim. | Anchors and collision footprints shift relative to the image, causing animation jitter. |
| Every visible pixel comes from the locked palette; alpha is either fully transparent or fully opaque. | The viewer reveals unauthorized colors or semi-transparent fringes. |

## 4. Sprite-Sheet Frame Layout

| Rule | Visible failure if violated |
|---|---|
| Each sprite sheet has one row; frames run left to right in time order. | Grid slicing yields the wrong order or mixes another animation. |
| Adjacent frames have `0` native pixels of padding; do not add separators, outer borders, or extrusion. | Automatic slicing treats empty columns or borders as image content. |
| Every frame in one sheet has identical `FW × FH` dimensions. | Frame boundaries cut into adjacent images, truncating or mixing subjects. |
| A sheet with `N` frames has total dimensions `(N × FW) × FH`. | Total width is not divisible by frame count and Godot cannot slice equal frames. |
| Every frame uses the same anchor and transparent canvas; never trim individual frames. | The subject drifts horizontally or vertically during playback. |
| Do not duplicate a static image to disguise it as a multi-frame sheet. | File size grows and creates a meaningless animation state. |

### Pre-Delivery Checklist

- [ ] File Manager shows that every delivered image is PNG.
- [ ] Image dimensions match a formula derived from `T = 16 px`.
- [ ] A transparency checkerboard shows no solid background or translucent fringe.
- [ ] At 100% zoom, pixel edges are sharp and have no anti-aliasing.
- [ ] Each candidate-slot marker is `16 × 16 px`, and four can occupy separate cells around non-overlapping candidate footprints.
- [ ] Every sprite sheet has one row, zero frame padding, and a width divisible by frame width.
- [ ] Every frame has the same canvas dimensions and subject-anchor position.
