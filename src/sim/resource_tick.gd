class_name ResourceTick
extends RefCounted

## Deterministic five-step settlement for the six city resources.
##
## The public dictionaries are read-only copies:
##
## | Field | Range | Meaning |
## | --- | --- | --- |
## | organ_transport_coverage[organ_id] | balance.normalized.min..max | Actual delivered flow divided by required flow for the settled tick. |
## | carryover_source_snapshot.transport_coverage_settled | balance.normalized.min..max | Final E3 city coverage consumed by T-19h. |
## | carryover_source_snapshot.transport_pressure_settled | balance.transport.pressure.min..max | Final E3 pressure consumed by T-19h. |
## | carryover_source_snapshot.waste_settled | balance.resources.waste.min..max | Final E3 waste consumed by T-19h. |
##
## Transport inputs are requested_flow_by_organ, available_transport_flow,
## requested_development_signal_by_organ, and available_development_signal_flow.
## This class settles both channels against active graph connectivity and shared
## residual edge capacity. Waste multipliers come from
## resource_satisfaction_by_organ; they must already reflect the caller's actual
## resource-satisfaction result.
##
## Knowledge badges are copied through every tick without participating in any
## settlement formula. Threshold events belong to T-18 and are never emitted here.

const SPENDABLE_RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]
const SETTLED_RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
	&"waste",
	&"stability",
	&"knowledge_badge_count",
]
const ACTIVE_ORGAN_STATES: Array[StringName] = [
	&"completed",
	&"operating",
]

var resources: Dictionary:
	get:
		return _resources.duplicate(true)

var organ_transport_coverage: Dictionary:
	get:
		return _organ_transport_coverage.duplicate(true)

var carryover_source_snapshot: Dictionary:
	get:
		return _carryover_source_snapshot.duplicate(true)

var settled_delivered_flow: Dictionary:
	get:
		return _settled_delivered_flow.duplicate(true)

var settled_edge_flow: Dictionary:
	get:
		return _settled_edge_flow.duplicate(true)

var settled_delivered_development_signal: Dictionary:
	get:
		return _settled_delivered_development_signal.duplicate(true)

var transport_coverage: float:
	get:
		return _transport_coverage

var transport_pressure: float:
	get:
		return _transport_pressure

var signal_coverage: float:
	get:
		return _signal_coverage

var _balance_access: Node
var _coverage_calculator: RefCounted
var _elapsed_accumulator := 0.0
var _resources: Dictionary = {}
var _organ_transport_coverage: Dictionary = {}
var _carryover_source_snapshot: Dictionary = {}
var _settled_delivered_flow: Dictionary = {}
var _settled_edge_flow: Dictionary = {}
var _settled_delivered_development_signal: Dictionary = {}
var _transport_coverage := 0.0
var _transport_pressure := 0.0
var _signal_coverage := 0.0


func configure(balance_access: Node, coverage_calculator: RefCounted) -> void:
	_balance_access = balance_access
	_coverage_calculator = coverage_calculator


func initialize_from_balance(overrides: Dictionary = {}) -> void:
	_resources = {}
	for resource_id in SETTLED_RESOURCE_IDS:
		var initial_value: Variant = _read_balance(
			"resources.%s.initial" % resource_id,
			0
		)
		if resource_id == &"knowledge_badge_count":
			_resources[resource_id] = int(overrides.get(resource_id, initial_value))
		else:
			_resources[resource_id] = float(
				overrides.get(resource_id, initial_value)
			)
	_organ_transport_coverage = {}
	_carryover_source_snapshot = {}
	_settled_delivered_flow = {}
	_settled_edge_flow = {}
	_settled_delivered_development_signal = {}
	_transport_coverage = float(
		_read_balance("network.transport.coverage.initial", 0.0)
	)
	_transport_pressure = float(
		_read_balance("network.transport.pressure.initial", 0.0)
	)
	_signal_coverage = float(
		_read_balance("network.signal.coverage.initial", 0.0)
	)
	_elapsed_accumulator = 0.0
	_update_carryover_source_snapshot()


