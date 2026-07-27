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


func load_saved_fields(_data: Dictionary) -> void:
	pass


func write_saved_fields(_target: Dictionary) -> void:
	pass
