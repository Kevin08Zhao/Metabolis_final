target_task: D-28
reported_by: ACCOUNT_D
status: OPEN
discovered_at_main_commit: 88041591dbfb688449484e66fa0cc8fc6aeb24a3
completed_work:
  - tools/check_assets.py
  - tests/test_check_assets.py
  - docs/ATTRIBUTIONS.md
  - docs/assets/D-F03_FINAL_AUDIT.json
  - docs/AUDIO_SFX_SPEC.md
  - docs/coord/done/D-24.md
  - docs/HEARTBEAT_AUDIO_SPEC.md
  - docs/assets/D-25_MANIFEST.md
  - audio/ambient/heartbeat_bed.wav
  - tools/build_d25_heartbeat_audio.py
  - tests/test_build_d25_heartbeat_audio.py
  - docs/coord/rework/T-37__from_ACCOUNT_D_d25_heartbeat_timing.open.md
checks:
  - Asset checker and heartbeat-builder tests: PASS (13)
  - Repository asset compliance: PASS (248 files, 0 errors, 7 non-blocking warnings)
  - Animation metadata and self-test: PASS
  - D-07/D-08 deterministic rebuild check: PASS
  - Godot 4.7.1 headless startup: PASS with two heartbeat-stream shutdown warnings
failed_contract:
  - D-25 has a validated stable fallback but is blocked by the T-37 three-band cadence gap.
  - D-26 audio assets do not exist because D-22 is not DONE.
  - D-27 is not DONE, so final mix and device-listening evidence is unavailable.
  - The full D-track source ledger cannot be frozen while required animation, audio, title integration, and screenshots remain upstream-blocked.
expected:
  - Every final visual and audio asset has traceable provenance, dimensions, naming, palette or audio-event validation, and a manifest entry.
  - External assets, if any, have verified redistribution and modification rights.
  - The final checker passes after all D-track deliverables land.
actual:
  - Current visual assets and heartbeat animations pass the new read-only checker.
  - Attribution records cover all current PixelLab jobs and deterministic asset groups.
  - The D-24 inventory and stable heartbeat fallback are recorded, but final three-band heartbeat, birth audio, and remaining upstream-blocked D-track outputs are absent.
impact:
  - D-28 cannot truthfully receive a DONE marker.
  - The checker and attribution index are ready for incremental use without blocking other accounts.
resolution_condition:
  - Complete D-24 through D-27 and all remaining D-track asset tasks.
  - Add any new source records to docs/ATTRIBUTIONS.md.
  - Rerun tools/check_assets.py and the F03 audit with zero errors.
opened_at: 2026-07-28T18:48:10Z
