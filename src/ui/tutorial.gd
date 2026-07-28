class_name Tutorial
extends Control

## Two-layer guidance: stage guidance and first-use action guidance.
##
## The two layers answer different questions and never share a trigger. Stage
## guidance runs once at the head of every stage and says what this stage is
## about. Action guidance runs once per *kind* of action, the first time that
## kind becomes available, and shows how to perform it. A player who meets the
## build decision in stage one never sees the build guidance again, in any later
## stage.
##
## Everything either layer does is declared in the tables in the next section.
## The logic below reads those tables and contains no stage name, no action name,
## no event name, and no duration of its own. Adding a guide means adding a row.
##
## Three rules constrain the locking, and all three are enforced structurally
## rather than by convention:
##
##   1. A target is locked for exactly two reasons: it is irrelevant to the
##      current stage (`LOCK_OFF_STAGE`), or a demonstration is playing and this
##      is not the demonstrated target (`LOCK_DEMO`). `lock_target` rejects any
##      other reason.
##   2. The demonstration lock is released the instant the demonstration ends.
##      `_end_demo` is the single exit and it always releases.
##   3. The build candidates and the resource-allocation entry are never locked,
##      by either reason, at any moment. They are listed in `PROTECTED_TARGETS`
##      and `lock_target` refuses them outright, so no future row can lock them
##      by accident.
##
## Relevance is read from configuration, never decided here. A target carries a
## `relevance_path`; when that path resolves to nothing for the current stage the
## target is irrelevant to it. That is how stage four locks the task entry
## without this script knowing that stage four is the one without a minigame:
## `chapters.stage_birth.minigame_id` is null, and the rest follows.
##
## Every string is a placeholder in square brackets. T-34 owns the real wording
## and supplies it through docs/UI_COPY.md. This script invents no player-facing
## sentence and no week number.
##
## Guidance can be skipped at any moment through `skip`, after which nothing
## triggers again for the rest of the save. Completion and skipping are both
## written to the save through `SaveManager`.
##
## Controls opt into a target by joining the group `tutorial_target_<target_id>`.
## That is the whole contract; this node keeps no registry and needs no
## registration call.
##
## Requires the `EventBus`, `Balance`, and `SaveManager` autoloads.

const LOG_PREFIX := "[TUTORIAL]"

## Where the two layers' state lives inside the `main_progress` save block.
const SAVE_BLOCK_KEY := "tutorial"

## Group name prefix a control joins to become part of a target.
const TARGET_GROUP_PREFIX := "tutorial_target_"

## The two, and only two, reasons a target may be locked.
const LOCK_OFF_STAGE := &"off_stage"
const LOCK_DEMO := &"demo"
const ALLOWED_LOCK_REASONS: Array[StringName] = [LOCK_OFF_STAGE, LOCK_DEMO]

## Never locked, for any reason, at any point in either layer. The prompt forbids
## locking the build candidates and the resource-allocation entry outright, so
## the prohibition lives here rather than in each row that might touch them.
const PROTECTED_TARGETS: Array[StringName] = [
	&"build_candidate_cards",
	&"resource_allocation_entry",
]

## The two layers, used as the first field of every emitted signal.
const LAYER_STAGE := &"stage"
const LAYER_ACTION := &"action"


# ---------------------------------------------------------------------------
# Table T1: guidance targets
#
# The first seven are the six regions of section 2 of docs/UI_LAYOUT.md, with
# the task row's minigame entry separated out because it is the one entry point
# a stage can lack. The last two are the protected interaction targets.
#
# `relevance_path` is a Balance path with one `%s` for the stage id. An empty
# path means the target is relevant to every stage. A path whose value is null
# or empty makes the target irrelevant to that stage, which is the only thing
# that produces an off-stage lock.
# ---------------------------------------------------------------------------

const TARGETS: Array[Dictionary] = [
	{
		&"target_id": &"resource_status_bar",
		&"region": "Rect2(0, 0, 640, 16)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"development_timeline",
		&"region": "Rect2(0, 16, 640, 8)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"task_operations_panel",
		&"region": "Rect2(0, 24, 608, 16)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"minigame_entry",
		&"region": "Rect2(0, 24, 608, 16)",
		&"relevance_path": "chapters.%s.minigame_id",
	},
	{
		&"target_id": &"organ_archive_button",
		&"region": "Rect2(608, 24, 16, 16)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"chapter_recap_button",
		&"region": "Rect2(624, 24, 16, 16)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"main_city_map",
		&"region": "Rect2(0, 40, 640, 320)",
		&"relevance_path": "",
	},
	{
		&"target_id": &"build_candidate_cards",
		&"region": "Rect2(0, 40, 640, 320)",
		&"relevance_path": "chapters.%s.required_build_decision_ids",
	},
	{
		&"target_id": &"resource_allocation_entry",
		&"region": "Rect2(0, 24, 608, 16)",
		&"relevance_path": "chapters.%s.required_operation_decision_ids",
	},
]


