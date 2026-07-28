class_name Ending
extends Node

## End state and run closure.
##
## The first season is complete when six conditions all hold. This node judges
## them one by one, refuses to close on anything less, freezes the run, builds the
## summary, and announces it. It presents no UI itself; the ending screen listens
## for `season_completed` and renders what it is handed.
##
## Two things are deliberately absent from the summary and must stay absent: any
## score, grade, or title. The run is a developmental process, not a performance,
## and ranking it would contradict what the game is teaching. Minigame stars are
## recorded because the player earned them, but they are never totalled into
## anything.
##
## It reads the run rather than driving it. Everything it knows arrives through
## docs/EVENT_API.md, except the two machines it is handed a reference to, which
## it only ever queries.
##
## Requires the `EventBus` and `Balance` autoloads.

const LOG_PREFIX := "[ENDING]"

## The six completion conditions of the first season, judged individually.
## Any one of them false keeps the run open.
const CONDITIONS: Array[StringName] = [
	&"all_stages_complete",
	&"organ_systems_established",
	&"birth_check_passed",
	&"birth_transition_complete",
	&"first_breath_started",
	&"ending_viewed",
]

## Shown on the ending screen. Provisional wording: T-31 owns docs/UI_COPY.md and
## will replace it there once D-17 unblocks that task. It is carried here rather
## than left to the UI so that no build can ship the ending without it.
const TEACHING_MODEL_DISCLAIMER := (
	"Metabolis is a simplified educational model of human development. "
	+ "It is not a medical tool and must not be used for medical judgement, "
	+ "diagnosis, or treatment."
)

## The stage chain. Queried, never driven.
var chapter_flow: ChapterFlow = null
## The birth machine. Queried, never driven.
var birth_machine: BirthMachine = null
## Nodes whose processing stops when the run closes, wired by the scene owner.
## The resource tick belongs here. Freezing by reference rather than by reaching
## into another script keeps this task to one file.
var freeze_targets: Array[Node] = []

var _ended: bool = false
var _summary: Dictionary = {}

var _operating_time_sec: float = 0.0
var _knowledge_reading_time_sec: float = 0.0
var _current_stage_id: StringName = &""
var _build_choices: Dictionary = {}
var _final_resources: Dictionary = {}
var _built_organ_ids: Array[StringName] = []
var _minigames: Dictionary = {}


func _ready() -> void:
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.build_decision_confirmed.connect(_on_build_decision_confirmed)
	EventBus.organ_built.connect(_on_organ_built)
	EventBus.resources_settled.connect(_on_resources_settled)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	EventBus.minigame_rated.connect(_on_minigame_rated)


## Operating time accrues only while the run is open. Reading time is reported
## separately by whoever owns the blocking archive panels, so the two never
## overlap and the summary can list them apart as the prompt requires.
func _process(delta: float) -> void:
	if not _ended:
		_operating_time_sec += delta


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

## Reported by the archive and summary panels when a blocking read closes.
## Those panels pause the game, so their time is not operating time.
func add_reading_time(seconds: float) -> void:
	if seconds > 0.0:
		_knowledge_reading_time_sec += seconds


## Judge all six conditions. Returns each by name so a caller can show exactly
## which one is outstanding rather than a bare false.
func evaluate_conditions() -> Dictionary:
	var stages_done := chapter_flow != null and chapter_flow.is_run_complete()
	var organs_done := _required_organ_ids().all(func(id): return _built_organ_ids.has(id))
	var gate_passed := birth_machine != null and birth_machine.gate_passed()
	var transition_done := birth_machine != null and birth_machine.birth_transition_complete
	var breath_started := birth_machine != null and birth_machine.current_state() == BirthMachine.State.ENDING
	var ending_seen := birth_machine != null and birth_machine.first_breath_complete

	return {
		&"all_stages_complete": stages_done,
		&"organ_systems_established": organs_done,
		&"birth_check_passed": gate_passed,
		&"birth_transition_complete": transition_done,
		&"first_breath_started": breath_started,
		&"ending_viewed": ending_seen,
	}


