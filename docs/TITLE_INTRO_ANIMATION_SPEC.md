# Metabolis Opening Animation Specification

This is the normative handoff for editing the title animation in another
Codex task, Godot session, or art workflow. `MUST` rules are compatibility
requirements; changing a `LOCKED` value requires updating this document,
`art/animations/title_layers/manifest.json`, and the QA report together.

## Source of truth

- Human-readable contract: this file.
- Machine-readable per-frame contract and SHA-256 hashes:
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
| Frames per layer | `64`, numbered `000–063` |
| File pattern | `frame_%03d.png` |
| Color | Only the 22 colors in `art/palette.gpl` |
| Alpha | Binary only: `0` or `255` |
| Sampling | Nearest-neighbor; integer source coordinates |
| Vanishing point | `(1088/3, 220/3) = (362.6667, 73.3333)` |
| Road upper edge | `(0,130) → (320,80)` |
| Road lower edge | `(160,200) → (320,100)` |
| Embedded text | Forbidden; title and menu are native Godot UI |

Layer order is back-to-front and MUST remain:

1. `01_sky` — opaque full-canvas sky and celestial objects.
2. `02_terrain` — road and surrounding ground; geometry is locked.
3. `03_main_building` — main perspective building, no road intersection.
4. `04_small_buildings` — exactly three perspective buildings.
5. `05_vehicle_cargo` — transient truck and delivered cargo.
6. `06_roadside_props` — lamps and grass anchored to road edges.

## Locked geometry

- Main-building projection quad: `(40,45)`, `(150,54.6591)`,
  `(150,98.8182)`, `(40,112)`.
- Small-building projection quad: `(180,69)`, `(260,70.8978)`,
  `(260,87.1971)`, `(180,98)`.
- Main building minimum road clearance: `> 0 px`; current QA minimum
  is `9.438 px`.
- Small buildings minimum road clearance: `> 0 px`; current QA minimum
  is `2.625 px`.
- Cargo anchor: `(160,99)`.
- Truck arrival Bézier: `(-15,171) → control (58,163) → (145,121)`.
- Truck departure Bézier: `(145,121) → control (232,108) → (338,80)`.
- Truck scale:
  `0.65 + 0.35 × clamp(distance_to_VP / stop_distance, 0.15, 1.8)`.

## Layer-specific editing rules

### 01_sky

- MUST be opaque in every frame.
- Cloud silhouettes remain consistent; only integer drift is allowed.
- Do not introduce horizontal bands or full-screen ordered dithering.
- Sun, moon, and stars remain small secondary elements.

### 02_terrain

- Road edges and center dashes MUST not move between frames.
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

### 05_vehicle_cargo

