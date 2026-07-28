<!-- generated-by: tools/pixellab_fetch.py -->
# D-10 PixelLab landing manifest

- Fetch plan: `fetch_plans/D-10_fetch_plan.json`
- Fetch plan SHA-256: `bc793b7aff9398ca3a4f5e6f1b01a0075edd9e9ee3a37e3762c8569e00763a43`
- Landing report: `docs/assets/D-10_LAND_REPORT.json`
- Palette: `art/palette.gpl` (22 locked colors)

| Item | Target | Status | Tool | Real ID | Actual usage | Source | Output SHA-256 |
|---|---|---|---|---|---:|---|---|
| `placenta_operating` | `art/organs/organ_placenta_operating.png` | PASS | `create_image_pixflux` | `e5f72fc6-40cb-46f6-8d08-9e16011b6c66` | 1 | `https://api.pixellab.ai/mcp/images/e5f72fc6-40cb-46f6-8d08-9e16011b6c66/download` | `83d2c551b9c24da2b1c277679f8374fe3d15f83de1b29ec0388942f03cbf6d9a` |

The committed fetch plan is the source of truth for full raw create/status responses and any base64 payload. This manifest never fabricates missing fields.

## Deterministic five-state matrix

All derived images use the landed operating master, the fixed `48 × 48 px`
canvas, bottom-center anchor `(24,48)`, binary alpha, and only the locked
22-color palette. They are reproduced by `tools/build_organ_states.py`.

| State | File | Production |
|---|---|---|
| Blueprint | `art/organs/organ_placenta_blueprint.png` | DERIVED: closed planning boundary, clipped hatch, open hub plan |
| Under construction | `art/organs/organ_placenta_under_construction.png` | DERIVED: anchored foundation, incomplete columns, scaffold |
| Completed | `art/organs/organ_placenta_completed.png` | DERIVED: built harbor with inactive port gates |
| Operating | `art/organs/organ_placenta_operating.png` | AI_MASTER: exact LAND output |
| Stressed | `art/organs/organ_placenta_stressed.png` | DERIVED: intact restricted gates and pressure rail |

Validation evidence: `docs/assets/D-10_VALIDATION_REPORT.json` (`PASS`).

The birth-sequence supply stop/function transfer is not a sixth
`OrganStateMachine` state, so this task intentionally creates no extra PNG.
Downstream birth transition work must derive that non-damaged overlay from the
operating state without describing the placenta as broken or permanently closed.
