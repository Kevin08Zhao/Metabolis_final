class_name NetworkIntervention
extends RefCounted

## Applies the three restricted transport-network interventions from T-15.
##
## Manual acceptance:
## 1. Call select_trunk_direction once, then again for the same stage. The first
##    result contains NetworkBuilder output; the second is rejected and disabled.
## 2. During an unconfirmed operation decision, call increase_edge_capacity on
##    the selected active mutable runtime edge. The supplied routing transaction
##    applies its preset plan and recomputes routing; capacity then rises by E1,
##    development signal falls by the configured cost, and [NET] reports success.
## 3. Call prioritize_bottleneck_edges with multiple active mutable edge IDs.
##    The returned order matches the player's order; a second call is rejected.
## 4. Call reject_manual_route_edit for an existing edge. The UI feedback names
##    the forbidden edit, action_rejected fires, and the console prints [NET].
## 5. After each successful intervention, is_available returns false for that
##    intervention while the other unused intervention entries remain available.

const ACTION_ID := &"intervene_transport_network"
const TRUNK_DIRECTION := &"trunk_direction"
const CAPACITY_INCREASE := &"capacity_increase"
const BOTTLENECK_PRIORITY := &"bottleneck_priority"

const FOCUS_DIRECTION := &"trunk_direction_control"
const FOCUS_CAPACITY := &"capacity_intervention_control"
const FOCUS_PRIORITY := &"bottleneck_priority_control"
const FOCUS_ROUTE := &"transport_route"

var feedback: String:
	get:
		return _feedback

var _balance_access: Node
var _event_bus: Node
var _uses_by_stage: Dictionary = {}
var _feedback := ""


func configure(balance_access: Node, event_bus: Node) -> void:
	_balance_access = balance_access
	_event_bus = event_bus


func is_available(
	stage_id: StringName,
	intervention_id: StringName,
	network_data: NetworkData = null
) -> bool:
	if intervention_id == CAPACITY_INCREASE:
		return (
			network_data != null
			and not network_data.transport_intervention_used
			and _use_count(stage_id, intervention_id) < _max_uses_per_stage()
		)
	return _use_count(stage_id, intervention_id) < _max_uses_per_stage()


func select_trunk_direction(
	chapter_data: ChapterData,
	organ_id: StringName,
	decision_id: StringName,
	option_id: StringName,
	network_builder: Node
) -> Dictionary:
	if not _ready():
		return {}
	if chapter_data == null:
		_reject(&"chapter_data_unavailable", FOCUS_DIRECTION)
		return {}
	var stage_id := chapter_data.stage_id
	if not is_available(stage_id, TRUNK_DIRECTION):
		_reject(&"usage_limit_reached", FOCUS_DIRECTION)
		return {}
	if chapter_data.phase != &"build_decision":
		_reject(&"not_in_build_decision", FOCUS_DIRECTION)
		return {}
	if chapter_data.active_build_decision_id != decision_id:
		_reject(&"build_decision_unavailable", FOCUS_DIRECTION)
		return {}
	if chapter_data.confirmed_build_decision_ids.has(decision_id):
		_reject(&"build_decision_locked", FOCUS_DIRECTION)
		return {}
	if not chapter_data.available_build_option_ids.has(option_id):
		_reject(&"build_option_unavailable", FOCUS_DIRECTION)
		return {}
	if (
		network_builder == null
		or not network_builder.has_method("generate_extension")
	):
		_reject(&"network_builder_unavailable", FOCUS_DIRECTION)
		return {}

	# NetworkBuilder owns route generation and reads D4/D5 from Balance. This
	# interface passes the selected candidate through without modifying a route.
	var extension: Variant = network_builder.call(
		"generate_extension",
		organ_id,
		decision_id,
		option_id
	)
	if not extension is Dictionary or extension.is_empty():
		_reject(&"invalid_trunk_direction", FOCUS_DIRECTION)
		return {}

	_record_use(stage_id, TRUNK_DIRECTION)
	_feedback = "Trunk direction locked for this stage."
	print(
		"[NET] trunk direction stage=%s decision=%s option=%s"
		% [stage_id, decision_id, option_id]
	)
	return extension


