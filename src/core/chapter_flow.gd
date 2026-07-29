class_name ChapterFlow
extends Node

## Chapter flow state machine.
##
## Drives the fixed ten-step loop of every stage, controls when each step may be
## left, and triggers carryover at a stage boundary. It implements no step's
## internal logic: each step calls a placeholder that returns immediately.
##
## Single source of stage configuration is docs/CHAPTER_TIMELINE.md, reached
## through `Balance` at `chapters.<stage_id>.*`. Nothing about a stage is
## hardcoded here, including the two known specials: stage one having a single
## build decision, and stage four having no step-ten carryover. Both fall out of
## `required_build_decision_ids` and `next_stage_id`.
##
## `_current_step` is assigned in exactly one place, `advance_to`. No other
## function may write it.
##
## Requires the `EventBus` and `Balance` autoloads to be registered.

enum Step {
	OBSERVE_STATE,
	RECEIVE_TARGETS,
	OPTIONAL_MINIGAME,
	RESOURCE_SETTLEMENT,
	BUILD_DECISION,
	BUILD_COMPLETION,
	OPERATION_DECISION,
	SYSTEM_ACTIVATION,
	KNOWLEDGE_UNLOCK,
	STAGE_COMPLETE,
}

## Step identifiers as persisted in `ChapterData.phase`. Index matches `Step`.
## The first entry matches `chapters.<stage_id>.initial_phase` in BALANCE.json.
const STEP_IDS: Array[StringName] = [
	&"observe_state",
	&"receive_targets",
	&"optional_minigame",
	&"resource_settlement",
	&"build_decision",
	&"build_completion",
	&"operation_decision",
	&"system_activation",
	&"knowledge_unlock",
	&"stage_complete",
]

const LOG_PREFIX := "[FLOW]"

## Emitted when the whole run reaches its terminal state, that is when a stage
## with no `next_stage_id` finishes. T-25 owns what happens next.
signal run_completed(final_stage_id: StringName)

## Stage data for the stage currently being played. Owned by T-09.
var chapter: ChapterData = null

var _current_step: int = Step.OBSERVE_STATE
## True between start_new_run and the first advance_to of the run. Entering the
## first stage establishes the initial step rather than changing it, so that one
## call is logged but emits nothing. This flag exists so start_new_run never has
## to write _current_step itself.
var _run_starting: bool = false
var _stage_order: Array[StringName] = []
var _stage_index: int = 0
var _run_complete: bool = false
var _visited_stage_ids: Array[StringName] = []


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

## Build the stage order from configuration and enter the first stage.
## Returns false when configuration is missing, without leaving a partial state.
func start_new_run() -> bool:
	_stage_order = _read_stage_order()
	if _stage_order.is_empty():
		push_error("%s Could not build the stage order from configuration; the run was not started." % LOG_PREFIX)
		return false

	_run_complete = false
	_visited_stage_ids = []
	_stage_index = 0
	_run_starting = true
	_enter_stage(_stage_order[0])
	return true


## Try to leave the current step. Returns true when the step actually changed.
## This is the only entry point callers should use; it never mutates
## `_current_step` itself but routes through `advance_to`.
func advance() -> bool:
	if _run_complete:
		push_warning("%s The run is already complete; ignoring the advance request." % LOG_PREFIX)
		return false

	if chapter == null:
		push_error("%s No stage is loaded; call start_new_run first." % LOG_PREFIX)
		return false

	_run_step_placeholder(_current_step)

	if not can_exit_current_step():
		return false

	if _current_step == Step.STAGE_COMPLETE:
		return _leave_final_step()

	advance_to(_next_step_after(_current_step))
	return true


## The single mutator of the current step. Logs the transition and emits the
## matching EVENT_API event. Every step change in this class routes through here.
func advance_to(next_step: int) -> void:
	if next_step < 0 or next_step >= STEP_IDS.size():
		push_error("%s Rejected an out-of-range step: %s" % [LOG_PREFIX, next_step])
		return

	var previous_step := _current_step
	_current_step = next_step

	if chapter != null:
		chapter.phase = STEP_IDS[_current_step]

	# Entering the first stage establishes the initial step rather than changing
	# it. docs/EVENT_API.md fires phase_changed only when the phase actually
	# changes, so the opening call is logged but not emitted.
	var is_run_start := _run_starting
	_run_starting = false
	var is_change := (not is_run_start) and previous_step != _current_step
	var previous_label: String = "(start)" if is_run_start else String(STEP_IDS[previous_step])

	print(
		"%s stage %d  %s -> %s"
		% [LOG_PREFIX, stage_number(), previous_label, STEP_IDS[_current_step]]
	)

	if is_change:
		EventBus.phase_changed.emit(previous_step, _current_step)


