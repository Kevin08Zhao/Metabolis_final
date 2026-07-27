class_name ChapterData
extends Resource

## Serializable stage definition, progress state, and stage-start conditions.

# Current stage identifier; initialize from balance.chapters.<stage_id>.id.
@export var stage_id: StringName = &"" # SAVED # SNAPSHOT
# Next linear stage identifier; initialize from balance.chapters.<stage_id>.next_stage_id.
@export var next_stage_id: StringName = &"" # SAVED # SNAPSHOT
# Current stage-flow phase; initialize from balance.chapters.<stage_id>.initial_phase.
var phase: StringName = &"" # SAVED # SNAPSHOT
# Required build decision IDs; initialize from balance.chapters.<stage_id>.required_build_decision_ids.
var required_build_decision_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Required operation decision IDs; initialize from balance.chapters.<stage_id>.required_operation_decision_ids.
var required_operation_decision_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Required organ IDs used by stage completion and graph validation; initialize from balance.chapters.<stage_id>.required_organ_ids.
var required_organ_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Irreversibly confirmed build decision IDs; initialize as empty per balance.chapters.<stage_id>.build_confirmation_policy.
var confirmed_build_decision_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Irreversibly confirmed operation decision IDs; initialize as empty per balance.chapters.<stage_id>.operation_confirmation_policy.
var confirmed_operation_decision_ids: Array[StringName] = [] # SAVED # SNAPSHOT
# Build decision currently offered; initialize from balance.chapters.<stage_id>.first_build_decision_id.
var active_build_decision_id: StringName = &"" # SAVED # SNAPSHOT
# Operation decision currently offered; initialize from balance.chapters.<stage_id>.operation_decision_id.
var active_operation_decision_id: StringName = &"" # SAVED # SNAPSHOT
# Optional minigame identifier; initialize from balance.chapters.<stage_id>.minigame_id.
var stage_minigame_id: StringName = &"" # SAVED # SNAPSHOT
# Optional minigame resolution; initialize from balance.minigame.initial_resolution.
var minigame_resolution: StringName = &"" # SAVED # SNAPSHOT
# Whether system collaboration observation is complete; initialize from balance.chapters.<stage_id>.system_observation_complete_initial.
var system_observation_complete: bool = false # SAVED # SNAPSHOT
# Whether the stage knowledge unlock is resolved; initialize from balance.chapters.<stage_id>.knowledge_unlock_resolved_initial.
var knowledge_unlock_resolved: bool = false # SAVED # SNAPSHOT
# Whether a blocking modal prevents stage actions; initialize from balance.ui.blocking_modal_open_initial.
var blocking_modal_open: bool = false # SAVED # SNAPSHOT
# Build option currently selected in the action interface; initialize as empty per balance.build.selection_policy.
var selected_build_option_id: StringName = &""
# Build options available for the active decision; initialize from balance.build_options.<decision_id>.available_option_ids.
var available_build_option_ids: Array[StringName] = []
# Build slot currently selected in the action interface; initialize as empty per balance.build.slot_selection_policy.
var selected_build_slot_id: StringName = &""
# Build slots available for the selected option; initialize from balance.build_options.<decision_id>.<option_id>.available_slot_ids.
var available_build_slot_ids: Array[StringName] = []
# Operation option currently selected in the action interface; initialize as empty per balance.operation.selection_policy.
var selected_operation_id: StringName = &""
# Operation options available in the current stage; initialize from balance.operation.available_options_by_stage.<stage_id>.
var available_operation_ids: Array[StringName] = []
# Current operation allocation total; initialize from balance.operation.allocation.initial_total.
var allocation_total: float = 0.0


func initialize_from_balance(_chapter_balance: Dictionary) -> void:
	pass


func reset_for_replay(_snapshot_data: Dictionary) -> void:
	pass


func load_saved_fields(_data: Dictionary) -> void:
	pass


func write_saved_fields(_target: Dictionary) -> void:
	pass