func advance_time(elapsed_seconds: float, settlement_input: Dictionary) -> int:
	if _balance_access == null or _coverage_calculator == null:
		push_warning("[RESOURCE TICK] Configure Balance and NetworkCoverage first.")
		return 0
	if elapsed_seconds < 0.0:
		push_warning("[RESOURCE TICK] Elapsed time cannot be negative.")
		return 0
	var tick_interval := float(_read_balance("tick_interval_sec", 0.0))
	if tick_interval <= 0.0:
		push_warning("[RESOURCE TICK] Balance tick interval must be positive.")
		return 0

	_elapsed_accumulator += elapsed_seconds
	var settled_count := 0
	while (
		_elapsed_accumulator > tick_interval
		or is_equal_approx(_elapsed_accumulator, tick_interval)
	):
		settle_tick(tick_interval, settlement_input)
		_elapsed_accumulator -= tick_interval
		if _elapsed_accumulator < 0.0 and is_zero_approx(_elapsed_accumulator):
			_elapsed_accumulator = 0.0
		settled_count += 1
	return settled_count


func settle_tick(tick_delta: float, settlement_input: Dictionary) -> Dictionary:
	if _balance_access == null or _coverage_calculator == null:
		push_warning("[RESOURCE TICK] Configure Balance and NetworkCoverage first.")
		return resources
	if tick_delta <= 0.0:
		push_warning("[RESOURCE TICK] Tick delta must be positive.")
		return resources
	if _resources.is_empty():
		initialize_from_balance()

	var organs := _dictionary_array(settlement_input.get("organs", []))

	# Fixed order: production, transport, consumption, waste, stability.
	_apply_production(tick_delta, organs)
	var network_result := _settle_network(settlement_input, organs)
	_apply_consumption(tick_delta, organs, network_result)
	_settle_waste(tick_delta, organs, settlement_input)
	_settle_stability(tick_delta)
	_update_carryover_source_snapshot()
	return resources


func run_acceptance_test() -> Array[Dictionary]:
	if _balance_access == null or _coverage_calculator == null:
		push_warning("[RESOURCE TICK] Acceptance test requires configuration.")
		return []
	initialize_from_balance()
	var settlement_input := _acceptance_input()
	var samples: Array[Dictionary] = []
	for tick_index in range(30):
		settle_tick(
			float(_read_balance("tick_interval_sec", 0.0)),
			settlement_input
		)
		var sample := {
			"tick": tick_index + 1,
			"resources": resources,
			"organ_transport_coverage": organ_transport_coverage,
			"stability": float(_resources[&"stability"]),
		}
		samples.append(sample)
		print(
			"[RESOURCE TICK] tick=",
			sample["tick"],
			" resources=",
			sample["resources"],
			" coverage=",
			sample["organ_transport_coverage"],
			" stability=",
			sample["stability"]
		)
	return samples


func _apply_production(tick_delta: float, organs: Array[Dictionary]) -> void:
	for resource_id in SPENDABLE_RESOURCE_IDS:
		var rate := float(
			_read_balance("resources.%s.per_tick_output" % resource_id, 0.0)
		)
		for organ in organs:
			if not _organ_is_active(organ):
				continue
			var organ_id := StringName(organ.get("organ_id", ""))
			rate += float(
				_read_balance(
					"organs.%s.per_tick_output.%s" % [organ_id, resource_id],
					0.0
				)
			) * _organ_multiplier(organ)
		_resources[resource_id] = _clamp_resource(
			resource_id,
			float(_resources.get(resource_id, 0.0)) + tick_delta * rate
		)


