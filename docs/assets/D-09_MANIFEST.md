# D-09 Transport-Network Variant Manifest

- Status: `PIXELLAB_REBUILT` (2026-07-29, Account D, Tier 2 Pixel Artisan)
- Art production: PixelLab API → tileset extraction → Python variant composition
- PixelLab calls: 4 (`create_topdown_tileset` at 16×16, one per canonical road shape)
- Tileset IDs: straight `98bc6e5b`, corner `62d4507e`, tee `12b308f8`, fourway `8fce437f`
- Post-processing: palette quantization to 22-color Metabolis palette, tile extraction from Wang spritesheets
- Variant count: 132 PNGs (11 geometries × 2 flow directions × 2 route roles × 3 passage states)
- Base tiles: PixelLab-generated road shapes, extracted and palette-remapped
- Build tool: `tools/build_d09_vessel_variants.py` (adapted for PixelLab base tiles)
- Original D-08 backups: `art/tiles/d08_backup/`

All 132 PNGs inherit their base geometry from PixelLab-generated art. Each variant
is a deterministic composition of flow direction, route role, and passage state
layers over the PixelLab road shape, quantized to the locked 22-color palette.
