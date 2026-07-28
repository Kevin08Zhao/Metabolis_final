task_id: T-21-2
task_name: Birth transition, umbilical supply stops
owner: ACCOUNT_C
status: DONE
base_main_commit: 01c14574874b208bb50c95ad9b0c093f3655da4d
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for umbilical_stop
upstream:
  - docs/coord/done/T-21_ready_check.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_umbilical_stop body, one constant and one field only)
checks:
  - Exactly one state function implemented. The remaining five bodies are still exactly pass, verified by scanning: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched, including the T-21-1 gate: PASS
  - One constant and one field added at the top with comments, as the prompt permits - MS_PER_SECOND, which is a unit conversion and explicitly outside the no-hardcoding rule, and _beat_token: PASS
  - The window is read through state_duration_ms, which reads Balance. No length is decided in the script, so retuning the beat needs no script edit: PASS
  - No AnimationPlayer and no third-party state machine plugin. A SceneTreeTimer is engine-native: PASS
  - The wait is interruptible and exits safely. On resume the beat checks four things before touching the machine - still the current beat by token, still in this state, not queued for deletion, still inside the tree - and returns without advancing if any fails: PASS
  - No animation and no sound played. Only events are emitted, and those come from transition_to: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and passing metrics as in
      T-21-1, call start(), and wait one frame for the gate. The machine is in
      umbilical_stop. Wait for the configured window. The console shows
      [BIRTH] ready_check -> umbilical_stop, then
      [BIRTH] umbilical_stop -> pulmonary_flow.
  - step_2: |
      Repeat and observe the entry frame only. The machine is still in
      umbilical_stop, confirming the beat does not advance re-entrantly from
      inside the entry hook.
  - step_3: |
      Repeat, then call transition_to(State.FAILURE_ROLLBACK) while the beat is
      running. When the timer fires the console shows
      [BIRTH] beat umbilical_stop was interrupted; exiting without advancing,
      and the machine is still in failure_rollback.
observed:
  - "step 1: ready_check -> umbilical_stop -> pulmonary_flow, elapsed at least the configured window"
  - "step 2: still umbilical_stop on the entry frame"
  - "step 3: interrupted cleanly, state stayed failure_rollback"
  - "extra, restart: interrupting and re-entering the beat leaves the stale timer unable to advance the machine; only the newest beat advances"
  - "extra, freed mid-beat: a machine queue_freed while its beat runs now exits quietly instead of emitting a state change on its way out"
force_quit_residue: |
  Nothing on disk. This state writes no file and touches no city state; it waits
  and then asks the machine to advance. A force quit during the beat loses only
  the in-memory current state, and the next run starts from IDLE.
  The SceneTreeTimer dies with the process, so no timer survives to fire against
  a restored machine.
  One consequence worth stating: because the beat carries no checkpoint, a force
  quit partway through the ending sequence returns the player to the readiness
  gate rather than to the middle of the sequence. That matches BIRTH_STATES,
  where failure_rollback also routes back to the gate, and it means the four E5
  checks are re-evaluated honestly rather than resumed on stale results.
pending_verification: |
  One thing could not be demonstrated and is recorded rather than glossed over.
  docs/BALANCE.json still has no chapters.stage_birth.birth_sequence keys, so
  state_duration_ms returns 0 for this beat and the acceptance run exercised a
  zero-length window. What that proves is the whole mechanism: the beat opens,
  yields, checks its four interruption conditions on resume, and advances or
  exits accordingly. What it does not prove is a beat actually occupying its
  10000 ms slot end to end.
  This is reported as OPEN in docs/coord/rework/T-06__from_ACCOUNT_C.open.md. The
  moment those keys land, rerunning the same three manual steps closes it, and
  this marker will gain a revalidation block with the measured window, exactly as
  docs/coord/done/T-05b.md did when BALANCE.json first arrived.
  No default was baked into the script to paper over the gap: the beat warns and
  points at missing_duration_paths() instead of substituting a length.
reported_not_fixed: |
  Nothing new. The T-21-1 note still stands - acknowledging a rollback re-runs
  the gate against whatever city_metrics currently holds, so the caller must
  refresh them between attempts. T-25 owns that.
notes: |
  A defect in this task's own first draft was found during acceptance and fixed
  inside the one function it owns. The interruption guard originally checked only
  the beat token and the current state, so a machine freed mid-beat still resumed
  and emitted a state change on its way out. Being freed is an interruption, and
  the prompt requires a safe exit from one, so the guard now also rejects a
  machine queued for deletion or no longer in the tree.
  No file owned by another account was modified. src/project.godot is unchanged.
completed_at: 2026-07-27T21:45:00-04:00
