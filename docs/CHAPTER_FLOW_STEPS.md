# Chapter Flow Step Gating

Companion table for `src/core/chapter_flow.gd`. It records what opens and closes
each of the ten steps every stage runs, and where the two stage specials come
from. The state machine drives the loop and triggers carryover; it implements no
step's internal logic.

Stage configuration is read through `Balance` at `chapters.<stage_id>.*`, which
carries the values locked by `docs/CHAPTER_TIMELINE.md`. Nothing about a stage is
written as a literal in the script, including the specials.

`_current_step` is assigned in exactly one place, `advance_to`. No other function
writes it.

## Table C1: The ten steps

| # | `Step` | `step_id` | Opens when | Closes when | Placeholder replaced by |
|---:|---|---|---|---|---|
| 1 | `OBSERVE_STATE` | `observe_state` | The stage is loaded, or step 10 of the previous stage completed | No blocking modal is open | T-29, T-19g |
| 2 | `RECEIVE_TARGETS` | `receive_targets` | Step 1 closed | `available_build_option_ids` is non-empty, sourced from `build_options.<decision_id>.available_option_ids` | T-13, T-13a |
| 3 | `OPTIONAL_MINIGAME` | `optional_minigame` | Step 2 closed | Always. Never a gate — see "The optional step is not a gate" below | T-19a |
| 4 | `RESOURCE_SETTLEMENT` | `resource_settlement` | Step 3 closed | Settlement returned | T-17 |
| 5 | `BUILD_DECISION` | `build_decision` | Step 4 closed, or step 6 closed with required decisions outstanding | `active_build_decision_id` is in `confirmed_build_decision_ids` | T-13 |
| 6 | `BUILD_COMPLETION` | `build_completion` | Step 5 closed | Completion returned. Routes back to step 5 while any required decision is unconfirmed | T-14, T-15a |
| 7 | `OPERATION_DECISION` | `operation_decision` | Step 6 closed with every required build decision confirmed | `active_operation_decision_id` is in `confirmed_operation_decision_ids` | T-19f |
| 8 | `SYSTEM_ACTIVATION` | `system_activation` | Step 7 closed | `system_observation_complete` is true | T-19 |
| 9 | `KNOWLEDGE_UNLOCK` | `knowledge_unlock` | Step 8 closed | `knowledge_unlock_resolved` is true | T-30 |
| 10 | `STAGE_COMPLETE` | `stage_complete` | Step 9 closed | `is_stage_exit_ready()` holds — see table C2 | T-25, T-19e |

`step_id` is what `ChapterData.phase` stores. The first entry matches
`chapters.<stage_id>.initial_phase` in `BALANCE.json`.

## Table C2: The stage-exit boolean

`is_stage_exit_ready()` implements the `stage_exit_ready` expression of
`docs/CHAPTER_TIMELINE.md` term for term. The current-stage and phase terms of
that expression are structural in the state machine, so the function evaluates the
remaining five:

| Term | Source |
|---|---|
| `required_build_decision_ids.is_subset_of(confirmed_build_decision_ids)` | `chapters.<stage_id>.required_build_decision_ids` |
| `required_operation_decision_ids.is_subset_of(confirmed_operation_decision_ids)` | `chapters.<stage_id>.required_operation_decision_ids` |
| `system_observation_complete == true` | `ChapterData`, seeded from `system_observation_complete_initial` |
| `knowledge_unlock_resolved == true` | `ChapterData`, seeded from `knowledge_unlock_resolved_initial` |
| `blocking_modal_open == false` | `ChapterData`, seeded from `ui.blocking_modal_open_initial` |

Stage four additionally requires `birth_check_passed`, `birth_transition_complete`,
and `first_breath_complete` for `final_completion_ready`. Those belong to T-19e,
T-20, and T-25; this class reports only that its own conditions hold.

## Table C3: The two stage specials

Both fall out of configuration. Neither is branched on a stage name.

| Special | Configuration that produces it | Effect |
|---|---|---|
| Stage one has a single build decision | `chapters.stage_origin.required_build_decision_ids` has one entry | Step 6 routes straight to step 7 because every required decision is already confirmed. Stages two through four have two entries, so steps 5 and 6 run twice |
| Stage four performs no step-ten carryover | `chapters.stage_birth.next_stage_id` is `null` | Leaving step 10 completes the run: no `stage_advanced`, no snapshot write, no carryover application. The `run_completed` signal fires instead |

