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
= 12 + 12 + 16
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
| Resource status bar | `Rect2(0, 0, 640, 12)` | 7,680 px² | Full window width × locked 12-pixel row |
| Development timeline | `Rect2(0, 12, 640, 12)` | 7,680 px² | Begins after resource row: `y = 0 + 12` |
| Task and operations panel | `Rect2(0, 24, 608, 16)` | 9,728 px² | `y = 12 + 12`; width `640 - 16 - 16 = 608` |
| Organ archive entry button | `Rect2(608, 24, 16, 16)` | 256 px² | Begins at task-panel right edge |
| Chapter recap entry button | `Rect2(624, 24, 16, 16)` | 256 px² | Begins at `608 + 16`; ends at `x = 640` |
| Main city map | `Rect2(0, 40, 640, 320)` | 204,800 px² | `y = 360 - 320 = 40`; size `40 × 16` by `20 × 16` |

The six rectangles do not overlap, remain within `Rect2(0,0,640,360)`, and cover the reference canvas exactly:

```text
7,680 + 7,680 + 9,728 + 256 + 256 + 204,800 = 230,400 px²
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

The resource bar simultaneously displays six resources in this fixed order: nutrient energy, cell material, developmental signal, waste, stability, and knowledge badge count. Six `96 × 12 px` cells, five `8 px` gaps, and two `12 px` outer margins fill the row:

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

Create one native-resolution main-city-map background and framing asset for “Metabolis: Birth of the City of Life,” exactly 640 × 320 pixels, representing a 40-column by 20-row grid of 16 × 16 pixel tiles in an orthographic top-down city view beginning below the UI at reference-canvas position (0,40). Show warm organic tissue terrain, grid-aligned transport roads, pump-station and organ-city silhouettes, and subdued synchronous background construction, while leaving current construction readable through stronger local contrast; keep all structures and turns on integer pixels and do not embed any UI into the map. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply a single 1-native-pixel exterior outline in #140F1D and use #514854 only for internal dark structure; use no object-specific outline color. Forbidden elements: minimap, achievement bar, task list, resource bar, timeline, archive button, recap button, text, labels, medical anatomy, blood, wounds, gradients, anti-aliasing, blur, feathering, partial transparency, non-integer scaling, colors outside the locked palette, photographic texture, volumetric light, or decorative UI.

### Development timeline

Create one native-resolution development-timeline strip for “Metabolis: Birth of the City of Life,” exactly 640 × 12 pixels at reference-canvas position (0,12), with a transparent background and a single horizontal integer-pixel path whose milestone sockets, completed span, current position, and remaining span remain readable without baked text; keep every mark inside the 12-pixel height and reserve all labels for runtime rendering. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using oxygen blue only for instructional or current-position emphasis and neutrals for non-semantic frame structure. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal separators; use no colored per-object outline and align every segment to integer pixels. Forbidden elements: minimap, achievement bar, task list, resource counters, operational metric cards, archive button, recap button, readable text, numbers, labels, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, extra rows, vertical timelines, or decorative badges.

### Task and operations panel

Create one native-resolution task-and-operations panel frame for “Metabolis: Birth of the City of Life,” exactly 608 × 16 pixels at reference-canvas position (0,24), divided into three permanently visible adjacent reading cells with no tabs: a 192 × 16 transport-pressure cell from x 0–191, a 192 × 16 waste-accumulation cell from x 192–383, and a 224 × 16 signal-coverage cell from x 384–607. In each cell reserve, from left to right, 3 pixels of padding, a 12-pixel non-color metric-icon slot, a 2-pixel gap, a 32-pixel raw-value slot, a 24-pixel runtime-unit slot, a 72-pixel scale, and the remaining width for current target, net direction, or lowest-coverage organ; keep all three readings visible in one horizontal gaze region and leave every value, unit, range, and target blank for runtime rendering. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply a single 1-native-pixel exterior outline in #140F1D and #514854 internal dividers, with integer-pixel geometry and no per-metric outline color. Forbidden elements: task list, tabs, carousel, page switch, hover-replacement content, minimap, achievement bar, resource bar, timeline, archive button, recap button, baked text, invented units, fixed numeric ranges, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, or additional metric tiers.

### Resource status bar

Create one native-resolution resource-status bar for “Metabolis: Birth of the City of Life,” exactly 640 × 12 pixels at reference-canvas position (0,0), with six permanently visible 96 × 12 resource cells in the fixed order nutrient energy, cell material, developmental signal, waste, stability, and knowledge badge count; place the cells at x 12, 116, 220, 324, 428, and 532, separated by five 8-pixel gaps and bounded by 12-pixel outer margins. Reserve one fixed icon position and one runtime-value slot in every cell, preserve the six locked non-color resource silhouettes, and keep stability as a continuous fill with its current tier texture while knowledge badges remain a count. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, assigning each semantic color only to its locked resource. Apply one 1-native-pixel exterior outline in #140F1D and #514854 internal separators; use no resource-specific outline color and align all icon and value slots to integer pixels. Forbidden elements: a seventh resource, operational metrics, minimap, achievement bar, task list, timeline, archive button, recap button, baked text, invented values, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, extra rows, scrolling, or decorative counters.

### Organ archive entry button

Create one native-resolution organ-archive entry button for “Metabolis: Birth of the City of Life,” exactly 16 × 16 pixels at reference-canvas position (608,24), with a transparent background, a compact organ-record silhouette readable without text, and integer-pixel pressed and unpressed boundaries that do not alter the 16 × 16 footprint; this button opens the archive but does not contain or reserve a persistent archive panel. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using tissue pink and neutrals without implying a resource state. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal structure; use no colored exterior outline and keep all pixels on the integer grid. Forbidden elements: archive panel content, organ list, task list, minimap, achievement bar, resource counter, timeline, readable text, letters, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, oversized hit art, or decorative badges.

### Chapter recap entry button

Create one native-resolution chapter-recap entry button for “Metabolis: Birth of the City of Life,” exactly 16 × 16 pixels at reference-canvas position (624,24), with a transparent background, a compact closed-record silhouette distinct from the organ-archive button without text, and integer-pixel pressed and unpressed boundaries that do not alter the 16 × 16 footprint; this button opens chapter recap but does not contain or reserve a persistent recap panel. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, using oxygen blue and neutrals without implying a resource or stability state. Apply one 1-native-pixel exterior outline in #140F1D and #514854 for internal structure; use no colored exterior outline and keep all pixels on the integer grid. Forbidden elements: recap-panel content, chapter list, task list, minimap, achievement bar, resource counter, timeline, readable text, letters, anatomy, blood, gradients, anti-aliasing, blur, glow, feathering, partial transparency, colors outside the locked palette, smooth vector curves, oversized hit art, or decorative badges.

## 6. Acceptance checks

- Draw all six region rectangles on a `640 × 360` canvas. Their intersection areas must all be zero, every right/bottom edge must remain at or below `640/360`, and their union must equal the full canvas.
- Recalculate `25,600 ÷ 230,400 × 100`; the result must be approximately `11.11%`, below the one-quarter limit.
- View the task row at native scale and verify that transport pressure, waste accumulation, and signal coverage remain visible together in the same horizontal region. Allocate 4 seconds to each reading in a left-to-right sweep; all three must be read within 12 seconds without opening, scrolling, tabbing, or moving to another panel.
- Confirm that no seventh persistent region, minimap, achievement bar, or task list appears. The two entry buttons must remain inside the already reserved task row and add zero pixels to the persistent UI height.

## 7. D-17 information-container capacity

All three containers use the Godot engine’s built-in font at `8 px`. Capacity calculations reserve an `8 px` advance for each full-width Chinese character and a fixed `10 px` line height. T-31 must treat the character counts below as hard maxima. Runtime code may truncate and warn, but may not shrink the font, add scrolling, paginate, collapse a section, or expand a container.

The immediate knowledge prompt is non-modal at `Rect2(400,312,224,32)`. It ignores pointer input, has no close control, appears with the operational result that triggered it, and removes itself after the Balance-defined duration. The organ archive is a paused modal at `Rect2(40,28,560,304)`. The chapter summary is a paused modal at `Rect2(48,28,544,304)`. Opening either modal pauses operation time and resource settlement; both show a two-bar pause symbol in the header throughout the pause.

### Table G1 — Immediate knowledge prompt capacity

| Container size | Border | Inner padding | Font pixel size | Line height | Maximum lines | Hard maximum Chinese characters per line |
|---:|---:|---:|---:|---:|---:|---:|
| `224 × 32 px` | `1 px` | `7 px` horizontal / `5 px` vertical | `8 px` | `10 px` | **2** | **26** |

```text
text_width = 224 - 2 × 1 border - 2 × 7 padding = 208 px
characters_per_line = floor(208 ÷ 8) = 26
text_height = 32 - 2 × 1 border - 2 × 5 padding = 20 px
maximum_lines = floor(20 ÷ 10) = 2
```

The two-line maximum includes all punctuation. A prompt longer than `26 × 2` Chinese character cells must be rewritten; a close label, title row, third line, or overflow indicator may not consume capacity.

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

## 8. D-17 English PixelLab descriptions

### Immediate knowledge prompt

Create one native-resolution immediate-knowledge prompt frame for “Metabolis: Birth of the City of Life,” exactly 224 × 32 pixels for placement at reference-canvas Rect2(400,312,224,32), with a solid opaque #514854 backing, one 1-pixel #140F1D exterior border, 7-pixel horizontal and 5-pixel vertical inner padding, and a subtle 1-pixel oxygen-blue causal-feedback rail kept inside the left padding. Reserve exactly two 10-pixel text lines for the Godot built-in font at 8-pixel size, with no title row and no close control; the prompt must be visually lightweight, must pass pointer input through to the game, must appear concurrently with the operational consequence it explains, and must self-dismiss after its runtime duration. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply the project-wide outline rule with #140F1D as the only exterior outline and #514854 as the opaque backing; keep all corners and edges on integer pixels. Forbidden elements: click-to-close behavior, close button, modal dimmer, input blocking, third text line, title row, scrollbar, pagination, folding, collapsible content, gradients, rounded-corner shadows, semi-transparent blur, frosted glass, feathering, anti-aliasing, glow, colors outside the locked palette, baked text, anatomy, blood, or decorative badges.

### Organ archive

Create one native-resolution paused organ-archive modal frame for “Metabolis: Birth of the City of Life,” exactly 560 × 304 pixels for placement at reference-canvas Rect2(40,28,560,304), with a fully opaque #514854 backing, a consistent 2-pixel #140F1D exterior outline, 12-pixel horizontal and 8-pixel vertical inner padding, a 20-pixel header followed by a 4-pixel gap, and seven fixed top-to-bottom field blocks separated by 6 pixels. Reserve exactly three 10-pixel lines per field for the Godot built-in font at 8-pixel size, keep all seven fields visible at once, and place a persistent two-bar pause symbol in the header using existing palette colors so the paused state remains visible without text; opening this modal pauses operation time and resource settlement, and closing it resumes both. Use tissue-pink accents only for archive hierarchy and neutral colors for backing and separators. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply one uniform 2-pixel exterior outline in #140F1D and 1-pixel #514854 internal separators, with no colored exterior outline and no mixed outline width on the modal perimeter. Forbidden elements: eighth field, scrollbar, pagination, tabs, folding, collapsible sections, auto-expanding fields, font shrinking, gradients, rounded-corner shadows, semi-transparent blur, frosted glass, feathering, anti-aliasing, glow, colors outside the locked palette, baked prose, anatomy, blood, or an invisible pause state.

### Chapter summary

Create one native-resolution paused chapter-summary modal frame for “Metabolis: Birth of the City of Life,” exactly 544 × 304 pixels for placement at reference-canvas Rect2(48,28,544,304), with a fully opaque #514854 backing, a consistent 2-pixel #140F1D exterior outline, 12-pixel horizontal and 8-pixel vertical inner padding, a 20-pixel header followed by a 4-pixel gap, and exactly six fixed top-to-bottom item blocks separated by 4 pixels. Reserve exactly four 10-pixel lines per item for the Godot built-in font at 8-pixel size, keep all six items visible at once, and place a persistent two-bar pause symbol in the header using existing palette colors so the paused state remains visible without text; opening this modal pauses operation time and resource settlement, and closing it resumes both. The six visual slots must remain fixed for current stage, structures formed, new system connection, three core knowledge points, before/after body-city change, and newly unlocked encyclopedia content, with no seventh slot even when Stage Two combines placental and germ-layer content. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply one uniform 2-pixel exterior outline in #140F1D and 1-pixel #514854 internal separators, with no colored exterior outline and no mixed outline width on the modal perimeter. Forbidden elements: seventh item, scrollbar, pagination, page dots, tabs, folding, collapsible sections, auto-expanding items, font shrinking, gradients, rounded-corner shadows, semi-transparent blur, frosted glass, feathering, anti-aliasing, glow, colors outside the locked palette, baked prose, anatomy, blood, or an invisible pause state.

## 9. D-17 acceptance

- Draw the three containers at their exact native sizes and fill them with monospaced `8 px` full-width Chinese test characters. G1 must fit exactly 26 characters on each of two lines; G2 must fit exactly 66 characters per line and three lines in each of seven fields; G3 must fit exactly 64 characters per line and four lines in each of six items.
- Open the organ archive and chapter summary for 30 real-time seconds each. Their two-bar pause symbols must remain visible, and operation time, resource settlement, and map simulation values must remain unchanged until close.
- Show an immediate knowledge prompt during an operation, attempt map and UI input through its rectangle, and wait for its Balance-defined duration. Input must remain available, no close action may be required, and the prompt must remove itself.
- Search the document and generated frames for scrollbars, pagination, page dots, folding controls, and collapsed sections. Any occurrence fails D-17; over-capacity copy must be shortened by T-31.
