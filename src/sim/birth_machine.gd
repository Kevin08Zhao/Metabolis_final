class_name BirthMachine
extends Node

## Birth transition state machine, skeleton.
##
## Birth is a controlled state machine, never a dynamic simulation. Seven states,
## a fixed legal transition graph, and a fixed millisecond timeline, all defined
## by docs/BIRTH_STATES.md.
##
## This file is the skeleton. Every state body is deliberately empty; T-21-1
## through T-21-7 fill them one state at a time, and none of them changes the
## graph or the routing. `_current_state` is assigned in exactly one place,
## `transition_to`.
##
## The entry gate is the four birth checks of table E5, already implemented by
## T-19e as `src/sim/birth_check.gd`. This machine consumes that verdict and does
## not re-derive it.
##
## State durations are read through `Balance`. The keys listed in
## docs/BIRTH_STATES.md do not exist in docs/BALANCE.json yet, so
## `state_duration_ms` warns and returns zero until T-06 adds them. The graph and
## the rejection rules do not depend on them.
##
## Every state change mounts on section 9 of docs/EVENT_API.md. Illegal
## transitions reuse `action_rejected` from section 8.
##
## Requires the `EventBus` and `Balance` autoloads.

enum State {
	IDLE,
	READY_CHECK,
	UMBILICAL_STOP,
	PULMONARY_FLOW,
	FETAL_SHUNTS,
	SYSTEMS_ONLINE,
	ENDING,
	FAILURE_ROLLBACK,
}

## Persisted spellings. Index matches `State`.
const STATE_IDS: Array[StringName] = [
	&"idle",
	&"ready_check",
	&"umbilical_stop",
	&"pulmonary_flow",
	&"fetal_shunts",
	&"systems_online",
	&"ending",
	&"failure_rollback",
]

## Balance key suffix per state, under `chapters.<stage_id>.birth_sequence.`.
## States with no window on the 45-second timeline map to an empty suffix.
const DURATION_KEYS := {
	State.IDLE: "",
	State.READY_CHECK: "",
	State.UMBILICAL_STOP: "umbilical_stop_ms",
	State.PULMONARY_FLOW: "pulmonary_flow_ms",
	State.FETAL_SHUNTS: "fetal_shunts_ms",
	State.SYSTEMS_ONLINE: "systems_online_ms",
	State.ENDING: "ending_ms",
	State.FAILURE_ROLLBACK: "",
}

## The legal transition graph of table B3. Anything absent here is illegal by
## construction rather than by a chain of conditionals.
const LEGAL_TRANSITIONS := {
	State.IDLE: [State.READY_CHECK],
	State.READY_CHECK: [State.UMBILICAL_STOP, State.FAILURE_ROLLBACK],
	State.UMBILICAL_STOP: [State.PULMONARY_FLOW, State.FAILURE_ROLLBACK],
	State.PULMONARY_FLOW: [State.FETAL_SHUNTS, State.FAILURE_ROLLBACK],
	State.FETAL_SHUNTS: [State.SYSTEMS_ONLINE, State.FAILURE_ROLLBACK],
	State.SYSTEMS_ONLINE: [State.ENDING, State.FAILURE_ROLLBACK],
	State.ENDING: [],
	State.FAILURE_ROLLBACK: [State.READY_CHECK],
}

const STAGE_ID := &"stage_birth"
const LOG_PREFIX := "[BIRTH]"
const ACTION_ID := &"birth_transition"

## Reason codes carried by `birth_rolled_back`. These identify why a rollback
## happened; they are not tunable gameplay parameters.
const REASON_GATE_CHECK_FAILED := &"gate_check_failed"
const REASON_PRECONDITION_LOST := &"precondition_lost"

## Added by T-21-1. Supplied by the caller before start(). The readiness gate
## reads the four E5 verdicts through it; T-19e owns the evaluation and this
## machine only consumes the result. Left null, the gate waits for an external
## verdict through submit_gate_result instead of guessing one.
var birth_check: BirthCheck = null

## Added by T-21-1. The E5 inputs the gate hands to birth_check: transport
## coverage, waste, stability, and either a birth readiness value or the
## signal coverage and pulmonary readiness pair the E5 formula derives it from.
## Supplied by the caller before start().
var city_metrics: Dictionary = {}

## Added by T-21-1. The full report from the last gate evaluation, so the UI can
## show all four rows together with their gaps and recovery directions. Empty
## when the gate has not run or could not run.
var gate_report: Dictionary = {}

## Added by T-21-2. Unit conversion, not a gameplay parameter: window lengths are
## configured in milliseconds and SceneTreeTimer takes seconds.
const MS_PER_SECOND := 1000.0

