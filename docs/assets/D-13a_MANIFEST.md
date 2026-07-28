
# D-13a Construction-Zone Asset Manifest

- Status: `PASS`
- Source LAND: `docs/assets/D-13a_SOURCE_LAND_REPORT.json`
- Deterministic source: D-07 focused/background construction tiles
- Delivered zone states: blueprint, under construction, and a reduced-detail background under-construction variant
- Standard zone: `64x64`; landmark zone: `80x80`
- Validation: `docs/assets/D-13a_VALIDATION_REPORT.json`

| File | SHA-256 |
|---|---|
| `art/construction/construction_zone_standard_blueprint.png` | `831552d6db50c6a468be0c2a0aa80650eef26009f680808bf4647e381be7b590` |
| `art/construction/construction_zone_standard_under_construction.png` | `765e9dac20c9b0d57f6c499618eec60163b961adb89c4e8776281c0e29cf7b79` |
| `art/construction/construction_zone_standard_background.png` | `0ed866cd3f24e13999ad85763682a62b1a7cc1f060b91275221d6a039fe0f455` |
| `art/construction/construction_zone_landmark_blueprint.png` | `c0e210149e7884f0dd64703dc79ae2f1800dcfb36ca2c6393c9874cccbd4372d` |
| `art/construction/construction_zone_landmark_under_construction.png` | `78ff9c164ab9bcc3e5193bd9d16dba67c5d279afb675b585476d05a7f0277741` |
| `art/construction/construction_zone_landmark_background.png` | `fc6c7af70308d2a03788bea1578b53ae7c8809c82517ef743f5a71dcf4bf0034` |

No completed, operating, or stressed **construction-zone** PNG is added. `organ_state.gd` assigns those states to the organ, while `ART_BIBLE.md` requires the closed boundary, hatch, and construction-marker silhouette to disappear when construction completes. Thus the corresponding construction-zone visual is absence, not a new sprite.