## Whether the current step's exit condition is satisfied. Every condition is
## derived from stage configuration and `ChapterData`, never from a literal.
func can_exit_current_step() -> bool:
	if chapter == null:
		return false

	match _current_step:
		Step.OBSERVE_STATE:
			return not chapter.blocking_modal_open
		Step.RECEIVE_TARGETS:
			return not chapter.available_build_option_ids.is_empty()
		Step.OPTIONAL_MINIGAME:
			# Never a gate. docs/CHAPTER_TIMELINE.md states that the minigame
			# does not appear in the stage-exit condition and that skipping,
			# completing, or never entering it all leave the main line free to
			# advance. Stage four, which has no minigame at all, is the same
			# case rather than a special one. T-19a records the resolution in
			# ChapterData; the flow reads it for display, never for gating.
			return true
		Step.RESOURCE_SETTLEMENT:
			return true
		Step.BUILD_DECISION:
			return chapter.confirmed_build_decision_ids.has(chapter.active_build_decision_id)
		Step.BUILD_COMPLETION:
			return true
		Step.OPERATION_DECISION:
			return chapter.confirmed_operation_decision_ids.has(chapter.active_operation_decision_id)
		Step.SYSTEM_ACTIVATION:
			return chapter.system_observation_complete
		Step.KNOWLEDGE_UNLOCK:
			return chapter.knowledge_unlock_resolved
		Step.STAGE_COMPLETE:
			return is_stage_exit_ready()
		_:
			return false


## The `stage_exit_ready` boolean of docs/CHAPTER_TIMELINE.md, implemented as
## written. Stage four additionally requires the checks T-19e and T-20 own; this
## class only reports that its own conditions hold.
func is_stage_exit_ready() -> bool:
	if chapter == null:
		return false
	return (
		_is_subset_of(chapter.required_build_decision_ids, chapter.confirmed_build_decision_ids)
		and _is_subset_of(chapter.required_operation_decision_ids, chapter.confirmed_operation_decision_ids)
		and chapter.system_observation_complete
		and chapter.knowledge_unlock_resolved
		and not chapter.blocking_modal_open
	)


func current_step() -> int:
	return _current_step


func current_step_id() -> StringName:
	return STEP_IDS[_current_step]


func current_stage_id() -> StringName:
	return chapter.stage_id if chapter != null else &""


## One-based stage number used by the [FLOW] log and the timeline UI.
func stage_number() -> int:
	return _stage_index + 1


func is_run_complete() -> bool:
	return _run_complete


# ---------------------------------------------------------------------------
# Step routing
# ---------------------------------------------------------------------------

## Steps five and six repeat until every required build decision is confirmed.
## Stage one exits after one pass because its configuration lists one decision;
## the count is never checked against a literal.
func _next_step_after(step: int) -> int:
	if step == Step.BUILD_COMPLETION and not _all_build_decisions_confirmed():
		_offer_next_build_decision()
		return Step.BUILD_DECISION
	return step + 1


func _all_build_decisions_confirmed() -> bool:
	return _is_subset_of(chapter.required_build_decision_ids, chapter.confirmed_build_decision_ids)


func _offer_next_build_decision() -> void:
	for decision_id in chapter.required_build_decision_ids:
		if not chapter.confirmed_build_decision_ids.has(decision_id):
			chapter.active_build_decision_id = decision_id
			chapter.selected_build_option_id = &""
			chapter.selected_build_slot_id = &""
			return


## Leaving step ten either advances to the next stage or completes the run.
## Stage four carries nothing over because its `next_stage_id` is null.
func _leave_final_step() -> bool:
	var from_stage_id := chapter.stage_id
	var to_stage_id := chapter.next_stage_id

	if to_stage_id == &"":
		_run_complete = true
		print("%s stage %d  %s -> run_complete" % [LOG_PREFIX, stage_number(), STEP_IDS[_current_step]])
		run_completed.emit(from_stage_id)
		return true

	EventBus.stage_advanced.emit(from_stage_id, to_stage_id)
	_stage_index += 1
	_enter_stage(to_stage_id)
	_placeholder_apply_carryover(from_stage_id, to_stage_id)
	return true


