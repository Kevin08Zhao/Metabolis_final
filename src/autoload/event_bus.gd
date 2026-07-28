extends Node

## EventBus · global event bus singleton
##
## This file is the code-side mirror of docs/EVENT_API.md: any node can send and
## receive events without holding a reference to any other node.
## It contains signal declarations and debug helpers only, never game logic.
## The signal set must match docs/EVENT_API.md exactly; do not add signals here
## that the document does not define.
##
## Usage:
##   EventBus.stage_advanced.emit(&"stage_01_origin", &"stage_02_harbor")
##   EventBus.stage_advanced.connect(_on_stage_advanced)
##   EventBus.debug_enabled = true   # runtime switch; prints [EVENT] on every emit

# ---------------------------------------------------------------------------
# 1 · Stage advance and snapshot write
# ---------------------------------------------------------------------------
signal stage_advanced(from_stage_id: StringName, to_stage_id: StringName)
signal stage_loaded(stage_id: StringName, stage_index: int)
signal stage_snapshot_written(snapshot_stage_id: StringName, snapshot: Dictionary)
signal phase_changed(previous_phase: int, current_phase: int)

# ---------------------------------------------------------------------------
# 2 · Build options presented, selected, construction started, construction complete
# ---------------------------------------------------------------------------
signal build_options_presented(decision_id: StringName, option_ids: Array[StringName], slot_ids: Array[StringName])
signal build_decision_confirmed(decision_id: StringName, option_id: StringName, slot_id: StringName, spent: Dictionary)
signal organ_construction_started(organ_id: StringName, slot_id: StringName, option_id: StringName)
signal organ_built(organ_id: StringName, slot_id: StringName, option_id: StringName)

# ---------------------------------------------------------------------------
# 3 · Operation decisions and resource priority changes
# ---------------------------------------------------------------------------
signal resource_priority_changed(decision_id: StringName, allocation: Dictionary, allocation_total: float)
signal operation_decision_confirmed(decision_id: StringName, operation_id: StringName, spent: Dictionary)
signal transport_network_intervened(edge_id: StringName, plan_id: StringName, capacity: float)
signal operation_result_settled(decision_id: StringName, outcome: Dictionary)
signal resources_settled(stage_id: StringName, deltas: Dictionary, totals: Dictionary)

# ---------------------------------------------------------------------------
# 4 · The three bottleneck types appearing and clearing
# ---------------------------------------------------------------------------
signal transport_pressure_appeared(edge_id: StringName, severity: float)
signal transport_pressure_cleared(edge_id: StringName)
signal waste_buildup_appeared(organ_id: StringName, severity: float)
signal waste_buildup_cleared(organ_id: StringName)
signal signal_gap_appeared(organ_id: StringName, severity: float)
signal signal_gap_cleared(organ_id: StringName)

# ---------------------------------------------------------------------------
# 5 · Stability band change, waste overflow, investable resource shortage
# ---------------------------------------------------------------------------
signal stability_band_changed(previous_band: int, current_band: int, stability: float)
signal waste_overflowed(waste: float, stability_penalty: float)
signal resource_shortage_raised(resource_id: StringName, amount: float, threshold: float)
signal resource_shortage_cleared(resource_id: StringName, amount: float)

# ---------------------------------------------------------------------------
# 6 · Minigame entry, exit, and star rating
# ---------------------------------------------------------------------------
signal minigame_entered(minigame_id: StringName, stage_id: StringName, time_limit_sec: float)
signal minigame_exited(minigame_id: StringName, resolution: int, elapsed_sec: float)
signal minigame_rated(minigame_id: StringName, stars: int, rating_detail: Dictionary)

# ---------------------------------------------------------------------------
# 7 · Knowledge unlock, system observation, carryover application
# ---------------------------------------------------------------------------
signal system_observation_started(organ_id: StringName, observation_id: StringName)
signal system_observation_ended(organ_id: StringName, observation_id: StringName)
signal knowledge_entry_unlocked(entry_id: StringName, organ_id: StringName, stage_id: StringName)
signal knowledge_entry_opened(entry_id: StringName, first_read: bool)
signal carryover_applied(from_stage_id: StringName, to_stage_id: StringName, carryover: Dictionary)
signal season_completed(summary: Dictionary)
signal delayed_feedback_shown(carryover_field: StringName, source_stage_id: StringName, source_decision_ids: Array[StringName])

# ---------------------------------------------------------------------------
# 8 · Action rejection
# ---------------------------------------------------------------------------
signal action_rejected(action_id: StringName, reason_code: StringName, focus_element: StringName)