## Added by T-21-2. Incremented whenever a timed beat starts. A beat's waiter
## captures the value and advances the machine only if it still matches, so a
## beat that was interrupted and later restarted can never be advanced by the
## stale timer of an earlier attempt.
var _beat_token: int = 0

var _current_state: int = State.IDLE
var _gate_passed: bool = false


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

## Enter the sequence at the readiness gate. Legal only from `IDLE`.
func start() -> bool:
	return transition_to(State.READY_CHECK)


## The single mutator of the current state. Rejects any transition absent from
## the graph, leaves the current state untouched on rejection, and never advances
## more than one step. `reason_code` is carried by `birth_rolled_back` and is
## ignored for every other target.
func transition_to(next_state: int, reason_code: StringName = &"") -> bool:
	if next_state < 0 or next_state >= STATE_IDS.size():
		return _reject(next_state, &"out_of_range")

	if next_state == _current_state:
		return _reject(next_state, &"same_state")

	var allowed: Array = LEGAL_TRANSITIONS.get(_current_state, [])
	if not allowed.has(next_state):
		return _reject(next_state, &"illegal_transition")

	var previous_state := _current_state
	_current_state = next_state

	print("%s %s -> %s" % [LOG_PREFIX, STATE_IDS[previous_state], STATE_IDS[_current_state]])

	# The sequence opens before the per-beat event, so a listener that swaps the
	# soundtrack has done so by the time the first beat arrives.
	if previous_state == State.IDLE:
		EventBus.birth_sequence_started.emit(STAGE_ID, total_budget_ms())

	EventBus.birth_state_changed.emit(previous_state, _current_state, state_duration_ms(_current_state))

	if _current_state == State.ENDING:
		EventBus.birth_sequence_completed.emit(STAGE_ID)
	elif _current_state == State.FAILURE_ROLLBACK:
		var reason := reason_code if reason_code != &"" else REASON_PRECONDITION_LOST
		EventBus.birth_rolled_back.emit(previous_state, reason)

	_enter_state(_current_state)
	return true


func can_transition_to(next_state: int) -> bool:
	if next_state < 0 or next_state >= STATE_IDS.size() or next_state == _current_state:
		return false
	var allowed: Array = LEGAL_TRANSITIONS.get(_current_state, [])
	return allowed.has(next_state)


## Record the verdict of `src/sim/birth_check.gd` and route accordingly. The
## machine consumes the verdict; it never re-evaluates the four checks itself.
func submit_gate_result(all_checks_passed: bool) -> bool:
	if _current_state != State.READY_CHECK:
		return _reject(_current_state, &"gate_result_outside_ready_check")

	_gate_passed = all_checks_passed
	if all_checks_passed:
		return transition_to(State.UMBILICAL_STOP)
	return transition_to(State.FAILURE_ROLLBACK, REASON_GATE_CHECK_FAILED)


## A rollback returns the player to the gate rather than ending the run.
## docs/OPERATION_SPEC.md guarantees a failed check never locks the flow.
func acknowledge_rollback() -> bool:
	return transition_to(State.READY_CHECK)


func current_state() -> int:
	return _current_state


func current_state_id() -> StringName:
	return STATE_IDS[_current_state]


func is_terminal() -> bool:
	var allowed: Array = LEGAL_TRANSITIONS.get(_current_state, [])
	return allowed.is_empty()


func gate_passed() -> bool:
	return _gate_passed


## Window length for a state on the 45-second timeline, in milliseconds. States
## with no window return zero, as do states whose key is not yet configured.
func state_duration_ms(state: int) -> int:
	var suffix: String = DURATION_KEYS.get(state, "")
	if suffix.is_empty():
		return 0
	var path := "chapters.%s.birth_sequence.%s" % [STAGE_ID, suffix]
	return int(Balance.get_value(path, 0))


## The configured ending-sequence budget, carried by `birth_sequence_started`.
func total_budget_ms() -> int:
	return int(Balance.get_value("chapters.%s.birth_sequence.total_budget_ms" % STAGE_ID, 0))


## Total of every configured window. Compare against `total_budget_ms()` to
## confirm the sequence still fits the budget after any retune.
func total_timeline_ms() -> int:
	var total := 0
	for state in DURATION_KEYS:
		total += state_duration_ms(state)
	return total


## Report the timeline keys that are missing, so a caller can fail loudly rather
## than silently running a zero-length sequence.
func missing_duration_paths() -> PackedStringArray:
	var missing := PackedStringArray()
	for state in DURATION_KEYS:
		var suffix: String = DURATION_KEYS[state]
		if suffix.is_empty():
			continue
		var path := "chapters.%s.birth_sequence.%s" % [STAGE_ID, suffix]
		if Balance.get_value(path, null) == null:
			missing.append(path)
	return missing


