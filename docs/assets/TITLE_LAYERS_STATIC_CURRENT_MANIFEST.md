# Current Static Title Layers

Local preview set for the planned 8-second, 8-fps layered title animation.

- Canvas: `320 × 180`
- Locked palette: `art/palette.gpl` (22 colors)
- Alpha: binary (`0` or `255`)
- Shared vanishing point: `(1088/3, 220/3)` = `(362.6667, 73.3333)`
- Road upper edge: `(0,130) → (320,80)`
- Current assets: `art/previews/title_layers_static/`
- QA report: `docs/assets/TITLE_LAYERS_STATIC_CURRENT_QA.json`

## Layers

| Layer | State A | State B | PixelLab source |
|---|---|---|---|
| Sky | `sky_title_afternoon.png` | `sky_title_night.png` | Deterministic palette-locked revision; original PixelLab bases: `312478f4-d477-49fb-8123-dce4f8f7cd3e`, `53afc23d-6758-4de3-8dbe-5e372e74283a` |
| Terrain and road | `terrain_road_afternoon.png` | `terrain_road_night.png` | `eed288fe-c411-49cc-83c9-c8204effa374`, `8cad388c-c183-467e-9ccb-62d34ffd59fc` |
| Main building | `building_main_construction.png` | `building_main_complete.png` | Pro candidate `7b13cbde-b219-45b6-91f1-a730cc18f285` index 0; construction edit `08fe67d4-5c69-4e54-9cf2-0d7934f45282` |
| Three small buildings | `building_small_construction.png` | `building_small_complete.png` | Pro candidate `cd9e8ad5-a15c-4eaa-b95c-8670e6b0ef8d` index 1; construction edit `39c6e00a-d4d6-4f68-b8a8-fc03af1472d0` |
| Truck and cargo | `vehicle_truck_arrival.png` | `vehicle_truck_departure.png` | `e110e1e7-4fa5-4583-8232-a96d5832ba1c`, `47495206-1d84-4d89-9bc7-0be1f03063b5` |
| Lamps and grass | `prop_roadside_day.png` | `prop_roadside_night.png` | `f159ce7d-b586-4c83-829e-af82153dfc02`, `458548c1-34a8-4d0e-9170-60a9c11e06cc` |

## Perspective Projection

The building sprites are projected with nearest-neighbor sampling after generation.

- Main building target quad: `(40,45)`, `(150,54.6591)`, `(150,98.8182)`, `(40,112)`
- Small-building target quad: `(180,69)`, `(260,70.8978)`, `(260,87.1971)`, `(180,98)`

Both top and bottom quad edges extend through the shared vanishing point. The
projected assets are then mapped back to the locked palette and binary alpha.

## Sky Revision

- No solid or dithered horizontal horizon band.
- Afternoon and night use the same two cloud silhouettes at `(28,24)` and
  `(168,42)`.
- The sun at `(278,44)` and moon at `(58,52)` have no dark circular outline.
- Stars use fixed irregular coordinates above the horizon.
- All ten non-sky layer hashes remained unchanged during the revision.

## Visual Constraints

- No explicit organ imagery, gore, labels, title, or menu embedded in the layers.
- Main building retains the four-window chamber metaphor.
- Exactly three distinct small buildings.
- Buildings remain fully above the road upper boundary.
- Main construction and completion states share one footprint; small-building
  construction and completion states share one footprint.
