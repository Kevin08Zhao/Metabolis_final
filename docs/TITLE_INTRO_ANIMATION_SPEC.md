# Metabolis Opening Animation Specification

This is the normative handoff for editing the title animation in another
Codex task, Godot session, or art workflow. `MUST` rules are compatibility
requirements; changing a `LOCKED` value requires updating this document,
`art/animations/title_layers/manifest.json`, and the QA report together.

## Source of truth

- Human-readable contract: this file.
- Machine-readable per-frame contract, frame maps, and SHA-256 hashes:
  `art/animations/title_layers/manifest.json`.
- Deterministic generator: `tools/build_title_layer_animation.py`.
- PixelLab-approved keyframes: `art/previews/title_layers_static/`.
- Godot playback: `src/ui/title_intro.gd` and `src/ui/title.tscn`.
- QA: `docs/assets/TITLE_LAYER_ANIMATION_QA.json`.

Rebuild command:

```bash
python tools/build_title_layer_animation.py \
  --repo-root . \
  --preview-root art/previews/title_layers_animation
```

## Global contract

| Property | Required value |
|---|---|
| Canvas | `320 × 180` pixels |
| Duration | `8.000 s` |
| Frame rate | `8 FPS` |
| Frames per layer | `64` logical frames, numbered `000–063` |
| File pattern | `frame_%03d.png`, sparse — duplicates are not written |
| PNG files on disk | `199` total across the seven layers |
| Frame resolution | `frame_maps` in the manifest, see below |
| Color | Only the 22 colors in `art/palette.gpl` |
| Alpha | Binary only: `0` or `255` |
| Sampling | Nearest-neighbor; integer source coordinates |
| Vanishing point | `(1088/3, 220/3) = (362.6667, 73.3333)` |
| Upper roadside ground edge | `(0,92) → (319,75.58)` |
| Road upper edge | `(0,130) → (320,80)` |
| Road lower edge | `(160,200) → (320,100)` |
| Road center-dash guide | `(0,172) → (319,85.21)` |
| Truck wheel-bottom guide | `(0,168) → (319,84.7)` |
| Embedded text | Forbidden; title and menu are native Godot UI |

Layer order is back-to-front and MUST remain:

1. `01_sky` — opaque full-canvas sky and celestial objects.
2. `02_terrain` — road and surrounding ground; geometry is locked.
3. `03_main_building` — main perspective building, no road intersection.
4. `04_small_buildings` — exactly three perspective buildings.
5. `05_vehicle_unloaded_cargo` — independently timed delivered cargo.
6. `05_vehicle_truck` — PixelLab loaded/empty truck animation.
7. `06_roadside_props` — lamps and grass anchored to road edges.

## Frame deduplication

Every layer still has `64` logical frames, but identical frames share a
single PNG. A layer directory is therefore sparse: a file exists only for
the first frame that introduces new pixels.

`manifest.json` carries the resolution table:

```json
"frame_maps": { "02_terrain": [0, 0, 0, ..., 24, 24, ...] }
```

- `frame_maps[layer][i]` is the frame number whose PNG renders logical
  frame `i`.
- `frame_maps[layer][i] <= i` MUST always hold; a map that points forward
  is a build error.
- Consumers MUST resolve through `frame_maps` and MUST NOT assume that
  `frame_%03d.png` exists for every `i`.
- Consumers SHOULD upload each distinct PNG to the GPU once and reuse the
  texture handle for every logical frame that maps to it.
- `src/ui/title_intro.gd` falls back to the identity map when the manifest
  is missing or malformed, so a fully populated directory still plays.

| Layer | Distinct PNGs | Duplicates removed |
|---|---:|---:|
| `01_sky` | `61` | `3` |
| `02_terrain` | `4` | `60` |
| `03_main_building` | `21` | `43` |
| `04_small_buildings` | `9` | `55` |
| `05_vehicle_unloaded_cargo` | `17` | `47` |
| `05_vehicle_truck` | `31` | `33` |
| `06_roadside_props` | `56` | `8` |
| **total** | **199** | **249** |

## Locked geometry

- Main-building projection quad: `(40,45)`, `(150,54.6591)`,
  `(150,98.8182)`, `(40,112)`.
- Small-building projection quad: `(180,69)`, `(260,70.8978)`,
  `(260,87.1971)`, `(180,98)`.