func _settle_network(
	settlement_input: Dictionary,
	organs: Array[Dictionary]
) -> Dictionary:
	var nodes: Array = settlement_input.get("nodes", [])
	var edges: Array = settlement_input.get("edges", [])
	var source_node_ids := _string_name_array(
		settlement_input.get("source_node_ids", [])
	)
	var required_organ_ids := _string_name_array(
		settlement_input.get(
			"required_organ_ids",
			_active_organ_ids(organs)
		)
	)
	var transport_result := _settle_transport_flows(
		organs,
		nodes,
		edges,
		source_node_ids,
		required_organ_ids,
		settlement_input.get(
			"requested_flow_by_organ",
			settlement_input.get("delivered_flow_by_organ", {})
		),
		float(settlement_input.get("available_transport_flow", 0.0)),
		settlement_input.get(
			"requested_development_signal_by_organ",
			settlement_input.get(
				"delivered_development_signal_by_organ",
				{}
			)
		),
		float(
			settlement_input.get(
				"available_development_signal_flow",
				0.0
			)
		)
	)
	_settled_delivered_flow = transport_result["delivered_flow_by_organ"]
	_settled_edge_flow = transport_result["edge_flow_by_id"]
	_settled_delivered_development_signal = transport_result[
		"delivered_development_signal_by_organ"
	]
	_organ_transport_coverage = _coverage_calculator.call(
		"calculate_coverages",
		organs,
		nodes,
		edges,
		source_node_ids,
		_settled_delivered_flow
	)

	_transport_coverage = _weighted_organ_coverage(required_organ_ids)
	_signal_coverage = _calculate_signal_coverage(
		organs,
		required_organ_ids,
		_settled_delivered_development_signal
	)
	_transport_pressure = _calculate_transport_pressure(
		edges,
		_settled_edge_flow
	)
	return {
		"required_organ_ids": required_organ_ids,
		"signal_satisfaction_by_organ": _signal_satisfaction_by_organ(
			organs,
			_settled_delivered_development_signal
		),
	}


