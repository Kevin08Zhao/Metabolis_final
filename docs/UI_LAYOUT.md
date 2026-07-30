# Metabolis Main-View UI Layout and PixelLab Prompts

## 1. Layout derivation

The reference window is `640 × 360 px`. The main city map is fixed by the grid baseline at `40 × 20` tiles with a `16 px` tile edge:

```text
map_width  = 40 × 16 = 640 px
map_height = 20 × 16 = 320 px
reserved_ui_height = window_height - map_height = 360 - 320 = 40 px
```

The reserved height is partitioned without remainder:

```text
resource_status_height + development_timeline_height + task_row_height
= 16 + 8 + 16
= 40 px
```

The task row contains the task/metric panel and both entry buttons:

```text
task_panel_width + archive_button_width + recap_button_width
= 608 + 16 + 16
= 640 px
```

The buttons consume no additional persistent screen area because they subdivide the already reserved 16-pixel task row. They open temporary views; those views are not additional main-view regions.

## 2. Region rectangle table

All coordinates use the `640 × 360` native reference canvas and Godot `Rect2(x, y, width, height)` notation. Rectangles are half-open: the right and bottom edges are excluded.

| Region | Rectangle | Area | Derivation |
|---|---|---:|---|
| Resource status bar | `Rect2(0, 0, 640, 16)` | 10,240 px² | Full window width × the locked 16-pixel UI-icon height |
| Development timeline | `Rect2(0, 16, 640, 8)` | 5,120 px² | Begins after the resource row: `y = 0 + 16`; ends at the task row |
| Task and operations panel | `Rect2(0, 24, 608, 16)` | 9,728 px² | `y = 16 + 8`; width `640 - 16 - 16 = 608` |
| Organ archive entry button | `Rect2(608, 24, 16, 16)` | 256 px² | Begins at task-panel right edge |
| Chapter recap entry button | `Rect2(624, 24, 16, 16)` | 256 px² | Begins at `608 + 16`; ends at `x = 640` |
| Main city map | `Rect2(0, 40, 640, 320)` | 204,800 px² | `y = 360 - 320 = 40`; size `40 × 16` by `20 × 16` |

The six rectangles do not overlap, remain within `Rect2(0,0,640,360)`, and cover the reference canvas exactly:

```text
10,240 + 5,120 + 9,728 + 256 + 256 + 204,800 = 230,400 px²
640 × 360 = 230,400 px²
```

## 3. Persistent UI area

The persistent UI is only the top 40-pixel strip; the city map is gameplay space rather than UI:

```text
persistent_ui_area = 640 × 40 = 25,600 px²
window_area = 640 × 360 = 230,400 px²
ui_percentage = 25,600 ÷ 230,400 × 100 = 11.111…%
11.111…% < 25%
```

At the default integer `2×` display, every coordinate and size doubles, but the percentage remains `11.111…%`.

## 4. Resource and operational-reading subdivision

The resource bar simultaneously displays six resources in this fixed order: nutrient energy, cell material, developmental signal, waste, stability, and knowledge badge count. Six `96 × 16 px` cells, five `8 px` gaps, and two `12 px` outer margins fill the row. The 16-pixel height is mandatory because every resource icon has the locked `1T × 1T = 16 × 16 px` canvas from `ASSET_SPEC.md`; a shorter row would clip or rescale the icon:

```text
6 × 96 + 5 × 8 + 2 × 12 = 640 px
cell_x = 12, 116, 220, 324, 428, 532
```

The task and operations panel keeps all three E8 readings in one horizontal gaze region:

| Reading | Rectangle | Required simultaneous content |
|---|---|---|
| Transport pressure | `Rect2(0, 24, 192, 16)` | Raw value, configured unit, pressure scale, current target |
| Waste accumulation | `Rect2(192, 24, 192, 16)` | Raw value, configured unit, maximum scale, net direction |
| Signal coverage | `Rect2(384, 24, 224, 16)` | Raw value, configured unit, coverage scale, lowest-coverage organ |

Ranges and units are runtime values from Table E8 and must not be baked into the artwork. Within each reading cell, reserve one continuous row in this order: 3-pixel left padding, 12-pixel non-color metric icon, 2-pixel gap, 32-pixel raw-value slot, 24-pixel unit slot, 72-pixel scale, and the remaining width for the target, net direction, or lowest-coverage organ. No tab, carousel, hover replacement, page switch, or vertical stack is allowed.

The 12-second budget is met by a single left-to-right sweep: `4 seconds × 3 readings = 12 seconds`. All three cells remain visible together inside `Rect2(0,24,608,16)`, so reading the next metric requires no panel switch and no movement to another screen region.

## 5. English PixelLab descriptions

### Main city map

Create one native-resolution main-city-map background and framing asset for “Metabolis: Birth of the City of Life,” exactly 640 × 320 pixels, representing a 40-column by 20-row grid of 16 × 16 pixel tiles in an orthographic top-down city view beginning below the UI at reference-canvas position (0,40). Show warm organic tissue terrain, grid-aligned transport roads, pump-station and organ-city silhouettes, and subdued synchronous background construction, while leaving current construction readable through stronger local contrast; keep all structures and turns on integer pixels and do not embed any UI into the map. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply a single 1-native-pixel exterior outline in #140F1D and use #514854 only for internal dark structure; use no object-specific outline color. Forbidden elements: minimap, achievement bar, task list, resource bar, timeline, archive button, recap button, text, labels, medical anatomy, blood, wounds, gradients, anti-aliasing, blur, feathering, partial transparency, non-integer scaling, colors outside the locked palette, photographic texture, volumetric light, or decorative UI.

