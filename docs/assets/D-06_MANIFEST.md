# D-06 PixelLab Style-Master Manifest

task_id: D-06
status: DONE
source: `docs/prompts/Metabolis_Prompts_Full_v2.md` D-06
prompt_artifact: `docs/D-06_PIXELLAB_CONCEPT_PROMPT.md`

## Delivered File

| File | Type | Native dimensions | Grid | SHA-256 |
|---|---|---:|---:|---|
| `art/reference/STYLE_MASTER.png` | Opaque RGBA PNG concept scene | `256 × 160 px` | `16 × 10` cells at `16 px` per cell | `d46390a722fbce77c586d565aa980b912df371c0cfbfd74789f4b98ed8d3f3c7` |

This is the project style reference, not an import-ready heart, road, or construction-zone sprite. Production assets must still use the individual canvases and anchors in `docs/ASSET_SPEC.md`.

## PixelLab Generation Record

| Role | PixelLab tool or model | Job ID | Seed | Result |
|---|---|---|---:|---|
| Rejected first attempt | Pixflux with forced palette | `24e39230-e09a-4007-9c79-8c7e9dd8f019` | `60601` | Rejected: extra buildings, people, text, and unreadable required subjects |
| Rejected composition attempt | Pixflux with forced palette and blockout | `9ca31be9-cc0f-4fb5-a17e-11c1b12ce2f9` | `60602` | Rejected: random pixel noise, semantic color leakage, and inconsistent outline width |
| Style reference | Create Image Pro | `49d33271-86c3-40ba-ac2d-a415d9248309` | `60603` | Accepted only as the mechanical surface-style reference; its geometry drifted from the grid |
| Selected scene | Reference-mode Pro image edit | `95d9507d-e1a4-4a6b-bd5f-e7d92aad7c33` | `60604` | Accepted after palette normalization and isolated-speck cleanup |

The selected PixelLab frame was normalized without dithering to the nearest locked color in CIE L\*a\*b\* space. Disconnected one-to-three-pixel generator specks were removed without moving a silhouette. Amber-like mechanical highlights were reassigned to neutral light, and blue-violet construction shadows were reassigned to neutral dark, so oxygen blue remains the only blueprint signal. No resampling, anti-aliasing, blur, or new color was introduced.

## Exact Pixel Checks

- PNG native dimensions are `256 × 160`: PASS
- Alpha values are fully opaque only; no partial alpha exists: PASS
- The final image contains 11 visible colors, all members of the locked 22-color palette: PASS
- No gradient, anti-aliased edge, blurred pixel, text, UI, character, face, blood, or anatomical cutaway is visible: PASS
- The exterior silhouette color is the single project outline `#140F1D`; internal mechanical depth uses neutrals: PASS
- The pump station, both roads, and the construction-zone boundary follow integer pixels and the composition's `16 px` grid: PASS
- The construction zone simultaneously shows a closed boundary, diagonal unfinished hatch, and four corner markers: PASS

### Five-Pixel Palette Sample

| Required sample | Pixel coordinate | Hex | Result |
|---|---:|---|---|
| Pump-station body | `(40,60)` | `#C25453` | PASS |
| Arterial road | `(120,40)` | `#C25453` | PASS |
| Blueprint marking | `(229,77)` | `#48A5CF` | PASS |
| Tissue ground | `(10,10)` | `#BE6E87` | PASS |
| Global exterior outline | `(175,48)` | `#140F1D` | PASS |

## Three-Minute Gate

- Subject and composition: one paired-chamber mechanical pump station, exactly two outward-bending arterial roads, and one empty blueprint-state construction zone are identifiable without labels: PASS
- Pixels and grid: silhouettes are hard-edged at native scale, roads keep a constant tile-scale width, the construction zone is fully visible, and no smooth or subpixel edge exists: PASS
- Palette: all five required samples match locked hex values and the complete visible-color set is a subset of the locked palette: PASS

**D-06 style gate: PASS.** Formal downstream asset generation may proceed, but every later asset still requires its own manifest and task-specific acceptance check.
