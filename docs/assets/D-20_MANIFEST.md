<!-- generated-by: tools/pixellab_fetch.py -->
# D-20 PixelLab landing manifest

- Fetch plan: `fetch_plans/D-20_fetch_plan.json`
- Fetch plan SHA-256: `4cbf7b7ef3468b08984364b8b30e8aa84b249cc0841f27440ca2b472d5119b0e`
- Landing report: `docs/assets/D-20_LAND_REPORT.json`
- Palette: `art/palette.gpl` (22 locked colors)

| Item | Target | Status | Tool | Real ID | Actual usage | Source | Output SHA-256 |
|---|---|---|---|---|---:|---|---|
| `heart_pulse_input` | `art/candidates/anim_heart_pulse_input.png` | PASS | `animate_image` | `97436fcf-d7c1-44ba-84cd-5a66f44d0a6e` | 1 | `https://api.pixellab.ai/mcp/images/97436fcf-d7c1-44ba-84cd-5a66f44d0a6e/download` | `902034bc00daf191de91eac9902a986ecd6d3b8d040d9ac7a932bd44d9da71ec` |
| `heart_pulse_contraction` | `art/candidates/anim_heart_pulse_contraction.png` | PASS | `animate_image` | `97436fcf-d7c1-44ba-84cd-5a66f44d0a6e` | 0 | `https://api.pixellab.ai/mcp/images/97436fcf-d7c1-44ba-84cd-5a66f44d0a6e/download` | `5e5d25f47035a85599f7008ba57f41e9c18b35136dd4024e84d5ea3e7c50186b` |
| `heart_pulse_peak` | `art/candidates/anim_heart_pulse_peak.png` | PASS | `animate_image` | `97436fcf-d7c1-44ba-84cd-5a66f44d0a6e` | 0 | `https://api.pixellab.ai/mcp/images/97436fcf-d7c1-44ba-84cd-5a66f44d0a6e/download` | `c60be401a40b18f1357db3840559e16df3c2291fe2c290eaf99728d97aceea5e` |
| `heart_pulse_relaxation` | `art/candidates/anim_heart_pulse_relaxation.png` | PASS | `animate_image` | `97436fcf-d7c1-44ba-84cd-5a66f44d0a6e` | 0 | `https://api.pixellab.ai/mcp/images/97436fcf-d7c1-44ba-84cd-5a66f44d0a6e/download` | `aacd82806942e6f14410690076a9878468e573492300f44756de0d9232454663` |

The committed fetch plan is the source of truth for full raw create/status responses and any base64 payload. This manifest never fabricates missing fields.

## Generation and selection

- Action prompt: `One complete pump heartbeat loop inside this supplied chamber region only: relaxed supplied start, rapid inward contraction of both chamber panels, peak contraction, then slow controlled expansion returning exactly to the supplied relaxed region. Preserve the boundary pixels and do not introduce new structures.`
- PixelLab request: `animate_image`, four generated frames, `no_background: true`, seed `20001`, and the same supplied D-11 pulse region as both the first and pinned last frame.
- PixelLab response contained the unchanged input at index 0 followed by four generated frames. Formal sheet indices are `[0, 2, 3, 2]`: relaxed, contraction, peak, then the contraction pose in reverse during the slower relaxation phase.
- Response index 1 was byte-identical to index 0 and was not selected. Response index 4 was retained as candidate evidence but was not selected because restoring the locked D-11 alpha footprint reduced it to the relaxed pose.
- `animate_image` does not expose remote project tags. The repository manifest and fetch plan provide the required `project:metabolis-final` provenance instead; no remote asset was deleted.

## Landing review

- Final output: `anim/heart_pump_active.png`, four 48 by 48 frames in one 192 by 48 row.
- Metadata: `anim/heart_pump_active.json`, unequal durations `[320, 120, 80, 280]`, fallback frame 0.
- Deterministic assembly: `tools/build_d20_heartbeat.py`.
- Validation: `docs/assets/D-20_VALIDATION_REPORT.json`.
- Review result: `PASS`; the original frame and alpha footprint are preserved, the pulse boundary and all pixels outside the pulse region remain static, and every visible pixel uses the locked palette.
