target_task: D-13b
reported_by: ACCOUNT_D
status: RESOLVED
discovered_at_main_commit: d13bb366833e0fec1e89d234495b827bcdefd502
failed_contract:
  - docs/BUILD_DECISION_SPEC.md Table D8 defines the three metric rows, units, directions, normalization, and comparison bars.
  - docs/UI_LAYOUT.md does not allocate an exact candidate-card rectangle or define card height, spacing, or the required 2-to-4-card arrangement.
  - src/ui/option_preview.gd fixes each comparison bar at 160 by 12 but builds a content-sized VBoxContainer with no card dimensions.
expected:
  - One exact allocation rectangle for the candidate comparison area.
  - Exact card width, height, inner padding, row spacing, and card-to-card spacing.
  - One deterministic layout rule for 2, 3, and 4 simultaneous candidate cards.
actual:
  - Metric semantics are complete, but exact static card geometry cannot be derived without inventing layout values.
impact:
  - D-13b cannot truthfully receive final PNGs, a PASS report, MANIFEST, or DONE marker.
  - No PixelLab call is justified because the missing information is deterministic UI geometry, not visual style.
resolution_condition:
  - The missing layout contract is committed to docs/UI_LAYOUT.md or an equivalent authoritative runtime scene.
opened_at: 2026-07-29T01:03:00+08:00