# ---------------------------------------------------------------------------
# Table T2: the five stage-guidance readings
#
# Fixed at five, in this order. `source` names how the value is produced;
# `placeholder` values are copy T-34 replaces, everything else is derived from
# configuration so that no stage fact is written twice.
# ---------------------------------------------------------------------------

const STAGE_READINGS: Array[Dictionary] = [
	{
		&"reading_id": &"developmental_time",
		&"source": &"placeholder",
		&"template": "[tutorial.time:%s]",
	},
	{
		&"reading_id": &"existing_structures",
		&"source": &"organs_before_stage",
		&"template": "",
	},
	{
		&"reading_id": &"new_demands",
		&"source": &"placeholder",
		&"template": "[tutorial.demands:%s]",
	},
	{
		&"reading_id": &"structures_to_form",
		&"source": &"organs_new_in_stage",
		&"template": "",
	},
	{
		&"reading_id": &"decision_count",
		&"source": &"required_decision_count",
		&"template": "",
	},
]


# ---------------------------------------------------------------------------
# Table T3: the stage-guidance row
#
# One row, applied to each stage of the configured chain. The four concrete
# rows are produced by `stage_guides`; they are not listed here because the
# chain already exists in configuration and a second copy of it would be a
# second thing to keep true.
# ---------------------------------------------------------------------------

const STAGE_GUIDE := {
	&"guide_id_template": "stage_guide_%s",
	&"trigger_signal": &"stage_loaded",
	&"trigger_argument_index": 0,
	&"highlight_target": &"development_timeline",
	&"completion_signal": &"phase_changed",
	&"completion_step_left": &"observe_state",
	&"readings": 5,
}


# ---------------------------------------------------------------------------
# Table T4: action guidance, one row per kind of action
#
# The six kinds are the six player actions of docs/GAME_RULES.md. Each row runs
# at most once per save, the first time its trigger fires.
#
# `trigger_step`, when set, narrows a `phase_changed` trigger to one step of the
# ten-step loop; the ordinal is looked up in `ChapterFlow.STEP_IDS` rather than
# written as a number. `demo_target` is demonstrated and stays interactive;
# every other non-protected target is locked for `demo_sec` and released the
# moment the demonstration ends. `path_targets` is the path hint, in order.
# ---------------------------------------------------------------------------

const ACTION_GUIDES: Array[Dictionary] = [
	{
		&"guide_id": &"action_guide_build_decision",
		&"action_id": &"confirm_build_decision",
		&"trigger_signal": &"build_options_presented",
		&"trigger_step": &"",
		&"demo_target": &"build_candidate_cards",
		&"highlight_target": &"build_candidate_cards",
		&"path_targets": [&"task_operations_panel", &"main_city_map", &"build_candidate_cards"],
		&"completion_signal": &"build_decision_confirmed",
		&"demo_sec": 6.0,
	},
	{
		&"guide_id": &"action_guide_operation_decision",
		&"action_id": &"confirm_operation_decision",
		&"trigger_signal": &"phase_changed",
		&"trigger_step": &"operation_decision",
		&"demo_target": &"resource_allocation_entry",
		&"highlight_target": &"resource_allocation_entry",
		&"path_targets": [&"task_operations_panel", &"resource_allocation_entry"],
		&"completion_signal": &"operation_decision_confirmed",
		&"demo_sec": 6.0,
	},
	{
		&"guide_id": &"action_guide_minigame",
		&"action_id": &"resolve_optional_minigame",
		&"trigger_signal": &"minigame_entered",
		&"trigger_step": &"",
		&"demo_target": &"minigame_entry",
		&"highlight_target": &"minigame_entry",
		&"path_targets": [&"task_operations_panel", &"minigame_entry"],
		&"completion_signal": &"minigame_exited",
		&"demo_sec": 5.0,
	},
	{
		&"guide_id": &"action_guide_transport_intervention",
		&"action_id": &"intervene_transport_network",
		&"trigger_signal": &"transport_pressure_appeared",
		&"trigger_step": &"",
		&"demo_target": &"main_city_map",
		&"highlight_target": &"main_city_map",
		&"path_targets": [&"task_operations_panel", &"main_city_map"],
		&"completion_signal": &"transport_network_intervened",
		&"demo_sec": 5.0,
	},
	{
		&"guide_id": &"action_guide_knowledge_archive",
		&"action_id": &"view_knowledge_archive",
		&"trigger_signal": &"knowledge_entry_unlocked",
		&"trigger_step": &"",
		&"demo_target": &"organ_archive_button",
		&"highlight_target": &"organ_archive_button",
		&"path_targets": [&"development_timeline", &"organ_archive_button"],
		&"completion_signal": &"knowledge_entry_opened",
		&"demo_sec": 4.0,
	},
	{
		&"guide_id": &"action_guide_stage_advance",
		&"action_id": &"advance_to_next_stage",
		&"trigger_signal": &"phase_changed",
		&"trigger_step": &"stage_complete",
		&"demo_target": &"chapter_recap_button",
		&"highlight_target": &"chapter_recap_button",
		&"path_targets": [&"development_timeline", &"chapter_recap_button"],
		&"completion_signal": &"stage_advanced",
		&"demo_sec": 4.0,
	},
]


