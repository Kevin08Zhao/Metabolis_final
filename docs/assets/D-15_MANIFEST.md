# D-15 Deterministic Resource Icon Manifest

- Task: `D-15`
- Final geometry: `DERIVED_DETERMINISTIC` from the six locked 8x8 bitmaps in `docs/ENCODING_SPEC.md`
- Canvas: `16x16`, transparent, binary alpha
- Anchor: `(8,8)`
- Palette: the 22 locked values in `docs/PALETTE.md`
- PixelLab references: seeds `15001`-`15006`, 32x32, style reference only; they never override locked bitmap geometry
- Validation: `PASS`

| File | Resource | State | SHA-256 |
|---|---|---|---|
| `art/icons/ui_resource_nutrient_energy_sufficient.png` | `nutrient_energy` | `sufficient` | `7f5286f1ff404efaae4133952fd5f3a5d17128605d31a0c416b2a400d7f2abee` |
| `art/icons/ui_resource_nutrient_energy_insufficient.png` | `nutrient_energy` | `insufficient` | `75479e89160dead24c747eec13b1478c0d2d1cfe4bcdcc6890a95f78dea5b0c6` |
| `art/icons/ui_resource_cell_material_sufficient.png` | `cell_material` | `sufficient` | `0a8b77c7b9bd1368084273bfb6a3b9493cfc86b4728966d88cda71328d659bae` |
| `art/icons/ui_resource_cell_material_insufficient.png` | `cell_material` | `insufficient` | `95e6ed3d65dfb6616a61c679f1811dff57d623854a43fb88e2d7466bbc87f246` |
| `art/icons/ui_resource_developmental_signal_sufficient.png` | `developmental_signal` | `sufficient` | `2503fe88cbf392b5ee2d2b872284801458b172b29a97bf9774b81e3477937a9e` |
| `art/icons/ui_resource_developmental_signal_insufficient.png` | `developmental_signal` | `insufficient` | `e78bc607ba9ebbc082f196c07bb5cacd912c6334faa6ac85862d2472b5da8417` |
| `art/icons/ui_resource_waste_normal.png` | `waste` | `normal` | `dceb16f4e8b85b056b414f073c09803bae2b46a2bf4ecfaded1efe393fdae0e9` |
| `art/icons/ui_resource_waste_overflow.png` | `waste` | `overflow` | `d54b84b308bb0cbc280da16b2a82a1fcbdd0e3fdb37af9d7d626e09453d7fa97` |
| `art/icons/ui_resource_stability_normal.png` | `stability` | `normal` | `8cbbd5a43f47bd87fa338ef1178077876f64e5317d9f861109ea0505611b1a30` |
| `art/icons/ui_resource_stability_warning.png` | `stability` | `warning` | `473ae1b40b6dfddda18b5bf17c1ceff835d92bfae6420b854165231a54def07f` |
| `art/icons/ui_resource_stability_critical.png` | `stability` | `critical` | `a6ab0c19a40d81e4e261064b636458949e4d5d052ccbfdb66bda2c05e186b308` |
| `art/icons/ui_resource_knowledge_badge_count.png` | `knowledge_badge` | `count` | `0a50119d184fa4e99da9afc25c36fe96ccb329c4d03a7cd3514de9a5c0a8060b` |

## State Matrix

| Resource | Applicable delivered states | Non-color encoding |
|---|---|---|
| Nutrient energy | sufficient, insufficient | solid versus one-pixel hollow interior |
| Cell material | sufficient, insufficient | solid versus one-pixel hollow interior |
| Developmental signal | sufficient, insufficient | solid versus one-pixel hollow interior |
| Waste | normal, overflow | one hollow hexagon versus three offset crosshatched copies |
| Stability | normal, warning, critical | solid/diagonal/crosshatch fill and 1/2/3-pixel borders |
| Knowledge badge | count | one solid four-long-arm star; no state variant |

The closest grayscale resource pair is nutrient energy versus stability. Their locked distinction remains the diamond's vertical symmetry versus the shield's six-pixel flat top and two-pixel central lower point.
