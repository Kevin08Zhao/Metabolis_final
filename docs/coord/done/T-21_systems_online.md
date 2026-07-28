task_id: T-21-5
task_name: Birth transition, major systems light up
owner: ACCOUNT_C
status: DONE
base_main_commit: f68b5a4
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for systems_online
upstream:
  - docs/coord/done/T-21_fetal_shunts.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_systems_online body only)
checks:
  - Exactly one state function implemented. The remaining two bodies are still exactly pass, verified by scanning: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched. All four earlier beats were diffed function by function against main: PASS
  - No new field or constant needed. MS_PER_SECOND and _beat_token came with T-21-2: PASS
  - The window is read through state_duration_ms, which reads Balance, and the successor comes from the graph. Neither the 5000 ms length nor the handoff target is decided in this function: PASS
  - No AnimationPlayer and no third-party state machine plugin. A SceneTreeTimer is engine-native: PASS
  - The wait is interruptible and exits safely on the same four conditions as the other beats: PASS
  - No animation and no sound played. Only events are emitted, and those come from transition_to: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and passing metrics, call
      start(), and let the whole sequence run. The console shows
      [BIRTH] fetal_shunts -> systems_online, then
      [BIRTH] beat systems_online running for 5000 ms, then
      [BIRTH] systems_online -> ending.
  - step_2: |
      Confirm the machine reports is_terminal() true at the ending, that
      birth_sequence_completed fired exactly once, and that a second later the
      machine is still in ending with no further beat running.
  - step_3: |
      Repeat, and call transition_to(State.FAILURE_ROLLBACK) while the beat is
      running. The console shows
      [BIRTH] beat systems_online was interrupted; exiting without advancing,
      and after the original window would have elapsed the machine is still in
      failure_rollback with birth_sequence_completed never having fired again.
observed:
  - "systems_online held 5010 ms against a configured 5000"
  - "reached ending, is_terminal() true, birth_sequence_completed fired exactly once"
  - "one second after the ending, still in ending; no further beat runs, because the ending is terminal and T-21-6 has not run"
  - "interrupted mid-beat, and six seconds later the machine was still in failure_rollback with the completion event never re-fired"
whole_sequence_measurement: |
  This is the first run in which the machine reaches the ending, so the full
  timeline could be measured end to end for the first time.
    entered ready_check        144 ms   window     0 ms
    entered umbilical_stop     144 ms   window 10000 ms   held  9925 ms   -75
    entered pulmonary_flow   10069 ms   window 10000 ms   held 10006 ms    +6
    entered fetal_shunts     20075 ms   window 10000 ms   held 10006 ms    +6
    entered systems_online   30081 ms   window  5000 ms   held  5010 ms   +10
    entered ending           35091 ms   window 10000 ms
  Four timed beats ran 34947 ms against a configured 35000. Adding the ending
  window gives 44947 ms against the 45000 ms budget, 53 ms under.
  The sequence finishes marginally early rather than overrunning, so it does not
  eat into the operating-time budget. The first beat is consistently the outlier
  at roughly -75 ms while later beats sit within about +10 ms; that asymmetry is
  worth knowing when D-22 and D-26 time real audio against the timeline.
force_quit_residue: |
  Identical to the earlier beats and for the same reasons. Nothing on disk; the
  beat writes no file and touches no city state. A SceneTreeTimer dies with the
  process. Because no beat carries a checkpoint, a force quit partway through the
  ending sequence returns the player to the readiness gate rather than to the
  middle of the sequence, so the four E5 checks are re-evaluated honestly instead
  of resumed on stale results.
  One thing changes at this beat. It is the last state before the terminal one,
  so a force quit here loses a run that was about to succeed. The player repeats
  the whole 45-second sequence rather than resuming near its end. That follows
  from BIRTH_STATES routing every interruption back to the gate and is not a
  defect, but T-26 should know it: a save written at the ending is the first one
  that can record a completed birth.
reported_not_fixed: |
  The duplication is now fourfold, and this is the last beat that extends it.
  umbilical_stop, pulmonary_flow, fetal_shunts, and systems_online differ only in
  which state they name and which one they hand off to; a single helper taking
  those two arguments would replace all four. T-21 assigns one state per task and
  forbids touching another state's function, so collapsing them is still not this
  task's change to make. Keeping this beat structurally identical is what keeps
  that refactor mechanical.
  T-21-6's ending is terminal and never hands off, and T-21-7's failure_rollback
  carries no window, so neither of them will grow the pattern further.
also_corrected: |
  This task's acceptance run exposed an arithmetic error published in
  docs/coord/done/T-21_fetal_shunts.md, which claimed the three observable phases
  overran their budget by 79 ms. An absolute timestamp had been used as if it
  were an elapsed duration; the phases actually ran under budget. That marker now
  carries a corrections block with the remeasured figures.
notes: |
  No file owned by another account was modified. src/project.godot is unchanged.
  docs/coord/rework/ contains no OPEN file against any upstream of this task.
completed_at: 2026-07-27T23:40:00-04:00