## Emitted when either layer puts something on screen. `payload` carries the
## five readings for the stage layer and the three parts for the action layer.
signal guide_shown(layer: StringName, guide_id: StringName, payload: Dictionary)

## Emitted when a guide reaches its completion condition.
signal guide_completed(layer: StringName, guide_id: StringName)

## Emitted once, when the player skips. Never emitted again in the same save.
signal guidance_skipped()

var _skipped: bool = false
var _completed_stage_guide_ids: Array[StringName] = []
var _seen_action_guide_ids: Array[StringName] = []

var _current_stage_id: StringName = &""
var _active_stage_guide_id: StringName = &""
var _active_action_guide_id: StringName = &""

var _demo_guide_id: StringName = &""
var _demo_remaining_sec: float = 0.0

## target_id -> Array[StringName] of the reasons currently holding it locked.
var _lock_reasons: Dictionary = {}
## target_id -> { BaseButton: previous disabled state }.
var _previous_disabled: Dictionary = {}

var _stage_label: Label = null
var _action_label: Label = null


func _ready() -> void:
	set_process(false)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_verify_tables()
	_build()
	_connect_tables()
	_adopt_saved_state()


# ---------------------------------------------------------------------------
# The readable tables, resolved
#
# `step_definition_rows` is the whole definition in one list: four stage rows
# and six action rows, each with its trigger, its highlight target, and its
# completion rule. Acceptance prints this rather than reading the source.
# ---------------------------------------------------------------------------

func step_definition_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append_array(stage_guides())
	rows.append_array(action_guides())
	return rows


## The four stage rows, one per stage of the configured chain.
func stage_guides() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for stage_id in stage_order():
		rows.append({
			&"layer": LAYER_STAGE,
			&"guide_id": stage_guide_id(stage_id),
			&"subject": stage_id,
			&"trigger": "%s(%s)" % [STAGE_GUIDE[&"trigger_signal"], stage_id],
			&"highlight_target": STAGE_GUIDE[&"highlight_target"],
			&"completion": (
				"%s leaves step %s, or acknowledge_stage_guide"
				% [STAGE_GUIDE[&"completion_signal"], STAGE_GUIDE[&"completion_step_left"]]
			),
			&"locks": _off_stage_target_ids(stage_id),
		})
	return rows


## The six action rows, in table order.
func action_guides() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for guide in ACTION_GUIDES:
		var trigger: String = String(guide[&"trigger_signal"])
		var step: StringName = guide[&"trigger_step"]
		var demo_target: StringName = guide[&"demo_target"]
		if step != &"":
			trigger = "%s reaching step %s" % [trigger, step]
		rows.append({
			&"layer": LAYER_ACTION,
			&"guide_id": guide[&"guide_id"],
			&"subject": guide[&"action_id"],
			&"trigger": "%s, first occurrence only" % trigger,
			&"highlight_target": guide[&"highlight_target"],
			&"completion": "%s, or the demonstration ending" % guide[&"completion_signal"],
			&"locks": _demo_locked_target_ids(demo_target),
		})
	return rows


## The stage chain, walked from configuration exactly as the flow walks it.
func stage_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var stage_id := _first_stage_id()
	while stage_id != &"" and not order.has(stage_id):
		order.append(stage_id)
		var value: Variant = Balance.get_value("chapters.%s.next_stage_id" % stage_id, null)
		stage_id = &"" if value == null else StringName(str(value))
	return order


func stage_guide_id(stage_id: StringName) -> StringName:
	return StringName(String(STAGE_GUIDE[&"guide_id_template"]) % stage_id)


# ---------------------------------------------------------------------------
# The five stage readings
# ---------------------------------------------------------------------------

## What the stage guidance shows for a stage: five readings, fixed order. Three
## are derived from configuration; two are placeholder copy for T-34.
func stage_readings(stage_id: StringName) -> Dictionary:
	var readings: Dictionary = {}
	for reading in STAGE_READINGS:
		var reading_id: StringName = reading[&"reading_id"]
		readings[reading_id] = _resolve_reading(reading, stage_id)
	return readings


