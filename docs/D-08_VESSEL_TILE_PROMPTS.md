# D-08 Vessel Tile PixelLab Prompts

## Interface alignment specification

- Every vessel tile is exactly `16 × 16` native pixels with the top-left anchor `(0,0)` and a transparent background.
- Pixel positions in this specification are **1-based**. On every active north, east, south, or west tile edge, the complete vessel interface begins at edge pixel **5** and is **8 pixels wide**, occupying edge pixels **5–12 inclusive**.
- Within that 8-pixel interface, edge pixels **5** and **12** are the two 1-pixel flanks in the global outline `#140F1D`; edge pixels **6–11 inclusive** are the 6-pixel road fill in the single base color `#BA3A3F`.
- The interface centerline lies between edge pixels **8** and **9**. An active interface reaches the canvas edge without an end-cap outline; only its two side outlines reach that edge. An inactive edge has no vessel pixels.
- Every interior arm preserves the same 8-pixel total width and 6-pixel fill width until it joins the central road surface. Junction interiors contain one continuous `#BA3A3F` surface with no hole, divider, arrow, lane marking, or status texture.
- All source tiles use integer pixels, fully transparent or fully opaque alpha, and the same edge rows. Rotation reuse is restricted to lossless quarter turns of the complete `16 × 16` canvas with nearest-neighbor sampling and no trimming.

## Straight

Create one canonical north-to-south straight vessel-road tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent PNG canvas with top-left anchor (0,0), designed to overlay the completed tissue-ground tile. Connect only the north and south edges; on each active edge, using 1-based pixel positions, start at edge pixel 5 and occupy pixels 5–12 inclusive for an 8-pixel total interface, with #140F1D at flank pixels 5 and 12 and the single road base color #BA3A3F at fill pixels 6–11; place the centerline between pixels 8 and 9, carry the same width continuously through the tile, and draw no end cap at either active edge. Align every pixel to the locked 16-pixel square grid. Apply the global outline rule with exactly one native pixel of #140F1D on both exterior flanks and no object-specific outline color; do not use shading, highlights, or any other visible fill color. The locked project palette is #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, but this geometry tile may visibly use only #BA3A3F and #140F1D. Forbidden elements: direction arrows, directional color coding, dashed or crossed status textures, lane markings, traffic signals, highlights, shadows, gradients, anti-aliasing, blur, feathering, partial transparency, text, labels, UI, anatomy, blood, tissue detail baked into the tile, colors outside the locked palette, crossings, overpasses, bridges, tunnels, or decorative variants.

## Corner

Create one canonical north-to-east right-angle vessel-road corner tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent PNG canvas with top-left anchor (0,0), designed to overlay the completed tissue-ground tile. Connect only the north and east edges; on both active edges, using 1-based pixel positions, start at edge pixel 5 and occupy pixels 5–12 inclusive for an 8-pixel total interface, with #140F1D at flank pixels 5 and 12 and the single road base color #BA3A3F at fill pixels 6–11; place each centerline between pixels 8 and 9, bend the road through one compact grid-aligned quarter turn, keep one continuous 6-pixel fill through the bend, and draw no end cap at either active edge. Align every pixel to the locked 16-pixel square grid. Apply the global outline rule with exactly one native pixel of #140F1D around the exterior sides of the bend and no object-specific outline color; do not use shading, highlights, or any other visible fill color. The locked project palette is #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, but this geometry tile may visibly use only #BA3A3F and #140F1D. Forbidden elements: direction arrows, directional color coding, dashed or crossed status textures, lane markings, traffic signals, highlights, shadows, gradients, anti-aliasing, blur, feathering, partial transparency, text, labels, UI, anatomy, blood, tissue detail baked into the tile, colors outside the locked palette, diagonal shortcuts, crossings, overpasses, bridges, tunnels, or decorative variants.

## Three-way junction

Create one canonical north-east-south three-way vessel-road junction tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent PNG canvas with top-left anchor (0,0), designed to overlay the completed tissue-ground tile. Connect only the north, east, and south edges; on every active edge, using 1-based pixel positions, start at edge pixel 5 and occupy pixels 5–12 inclusive for an 8-pixel total interface, with #140F1D at flank pixels 5 and 12 and the single road base color #BA3A3F at fill pixels 6–11; place every centerline between pixels 8 and 9, merge all three 6-pixel fills into one continuous central road surface with no hole, and draw no end cap on an active edge while keeping the west edge fully inactive. Align every pixel to the locked 16-pixel square grid. Apply the global outline rule with exactly one native pixel of #140F1D around the exterior perimeter of the joined road and no object-specific outline color; do not outline the internal meeting seams and do not use shading, highlights, or any other visible fill color. The locked project palette is #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, but this geometry tile may visibly use only #BA3A3F and #140F1D. Forbidden elements: direction arrows, directional color coding, dashed or crossed status textures, lane markings, traffic signals, highlights, shadows, gradients, anti-aliasing, blur, feathering, partial transparency, text, labels, UI, anatomy, blood, tissue detail baked into the tile, colors outside the locked palette, a fourth arm, crossings, overpasses, bridges, tunnels, or decorative variants.