func _settle_transport_flows(
	organs: Array[Dictionary],
	nodes: Array,
	edges: Array,
	source_node_ids: Array[StringName],
	required_organ_ids: Array[StringName],
	requested_flow_by_organ: Dictionary,
	available_transport_flow: float,
	requested_signal_by_organ: Dictionary,
	available_signal_flow: float
) -> Dictionary:
	var organ_by_id: Dictionary = {}
	for organ in organs:
		organ_by_id[StringName(organ.get("organ_id", ""))] = organ

	var adjacency: Dictionary = {}
	var node_owner: Dictionary = {}
	var nodes_by_position: Dictionary = {}
	var delivery_node_by_organ: Dictionary = {}
	var delivery_sequence_by_organ: Dictionary = {}
	for node_value in nodes:
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var node_id := StringName(node.get("node_id", ""))
		if node_id.is_empty():
			continue
		adjacency[node_id] = []
		var organ_id := StringName(node.get("organ_id", ""))
		node_owner[node_id] = organ_id
		if not organ_id.is_empty():
			var sequence := int(node.get("sequence", 0))
			var current_sequence := int(
				delivery_sequence_by_organ.get(organ_id, -1)
			)
			var current_node_id := StringName(
				delivery_node_by_organ.get(organ_id, "")
			)
			if (
				sequence > current_sequence
				or (
					sequence == current_sequence
					and (
						current_node_id.is_empty()
						or String(node_id) < String(current_node_id)
					)
				)
			):
				delivery_sequence_by_organ[organ_id] = sequence
				delivery_node_by_organ[organ_id] = node_id
		var position: Variant = node.get("grid_position")
		if position is Vector2i:
			if not nodes_by_position.has(position):
				nodes_by_position[position] = []
			nodes_by_position[position].append(node_id)

	var residual_capacity: Dictionary = {}
	var settled_edge_flow: Dictionary = {}
	for edge_value in edges:
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var edge_id := StringName(edge.get("edge_id", ""))
		var start_node_id := StringName(edge.get("start_node_id", ""))
		var end_node_id := StringName(edge.get("end_node_id", ""))
		if (
			edge_id.is_empty()
			or not adjacency.has(start_node_id)
			or not adjacency.has(end_node_id)
		):
			continue
		residual_capacity[edge_id] = maxf(
			float(edge.get("effective_capacity", 0.0)),
			0.0
		)
		settled_edge_flow[edge_id] = 0.0
		_add_transport_link(adjacency, start_node_id, end_node_id, edge_id)

	for position in nodes_by_position:
		var junction_nodes: Array = nodes_by_position[position]
		junction_nodes.sort_custom(
			func(left: Variant, right: Variant) -> bool:
				return String(left) < String(right)
		)
		for left_index in range(junction_nodes.size()):
			for right_index in range(left_index + 1, junction_nodes.size()):
				_add_transport_link(
					adjacency,
					StringName(junction_nodes[left_index]),
					StringName(junction_nodes[right_index]),
					&""
				)

	for node_id in adjacency:
		var links: Array = adjacency[node_id]
		links.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				if String(left["neighbor_node_id"]) != String(
					right["neighbor_node_id"]
				):
					return String(left["neighbor_node_id"]) < String(
						right["neighbor_node_id"]
					)
				return String(left["edge_id"]) < String(right["edge_id"])
		)

	var remaining_flow := maxf(available_transport_flow, 0.0)
	var remaining_signal_flow := maxf(available_signal_flow, 0.0)
	var settled_delivered_flow: Dictionary = {}
	var settled_delivered_signal: Dictionary = {}
	for organ_id in required_organ_ids:
		var organ: Dictionary = organ_by_id.get(organ_id, {})
		var required_flow := maxf(float(organ.get("required_flow", 0.0)), 0.0)
		var required_signal := maxf(
			float(organ.get("required_development_signal", 0.0)),
			0.0
		)
		var requested_flow := clampf(
			float(requested_flow_by_organ.get(organ_id, required_flow)),
			0.0,
			required_flow
		)
		var requested_signal := clampf(
			float(requested_signal_by_organ.get(organ_id, required_signal)),
			0.0,
			required_signal
		)
		var path_result := _find_transport_path(
			StringName(delivery_node_by_organ.get(organ_id, "")),
			source_node_ids,
			adjacency,
			node_owner,
			organ_by_id,
			residual_capacity
		)
		if not bool(path_result["found"]):
			settled_delivered_flow[organ_id] = 0.0
			settled_delivered_signal[organ_id] = 0.0
			continue
		var path_edge_ids: Array[StringName] = path_result["edge_ids"]
		var path_capacity := requested_flow
		if required_flow <= 0.0:
			path_capacity = INF
		for edge_id in path_edge_ids:
			path_capacity = minf(
				path_capacity,
				float(residual_capacity.get(edge_id, 0.0))
			)
		var delivered_flow := minf(
			requested_flow,
			minf(path_capacity, remaining_flow)
		)
		settled_delivered_flow[organ_id] = delivered_flow
		remaining_flow = maxf(remaining_flow - delivered_flow, 0.0)
		for edge_id in path_edge_ids:
			residual_capacity[edge_id] = maxf(
				float(residual_capacity[edge_id]) - delivered_flow,
				0.0
			)
			settled_edge_flow[edge_id] = (
				float(settled_edge_flow[edge_id]) + delivered_flow
			)

		var signal_path_capacity := requested_signal
		if required_signal <= 0.0:
			signal_path_capacity = INF
		for edge_id in path_edge_ids:
			signal_path_capacity = minf(
				signal_path_capacity,
				float(residual_capacity.get(edge_id, 0.0))
			)
		var delivered_signal := minf(
			requested_signal,
			minf(signal_path_capacity, remaining_signal_flow)
		)
		settled_delivered_signal[organ_id] = delivered_signal
		remaining_signal_flow = maxf(
			remaining_signal_flow - delivered_signal,
			0.0
		)
		for edge_id in path_edge_ids:
			residual_capacity[edge_id] = maxf(
				float(residual_capacity[edge_id]) - delivered_signal,
				0.0
			)
			settled_edge_flow[edge_id] = (
				float(settled_edge_flow[edge_id]) + delivered_signal
			)

	return {
		"delivered_flow_by_organ": settled_delivered_flow,
		"delivered_development_signal_by_organ": settled_delivered_signal,
		"edge_flow_by_id": settled_edge_flow,
	}


