class_name OrganStateMachine
extends Node

## Owns the visual/runtime state of every buildable gameplay organ.
##
## State matrix (`true` means art is required for that organ/state):
##
## | Organ                   | Blueprint | Under construction | Completed | Operating | Stressed |
## |-------------------------|-----------|--------------------|-----------|-----------|----------|
## | cell_cluster            | true      | true               | true      | true      | true     |
## | placenta_port           | true      | true               | true      | true      | true     |
## | germ_layer_districts    | true      | true               | true      | true      | true     |
## | heart_pump              | true      | true               | true      | true      | true     |
## | neural_network          | true      | true               | true      | true      | true     |
## | lung_exchange           | true      | true               | true      | true      | true     |
## | pulmonary_interface     | true      | true               | true      | true      | true     |
##
## Background structures in Stage Three are formation animations rather than
## buildable organs, so they intentionally have no state-machine rows.
##
## Acceptance walk:
##
##     var machine := OrganStateMachine.new()
##     add_child(machine)
##     machine.configure(Balance, EventBus)
##     assert(machine.register_organ(&"heart_pump"))
##     assert(machine.start_construction(
##         &"heart_pump", &"build_heart_pump", &"heart_early_flow", &"heart_slot"
##     ))
##     machine.advance_construction(24.0)
##     assert(machine.current_state(&"heart_pump") == State.COMPLETED)
##     assert(machine.transition_to(&"heart_pump", State.OPERATING))
##     assert(machine.transition_to(&"heart_pump", State.STRESSED))
##     assert(machine.transition_to(&"heart_pump", State.OPERATING))

enum State {
	BLUEPRINT,
	UNDER_CONSTRUCTION,
	COMPLETED,
	OPERATING,
	STRESSED,
}

const STATE_IDS: Dictionary = {
	State.BLUEPRINT: &"blueprint",
	State.UNDER_CONSTRUCTION: &"under_construction",
	State.COMPLETED: &"completed",
	State.OPERATING: &"operating",
	State.STRESSED: &"stressed",
}
const ORGAN_IDS: Array[StringName] = [
	&"cell_cluster",
	&"placenta_port",
	&"germ_layer_districts",
	&"heart_pump",
	&"neural_network",
	&"lung_exchange",
	&"pulmonary_interface",
]
const ALL_STATES: Array[State] = [
	State.BLUEPRINT,
	State.UNDER_CONSTRUCTION,
	State.COMPLETED,
	State.OPERATING,
	State.STRESSED,
]
const ALLOWED_STATES_BY_ORGAN: Dictionary = {
	&"cell_cluster": ALL_STATES,
	&"placenta_port": ALL_STATES,
	&"germ_layer_districts": ALL_STATES,
	&"heart_pump": ALL_STATES,
	&"neural_network": ALL_STATES,
	&"lung_exchange": ALL_STATES,
	&"pulmonary_interface": ALL_STATES,
}
const ALLOWED_TRANSITIONS: Dictionary = {
	State.BLUEPRINT: [State.UNDER_CONSTRUCTION],
	State.UNDER_CONSTRUCTION: [State.COMPLETED],
	State.COMPLETED: [State.OPERATING],
	State.OPERATING: [State.STRESSED],
	State.STRESSED: [State.OPERATING],
}
const ORGAN_ID_BY_BUILD_DECISION: Dictionary = {
	&"build_cell_cluster": &"cell_cluster",
	&"build_placenta_port": &"placenta_port",
	&"build_germ_layer_districts": &"germ_layer_districts",
	&"build_heart_pump": &"heart_pump",
	&"build_neural_network": &"neural_network",
	&"build_lung_exchange": &"lung_exchange",
	&"build_pulmonary_interface": &"pulmonary_interface",
}

var _states: Dictionary = {}
var _construction_jobs: Dictionary = {}
var _balance_access: Node
var _event_sink: Node


func _ready() -> void:
	configure(get_node_or_null("/root/Balance"), get_node_or_null("/root/EventBus"))


func configure(balance_access: Node, event_sink: Node) -> void:
	_balance_access = balance_access
	_event_sink = event_sink


func register_organ(organ_id: StringName) -> bool:
	if not ALLOWED_STATES_BY_ORGAN.has(organ_id):
		push_warning("[ORGAN] Unknown organ '%s' cannot be registered." % organ_id)
		return false
	if _states.has(organ_id):
		push_warning("[ORGAN] Organ '%s' is already registered." % organ_id)
		return false
	_states[organ_id] = State.BLUEPRINT
	return true


