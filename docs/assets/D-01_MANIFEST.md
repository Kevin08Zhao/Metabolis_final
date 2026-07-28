# D-01 Palette Manifest

task_id: D-01
status: DONE
source: `docs/prompts/Metabolis_Prompts_Full_v2.md` D-01
palette_revision: D-02 accessibility retest, 2026-07-28

## Delivered files

| File | Deliverable type | Dimensions | Seed | Palette record |
|---|---|---|---|---|
| `art/palette.gpl` | GIMP palette | Not applicable | Not applicable - deterministic text palette | 22 rows; each row embeds its canonical hex |
| `docs/PALETTE.md` | Hex and semantic-use table | Not applicable | Not applicable - deterministic text table | Same 22 unique hex values as the GPL |

## Checks

- GIMP header, palette name, six columns, and 22 parseable color rows: PASS
- Every GPL decimal triplet converts to the hex embedded in the same row: PASS
- Six semantic groups each contain dark, main, and light values: PASS
- One global outline and three neutral values bring the total to 22: PASS
- Every hex has a non-empty semantic use and forbidden use in `docs/PALETTE.md`: PASS
- D-02 pairwise retest has no value below the locked `10.00` threshold: PASS

No raster image is produced by D-01, so pixel dimensions and a PixelLab seed do not apply.