func _resolve_reading(reading: Dictionary, stage_id: StringName) -> Variant:
	var source: StringName = reading[&"source"]
	match source:
		&"placeholder":
			return String(reading[&"template"]) % stage_id
		&"organs_before_stage":
			return _organs_through(_previous_stage_id(stage_id))
		&"organs_new_in_stage":
			var before := _organs_through(_previous_stage_id(stage_id))
			var added: Array[StringName] = []
			for organ_id in _organs_through(stage_id):
				if not before.has(organ_id):
					added.append(organ_id)
			return added
		&"required_decision_count":
			return (
				_string_names_at("chapters.%s.required_build_decision_ids" % stage_id).size()
				+ _string_names_at("chapters.%s.required_operation_decision_ids" % stage_id).size()
			)
	push_error("%s Table T2 names an unknown reading source '%s'." % [LOG_PREFIX, source])
	return "[tutorial.unknown-source]"


func _organs_through(stage_id: StringName) -> Array[StringName]:
	if stage_id == &"":
		return []
	return _string_names_at("organs.required_ids_by_stage.%s" % stage_id)


func _previous_stage_id(stage_id: StringName) -> StringName:
	var previous: StringName = &""
	for candidate in stage_order():
		if candidate == stage_id:
			return previous
		previous = candidate
	return &""


# ---------------------------------------------------------------------------
# Skipping
#
# One call, allowed at any moment, and irreversible for the rest of the save.
# It cancels whatever is on screen, releases every lock it is holding, and
# persists immediately so that a player who skips and quits does not meet the
# guidance again.
# ---------------------------------------------------------------------------

func skip() -> bool:
	if _skipped:
		return false

	_skipped = true
	_end_demo()
	_active_stage_guide_id = &""
	_active_action_guide_id = &""
	_release_all_locks()
	_refresh_labels()
	print("%s Skipped. Nothing triggers again in this save." % LOG_PREFIX)
	guidance_skipped.emit()
	persist()
	return true


func is_skipped() -> bool:
	return _skipped


## True once every stage guide has completed and every action guide has been
## seen. Skipping does not make this true; the two are separate save fields and
## a skipped run reports skipped, not complete.
func is_complete() -> bool:
	for row in stage_guides():
		if not _completed_stage_guide_ids.has(row[&"guide_id"]):
			return false
	for guide in ACTION_GUIDES:
		if not _seen_action_guide_ids.has(guide[&"guide_id"]):
			return false
	return true


func completed_stage_guide_ids() -> Array[StringName]:
	return _completed_stage_guide_ids.duplicate()


func seen_action_guide_ids() -> Array[StringName]:
	return _seen_action_guide_ids.duplicate()


func active_stage_guide_id() -> StringName:
	return _active_stage_guide_id


func active_action_guide_id() -> StringName:
	return _active_action_guide_id


# ---------------------------------------------------------------------------
# The save
#
# The state is a block inside `main_progress`. It is read back through
# `SaveManager.build_payload` and written with `set_main_progress`, so this node
# adds no field to the save format and needs no change in
# src/autoload/save_manager.gd.
# ---------------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"skipped": _skipped,
		"completed_stage_guide_ids": _as_strings(_completed_stage_guide_ids),
		"seen_action_guide_ids": _as_strings(_seen_action_guide_ids),
	}


func apply_save_dict(block: Dictionary) -> void:
	_skipped = bool(block.get("skipped", false))
	_completed_stage_guide_ids = _string_names_in(block.get("completed_stage_guide_ids", []))
	_seen_action_guide_ids = _string_names_in(block.get("seen_action_guide_ids", []))
	if _skipped:
		_release_all_locks()
	_refresh_labels()


## Write the block and save. Called on every completion and on skipping, because
## the prompt requires both outcomes to reach the save rather than only the run.
func persist() -> bool:
	var progress: Dictionary = SaveManager.build_payload().get("main_progress", {})
	progress[SAVE_BLOCK_KEY] = to_save_dict()
	SaveManager.set_main_progress(progress)
	return SaveManager.autosave(&"tutorial")


func _adopt_saved_state() -> void:
	var progress: Dictionary = SaveManager.build_payload().get("main_progress", {})
	var value: Variant = progress.get(SAVE_BLOCK_KEY, {})
	if value is Dictionary:
		apply_save_dict(value)


# ---------------------------------------------------------------------------
# Locking
#
# Two reasons, one entry point, one release. `lock_target` is the only function
# that closes a target and it refuses everything that is not one of the two
# sanctioned reasons, and everything in PROTECTED_TARGETS. A future row cannot
# route around it because nothing else touches `_previous_disabled`.
# ---------------------------------------------------------------------------