### Development timeline

Create one native-resolution development-timeline strip for “Metabolis: Birth of the City of Life,” exactly 640 × 8 pixels at reference-canvas position (0,16), with a transparent background and a single horizontal integer-pixel path whose milestone sockets, completed span, current position, and remaining span remain readable without baked text; keep every mark inside the 8-pixel height and reserve all labels for runtime rendering. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using oxygen blue only for instructional or current-position emphasis and neutrals for non-semantic frame structure. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal separators; use no colored per-object outline and align every segment to integer pixels. Forbidden elements: minimap, achievement bar, task list, resource counters, operational metric cards, archive button, recap button, readable text, numbers, labels, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, extra rows, vertical timelines, or decorative badges.

### Task and operations panel

Create one native-resolution task-and-operations panel frame for “Metabolis: Birth of the City of Life,” exactly 608 × 16 pixels at reference-canvas position (0,24), divided into three permanently visible adjacent reading cells with no tabs: a 192 × 16 transport-pressure cell from x 0–191, a 192 × 16 waste-accumulation cell from x 192–383, and a 224 × 16 signal-coverage cell from x 384–607. In each cell reserve, from left to right, 3 pixels of padding, a 12-pixel non-color metric-icon slot, a 2-pixel gap, a 32-pixel raw-value slot, a 24-pixel runtime-unit slot, a 72-pixel scale, and the remaining width for current target, net direction, or lowest-coverage organ; keep all three readings visible in one horizontal gaze region and leave every value, unit, range, and target blank for runtime rendering. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply a single 1-native-pixel exterior outline in #140F1D and #514854 internal dividers, with integer-pixel geometry and no per-metric outline color. Forbidden elements: task list, tabs, carousel, page switch, hover-replacement content, minimap, achievement bar, resource bar, timeline, archive button, recap button, baked text, invented units, fixed numeric ranges, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, or additional metric tiers.

### Resource status bar

Create one native-resolution resource-status bar for “Metabolis: Birth of the City of Life,” exactly 640 × 16 pixels at reference-canvas position (0,0), with six permanently visible 96 × 16 resource cells in the fixed order nutrient energy, cell material, developmental signal, waste, stability, and knowledge badge count; place the cells at x 12, 116, 220, 324, 428, and 532, separated by five 8-pixel gaps and bounded by 12-pixel outer margins. Reserve one unscaled 16 × 16 icon canvas and one runtime-value slot in every cell, preserve the six locked non-color resource silhouettes, and keep stability as a continuous fill with its current tier texture while knowledge badges remain a count. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, assigning each semantic color only to its locked resource. Apply one 1-native-pixel exterior outline in #140F1D and #514854 internal separators; use no resource-specific outline color and align all icon and value slots to integer pixels. Forbidden elements: a seventh resource, operational metrics, minimap, achievement bar, task list, timeline, archive button, recap button, baked text, invented values, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, extra rows, scrolling, pre-scaling the resource icons, or decorative counters.

### Organ archive entry button

Create one native-resolution organ-archive entry button for “Metabolis: Birth of the City of Life,” exactly 16 × 16 pixels at reference-canvas position (608,24), with a transparent background, a compact organ-record silhouette readable without text, and integer-pixel pressed and unpressed boundaries that do not alter the 16 × 16 footprint; this button opens the archive but does not contain or reserve a persistent archive panel. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using tissue pink and neutrals without implying a resource state. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal structure; use no colored exterior outline and keep all pixels on the integer grid. Forbidden elements: archive panel content, organ list, task list, minimap, achievement bar, resource counter, timeline, readable text, letters, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, oversized hit art, or decorative badges.

### Chapter recap entry button

Create one native-resolution chapter-recap entry button for “Metabolis: Birth of the City of Life,” exactly 16 × 16 pixels at reference-canvas position (624,24), with a transparent background, a compact closed-record silhouette distinct from the organ-archive button without text, and integer-pixel pressed and unpressed boundaries that do not alter the 16 × 16 footprint; this button opens chapter recap but does not contain or reserve a persistent recap panel. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using oxygen blue and neutrals without implying a resource or stability state. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal structure; use no colored exterior outline and keep all pixels on the integer grid. Forbidden elements: recap-panel content, chapter list, task list, minimap, achievement bar, resource counter, timeline, readable text, letters, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, oversized hit art, or decorative badges.

## 6. Acceptance checks

- Draw all six region rectangles on a `640 × 360` canvas. Their intersection areas must all be zero, every right/bottom edge must remain at or below `640/360`, and their union must equal the full canvas.
- Recalculate `25,600 ÷ 230,400 × 100`; the result must be approximately `11.11%`, below the one-quarter limit.
- View the task row at native scale and verify that transport pressure, waste accumulation, and signal coverage remain visible together in the same horizontal region. Allocate 4 seconds to each reading in a left-to-right sweep; all three must be read within 12 seconds without opening, scrolling, tabbing, or moving to another panel.
- Confirm that no seventh persistent region, minimap, achievement bar, or task list appears. The two entry buttons must remain inside the already reserved task row and add zero pixels to the persistent UI height.