# ---------------------------------------------------------------------------
# 9 · Birth transition
# ---------------------------------------------------------------------------
signal birth_sequence_started(stage_id: StringName, total_budget_ms: int)
signal birth_state_changed(previous_state: int, current_state: int, window_ms: int)
signal birth_sequence_completed(stage_id: StringName)
signal birth_rolled_back(from_state: int, reason_code: StringName)


# ---------------------------------------------------------------------------
# Debug helpers
# ---------------------------------------------------------------------------

## Shared prefix for every debug line this singleton prints.
const LOG_PREFIX := "[EVENT]"

## Every event name defined by docs/EVENT_API.md, in document order.
## This constant also keeps the debug logger attached only to the listed signals,
## so the built-in Node signals stay untouched.
const EVENT_NAMES := [
	&"stage_advanced",
	&"stage_loaded",
	&"stage_snapshot_written",
	&"phase_changed",
	&"build_options_presented",
	&"build_decision_confirmed",
	&"organ_construction_started",
	&"organ_built",
	&"resource_priority_changed",
	&"operation_decision_confirmed",
	&"transport_network_intervened",
	&"operation_result_settled",
	&"resources_settled",
	&"transport_pressure_appeared",
	&"transport_pressure_cleared",
	&"waste_buildup_appeared",
	&"waste_buildup_cleared",
	&"signal_gap_appeared",
	&"signal_gap_cleared",
	&"stability_band_changed",
	&"waste_overflowed",
	&"resource_shortage_raised",
	&"resource_shortage_cleared",
	&"minigame_entered",
	&"minigame_exited",
	&"minigame_rated",
	&"system_observation_started",
	&"system_observation_ended",
	&"knowledge_entry_unlocked",
	&"knowledge_entry_opened",
	&"carryover_applied",
	&"season_completed",
	&"delayed_feedback_shown",
	&"action_rejected",
	&"birth_sequence_started",
	&"birth_state_changed",
	&"birth_sequence_completed",
	&"birth_rolled_back",
]

## Debug switch, changeable at any time while running. When true, every emit
## prints one [EVENT] line; when false this singleton produces no output at all.
## Deliberately a plain variable rather than conditional compilation.
var debug_enabled: bool = false


func _ready() -> void:
	_attach_debug_logger()


## Attach the shared debug logger to every signal listed in EVENT_NAMES.
## The logger makes no gameplay decision; it only prints when debug_enabled.
func _attach_debug_logger() -> void:
	for signal_info in get_signal_list():
		var event_name := StringName(signal_info["name"])
		if not EVENT_NAMES.has(event_name):
			continue
		var argument_count: int = (signal_info["args"] as Array).size()
		var logger := Callable(self, "_log_%d" % argument_count).bind(event_name)
		if not is_connected(event_name, logger):
			connect(event_name, logger)


## Self-check: compare the signals this script actually declares against
## EVENT_NAMES. Returns two keys: "missing" for names listed but not declared,
## and "extra" for signals declared but not listed.
## Used by the T-44 smoke test and after any change to docs/EVENT_API.md.
func verify_signal_set() -> Dictionary:
	var declared: Array[StringName] = []
	for signal_info in get_signal_list():
		declared.append(StringName(signal_info["name"]))
	var missing: Array[StringName] = []
	for expected_name in EVENT_NAMES:
		if not declared.has(expected_name):
			missing.append(expected_name)
	var extra: Array[StringName] = []
	for declared_name in declared:
		if EVENT_NAMES.has(declared_name):
			continue
		if _is_builtin_signal(declared_name):
			continue
		extra.append(declared_name)
	return {"missing": missing, "extra": extra}


## Signals built into Node and Object are excluded from the self-check.
func _is_builtin_signal(event_name: StringName) -> bool:
	return ClassDB.class_has_signal("Node", event_name)


func _log(event_name: StringName, arguments: Array) -> void:
	if not debug_enabled:
		return
	print(LOG_PREFIX, " ", event_name, " ", arguments)


# Dispatch by argument count. In Godot 4 bound arguments are appended after the
# signal arguments, so the last parameter of each dispatcher is the event name.
func _log_1(a0: Variant, event_name: StringName) -> void:
	_log(event_name, [a0])


func _log_2(a0: Variant, a1: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1])


func _log_3(a0: Variant, a1: Variant, a2: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1, a2])


func _log_4(a0: Variant, a1: Variant, a2: Variant, a3: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1, a2, a3])