func lock_target(target_id: StringName, reason: StringName) -> bool:
	if not ALLOWED_LOCK_REASONS.has(reason):
		push_error(
			"%s Refused to lock '%s': '%s' is not one of the two sanctioned reasons %s."
			% [LOG_PREFIX, target_id, reason, ALLOWED_LOCK_REASONS]
		)
		return false

	if PROTECTED_TARGETS.has(target_id):
		push_error(
			"%s Refused to lock '%s': it is protected and may never be locked, for any reason."
			% [LOG_PREFIX, target_id]
		)
		return false

	if not _is_known_target(target_id):
		push_error("%s Refused to lock '%s': it is not in table T1." % [LOG_PREFIX, target_id])
		return false

	var reasons: Array = _lock_reasons.get(target_id, [])
	if reasons.is_empty():
		_disable_group(target_id)
	if not reasons.has(reason):
		reasons.append(reason)
	_lock_reasons[target_id] = reasons
	return true


func release_target(target_id: StringName, reason: StringName) -> void:
	if not _lock_reasons.has(target_id):
		return
	var reasons: Array = _lock_reasons[target_id]
	reasons.erase(reason)
	if reasons.is_empty():
		_lock_reasons.erase(target_id)
		_restore_group(target_id)
	else:
		_lock_reasons[target_id] = reasons


func locked_target_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key in _lock_reasons:
		ids.append(StringName(str(key)))
	ids.sort()
	return ids


func lock_reasons(target_id: StringName) -> Array[StringName]:
	var reasons: Array[StringName] = []
	var held: Array = _lock_reasons.get(target_id, [])
	for reason in held:
		reasons.append(StringName(str(reason)))
	return reasons


func _release_reason(reason: StringName) -> void:
	for target_id in locked_target_ids():
		release_target(target_id, reason)


func _release_all_locks() -> void:
	for reason in ALLOWED_LOCK_REASONS:
		_release_reason(reason)


func _disable_group(target_id: StringName) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var remembered: Dictionary = {}
	for node in tree.get_nodes_in_group(_group_of(target_id)):
		if node is BaseButton:
			var button: BaseButton = node
			remembered[button] = button.disabled
			button.disabled = true
		else:
			push_warning(
				"%s '%s' is in group '%s' but is not a BaseButton, so it cannot be greyed out."
				% [LOG_PREFIX, node.name, _group_of(target_id)]
			)
	_previous_disabled[target_id] = remembered


func _restore_group(target_id: StringName) -> void:
	var remembered: Dictionary = _previous_disabled.get(target_id, {})
	for key in remembered:
		if not is_instance_valid(key):
			continue
		var button: BaseButton = key
		button.disabled = bool(remembered[key])
	_previous_disabled.erase(target_id)


func _group_of(target_id: StringName) -> StringName:
	return StringName(TARGET_GROUP_PREFIX + String(target_id))


# ---------------------------------------------------------------------------
# Off-stage locking
#
# Recomputed once per stage, from configuration. It holds for the whole stage,
# not only while the stage guidance is on screen, because a target that has
# nothing to do with this stage has nothing to do with it at any point in it.
# ---------------------------------------------------------------------------

func _apply_off_stage_locks(stage_id: StringName) -> void:
	_release_reason(LOCK_OFF_STAGE)
	if _skipped:
		return
	for target_id in _off_stage_target_ids(stage_id):
		lock_target(target_id, LOCK_OFF_STAGE)