## 7. D-17 information-container capacity

The D-17 immediate prompt is split by D-17a into four urgency tiers: broadcast, attribution, pressure, and alert. All four are non-modal, pointer-transparent, and self-dismissing. They extend downward from the lower edge of the reserved top UI at `y = 40`; they are not a seventh persistent UI region. Only an alert in assist mode may wait for a manual dismissal. The organ archive remains a paused modal at `Rect2(40,28,560,304)`, and the chapter summary remains a paused modal at `Rect2(48,28,544,304)`.

G1a-G1d notifications use the project pixel font at its native `10 px` size. Capacity calculations reserve a `10 px` advance for each full-width Chinese character and a fixed `10 px` line height. T-31 and T-34 must treat every notification character count below as a hard maximum. Runtime code truncates and prints a `[UI]` warning; it may not shrink the font, add scrolling, paginate, fold content, or expand a container.

The requested D-17a height baselines `20/32/32/40 px` conflict with the requirement that both dimensions be whole multiples of the locked `16 px` tile edge. The smallest compliant upward adjustment is:

```text
broadcast_height = ceil(20 ÷ 16) × 16 = 32 px = 2T
attribution_height = 32 px = 2T
pressure_height = 32 px = 2T
alert_height = ceil(40 ÷ 16) × 16 = 48 px = 3T
```

Widths already satisfy the rule: `112 = 7T`, `128 = 8T`, and `144 = 9T`.

The right edge is locked to `x = 640`, so each anchor derives as `anchor_x = 640 - width`. The first card starts at `anchor_y = reserved_ui_height = 40`. A `4 px` vertical gap separates cards. Three broadcasts therefore occupy:

```text
broadcast_1 = Rect2(528, 40, 112, 32)
broadcast_2_y = 40 + (32 + 4) = 76
broadcast_3_y = 40 + 2 × (32 + 4) = 112
stack_bottom = 112 + 32 = 144 px < 360 px
```

The three-card stack stays `216 px` above the screen bottom.

### Table G1a — Broadcast prompt capacity

| Container size | Top-right anchor | Vertical gap | Border | Inner padding | Icon / rail allocation | Font | Line height | Maximum lines | Hard maximum Chinese characters per line | Entry / exit |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `112 × 32 px` (`7T × 2T`) | `(528,40)` | `4 px` | `1 px` | `4 px` horizontal / `5 px` vertical | `1 px` rail + `8 px` icon + `2 px` gap | `10 px` | `10 px` | **1** | **9** | `160 ms / 180 ms` |

```text
text_width = 112 - 2 × 1 border - 2 × 4 padding - 1 rail - 8 icon - 2 gap = 91 px
characters_per_line = floor(91 ÷ 10) = 9
```

Broadcast is a square-corner confirmation card. Its entry divides one `16 px` cell into two `8 px` halves, then unfolds horizontally like cell division. It holds without pulse. On exit it contracts to one cell and flies to the mapped resource icon or map marker; it never fades in place.

### Table G1b — Attribution prompt capacity

| Container size | Top-right anchor | Vertical gap | Border | Inner padding | Icon / rail allocation | Font | Line height | Maximum lines | Hard maximum Chinese characters per line | Entry / exit |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `128 × 32 px` (`8T × 2T`) | `(512,40)` | `4 px` | `1 px` | `4 px` horizontal / `5 px` vertical | `2 px` rail + `8 px` icon + `2 px` gap | `10 px` | `10 px` | **2** | **10** | `260 ms / 240 ms` |

```text
text_width = 128 - 2 × 1 border - 2 × 4 padding - 2 rail - 8 icon - 2 gap = 106 px
characters_per_line = floor(106 ÷ 10) = 10
text_height = 32 - 2 × 1 border - 2 × 5 padding = 20 px = 2 lines
```

Attribution has rounded soft corners. A single bright pixel travels once around the outline like a neural impulse before the two text lines settle. On exit the bright pixel leads the card as it contracts and flies to its mapped target.
During dwell the outline, rail, star, and two settled lines remain still; attribution has no pulse because it explains a cause without demanding immediate action.

### Table G1c — Pressure prompt capacity

| Container size | Top-right anchor | Vertical gap | Border | Inner padding | Icon / rail allocation | Font | Line height | Maximum lines | Hard maximum Chinese characters per line | Entry / exit |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `128 × 32 px` (`8T × 2T`) | `(512,40)` | `4 px` | `2 px` | `4 px` horizontal / `4 px` vertical | `3 px` rail + `16 px` D-16 icon + `2 px` gap | `10 px` | `10 px` | **2** | **9** | `220 ms / 220 ms` |

```text
text_width = 128 - 2 × 2 border - 2 × 4 padding - 3 rail - 16 icon - 2 gap = 95 px
characters_per_line = floor(95 ÷ 10) = 9
text_height = 32 - 2 × 2 border - 2 × 4 padding = 20 px = 2 lines
```

