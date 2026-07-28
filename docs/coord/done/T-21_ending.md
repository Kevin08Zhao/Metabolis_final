task_id: T-21-6
task_name: Birth transition, ending picture
owner: ACCOUNT_C
status: DONE
base_main_commit: 28694a3
source: docs/prompts/Metabolis_Prompts_Full_v2.md · T-21 · birth transition per-state implementation, run for ending
upstream:
  - docs/coord/done/T-21_systems_online.md (status DONE)
  - docs/BIRTH_STATES.md (full text, pasted)
  - src/sim/birth_machine.gd (current full text, pasted)
outputs:
  - src/sim/birth_machine.gd (the _on_enter_ending body and two new fields only)
checks:
  - Exactly one state function implemented. The one remaining body, failure_rollback, is still exactly pass: PASS
  - transition_to unchanged, verified by diffing the function against main: PASS
  - No other state function touched. All five earlier states were diffed function by function against main: PASS
  - Two fields added at the top with comments, as the prompt permits - birth_transition_complete and first_breath_complete: PASS
  - The window is read through state_duration_ms, which reads Balance. No length is decided in the script: PASS
  - No AnimationPlayer and no third-party state machine plugin. A SceneTreeTimer is engine-native: PASS
  - The wait is interruptible and exits safely, on the same four conditions as the other beats: PASS
  - No animation and no sound played. Only events are emitted, and birth_sequence_completed was already emitted by transition_to on the way in: PASS
  - Live run on Godot 4.7.1.stable, headless, 0 script errors: PASS
what_makes_this_state_different: |
  It is terminal. Every other beat holds a window and then hands off; this one
  holds a window and then stops. The exit judgement the prompt asks for is
  therefore that there is none, which is what the graph in T-20 already encodes.
  It is also the only state that produces durable results for anyone else. The
  two flags it sets are the last two terms of final_completion_ready in
  docs/CHAPTER_TIMELINE.md, and their names come from that expression rather than
  being invented here.
  They are set at different moments on purpose. birth_transition_complete turns
  true on arrival, because by then the transition has run. first_breath_complete
  turns true only after the window has fully elapsed, because that window is the
  first breath. Setting both on arrival would let T-25 close the run before the
  ending had been seen, which is the whole point of giving it a window.
manual_test:
  - step_1: |
      Build a BirthMachine with a configured BirthCheck and passing metrics, call
      start(), and let the whole sequence run. On arrival at the ending, read the
      two flags: birth_transition_complete is already true and
      first_breath_complete is still false.
  - step_2: |
      Wait for the configured window. The console shows
      [BIRTH] first breath complete; the run is ready for T-25 to close, and both
      flags now read true. The machine is still in ending and still terminal.
  - step_3: |
      Attempt transition_to on any other state. Every attempt is refused with
      illegal_transition and the state is unchanged, including the attempt to
      roll back, since success cannot be revoked after the fact.
observed:
  - "on arrival: birth_transition_complete=true, first_breath_complete=false"
  - "ending picture held 10005 ms against a configured 10000"
  - "after the window: both flags true, still in ending, is_terminal() true"
  - "both final_completion_ready terms satisfied together for the first time"
  - "ending -> ready_check and ending -> failure_rollback both refused with illegal_transition"
  - "torn down mid-window: the machine was freed one frame into the ending, and eleven seconds later it was invalid with first_breath_complete never set"
force_quit_residue: |
  Nothing on disk, as with every other beat; this machine has no save hook and
  T-26 has not run. A SceneTreeTimer dies with the process.
  This state is where that stops being a small matter. It is the only place a
  completed birth exists at all, and it exists only in memory as two flags. A
  force quit before T-26 writes them loses the completion, and the player repeats
  the whole 45-second sequence from the readiness gate.
  Deliberately verified rather than assumed: a machine freed one frame into the
  ending window did not come back to set first_breath_complete when its timer
  fired. A torn-down run cannot report a birth it did not finish showing.
reported_not_fixed: |
  There is no event marking the end of the ending picture.
  birth_sequence_completed fires on arrival, which is when the picture starts,
  and docs/EVENT_API.md defines nothing for when it finishes. D-22 and D-26 can
  work from the arrival event plus the window they are handed, so nothing is
  blocked today, but if the ending animation ever needs a distinct completion
  hook, adding one is a T-08 revalidation and should be requested rather than
  improvised. Consumers can poll first_breath_complete in the meantime.
notes: |
  The duplication reported in T-21-3 through T-21-5 does not grow here. This
  state holds a window like the others, but it sets flags instead of handing off,
  so the shared helper those markers ask for would cover four beats, not five.
  No file owned by another account was modified. src/project.godot is unchanged.
  docs/coord/rework/ contains no OPEN file against any upstream of this task.
completed_at: 2026-07-28T00:15:00-04:00
