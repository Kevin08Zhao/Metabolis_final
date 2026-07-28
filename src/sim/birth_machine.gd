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

## Local to this machine. docs/EVENT_API.md defines no birth event, because it
## covers only moments present in the rules table of docs/GAME_RULES.md and the
## birth sequence contains no player action. See the known gap section of
## docs/BIRTH_STATES.md.
signal birth_state_changed(previous_state: int, current_state: int)

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
## more than one step.
func transition_to(next_state: int) -> bool:
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
	birth_state_changed.emit(previous_state, _current_state)
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
	return transition_to(State.FAILURE_ROLLBACK)


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


## Total of every configured window. Compare against `total_budget_ms` to confirm
## the sequence still fits the budget after any retune.
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


## Filled by T-21-1.
func _on_enter_ready_check() -> void:
	pass


## Filled by T-21-2.
func _on_enter_umbilical_stop() -> void:
	pass


## Filled by T-21-3.
func _on_enter_pulmonary_flow() -> void:
	pass


## Filled by T-21-4.
func _on_enter_fetal_shunts() -> void:
	pass


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