func _find_transport_path(
	target_node_id: StringName,
	source_node_ids: Array[StringName],
	adjacency: Dictionary,
	node_owner: Dictionary,
	organ_by_id: Dictionary,
	residual_capacity: Dictionary
) -> Dictionary:
	if target_node_id.is_empty():
		return {"found": false, "edge_ids": []}
	var queue: Array[StringName] = []
	var visited: Dictionary = {}
	var previous_node: Dictionary = {}
	var previous_edge: Dictionary = {}
	var sorted_sources := source_node_ids.duplicate()
	sorted_sources.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			return String(left) < String(right)
	)
	for source_node_id in sorted_sources:
		if (
			not adjacency.has(source_node_id)
			or not _transport_node_is_passable(
				source_node_id,
				node_owner,
				organ_by_id
			)
		):
			continue
		visited[source_node_id] = true
		queue.append(source_node_id)

	var reached_target_node_id := StringName()
	var queue_index := 0
	while queue_index < queue.size():
		var current_node_id := queue[queue_index]
		queue_index += 1
		if current_node_id == target_node_id:
			reached_target_node_id = current_node_id
			break
		for link_value in adjacency[current_node_id]:
			var link: Dictionary = link_value
			var neighbor_node_id := StringName(link["neighbor_node_id"])
			var edge_id := StringName(link["edge_id"])
			if visited.has(neighbor_node_id):
				continue
			if (
				not edge_id.is_empty()
				and float(residual_capacity.get(edge_id, 0.0)) <= 0.0
			):
				continue
			if not _transport_node_is_passable(
				neighbor_node_id,
				node_owner,
				organ_by_id
			):
				continue
			visited[neighbor_node_id] = true
			previous_node[neighbor_node_id] = current_node_id
			previous_edge[neighbor_node_id] = edge_id
			queue.append(neighbor_node_id)

	if reached_target_node_id.is_empty():
		return {"found": false, "edge_ids": []}

	var reversed_edge_ids: Array[StringName] = []
	var cursor := reached_target_node_id
	while previous_node.has(cursor):
		var edge_id := StringName(previous_edge[cursor])
		if not edge_id.is_empty():
			reversed_edge_ids.append(edge_id)
		cursor = StringName(previous_node[cursor])
	reversed_edge_ids.reverse()
	return {"found": true, "edge_ids": reversed_edge_ids}


func _transport_node_is_passable(
	node_id: StringName,
	node_owner: Dictionary,
	organ_by_id: Dictionary
) -> bool:
	var organ_id := StringName(node_owner.get(node_id, ""))
	if organ_id.is_empty() or not organ_by_id.has(organ_id):
		return true
	return _organ_is_active(organ_by_id[organ_id])


func _add_transport_link(
	adjacency: Dictionary,
	left_node_id: StringName,
	right_node_id: StringName,
	edge_id: StringName
) -> void:
	if left_node_id == right_node_id:
		return
	adjacency[left_node_id].append({
		"neighbor_node_id": right_node_id,
		"edge_id": edge_id,
	})
	adjacency[right_node_id].append({
		"neighbor_node_id": left_node_id,
		"edge_id": edge_id,
	})


func _apply_consumption(
	tick_delta: float,
	organs: Array[Dictionary],
	network_result: Dictionary
) -> void:
	var signal_satisfaction: Dictionary = network_result[
		"signal_satisfaction_by_organ"
	]
	for resource_id in SPENDABLE_RESOURCE_IDS:
		var rate := float(
			_read_balance("resources.%s.per_tick_consumption" % resource_id, 0.0)
		)
		for organ in organs:
			if not _organ_is_active(organ):
				continue
			var organ_id := StringName(organ.get("organ_id", ""))
			var satisfaction := float(
				signal_satisfaction.get(organ_id, 0.0)
				if resource_id == &"development_signal"
				else _organ_transport_coverage.get(organ_id, 0.0)
			)
			rate += float(
				_read_balance(
					"organs.%s.per_tick_consumption.%s" % [
						organ_id,
						resource_id,
					],
					0.0
				)
			) * _organ_multiplier(organ) * satisfaction
		_resources[resource_id] = _clamp_resource(
			resource_id,
			float(_resources.get(resource_id, 0.0)) - tick_delta * rate
		)


