class_name NetworkData
extends RefCounted

## Runtime transport graph, routing state, and settled network metrics.

# Transport node records; initialize from balance.network.nodes_by_stage.<stage_id>.
var nodes: Array = [] # SAVED # SNAPSHOT
# Transport edge records; initialize from balance.network.edges_by_stage.<stage_id>.
var edges: Array = [] # SAVED # SNAPSHOT
# IDs of edges currently carrying flow; initialize from balance.network.active_edges_by_stage.<stage_id>.
var active_transport_edge_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# IDs of edges eligible for intervention; initialize from balance.network.mutable_edges_by_stage.<stage_id>.
var mutable_transport_edge_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Alternate-route plans keyed by edge ID; initialize from balance.transport.intervention.plan_by_edge.
var transport_intervention_plan_by_edge: Dictionary = {} # SAVED # SNAPSHOT
# Required-organ disconnection results keyed by edge ID; calculate from the current graph and required organ IDs.
var disconnects_required_organs: Dictionary = {}
# Whether the current stage intervention was consumed; initialize from balance.transport.intervention.used_initial.
var transport_intervention_used: bool = false # SAVED # SNAPSHOT
# Whether the current stage's trunk-direction intervention was consumed.
var trunk_direction_intervention_used: bool = false # SAVED # SNAPSHOT
# Whether the current stage's bottleneck-priority intervention was consumed.
var bottleneck_priority_intervention_used: bool = false # SAVED # SNAPSHOT
# Settled network efficiency; initialize from balance.network.efficiency.initial.
var network_efficiency: float = 0.0 # SAVED # SNAPSHOT
# Settled transport pressure; initialize from balance.transport.pressure.initial.
var transport_pressure: float = 0.0 # SAVED # SNAPSHOT
# Settled city-wide transport coverage; initialize from balance.transport.coverage.initial.
var transport_coverage: float = 0.0 # SAVED # SNAPSHOT
# Settled city-wide development signal coverage; initialize from balance.signal.coverage.initial.
var signal_coverage: float = 0.0 # SAVED # SNAPSHOT
# Starting network multiplier carried into this stage; initialize from balance.carryover.network_efficiency.base.
var network_efficiency_coefficient: float = 0.0 # SAVED # SNAPSHOT
# Edge currently selected in the transport interface; initialize as empty per balance.transport.selection_policy.
var selected_transport_edge_id: StringName = &""


func initialize_from_balance(_network_balance: Dictionary, _stage_id: StringName) -> void:
	pass


func recalculate_routes() -> void:
	pass


func load_saved_fields(data: Dictionary) -> void:
	nodes = data.get("nodes", []).duplicate(true)
	edges = data.get("edges", []).duplicate(true)
	active_transport_edge_ids = _string_name_array(
		data.get("active_transport_edge_ids", [])
	)
	mutable_transport_edge_ids = _string_name_array(
		data.get("mutable_transport_edge_ids", [])
	)
	transport_intervention_plan_by_edge = data.get(
		"transport_intervention_plan_by_edge",
		{}
	).duplicate(true)
	transport_intervention_used = bool(
		data.get("transport_intervention_used", false)
	)
	trunk_direction_intervention_used = bool(
		data.get("trunk_direction_intervention_used", false)
	)
	bottleneck_priority_intervention_used = bool(
		data.get("bottleneck_priority_intervention_used", false)
	)
	network_efficiency = float(data.get("network_efficiency", 0.0))
	transport_pressure = float(data.get("transport_pressure", 0.0))
	transport_coverage = float(data.get("transport_coverage", 0.0))
	signal_coverage = float(data.get("signal_coverage", 0.0))
	network_efficiency_coefficient = float(
		data.get("network_efficiency_coefficient", 0.0)
	)


func write_saved_fields(target: Dictionary) -> void:
	target["nodes"] = nodes.duplicate(true)
	target["edges"] = edges.duplicate(true)
	target["active_transport_edge_ids"] = active_transport_edge_ids.duplicate()
	target["mutable_transport_edge_ids"] = mutable_transport_edge_ids.duplicate()
	target["transport_intervention_plan_by_edge"] = (
		transport_intervention_plan_by_edge.duplicate(true)
	)
	target["transport_intervention_used"] = transport_intervention_used
	target["trunk_direction_intervention_used"] = (
		trunk_direction_intervention_used
	)
	target["bottleneck_priority_intervention_used"] = (
		bottleneck_priority_intervention_used
	)
	target["network_efficiency"] = network_efficiency
	target["transport_pressure"] = transport_pressure
	target["transport_coverage"] = transport_coverage
	target["signal_coverage"] = signal_coverage
	target["network_efficiency_coefficient"] = network_efficiency_coefficient


func _string_name_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not values is Array:
		return result
	for value: Variant in values:
		result.append(StringName(value))
	return result
