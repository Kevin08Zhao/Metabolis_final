class_name DelayedFeedback
extends Node

## Delayed feedback for cross-stage carryover.
##
## A build decision's future-convenience dimension and an operation decision's
## result only fully show up in the stage after the one that made them. T-19h
## already computes and applies the carryover; this node's whole job is to tell
## the player, at the moment a carried value first actually bites, which earlier
## decision put it there.
##
## Timing is the point. The hint fires when the value first affects what the
## player is doing, not when the stage opens. Dumping all three at stage start
## would be an information screen, not a causal link, and would teach nothing.
##
## Three boundaries are deliberate:
##
## - It listens and nothing else. It holds no reference to the carryover
##   settlement, to any decision script, or to the save. It cannot write to a save
##   because it has nowhere to write, which is how the replay rule stays true for
##   free: hints fire normally on a replay and persist nothing.
## - Hints never block. They ride the same non-blocking container as the immediate
##   knowledge hints of table E11, through docs/EVENT_API.md.
## - One hint per carryover field per stage. Repeating it would turn an
##   explanation into nagging.
##
## Requires the `EventBus` and `Balance` autoloads.

const LOG_PREFIX := "[DELAYED]"

## The three table F1 carryover fields, in the order that document lists them.
const CARRYOVER_FIELDS: Array[StringName] = [
	&"network_efficiency_coefficient",
	&"initial_operation_pressure",
	&"initial_waste_accumulation",
]

## Which moment counts as a field first biting. Each is the earliest point at
## which a player could feel that value rather than read it.
##
## network_efficiency_coefficient - the network's capacity first limits delivery,
##   which surfaces as a transport pressure bottleneck.
## initial_operation_pressure - the first operation settlement resolves against a
##   pressure the player did not create this stage.
## initial_waste_accumulation - waste first surfaces as a bottleneck.
const TRIGGERS := {
	&"transport_pressure_appeared": &"network_efficiency_coefficient",
	&"operation_result_settled": &"initial_operation_pressure",
	&"waste_buildup_appeared": &"initial_waste_accumulation",
}

## Stage currently being played, and the carryover it was handed.
var _current_stage_id: StringName = &""
var _source_stage_id: StringName = &""
var _carryover: Dictionary = {}
## Carryover fields already explained during the current stage.
var _shown_this_stage: Array[StringName] = []


func _ready() -> void:
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.carryover_applied.connect(_on_carryover_applied)
	EventBus.transport_pressure_appeared.connect(_on_transport_pressure_appeared)
	EventBus.operation_result_settled.connect(_on_operation_result_settled)
	EventBus.waste_buildup_appeared.connect(_on_waste_buildup_appeared)


# ---------------------------------------------------------------------------
# Read-only view, for a UI that wants to render the hint itself
# ---------------------------------------------------------------------------

## Carryover fields still unexplained in the current stage.
func pending_fields() -> Array[StringName]:
	var pending: Array[StringName] = []
	if _carryover.is_empty():
		return pending
	for field in CARRYOVER_FIELDS:
		if not _shown_this_stage.has(field):
			pending.append(field)
	return pending


## The build decisions of the stage that produced the current carryover. Read
## from configuration, so no decision script has to report anything.
func source_decision_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if _source_stage_id == &"":
		return result
	var value: Variant = Balance.get_value(
		"chapters.%s.required_build_decision_ids" % _source_stage_id, []
	)
	if value is Array:
		for entry in value:
			result.append(StringName(str(entry)))
	return result


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

## A new stage clears the per-stage allowance. The carryover is deliberately not
## cleared here: stage_loaded fires before carryover_applied, so clearing it on
## load and setting it on apply keeps the two in the right order.
func _on_stage_loaded(stage_id: StringName, _stage_index: int) -> void:
	_current_stage_id = stage_id
	_shown_this_stage = []
	_source_stage_id = &""
	_carryover = {}


func _on_carryover_applied(
	from_stage_id: StringName, to_stage_id: StringName, carryover: Dictionary
) -> void:
	if to_stage_id != _current_stage_id:
		return
	_source_stage_id = from_stage_id
	_carryover = carryover.duplicate()


func _on_transport_pressure_appeared(_edge_id: StringName, _severity: float) -> void:
	_explain(&"network_efficiency_coefficient")


func _on_operation_result_settled(_decision_id: StringName, _outcome: Dictionary) -> void:
	_explain(&"initial_operation_pressure")


func _on_waste_buildup_appeared(_organ_id: StringName, _severity: float) -> void:
	_explain(&"initial_waste_accumulation")


# ---------------------------------------------------------------------------
# The one thing this node does
# ---------------------------------------------------------------------------

## Explain a carryover field, once, if this stage actually received one.
## Stage one never explains anything, because it has no predecessor and therefore
## no carryover; that falls out of the empty record rather than a stage check.
func _explain(field: StringName) -> void:
	if _carryover.is_empty() or _source_stage_id == &"":
		return
	if _shown_this_stage.has(field):
		return
	if not _carryover.has(field):
		return

	_shown_this_stage.append(field)
	var decisions := source_decision_ids()

	print(
		"%s %s in %s came from %s (%s); value %s"
		% [LOG_PREFIX, field, _current_stage_id, _source_stage_id, ", ".join(_decision_strings(decisions)), _carryover[field]]
	)
	EventBus.delayed_feedback_shown.emit(field, _source_stage_id, decisions)


func _decision_strings(ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	return out
