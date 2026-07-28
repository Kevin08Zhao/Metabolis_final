# D-08 Vessel Tile Manifest

- Status: `PASS`
- Source: deterministic local build, `tools/build_core_tiles.py`
- PixelLab generation calls: `0`
- Contract: four canonical `16x16` RGBA PNGs, 11 logical rotations, binary alpha
- Interface: positions 5–12 inclusive; `#140F1D` at 5 and 12; `#BA3A3F` at 6–11
- Validation: `docs/assets/D-08_VALIDATION_REPORT.json`

| File | Canonical interfaces | SHA-256 |
|---|---|---|
| `art/tiles/tile_vessel_straight.png` | NS | `2d3b415b2d71af3bb8e20f78d143ddef0022def9b244599ba7c476bc47d3b9b8` |
| `art/tiles/tile_vessel_corner.png` | NE | `5d3bbba96672992a5a27641baa5a2dce2937ea0f9adc912230ed2e2abf8c28a6` |
| `art/tiles/tile_vessel_tee.png` | NES | `225b80e0fe6e06b3b95f90e3ea338ab2b616535d89bdf9b0f939ab8e7aac37a3` |
| `art/tiles/tile_vessel_fourway.png` | NESW | `c592551951c4a5843df55d38aaac44bae627bf908e4b9e3ddbb5b19aff6bbb8a` |

The canonical files generate all 11 logical direction variants using lossless 90-degree rotations. The specified 5x5 double-loop splice has no unmatched or outward-facing interface.