- Truck faces and travels toward the upper-right vanishing direction.
- Arrival `0–13`; unload stop `14–22`; departure `23–38`; absent `39–63`.
- Cargo appears `12–16`, stays through `28`, fades `29–43`, then is absent.
- Truck and cargo are allowed to be fully transparent when absent.

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
| 00 | 0.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-15.0,171.0) s=1.263 | absent 0% | 0% | hidden |
| 01 | 0.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-12.5,170.7) s=1.259 | absent 0% | 0% | hidden |
| 02 | 0.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (-5.6,169.8) s=1.248 | absent 0% | 0% | hidden |
| 03 | 0.375 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (5.0,168.2) s=1.231 | absent 0% | 0% | hidden |
| 04 | 0.500 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (18.7,165.7) s=1.209 | absent 0% | 0% | hidden |
| 05 | 0.625 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (34.7,162.0) s=1.184 | absent 0% | 0% | hidden |
| 06 | 0.750 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (52.3,157.3) s=1.155 | absent 0% | 0% | hidden |
| 07 | 0.875 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (70.8,151.5) s=1.125 | absent 0% | 0% | hidden |
| 08 | 1.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (89.1,145.0) s=1.094 | absent 0% | 0% | hidden |
| 09 | 1.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (106.4,138.2) s=1.065 | absent 0% | 0% | hidden |
| 10 | 1.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (121.7,131.7) s=1.039 | absent 0% | 0% | hidden |
| 11 | 1.375 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (134.0,126.2) s=1.019 | absent 0% | 0% | hidden |
| 12 | 1.500 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (142.1,122.4) s=1.005 | appearing 0% | 0% | hidden |
| 13 | 1.625 | afternoon_amber | day | 0% / — | 0%/0%/0% | arriving (145.0,121.0) s=1.000 | appearing 16% | 0% | hidden |
| 14 | 1.750 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | appearing 50% | 0% | hidden |
| 15 | 1.875 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | appearing 84% | 0% | hidden |
| 16 | 2.000 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 0% | hidden |
| 17 | 2.125 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 1% | hidden |
| 18 | 2.250 | afternoon_amber | day | 0% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 3% | hidden |
| 19 | 2.375 | afternoon_amber | day | 1% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 6% | hidden |
| 20 | 2.500 | dusk_tissue | day | 2% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 10% | hidden |
| 21 | 2.625 | dusk_tissue | day | 5% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 16% | hidden |
| 22 | 2.750 | dusk_tissue | day | 9% / — | 0%/0%/0% | unloading (145.0,121.0) s=1.000 | delivered 100% | 22% | hidden |
| 23 | 2.875 | dusk_tissue | day | 13% / — | 2%/0%/0% | departing (145.0,121.0) s=1.000 | delivered 100% | 28% | hidden |
| 24 | 3.000 | dusk_tissue | dusk | 18% / — | 7%/0%/0% | departing (147.2,120.7) s=0.997 | delivered 100% | 35% | hidden |
| 25 | 3.125 | dusk_tissue | dusk | 24% / — | 16%/0%/0% | departing (153.5,119.7) s=0.987 | delivered 100% | 43% | hidden |
| 26 | 3.250 | dusk_blue_light | dusk | 30% / — | 26%/0%/0% | departing (163.3,118.1) s=0.971 | delivered 100% | 50% | hidden |
| 27 | 3.375 | dusk_blue_light | dusk | 37% / — | 38%/0%/0% | departing (176.1,116.0) s=0.951 | delivered 100% | 57% | hidden |
| 28 | 3.500 | dusk_blue_light | dusk | 43% / — | 50%/0%/0% | departing (191.4,113.3) s=0.926 | delivered 100% | 65% | hidden |
| 29 | 3.625 | dusk_blue_light | dusk | 50% / — | 62%/2%/0% | departing (208.6,110.0) s=0.899 | consumed 100% | 72% | hidden |
| 30 | 3.750 | night_blue | late_dusk | 57% / — | 74%/7%/0% | departing (227.2,106.3) s=0.869 | consumed 99% | 78% | hidden |
| 31 | 3.875 | night_blue | late_dusk | 63% / — | 84%/16%/0% | departing (246.4,102.2) s=0.838 | consumed 94% | 84% | hidden |
| 32 | 4.000 | night_blue | late_dusk | 70% / — | 93%/26%/0% | departing (265.7,97.9) s=0.807 | consumed 88% | 90% | hidden |
| 33 | 4.125 | night_blue | late_dusk | 76% / — | 98%/38%/0% | departing (284.3,93.5) s=0.777 | consumed 80% | 94% | hidden |
| 34 | 4.250 | night_blue_dark | late_dusk | 82% / — | 100%/50%/0% | departing (301.4,89.4) s=0.750 | consumed 71% | 97% | hidden |
| 35 | 4.375 | night_blue_dark | late_dusk | 87% / — | 100%/62%/2% | departing (316.2,85.7) s=0.726 | consumed 61% | 99% | hidden |
| 36 | 4.500 | night_blue_dark | night | 91% / — | 100%/74%/7% | departing (327.7,82.7) s=0.707 | consumed 50% | 100% | hidden |
| 37 | 4.625 | night_blue_dark | night | 95% / — | 100%/84%/16% | departing (335.3,80.7) s=0.703 | consumed 39% | 100% | hidden |
| 38 | 4.750 | night_blue_dark | night | 98% / — | 100%/93%/26% | departing (338.0,80.0) s=0.703 | consumed 29% | 100% | hidden |
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
2. Confirm QA status is `PASS` and total PNG count is `384`.
3. Confirm all images are RGBA `320×180`, palette-locked, binary-alpha.
4. Confirm both building layers report `never_intersects_road: true`.
5. Run:
   `/opt/homebrew/bin/godot --headless --path src --editor --quit`.
6. Run the gameplay entry regression test.
7. Review the Godot recording at frames `0`, `32`, `42`, `46`, `52`,
   `60`, and `63` before publishing.

Do not hand-edit generated hashes. Rebuild them from the generator.