func _settle_waste(
	tick_delta: float,
	organs: Array[Dictionary],
	settlement_input: Dictionary
) -> void:
	var generation_total := float(
		_read_balance("resources.waste.accumulation_per_tick", 0.0)
	)
	var processing_total := 0.0
	var resource_satisfaction: Dictionary = settlement_input.get(
		"resource_satisfaction_by_organ",
		{}
	)
	var normalized_min := float(
		_read_balance("operations.normalized.min", 0.0)
	)
	var normalized_max := float(
		_read_balance("operations.normalized.max", 0.0)
	)
	for organ in organs:
		if not _organ_is_active(organ):
			continue
		var organ_id := StringName(organ.get("organ_id", ""))
		var satisfaction_multiplier := clampf(
			float(resource_satisfaction.get(organ_id, normalized_max)),
			normalized_min,
			normalized_max
		)
		var multiplier := _organ_multiplier(organ) * satisfaction_multiplier
		generation_total += float(
			_read_balance(
				"organs.%s.per_tick_output.waste" % organ_id,
				0.0
			)
		) * multiplier
		processing_total += float(
			_read_balance(
				"organs.%s.per_tick_consumption.waste" % organ_id,
				0.0
			)
		) * multiplier

	var intervention_waste_removal := maxf(
		float(settlement_input.get("intervention_waste_removal", 0.0)),
		0.0
	)
	var waste_next := float(_resources.get(&"waste", 0.0)) + tick_delta * (
		generation_total
		- processing_total
		- intervention_waste_removal
	)
	_resources[&"waste"] = _clamp_resource(&"waste", waste_next)


func _settle_stability(tick_delta: float) -> void:
	var normalized_waste := _normalize(
		float(_resources.get(&"waste", 0.0)),
		float(_read_balance("resources.waste.min", 0.0)),
		float(_read_balance("resources.waste.max", 0.0))
	)
	var normalized_pressure := _normalize(
		_transport_pressure,
		float(_read_balance("network.transport.pressure.min", 0.0)),
		float(_read_balance("network.transport.pressure.max", 0.0))
	)
	var stability_rate := (
		float(_read_balance("operations.stability.base_recovery", 0.0))
		+ float(
			_read_balance("operations.stability.transport_weight", 0.0)
		) * _transport_coverage
		+ float(
			_read_balance("operations.stability.signal_weight", 0.0)
		) * _signal_coverage
		- float(
			_read_balance("operations.stability.waste_weight", 0.0)
		) * normalized_waste
		- float(
			_read_balance("operations.stability.pressure_weight", 0.0)
		) * normalized_pressure
	)
	_resources[&"stability"] = _clamp_resource(
		&"stability",
		float(_resources.get(&"stability", 0.0)) + tick_delta * stability_rate
	)


func _weighted_organ_coverage(required_organ_ids: Array[StringName]) -> float:
	var weighted_total := 0.0
	var weight_total := 0.0
	for organ_id in required_organ_ids:
		if not _organ_transport_coverage.has(organ_id):
			continue
		var weight := float(
			_read_balance(
				"network.transport.coverage.organ_weights.%s" % organ_id,
				0.0
			)
		)
		weighted_total += float(_organ_transport_coverage[organ_id]) * weight
		weight_total += weight
	var normalized_min := float(
		_read_balance("operations.normalized.min", 0.0)
	)
	var normalized_max := float(
		_read_balance("operations.normalized.max", 0.0)
	)
	if weight_total <= 0.0:
		return normalized_max
	return clampf(weighted_total / weight_total, normalized_min, normalized_max)


