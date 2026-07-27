upstream_task: T-06
reported_by: ACCOUNT_B
status: OPEN
discovered_at_main_commit: 86d39a8699cfcbaadff5b317e0e6370e889af8f0
failed_files:
- docs/BALANCE.json
- docs/BALANCE_VALIDATION.md
blocked_task: T-12
downstream_impact:
- T-13a
- T-13
- T-15a
- T-16
- T-17
- T-18
- T-19f
- T-19e
- T-19
- T-19h
- T-19g
- T-15
- T-19c
reproduction:
1. Read the T-12 constraint in docs/prompts/Metabolis_Prompts_Full_v2.md requiring grid rows, columns, and tile side length to be read from Balance.
2. Inspect docs/BALANCE.json and docs/BALANCE_VALIDATION.md for grid row, column, and tile-size paths.
3. Observe that no such paths exist under any of the twelve allowed top-level configuration blocks.
4. Attempt the T-12 acceptance step that reduces row and column counts in BALANCE.json and reruns the grid.
expected: |
  BALANCE.json exposes stable, documented paths for grid column count, row count,
  and tile side length. Their initial values match GRID_BASELINE.md, and changing
  the row or column values changes the rendered grid without a script edit.
actual: |
  BALANCE.json contains organ origins and candidate slot coordinates but no grid
  dimensions or tile side length. T-12 therefore cannot read the required values,
  and its configuration-change acceptance step cannot be performed.
required_resolution: |
  Add the three required grid values within the existing twelve-block Balance
  schema, document their paths and units in BALANCE_VALIDATION.md, rerun T-06
  validation, update docs/coord/done/T-06.md, and rename this marker to
  T-06__from_ACCOUNT_B.resolved.md in the same repair commit.
