# D-17 Information-Container Manifest

task_id: D-17
status: DONE
source: `docs/prompts/Metabolis_Prompts_Full_v2.md` D-17
specification: `docs/UI_LAYOUT.md` sections 7-9

The original D-17 deliverable is three capacity tables plus three English PixelLab descriptions. It does not require generated PNGs. Reserved filenames and seeds are recorded for downstream visual production.

| Container | Reserved static-image filename | Native canvas | Reserved seed | Hard text capacity |
|---|---|---:|---:|---|
| Immediate knowledge prompt | `ui_prompt_knowledge.png` | `224 × 32 px` | `17001` | 2 lines; 26 full-width Chinese characters per line |
| Organ archive | `ui_modal_organ_archive.png` | `560 × 304 px` | `17002` | 7 fields × 3 lines; 66 characters per line |
| Chapter summary | `ui_modal_chapter_summary.png` | `544 × 304 px` | `17003` | 6 items × 4 lines; 64 characters per line |

## Checks

- G1 text width is `224 - 2 × 1 - 2 × 7 = 208 px`; `floor(208 / 8) = 26`: PASS
- G2 text width is `560 - 2 × 2 - 2 × 12 = 532 px`; `floor(532 / 8) = 66`: PASS
- G3 text width is `544 - 2 × 2 - 2 × 12 = 516 px`; `floor(516 / 8) = 64`: PASS
- A reference render using an 8-pixel full-width CJK test glyph measured `208 px`, `528 px`, and `512 px` for the G1, G2, and G3 line maxima and showed no vertical overflow: PASS
- Seven archive fields and six summary items fit without scrolling or pagination: PASS
- Immediate prompt is specified as pointer-transparent and self-dismissing: PASS
- Both reading modals specify a persistent non-text pause symbol: PASS
- All three descriptions use the final palette and forbid gradients, rounded-corner shadows, semi-transparent blur, and out-of-palette colors: PASS

The reference render validates this specification's hard capacity. Runtime font loading, pause behavior, pointer pass-through, and timed dismissal remain downstream implementation checks; this manifest does not claim that those Godot controls already exist.
