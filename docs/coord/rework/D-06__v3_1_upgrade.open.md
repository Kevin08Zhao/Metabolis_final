target_task: D-06
reported_by: ACCOUNT_D
status: OPEN
discovered_at: 2026-07-28T15:09:21Z
discovered_at_main_commit: 0c0c6e757a36f657667815965cfd256739359bc0
source: Metabolis D 轨道 Prompt v3.1 · P-02 (D-06)
failed_files:
  - art/reference/STYLE_MASTER.png (legacy 256 × 160 output; v3.1 requires art/reference/style_master.png at 320 × 180)
  - fetch_plans/D-06_fetch_plan.json (missing)
  - docs/assets/D-06_LAND_REPORT.json (missing)
  - docs/assets/D-06_MANIFEST.md (legacy v2 manifest; no v3.1 landing report or quota evidence)
  - docs/coord/done/D-06.md (legacy v2 completion marker)
evidence:
  - The legacy style master is 256 × 160 and uses an uppercase filename.
  - The legacy manifest records four PixelLab jobs but does not contain the v3.1 fetch-plan or automated LAND report.
  - docs/assets/QUOTA_LEDGER.md has no D-06 production row.
  - The repository contains no recorded v3.1 mandatory human style-gate confirmation.
expected:
  - Generate candidates one at a time with a current PixelLab schema that supports fixed seed, 320 × 180, and an opaque canvas.
  - Keep every visible output pixel within the locked 22-value palette after deterministic normalization.
  - Present the first candidate and its automated evidence for explicit human confirmation before LAND.
  - After confirmation, LAND art/reference/style_master.png, the fetch plan, automated report, manifest, quota row, and updated DONE marker atomically.
actual:
  - D-06 is complete only under the legacy v2 contract.
impact:
  - P-02 cannot SHIP under v3.1 until the mandatory human style gate passes.
resolution:
  - Preserve the legacy image and manifest as historical evidence until the v3.1 replacement is confirmed.
  - Convert this file to .resolved.md only in the confirmed final LAND change.
