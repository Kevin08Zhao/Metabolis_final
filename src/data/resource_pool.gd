class_name ResourcePool
extends RefCounted

## Runtime resource values and tick rates for the current body-city state.

# Available nutrient energy; initialize from balance.resources.nutrient_energy.initial.
var nutrient_energy: float = 0.0 # SAVED # SNAPSHOT
# Available cell material; initialize from balance.resources.cell_material.initial.
var cell_material: float = 0.0 # SAVED # SNAPSHOT
# Available development signal; initialize from balance.resources.development_signal.initial.
var development_signal: float = 0.0 # SAVED # SNAPSHOT
# Accumulated waste; initialize from balance.resources.waste.initial.
var waste: float = 0.0 # SAVED # SNAPSHOT
# Aggregate city stability; initialize from balance.resources.stability.initial.
var stability: float = 0.0 # SAVED # SNAPSHOT
# Earned knowledge badges; initialize from balance.resources.knowledge_badge_count.initial.
var knowledge_badge_count: int = 0 # SAVED # SNAPSHOT
# Per-tick output by resource ID; initialize from balance.resources.<resource_id>.per_tick_output.
var per_tick_output: Dictionary = {} # SAVED # SNAPSHOT
# Per-tick consumption by resource ID; initialize from balance.resources.<resource_id>.per_tick_consumption.
var per_tick_consumption: Dictionary = {} # SAVED # SNAPSHOT


func initialize_from_balance(_balance_data: Dictionary) -> void:
	pass


func apply_tick(_tick_delta: float) -> void:
	pass


func load_saved_fields(_data: Dictionary) -> void:
	pass


func write_saved_fields(_target: Dictionary) -> void:
	pass