Pressure uses a left-top cut corner. Edge particles seep inward one integer pixel per frame, communicating accumulating load without relying on colour. The icon is one of the three existing D-16 bottleneck markers. Exit reverses the seep, contracts, and flies to the affected organ or resource icon.
During dwell the seep stops at the inner edge while the cut corner, 2-pixel border, 3-pixel rail, and D-16 marker remain fixed, preserving pressure without imitating the alert heartbeat.

### Table G1d — Alert prompt capacity

| Container size | Top-right anchor | Vertical gap | Border | Inner padding | Icon / rail allocation | Font | Line height | Maximum lines | Hard maximum Chinese characters per line | Entry / exit |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `144 × 48 px` (`9T × 3T`) | `(496,40)` | `4 px` | `3 px` | `4 px` horizontal / `11 px` vertical | `4 px` rail + `16 px` D-16 icon + `2 px` gap | `10 px` | `10 px` | **2** | **10** | `240 ms / 280 ms` |

```text
text_width = 144 - 2 × 3 border - 2 × 4 padding - 4 rail - 16 icon - 2 gap = 108 px
characters_per_line = floor(108 ÷ 10) = 10
text_height = 48 - 2 × 3 border - 2 × 11 padding = 20 px = 2 lines
```

Alert combines a left-top cut corner with the thickest border and widest rail. Its D-16 bottleneck marker matches the map marker. During dwell the border performs a one-pixel inward/outward heartbeat at the Balance BPM for the current stability band. A one-pixel arterial-coral leader runs from the card edge toward the mapped organ for the alert dwell; when direct travel would cross an organ silhouette, it takes an orthogonal route around that silhouette’s bounding rectangle with a one-pixel clearance. It may touch the marker but never crosses the organ body. Exit contracts on the heartbeat and flies to that marker. Only assist-mode alerts may expose a close control and wait for it.

### D-17a non-colour encoding matrix

| Tier | Outline shape | Border thickness | Left rail width | Tier icon | Container size | Primary grayscale identifier |
|---|---|---:|---:|---|---:|---|
| Broadcast | Square corners | `1 px` | `1 px` | Dividing-cell glyph | `112 × 32` | Smallest width plus square silhouette |
| Attribution | Rounded soft edge | `1 px` | `2 px` | Knowledge-star impulse glyph | `128 × 32` | Rounded silhouette |
| Pressure | Left-top cut corner | `2 px` | `3 px` | Existing D-16 bottleneck marker | `128 × 32` | Cut corner plus 2-pixel border |
| Alert | Left-top cut corner | `3 px` | `4 px` | Existing D-16 bottleneck marker | `144 × 48` | Unique 3T height plus 3-pixel border |

Every tier simultaneously uses at least two non-colour dimensions. In grayscale, pressure and alert are the easiest pair to confuse because both reuse a D-16 marker and a cut corner. Increasing alert height from `2T` to `3T` is the lowest-cost separation: it changes one permitted dimension, preserves the shared map-marker grammar, and needs no new icon.

Within G1c/G1d the D-16 marker identifies the notification tier and bottleneck family; it never replaces a resource's locked silhouette. Resource identity remains visible in the unchanged resource bar, and a resource notification exits to that existing silhouette. Stability therefore keeps its shield, waste keeps its original resource outline, and shortages keep the hollow investable-resource status encoding at their targets.

Forbidden in all four tiers: gradients, rounded-corner shadows, semi-transparent blur, colours outside the locked palette, scrollbars, pagination, folding, close buttons (except assist-mode alert), and exclamation-mark graphics. No fifth tier, history panel, notification centre, unread count, or seventh persistent UI region is permitted.

The Godot acceptance test measured the project bitmap font at its native `10 px` size with full-width Chinese test glyphs, not an estimated advance. G1a measured `90 px` for 9 glyphs and `100 px` for 10 against `91 px` available; G1b measured `100/110 px` for 10/11 against `106 px`; G1c measured `90/100 px` for 9/10 against `95 px`; G1d measured `100/110 px` for 10/11 against `108 px`. These four maxima are therefore hard measured limits.

### Table G2 — Organ archive capacity

| Container size | Border | Inner padding | Header | Font pixel size | Line height | Maximum lines | Hard maximum Chinese characters per line |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `560 × 304 px` | `2 px` | `12 px` horizontal / `8 px` vertical | `20 px` header + `4 px` gap | `8 px` | `10 px` | **21 total; 3 per field × 7 fields** | **66** |

```text
text_width = 560 - 2 × 2 border - 2 × 12 padding = 532 px
characters_per_line = floor(532 ÷ 8) = 66
field_text_height = 3 × 10 = 30 px
seven_fields = 7 × 30 = 210 px
six_field_gaps = 6 × 6 = 36 px
available_field_height = 304 - 2 × 2 border - 2 × 8 padding - 20 header - 4 gap = 260 px
210 + 36 = 246 px ≤ 260 px
```

The archive has exactly seven fixed field slots, numbered G2-1 through G2-7 in top-to-bottom reading order. Each slot includes its runtime field label in its three-line allocation. All seven remain visible together; unused lines in one field may not be transferred to another field.

### Table G3 — Chapter summary capacity