- Main building minimum road clearance: `> 0 px`; current QA minimum
  is `9.438 px`.
- Small buildings minimum road clearance: `> 0 px`; current QA minimum
  is `2.625 px`.
- Delivered-cargo bounding box: `(121,99) → (144,110)`.
- Truck rear-wheel arrival: `x=-12 → 82`, frames `0–13`.
- Truck rear-wheel departure: `x=82 → 340`, frames `23–38`.
- Both visible wheel bottoms follow `(0,168) → (319,84.7)`.
- Truck scale:
  `clamp(0.35, 1.15, 0.9 × (VP.x - rear_x) / (VP.x - 82))`.

## Layer-specific editing rules

### 01_sky

- MUST be opaque in every frame.
- Cloud silhouettes remain consistent; only integer drift is allowed.
- Do not introduce horizontal bands or full-screen ordered dithering.
- Sun, moon, and stars remain small secondary elements.

### 02_terrain

- Road edges and center dashes MUST not move between frames.
- The upper roadside ground edge MUST pass through source coordinates
  `(0,92)` and `(319,75.58)`; rasterized edge pixels may differ by at
  most `0.5 px` vertically.
- The continuous center-dash guide MUST pass through source coordinates
  `(0,172)` and `(319,85.21)`; rasterized dash pixels may differ by at
  most `0.5 px` vertically.
- Exactly four distinct terrain PNGs are stored; the 64 logical frames
  resolve to them through `manifest.json`'s `frame_maps`.
- Day/night changes are palette swaps, not geometry changes.
- The off-canvas vanishing point MUST remain shared with all buildings.

### 03_main_building

- Footprint and perspective quad are locked for all 64 frames.
- Construction reveals bottom-to-top during frames `18–40`.
- Window indices are `0=upper-left`, `1=upper-right`,
  `2=lower-right`, `3=lower-left`.
- Frames `44–55` create the four-chamber heartbeat metaphor.

### 04_small_buildings

- Exactly three buildings; their footprints and perspective are locked.
- Build intervals: A `22–34`, B `28–40`, C `34–46`.
- The three bases may differ in height but MUST remain above the road.

### 05_vehicle_truck

- Truck faces and travels toward the upper-right vanishing direction.
- Arrival `0–13`; unload stop `14–22`; departure `23–38`; absent `39–63`.
- The loaded and empty source sprites are PixelLab assets snapped to the
  locked 22-color palette before frame generation.
- The two visible wheel bottoms MUST stay within `1 px` of the locked
  wheel-bottom guide in every visible frame.
- Loaded-to-empty transition runs during frames `12–16`.
- Truck is allowed to be fully transparent when absent.

### 05_vehicle_unloaded_cargo

- Cargo appears `12–16`, stays through `28`, fades `29–43`, then is absent.
- Delivered pixels MUST remain inside `(121,99) → (144,110)`.
- The two boxes use option 2 and preserve their shared vanishing point.
- Cargo is allowed to be fully transparent when absent.

### 06_roadside_props

- Lamp and grass bottom anchors are locked to the two road edges.
- Grass sway changes pixels above each anchor; anchors do not move.
- Lamps are off by day, on at night, and dim during dawn.

## Godot title and menu contract

The title and menu are not image layers. Godot draws them from native
`Label`, `Button`, `StyleBoxFlat`, and font resources.

- Title begins at frame `42` (`5.250 s`).
- Only the native `Metabolis` title is shown; there is no subtitle.
- Menu begins at frame `52` (`6.500 s`).
- Menu becomes interactive at frame `60` (`7.500 s`).
- Accept, cancel, or select input may skip to frame `63`.

## Per-frame contract

`Main` is build progress followed by active window indices. `Small` lists
A/B/C build progress. Truck coordinates are sprite centers. `Cargo` and
`Night` are visibility/intensity. Exact cloud, sun, moon, grass phase,
file paths, and SHA-256 values are stored in the machine-readable manifest.

