class_name GameState
extends Node

## Scene-tree owner for the three-block save structure and current runtime state.

# Save-format version; initialize from balance.save.version.
var save_version: int = 0 # SAVED
# Main progression block containing current and unlocked stage IDs; initialize from balance.progress.initial.
var main_progress: Dictionary = {} # SAVED
# Complete current city block containing ResourcePool, OrganData records, NetworkData, ChapterData, and the exact three-field operation_start_conditions record; initialize from balance.save.current_city_state_schema.
var current_city_state: Dictionary = {} # SAVED # SNAPSHOT
# Stage-start city snapshots keyed by stage ID; initialize as empty and write once per balance.save.chapter_snapshot_policy.
var chapter_snapshots: Dictionary = {} # SAVED
# Unlocked knowledge entry IDs; initialize from balance.knowledge.initial_unlocked_entry_ids.
var unlocked_knowledge_entry_ids: Array[StringName] = [] # SAVED
# Read knowledge entry IDs; initialize as empty per balance.knowledge.read_tracking_policy.
var read_knowledge_entry_ids: Array[StringName] = [] # SAVED
# Knowledge entry currently selected in the archive interface; initialize as empty per balance.knowledge.selection_policy.
var selected_knowledge_entry_id: StringName = &""


func initialize_new_game(_balance_data: Dictionary) -> void:
	pass


func bind_current_city_state(
	_resources: ResourcePool,
	_organs: Array[OrganData],
	_network: NetworkData,
	_chapter: ChapterData
) -> void:
	pass


func create_stage_snapshot(_stage_id: StringName) -> void:
	pass


func restore_stage_snapshot(_stage_id: StringName) -> void:
	pass


func load_save_blocks(_save_data: Dictionary) -> void:
	pass


func write_save_blocks(_target: Dictionary) -> void:
	pass