| Container size | Border | Inner padding | Header | Font pixel size | Line height | Maximum lines | Hard maximum Chinese characters per line |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `544 × 304 px` | `2 px` | `12 px` horizontal / `8 px` vertical | `20 px` header + `4 px` gap | `8 px` | `10 px` | **24 total; 4 per item × 6 items** | **64** |

```text
text_width = 544 - 2 × 2 border - 2 × 12 padding = 516 px
characters_per_line = floor(516 ÷ 8) = 64
item_text_height = 4 × 10 = 40 px
six_items = 6 × 40 = 240 px
five_item_gaps = 5 × 4 = 20 px
available_item_height = 304 - 2 × 2 border - 2 × 8 padding - 20 header - 4 gap = 260 px
240 + 20 = 260 px
```

The six fixed items are: current developmental stage; structures formed in the chapter; newly established system connection; three core knowledge points; before/after change in the body-city; and newly unlocked encyclopedia content. Each item includes its runtime label in its four-line allocation. Stage Two must compress placental and germ-layer content into these same six slots; it may not add a seventh item.

### Table G4 — Event-to-notification mapping

This table contains every `docs/EVENT_API.md` event that enters the shared top-right notification layer. Events omitted here already own a dedicated surface (resource bar, decision panel, archive, timeline, birth presentation, or ending) and must not be duplicated as notifications. All copy keys resolve to placeholders until T-31/T-34 supplies final copy.

| Event name | Notification tier | Copy key | Balance dwell path | Exit target |
|---|---|---|---|---|
| `organ_built` | broadcast | `notification.organ_built` | `notifications.dwell_sec.broadcast` | `map_organ` |
| `operation_result_settled` | attribution | `notification.operation_result` | `notifications.dwell_sec.attribution` | `none` |
| `transport_pressure_appeared` | first attribution; same-stage repeat broadcast | `notification.transport_pressure` | `notifications.dwell_sec.attribution`; repeat uses `.broadcast` | `map_organ` |
| `waste_buildup_appeared` | first attribution; same-stage repeat broadcast | `notification.waste_processing` | `notifications.dwell_sec.attribution`; repeat uses `.broadcast` | `map_organ` |
| `signal_gap_appeared` | first attribution; same-stage repeat broadcast | `notification.signal_coordination` | `notifications.dwell_sec.attribution`; repeat uses `.broadcast` | `map_organ` |
| `transport_pressure_cleared` | broadcast | `notification.transport_recovered` | `notifications.dwell_sec.broadcast` | `map_organ` |
| `waste_buildup_cleared` | broadcast | `notification.waste_recovered` | `notifications.dwell_sec.broadcast` | `map_organ` |
| `signal_gap_cleared` | broadcast | `notification.signal_recovered` | `notifications.dwell_sec.broadcast` | `map_organ` |
| `stability_band_changed` | first downward transition attribution; same-stage downward repeat broadcast; critical transition alert; recovery broadcast | `notification.stability_response` | tier-matched path under `notifications.dwell_sec` | `resource_stability` |
| `waste_overflowed` | alert | `notification.waste_overflow` | `notifications.dwell_sec.alert` | `resource_waste` |
| `resource_shortage_raised` | pressure | `notification.resource_shortage` | `notifications.dwell_sec.pressure` | `resource_argument_0` |
| `resource_shortage_cleared` | broadcast | `notification.resource_recovered` | `notifications.dwell_sec.broadcast` | `resource_argument_0` |
| `minigame_exited` | broadcast | `notification.minigame_resolved` | `notifications.dwell_sec.broadcast` | `none` |
| `minigame_rated` | broadcast | `notification.minigame_rated` | `notifications.dwell_sec.broadcast` | `none` |
| `system_observation_ended` | attribution | `notification.system_observed` | `notifications.dwell_sec.attribution` | `map_organ` |
| `knowledge_entry_unlocked` | broadcast; `hint_neural_tube_compensation` override is attribution | `notification.knowledge_unlocked`; neural-tube override uses `notification.neural_tube_compensation` | `notifications.dwell_sec.broadcast`; neural-tube override uses `.attribution` | `resource_knowledge_badges`; neural-tube override uses argument-1 `map_organ` |
| `delayed_feedback_shown` | attribution | `notification.delayed_feedback` | `notifications.dwell_sec.attribution` | `none` |
| `action_rejected` | pressure | `notification.action_rejected` | `notifications.dwell_sec.pressure` | `none` |
| `birth_sequence_started` | first attribution; same-stage retry broadcast | `notification.birth_transition` | `notifications.dwell_sec.attribution`; retry uses `.broadcast` | `none` |
| `birth_rolled_back` | alert | `notification.birth_retry` | `notifications.dwell_sec.alert` | `none` |

The merge groups are taken only from EVENT_API rows marked `repeatable within one tick`:

- `investable_resource_shortage`: all same-tick `resource_shortage_raised` signals, regardless of which of the three investable resources fired.
- One same-name group each for `organ_built`, the six bottleneck appeared/cleared events, `resource_shortage_cleared`, `knowledge_entry_unlocked`, and `action_rejected`. The `hint_neural_tube_compensation` override is excluded from the knowledge-unlock merge group because table E11 requires that hint never to merge.
- No other G4 row merges. In particular, events marked `at most once per tick`, `once per stage`, or `once per run` never enter a merge group.

