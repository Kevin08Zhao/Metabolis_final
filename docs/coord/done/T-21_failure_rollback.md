task_id: T-21-7
task_name: Birth transition, failure rollback
owner: ACCOUNT_C
status: DONE
base_main_commit: 958936c
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for failure_rollback
upstream:
  - docs/coord/done/T-21_ending.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_failure_rollback body only)
checks:
  - Exactly one state function implemented. This is the seventh and last, so no body remains as pass: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched. All six earlier states were diffed function by function against main: PASS
  - No new field or constant needed: PASS
  - No hardcoded gameplay value. This state has no window and reads no threshold; the thresholds it displays were produced by T-19e: PASS
  - No AnimationPlayer and no third-party state machine plugin. No timer either, because this state waits for a person rather than a clock: PASS
  - Exits safely. The exit is acknowledge_rollback, already in place since T-20, and it is the only way out: PASS
  - No animation and no sound played. Only events are emitted, and birth_rolled_back was already emitted by transition_to on the way in: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
what_this_state_does: |
  It unwinds the attempt so a retry starts from a clean machine, and then waits.
  What is unwound is only this machine's own state. The rollback never touches the
  city, the organs, or the resources, so there is nothing out there to undo and
  nothing that could be left half undone. That is what makes the guarantee in
  docs/BIRTH_STATES.md cheap to keep: this is never a death, a game over, or a
  lost run, because nothing was destroyed to begin with.
  Three things are reset - the gate verdict and the two completion flags - and one
  thing is deliberately kept.
  gate_report is kept on purpose. It holds the four checks with their current
  values, thresholds, gaps, and recovery directions, and this state is exactly
  where the player reads them to learn what to fix. Clearing it here would throw
  away the only explanation of why the attempt stopped.
  The in-flight beat is cancelled by bumping the beat token. The beat's own guard
  already refuses to advance a machine that has left its state, so this is belt
  and braces, but it makes the cancellation deliberate rather than incidental.
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and metrics that fail
      every check, then call start(). One frame later the machine is in
      failure_rollback, is_terminal() is false, gate_passed() is false, both
      completion flags are false, and gate_report still holds all four failing
      rows.
  - step_2: |
      Fix city_metrics, call acknowledge_rollback(), and let the run proceed. The
      gate re-runs against the new metrics, passes, and the sequence goes all the
      way to the ending with both completion flags true. A rolled-back attempt
      leaves nothing that blocks a later success.
  - step_3: |
      Repeat, but trigger the rollback from a running beat rather than from the
      gate. The cancelled beat's timer fires with the machine still in
      failure_rollback and does not advance it; acknowledging returns to the gate
      as usual.
observed:
  - "gate failed: state failure_rollback, not terminal, gate_passed false, both completion flags false, retry_allowed true"
  - "gate_report readable during the rollback, all four rows with values, thresholds, gaps and recovery directions"
  - "transport_coverage current 0.20 minimum 0.70 gap 0.50, recovery increase_transport_capacity_or_choose_transport_priority"
  - "waste current 90.00 maximum 50.00 gap 40.00, recovery increase_waste_priority_and_wait_for_processing"
  - "stability current 10.00 minimum 55.00 gap 45.00, recovery resolve_bottlenecks_and_wait_for_recovery"
  - "birth_readiness current 0.10 minimum 0.70 gap 0.60, recovery support_lung_exchange_and_pulmonary_interface"
  - "after fixing the metrics and acknowledging: gate passed, run reached the ending, birth_transition_complete and first_breath_complete both true"
  - "rollback from a running beat: the cancelled beat's timer fired with the machine still in failure_rollback and did not advance it; acknowledging returned to the gate"
force_quit_residue: |
  Nothing on disk, and less at stake here than anywhere else in the chain. This
  state holds no completion, no partial progress, and no timer. A force quit
  during a rollback loses only the fact that a rollback was in progress, and the
  next run begins at the readiness gate, which is where the rollback was heading
  anyway.
  The one thing lost is the explanation: gate_report is in memory, so a force quit
  discards the four rows telling the player what to fix. They are regenerated the
  moment the gate runs again, so the loss is momentary rather than permanent.
reported_not_fixed: |
  Nothing new. The shared-helper refactor reported in T-21-3 through T-21-5 still
  stands and covers four beats; this state does not extend it, having no window
  and no handoff.
  The missing end-of-ending-picture event reported in T-21-6 also still stands.
notes: |
  This completes the seven-state birth machine. Every body that was pass in T-20
  now has an implementation, and transition_to has not been touched since T-20
  delivered it - verified against main on each of the seven runs.
  T-22, the input lock, requires all seven markers and is now unblocked.
  No file owned by another account was modified. src/project.godot is unchanged.
  docs/coord/rework/ contains no OPEN file against any upstream of this task.
completed_at: 2026-07-28T00:45:00-04:00