func increase_edge_capacity(
	chapter_data: ChapterData,
	network_data: NetworkData,
	resources: Dictionary,
	apply_plan_and_recompute: Callable
) -> Dictionary:
	if not _ready():
		return {}
	if chapter_data == null:
		_reject(&"chapter_data_unavailable", FOCUS_CAPACITY)
		return {}
	if network_data == null:
		_reject(&"network_data_unavailable", FOCUS_CAPACITY)
		return {}
	var stage_id := chapter_data.stage_id
	if not is_available(stage_id, CAPACITY_INCREASE, network_data):
		_reject(&"usage_limit_reached", FOCUS_CAPACITY)
		return {}
	if chapter_data.phase != &"operation_decision":
		_reject(&"not_in_operation_decision", FOCUS_CAPACITY)
		return {}
	var operation_id := chapter_data.active_operation_decision_id
	if operation_id.is_empty():
		_reject(&"operation_decision_unavailable", FOCUS_CAPACITY)
		return {}
	if chapter_data.confirmed_operation_decision_ids.has(operation_id):
		_reject(&"operation_decision_locked", FOCUS_CAPACITY)
		return {}
	var selected_edge_id := network_data.selected_transport_edge_id
	if selected_edge_id.is_empty():
		_reject(&"edge_not_selected", FOCUS_CAPACITY)
		return {}
	if not network_data.active_transport_edge_ids.has(selected_edge_id):
		_reject(&"edge_not_active", FOCUS_ROUTE)
		return {}
	if not network_data.mutable_transport_edge_ids.has(selected_edge_id):
		_reject(&"edge_not_mutable", FOCUS_ROUTE)
		return {}
	if not network_data.disconnects_required_organs.has(selected_edge_id):
		_reject(&"connectivity_not_validated", FOCUS_ROUTE)
		return {}
	if bool(network_data.disconnects_required_organs[selected_edge_id]):
		_reject(&"required_organ_would_disconnect", FOCUS_ROUTE)
		return {}
	var plan: Variant = network_data.transport_intervention_plan_by_edge.get(
		selected_edge_id,
		null
	)
	var plan_id := _plan_id(plan)
	if plan_id.is_empty():
		_reject(&"intervention_plan_unavailable", FOCUS_ROUTE)
		return {}
	if not apply_plan_and_recompute.is_valid():
		_reject(&"routing_transaction_unavailable", FOCUS_ROUTE)
		return {}
	var selected_edge := _find_runtime_edge(network_data.edges, selected_edge_id)
	if selected_edge.is_empty():
		_reject(&"runtime_edge_not_found", FOCUS_ROUTE)
		return {}

	var spec_tier_id := StringName(selected_edge.get("spec_tier_id", ""))
	var capacity_before := float(selected_edge.get("effective_capacity", -1.0))
	var base_increment := float(
		_read("network.transport.intervention.capacity_increment", -1.0)
	)
	var spec_multiplier := float(
		_read(
			"network.transport.intervention.spec_multiplier.%s" % spec_tier_id,
			-1.0
		)
	)
	var response_input: Array = _read_array(
		"network.transport.intervention.pressure_response.input_range"
	)
	var response_output: Array = _read_array(
		"network.transport.intervention.pressure_response.output_range"
	)
	var capacity_min := float(_read("network.transport.capacity.min", -1.0))
	var capacity_max := float(_read("network.transport.capacity.max", -1.0))
	var signal_cost := float(
		_read(
			"network.transport.intervention.cost.development_signal",
			-1.0
		)
	)
	var unlock_pressure := float(
		_read("network.transport.intervention.unlock_pressure", -1.0)
	)
	if (
		spec_tier_id.is_empty()
		or capacity_before < 0.0
		or base_increment < 0.0
		or spec_multiplier < 0.0
		or signal_cost < 0.0
		or unlock_pressure < 0.0
		or capacity_min < 0.0
		or capacity_max < capacity_min
		or not _is_range(response_input)
		or not _is_range(response_output)
	):
		_reject(&"invalid_balance_configuration", FOCUS_CAPACITY)
		return {}

	if network_data.transport_pressure < unlock_pressure:
		_reject(&"transport_pressure_below_unlock", &"transport_pressure")
		return {}
	var available_signal := float(resources.get("development_signal", 0.0))
	if available_signal < signal_cost:
		_reject(&"insufficient_development_signal", &"development_signal")
		return {}

	var pressure_response := _map_clamped(
		network_data.transport_pressure,
		float(response_input[0]),
		float(response_input[1]),
		float(response_output[0]),
		float(response_output[1])
	)
	var capacity_delta := base_increment * spec_multiplier * pressure_response
	var capacity_after := clampf(
		capacity_before + capacity_delta,
		capacity_min,
		capacity_max
	)

	# The routing owner performs the document-defined preset-plan application and
	# one route recomputation as a single transaction. The plan is passed through
	# unchanged because its internal representation is not defined by T-15.
	var routing_committed: Variant = apply_plan_and_recompute.call(
		selected_edge_id,
		plan,
		capacity_after
	)
	if routing_committed != true:
		_reject(&"routing_transaction_failed", FOCUS_ROUTE)
		return {}

	# Commit local runtime, resource, and usage state only after routing succeeds.
	# The edge comes from NetworkData.edges, never NetworkBuilder's copy getter.
	selected_edge["effective_capacity"] = capacity_after
	resources["development_signal"] = available_signal - signal_cost
	network_data.transport_intervention_used = true
	_record_use(stage_id, CAPACITY_INCREASE)
	_feedback = "Capacity intervention applied; this entry is now disabled."
	_emit(
		&"transport_network_intervened",
		[selected_edge_id, plan_id, capacity_after]
	)
	print(
		"[NET] capacity edge=%s before=%.3f delta=%.3f after=%.3f"
		% [selected_edge_id, capacity_before, capacity_delta, capacity_after]
	)
	return {
		"edge_id": selected_edge_id,
		"plan_id": plan_id,
		"capacity_before": capacity_before,
		"capacity_delta": capacity_delta,
		"capacity_after": capacity_after,
		"development_signal_spent": signal_cost,
	}


