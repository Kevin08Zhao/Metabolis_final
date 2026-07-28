class_name BuildDecision
extends Node

## Settles an irreversible, Balance-driven build decision.
##
## Manual acceptance:
## 1. Success: present build_heart_pump as chapter 3, decision 1; select
##    heart_reinforced and a listed slot; press confirm twice. The first press
##    changes no resource. The second deducts 48 nutrient energy, 42 cell
##    material, and 30 development signal, then disables confirmation.
## 2. Shortage: repeat with nutrient energy below 48. The second press changes
##    no resource and feedback_text() names nutrient_energy with a [BUILD] prefix.
## 3. Reselect: after success, select another option or press confirm again.
##    Both calls fail, no resource changes, and the record remains unchanged.
##
## Each confirmed_decisions entry is a read-only copy with these fields:
## chapter_number, decision_sequence, stage_id, decision_id,
## selected_candidate_id, selected_slot_id, spent, preview_snapshot,
## network_efficiency, build_duration, and future_convenience.

const INVESTABLE_RESOURCES: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]
const METRICS: Array[StringName] = [
	&"network_efficiency",
	&"build_duration",
	&"future_convenience",
]
const BUILD_DECISION_PHASE := &"build_decision"
const ACTION_ID := &"confirm_build_decision"

var confirmed_decisions: Dictionary:
	get:
		return _confirmed_decisions.duplicate(true)

var _balance_access: Node
var _event_bus: Node
var _chapter: Object
var _resources: Object
var _confirmed_decisions: Dictionary = {}
var _chapter_number := 0
var _decision_sequence := 0
var _decision_id := StringName()
var _confirmation_pending := false
var _confirmation_enabled := false
var _feedback := ""


func configure(
	balance_access: Node,
	event_bus: Node,
	chapter: Object,
	resources: Object
) -> void:
	_balance_access = balance_access
	_event_bus = event_bus
	_chapter = chapter
	_resources = resources


func present_decision(
	chapter_number: int,
	decision_sequence: int,
	decision_id: StringName
) -> Array[StringName]:
	var empty: Array[StringName] = []
	if not _is_configured():
		_reject(&"not_configured", &"build_decision_panel")
		return empty
	if StringName(_chapter.get("phase")) != BUILD_DECISION_PHASE:
		_reject(&"wrong_phase", &"build_decision_panel")
		return empty
	if _is_confirmed(decision_id):
		_reject(&"already_confirmed", &"confirmation_button")
		return empty

	var option_values: Variant = _balance_access.call(
		"get_value",
		"build_options.%s.available_option_ids" % decision_id,
		[]
	)
	var option_ids := _to_string_name_array(option_values)
	if option_ids.size() < 2 or option_ids.size() > 4:
		_reject(&"invalid_candidate_count", &"option_cards")
		return empty

	var slot_ids: Array[StringName] = []
	for option_id in option_ids:
		var option_slots := _read_option_slots(decision_id, option_id)
		if option_slots.is_empty():
			_reject(&"invalid_slot_set", &"build_slot_overlay")
			return empty
		for slot_id in option_slots:
			if not slot_ids.has(slot_id):
				slot_ids.append(slot_id)

	_chapter_number = chapter_number
	_decision_sequence = decision_sequence
	_decision_id = decision_id
	_confirmation_pending = false
	_confirmation_enabled = true
	_feedback = ""
	_chapter.set("active_build_decision_id", decision_id)
	_chapter.set("available_build_option_ids", option_ids.duplicate())
	_chapter.set("selected_build_option_id", StringName())
	_chapter.set("available_build_slot_ids", slot_ids.duplicate())
	_chapter.set("selected_build_slot_id", StringName())
	_emit_event("build_options_presented", [decision_id, option_ids, slot_ids])
	print("[BUILD] presented decision=", decision_id, " options=", option_ids)
	return option_ids


func select_candidate(option_id: StringName, slot_id: StringName) -> bool:
	if not _confirmation_enabled or _is_confirmed(_decision_id):
		return _reject(&"already_confirmed", &"confirmation_button")
	var available_options := _to_string_name_array(_chapter.get("available_build_option_ids"))
	if not available_options.has(option_id):
		return _reject(&"invalid_option", &"option_cards")
	var available_slots := _read_option_slots(_decision_id, option_id)
	if not available_slots.has(slot_id):
		return _reject(&"invalid_slot", &"build_slot_overlay")

	_chapter.set("selected_build_option_id", option_id)
	_chapter.set("available_build_slot_ids", available_slots.duplicate())
	_chapter.set("selected_build_slot_id", slot_id)
	_confirmation_pending = false
	_feedback = ""
	print("[BUILD] selected option=", option_id, " slot=", slot_id)
	return true


