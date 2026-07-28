# D-07 Terrain and Tissue Tile PixelLab Prompts

## Empty ground

Create one functional seamless empty-ground terrain tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent-capable PNG canvas, designed to repeat edge-to-edge on the locked square grid with every pixel and feature aligned to integer coordinates and with the left/right and top/bottom edge patterns matching exactly. Depict a quiet, low-detail, non-semantic ground surface using primarily #514854 and #817582, with no directional marks and no focal feature, so simultaneous background construction remains subordinate to the current construction zone. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply the project-wide outline rule: #140F1D is the only exterior-outline color and is exactly 1 native pixel wide, while #514854 is used for internal dark structure; because this is an interior repeating ground tile, do not draw an outline around the 16 × 16 canvas edge and reserve #140F1D for a true semantic boundary. Keep all shading as hard pixel clusters, keep alpha fully transparent or fully opaque, and create no decorative variants. Forbidden elements: anatomical detail, organs, blood, wounds, gradients, anti-aliasing, feathering, blur, text, labels, UI elements, smooth vector curves, partial transparency, colors outside the locked palette, isolated decoration, flowers, debris, or props.

## Tissue ground

Create one functional seamless organic-tissue ground tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent-capable PNG canvas, designed to repeat edge-to-edge on the locked square grid with every pixel and feature aligned to integer coordinates and with identical continuation at opposite edges. Build the surface from #91465F, #BE6E87, and #EC98B1 as a restrained field of irregular 2 × 2 and 3 × 2 pixel clusters with no single cluster acting as a landmark, no directional stripe, and no feature crossing an edge unless it continues at the corresponding opposite edge; the result must read as warm organic city terrain, not anatomy. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply the project-wide outline rule: #140F1D is the only exterior-outline color and is exactly 1 native pixel wide, while #514854 is used for internal dark structure; do not outline the 16 × 16 tile canvas, and use #140F1D only where a separate boundary tile marks the exterior edge of a tissue region. Keep all shading as hard integer-pixel clusters, keep alpha fully transparent or fully opaque, and create no decorative variants. Forbidden elements: anatomical detail, veins, cells drawn as literal biology, blood, wounds, gradients, anti-aliasing, feathering, blur, text, labels, UI elements, smooth vector curves, partial transparency, colors outside the locked palette, isolated decoration, pores, hair, or props.

## Tissue boundary

Create the complete minimal four-neighbor tissue-boundary set for “Metabolis: Birth of the City of Life” as sixteen independent 16 × 16 native-pixel PNG tiles representing every binary continuation combination of north, east, south, and west: isolated, N, E, S, W, NS, EW, NE, ES, SW, WN, NES, ESW, SWN, WNE, and NESW. Sixteen is required because each of the four grid edges independently either continues tissue or meets empty ground, producing 2^4 = 16 combinations; this is the minimum set that can form any closed orthogonal region while covering isolated pieces, end caps, straight runs, corners, T-junctions, and a fully surrounded interior tile. Align every continuation exactly to the locked 16-pixel square grid, make matching edge pixels identical, keep the tissue side in #91465F, #BE6E87, and #EC98B1, keep the empty side in #514854 and #817582, and draw one continuous 1-native-pixel #140F1D exterior outline only where tissue meets empty ground; never draw a double outline along two connected tissue edges, and use #514854 for any internal dark structure. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Keep all curves as deliberate one-pixel stair steps, keep alpha fully transparent or fully opaque, and create no decorative variants beyond the sixteen required connectivity states. Forbidden elements: anatomical detail, literal skin or flesh, blood, wounds, gradients, anti-aliasing, feathering, blur, text, labels, UI elements, smooth vector curves, partial transparency, colors outside the locked palette, decorative corner motifs, debris, or props.

## Construction-zone underlay