func _off_stage_target_ids(stage_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for target in TARGETS:
		var target_id: StringName = target[&"target_id"]
		if PROTECTED_TARGETS.has(target_id):
			continue
		if not _is_relevant(target, stage_id):
			ids.append(target_id)
	return ids


func _is_relevant(target: Dictionary, stage_id: StringName) -> bool:
	var path: String = target[&"relevance_path"]
	if path == "" or stage_id == &"":
		return true
	var value: Variant = Balance.get_value(path % stage_id, null)
	if value == null:
		return false
	if value is Array:
		return not (value as Array).is_empty()
	if value is String:
		return not (value as String).is_empty()
	return true


# ---------------------------------------------------------------------------
# The stage layer
# ---------------------------------------------------------------------------

func _begin_stage_guide(stage_id: StringName) -> void:
	_current_stage_id = stage_id
	_apply_off_stage_locks(stage_id)

	if _skipped:
		return

	var guide_id := stage_guide_id(stage_id)
	if _completed_stage_guide_ids.has(guide_id):
		return

	_active_stage_guide_id = guide_id
	var payload := stage_readings(stage_id)
	payload[&"highlight_target"] = STAGE_GUIDE[&"highlight_target"]
	_refresh_labels()
	print("%s stage guidance for %s: %s" % [LOG_PREFIX, stage_id, payload])
	guide_shown.emit(LAYER_STAGE, guide_id, payload)


## The player's dismissal. The stage guidance also completes on its own when the
## stage leaves the first step, so a player who never presses anything is not
## stuck behind it.
func acknowledge_stage_guide() -> bool:
	if _active_stage_guide_id == &"":
		return false
	_complete_stage_guide()
	return true


func _complete_stage_guide() -> void:
	var guide_id := _active_stage_guide_id
	if guide_id == &"":
		return
	_active_stage_guide_id = &""
	if not _completed_stage_guide_ids.has(guide_id):
		_completed_stage_guide_ids.append(guide_id)
	_refresh_labels()
	print("%s stage guidance %s completed." % [LOG_PREFIX, guide_id])
	guide_completed.emit(LAYER_STAGE, guide_id)
	persist()


# ---------------------------------------------------------------------------
# The action layer
#
# Three parts, in one pass: the demonstration, the highlight, and the path hint.
# The demonstration is the only one that locks anything, and it locks for a
# bounded time rather than until the player acts, so a player who ignores it is
# never held.
# ---------------------------------------------------------------------------

func _begin_action_guide(guide: Dictionary) -> void:
	var guide_id: StringName = guide[&"guide_id"]
	if _skipped or _seen_action_guide_ids.has(guide_id):
		return

	# Marked seen at the start, not at the end. The rule is "the first time this
	# kind of action appears", and it has now appeared; whether the player goes
	# on to perform it is a different question and must not bring the
	# demonstration back a second time.
	_seen_action_guide_ids.append(guide_id)
	_active_action_guide_id = guide_id

	var payload := {
		&"demonstration": "[tutorial.demo:%s]" % guide[&"action_id"],
		&"demo_target": guide[&"demo_target"],
		&"highlight": "[tutorial.highlight:%s]" % guide[&"action_id"],
		&"highlight_target": guide[&"highlight_target"],
		&"path_hint": "[tutorial.path:%s]" % guide[&"action_id"],
		&"path_targets": guide[&"path_targets"],
	}

	_start_demo(guide)
	_refresh_labels()
	print("%s action guidance %s: %s" % [LOG_PREFIX, guide_id, payload])
	guide_shown.emit(LAYER_ACTION, guide_id, payload)
	persist()


func _complete_action_guide(guide_id: StringName) -> void:
	if _active_action_guide_id != guide_id:
		return
	_active_action_guide_id = &""
	if _demo_guide_id == guide_id:
		_end_demo()
	_refresh_labels()
	print("%s action guidance %s completed." % [LOG_PREFIX, guide_id])
	guide_completed.emit(LAYER_ACTION, guide_id)
	persist()


func _start_demo(guide: Dictionary) -> void:
	_end_demo()
	var demo_target: StringName = guide[&"demo_target"]
	_demo_guide_id = guide[&"guide_id"]
	_demo_remaining_sec = float(guide[&"demo_sec"])
	for target_id in _demo_locked_target_ids(demo_target):
		lock_target(target_id, LOCK_DEMO)
	set_process(_demo_remaining_sec > 0.0)


## Everything the demonstration closes: every table T1 target except the one
## being demonstrated and the protected ones. Exposed so acceptance can compare
## this list against the protected list without running a demonstration.
func _demo_locked_target_ids(demo_target: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for target in TARGETS:
		var target_id: StringName = target[&"target_id"]
		if target_id == demo_target or PROTECTED_TARGETS.has(target_id):
			continue
		ids.append(target_id)
	return ids


## The single exit from a demonstration. Always releases, whatever ended it.
func _end_demo() -> void:
	if _demo_guide_id == &"":
		return
	_demo_guide_id = &""
	_demo_remaining_sec = 0.0
	set_process(false)
	_release_reason(LOCK_DEMO)


func demo_running() -> bool:
	return _demo_guide_id != &""


func _process(delta: float) -> void:
	if _demo_guide_id == &"":
		set_process(false)
		return
	_demo_remaining_sec -= delta
	if _demo_remaining_sec <= 0.0:
		var finished := _demo_guide_id
		_end_demo()
		print("%s demonstration %s ended; every demonstration lock released." % [LOG_PREFIX, finished])


# ---------------------------------------------------------------------------
# Wiring
#
# Every connection comes from a table row. Several rows share an event —
# `phase_changed` carries the stage completion and two action triggers — so the
# rows are grouped by event first and each event is connected exactly once.
#
# That grouping is not a tidiness choice. Godot compares two Callables produced
# by `Callable.bind` without looking at the bound arguments, so connecting one
# event twice with different bound keys is rejected as a duplicate connection.
# One connection per event, dispatching to every row that wants it, sidesteps
# the comparison entirely.
#
# Arity comes from the EventBus signal list, so a row for an event of a shape
# not used yet needs no change here.
# ---------------------------------------------------------------------------

## signal name -> the dispatch keys waiting on it, in table order.
var _keys_by_signal: Dictionary = {}


func _connect_tables() -> void:
	var stage_trigger: StringName = STAGE_GUIDE[&"trigger_signal"]
	var stage_completion: StringName = STAGE_GUIDE[&"completion_signal"]
	_register(stage_trigger, "stage_trigger")
	_register(stage_completion, "stage_completion")
	for guide in ACTION_GUIDES:
		var trigger_signal: StringName = guide[&"trigger_signal"]
		var completion_signal: StringName = guide[&"completion_signal"]
		_register(trigger_signal, "action_trigger:%s" % guide[&"guide_id"])
		_register(completion_signal, "action_completion:%s" % guide[&"guide_id"])

	for key in _keys_by_signal:
		_connect_once(StringName(str(key)))


func _register(signal_name: StringName, key: String) -> void:
	var keys: Array = _keys_by_signal.get(signal_name, [])
	keys.append(key)
	_keys_by_signal[signal_name] = keys


func _connect_once(signal_name: StringName) -> void:
	var arity := _signal_arity(signal_name)
	if arity < 0:
		push_error(
			"%s A table row names '%s', which is not a signal on EventBus."
			% [LOG_PREFIX, signal_name]
		)
		return

	# A fresh lambda per event. Lambdas compare by identity, so unlike a bound
	# Callable each one is a distinct connection.
	var relay: Callable
	match arity:
		0:
			relay = func() -> void:
				_dispatch_signal(signal_name, [])
		1:
			relay = func(a: Variant) -> void:
				_dispatch_signal(signal_name, [a])
		2:
			relay = func(a: Variant, b: Variant) -> void:
				_dispatch_signal(signal_name, [a, b])
		3:
			relay = func(a: Variant, b: Variant, c: Variant) -> void:
				_dispatch_signal(signal_name, [a, b, c])
		4:
			relay = func(a: Variant, b: Variant, c: Variant, d: Variant) -> void:
				_dispatch_signal(signal_name, [a, b, c, d])
		_:
			push_error(
				"%s '%s' carries %d arguments; the relays cover up to four."
				% [LOG_PREFIX, signal_name, arity]
			)
			return

	var error := EventBus.connect(signal_name, relay)
	if error != OK:
		push_error("%s Could not connect '%s' (error %d)." % [LOG_PREFIX, signal_name, error])


func _signal_arity(signal_name: StringName) -> int:
	for entry in EventBus.get_signal_list():
		if StringName(str(entry.get("name", ""))) != signal_name:
			continue
		var args: Variant = entry.get("args", [])
		if args is Array:
			return (args as Array).size()
		return 0
	return -1


## Every row waiting on this event, in table order. Order matters in one place:
## a stage guidance completion and an action trigger can both ride the same
## `phase_changed`, and the stage row is registered first so the stage layer
## closes before the action layer opens.
func _dispatch_signal(signal_name: StringName, args: Array) -> void:
	var keys: Array = _keys_by_signal.get(signal_name, [])
	for key in keys:
		_dispatch(str(key), args)


func _dispatch(key: String, args: Array) -> void:
	if _skipped:
		return

	var parts := key.split(":")
	var kind: String = parts[0]
	var guide_id: StringName = StringName(parts[1]) if parts.size() > 1 else &""

	match kind:
		"stage_trigger":
			var index: int = STAGE_GUIDE[&"trigger_argument_index"]
			if index < args.size():
				_begin_stage_guide(StringName(str(args[index])))
		"stage_completion":
			var step_left: StringName = STAGE_GUIDE[&"completion_step_left"]
			if _active_stage_guide_id != &"" and _left_step(args, step_left):
				_complete_stage_guide()
		"action_trigger":
			var guide := _action_guide(guide_id)
			if guide.is_empty():
				return
			var step: StringName = guide[&"trigger_step"]
			if step != &"" and not _entered_step(args, step):
				return
			_begin_action_guide(guide)
		"action_completion":
			_complete_action_guide(guide_id)


## `phase_changed(previous_phase, current_phase)` carries the ordinals of
## `ChapterFlow.Step`. The ordinal is looked up from the step id rather than
## written here, so a reordering of the loop cannot silently retarget a row.
func _entered_step(args: Array, step_id: StringName) -> bool:
	if args.size() < 2:
		return false
	return int(args[1]) == _step_ordinal(step_id)


func _left_step(args: Array, step_id: StringName) -> bool:
	if args.size() < 2:
		return false
	return int(args[0]) == _step_ordinal(step_id) and int(args[1]) != _step_ordinal(step_id)


func _step_ordinal(step_id: StringName) -> int:
	return ChapterFlow.STEP_IDS.find(step_id)


func _action_guide(guide_id: StringName) -> Dictionary:
	for guide in ACTION_GUIDES:
		if guide[&"guide_id"] == guide_id:
			return guide
	return {}


# ---------------------------------------------------------------------------
# Table validation
#
# Run once at _ready. It catches the mistakes a table invites: a protected
# target that some row wants locked, a target id that does not exist, a reading
# list that is no longer five long.
# ---------------------------------------------------------------------------

func _verify_tables() -> void:
	if STAGE_READINGS.size() != int(STAGE_GUIDE[&"readings"]):
		push_error(
			"%s Table T2 holds %d readings; the stage guidance shows exactly %d."
			% [LOG_PREFIX, STAGE_READINGS.size(), int(STAGE_GUIDE[&"readings"])]
		)

	for target_id in PROTECTED_TARGETS:
		if not _is_known_target(target_id):
			push_error("%s Protected target '%s' is not in table T1." % [LOG_PREFIX, target_id])

	for guide in ACTION_GUIDES:
		for field in [&"demo_target", &"highlight_target"]:
			var target_id: StringName = guide[field]
			if not _is_known_target(target_id):
				push_error(
					"%s Row '%s' names target '%s', which is not in table T1."
					% [LOG_PREFIX, guide[&"guide_id"], target_id]
				)
		var path_targets: Array = guide[&"path_targets"]
		for target_id in path_targets:
			if not _is_known_target(target_id):
				push_error(
					"%s Row '%s' names path target '%s', which is not in table T1."
					% [LOG_PREFIX, guide[&"guide_id"], target_id]
				)
		if PROTECTED_TARGETS.has(guide[&"demo_target"]):
			# Legal, and deliberately so: a demonstration of the build decision
			# demonstrates the candidates. It locks everything else and never
			# them, which is why this is a note rather than an error.
			print(
				"%s Row '%s' demonstrates protected target '%s'; it stays interactive throughout."
				% [LOG_PREFIX, guide[&"guide_id"], guide[&"demo_target"]]
			)


func _is_known_target(target_id: StringName) -> bool:
	for target in TARGETS:
		if target[&"target_id"] == target_id:
			return true
	return false


# ---------------------------------------------------------------------------
# Display
#
# Two labels and nothing else. Guidance is a panel, never a modal: it takes no
# input focus and covers no control, so it cannot be what stops a player acting.
# ---------------------------------------------------------------------------

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.name = "Guidance"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	_stage_label = Label.new()
	_stage_label.name = "StageGuidance"
	_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage_label)

	_action_label = Label.new()
	_action_label.name = "ActionGuidance"
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_action_label)

	_refresh_labels()


