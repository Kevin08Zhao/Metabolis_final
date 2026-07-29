# D-29 Title Scene Integration Spec

## Status

Background production is complete. Runtime title scene contract is documented below.
The accepted text-free title background (`art/backgrounds/background_title.png`)
is palette-quantized, integer-scaled to 640x360, and must not be regenerated.

## Title Scene Layout (640×360 px)

| Region | Rectangle | Content |
|---|---|---|
| Background | `Rect2(0, 0, 640, 360)` | Accepted D-29 title background (already generated) |
| Title band | `Rect2(160, 80, 320, 40)` | Runtime "Metabolis: Birth of the City of Life" — Godot 8px font, centered |
| Education disclaimer | `Rect2(80, 300, 480, 20)` | Runtime disclaimer text — 8px font, centered, one line |
| Entry button (Start) | `Rect2(240, 200, 160, 32)` | "Begin" — enabled when build_options loaded |
| Entry button (Continue) | `Rect2(240, 240, 160, 32)` | "Continue" — enabled when save snapshot exists |
| Subtle pulse | Heart organ at map center | One outward pulse every 3 seconds, mint green #B1FFD1, 2px expansion |

## Required real screenshots (5)

1. **Title idle**: Full 640×360, all elements visible, no interaction
2. **Title with hover**: New Game button focused
3. **Title education disclaimer visible**: Full disclaimer visible without scrolling
4. **Transition to game**: First playable game frame after New Game
5. **Ending screen with title**: Ending scene with full title text

## Verification

1. Open the title scene in Godot 4.7.1.
2. Verify background renders at 640×360 with no palette violations.
3. Click "Begin" and verify scene transition to stage_origin.
4. Click "Continue" (with save present) and verify scene restoration.
5. Take 5 real screenshots matching the list above.
6. Verify the subtle pulse does not overlap the entry buttons.
7. Verify education disclaimer text fits in one line at 8px font.

## Completion

The runtime scenes and routing exist. The accepted background is loaded through
`AssetLoader`, the title uses the engine font, the disclaimer fits its one-line
band, the three-second mint pulse is active, and the five screenshots under
`art/screenshots/` were captured from Godot 4.7.1.