| F | Time | Sky | Terrain | Main / windows | Small A/B/C | Truck | Cargo | Night | UI |
|---:|---:|---|---|---|---|---|---|---:|---|
| 00 | 0.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-12.0,171.1) s=1.150 | absent 0% | 0% | hidden |
| 01 | 0.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-10.4,170.7) s=1.150 | absent 0% | 0% | hidden |
| 02 | 0.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-6.0,169.6) s=1.150 | absent 0% | 0% | hidden |
| 03 | 0.375 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (0.7,167.8) s=1.150 | absent 0% | 0% | hidden |
| 04 | 0.500 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (9.2,165.6) s=1.133 | absent 0% | 0% | hidden |
| 05 | 0.625 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (19.0,163.0) s=1.102 | absent 0% | 0% | hidden |
| 06 | 0.750 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (29.6,160.3) s=1.068 | absent 0% | 0% | hidden |
| 07 | 0.875 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (40.4,157.4) s=1.033 | absent 0% | 0% | hidden |
| 08 | 1.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (51.0,154.7) s=1.000 | absent 0% | 0% | hidden |
| 09 | 1.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (60.8,152.1) s=0.968 | absent 0% | 0% | hidden |
| 10 | 1.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (69.3,149.9) s=0.941 | absent 0% | 0% | hidden |
| 11 | 1.375 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (76.0,148.2) s=0.919 | absent 0% | 0% | hidden |
| 12 | 1.500 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (80.4,147.0) s=0.905 | appearing 0% | 0% | hidden |
| 13 | 1.625 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (82.0,146.6) s=0.900 | appearing 16% | 0% | hidden |
| 14 | 1.750 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | appearing 50% | 0% | hidden |
| 15 | 1.875 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | appearing 84% | 0% | hidden |
| 16 | 2.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 0% | hidden |
| 17 | 2.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 1% | hidden |
| 18 | 2.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 3% | hidden |
| 19 | 2.375 | afternoon_amber | day | 1% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 6% | hidden |
| 20 | 2.500 | dusk_tissue | day | 2% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 10% | hidden |
| 21 | 2.625 | dusk_tissue | day | 5% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 16% | hidden |
| 22 | 2.750 | dusk_tissue | day | 9% / — | 0%/0%/0% | unloading (82.0,146.6) s=0.900 | delivered 100% | 22% | hidden |
| 23 | 2.875 | dusk_tissue | day | 13% / — | 2%/0%/0% | departing (82.0,146.6) s=0.900 | delivered 100% | 28% | hidden |
| 24 | 3.000 | dusk_tissue | dusk | 18% / — | 7%/0%/0% | departing (85.3,145.7) s=0.889 | delivered 100% | 35% | hidden |
| 25 | 3.125 | dusk_tissue | dusk | 24% / — | 16%/0%/0% | departing (94.5,143.3) s=0.860 | delivered 100% | 43% | hidden |
| 26 | 3.250 | dusk_blue_light | dusk | 30% / — | 26%/0%/0% | departing (108.8,139.6) s=0.814 | delivered 100% | 50% | hidden |
| 27 | 3.375 | dusk_blue_light | dusk | 37% / — | 38%/0%/0% | departing (127.3,134.8) s=0.755 | delivered 100% | 57% | hidden |
| 28 | 3.500 | dusk_blue_light | dusk | 43% / — | 50%/0%/0% | departing (148.9,129.1) s=0.685 | delivered 100% | 65% | hidden |
| 29 | 3.625 | dusk_blue_light | dusk | 50% / — | 62%/2%/0% | departing (172.8,122.9) s=0.609 | consumed 100% | 72% | hidden |
| 30 | 3.750 | night_blue | late_dusk | 57% / — | 74%/7%/0% | departing (198.1,116.3) s=0.528 | consumed 99% | 78% | hidden |
| 31 | 3.875 | night_blue | late_dusk | 63% / — | 84%/16%/0% | departing (223.9,109.5) s=0.445 | consumed 94% | 84% | hidden |
| 32 | 4.000 | night_blue | late_dusk | 70% / — | 93%/26%/0% | departing (249.2,102.9) s=0.364 | consumed 88% | 90% | hidden |
| 33 | 4.125 | night_blue | late_dusk | 76% / — | 98%/38%/0% | departing (273.1,96.7) s=0.350 | consumed 80% | 94% | hidden |
| 34 | 4.250 | night_blue_dark | late_dusk | 82% / — | 100%/50%/0% | departing (294.7,91.0) s=0.350 | consumed 71% | 97% | hidden |
| 35 | 4.375 | night_blue_dark | late_dusk | 87% / — | 100%/62%/2% | departing (313.2,86.2) s=0.350 | consumed 61% | 99% | hidden |
| 36 | 4.500 | night_blue_dark | night | 91% / — | 100%/74%/7% | departing (327.5,82.5) s=0.350 | consumed 50% | 100% | hidden |
| 37 | 4.625 | night_blue_dark | night | 95% / — | 100%/84%/16% | departing (336.7,80.1) s=0.350 | consumed 39% | 100% | hidden |
| 38 | 4.750 | night_blue_dark | night | 98% / — | 100%/93%/26% | departing (340.0,79.2) s=0.350 | consumed 29% | 100% | hidden |
| 39 | 4.875 | night_blue_dark | night | 99% / — | 100%/98%/38% | — | consumed 20% | 100% | hidden |
| 40 | 5.000 | night_blue_dark | night | 100% / — | 100%/100%/50% | — | consumed 12% | 100% | hidden |
| 41 | 5.125 | night_blue_dark | night | 100% / — | 100%/100%/62% | — | consumed 6% | 100% | hidden |
| 42 | 5.250 | night_blue_dark | night | 100% / — | 100%/100%/74% | — | consumed 1% | 100% | title_entering |
| 43 | 5.375 | night_blue_dark | night | 100% / — | 100%/100%/84% | — | consumed 0% | 100% | title_entering |
| 44 | 5.500 | night_blue_dark | night | 100% / 0 | 100%/100%/93% | — | absent 0% | 100% | title_entering |
| 45 | 5.625 | night_blue_dark | night | 100% / 0 | 100%/100%/98% | — | absent 0% | 100% | title_entering |
| 46 | 5.750 | night_blue_dark | night | 100% / 1 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 47 | 5.875 | night_blue_dark | night | 100% / 1 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 48 | 6.000 | night_blue_dark | night | 100% / 2 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 49 | 6.125 | night_blue_dark | night | 100% / 2 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 50 | 6.250 | night_blue_dark | night | 100% / 3 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 51 | 6.375 | night_blue_dark | night | 100% / 3 | 100%/100%/100% | — | absent 0% | 100% | title_entering |
| 52 | 6.500 | night_blue_dark | night | 100% / 0,1,2,3 | 100%/100%/100% | — | absent 0% | 100% | menu_entering |
| 53 | 6.625 | night_blue_dark | night | 100% / — | 100%/100%/100% | — | absent 0% | 100% | menu_entering |
| 54 | 6.750 | night_blue_dark | night | 100% / — | 100%/100%/100% | — | absent 0% | 100% | menu_entering |
| 55 | 6.875 | night_blue_dark | night | 100% / 0,1,2,3 | 100%/100%/100% | — | absent 0% | 100% | menu_entering |
| 56 | 7.000 | dawn_blue | late_dusk | 100% / — | 100%/100%/100% | — | absent 0% | 100% | menu_entering |
| 57 | 7.125 | dawn_blue | late_dusk | 100% / — | 100%/100%/100% | — | absent 0% | 96% | menu_entering |
| 58 | 7.250 | dawn_blue | late_dusk | 100% / — | 100%/100%/100% | — | absent 0% | 87% | menu_entering |
| 59 | 7.375 | dawn_blue_light | late_dusk | 100% / — | 100%/100%/100% | — | absent 0% | 74% | menu_entering |
| 60 | 7.500 | dawn_blue_light | dusk | 100% / — | 100%/100%/100% | — | absent 0% | 61% | interactive |
| 61 | 7.625 | dawn_blue_light | dusk | 100% / — | 100%/100%/100% | — | absent 0% | 48% | interactive |
| 62 | 7.750 | dawn_tissue | dusk | 100% / — | 100%/100%/100% | — | absent 0% | 39% | interactive |
| 63 | 7.875 | dawn_tissue | dusk | 100% / — | 100%/100%/100% | — | absent 0% | 35% | interactive |

## Required validation after edits

1. Run the rebuild command.
2. Confirm QA status is `PASS` and total PNG count is `199`,
   with `logical_frame_count` still `448`.
3. Confirm all images are RGBA `320×180`, palette-locked, binary-alpha.
4. Confirm both building layers report `never_intersects_road: true`.
5. Run:
   `/opt/homebrew/bin/godot --headless --path src --editor --quit`.
6. Run the gameplay entry regression test.
7. Review the Godot recording at frames `0`, `32`, `42`, `46`, `52`,
   `60`, and `63` before publishing.

Do not hand-edit generated hashes. Rebuild them from the generator.
