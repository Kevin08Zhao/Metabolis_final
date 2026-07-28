
# D-12 Paired-Lungs Static Asset Manifest

- Status: `PASS`
- Canvas/anchor: `48x48`, bottom-center `(24,48)`
- Source LAND: `docs/assets/D-12_SOURCE_LAND_REPORT.json`
- Derivation: `tools/build_d12_d13a_assets.py` (0 additional PixelLab calls)
- Fixed topology: 12 structural terminal branches in every state
- Readiness: 4 / 8 / 12 complete branch markings; incomplete branches remain dotted so topology never changes
- Validation: `docs/assets/D-12_VALIDATION_REPORT.json`

| File | SHA-256 |
|---|---|
| `art/organs/organ_lungs_blueprint.png` | `0a1b43044657e678edb7d9f05a6bfefbb1af7060e0dbce0185f83e1012a2813a` |
| `art/organs/organ_lungs_under_construction.png` | `af5e2077bcf470df661aef7472d2f493ae39b40bd2c02904221d73d6ba470832` |
| `art/organs/organ_lungs_completed.png` | `793ee740be6da7120aed80b97f78ee48f55e79ad34fc6e6dfb96d9af8f86d154` |
| `art/organs/organ_lungs_operating.png` | `27e30633dbb732c537f05e9443c17597706e47f4bc41fbb5af7690ff72b87844` |
| `art/organs/organ_lungs_stressed.png` | `f428fbec3617214ada22ea68a89d46a20c42f00b7c60a5d3e231b7afbbeb6b12` |

`operating` is the single-state demonstration fallback because it shows the fully expanded exchange facility and all 12 completed branch markings.
