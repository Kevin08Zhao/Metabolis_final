class_name BottleneckDetector
extends RefCounted

## Detects and locates the three independent E7 bottlenecks.
##
## Manual acceptance:
## - Raise transport pressure above its Balance entry line with an under-covered
##   organ or overloaded edge. The result names that organ and edge, emits
##   transport_pressure_appeared, and unlocks hint_transport_capacity once.
## - Raise waste or its net rate. The result names the organ with the largest
##   generation-minus-processing value and unlocks hint_waste_processing once.
## - Lower signal coverage. The result names the lowest-ratio organ and weakest
##   path edge. In stage_circulation, when transport limits signal in the same
##   settlement, hint_neural_tube_compensation unlocks on the first detection.
## - Repeat each active sample for multiple ticks. No appearance event or hint
##   repeats. Cross its recovery conditions, then re-enter to start a new episode.
##
## This class publishes data and canonical events only. Rendering belongs to the
## map overlays and the knowledge-hint container.

const TRANSPORT := &"transport_pressure"
const WASTE := &"waste_accumulation"
const SIGNAL := &"signal_coverage_low"

const HINT_TRANSPORT := &"hint_transport_capacity"
const HINT_WASTE := &"hint_waste_processing"
const HINT_SIGNAL := &"hint_signal_coordination"
const HINT_NEURAL := &"hint_neural_tube_compensation"

var active_results: Dictionary:
	get:
		return _active_results.duplicate(true)

var _balance_access: Node
var _event_bus: Node
var _active_results: Dictionary = {
	TRANSPORT: {},
	WASTE: {},
	SIGNAL: {},
}
var _episode_hint_emitted: Dictionary = {}
var _signal_hint_stages: Dictionary = {}
var _neural_hint_emitted := false


func configure(balance_access: Node, event_bus: Node) -> void:
	_balance_access = balance_access
	_event_bus = event_bus


