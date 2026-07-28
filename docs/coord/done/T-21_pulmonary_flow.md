task_id: T-21-3
task_name: Birth transition, pulmonary blood flow rises
owner: ACCOUNT_C
status: DONE
base_main_commit: f2c07f5
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for pulmonary_flow
upstream:
  - docs/coord/done/T-21_umbilical_stop.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_pulmonary_flow body only)
checks:
  - Exactly one state function implemented. The remaining four bodies are still exactly pass, verified by scanning: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched, including both beats T-21-1 and T-21-2 own: PASS
  - No new field or constant needed. MS_PER_SECOND and _beat_token were already added by T-21-2 and are reused: PASS
  - The window is read through state_duration_ms, which reads Balance. No length is decided in the script: PASS
  - No AnimationPlayer and no third-party state machine plugin. A SceneTreeTimer is engine-native: PASS
  - The wait is interruptible and exits safely. On resume the beat checks four conditions before touching the machine - still the current beat by token, still in this state, not queued for deletion, still inside the tree: PASS
  - No animation and no sound played. Only events are emitted, and those come from transition_to: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and passing metrics, call
      start(), and let the sequence run. The console shows
      [BIRTH] umbilical_stop -> pulmonary_flow, then
      [BIRTH] beat pulmonary_flow running for 10000 ms, then
      [BIRTH] pulmonary_flow -> fetal_shunts.
  - step_2: |
      Time the gap between the birth_state_changed that opens pulmonary_flow and
      the one that opens fetal_shunts. It matches the configured window.
  - step_3: |
      Repeat, and call transition_to(State.FAILURE_ROLLBACK) while the beat is
      running. The console shows
      [BIRTH] beat pulmonary_flow was interrupted; exiting without advancing,
      and after the original window would have elapsed the machine is still in
      failure_rollback.
observed:
  - "step 1: umbilical_stop -> pulmonary_flow -> fetal_shunts, each beat announcing its 10000 ms window"
  - "step 2: pulmonary_flow held 10004 ms against a configured 10000, measured signal to signal"
  - "step 3: interrupted mid-beat, and eleven seconds later the machine was still in failure_rollback"
  - "whole sequence so far: entered ready_check at 135 ms, umbilical_stop at 135 ms, pulmonary_flow at 10066 ms, fetal_shunts at 20070 ms"
force_quit_residue: |
  Identical to T-21-2 and for the same reasons. Nothing on disk; the beat writes
  no file and touches no city state. A SceneTreeTimer dies with the process, so
  no timer survives to fire against a restored machine. Because no beat carries a
  checkpoint, a force quit partway through the ending sequence returns the player
  to the readiness gate rather than to the middle of the sequence, which means
  the four E5 checks are re-evaluated honestly instead of resumed on stale
  results.
reported_not_fixed: |
  The three timed beats - umbilical_stop, pulmonary_flow, and the fetal_shunts
  beat T-21-4 will write - are structurally identical and differ only in which
  state they name. Folding them into one shared helper would remove the
  duplication, but T-21 assigns one state per task and forbids touching another
  state's function, so it is not this task's change to make. Reported here so
  whoever owns the refactor can take all three at once rather than discovering
  the pattern late.
notes: |
  No file owned by another account was modified. src/project.godot is unchanged.
  docs/coord/rework/ contains no OPEN file against any upstream of this task; the
  T-06 report this chain filed is now resolved.
completed_at: 2026-07-27T22:20:00-04:00