## Four-way junction

Create one four-way at-grade vessel-road junction tile for “Metabolis: Birth of the City of Life,” exactly 16 × 16 native pixels on a transparent PNG canvas with top-left anchor (0,0), designed to overlay the completed tissue-ground tile. Connect the north, east, south, and west edges; on every active edge, using 1-based pixel positions, start at edge pixel 5 and occupy pixels 5–12 inclusive for an 8-pixel total interface, with #140F1D at flank pixels 5 and 12 and the single road base color #BA3A3F at fill pixels 6–11; place every centerline between pixels 8 and 9, merge all four 6-pixel fills into one continuous same-level central road surface with no center hole or internal divider, and draw no end cap on any active edge. Align every pixel to the locked 16-pixel square grid. Apply the global outline rule with exactly one native pixel of #140F1D around only the exterior perimeter of the joined road and no object-specific outline color; do not outline internal meeting seams and do not use shading, highlights, or any other visible fill color. The locked project palette is #6F0417, #BA3A3F, #F26B6A, #48A5CF, #7AD1FD, #E8F6FF, #29314A, #404586, #6A6BB0, #91465F, #BE6E87, #EC98B1, #B26C09, #E2953A, #FEC792, #73CD9B, #B1FFD1, #F4FFF8, #140F1D, #514854, #817582, #E8DCCF, but this geometry tile may visibly use only #BA3A3F and #140F1D. Forbidden elements: direction arrows, directional color coding, dashed or crossed status textures, lane markings, traffic signals, highlights, shadows, gradients, anti-aliasing, blur, feathering, partial transparency, text, labels, UI, anatomy, blood, tissue detail baked into the tile, colors outside the locked palette, grade-separated crossings, overpasses, bridges, tunnels, ramps, or decorative variants.

## Direction variants and rotation reuse

| Geometry | Logical variants | Canonical source | Rotation reuse |
|---|---:|---|---|
| Straight | 2: NS, EW | NS | EW is a lossless 90° rotation |
| Corner | 4: NE, ES, SW, WN | NE | The other three are 90°, 180°, and 270° rotations |
| Three-way | 4: NES, ESW, SWN, WNE | NES | The other three are 90°, 180°, and 270° rotations |
| Four-way | 1: NESW | NESW | Rotation produces the same geometry |

The complete geometry system has **11 logical direction variants** but requires only **4 generated source PNGs**. Rotation reuse is allowed because every tile is square, every interface uses the same centered pixels 5–12, and quarter turns preserve integer pixels. Free-angle rotation, interpolation, resampling, trimming, or hand-adjusted rotated copies are forbidden.

## Exact file list

All files belong in `art/tiles/` and follow the locked `{category}_{subject}_{variant}.png` lowercase `snake_case` template.

| Exact file name | Pixel size | Canonical interfaces | Use |
|---|---:|---|---|
| `tile_vessel_straight.png` | 16 × 16 px | NS | Straight source; rotate once for EW |
| `tile_vessel_corner.png` | 16 × 16 px | NE | Corner source; rotate for ES, SW, WN |
| `tile_vessel_tee.png` | 16 × 16 px | NES | Three-way source; rotate for ESW, SWN, WNE |
| `tile_vessel_fourway.png` | 16 × 16 px | NESW | Four-way same-level junction |

**Generated source count: 4. Logical in-game variant count after rotation: 11.**

## Pixel-level splice self-check

At 1600% zoom with nearest-neighbor display, assemble a 5 × 5 double-loop network on transparent or tissue-ground tiles. Use these occupied cells, leaving all unlisted cells empty:

```text
ES   EW   ESW  EW   SW
NS   .    NS   .    NS
NES  EW   NESW EW   SWN
NS   .    NS   .    NS
NE   EW   WNE  EW   WN
```

Use the four generated sources plus lossless quarter-turn variants to build the pattern. It contains every geometry class and every required rotation. The outer boundary has no open interface, while every neighboring occupied pair shares one active interface. Inspect each shared edge: rows or columns 5 and 12 must continue as uninterrupted `#140F1D`, rows or columns 6–11 must continue as uninterrupted `#BA3A3F`, and no other edge pixel may become opaque. Any one-pixel step, cap line, double outline, transparent gap, or fill-width change fails the tile set.