func _calculate_transport_pressure(edges: Array, edge_flow_by_id: Dictionary) -> float:
	var max_route_utilization := 0.0
	var denominator_floor := float(
		_read_balance(
			"network.transport.capacity.denominator_floor",
			0.0
		)
	)
	for edge_value in edges:
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var edge_id := StringName(edge.get("edge_id", ""))
		var edge_flow := float(edge_flow_by_id.get(edge_id, 0.0))
		var effective_capacity := float(edge.get("effective_capacity", 0.0))
		var utilization := edge_flow / maxf(
			effective_capacity,
			denominator_floor
		)
		max_route_utilization = maxf(max_route_utilization, utilization)
	var pressure := (
		float(_read_balance("network.transport.pressure.base", 0.0))
		+ float(
			_read_balance("network.transport.pressure.coverage_weight", 0.0)
		) * (
			float(_read_balance("operations.normalized.max", 0.0))
			- _transport_coverage
		)
		+ float(
			_read_balance("network.transport.pressure.utilization_weight", 0.0)
		) * max_route_utilization
	)
	return clampf(
		pressure,
		float(_read_balance("network.transport.pressure.min", 0.0)),
		float(_read_balance("network.transport.pressure.max", 0.0))
	)


func _calculate_signal_coverage(
	organs: Array[Dictionary],
	required_organ_ids: Array[StringName],
	delivered_signal: Dictionary
) -> float:
	var satisfaction := _signal_satisfaction_by_organ(organs, delivered_signal)
	var weighted_total := 0.0
	var weight_total := 0.0
	for organ_id in required_organ_ids:
		if not satisfaction.has(organ_id):
			continue
		var weight := float(
			_read_balance("network.signal.organ_weights.%s" % organ_id, 0.0)
		)
		weighted_total += float(satisfaction[organ_id]) * weight
		weight_total += weight
	var signal_min := float(
		_read_balance("network.signal.coverage.min", 0.0)
	)
	var signal_max := float(
		_read_balance("network.signal.coverage.max", 0.0)
	)
	if weight_total <= 0.0:
		return signal_max
	return clampf(weighted_total / weight_total, signal_min, signal_max)