Tutorial notifications are the three E11 bottleneck appearances, the neural-tube knowledge-unlock override, downward `stability_band_changed` transitions, `delayed_feedback_shown`, and `birth_sequence_started`. An on-screen alert moves them to the FIFO wait queue. `stage_loaded` clears only the first/repeat counters; it does not generate a notification.

For `stability_band_changed`, only a worsening transition (`current_band > previous_band`) participates in the E11 first/repeat counter. A recovery (`current_band < previous_band`) is a non-tutorial broadcast and does not consume the first later downward attribution.

The neural-tube override deliberately consumes the existing `knowledge_entry_unlocked` event instead of re-deriving gameplay conditions from `signal_gap_appeared`. `BottleneckDetector` emits that entry only for `stage_circulation` when transport coverage limits signal in the same settlement. The override supersedes the still-pending generic `signal_gap_appeared` card, so the E11 compensation case produces one explanation rather than both the compensation and outside-compensation copy. It also remains outside the knowledge-unlock merge group.

`NotificationQueue` does not implement the once-per-save guard and never reads or writes a save. `BottleneckDetector` owns the runtime guard and exposes it in `snapshot_state`; persisting and restoring that upstream snapshot remains a T-18/T-27 integration responsibility. The presentation layer stays stateless as required.

T-30b exposes assist-mode presentation hooks, but does not connect them directly to `HintSystem`: the accepted EventBus API has no assist-mode signal, and this layer may subscribe only to EventBus. T-33a must route its assist state through an accepted EventBus mount point before the production queue can consume it.

### G4 dwell-time budget for the 1068-second route

The estimate uses the accepted no-rollback walkthrough, counts cards after required same-tick merging, and charges each card its full dwell even when cards overlap on screen. This is deliberately more conservative than wall-clock visibility.

| G4 event or group | Presented cards | Dwell each | Budget |
|---|---:|---:|---:|
| `organ_built` merged by stage tick | 4 | 1.5 s | 6.0 s |
| `operation_result_settled` | 4 | 3.0 s | 12.0 s |
| Three E11 bottleneck-appearance rows | 12 | 3.0 s | 36.0 s |
| Three bottleneck-cleared rows | 12 | 1.5 s | 18.0 s |
| `stability_band_changed` (charged at alert dwell) | 4 | 4.0 s | 16.0 s |
| `waste_overflowed` | 2 | 4.0 s | 8.0 s |
| `resource_shortage_raised` merged by stage tick | 4 | 2.5 s | 10.0 s |
| `resource_shortage_cleared` merged by stage tick | 4 | 1.5 s | 6.0 s |
| `minigame_exited` | 3 | 1.5 s | 4.5 s |
| `minigame_rated` | 3 | 1.5 s | 4.5 s |
| `system_observation_ended` | 4 | 3.0 s | 12.0 s |
| Generic `knowledge_entry_unlocked` merged by stage tick | 4 | 1.5 s | 6.0 s |
| Never-merge neural-tube knowledge override | 1 | 3.0 s | 3.0 s |
| First-impact `delayed_feedback_shown` rows | 3 | 3.0 s | 9.0 s |
| Same-tick `action_rejected` validation group | 1 | 2.5 s | 2.5 s |
| `birth_sequence_started` | 1 | 3.0 s | 3.0 s |
| `birth_rolled_back` on accepted route | 0 | 4.0 s | 0.0 s |
| **Total** | **69** | — | **156.5 s** |

`156.5 s <= 160 s`, leaving `3.5 s` of the fixed observation-and-immediate-prompt budget. Assist mode may lengthen dwell for accessibility, but it does not alter the authored 160-second route budget, event count, tier, order, or copy.

## 8. D-17 English PixelLab descriptions

### G1a broadcast prompt

Create one native-resolution broadcast prompt frame for “Metabolis: Birth of the City of Life,” exactly 112 × 32 pixels (`7T × 2T`) at reference anchor `(528,40)`, with square corners, an opaque `#514854` surface, a 1-pixel `#140F1D` exterior border, a 1-pixel oxygen-blue left rail, a reserved 8-pixel dividing-cell tier-icon slot, and integer-pixel geometry. Reserve one 10-pixel line for the project pixel font at its native 10-pixel size and leave all copy to runtime. The frame must read as the smallest, quietest top-bar extension and must support a cell-division entry and a contracting target-seeking exit. Use only the locked 22-colour palette. Forbidden: baked text, close button, modal dimmer, input capture, gradients, shadows, blur, glow, anti-aliasing, partial transparency, pagination, scrolling, folding, an exclamation-mark graphic, or any fifth tier.

### G1b attribution prompt

Create one native-resolution attribution prompt frame for “Metabolis: Birth of the City of Life,” exactly 128 × 32 pixels (`8T × 2T`) at reference anchor `(512,40)`, with a rounded soft-edge silhouette drawn on integer pixels, an opaque `#514854` surface, a 1-pixel `#140F1D` exterior border, a 2-pixel oxygen-blue left rail, and a reserved 8-pixel knowledge-star impulse icon slot. Reserve two 10-pixel lines for the project pixel font at its native 10-pixel size. The perimeter must provide a continuous one-pixel route for a single bright pixel to travel once like a neural impulse before the text settles. Use only the locked palette and leave all prose to runtime. Apply the same forbidden list as G1a; do not add a title row or close control.

