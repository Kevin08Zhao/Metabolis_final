# D-07 Terrain Tile Manifest

- Status: `PASS`
- Source: deterministic local build, `tools/build_core_tiles.py`
- PixelLab generation calls: `0`
- Contract: 19 native `16x16` RGBA PNGs, locked 22-color palette, binary alpha
- Validation: `docs/assets/D-07_VALIDATION_REPORT.json`

| File | SHA-256 |
|---|---|
| `art/tiles/tile_terrain_empty.png` | `45264e3a441c31afe5d27c9a4c6cbdca07b29786ced12af382a45749c8d86412` |
| `art/tiles/tile_tissue_ground.png` | `78bebede486f21e89413c638991e3238ace0d73a0c3de1569904f70313c83ab7` |
| `art/tiles/tile_tissue_isolated.png` | `d5f62f207c09d93be2f0d6edf2c1498f1ea139f806ef70f427e5d0e49b916214` |
| `art/tiles/tile_tissue_n.png` | `5604175d1b39ad7d45738a08b018ffd0ed069a0c7bcd0f4195d9722a5877ba62` |
| `art/tiles/tile_tissue_e.png` | `dd1dc486ff6321f1a3c7c5b0d89367970538284eb97313a47a5688d56fbde5ae` |
| `art/tiles/tile_tissue_s.png` | `fdeeb939db5a6dfa3f7b800fc9f29fed6b57bd3bbf61b4591a7bf97b9e56da70` |
| `art/tiles/tile_tissue_w.png` | `c0463e54daf09a15d1eb3375614f57e3ae854c87e32d54487faa79a6d164f876` |
| `art/tiles/tile_tissue_ns.png` | `0e0047a940b29df356916fc8ea1c1d2c51866f5002a5c3d88adacae73b5d3b07` |
| `art/tiles/tile_tissue_ew.png` | `63d481df6f75d114f146c41eef9fa3af0a7a009c991efec80a4422f50ff48ae6` |
| `art/tiles/tile_tissue_ne.png` | `d262d4e7becfc9aeb096433c7e0bd84270d3af5f7462191af86ad96e3f41f1bf` |
| `art/tiles/tile_tissue_es.png` | `31fff43d2e8ab02a7f878b93bc6082a49c12627420a07399830b7483dd6a6519` |
| `art/tiles/tile_tissue_sw.png` | `2d72f88b60a4317e7712565ed84d771ab075d015bdf11e7d317bca7d7f895e86` |
| `art/tiles/tile_tissue_wn.png` | `7b5aad772d4fd7ebaa1725ce0d62eaf4819e6994798239b59078d16584c3e9ca` |
| `art/tiles/tile_tissue_nes.png` | `4b7edcb8c6b076554af4c17ef57f350ce163a92bfbfd87dcb82d3c8268744b2a` |
| `art/tiles/tile_tissue_esw.png` | `d379894191f71293441eae4088b34011ee8a39b28c56cda6d21530722c6a1ca5` |
| `art/tiles/tile_tissue_swn.png` | `74c4e2708f8db9b5389d97cfdba0045136d74e155198355bf5330a46c806598b` |
| `art/tiles/tile_tissue_wne.png` | `7ea361130a139987e0ef8509e159dbf051768a1da15e4e8c20ba4e05218ed842` |
| `art/tiles/tile_construction_focus.png` | `daaaecbcff82a2556f650120e7ac557c5cc988fa0237e9b6b24eb185efad58bf` |
| `art/tiles/tile_construction_background.png` | `16d5b2e6ea4b25303eba34e8b80ba6aa825449187adae6b95690c26954f8ac4a` |

Boundary variants use canonical N/E/S/W bit masks and lossless quarter-turn derivation. The construction background retains 62.82% of the focused line-pixel count, satisfying the required 30–40% reduction.
