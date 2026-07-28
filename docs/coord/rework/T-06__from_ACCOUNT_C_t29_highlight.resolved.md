reported_task: T-06
reported_by: ACCOUNT_C
status: RESOLVED
discovered_while: T-29
base_main_commit: 3430759bd798c72c3cc12d8e7d02452dedb21458
failed_files:
  - docs/BALANCE.json
  - docs/BALANCE_VALIDATION.md
reproduction:
  - Read the T-29 prompt in docs/prompts/Metabolis_Prompts_Full_v2.md.
  - Confirm that every resource value change must produce a temporary highlight
    whose duration is read from Balance.
  - Search docs/BALANCE.json and docs/BALANCE_VALIDATION.md for a resource-change
    highlight duration.
expected: |
  BALANCE.json defines one positive duration in seconds for the resource-bar
  value-change highlight, and BALANCE_VALIDATION.md records its path, unit,
  source, and validation rule. T-29 can then read that path without a gameplay
  literal or a silent fallback.
actual: |
  No resource-bar highlight duration exists. The only display duration under
  assist is assist.knowledge.immediate_prompt_display_sec, which belongs to the
  T-30 immediate knowledge prompt and cannot be reused as a resource-change
  timing value without changing its meaning.
impact: |
  T-29 cannot satisfy both of its locked constraints: every value change must
  highlight, and the highlight duration must come from Balance. Hardcoding a
  duration in src/ui/resource_bar.gd would violate the single numeric authority;
  using the immediate-prompt duration would couple unrelated UI behaviors.
requested_resolution: |
  Add a dedicated positive seconds value, preferably
  assist.ui.resource_change_highlight_sec, and document and validate it in
  BALANCE_VALIDATION.md. Resolve this record and revalidate done/T-06.md before
  Account C resumes T-29.
reported_at: 2026-07-28T13:25:00-04:00
resolved_at: 2026-07-28T14:50:00-04:00
resolved_by: ACCOUNT_C
authorization: The project owner explicitly authorized ACCOUNT_C to repair the upstream omission.
resolution:
  - Added assist.ui.resource_change_highlight_sec = 0.35 to docs/BALANCE.json.
  - Documented the path, seconds unit, and validation bounds in docs/BALANCE_VALIDATION.md.
  - Revalidated docs/coord/done/T-06.md before resuming T-29.
