class_name OrganData
extends Resource

## Serializable definition and runtime state for one organ or organ system.

# Stable organ identifier; initialize from balance.organs.<organ_id>.id.
@export var organ_id: StringName = &"" # SAVED # SNAPSHOT
# Current organ state ID; initialize from balance.organs.<organ_id>.initial_state.
@export var state_id: StringName = &"" # SAVED # SNAPSHOT
# Selected specification tier; initialize from balance.organs.<organ_id>.spec_tier_id.
@export var spec_tier_id: StringName = &"" # SAVED # SNAPSHOT
# Top-left grid coordinate; initialize from balance.organs.<organ_id>.grid_origin.
@export var grid_origin: Vector2i = Vector2i.ZERO # SAVED # SNAPSHOT
# Grid footprint identifier; initialize from balance.organs.<organ_id>.footprint_id.
@export var footprint_id: StringName = &"" # SAVED # SNAPSHOT
# Whether the organ participates in tick settlement; initialize from balance.organs.<organ_id>.active.
@export var active: bool = false # SAVED # SNAPSHOT
# Organ-local resource values and tick rates; initialize from balance.organs.<organ_id>.resources.
var resource_pool: ResourcePool # SAVED # SNAPSHOT
# Required delivered flow; initialize from balance.organs.<organ_id>.required_flow.
var required_flow: float = 0.0 # SAVED # SNAPSHOT
# Required development signal; initialize from balance.organs.<organ_id>.required_development_signal.
var required_development_signal: float = 0.0 # SAVED # SNAPSHOT
# Settled transport coverage; initialize from balance.organs.<organ_id>.transport_coverage.initial.
var transport_coverage: float = 0.0 # SAVED # SNAPSHOT
# Settled signal coverage; initialize from balance.organs.<organ_id>.signal_coverage.initial.
var signal_coverage: float = 0.0 # SAVED # SNAPSHOT
# Waste generated per tick; initialize from balance.organs.<organ_id>.per_tick_output.waste.
var waste_generation_per_tick: float = 0.0 # SAVED # SNAPSHOT
# Waste processed per tick; initialize from balance.organs.<organ_id>.per_tick_consumption.waste.
var waste_processing_per_tick: float = 0.0 # SAVED # SNAPSHOT


func initialize_from_balance(_organ_balance: Dictionary) -> void:
	pass


func set_runtime_state(_next_state_id: StringName) -> void:
	pass


func load_saved_fields(_data: Dictionary) -> void:
	pass


func write_saved_fields(_target: Dictionary) -> void:
	pass