func _refresh_labels() -> void:
	if _stage_label != null and is_instance_valid(_stage_label):
		_stage_label.text = _stage_text()
		_stage_label.visible = _active_stage_guide_id != &""
	if _action_label != null and is_instance_valid(_action_label):
		_action_label.text = _action_text()
		_action_label.visible = _active_action_guide_id != &""


func _stage_text() -> String:
	if _skipped:
		return "[tutorial.skipped]"
	if _active_stage_guide_id == &"":
		return "[tutorial.stage:none]"
	var parts := PackedStringArray()
	var readings := stage_readings(_current_stage_id)
	for reading in STAGE_READINGS:
		var reading_id: StringName = reading[&"reading_id"]
		parts.append("%s: %s" % [reading_id, _as_text(readings[reading_id])])
	return "\n".join(parts)


func _action_text() -> String:
	if _skipped or _active_action_guide_id == &"":
		return "[tutorial.action:none]"
	var guide := _action_guide(_active_action_guide_id)
	if guide.is_empty():
		return "[tutorial.action:none]"
	return "\n".join(PackedStringArray([
		"[tutorial.demo:%s]" % guide[&"action_id"],
		"[tutorial.highlight:%s]" % guide[&"highlight_target"],
		"[tutorial.path:%s]" % _as_text(guide[&"path_targets"]),
	]))


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

func _first_stage_id() -> StringName:
	var value: Variant = Balance.get_value("progress.initial.current_stage_id", null)
	return &"" if value == null else StringName(str(value))


func _string_names_at(path: String) -> Array[StringName]:
	var value: Variant = Balance.get_value(path, [])
	if not value is Array:
		return []
	return _string_names_in(value)


func _string_names_in(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if not value is Array:
		return names
	for entry in value as Array:
		names.append(StringName(str(entry)))
	return names


func _as_strings(names: Array[StringName]) -> Array:
	var out: Array = []
	for name_value in names:
		out.append(String(name_value))
	return out


func _as_text(value: Variant) -> String:
	if value is Array:
		var parts := PackedStringArray()
		for entry in value as Array:
			parts.append(str(entry))
		return "[%s]" % ", ".join(parts)
	return str(value)