# ---------------------------------------------------------------------------
# State bodies
#
# Every body is empty by design. T-21-1 through T-21-7 fill exactly one each and
# must not touch the graph, the routing, or any other state.
# ---------------------------------------------------------------------------

func _enter_state(state: int) -> void:
	match state:
		State.READY_CHECK:
			_on_enter_ready_check()
		State.UMBILICAL_STOP:
			_on_enter_umbilical_stop()
		State.PULMONARY_FLOW:
			_on_enter_pulmonary_flow()
		State.FETAL_SHUNTS:
			_on_enter_fetal_shunts()
		State.SYSTEMS_ONLINE:
			_on_enter_systems_online()
		State.ENDING:
			_on_enter_ending()
		State.FAILURE_ROLLBACK:
			_on_enter_failure_rollback()


## Implemented by T-21-1.
##
## Entry action: read the four E5 verdicts through `birth_check` and hold them in
## `gate_report`. Exit judgement: all four passed, or any of them failed.
##
## The verdict is submitted deferred rather than inline. `transition_to` calls
## this function while it is still unwinding, so transitioning from inside it
## would be re-entrant. Deferring also makes the wait interruptible at no extra
## cost: if anything moves the machine out of `ready_check` first, the late
## verdict lands in `submit_gate_result`, which already rejects it and leaves the
## state untouched. No guard is needed here.
##
## Nothing is played. Sound and animation belong to D-22 and D-26 and hang off
## `birth_state_changed`, which `transition_to` has already emitted by now.
func _on_enter_ready_check() -> void:
	gate_report = {}

	if birth_check == null:
		push_warning(
			"%s No BirthCheck supplied; the gate is waiting for an external verdict through submit_gate_result()."
			% LOG_PREFIX
		)
		return

	if city_metrics.is_empty():
		push_warning(
			"%s No city metrics supplied; the gate is waiting for an external verdict through submit_gate_result()."
			% LOG_PREFIX
		)
		return

	# birth_transition_complete is false here by definition: this is the gate, so
	# the transition has not run yet. BirthCheck deduplicates the birth hint on
	# its own, so a retry does not emit it twice.
	gate_report = birth_check.check(city_metrics, false)

	var passed := bool(gate_report.get("passed", false))
	print(
		"%s gate evaluated: passed=%s retry_allowed=%s"
		% [LOG_PREFIX, passed, gate_report.get("retry_allowed", true)]
	)
	submit_gate_result.call_deferred(passed)


