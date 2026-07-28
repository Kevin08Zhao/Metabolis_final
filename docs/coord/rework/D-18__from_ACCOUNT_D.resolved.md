target_task: D-18
reported_by: ACCOUNT_D
status: RESOLVED
failed_files:
  - docs/ANIM_META_SPEC.md (missing before D-18)
  - tools/check_anim.py (missing before D-18)
impact:
  - Animation production had no locked metadata pair contract.
  - Frame-count, alpha-channel, filename, and EVENT_API mismatches could not be detected in batch.
resolution:
  - Defined the exact seven-field JSON object and same-stem PNG/JSON pairing rule.
  - Added a read-only recursive checker that derives the event allowlist from EVENT_API.
  - Added a complete documentation-only example and in-memory positive/negative tests.
  - Confirmed the current empty animation directory passes without creating an animation.
resolved_at: 2026-07-29T01:01:12+08:00