Stage four also has `minigame_id: null`, which needs no special handling because
step 3 never gates.

## The optional step is not a gate

`docs/CHAPTER_TIMELINE.md` states that the minigame does not appear in the
stage-exit condition, and that skipping it, completing it, or never entering it all
leave the main line free to advance. Step 3 therefore always closes. T-19a records
the resolution in `ChapterData.minigame_resolution` for display; the flow reads it
for nothing.

This makes stage four ordinary rather than special: a stage with no minigame
behaves exactly like a stage whose minigame was skipped.

## Events the flow emits

The state machine owns four events from `docs/EVENT_API.md`. Everything else is
emitted by the task that owns the step.

| Event | Emitted at |
|---|---|
| `phase_changed` | Every real step change, from `advance_to`. Entering the first stage establishes the initial step rather than changing it, so that one case is logged but not emitted |
| `stage_advanced` | Leaving step 10 when `next_stage_id` is not null, before the next stage is entered |
| `stage_loaded` | After the entered stage's `ChapterData` is built and its step is set to 1 |
| `stage_snapshot_written` | From the carryover placeholder, only on a first visit to the entered stage. Table F2 of `docs/CARRYOVER_SPEC.md` commits on first entry, which is after `stage_loaded`. A replay visit writes nothing and must not emit it |
| `carryover_applied` | From the carryover placeholder, on every entry including replay |

The last two belong to T-19h and T-26 and move there when those tasks land.

## Logging

Every transition prints one line:

```text
[FLOW] stage <one-based stage number>  <old step> -> <new step>
```

The first line of a run reads `(start) -> observe_state`, since no step preceded
it.

## Acceptance driver

Attach this to any `Node` in a scene and run it. It requires the `EventBus` and
`Balance` autoloads.

```gdscript
extends Node


func _ready() -> void:
	var flow := ChapterFlow.new()
	add_child(flow)

	if not flow.start_new_run():
		push_error("start_new_run failed")
		return

	while not flow.is_run_complete():
		if not flow.advance():
			push_error("stuck at stage %d step %s" % [flow.stage_number(), flow.current_step_id()])
			return
		if flow.stage_number() == 2 and flow.current_step() == ChapterFlow.Step.OBSERVE_STATE:
			print(">>> reached stage 2 step 1 <<<")
			return
```

Observed output, from stage one's opening through to stage two's step 1:

```text
[FLOW] stage 1  (start) -> observe_state
[FLOW] stage 1  observe_state -> receive_targets
[FLOW] stage 1  receive_targets -> optional_minigame
[FLOW] stage 1  optional_minigame -> resource_settlement
[FLOW] stage 1  resource_settlement -> build_decision
[FLOW] stage 1  build_decision -> build_completion
[FLOW] stage 1  build_completion -> operation_decision
[FLOW] stage 1  operation_decision -> system_activation
[FLOW] stage 1  system_activation -> knowledge_unlock
[FLOW] stage 1  knowledge_unlock -> stage_complete
[FLOW] stage 2  stage_complete -> observe_state
>>> reached stage 2 step 1 <<<
```

Stage one goes `build_decision -> build_completion -> operation_decision` with no
return to step 5, which is the single-build-decision special showing up without a
stage-name branch. Stage two shows the other side:

```text
[FLOW] stage 2  build_decision -> build_completion
[FLOW] stage 2  build_completion -> build_decision
[FLOW] stage 2  build_decision -> build_completion
[FLOW] stage 2  build_completion -> operation_decision
```

Running past stage two reaches the terminal state:

```text
[FLOW] stage 4  knowledge_unlock -> stage_complete
[FLOW] stage 4  stage_complete -> run_complete
```

Across the full run the flow emits four `stage_loaded`, three `stage_advanced`,
three `stage_snapshot_written`, and three `carryover_applied`. Stage four
contributes none of the last three, which is the no-carryover special.

## Registration requirement

`ChapterFlow` fails to parse unless `EventBus` and `Balance` are registered as
autoloads. Neither registration is currently committed to `src/project.godot`. See
the note in `docs/coord/done/T-19d.md`.