func evaluate(stage_id: StringName, metrics: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if _balance_access == null or _event_bus == null:
		push_warning("[BOTTLENECK] Balance and EventBus are required.")
		return results
	_evaluate_transport(stage_id, metrics, results)
	_evaluate_waste(stage_id, metrics, results)
	_evaluate_signal(stage_id, metrics, results)
	return results


func snapshot_state() -> Dictionary:
	return {
		"active_results": _active_results.duplicate(true),
		"episode_hint_emitted": _episode_hint_emitted.duplicate(true),
		"signal_hint_stages": _signal_hint_stages.duplicate(true),
		"neural_hint_emitted": _neural_hint_emitted,
	}


func restore_state(state: Dictionary) -> void:
	_active_results = state.get("active_results", {}).duplicate(true)
	for bottleneck_id in [TRANSPORT, WASTE, SIGNAL]:
		if not _active_results.has(bottleneck_id):
			_active_results[bottleneck_id] = {}
	_episode_hint_emitted = state.get(
		"episode_hint_emitted",
		{}
	).duplicate(true)
	_signal_hint_stages = state.get("signal_hint_stages", {}).duplicate(true)
	_neural_hint_emitted = bool(state.get("neural_hint_emitted", false))


func _evaluate_transport(
	stage_id: StringName,
	metrics: Dictionary,
	results: Array[Dictionary]
) -> void:
	var pressure := float(metrics.get("transport_pressure", 0.0))
	var coverages: Dictionary = metrics.get("organ_transport_coverage", {})
	var edges: Array = metrics.get("edges", [])
	var edge_flows: Dictionary = metrics.get("edge_flow_by_id", {})
	var enter := _read("operations.bottlenecks.transport_pressure.enter", INF)
	var recover := _read(
		"operations.bottlenecks.transport_pressure.recover",
		-INF
	)
	var organ_recover := _read(
		"operations.bottlenecks.transport_pressure.organ_coverage_recover",
		INF
	)
	var lowest_organs := _lowest_value_ids(coverages)
	var target_organ := _highest_utilization_organ(
		lowest_organs,
		edges,
		edge_flows
	)
	var target_edge := _highest_utilization_edge(edges, edge_flows, target_organ)
	var under_covered := (
		not target_organ.is_empty()
		and float(coverages[target_organ]) < organ_recover
	)
	var recovered := (
		pressure <= recover
		and _all_values_at_least(coverages, organ_recover)
	)
	var candidates: Array[Dictionary] = []
	for edge: Variant in edges:
		if not edge is Dictionary:
			continue
		var edge_id := StringName(edge.get("edge_id", ""))
		if _edge_is_overloaded(edge_id, edges, edge_flows):
			candidates.append({
				"target_id": edge_id,
				"target_organ_id": StringName(edge.get("organ_id", "")),
				"target_edge_id": edge_id,
			})
	if under_covered and not target_edge.is_empty():
		_append_unique_candidate(candidates, target_edge, target_organ, target_edge)
	var active_now := pressure >= enter and not candidates.is_empty()
	_sync_targets(
		TRANSPORT,
		stage_id,
		active_now,
		recovered,
		candidates,
		pressure,
		enter,
		&"transport_pressure_appeared",
		&"transport_pressure_cleared",
		HINT_TRANSPORT,
		results
	)


func _evaluate_waste(
	stage_id: StringName,
	metrics: Dictionary,
	results: Array[Dictionary]
) -> void:
	var waste := float(metrics.get("waste", 0.0))
	var net_rate := float(metrics.get("net_waste_rate", 0.0))
	var enter := _read("operations.bottlenecks.waste.enter", INF)
	var recover := _read("operations.bottlenecks.waste.recover", -INF)
	var rate_enter := _read(
		"operations.bottlenecks.waste.net_rate_enter",
		INF
	)
	var rate_recover := _read(
		"operations.bottlenecks.waste.net_rate_recover",
		-INF
	)
	var generation: Dictionary = metrics.get("organ_waste_generation", {})
	var processing: Dictionary = metrics.get("organ_waste_processing", {})
	var net_by_organ: Dictionary = {}
	for organ_id: Variant in generation:
		net_by_organ[organ_id] = (
			float(generation[organ_id])
			- float(processing.get(organ_id, 0.0))
		)
	var target_organ := _highest_value_id(net_by_organ)
	var waste_route_utilization: Dictionary = metrics.get(
		"waste_route_utilization",
		{}
	)
	var target_edge := _highest_value_id(waste_route_utilization)
	var candidates: Array[Dictionary] = []
	if not target_organ.is_empty():
		candidates.append({
			"target_id": target_organ,
			"target_organ_id": target_organ,
			"target_edge_id": target_edge,
		})
	_sync_targets(
		WASTE,
		stage_id,
		(waste >= enter or net_rate > rate_enter)
		and not target_organ.is_empty(),
		waste <= recover and net_rate <= rate_recover,
		candidates,
		waste,
		enter,
		&"waste_buildup_appeared",
		&"waste_buildup_cleared",
		HINT_WASTE,
		results
	)


func _evaluate_signal(
	stage_id: StringName,
	metrics: Dictionary,
	results: Array[Dictionary]
) -> void:
	var coverage := float(metrics.get("signal_coverage", 1.0))
	var enter := _read("operations.bottlenecks.signal_coverage.enter", -INF)
	var recover := _read(
		"operations.bottlenecks.signal_coverage.recover",
		INF
	)
	var organ_recover := _read(
		"operations.bottlenecks.signal_coverage.organ_recovery_ratio",
		INF
	)
	var delivered: Dictionary = metrics.get(
		"delivered_development_signal_by_organ",
		{}
	)
	var required: Dictionary = metrics.get(
		"required_development_signal_by_organ",
		{}
	)
	var ratios: Dictionary = {}
	for organ_id: Variant in required:
		var required_value := float(required[organ_id])
		if required_value > 0.0:
			ratios[organ_id] = float(delivered.get(organ_id, 0.0)) / required_value
	var target_organ := _lowest_value_id(ratios)
	var target_edge := StringName(
		metrics.get("weakest_signal_edge_by_organ", {}).get(
			target_organ,
			""
		)
	)
	var active_now := (
		coverage <= enter
		and not target_organ.is_empty()
		and not target_edge.is_empty()
		and float(ratios[target_organ]) < organ_recover
	)
	var recovered := coverage >= recover and _all_values_at_least(
		ratios,
		organ_recover
	)
	var candidates: Array[Dictionary] = []
	if active_now:
		candidates.append({
			"target_id": target_organ,
			"target_organ_id": target_organ,
			"target_edge_id": target_edge,
		})
	var was_active := not _targets_for(SIGNAL).is_empty()
	_sync_targets(
		SIGNAL,
		stage_id,
		active_now,
		recovered,
		candidates,
		coverage,
		enter,
		&"signal_gap_appeared",
		&"signal_gap_cleared",
		&"",
		results
	)
	if not active_now:
		return
	var compensation := (
		stage_id == &"stage_circulation"
		and bool(metrics.get("transport_coverage_limits_signal", false))
		and not _neural_hint_emitted
	)
	if compensation:
		_neural_hint_emitted = true
		_emit_hint(HINT_NEURAL, target_organ, stage_id)
	elif not was_active and not bool(_signal_hint_stages.get(stage_id, false)):
		_signal_hint_stages[stage_id] = true
		_emit_hint(HINT_SIGNAL, target_organ, stage_id)


func _sync_targets(
	bottleneck_id: StringName,
	stage_id: StringName,
	active_now: bool,
	recovered: bool,
	candidates: Array[Dictionary],
	current_value: float,
	threshold: float,
	appeared_event: StringName,
	cleared_event: StringName,
	hint_id: StringName,
	results: Array[Dictionary]
) -> void:
	var active_targets := _targets_for(bottleneck_id)
	var was_active := not active_targets.is_empty()
	if recovered:
		for target_id: Variant in active_targets.keys():
			_emit(cleared_event, [StringName(target_id)])
		active_targets.clear()
		_episode_hint_emitted.erase(bottleneck_id)
		_active_results[bottleneck_id] = active_targets
		return
	if not active_now:
		for result: Variant in active_targets.values():
			var held: Dictionary = result.duplicate(true)
			held["first_occurrence"] = false
			results.append(held)
		return
	var candidate_ids: Dictionary = {}
	for candidate in candidates:
		var target_id := StringName(candidate["target_id"])
		candidate_ids[target_id] = true
		var first := not active_targets.has(target_id)
		var result := {
			"bottleneck_id": bottleneck_id,
			"target_organ_id": candidate["target_organ_id"],
			"target_edge_id": candidate["target_edge_id"],
			"current_value": current_value,
			"threshold": threshold,
			"first_occurrence": first,
		}
		active_targets[target_id] = result
		results.append(result.duplicate(true))
		if first:
			_emit(appeared_event, [target_id, current_value])
	for target_id: Variant in active_targets.keys():
		if not candidate_ids.has(target_id):
			var held: Dictionary = active_targets[target_id].duplicate(true)
			held["current_value"] = current_value
			held["threshold"] = threshold
			held["first_occurrence"] = false
			active_targets[target_id] = held
			results.append(held.duplicate(true))
	_active_results[bottleneck_id] = active_targets
	if not was_active and not hint_id.is_empty() and not candidates.is_empty():
		_episode_hint_emitted[bottleneck_id] = true
		_emit_hint(
			hint_id,
			StringName(candidates[0]["target_organ_id"]),
			stage_id
		)


func _targets_for(bottleneck_id: StringName) -> Dictionary:
	var value: Variant = _active_results.get(bottleneck_id, {})
	return value if value is Dictionary else {}


func _emit_hint(
	hint_id: StringName,
	organ_id: StringName,
	stage_id: StringName
) -> void:
	_emit(&"knowledge_entry_unlocked", [hint_id, organ_id, stage_id])


func _emit(signal_name: StringName, arguments: Array) -> void:
	if not _event_bus.has_signal(signal_name):
		push_warning("[BOTTLENECK] EventBus is missing '%s'." % signal_name)
		return
	_event_bus.callv("emit_signal", [signal_name] + arguments)


func _read(path: String, default_value: float) -> float:
	return float(_balance_access.call("get_value", path, default_value))


func _lowest_value_id(values: Dictionary) -> StringName:
	var result := &""
	var best := INF
	for key: Variant in values:
		var value := float(values[key])
		if value < best or (is_equal_approx(value, best) and String(key) < String(result)):
			result = StringName(key)
			best = value
	return result


func _lowest_value_ids(values: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var best := INF
	for key: Variant in values:
		var value := float(values[key])
		if value < best and not is_equal_approx(value, best):
			best = value
			result = [StringName(key)]
		elif is_equal_approx(value, best):
			result.append(StringName(key))
	result.sort()
	return result


func _highest_value_id(values: Dictionary) -> StringName:
	var result := &""
	var best := -INF
	for key: Variant in values:
		var value := float(values[key])
		if value > best or (is_equal_approx(value, best) and String(key) < String(result)):
			result = StringName(key)
			best = value
	return result


func _highest_utilization_organ(
	organ_ids: Array[StringName],
	edges: Array,
	flows: Dictionary
) -> StringName:
	var result := &""
	var best := -INF
	for organ_id in organ_ids:
		var edge_id := _highest_utilization_edge(edges, flows, organ_id)
		var utilization := _edge_utilization(edge_id, edges, flows)
		if (
			utilization > best
			or (
				is_equal_approx(utilization, best)
				and String(organ_id) < String(result)
			)
		):
			result = organ_id
			best = utilization
	return result


func _append_unique_candidate(
	candidates: Array[Dictionary],
	target_id: StringName,
	organ_id: StringName,
	edge_id: StringName
) -> void:
	for candidate in candidates:
		if StringName(candidate["target_id"]) == target_id:
			return
	candidates.append({
		"target_id": target_id,
		"target_organ_id": organ_id,
		"target_edge_id": edge_id,
	})


func _all_values_at_least(values: Dictionary, threshold: float) -> bool:
	if values.is_empty():
		return false
	for value: Variant in values.values():
		if float(value) < threshold:
			return false
	return true


func _highest_utilization_edge(
	edges: Array,
	flows: Dictionary,
	preferred_organ: StringName
) -> StringName:
	var candidates: Dictionary = {}
	for edge: Variant in edges:
		if not edge is Dictionary:
			continue
		if (
			not preferred_organ.is_empty()
			and StringName(edge.get("organ_id", "")) != preferred_organ
		):
			continue
		var edge_id := StringName(edge.get("edge_id", ""))
		var capacity := float(edge.get("effective_capacity", 0.0))
		if not edge_id.is_empty() and capacity > 0.0:
			candidates[edge_id] = float(flows.get(edge_id, 0.0)) / capacity
	if candidates.is_empty() and not preferred_organ.is_empty():
		return _highest_utilization_edge(edges, flows, &"")
	return _highest_value_id(candidates)


func _edge_is_overloaded(
	edge_id: StringName,
	edges: Array,
	flows: Dictionary
) -> bool:
	for edge: Variant in edges:
		if edge is Dictionary and StringName(edge.get("edge_id", "")) == edge_id:
			return (
				float(flows.get(edge_id, 0.0))
				> float(edge.get("effective_capacity", INF))
			)
	return false


func _edge_utilization(
	edge_id: StringName,
	edges: Array,
	flows: Dictionary
) -> float:
	for edge: Variant in edges:
		if edge is Dictionary and StringName(edge.get("edge_id", "")) == edge_id:
			var capacity := float(edge.get("effective_capacity", 0.0))
			if capacity > 0.0:
				return float(flows.get(edge_id, 0.0)) / capacity
	return -INF
