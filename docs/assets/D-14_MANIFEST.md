# D-14 UI Framework Manifest

task_id: D-14
status: DONE
source: `docs/prompts/Metabolis_Prompts_Full_v2.md` D-14
specification: `docs/UI_LAYOUT.md` sections 1-6

The original D-14 deliverable is a layout specification plus six English PixelLab descriptions. It does not require generated PNGs. The reserved filenames and seeds below make later generation reproducible without claiming that images already exist.

| Prompt target | Reserved static-image filename | Native canvas | Reserved seed | Delivery state |
|---|---|---:|---:|---|
| Main city map | `ui_map_main_city.png` | `640 × 320 px` | `14001` | Description locked; PNG not part of D-14 |
| Development timeline | `ui_timeline_development.png` | `640 × 8 px` | `14002` | Description locked; PNG not part of D-14 |
| Task and operations panel | `ui_panel_operations.png` | `608 × 16 px` | `14003` | Description locked; PNG not part of D-14 |
| Resource status bar | `ui_status_resources.png` | `640 × 16 px` | `14004` | Description locked; PNG not part of D-14 |
| Organ archive entry button | `ui_button_organ_archive.png` | `16 × 16 px` | `14005` | Description locked; PNG not part of D-14 |
| Chapter recap entry button | `ui_button_chapter_recap.png` | `16 × 16 px` | `14006` | Description locked; PNG not part of D-14 |

## Checks

- Six rectangles are pairwise non-overlapping, in bounds, and cover the `640 × 360 px` reference canvas: PASS
- Persistent UI occupies `25,600 / 230,400 = 11.111...%`, below 25%: PASS
- The resource row is 16 pixels high and accepts the unscaled `16 × 16 px` icons from `ASSET_SPEC.md`: PASS
- All three E8 readings remain visible in one `608 × 16 px` horizontal gaze region: PASS
- A `640 × 360 px` reference raster of all six rectangles shows no overlap, clipping, or uncovered pixel: PASS
- Each of the six English descriptions includes the final 22-color palette, native size, outline rule, and forbidden list: PASS
