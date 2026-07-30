# Visual Cohesion Guide

## Direction

The builder sequence uses a friendly top-down body-city rather than a visible board of independent tiles. The visual reference establishes the desired density, warmth, and continuity; Metabolis does not copy its vehicles, layout, or structures.

The map reads in this order:

1. a continuous peach-pink tissue ground;
2. raised coral organ districts with dark berry cellular walls;
3. luminous cyan transport vessels that select connected straight, corner, branch, and junction art;
4. compact organ-buildings whose visible silhouettes fit their declared footprints;
5. dark berry interface panels with coral edging.

## Locked Prototype Palette

The canonical 22-color palette is stored in `art/palette.gpl`. System-map art
uses the same semantic groups documented in `docs/ART_BIBLE.md`:

| Semantic group | Dark / main / light |
|---|---|
| Arterial coral | `#340106` / `#BA3A3F` / `#C25453` |
| Oxygen blue | `#48A5CF` / `#7AD1FD` / `#CDD9E1` |
| Blue violet | `#29314A` / `#404586` / `#53548C` |
| Tissue pink | `#91465F` / `#BE6E87` / `#C98197` |
| Warm amber | `#B26C09` / `#E2953A` / `#DDAD7E` |
| Mint green | `#73CD9B` / `#B1FFD1` / `#F4FFF8` |
| Neutrals | `#140F1D` / `#514854` / `#817582` / `#E8DCCF` |

## Scale and Placement Rules

- The logical placement grid remains 16 × 16 pixels.
- The grid is invisible during observation and operation.
- A low-opacity grid appears only while a placement or unfinished route tool is active.
- Valid anatomical regions may appear as temporary tool overlays, but they are not permanent map rectangles.
- A confirmed building never keeps a footprint outline.
- A 2 × 2 structure uses a 32 × 32 pixel canvas.
- A 7 × 7 landmark uses a 112 × 112 pixel canvas.
- Excess transparent padding is cropped before a sprite is accepted; system facilities retain a four-pixel safety margin inside the standard source canvas.
- Buildings use nearest-neighbor scaling and a bottom-center anchor.
- System facilities use 56 × 56 source canvases and render into their 112 × 112 logical footprints at an exact 2× scale.
- Transport routes use broad arterial-street tiles with cyan curbs and a cream center marking. They select art from neighbor connectivity; separate square stamps may not be placed side by side without edge matching.

## Screen Composition

- The prototype canvas is 800 × 450 pixels.
- The playable body-city map remains 640 × 320 pixels, beginning below the 40 pixel top HUD.
- All build and operation buttons live in the 160 pixel right rail outside the map.
- Objective and feedback text live in the 90 pixel lower information region outside the map.
- No instructional text, action button, or interactive panel may cover the playable map.

## Connected Vessel Masks

The vessel set uses `N = 1`, `E = 2`, `S = 4`, and `W = 8`. Adding the connected directions produces the tile mask. The active renderer supports isolated endpoints, four dead ends, two straights, four corners, four three-way junctions, and the four-way junction.

## PixelLab Asset Record

| Asset | PixelLab ID | Local file | Runtime status |
|---|---|---|---|
| Tissue transition atlas | `d23064a7-8b19-4b37-a609-b019659363b6` | `art/tiles/organic/tile_tissue_transition_v2.png` | Palette-normalized foundation for later terrain autotiling |
| Connected body-city roads | `5f401703-f6c4-4571-92d4-1267f9d84a70` | `art/tiles/organic/road_v3_transparent/tile_city_road_transparent_00.png` through `17.png` | Active; widened for readability and given transparent surroundings for seamless placement on every system map |
| Earlier connected vessel paths | `b40dd791-02fc-42c3-950f-3ce58deb4e48` | `art/tiles/organic/vessel_v1/tile_vessel_cohesive_00.png` through `17.png` | Preserved source, not active |
| Life Harbor | `21256c8e-2480-44db-8a2e-deb230a44f6e` | `art/organs/cohesive/organ_placenta_harbor_v1.png` | Active |
| Early heart pumping station | `5e24720c-d644-439e-9897-99645b2291bb` | `art/organs/cohesive/organ_heart_pump_v1.png` | Active |
| First cell district | `fcf92134-2341-4d35-8e2e-10de6dac4171` | `art/organs/cohesive/organ_cell_district_v2.png` | Active after the third division cycle |

## Generation Prompt Set

The terrain prompt specifies warm peach-pink living tissue, small cell bubbles, a raised coral organ plateau, a dark berry cellular wall, seamless rounded transitions, and no gore, realism, buildings, or text.

The active road prompt specifies a broad raspberry body-city arterial street on peach-pink tissue, luminous cyan curbs, a pale cream dashed center line, seamless rounded junctions, and no vehicles, blood, gore, or text.

The organ prompts specify compact top-down civic structures, coral roof plates, dark raspberry foundations, luminous cyan ports, strict 32 or 48 pixel canvases, readable silhouettes, and no text, gore, or realism.

## Acceptance

- No permanent checkerboard is visible.
- A completed route contains no visible square seams at a straight or corner.
- A completed building has no green or white footprint box.
- The Life Harbor, cell district, and heart pumping station share one palette and top-down camera.
- At 2× display scale, every landmark is readable without exceeding its grid footprint.
- The right action rail and lower information region remain fully outside the 640 × 320 map.
- Routes read as connected city streets and remain visibly narrower than 7 × 7 landmark buildings.
- Each body system has a separate warm map page; unlocked pages are selected from the right rail or with number keys.
- Cross-boundary delivery uses visible vans, freight cars, scooters, and trams instead of abstract moving dots.
