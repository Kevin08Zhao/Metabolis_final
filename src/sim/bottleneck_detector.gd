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
var _active_results: Dictionary = {}
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
	var target_organ := _lowest_value_id(coverages)
	var target_edge := _highest_utilization_edge(edges, edge_flows, target_organ)
	var under_covered := (
		not target_organ.is_empty()
		and float(coverages[target_organ]) < organ_recover
	)
	var overloaded := _edge_is_overloaded(target_edge, edges, edge_flows)
	var active_now := (
		pressure >= enter
		and not target_edge.is_empty()
		and (under_covered or overloaded)
	)
	var recovered := (
		pressure <= recover
		and _all_values_at_least(coverages, organ_recover)
	)
	_transition(
		TRANSPORT,
		stage_id,
		active_now,
		recovered,
		target_organ,
		target_edge,
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
	_transition(
		WASTE,
		stage_id,
		(waste >= enter or net_rate > rate_enter)
		and not target_organ.is_empty(),
		waste <= recover and net_rate <= rate_recover,
		target_organ,
		target_edge,
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
	var first := not _active_results.has(SIGNAL)
	var active_now := (
		coverage <= enter
		and not target_organ.is_empty()
		and float(ratios[target_organ]) < organ_recover
	)
	var recovered := coverage >= recover and _all_values_at_least(
		ratios,
		organ_recover
	)
	_transition(
		SIGNAL,
		stage_id,
		active_now,
		recovered,
		target_organ,
		target_edge,
		coverage,
		enter,
		&"signal_gap_appeared",
		&"signal_gap_cleared",
		&"",
		results
	)
	if not active_now or not first:
		return
	var compensation := (
		stage_id == &"stage_circulation"
		and bool(metrics.get("transport_coverage_limits_signal", false))
		and not _neural_hint_emitted
	)
	if compensation:
		_neural_hint_emitted = true
		_emit_hint(HINT_NEURAL, target_organ, stage_id)
	elif not bool(_signal_hint_stages.get(stage_id, false)):
		_signal_hint_stages[stage_id] = true
		_emit_hint(HINT_SIGNAL, target_organ, stage_id)


func _transition(
	bottleneck_id: StringName,
	stage_id: StringName,
	active_now: bool,
	recovered: bool,
	target_organ: StringName,
	target_edge: StringName,
	current_value: float,
	threshold: float,
	appeared_event: StringName,
	cleared_event: StringName,
	hint_id: StringName,
	results: Array[Dictionary]
) -> void:
	var was_active := _active_results.has(bottleneck_id)
	if was_active and recovered:
		var previous: Dictionary = _active_results[bottleneck_id]
		var clear_target := StringName(
			previous.get(
				"target_edge_id" if bottleneck_id == TRANSPORT else "target_organ_id",
				""
			)
		)
		_emit(cleared_event, [clear_target])
		_active_results.erase(bottleneck_id)
		_episode_hint_emitted.erase(bottleneck_id)
		return
	if not active_now:
		return
	var result := {
		"bottleneck_id": bottleneck_id,
		"target_organ_id": target_organ,
		"target_edge_id": target_edge,
		"current_value": current_value,
		"threshold": threshold,
		"first_occurrence": not was_active,
	}
	_active_results[bottleneck_id] = result
	results.append(result.duplicate(true))
	if was_active:
		return
	var event_target := target_edge if bottleneck_id == TRANSPORT else target_organ
	_emit(appeared_event, [event_target, current_value])
	if not hint_id.is_empty():
		_episode_hint_emitted[bottleneck_id] = true
		_emit_hint(hint_id, target_organ, stage_id)


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


func _highest_value_id(values: Dictionary) -> StringName:
	var result := &""
	var best := -INF
	for key: Variant in values:
		var value := float(values[key])
		if value > best or (is_equal_approx(value, best) and String(key) < String(result)):
			result = StringName(key)
			best = value
	return result


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