func prioritize_bottleneck_edges(
	chapter_data: ChapterData,
	ordered_edge_ids: Array[StringName],
	active_transport_edge_ids: Array[StringName],
	mutable_transport_edge_ids: Array[StringName]
) -> Array[StringName]:
	if not _ready():
		return []
	if chapter_data == null:
		_reject(&"chapter_data_unavailable", FOCUS_PRIORITY)
		return []
	var stage_id := chapter_data.stage_id
	if not is_available(stage_id, BOTTLENECK_PRIORITY):
		_reject(&"usage_limit_reached", FOCUS_PRIORITY)
		return []
	if chapter_data.phase != &"operation_decision":
		_reject(&"not_in_operation_decision", FOCUS_PRIORITY)
		return []
	var operation_id := chapter_data.active_operation_decision_id
	if operation_id.is_empty():
		_reject(&"operation_decision_unavailable", FOCUS_PRIORITY)
		return []
	if chapter_data.confirmed_operation_decision_ids.has(operation_id):
		_reject(&"operation_decision_locked", FOCUS_PRIORITY)
		return []
	if ordered_edge_ids.is_empty():
		_reject(&"no_bottleneck_edges_selected", FOCUS_PRIORITY)
		return []

	var result: Array[StringName] = []
	for edge_id: StringName in ordered_edge_ids:
		if (
			edge_id.is_empty()
			or result.has(edge_id)
			or not active_transport_edge_ids.has(edge_id)
			or not mutable_transport_edge_ids.has(edge_id)
		):
			_reject(&"edge_not_prioritizable", FOCUS_PRIORITY)
			return []
		result.append(edge_id)

	_record_use(stage_id, BOTTLENECK_PRIORITY)
	_feedback = "Bottleneck priority locked for this stage."
	print("[NET] bottleneck priority stage=%s order=%s" % [stage_id, result])
	return result


func reject_manual_route_edit(edge_id: StringName) -> bool:
	_reject(
		&"manual_route_edit_forbidden",
		edge_id if not edge_id.is_empty() else FOCUS_ROUTE
	)
	return false


func _ready() -> bool:
	if _balance_access == null:
		_reject(&"balance_unavailable", FOCUS_ROUTE)
		return false
	return true


func _max_uses_per_stage() -> int:
	return maxi(
		int(_read("network.transport.intervention.max_uses_per_stage", 0)),
		0
	)


func _use_count(stage_id: StringName, intervention_id: StringName) -> int:
	var stage_uses: Dictionary = _uses_by_stage.get(stage_id, {})
	return int(stage_uses.get(intervention_id, 0))


func _record_use(stage_id: StringName, intervention_id: StringName) -> void:
	var stage_uses: Dictionary = _uses_by_stage.get(stage_id, {})
	stage_uses[intervention_id] = _use_count(stage_id, intervention_id) + 1
	_uses_by_stage[stage_id] = stage_uses


func _read(path: String, default_value: Variant) -> Variant:
	if _balance_access == null or not _balance_access.has_method("get_value"):
		return default_value
	return _balance_access.call("get_value", path, default_value)


func _read_array(path: String) -> Array:
	var value: Variant = _read(path, [])
	return value if value is Array else []


func _is_range(value: Array) -> bool:
	return value.size() == 2 and float(value[1]) > float(value[0])


func _map_clamped(
	value: float,
	input_min: float,
	input_max: float,
	output_min: float,
	output_max: float
) -> float:
	var ratio := clampf(
		(value - input_min) / (input_max - input_min),
		0.0,
		1.0
	)
	return lerpf(output_min, output_max, ratio)


func _plan_id(plan: Variant) -> StringName:
	if plan is String or plan is StringName:
		return StringName(plan)
	if plan is Dictionary:
		return StringName(plan.get("plan_id", ""))
	return &""


func _find_runtime_edge(
	edges: Array,
	edge_id: StringName
) -> Dictionary:
	for edge: Variant in edges:
		if edge is Dictionary and StringName(edge.get("edge_id", "")) == edge_id:
			return edge
	return {}


func _emit(signal_name: StringName, arguments: Array) -> void:
	if _event_bus != null and _event_bus.has_signal(signal_name):
		_event_bus.emit_signal(signal_name, arguments[0], arguments[1], arguments[2])


func _reject(reason_code: StringName, focus_element: StringName) -> void:
	_feedback = "Network intervention rejected: %s." % reason_code
	print(
		"[NET] rejected action=%s reason=%s focus=%s"
		% [ACTION_ID, reason_code, focus_element]
	)
	if _event_bus != null and _event_bus.has_signal("action_rejected"):
		_event_bus.emit_signal(
			"action_rejected",
			ACTION_ID,
			reason_code,
			focus_element
		)