## Close the run if every condition holds. Returns false and changes nothing
## otherwise, naming the outstanding conditions in the log.
func try_close() -> bool:
	if _ended:
		return false

	var verdict := evaluate_conditions()
	var outstanding: Array[StringName] = []
	for condition in CONDITIONS:
		if not bool(verdict[condition]):
			outstanding.append(condition)

	if not outstanding.is_empty():
		print("%s Not complete; outstanding: %s" % [LOG_PREFIX, ", ".join(_names(outstanding))])
		return false

	_ended = true
	_freeze()
	_summary = _build_summary()
	print("%s Season complete. Run frozen; summary built." % LOG_PREFIX)
	print("%s %s" % [LOG_PREFIX, TEACHING_MODEL_DISCLAIMER])
	EventBus.season_completed.emit(_summary.duplicate(true))
	return true


func is_ended() -> bool:
	return _ended


func summary() -> Dictionary:
	return _summary.duplicate(true)


# ---------------------------------------------------------------------------
# Freezing
# ---------------------------------------------------------------------------

## Stop the resource tick and any other node the scene owner wired in, and stop
## accruing operating time. The stage chain needs nothing done to it: condition
## one already required it to be complete, so there is nothing left to advance.
func _freeze() -> void:
	set_process(false)
	for node in freeze_targets:
		if is_instance_valid(node):
			node.set_process(false)
			node.set_physics_process(false)
			print("%s Froze %s." % [LOG_PREFIX, node.name])


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

## Exactly the fields the prompt lists, and nothing else. No score, no grade, no
## title. If a future task wants one, it has to change the prompt first.
func _build_summary() -> Dictionary:
	return {
		&"completion_time": {
			&"operating_time_sec": _operating_time_sec,
			&"knowledge_reading_time_sec": _knowledge_reading_time_sec,
		},
		&"build_choices_by_stage": _build_choices.duplicate(true),
		&"final_resources": _final_resources.duplicate(true),
		&"birth_check_values": _birth_check_values(),
		&"minigames": _minigames.duplicate(true),
		&"teaching_model_disclaimer": TEACHING_MODEL_DISCLAIMER,
	}


func _birth_check_values() -> Dictionary:
	if birth_machine == null:
		return {}
	var report := birth_machine.gate_report
	var values: Variant = report.get("current_values", {})
	return (values as Dictionary).duplicate() if values is Dictionary else {}


func _required_organ_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var value: Variant = Balance.get_value("chapters.stage_birth.required_organ_ids", [])
	if value is Array:
		for entry in value:
			result.append(StringName(str(entry)))
	return result


func _names(ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	return out


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_stage_loaded(stage_id: StringName, _stage_index: int) -> void:
	_current_stage_id = stage_id


func _on_build_decision_confirmed(
	decision_id: StringName, option_id: StringName, _slot_id: StringName, _spent: Dictionary
) -> void:
	if not _build_choices.has(_current_stage_id):
		_build_choices[_current_stage_id] = {}
	var stage_choices: Dictionary = _build_choices[_current_stage_id]
	stage_choices[decision_id] = option_id


func _on_organ_built(organ_id: StringName, _slot_id: StringName, _option_id: StringName) -> void:
	if not _built_organ_ids.has(organ_id):
		_built_organ_ids.append(organ_id)


func _on_resources_settled(_stage_id: StringName, _deltas: Dictionary, totals: Dictionary) -> void:
	_final_resources = totals.duplicate()


func _on_minigame_exited(minigame_id: StringName, resolution: int, _elapsed_sec: float) -> void:
	if not _minigames.has(minigame_id):
		_minigames[minigame_id] = {&"played": false, &"stars": 0}
	var record: Dictionary = _minigames[minigame_id]
	record[&"played"] = resolution == MinigameRuntime.Resolution.COMPLETED


func _on_minigame_rated(minigame_id: StringName, stars: int, _detail: Dictionary) -> void:
	if not _minigames.has(minigame_id):
		_minigames[minigame_id] = {&"played": true, &"stars": 0}
	var record: Dictionary = _minigames[minigame_id]
	record[&"stars"] = stars
