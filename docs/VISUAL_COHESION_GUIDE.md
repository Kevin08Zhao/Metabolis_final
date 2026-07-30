# Visual Cohesion Guide

## Direction

The builder sequence uses a friendly top-down body-city rather than a visible board of independent tiles. The visual reference establishes the desired density, warmth, and continuity; Metabolis does not copy its vehicles, layout, or structures.

The map reads in this order:

1. a continuous peach-pink tissue ground;
2. a legible civic plan of perimeter avenues, neighborhood props, and a central construction parcel;
3. raised coral organ districts with dark berry cellular walls;
4. luminous cyan transport roads that select connected straight, corner, branch, and junction art;
5. compact organ-buildings whose visible silhouettes fit their declared footprints;
6. cell residents and city vehicles that remain grounded by shadows and street alignment;
7. dark berry interface panels with coral edging.

## Locked Prototype Palette

| Role | Color |
|---|---|
| Tissue ground | `#F7A39E` |
| Tissue highlight | `#FFC2B6` |
| Organ-district top | `#F27FA3` |
| Organ-district midtone | `#BD4178` |
| Organ-district wall | `#752754` |
| Global outline and panel base | `#28152F` |
| Transport vessel | `#64DDD8` |
| Vessel highlight | `#C7FFF4` |

## Scale and Placement Rules

- The logical placement grid remains 16 × 16 pixels.
- The grid is invisible during observation and operation.
- A low-opacity grid appears only while a placement or unfinished route tool is active.
- Each system has one softly paved civic construction parcel. Its full grid and stronger border appear only while the placement tool is active.
- A confirmed building never keeps a footprint outline.
- A 2 × 2 structure uses a 32 × 32 pixel canvas.
- A 6 × 6 landmark uses a 96 × 96 pixel canvas.
- Transparent padding is cropped and integer-scaled before a sprite is accepted.
- Buildings use a bottom-center anchor and may not be stretched beyond their declared canvas.
- A player facility receives a matching paved plaza and short service aprons computed from its chosen grid origin.
- Fixed shops, phone booths, shelters, lamps, citizens, and maintenance traffic stay outside the construction parcel.
- Every background prop and moving actor uses a ground pad or contact shadow; no object may appear to float over the map.
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
| Membrane phone booth | `fc67e01d-5fa2-4887-8417-bdd3b22e61cb` | `art/props/system/prop_cell_phone_booth.png` | Active fixed neighborhood infrastructure |
| Nutrient corner shop | `0984c8f1-552b-47fa-9b6d-7457f00d72a1` | `art/props/system/prop_nutrient_corner_shop.png` | Active fixed neighborhood infrastructure |
| Body-city transit shelter | `aec6af78-8df6-4a98-a61f-7ea79f86c190` | `art/props/system/prop_body_transit_shelter.png` | Active fixed neighborhood infrastructure |
| Tissue street lamp | `06fc7535-b8e2-4b0c-b9e7-b8d32cedff78` | `art/props/system/prop_tissue_street_lamp.png` | Active fixed neighborhood infrastructure |

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
- Routes read as connected city streets and remain visibly narrower than 6 × 6 landmark buildings.
- Each body system has a separate warm map page; unlocked pages are selected from the right rail or with number keys.
- Cross-boundary delivery uses visible vans, freight cars, scooters, and trams instead of abstract moving dots.
- Every map has a readable street hierarchy, fixed civic props, ambient residents, and ambient municipal traffic.
- A 6 × 6 facility can be placed at several positions inside its parcel but nowhere outside it.
- Construction has a visible three-second buffer with progress, scaffold scan, and workers.
- The completed plaza and access aprons move with the facility and meet its ports without a floating gap.
