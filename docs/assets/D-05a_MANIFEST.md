# D-05a PixelLab Pipeline Manifest

## Provenance

- Task: `D-05a`
- Owner: `ACCOUNT_D`
- Base main commit: `46a856bf3e0ca1c3402fbd598f5c551ccaa57e11`
- PixelLab schema source: live MCP declarations read at `2026-07-28T14:41:01Z`
- PixelLab access proof: real `get_balance({})` response recorded in `PIXELLAB_TOOL_SNAPSHOT.md`
- Fetch plan: `NOT_APPLICABLE` — D-05a builds the landing pipeline and performs no PixelLab generation
- Generation calls / units: `0 / 0`

## Delivered Files

| File | Role | Verification |
|---|---|---|
| `tools/pixellab_fetch.py` | URL/base64 retrieval, 22-color nearest mapping, binary alpha, deterministic operations, report and MANIFEST writer | Mixed self-test PASS; SHA-256 `f703027c206e126086f5a7f4602f49221591bed312be5960093d3ba22d763b94` |
| `.github/workflows/pixellab_land.yml` | Task-branch landing Action with delayed failure and `contents: write` only | YAML parse PASS; SHA-256 `3276ee19c3bf5b4405dff9c91855124760fcea039d6a4931632c7113ecd5db48` |
| `art/reference/palette_strip.png` | Locked 22-color transfer strip, one `16 × 16` block per GPL entry | `352 × 16`, 22 ordered colors; SHA-256 `5120007fbc6c9aefbe3535c476a2314f5ab38eeca056394b3066a70f06d5e0b0` |
| `docs/PIXELLAB_PIPELINE.md` | Fetch-plan, processing, safety, Action, and local verification contract | Required report fields and allowed operations documented |
| `docs/PIXELLAB_TOOL_SNAPSHOT.md` | Actual 65-tool inventory and current core schemas | Counted 65 unique names; no schema field inferred from PDF |
| `docs/assets/QUOTA_LEDGER.md` | Actual usage ledger and pre-task balance baseline | D-05a row records 0 calls and 0 units |
| `docs/assets/D-05a_SELF_TEST_REPORT.json` | Machine-readable acceptance evidence | 11/11 checks PASS; SHA-256 `6874d3c4b15ee443742f28d8b73922d597e02af26fd587f8490d719cc00d1af4` |
| `docs/assets/D-05a_MANIFEST.md` | This delivery inventory | No generated asset or fetch plan claimed |
| `docs/coord/done/D-05a.md` | Completion marker created only after local VERIFY | Status `DONE` |

## Acceptance Evidence

The mixed plan contains exactly one valid `3 × 2` base64 PNG scaled by nearest-neighbor to `6 × 4`, and one deliberately unreachable HTTPS URL. The valid item lands with binary alpha and zero visible out-of-palette pixels. The URL item fails independently; the plan retains the successful file and produces report/MANIFEST evidence, while the script returns failure semantics. Static workflow checks confirm that evidence is committed before the final `exit 1` and that any `docs/coord/done/` output is rejected.

Independent checks also cover crop, tiled nine-slice composition, refusal to overwrite an unknown existing file, ordered 22-block palette-strip content, report field completeness, and exact 65-tool snapshot count.
