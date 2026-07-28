task_id: T-21-4
task_name: Birth transition, fetal shunts change function
owner: ACCOUNT_C
status: DONE
base_main_commit: 45e7aff
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for fetal_shunts
upstream:
  - docs/coord/done/T-21_pulmonary_flow.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_fetal_shunts body only)
checks:
  - Exactly one state function implemented. The remaining three bodies are still exactly pass, verified by scanning: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched, including the three beats T-21-1 through T-21-3 own: PASS
  - No new field or constant needed. MS_PER_SECOND and _beat_token came with T-21-2 and are reused: PASS
  - The window is read through state_duration_ms, which reads Balance. No length is decided in the script: PASS
  - No AnimationPlayer and no third-party state machine plugin. A SceneTreeTimer is engine-native: PASS
  - The wait is interruptible and exits safely. On resume the beat checks four conditions before touching the machine - still the current beat by token, still in this state, not queued for deletion, still inside the tree: PASS
  - No animation and no sound played. Only events are emitted, and those come from transition_to: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and passing metrics, call
      start(), and let the sequence run. After the first two beats the console
      shows [BIRTH] pulmonary_flow -> fetal_shunts, then
      [BIRTH] beat fetal_shunts running for 10000 ms, then
      [BIRTH] fetal_shunts -> systems_online.
  - step_2: |
      Time the gap between the birth_state_changed that opens fetal_shunts and
      the one that opens systems_online. It matches the configured window.
  - step_3: |
      Repeat, and call transition_to(State.FAILURE_ROLLBACK) while the beat is
      running. The console shows
      [BIRTH] beat fetal_shunts was interrupted; exiting without advancing, and
      after the original window would have elapsed the machine is still in
      failure_rollback.
observed:
  - "step 1 and 2: fetal_shunts held 10006 ms against a configured 10000, measured signal to signal, then handed off to systems_online"
  - "step 3: interrupted mid-beat, and eleven seconds later the machine was still in failure_rollback"
  - "full observable run: ready_check at 183 ms, umbilical_stop at 183 ms, pulmonary_flow at 10061 ms, fetal_shunts at 20073 ms, systems_online at 30079 ms"
  - "the three observable phases together occupied 30079 ms against the 30000 ms table B2 allots them, a 79 ms overrun from frame quantisation across three timers"
  - "systems_online then holds, because T-21-5 has not run yet and its body is still pass, which is the expected shape of a partly built chain"
force_quit_residue: |
  Identical to T-21-2 and T-21-3 and for the same reasons. Nothing on disk; the
  beat writes no file and touches no city state. A SceneTreeTimer dies with the
  process, so no timer survives to fire against a restored machine. Because no
  beat carries a checkpoint, a force quit partway through the ending sequence
  returns the player to the readiness gate rather than to the middle of the
  sequence, which means the four E5 checks are re-evaluated honestly instead of
  resumed on stale results.
reported_not_fixed: |
  The duplication is now threefold. umbilical_stop, pulmonary_flow, and
  fetal_shunts are structurally identical and differ only in which state they
  name and which state they hand off to. They want one shared helper taking two
  state arguments.
  T-21 assigns one state per task and forbids touching another state's function,
  so collapsing them is not this task's change to make. Keeping this beat
  structurally identical to the other two is deliberate: it is what keeps that
  refactor mechanical rather than a rewrite, for whoever ends up owning it.
  T-21-5 does not extend the pattern. systems_online is the last state with a
  window that hands off, but at 5000 ms rather than 10000, and T-21-6's ending is
  terminal so it never hands off at all.
notes: |
  No file owned by another account was modified. src/project.godot is unchanged.
  docs/coord/rework/ contains no OPEN file against any upstream of this task.
completed_at: 2026-07-27T23:00:00-04:00