func _enter_stage(stage_id: StringName) -> void:
	chapter = ChapterData.new()
	var stage_config := _stage_config(stage_id)
	chapter.initialize_from_balance(stage_config)
	_apply_stage_config(stage_config, stage_id)

	advance_to(Step.OBSERVE_STATE)
	EventBus.stage_loaded.emit(stage_id, _stage_index)


## Copy configuration into ChapterData. T-09 owns `initialize_from_balance`,
## which is still a stub, so this class fills the fields it needs to gate on and
## will drop this function once T-09 implements it.
func _apply_stage_config(stage_config: Dictionary, stage_id: StringName) -> void:
	chapter.stage_id = stage_id
	chapter.next_stage_id = _to_string_name(stage_config.get("next_stage_id"))
	chapter.required_build_decision_ids = _to_string_name_array(stage_config.get("required_build_decision_ids", []))
	chapter.required_operation_decision_ids = _to_string_name_array(stage_config.get("required_operation_decision_ids", []))
	chapter.required_organ_ids = _to_string_name_array(stage_config.get("required_organ_ids", []))
	chapter.confirmed_build_decision_ids.clear()
	chapter.confirmed_operation_decision_ids.clear()
	chapter.active_build_decision_id = _to_string_name(stage_config.get("first_build_decision_id"))
	chapter.active_operation_decision_id = _to_string_name(stage_config.get("operation_decision_id"))
	chapter.stage_minigame_id = _to_string_name(stage_config.get("minigame_id"))
	chapter.minigame_resolution = _pending_minigame_resolution()
	chapter.system_observation_complete = bool(stage_config.get("system_observation_complete_initial", false))
	chapter.knowledge_unlock_resolved = bool(stage_config.get("knowledge_unlock_resolved_initial", false))
	chapter.blocking_modal_open = bool(Balance.get_value("ui.blocking_modal_open_initial", false))
	chapter.available_build_option_ids.clear()
	chapter.available_operation_ids.clear()


# ---------------------------------------------------------------------------
# Step placeholders
#
# Each one stands in for the task that will own the step, returns immediately,
# and records only the outcome the next gate reads. None of them implements the
# step. When the owning task lands, its handler replaces the body here.
# ---------------------------------------------------------------------------

## Handlers registered for a step, keyed by the `Step` ordinal. A step with a
## handler calls it and never reaches its placeholder.
##
## This is the seam the placeholders below were written against. Their comments
## say the owning task's handler replaces the body; registering one does exactly
## that, without this class learning what any system is. An unassembled run,
## which is every acceptance driver written before the systems were wired
## together, registers nothing and behaves exactly as it did.
var _step_handlers: Dictionary = {}


## Register the real behaviour of a step. Passing an invalid callable clears the
## registration and returns the step to its placeholder.
func register_step_handler(step: int, handler: Callable) -> bool:
	if step < 0 or step >= STEP_IDS.size():
		push_error("%s Rejected a handler for an out-of-range step: %s" % [LOG_PREFIX, step])
		return false
	if not handler.is_valid():
		_step_handlers.erase(step)
		return true
	_step_handlers[step] = handler
	return true


func has_step_handler(step: int) -> bool:
	return _step_handlers.has(step)


func _run_step_placeholder(step: int) -> void:
	if _step_handlers.has(step):
		var handler: Callable = _step_handlers[step]
		if handler.is_valid():
			handler.call()
			return
		push_warning(
			"%s The handler for step %s became invalid; falling back to the placeholder."
			% [LOG_PREFIX, STEP_IDS[step]]
		)
		_step_handlers.erase(step)

	match step:
		Step.OBSERVE_STATE:
			_placeholder_observe_state()
		Step.RECEIVE_TARGETS:
			_placeholder_receive_targets()
		Step.OPTIONAL_MINIGAME:
			_placeholder_optional_minigame()
		Step.RESOURCE_SETTLEMENT:
			_placeholder_resource_settlement()
		Step.BUILD_DECISION:
			_placeholder_build_decision()
		Step.BUILD_COMPLETION:
			_placeholder_build_completion()
		Step.OPERATION_DECISION:
			_placeholder_operation_decision()
		Step.SYSTEM_ACTIVATION:
			_placeholder_system_activation()
		Step.KNOWLEDGE_UNLOCK:
			_placeholder_knowledge_unlock()
		Step.STAGE_COMPLETE:
			_placeholder_stage_complete()