func _signal_satisfaction_by_organ(
	organs: Array[Dictionary],
	delivered_signal: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	var denominator_floor := float(
		_read_balance("network.signal.denominator_floor", 0.0)
	)
	var signal_min := float(
		_read_balance("network.signal.coverage.min", 0.0)
	)
	var signal_max := float(
		_read_balance("network.signal.coverage.max", 0.0)
	)
	for organ in organs:
		if not _organ_is_active(organ):
			continue
		var organ_id := StringName(organ.get("organ_id", ""))
		var required_signal := float(
			organ.get(
				"required_development_signal",
				_read_balance(
					"organs.%s.required_development_signal" % organ_id,
					0.0
				)
			)
		)
		var ratio := float(delivered_signal.get(organ_id, 0.0)) / maxf(
			required_signal,
			denominator_floor
		)
		result[organ_id] = clampf(ratio, signal_min, signal_max)
	return result


func _organ_multiplier(organ: Dictionary) -> float:
	return maxf(float(organ.get("active_multiplier", 1.0)), 0.0) * maxf(
		float(organ.get("tier_multiplier", 1.0)),
		0.0
	)


func _organ_is_active(organ: Dictionary) -> bool:
	return ACTIVE_ORGAN_STATES.has(
		StringName(organ.get("state", organ.get("state_id", "")))
	)


func _active_organ_ids(organs: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for organ in organs:
		if _organ_is_active(organ):
			result.append(StringName(organ.get("organ_id", "")))
	return result


func _clamp_resource(resource_id: StringName, value: float) -> float:
	var minimum := 0.0
	if resource_id == &"waste" or resource_id == &"stability":
		minimum = float(
			_read_balance("resources.%s.min" % resource_id, 0.0)
		)
	var maximum := float(
		_read_balance("resources.%s.max" % resource_id, INF)
	)
	return clampf(value, minimum, maximum)


func _normalize(value: float, minimum: float, maximum: float) -> float:
	var normalized_min := float(
		_read_balance("operations.normalized.min", 0.0)
	)
	var normalized_max := float(
		_read_balance("operations.normalized.max", 0.0)
	)
	var range_size := maximum - minimum
	if is_zero_approx(range_size):
		return normalized_min
	return clampf(
		(value - minimum) / range_size,
		normalized_min,
		normalized_max
	)


func _update_carryover_source_snapshot() -> void:
	_carryover_source_snapshot = {
		"transport_coverage_settled": _transport_coverage,
		"transport_pressure_settled": _transport_pressure,
		"waste_settled": float(_resources.get(&"waste", 0.0)),
	}


func _read_balance(path: String, default_value: Variant) -> Variant:
	if _balance_access == null:
		return default_value
	return _balance_access.call("get_value", path, default_value)


func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for item in value:
		result.append(StringName(item))
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if item is Dictionary:
			result.append(item)
	return result


func _acceptance_input() -> Dictionary:
	var organs: Array[Dictionary] = [
		{"organ_id": &"cell_cluster", "state": &"completed", "required_flow": 0.16, "required_development_signal": 0.08, "grid_position": Vector2i(0, 0)},
		{"organ_id": &"placenta_port", "state": &"completed", "required_flow": 0.22, "required_development_signal": 0.10, "grid_position": Vector2i(1, 0)},
		{"organ_id": &"germ_layer_districts", "state": &"operating", "required_flow": 0.24, "required_development_signal": 0.14, "grid_position": Vector2i(2, 0)},
		{"organ_id": &"heart_pump", "state": &"completed", "required_flow": 0.28, "required_development_signal": 0.12, "grid_position": Vector2i(3, 0)},
	]
	var nodes: Array[Dictionary] = [
		{"node_id": &"node_a", "organ_id": &"cell_cluster", "grid_position": Vector2i(0, 0)},
		{"node_id": &"node_b", "organ_id": &"placenta_port", "grid_position": Vector2i(1, 0)},
		{"node_id": &"node_c", "organ_id": &"germ_layer_districts", "grid_position": Vector2i(2, 0)},
		{"node_id": &"node_d", "organ_id": &"heart_pump", "grid_position": Vector2i(3, 0)},
	]
	var edges: Array[Dictionary] = [
		{"edge_id": &"edge_ab", "start_node_id": &"node_a", "end_node_id": &"node_b", "coverage_radius": 1.0, "effective_capacity": 2.0},
		{"edge_id": &"edge_bc", "start_node_id": &"node_b", "end_node_id": &"node_c", "coverage_radius": 1.0, "effective_capacity": 2.0},
		{"edge_id": &"edge_cd", "start_node_id": &"node_c", "end_node_id": &"node_d", "coverage_radius": 1.0, "effective_capacity": 2.0},
	]
	return {
		"organs": organs,
		"required_organ_ids": [
			&"cell_cluster",
			&"placenta_port",
			&"germ_layer_districts",
			&"heart_pump",
		],
		"nodes": nodes,
		"edges": edges,
		"source_node_ids": [&"node_a"],
		"requested_flow_by_organ": {
			&"cell_cluster": 0.16,
			&"placenta_port": 0.22,
			&"germ_layer_districts": 0.24,
			&"heart_pump": 0.28,
		},
		"available_transport_flow": 0.90,
		"requested_development_signal_by_organ": {
			&"cell_cluster": 0.08,
			&"placenta_port": 0.10,
			&"germ_layer_districts": 0.14,
			&"heart_pump": 0.12,
		},
		"available_development_signal_flow": 0.44,
		"resource_satisfaction_by_organ": {
			&"cell_cluster": 1.0,
			&"placenta_port": 1.0,
			&"germ_layer_districts": 1.0,
			&"heart_pump": 1.0,
		},
		"intervention_waste_removal": 0.0,
	}