### G1c pressure prompt

Create one native-resolution pressure prompt frame for “Metabolis: Birth of the City of Life,” exactly 128 × 32 pixels (`8T × 2T`) at reference anchor `(512,40)`, with a clearly cut top-left corner, an opaque `#514854` surface, a 2-pixel `#140F1D` exterior border, a 3-pixel semantic left rail, and one reserved unscaled 16 × 16 slot that directly reuses the matching D-16 transport-pressure, waste-accumulation, or signal-coverage marker. Reserve two 10-pixel lines for the project pixel font at its native 10-pixel size. The edge must support integer-pixel particles seeping inward during entry and reversing before a target-seeking exit. Use oxygen blue for teaching, cold blue-violet for waste, and only existing locked semantics. Apply the G1a forbidden list; never invent a fourth bottleneck marker.

### G1d alert prompt

Create one native-resolution alert prompt frame for “Metabolis: Birth of the City of Life,” exactly 144 × 48 pixels (`9T × 3T`) at reference anchor `(496,40)`, with a cut top-left corner, an opaque `#514854` surface, a 3-pixel `#140F1D` clipped-corner exterior border, a 4-pixel arterial-coral left rail, and one reserved unscaled 16 × 16 slot that directly reuses the matching D-16 bottleneck marker. Reserve two 10-pixel lines for the project pixel font at its native 10-pixel size. The border must support a one-pixel heartbeat contraction at the runtime Balance BPM, plus a one-pixel arterial-coral orthogonal leader that avoids the mapped organ silhouette. Use only locked colours. Apply the G1a forbidden list; the only permitted close control is the assist-mode alert exception, and it must occupy existing padding without adding a row.

### Organ archive

Create one native-resolution paused organ-archive modal frame for “Metabolis: Birth of the City of Life,” exactly 560 × 304 pixels for placement at reference-canvas Rect2(40,28,560,304), with a fully opaque #514854 backing, a consistent 2-pixel #140F1D exterior outline, 12-pixel horizontal and 8-pixel vertical inner padding, a 20-pixel header followed by a 4-pixel gap, and seven fixed top-to-bottom field blocks separated by 6 pixels. Reserve exactly three 10-pixel lines per field for the Godot built-in font at 8-pixel size, keep all seven fields visible at once, and place a persistent two-bar pause symbol in the header using existing palette colors so the paused state remains visible without text; opening this modal pauses operation time and resource settlement, and closing it resumes both. Use tissue-pink accents only for archive hierarchy and neutral colors for backing and separators. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply one uniform 2-pixel exterior outline in #140F1D and 1-pixel #514854 internal separators, with no colored exterior outline and no mixed outline width on the modal perimeter. Forbidden elements: eighth field, scrollbar, pagination, tabs, folding, collapsible sections, auto-expanding fields, font shrinking, gradients, rounded-corner shadows, semi-transparent blur, frosted glass, feathering, anti-aliasing, glow, colors outside the locked palette, baked prose, anatomy, blood, or an invisible pause state.

### Chapter summary

Create one native-resolution paused chapter-summary modal frame for “Metabolis: Birth of the City of Life,” exactly 544 × 304 pixels for placement at reference-canvas Rect2(48,28,544,304), with a fully opaque #514854 backing, a consistent 2-pixel #140F1D exterior outline, 12-pixel horizontal and 8-pixel vertical inner padding, a 20-pixel header followed by a 4-pixel gap, and exactly six fixed top-to-bottom item blocks separated by 4 pixels. Reserve exactly four 10-pixel lines per item for the Godot built-in font at 8-pixel size, keep all six items visible at once, and place a persistent two-bar pause symbol in the header using existing palette colors so the paused state remains visible without text; opening this modal pauses operation time and resource settlement, and closing it resumes both. The six visual slots must remain fixed for current stage, structures formed, new system connection, three core knowledge points, before/after body-city change, and newly unlocked encyclopedia content, with no seventh slot even when Stage Two combines placental and germ-layer content. Use exactly and only the locked palette #340106, #BA3A3F, #C25453, #48A5CF, #7AD1FD, #CDD9E1, #29314A, #404586, #53548C, #91465F, #BE6E87, #C98197, #B26C09, #E2953A, #DDAD7E, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply one uniform 2-pixel exterior outline in #140F1D and 1-pixel #514854 internal separators, with no colored exterior outline and no mixed outline width on the modal perimeter. Forbidden elements: seventh item, scrollbar, pagination, page dots, tabs, folding, collapsible sections, auto-expanding items, font shrinking, gradients, rounded-corner shadows, semi-transparent blur, frosted glass, feathering, anti-aliasing, glow, colors outside the locked palette, baked prose, anatomy, blood, or an invisible pause state.

## 9. D-13b Candidate-card comparison area

The build-decision phase overlays a row of candidate cards on top of the main city map. Every card shares one identical outer frame and one identical internal row template. Runtime composable rows and the PixelLab card-art slot must not alter the per-card rectangle, grid-aligned placement, or layout rule.