## Replaced by T-29 and T-19g.
func _placeholder_observe_state() -> void:
	return


## Replaced by T-13 and T-13a.
func _placeholder_receive_targets() -> void:
	if not chapter.available_build_option_ids.is_empty():
		return
	var path := "build_options.%s.available_option_ids" % chapter.active_build_decision_id
	chapter.available_build_option_ids = _to_string_name_array(Balance.get_value(path, []))


## Replaced by T-19a. Leaving the resolution at its configured initial value is
## the honest skeleton outcome: no run was offered and none was played. The flow
## does not gate on it either way, so nothing downstream is blocked.
func _placeholder_optional_minigame() -> void:
	return


## Replaced by T-17.
func _placeholder_resource_settlement() -> void:
	return


## Replaced by T-13.
func _placeholder_build_decision() -> void:
	if chapter.confirmed_build_decision_ids.has(chapter.active_build_decision_id):
		return
	chapter.confirmed_build_decision_ids.append(chapter.active_build_decision_id)


## Replaced by T-14 and T-15a.
func _placeholder_build_completion() -> void:
	return


## Replaced by T-19f.
func _placeholder_operation_decision() -> void:
	if chapter.confirmed_operation_decision_ids.has(chapter.active_operation_decision_id):
		return
	chapter.confirmed_operation_decision_ids.append(chapter.active_operation_decision_id)


## Replaced by T-19.
func _placeholder_system_activation() -> void:
	chapter.system_observation_complete = true


## Replaced by T-30.
func _placeholder_knowledge_unlock() -> void:
	chapter.knowledge_unlock_resolved = true


## Replaced by T-25 and T-19e.
func _placeholder_stage_complete() -> void:
	return


## Replaced by T-19h and T-26. Per table F2 of docs/CARRYOVER_SPEC.md the record
## is committed when the entered stage is reached for the first time, which is
## after `stage_loaded`, so both events are emitted from here rather than from
## `_leave_final_step`. On a replay visit nothing is written and
## `stage_snapshot_written` must not fire.
func _placeholder_apply_carryover(from_stage_id: StringName, to_stage_id: StringName) -> void:
	var carryover := {
		&"network_efficiency_coefficient": 0.0,
		&"initial_operation_pressure": 0.0,
		&"initial_waste_accumulation": 0.0,
	}

	if not _visited_stage_ids.has(to_stage_id):
		_visited_stage_ids.append(to_stage_id)
		EventBus.stage_snapshot_written.emit(to_stage_id, carryover)

	EventBus.carryover_applied.emit(from_stage_id, to_stage_id, carryover)


# ---------------------------------------------------------------------------
# Configuration access
# ---------------------------------------------------------------------------

## Walk `next_stage_id` from the configured starting stage. The order is never
## taken from dictionary iteration order and never listed literally here.
func _read_stage_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var stage_id := _to_string_name(Balance.get_value("progress.initial.current_stage_id", null))

	while stage_id != &"":
		if order.has(stage_id):
			push_error("%s The stage chain revisits '%s'; the order is not linear." % [LOG_PREFIX, stage_id])
			return []
		order.append(stage_id)
		var stage_config := _stage_config(stage_id)
		if stage_config.is_empty():
			push_error("%s Missing configuration for stage '%s'." % [LOG_PREFIX, stage_id])
			return []
		stage_id = _to_string_name(stage_config.get("next_stage_id"))

	return order


func _stage_config(stage_id: StringName) -> Dictionary:
	var value: Variant = Balance.get_value("chapters.%s" % stage_id, {})
	return value if value is Dictionary else {}


func _pending_minigame_resolution() -> StringName:
	return _to_string_name(Balance.get_value("minigames.runtime.initial_resolution", null))


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

## A configured null becomes the empty StringName, which is how this class spells
## "stage four has no next stage" and "stage four has no minigame".
func _to_string_name(value: Variant) -> StringName:
	if value == null:
		return &""
	return StringName(str(value))


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			result.append(StringName(str(entry)))
	return result


func _is_subset_of(required: Array[StringName], present: Array[StringName]) -> bool:
	for entry in required:
		if not present.has(entry):
			return false
	return true