## Synchronize an organ already completed by an authoritative build owner. This
## emits no construction event: the owner has already published organ_built.
func adopt_operating_organ(organ_id: StringName) -> bool:
	if not ALLOWED_STATES_BY_ORGAN.has(organ_id):
		push_warning("[ORGAN] Unknown organ '%s' cannot be adopted." % organ_id)
		return false
	_states[organ_id] = State.OPERATING
	_construction_jobs.erase(organ_id)
	return true


func current_state(organ_id: StringName) -> State:
	return _states.get(organ_id, State.BLUEPRINT) as State


func allowed_states(organ_id: StringName) -> Array[State]:
	if not ALLOWED_STATES_BY_ORGAN.has(organ_id):
		return []
	var result: Array[State] = []
	result.assign(ALLOWED_STATES_BY_ORGAN[organ_id])
	return result


func transition_to(
	organ_id: StringName,
	next_state: State,
	event_context: Dictionary = {}
) -> bool:
	if not _states.has(organ_id):
		push_warning("[ORGAN] Unregistered organ '%s' cannot change state." % organ_id)
		return false
	if not (ALLOWED_STATES_BY_ORGAN[organ_id] as Array).has(next_state):
		push_warning("[ORGAN] State '%s' is not available for organ '%s'." % [next_state, organ_id])
		return false

	var previous_state: State = _states[organ_id]
	if not (ALLOWED_TRANSITIONS[previous_state] as Array).has(next_state):
		push_warning(
			"[ORGAN] Illegal transition for '%s': %s -> %s."
			% [organ_id, STATE_IDS[previous_state], STATE_IDS[next_state]]
		)
		return false
	if (
		next_state == State.UNDER_CONSTRUCTION
		or next_state == State.COMPLETED
	) and not _has_construction_event_context(event_context):
		push_warning(
			"[ORGAN] Transition to '%s' requires slot_id and option_id event context."
			% STATE_IDS[next_state]
		)
		return false

	_states[organ_id] = next_state
	print("[ORGAN] ", organ_id, " ", STATE_IDS[previous_state], " -> ", STATE_IDS[next_state])
	_emit_transition_event(organ_id, next_state, event_context)
	return true


func start_construction(
	organ_id: StringName,
	decision_id: StringName,
	option_id: StringName,
	slot_id: StringName
) -> bool:
	if _balance_access == null or _event_sink == null:
		push_warning("[ORGAN] Construction requires Balance and EventBus.")
		return false
	if ORGAN_ID_BY_BUILD_DECISION.get(decision_id, &"") != organ_id:
		push_warning("[ORGAN] Build decision '%s' does not construct organ '%s'." % [decision_id, organ_id])
		return false

	var duration_path := "build_options.%s.%s.metrics.build_duration" % [decision_id, option_id]
	var duration_sec := float(_balance_access.call("get_value", duration_path, -1.0))
	if duration_sec <= 0.0:
		push_warning("[ORGAN] Missing positive construction duration at '%s'." % duration_path)
		return false
	var event_context := {"slot_id": slot_id, "option_id": option_id}
	if not transition_to(organ_id, State.UNDER_CONSTRUCTION, event_context):
		return false

	_construction_jobs[organ_id] = {
		"elapsed_sec": 0.0,
		"duration_sec": duration_sec,
		"slot_id": slot_id,
		"option_id": option_id,
	}
	return true


func advance_construction(delta_sec: float) -> Array[StringName]:
	var completed_organs: Array[StringName] = []
	if delta_sec <= 0.0:
		return completed_organs

	for organ_id_value in _construction_jobs.keys():
		var organ_id := StringName(organ_id_value)
		var job: Dictionary = _construction_jobs[organ_id]
		job["elapsed_sec"] = float(job["elapsed_sec"]) + delta_sec
		_construction_jobs[organ_id] = job
		if float(job["elapsed_sec"]) < float(job["duration_sec"]):
			continue
		if not transition_to(organ_id, State.COMPLETED, job):
			continue

		_construction_jobs.erase(organ_id)
		completed_organs.append(organ_id)

	return completed_organs


func _has_construction_event_context(event_context: Dictionary) -> bool:
	return (
		_event_sink != null
		and event_context.has("slot_id")
		and event_context.has("option_id")
	)


func _emit_transition_event(
	organ_id: StringName,
	next_state: State,
	event_context: Dictionary
) -> void:
	if next_state == State.UNDER_CONSTRUCTION:
		_event_sink.emit_signal(
			&"organ_construction_started",
			organ_id,
			StringName(event_context["slot_id"]),
			StringName(event_context["option_id"])
		)
	elif next_state == State.COMPLETED:
		_event_sink.emit_signal(
			&"organ_built",
			organ_id,
			StringName(event_context["slot_id"]),
			StringName(event_context["option_id"])
		)
