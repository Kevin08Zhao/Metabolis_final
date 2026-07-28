<!-- generated-by: tools/pixellab_fetch.py -->
# D-11 PixelLab landing manifest

- Fetch plan: `fetch_plans/D-11_fetch_plan.json`
- Fetch plan SHA-256: `5bb32515eb2f734b1cb4979ecb1ab4ebd9385911f42c4571ad640b5b514c74a9`
- Landing report: `docs/assets/D-11_LAND_REPORT.json`
- Palette: `art/palette.gpl` (22 locked colors)

| Item | Target | Status | Tool | Real ID | Actual usage | Source | Output SHA-256 |
|---|---|---|---|---|---:|---|---|
| `heart_operating` | `art/organs/organ_heart_operating.png` | PASS | `create_image_pixflux` | `f6688d85-ddf0-4f23-8360-8899ce255648` | 1 | `https://api.pixellab.ai/mcp/images/f6688d85-ddf0-4f23-8360-8899ce255648/download` | `553cf70cc9cae8d7f686fc7a3031a16e4df6a79b39763bf0f5d72927919815d9` |

The committed fetch plan is the source of truth for full raw create/status responses and any base64 payload. This manifest never fabricates missing fields.

## Deterministic five-state matrix

All derived images use the landed operating master, the fixed `48 × 48 px`
canvas, bottom-center anchor `(24,48)`, binary alpha, and only the locked
22-color palette. They are reproduced by `tools/build_organ_states.py`.

| State | File | Production |
|---|---|---|
| Blueprint | `art/organs/organ_heart_blueprint.png` | DERIVED: planning footprint and incomplete paired bay lines |
| Under construction | `art/organs/organ_heart_under_construction.png` | DERIVED: incomplete columns/scaffold; no closed pulse chambers |
| Completed | `art/organs/organ_heart_completed.png` | DERIVED: built pump with inactive chamber shutters |
| Operating | `art/organs/organ_heart_operating.png` | AI_MASTER: exact LAND output |
| Stressed | `art/organs/organ_heart_stressed.png` | DERIVED: chamber cross-braces and blocked central outlet |

Validation evidence: `docs/assets/D-11_VALIDATION_REPORT.json` (`PASS`).

The separable pulse region is native-pixel rectangle `(12,21)-(37,36)`.
It reserves two pixels of deformation margin. Blueprint and under-construction
states omit a complete pulse region. The stressed state's braces and blocked
outlet remain distinct from operating in grayscale, without relying on color.