## Implemented by T-21-2.
##
## Entry action: open the first observable beat of the 45-second timeline. Exit
## judgement: the beat's configured window has elapsed.
##
## The window is read through state_duration_ms, which reads Balance. Nothing
## about the length is decided here, so retuning the beat needs no script edit.
##
## The wait is interruptible. A SceneTreeTimer yields control rather than
## blocking, and on resume this beat checks four things before touching the
## machine: that it is still the current beat, by token; that the machine is
## still in this state; that the machine has not been queued for deletion; and
## that it is still inside the tree. Any of them failing means something took
## over or tore down the machine while the timer ran, so the beat exits without
## advancing and without rewinding anything.
##
## Being freed counts as an interruption. Without the last two checks a machine
## freed mid-beat would still resume and emit a state change on its way out.
##
## Nothing is played. Sound and animation belong to D-22 and D-26 and hang off
## birth_state_changed, which transition_to has already emitted by now.
func _on_enter_umbilical_stop() -> void:
	_beat_token += 1
	var token := _beat_token
	var window_ms := state_duration_ms(State.UMBILICAL_STOP)

	var tree := get_tree()
	if tree == null:
		push_warning("%s Not inside a scene tree; the beat cannot time itself." % LOG_PREFIX)
		return

	if window_ms > 0:
		print("%s beat %s running for %d ms" % [LOG_PREFIX, STATE_IDS[State.UMBILICAL_STOP], window_ms])
		await tree.create_timer(float(window_ms) / MS_PER_SECOND).timeout
	else:
		push_warning(
			"%s No window configured for %s; advancing on the next frame. See missing_duration_paths()."
			% [LOG_PREFIX, STATE_IDS[State.UMBILICAL_STOP]]
		)
		await tree.process_frame

	if (
		token != _beat_token
		or _current_state != State.UMBILICAL_STOP
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		print("%s beat %s was interrupted; exiting without advancing." % [LOG_PREFIX, STATE_IDS[State.UMBILICAL_STOP]])
		return

	transition_to(State.PULMONARY_FLOW)


## Implemented by T-21-3.
##
## Entry action: open the second observable beat of the 45-second timeline. Exit
## judgement: the beat's configured window has elapsed.
##
## Same shape as the first beat, deliberately. The window comes from
## state_duration_ms, the wait yields on an engine SceneTreeTimer, and on resume
## the beat checks the same four interruption conditions before touching the
## machine: still the current beat by token, still in this state, not queued for
## deletion, still inside the tree. Any of them failing means something took over
## or tore down the machine while the timer ran, so the beat exits without
## advancing and without rewinding anything.
##
## The repetition is not an oversight. T-21 assigns one state per task and
## forbids touching another state's function, so folding the three timed beats
## into a shared helper is not this task's to make. Whoever owns the refactor can
## take all three at once later.
##
## Nothing is played. Sound and animation belong to D-22 and D-26 and hang off
## birth_state_changed, which transition_to has already emitted by now.
func _on_enter_pulmonary_flow() -> void:
	_beat_token += 1
	var token := _beat_token
	var window_ms := state_duration_ms(State.PULMONARY_FLOW)

	var tree := get_tree()
	if tree == null:
		push_warning("%s Not inside a scene tree; the beat cannot time itself." % LOG_PREFIX)
		return

	if window_ms > 0:
		print("%s beat %s running for %d ms" % [LOG_PREFIX, STATE_IDS[State.PULMONARY_FLOW], window_ms])
		await tree.create_timer(float(window_ms) / MS_PER_SECOND).timeout
	else:
		push_warning(
			"%s No window configured for %s; advancing on the next frame. See missing_duration_paths()."
			% [LOG_PREFIX, STATE_IDS[State.PULMONARY_FLOW]]
		)
		await tree.process_frame

	if (
		token != _beat_token
		or _current_state != State.PULMONARY_FLOW
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		print("%s beat %s was interrupted; exiting without advancing." % [LOG_PREFIX, STATE_IDS[State.PULMONARY_FLOW]])
		return

	transition_to(State.FETAL_SHUNTS)


## Implemented by T-21-4.
##
## Entry action: open the third and last observable beat of the 45-second
## timeline. Exit judgement: the beat's configured window has elapsed.
##
## Third repetition of the same shape, and deliberately so. The window comes from
## state_duration_ms, the wait yields on an engine SceneTreeTimer, and on resume
## the beat checks the same four interruption conditions before touching the
## machine: still the current beat by token, still in this state, not queued for
## deletion, still inside the tree.
##
## The duplication is now threefold and wants a shared helper. T-21 assigns one
## state per task and forbids touching another state's function, so collapsing
## them is not this task's change to make; it is reported in the marker instead.
## Leaving this beat structurally identical to the other two is what keeps that
## refactor a mechanical one when someone does own it.
##
## Nothing is played. Sound and animation belong to D-22 and D-26 and hang off
## birth_state_changed, which transition_to has already emitted by now.
func _on_enter_fetal_shunts() -> void:
	_beat_token += 1
	var token := _beat_token
	var window_ms := state_duration_ms(State.FETAL_SHUNTS)

	var tree := get_tree()
	if tree == null:
		push_warning("%s Not inside a scene tree; the beat cannot time itself." % LOG_PREFIX)
		return

	if window_ms > 0:
		print("%s beat %s running for %d ms" % [LOG_PREFIX, STATE_IDS[State.FETAL_SHUNTS], window_ms])
		await tree.create_timer(float(window_ms) / MS_PER_SECOND).timeout
	else:
		push_warning(
			"%s No window configured for %s; advancing on the next frame. See missing_duration_paths()."
			% [LOG_PREFIX, STATE_IDS[State.FETAL_SHUNTS]]
		)
		await tree.process_frame

	if (
		token != _beat_token
		or _current_state != State.FETAL_SHUNTS
		or is_queued_for_deletion()
		or not is_inside_tree()
	):
		print("%s beat %s was interrupted; exiting without advancing." % [LOG_PREFIX, STATE_IDS[State.FETAL_SHUNTS]])
		return

	transition_to(State.SYSTEMS_ONLINE)


## Filled by T-21-5.
func _on_enter_systems_online() -> void:
	pass


## Filled by T-21-6.
func _on_enter_ending() -> void:
	pass


## Filled by T-21-7.
func _on_enter_failure_rollback() -> void:
	pass


# ---------------------------------------------------------------------------
# Rejection
# ---------------------------------------------------------------------------

func _reject(attempted_state: int, reason_code: StringName) -> bool:
	var attempted_id: StringName = (
		STATE_IDS[attempted_state]
		if attempted_state >= 0 and attempted_state < STATE_IDS.size()
		else &"<out_of_range>"
	)
	print(
		"%s rejected %s -> %s (%s); state unchanged."
		% [LOG_PREFIX, STATE_IDS[_current_state], attempted_id, reason_code]
	)
	EventBus.action_rejected.emit(ACTION_ID, reason_code, STATE_IDS[_current_state])
	return false
