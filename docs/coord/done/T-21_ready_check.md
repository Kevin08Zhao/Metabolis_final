task_id: T-21-1
task_name: Birth transition, readiness check state
owner: ACCOUNT_C
status: DONE
base_main_commit: 83e2b45
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for ready_check
upstream:
  - docs/coord/done/T-20.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
  - src/sim/birth_check.gd (T-19e, consumed not modified)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_ready_check body and three new fields only)
checks:
  - Exactly one state function implemented. The other six bodies are still exactly pass, verified by scanning rather than by eye: PASS
  - transition_to unchanged. No other state function touched. File structure unchanged: PASS
  - Three new fields added at the top of the file with comments explaining their use, as the prompt permits - birth_check, city_metrics, gate_report: PASS
  - No hardcoded threshold or duration. Every threshold is read by T-19e through Balance; this state passes metrics in and reads a verdict out: PASS
  - No AnimationPlayer and no third-party state machine plugin: PASS
  - The wait is interruptible and exits safely. The verdict is submitted deferred, so if anything moves the machine out of ready_check first, the late verdict reaches submit_gate_result, which rejects it with gate_result_outside_ready_check and leaves the state untouched. Verified as step 4 below: PASS
  - No animation and no sound played. Only events are emitted, and those come from transition_to which was already in place: PASS
  - Nothing else fixed in passing. One behaviour worth reporting was found and is reported below rather than changed: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
manual_test:
  - step_1: |
      Add a BirthMachine to a scene. Create a BirthCheck, call
      configure(/root/Balance, /root/EventBus), assign it to machine.birth_check,
      and set machine.city_metrics to the Balance zero-reward baseline:
      transport_coverage 0.8, waste 45.0, stability 70.0, birth_readiness 0.78.
      Call start().
  - step_2: |
      Wait one frame, because the verdict is deferred. The console shows
      [BIRTH] idle -> ready_check, then [BIRTH CHECK] ... passed=true, then
      [BIRTH] gate evaluated: passed=true, then
      [BIRTH] ready_check -> umbilical_stop. gate_passed() is true and
      gate_report["passed"] is true.
  - step_3: |
      Repeat with every metric beyond its threshold, for example
      transport_coverage 0.2, waste 90.0, stability 10.0, birth_readiness 0.1.
      The verdict is passed=false, the machine moves ready_check ->
      failure_rollback carrying reason gate_check_failed, is_terminal() is false,
      gate_report["retry_allowed"] is true, and all four rows report a failure.
observed:
  - "step 1 and 2: gate passed, ready_check -> umbilical_stop after one frame, knowledge_entry_unlocked emitted once for hint_birth_transition"
  - "step 3: gate failed on all four rows, ready_check -> failure_rollback with gate_check_failed, not terminal, retry_allowed true"
  - "extra, no BirthCheck supplied: the gate stays at ready_check and warns rather than guessing a verdict, and an external submit_gate_result is still accepted"
  - "extra, interrupted: forcing failure_rollback before the deferred verdict lands makes the late verdict be rejected with gate_result_outside_ready_check, state unchanged"
force_quit_residue: |
  Nothing on disk. This state writes no file. gate_report, gate_passed, and the
  machine's current state are in-memory only; birth_machine has no save hook and
  T-26 has not run yet. The gate reads city metrics and never writes them, so no
  half-applied change is left in the city state and no transition is left partly
  performed.
  One side effect can outlive the process. When all four checks pass, T-19e emits
  knowledge_entry_unlocked once for hint_birth_transition. If the player force
  quits before that reaches a save, the unlock is lost and is emitted again on
  the next attempt. That is idempotent from the player's side, since the hint
  still appears once per save, and T-19e exposes restore_state so a loaded save
  can re-establish birth_transition_unlocked and birth_hint_emitted without
  re-emitting.
  Summary: no corrupt residue and no partial transition; at worst one knowledge
  hint unlock is lost and repeats.
reported_not_fixed: |
  Acknowledging a rollback returns the machine to ready_check, which re-runs the
  gate immediately against whatever city_metrics currently holds. If the caller
  has not refreshed those metrics, the same verdict repeats and the machine
  bounces straight back to failure_rollback. This is correct behaviour and it
  matches the OPERATION_SPEC guarantee that a failed check does not lock the
  flow, but it means the caller must refresh city_metrics between attempts.
  T-25 owns that integration. Per the prompt's instruction not to fix other
  things in passing, this is reported and not changed.
blocking_dependency: |
  Unchanged from T-20 and still open. docs/BALANCE.json has no
  chapters.stage_birth.birth_sequence.* keys, so window_ms reads 0 on every
  event. T-21-1 does not need them, because the readiness gate carries no window
  on the 45-second timeline. T-21-2 does.
notes: |
  No file owned by another account was modified. src/sim/birth_check.gd is
  consumed through its public interface and left untouched. src/project.godot is
  unchanged. docs/coord/rework/ contains no OPEN file against T-20.
completed_at: 2026-07-27T21:00:00-04:00