Create two functional seamless construction-zone underlay tiles for “Metabolis: Birth of the City of Life,” one focused-current-zone tile and one subdued-background-synchronous-construction tile, each exactly 16 × 16 native pixels on a transparent PNG canvas and aligned edge-to-edge to the locked square grid with every hatch segment, corner tick, and gap placed on integer pixels and continuing identically across opposite edges. Both tiles must remain distinguishable from tissue ground without color: use a fixed one-pixel 45-degree diagonal hatch at a four-pixel pitch plus orthogonal blueprint corner ticks, while ordinary tissue ground contains only irregular unoriented 2 × 2 and 3 × 2 clusters; never replace this texture distinction with color alone. For the focused tile, use #7AD1FD planning lines over the visible #BE6E87 tissue base, producing approximately 24 L* points of grayscale line-to-base contrast; for the background tile, use #48A5CF planning lines over the same base, producing approximately 8 L* points, so background synchronous construction is 14–18 L* points lower in contrast than the focused current zone and contains 30–40% fewer hatch and corner pixels. Use exactly and only the locked palette #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF. Apply the project-wide outline rule: #140F1D is the only exterior-outline color and is exactly 1 native pixel wide, while #514854 is used for internal dark structure; do not outline each repeating 16 × 16 underlay tile, and reserve #140F1D for the closed outer perimeter of the complete construction zone. Keep alpha fully transparent or fully opaque, keep both variants functional rather than decorative, and do not depict construction-in-progress or completed construction. Forbidden elements: anatomical detail, organs, blood, wounds, workers, people, gradients, anti-aliasing, feathering, blur, text, labels, numbers, UI elements, smooth vector curves, partial transparency, colors outside the locked palette, decorative props, tools, or finished structures.

## Exact file list

All files belong in `art/tiles/` and follow the locked `{category}_{subject}_{variant}.png` lowercase `snake_case` template.

| Exact file name | Pixel size | Purpose |
|---|---:|---|
| `tile_terrain_empty.png` | 16 × 16 px | Seamless low-detail empty ground |
| `tile_tissue_ground.png` | 16 × 16 px | Seamless tissue interior; also the NESW boundary state |
| `tile_tissue_isolated.png` | 16 × 16 px | Tissue with no connected neighbor |
| `tile_tissue_n.png` | 16 × 16 px | Tissue continuing north only |
| `tile_tissue_e.png` | 16 × 16 px | Tissue continuing east only |
| `tile_tissue_s.png` | 16 × 16 px | Tissue continuing south only |
| `tile_tissue_w.png` | 16 × 16 px | Tissue continuing west only |
| `tile_tissue_ns.png` | 16 × 16 px | North–south tissue run |
| `tile_tissue_ew.png` | 16 × 16 px | East–west tissue run |
| `tile_tissue_ne.png` | 16 × 16 px | North–east tissue corner |
| `tile_tissue_es.png` | 16 × 16 px | East–south tissue corner |
| `tile_tissue_sw.png` | 16 × 16 px | South–west tissue corner |
| `tile_tissue_wn.png` | 16 × 16 px | West–north tissue corner |
| `tile_tissue_nes.png` | 16 × 16 px | North–east–south tissue junction |
| `tile_tissue_esw.png` | 16 × 16 px | East–south–west tissue junction |
| `tile_tissue_swn.png` | 16 × 16 px | South–west–north tissue junction |
| `tile_tissue_wne.png` | 16 × 16 px | West–north–east tissue junction |
| `tile_construction_focus.png` | 16 × 16 px | Blueprint underlay for the current construction zone |
| `tile_construction_background.png` | 16 × 16 px | Lower-contrast, lower-detail blueprint underlay for synchronous background construction |

## Three-minute tiling self-check

1. **0:00–1:00 — repeat seams:** At 100% zoom with nearest-neighbor display, fill a 5 × 5 block with each of `tile_terrain_empty.png`, `tile_tissue_ground.png`, `tile_construction_focus.png`, and `tile_construction_background.png`. Scan every x/y line at 16-pixel intervals; reject any visible gap, doubled line, broken hatch, or cluster that terminates at one edge without continuing from the opposite edge.
2. **1:00–2:00 — closed boundary:** Build a 3 × 3 tissue island using rows `ES / ESW / SW`, `NES / NESW / SWN`, and `NE / WNE / WN`, with empty-ground tiles around it. The `#140F1D` perimeter must form one closed one-pixel loop, and the eight internal shared edges must contain neither a seam nor a double outline.
3. **2:00–3:00 — grayscale hierarchy:** Convert the test block to grayscale. Confirm that tissue ground still reads as irregular, unoriented clusters; both construction underlays still read as ordered 45-degree hatch plus orthogonal ticks; and the background construction variant is visibly quieter than the focused variant without disappearing.

## Grayscale distinction

Tissue ground is encoded by irregular, unoriented 2 × 2 and 3 × 2 clusters. Construction-zone underlay is encoded by a one-pixel 45-degree hatch on a fixed four-pixel rhythm plus orthogonal corner ticks. The focused and background underlays retain the same non-color grammar, while differing in line-to-base contrast and detail density. Therefore the construction location remains identifiable after color removal, and background synchronous construction cannot acquire the visual weight of the current construction zone.