### Card outer rectangle

| Property | Value | px |
|---|---:|---:|
| Card width | `148 px` | 148 |
| Card height | `262 px` | 262 |
| Exterior border | `2 px` uniform `#140F1D` | 2 |
| Inner padding | `8 px` horizontal / `8 px` vertical | 8 |
| Content width | `148 − 2 × 2 − 2 × 8 = 128 px` | 128 |
| Content height | `262 - 2 x 2 - 2 x 8 = 242 px` | 242 |

Godot notation: `Rect2(0, 0, 148, 262)` before placement.

### Card-to-card spacing

| Candidate count | Gap between cards | px |
|---|---:|---:|
| 2 | `248 px` | 248 |
| 3 | `16 px` | 16 |
| 4 | `16 px` | 16 |

### Deterministic placement rule

The card row is centered on the reference canvas. For `N` cards at width `148 px` each:

```
total_width = N × 148 + (N − 1) × gap
margin_x = (640 − total_width) / 2
card_x[i] = margin_x + i × (148 + gap)   for i = 0 … N−1
card_y = 40 + (320 - 262) / 2 = 69
```

| N | `total_width` | `margin_x` | `card_x` positions |
|---|---:|---:|---|
| 2 | `544` | `48` | `48`, `344` |
| 3 | `476` | `82` | `82`, `246`, `410` |
| 4 | `640` | `0` | `0`, `164`, `328`, `492` |

All card `card_y` coordinates are `69`. The card row does not overlap the persistent top-40-pixel UI strip. All coordinates are integer pixels.

### Card internal row template

Every card reserves the following vertical allocation inside its `128 x 242 px` content area. The PixelLab concept-art slot occupies the largest flat rectangle.

| Row | Height | Content | Runtime label or slot |
|---|---:|---|---|
| Concept art | `128 px` | PixelLab-generated candidate illustration at `128 × 128 px`, integer-pixel placement, `22`-color locked palette | Image slot, no text |
| Art-to-name gap | `4 px` | Transparent spacer | — |
| Candidate name | `12 px` | `8 px` Godot built-in font, left-aligned, one line | Runtime option name |
| Name-to-metrics gap | `4 px` | Transparent spacer | — |
| Metric row (×3) | `22 px` each | `8 px` font label left, `128 × 12 px` comparison bar below; three rows for network efficiency, build duration, future convenience | Runtime values, units, and normalized bars |
| Metrics-to-cost gap | `4 px` | Transparent spacer | — |
| Resource cost row | `24 px` | Three `36 × 16 px` cost cells (nutrient energy, cell material, developmental signal), each with a `16 × 16 px` resource-icon slot and a runtime-value slot | Runtime cost values |

Total content height: `128 + 4 + 12 + 4 + 3 x 22 + 4 + 24 = 242 px`, exactly matching the available content height.

### Required PixelLab card art (D-13b)

The concept-art slot is `128 × 128 px` and must contain exactly one PixelLab-generated candidate illustration per build option. Each illustration shows the candidate organ, district, or interface in a top-down orthographic view matching the main city-map style. Every illustration uses the locked `22`-color palette, binary alpha, `1`-pixel `#140F1D` exterior outlines, and `#514854` internal structure lines. Forbidden: baked text, baked metric numbers, comparison bars, cost icons, minimap elements, gradients, anti-aliasing, partial transparency, or colors outside the palette. The art distinguishes candidates through silhouette, structure, and construction-stage markers without text.

Seven build decisions × two options = fourteen `128 × 128 px` candidate art slots. Each slot is addressed by `build_decision_id` and `build_option_id` from `BUILD_DECISION_SPEC.md` Table D1.

### D-13b acceptance

- Draw the six region rectangles from Section 2 plus the card placement rectangle for `N = 2, 3, 4`. No overlap with the persistent top-40-pixel UI strip, and all rectangles must remain within `Rect2(0, 0, 640, 360)`.
- Fill one card with Chinese test characters in the `8 px` Godot font and verify that `128 px` accommodates 16 characters at full width and that three metric labels, three `128 px` comparison bars, one candidate name, and three cost cells fit without clipping.
- Verify that the art slot is square at `128 × 128 px` and contains no baked text, baked metrics, or out-of-palette colors.

## 10. D-17 acceptance

- Draw the G1a-G1d variants at their exact native sizes and fill them with the project `10 px` full-width Chinese test characters. G1a must fit 9 characters on one line, G1b 10 characters on each of two lines, G1c 9 characters on each of two lines, and G1d 10 characters on each of two lines. Retain the separately authored G2/G3 modal-capacity checks.
- Open the organ archive and chapter summary for 30 real-time seconds each. Their two-bar pause symbols must remain visible, and operation time, resource settlement, and map simulation values must remain unchanged until close.
- Emit each G4 tier during an operation, attempt map and UI input through every card rectangle, and wait for each Balance-defined duration. Input must remain available and all cards must self-dismiss; only an alert while assist mode is active may wait for its close control.
- Search the document and generated frames for scrollbars, pagination, page dots, folding controls, and collapsed sections. Any occurrence fails D-17; over-capacity copy must be shortened by T-31.
