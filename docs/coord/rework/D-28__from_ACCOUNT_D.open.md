target_task: D-28
reported_by: ACCOUNT_D
status: OPEN
discovered_at_main_commit: 88041591dbfb688449484e66fa0cc8fc6aeb24a3
completed_work:
  - tools/check_assets.py
  - tests/test_check_assets.py
  - docs/ATTRIBUTIONS.md
  - docs/assets/D-F03_FINAL_AUDIT.json
checks:
  - Asset checker tests: PASS (11)
  - Repository asset compliance: PASS (247 files, 0 errors, 7 non-blocking warnings)
  - Animation metadata and self-test: PASS
  - D-07/D-08 deterministic rebuild check: PASS
failed_contract:
  - D-24 is not DONE, so the final sound-effect inventory is unavailable.
  - D-25 and D-26 audio assets do not exist.
  - D-27 is not DONE, so final mix and device-listening evidence is unavailable.
  - The full D-track source ledger cannot be frozen while required animation, audio, title integration, and screenshots remain upstream-blocked.
expected:
  - Every final visual and audio asset has traceable provenance, dimensions, naming, palette or audio-event validation, and a manifest entry.
  - External assets, if any, have verified redistribution and modification rights.
  - The final checker passes after all D-track deliverables land.
actual:
  - Current visual assets and heartbeat animations pass the new read-only checker.
  - Attribution records cover all current PixelLab jobs and deterministic asset groups.
  - Final audio and remaining upstream-blocked D-track outputs are absent.
impact:
  - D-28 cannot truthfully receive a DONE marker.
  - The checker and attribution index are ready for incremental use without blocking other accounts.
resolution_condition:
  - Complete D-24 through D-27 and all remaining D-track asset tasks.
  - Add any new source records to docs/ATTRIBUTIONS.md.
  - Rerun tools/check_assets.py and the F03 audit with zero errors.
opened_at: 2026-07-28T18:48:10Z
