upstream_task: T-06
reported_by: ACCOUNT_C
status: RESOLVED
discovered_at_main_commit: 01c14574874b208bb50c95ad9b0c093f3655da4d
resolved_by: ACCOUNT_C
resolved_at: 2026-07-27T22:20:00-04:00
resolved_under: |
  Explicit authorization from the project owner, who asked ACCOUNT_C to carry out
  the repair directly rather than wait for a CODEX round. This is a deliberate
  exception to file ownership and is recorded here and in docs/coord/done/T-06.md
  so the T-06 owner is not surprised by an edit it did not make.
  There was no judgment to exercise: all six values were already fixed by table
  B2 of docs/BIRTH_STATES.md, an accepted specification, and the repair is the
  mechanical act of writing them down.
failed_files:
- docs/BALANCE.json
- docs/BALANCE_VALIDATION.md
blocked_task: T-21-2
downstream_impact:
- T-21-3
- T-21-4
- T-21-5
- T-21-6
- T-21-7
- T-22
- T-25
- D-22
- D-26
reproduction:
1. Read the T-20 constraint in docs/prompts/Metabolis_Prompts_Full_v2.md requiring that every duration in the birth sequence be read from Balance, with no gameplay parameter hardcoded in the script.
2. Read table B2 of docs/BIRTH_STATES.md, which fixes the 45-second ending sequence as five windows, and the required Balance keys section below it, which names the six paths those windows need.
3. Inspect docs/BALANCE.json under chapters.stage_birth for a birth_sequence block, and docs/BALANCE_VALIDATION.md for any birth_sequence path.
4. Observe that neither exists.
5. Run src/sim/birth_machine.gd and call missing_duration_paths(). It returns all five window paths. state_duration_ms() returns 0 for every state and total_timeline_ms() returns 0.
expected: |
  BALANCE.json exposes the five birth-sequence window lengths and the total
  budget, inside the existing twelve-block schema. Their values match table B2 of
  docs/BIRTH_STATES.md, and total_timeline_ms() equals total_budget_ms, which is
  the 45-second ending sequence the operating-time budget allocates.
actual: |
  BALANCE.json has no birth_sequence block under chapters.stage_birth.
  birth_machine reports all five window paths as missing, every window reads as
  zero, and the whole ending sequence measures zero milliseconds. T-21-2 cannot
  implement a state whose exit condition is "the configured duration elapses",
  because there is no configured duration to elapse.
required_resolution: |
  Add the following six values under chapters.stage_birth.birth_sequence. The
  path sits inside chapters, which is already one of the twelve permitted
  top-level blocks, so the required twelve-key schema is unchanged. This mirrors
  how T-06__from_ACCOUNT_B was resolved, where three grid values were added under
  the existing build_options block.

    chapters.stage_birth.birth_sequence.umbilical_stop_ms   = 10000
    chapters.stage_birth.birth_sequence.pulmonary_flow_ms   = 10000
    chapters.stage_birth.birth_sequence.fetal_shunts_ms     = 10000
    chapters.stage_birth.birth_sequence.systems_online_ms   = 5000
    chapters.stage_birth.birth_sequence.ending_ms           = 10000
    chapters.stage_birth.birth_sequence.total_budget_ms     = 45000

  The five window values are fixed by table B2 of docs/BIRTH_STATES.md and are
  not open for retuning here: three observable phases at exactly 10000 ms each
  total 30000 ms, and the ending picture takes the remaining 15000 ms, split so
  that systems lighting up reads as its own beat before the final image settles.
  They sum to 45000 ms, which meets the ending-sequence budget exactly rather
  than exceeding it. ready_check and failure_rollback carry no window on purpose;
  giving either one would push the total past budget.

  Then document all six paths and their unit in BALANCE_VALIDATION.md, rerun the
  T-06 validation, update docs/coord/done/T-06.md, and rename this marker to
  T-06__from_ACCOUNT_C.resolved.md in the same repair commit.
resolution: |
  Added chapters.stage_birth.birth_sequence with the six values above. The block
  sits inside chapters, already one of the twelve permitted top-level blocks, so
  the twelve-key schema is unchanged and was re-counted after the edit.
  The five window values sum to 45000, which equals total_budget_ms, verified
  arithmetically and again at runtime through BirthMachine.total_timeline_ms().
  BALANCE_VALIDATION.md documents all six paths and their unit in the chapters
  section.
  birth_machine.missing_duration_paths() now returns empty, and the beats that
  were running zero-length windows now hold their configured length. T-21-2 was
  revalidated against a real 10000 ms window as part of this repair; see the
  revalidations block of docs/coord/done/T-21_umbilical_stop.md.
notes: |
  This is a completeness gap rather than a defect. T-06 ran before T-20 existed,
  so there was no birth-sequence specification to draw placeholders from at the
  time. The T-06 prompt requires every placeholder appearing in a specification
  to have a matching key, and docs/BIRTH_STATES.md is now an accepted
  specification that declares six.
  T-21-1 is unaffected and already passed acceptance: the readiness gate carries
  no window on the 45-second timeline, so it reads no duration. T-21-2 is the
  first beat where a window actually elapses.
  No key was invented locally and no default was baked into birth_machine.gd. The
  machine reports the missing paths through missing_duration_paths() rather than
  substituting a value, so nothing in the repository depends on a guess.