func request_confirmation() -> bool:
	if not _is_configured():
		return _reject(&"not_configured", &"build_decision_panel")
	if _is_confirmed(_decision_id) or not _confirmation_enabled:
		return _reject(&"already_confirmed", &"confirmation_button")
	if StringName(_chapter.get("phase")) != BUILD_DECISION_PHASE:
		return _reject(&"wrong_phase", &"build_decision_panel")
	if StringName(_chapter.get("active_build_decision_id")) != _decision_id:
		return _reject(&"inactive_decision", &"build_decision_panel")

	var option_id := StringName(_chapter.get("selected_build_option_id"))
	var slot_id := StringName(_chapter.get("selected_build_slot_id"))
	var available_options := _to_string_name_array(_chapter.get("available_build_option_ids"))
	var available_slots := _to_string_name_array(_chapter.get("available_build_slot_ids"))
	if not available_options.has(option_id):
		return _reject(&"invalid_option", &"option_cards")
	if not available_slots.has(slot_id):
		return _reject(&"invalid_slot", &"build_slot_overlay")

	if not _confirmation_pending:
		_confirmation_pending = true
		_feedback = "[BUILD] Confirm the irreversible selection again."
		print(_feedback)
		return false

	var option_path := "build_options.%s.%s" % [_decision_id, option_id]
	var cost_variant: Variant = _balance_access.call("get_value", "%s.cost" % option_path, {})
	if not cost_variant is Dictionary:
		return _reject(&"invalid_cost", &"resource_bar")
	var cost: Dictionary = cost_variant
	var spent := _validated_cost(cost)
	if spent.is_empty():
		return false
	var preview := _read_preview(option_path)
	if preview.is_empty():
		return _reject(&"invalid_preview", &"option_cards")

	_confirmation_enabled = false
	_confirmation_pending = false
	for resource_id in INVESTABLE_RESOURCES:
		var current_amount := float(_resources.get(resource_id))
		_resources.set(resource_id, current_amount - float(spent[resource_id]))

	var confirmed_ids := _to_string_name_array(_chapter.get("confirmed_build_decision_ids"))
	confirmed_ids.append(_decision_id)
	_chapter.set("confirmed_build_decision_ids", confirmed_ids)
	var record := {
		"chapter_number": _chapter_number,
		"decision_sequence": _decision_sequence,
		"stage_id": StringName(_chapter.get("stage_id")),
		"decision_id": _decision_id,
		"selected_candidate_id": option_id,
		"selected_slot_id": slot_id,
		"spent": spent.duplicate(true),
		"preview_snapshot": preview.duplicate(true),
		"network_efficiency": preview["network_efficiency"],
		"build_duration": preview["build_duration"],
		"future_convenience": preview["future_convenience"],
	}
	_confirmed_decisions[_decision_id] = record
	_feedback = "[BUILD] Decision confirmed."
	_emit_event(
		"build_decision_confirmed",
		[_decision_id, option_id, slot_id, spent.duplicate(true)]
	)
	print("[BUILD] confirmed decision=", _decision_id, " option=", option_id, " slot=", slot_id)
	return true


func confirmation_enabled() -> bool:
	return _confirmation_enabled


func feedback_text() -> String:
	return _feedback


func restore_confirmed_decisions(records: Dictionary) -> void:
	_confirmed_decisions = records.duplicate(true)
	if _confirmed_decisions.has(_decision_id):
		_confirmation_pending = false
		_confirmation_enabled = false


func _validated_cost(cost: Dictionary) -> Dictionary:
	var spent: Dictionary = {}
	var shortages: Array[String] = []
	for resource_id in INVESTABLE_RESOURCES:
		var value: Variant = cost.get(resource_id, null)
		if not value is float and not value is int:
			_reject(&"invalid_cost", &"resource_bar")
			return {}
		var amount := float(value)
		if amount < 0.0:
			_reject(&"invalid_cost", &"resource_bar")
			return {}
		var available := float(_resources.get(resource_id))
		spent[resource_id] = amount
		if available < amount:
			shortages.append(String(resource_id))
	if not shortages.is_empty():
		_reject(
			&"insufficient_resources",
			&"resource_bar",
			"insufficient resources: %s" % ", ".join(shortages)
		)
		return {}
	return spent


func _read_preview(option_path: String) -> Dictionary:
	var preview: Dictionary = {}
	for metric_id in METRICS:
		var value: Variant = _balance_access.call(
			"get_value",
			"%s.metrics.%s" % [option_path, metric_id],
			null
		)
		if not value is float and not value is int:
			return {}
		preview[metric_id] = float(value)
	return preview


func _read_option_slots(
	decision_id: StringName,
	option_id: StringName
) -> Array[StringName]:
	return _to_string_name_array(
		_balance_access.call(
			"get_value",
			"build_options.%s.%s.available_slot_ids" % [decision_id, option_id],
			[]
		)
	)


func _is_confirmed(decision_id: StringName) -> bool:
	if decision_id.is_empty():
		return false
	if _confirmed_decisions.has(decision_id):
		return true
	if _chapter == null:
		return false
	return _to_string_name_array(_chapter.get("confirmed_build_decision_ids")).has(decision_id)


func _is_configured() -> bool:
	return (
		_balance_access != null
		and _event_bus != null
		and _chapter != null
		and _resources != null
	)


func _reject(
	reason_code: StringName,
	focus_element: StringName,
	detail: String = ""
) -> bool:
	var reason_text := String(reason_code) if detail.is_empty() else detail
	_feedback = "[BUILD] Rejected: %s." % reason_text
	print(_feedback)
	_emit_event("action_rejected", [ACTION_ID, reason_code, focus_element])
	return false


func _emit_event(event_name: StringName, arguments: Array) -> void:
	if _event_bus == null or not _event_bus.has_signal(event_name):
		return
	_event_bus.callv("emit_signal", [event_name] + arguments)


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for item in value:
		result.append(StringName(item))
	return result
