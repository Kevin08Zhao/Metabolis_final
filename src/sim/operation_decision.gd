class_name OperationDecision
extends Node

## Owns one irreversible, Balance-driven operation-priority transaction.
##
## The module's interface is configure, present_decision, select_priority, and
## request_confirmation. The second confirmation atomically locks the decision,
## performs one E3 settlement, runs one E4 threshold check, and publishes a
## read-only record.
##
## Manual acceptance:
## 1. Present stage_origin and confirm transport_priority twice. Print all six
##    resources before and after; the first press changes nothing and the second
##    changes values, settles once, checks thresholds once, and disables confirm.
## 2. Press confirm again in the same stage. No resource, record, or event changes.
## 3. Compare available_operation_ids with Table E6 and print
##    validate_non_dominance(). It returns six pair rows and passed=true.
##
## Each nine-column validation row contains: decision_id, candidate_a,
## candidate_b, a_advantage, b_advantage, seven_dimension_result, delete_flag,
## equal_weight_s, and tolerance_result.

const OPERATION_DECISION_PHASE := &"operation_decision"
const ACTION_ID := &"confirm_operation_decision"
const RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
	&"waste",
	&"stability",
	&"knowledge_badge_count",
]
const INVESTABLE_RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]
const ALLOCATION_CHANNEL_IDS: Array[StringName] = [
	&"transport",
	&"waste",
	&"signal",
]
const VALIDATION_DIMENSIONS: Array[StringName] = [
	&"cost_nutrient_energy",
	&"cost_cell_material",
	&"cost_development_signal",
	&"outcome_transport_pressure",
	&"outcome_waste",
	&"outcome_stability",
	&"outcome_network_efficiency",
]

var decision_records: Dictionary:
	get:
		return _decision_records.duplicate(true)

var _balance_access: Node
var _event_bus: Node
var _chapter: Object
var _resources: Object
var _resource_tick: RefCounted
var _threshold_watcher: RefCounted
var _stage_number := 0
var _decision_id := StringName()
var _selected_allocation: Dictionary = {}
var _confirmation_pending := false
var _confirmation_enabled := false
var _decision_records: Dictionary = {}
var _feedback := ""


func configure(
	balance_access: Node,
	event_bus: Node,
	chapter: Object,
	resources: Object,
	resource_tick: RefCounted,
	threshold_watcher: RefCounted
) -> void:
	_balance_access = balance_access
	_event_bus = event_bus
	_chapter = chapter
	_resources = resources
	_resource_tick = resource_tick
	_threshold_watcher = threshold_watcher


func present_decision(
	stage_number: int,
	decision_id: StringName
) -> Array[StringName]:
	var empty: Array[StringName] = []
	if not _is_configured_for_presentation():
		return empty
	if StringName(_chapter.get("phase")) != OPERATION_DECISION_PHASE:
		return empty
	var stage_id := StringName(_chapter.get("stage_id"))
	var option_ids := _to_string_name_array(
		_read_balance(
			"operations.available_options_by_stage.%s" % stage_id,
			[]
		)
	)
	var expected_count := int(
		_read_balance(
			"operations.option_count_by_stage.%s" % stage_id,
			0
		)
	)
	if option_ids.size() != expected_count:
		return empty
	_stage_number = stage_number
	_decision_id = decision_id
	_selected_allocation = {}
	_confirmation_pending = false
	_confirmation_enabled = true
	_feedback = ""
	_chapter.set("active_operation_decision_id", decision_id)
	_chapter.set("available_operation_ids", option_ids.duplicate())
	_chapter.set("selected_operation_id", StringName())
	_chapter.set(
		"allocation_total",
		float(_read_balance("operations.allocation.initial_total", 0.0))
	)
	return option_ids


func select_priority(operation_id: StringName) -> bool:
	if not _confirmation_enabled or _is_confirmed():
		return false
	var available_ids := _to_string_name_array(
		_chapter.get("available_operation_ids")
	)
	if not available_ids.has(operation_id):
		return false
	var allocation_value: Variant = _read_balance(
		"operations.options.%s.allocation_weights" % operation_id,
		{}
	)
	if not allocation_value is Dictionary:
		return false
	var allocation: Dictionary = allocation_value
	var total := 0.0
	for channel_id in ALLOCATION_CHANNEL_IDS:
		var amount: Variant = allocation.get(channel_id, null)
		if not amount is float and not amount is int:
			return false
		if float(amount) < 0.0:
			return false
		total += float(amount)
	var required_total := float(
		_read_balance("operations.allocation.required_total", 0.0)
	)
	if not is_equal_approx(total, required_total):
		return false
	_selected_allocation = allocation.duplicate(true)
	_chapter.set("selected_operation_id", operation_id)
	_chapter.set("allocation_total", total)
	_confirmation_pending = false
	_feedback = ""
	_emit_event(
		&"resource_priority_changed",
		[_decision_id, _selected_allocation.duplicate(true), total]
	)
	return true


func request_confirmation(settlement_input: Dictionary) -> bool:
	if not _is_fully_configured():
		return _reject(&"not_configured", &"operation_decision_panel")
	if not _confirmation_enabled or _is_confirmed():
		return _reject(&"already_confirmed", &"confirmation_button")
	if StringName(_chapter.get("phase")) != OPERATION_DECISION_PHASE:
		return _reject(&"wrong_phase", &"operation_decision_panel")
	if StringName(_chapter.get("active_operation_decision_id")) != _decision_id:
		return _reject(&"inactive_decision", &"operation_decision_panel")

	var operation_id := StringName(_chapter.get("selected_operation_id"))
	if (
		operation_id.is_empty()
		or not _to_string_name_array(
			_chapter.get("available_operation_ids")
		).has(operation_id)
	):
		return _reject(&"invalid_option", &"operation_option_cards")
	var required_total := float(
		_read_balance("operations.allocation.required_total", 0.0)
	)
	if not is_equal_approx(
		float(_chapter.get("allocation_total")),
		required_total
	):
		return _reject(&"invalid_allocation_total", &"allocation_meter")

	var max_confirms := int(
		_read_balance("operations.max_confirms_per_stage", 0)
	)
	var confirmed_ids := _to_string_name_array(
		_chapter.get("confirmed_operation_decision_ids")
	)
	if max_confirms <= 0 or confirmed_ids.size() >= max_confirms:
		return _reject(&"stage_limit_reached", &"confirmation_button")

	if not _confirmation_pending:
		_confirmation_pending = true
		_feedback = "[OPERATION] Confirm the irreversible priority again."
		print(_feedback)
		return false

	var cost := _validated_cost(operation_id)
	if cost.is_empty():
		return false
	var configured_outcome := _validated_outcome(operation_id)
	if configured_outcome.is_empty():
		return _reject(&"invalid_outcome", &"operation_option_cards")

	var resources_before := _resource_snapshot()
	var resources_for_settlement := _prepare_transaction_resources(
		resources_before,
		cost,
		configured_outcome
	)
	_resource_tick.call(
		"initialize_from_balance",
		resources_for_settlement.duplicate(true)
	)
	var operation_input := settlement_input.duplicate(true)
	_apply_allocation_to_settlement_input(operation_input)
	operation_input["operation_id"] = operation_id
	var tick_delta := float(_read_balance("tick_interval_sec", 0.0))
	var settled_value: Variant = _resource_tick.call(
		"settle_tick",
		tick_delta,
		operation_input
	)
	if not settled_value is Dictionary:
		return _reject(&"settlement_failed", &"resource_bar")
	var settled_resources: Dictionary = settled_value
	if not _has_all_resources(settled_resources):
		return _reject(&"settlement_failed", &"resource_bar")

	var resources_after := _apply_settled_resources(settled_resources)
	var deltas := _resource_deltas(resources_before, resources_after)

	_confirmation_enabled = false
	_confirmation_pending = false
	confirmed_ids.append(_decision_id)
	_chapter.set("confirmed_operation_decision_ids", confirmed_ids)

	var outcome := {
		"operation_id": operation_id,
		"allocation": _selected_allocation.duplicate(true),
		"configured_effect": configured_outcome.duplicate(true),
		"resources": resources_after.duplicate(true),
		"deltas": deltas.duplicate(true),
	}
	var record := {
		"stage_number": _stage_number,
		"stage_id": StringName(_chapter.get("stage_id")),
		"decision_id": _decision_id,
		"selected_priority_id": operation_id,
		"allocation": _selected_allocation.duplicate(true),
		"resources_at_submission": resources_before.duplicate(true),
		"spent": cost.duplicate(true),
		"settled_resources": resources_after.duplicate(true),
		"outcome": outcome.duplicate(true),
	}
	_decision_records[_decision_id] = record

	_emit_event(
		&"operation_decision_confirmed",
		[_decision_id, operation_id, cost.duplicate(true)]
	)
	var threshold_events: Array = _threshold_watcher.call(
		"watch",
		resources_after.duplicate(true)
	)
	outcome["threshold_events"] = threshold_events.duplicate(true)
	record["outcome"] = outcome.duplicate(true)
	record["threshold_events"] = threshold_events.duplicate(true)
	_decision_records[_decision_id] = record
	_emit_event(
		&"operation_result_settled",
		[_decision_id, outcome.duplicate(true)]
	)
	_feedback = "[OPERATION] Decision confirmed and settled."
	print(
		"[OPERATION] confirmed decision=",
		_decision_id,
		" priority=",
		operation_id,
		" before=",
		resources_before,
		" after=",
		resources_after,
		" thresholds=",
		threshold_events
	)
	return true


func confirmation_enabled() -> bool:
	return _confirmation_enabled


func feedback_text() -> String:
	return _feedback


func restore_decision_records(records: Dictionary) -> void:
	_decision_records = records.duplicate(true)
	if _decision_records.has(_decision_id):
		_confirmation_pending = false
		_confirmation_enabled = false


func validate_non_dominance() -> Dictionary:
	var stage_id := StringName()
	if _chapter != null:
		stage_id = StringName(_chapter.get("stage_id"))
	var option_ids := _to_string_name_array(
		_read_balance(
			"operations.available_options_by_stage.%s" % stage_id,
			[]
		)
	)
	var raw_scores: Dictionary = {}
	for option_id in option_ids:
		var values := _validation_values(option_id)
		if values.is_empty():
			return {"passed": false, "rows": [], "reason": &"invalid_option_data"}
		raw_scores[option_id] = values
	var normalized_scores := _normalize_validation_scores(
		option_ids,
		raw_scores
	)
	if normalized_scores.is_empty():
		return {"passed": false, "rows": [], "reason": &"invalid_score_range"}

	var tolerance := float(
		_read_balance(
			"build_options.validation.equal_weight_tolerance",
			0.0
		)
	)
	var rows: Array[Dictionary] = []
	var passed := true
	for first_index in range(option_ids.size()):
		for second_index in range(first_index + 1, option_ids.size()):
			var candidate_a := option_ids[first_index]
			var candidate_b := option_ids[second_index]
			var scores_a: Dictionary = normalized_scores[candidate_a]
			var scores_b: Dictionary = normalized_scores[candidate_b]
			var a_advantages: Array[StringName] = []
			var b_advantages: Array[StringName] = []
			var a_not_worse := true
			var b_not_worse := true
			var s_a := 0.0
			var s_b := 0.0
			for dimension_id in VALIDATION_DIMENSIONS:
				var a_score := float(scores_a[dimension_id])
				var b_score := float(scores_b[dimension_id])
				s_a += a_score
				s_b += b_score
				if a_score > b_score and not is_equal_approx(a_score, b_score):
					a_advantages.append(dimension_id)
					b_not_worse = false
				elif b_score > a_score and not is_equal_approx(a_score, b_score):
					b_advantages.append(dimension_id)
					a_not_worse = false
			var a_dominates := a_not_worse and not a_advantages.is_empty()
			var b_dominates := b_not_worse and not b_advantages.is_empty()
			var balanced := (
				absf(s_a - s_b)
				<= tolerance * maxf(s_a, s_b)
			)
			if a_dominates or b_dominates or not balanced:
				passed = false
			rows.append({
				"decision_id": _decision_id,
				"candidate_a": candidate_a,
				"candidate_b": candidate_b,
				"a_advantage": a_advantages,
				"b_advantage": b_advantages,
				"seven_dimension_result": (
					&"a_dominates"
					if a_dominates
					else &"b_dominates"
					if b_dominates
					else &"neither_dominates"
				),
				"delete_flag": (
					&"DELETE_A"
					if b_dominates
					else &"DELETE_B"
					if a_dominates
					else &"KEEP_BOTH"
				),
				"equal_weight_s": {"a": s_a, "b": s_b},
				"tolerance_result": {
					"difference": absf(s_a - s_b),
					"limit": tolerance * maxf(s_a, s_b),
					"passed": balanced,
				},
			})
	return {
		"passed": passed,
		"tolerance": tolerance,
		"rows": rows,
	}


func _is_configured_for_presentation() -> bool:
	return (
		_balance_access != null
		and _event_bus != null
		and _chapter != null
		and _resources != null
	)


func _is_fully_configured() -> bool:
	return (
		_is_configured_for_presentation()
		and _resource_tick != null
		and _threshold_watcher != null
		and _resource_tick.has_method("initialize_from_balance")
		and _resource_tick.has_method("settle_tick")
		and _threshold_watcher.has_method("watch")
	)


func _is_confirmed() -> bool:
	if _chapter == null or _decision_id.is_empty():
		return false
	return _to_string_name_array(
		_chapter.get("confirmed_operation_decision_ids")
	).has(_decision_id)


func _emit_event(event_name: StringName, arguments: Array) -> void:
	if _event_bus == null or not _event_bus.has_signal(event_name):
		return
	_event_bus.callv("emit_signal", [event_name] + arguments)


func _validated_cost(operation_id: StringName) -> Dictionary:
	var value: Variant = _read_balance(
		"operations.options.%s.cost" % operation_id,
		{}
	)
	if not value is Dictionary:
		return {}
	var cost: Dictionary = {}
	var shortages: Array[String] = []
	for resource_id in INVESTABLE_RESOURCE_IDS:
		var amount_value: Variant = value.get(resource_id, null)
		if not amount_value is float and not amount_value is int:
			return {}
		var amount := float(amount_value)
		if amount < 0.0:
			return {}
		cost[resource_id] = amount
		if float(_resources.get(resource_id)) < amount:
			shortages.append(String(resource_id))
	if not shortages.is_empty():
		_reject(
			&"insufficient_resources",
			&"resource_bar",
			"insufficient resources: %s" % ", ".join(shortages)
		)
		return {}
	return cost


func _validated_outcome(operation_id: StringName) -> Dictionary:
	var value: Variant = _read_balance(
		"operations.options.%s.outcome" % operation_id,
		{}
	)
	if not value is Dictionary:
		return {}
	var outcome_value: Dictionary = value
	var result: Dictionary = {}
	for metric_id in [
		&"transport_pressure",
		&"waste",
		&"stability",
		&"network_efficiency",
	]:
		var amount: Variant = outcome_value.get(metric_id, null)
		if not amount is float and not amount is int:
			return {}
		result[metric_id] = float(amount)
	return result


func _resource_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		var value: Variant = _resources.get(resource_id)
		if resource_id == &"knowledge_badge_count":
			result[resource_id] = int(value)
		else:
			result[resource_id] = float(value)
	return result


func _has_all_resources(values: Dictionary) -> bool:
	for resource_id in RESOURCE_IDS:
		if not values.has(resource_id):
			return false
		var value: Variant = values[resource_id]
		if not value is float and not value is int:
			return false
	return true


func _prepare_transaction_resources(
	resources_before: Dictionary,
	cost: Dictionary,
	configured_outcome: Dictionary
) -> Dictionary:
	var result := resources_before.duplicate(true)
	for resource_id in INVESTABLE_RESOURCE_IDS:
		result[resource_id] = _clamp_resource(
			resource_id,
			float(result[resource_id]) - float(cost[resource_id])
		)
	result[&"waste"] = _clamp_resource(
		&"waste",
		float(result[&"waste"]) + float(configured_outcome[&"waste"])
	)
	result[&"stability"] = _clamp_resource(
		&"stability",
		float(result[&"stability"]) + float(configured_outcome[&"stability"])
	)
	result[&"knowledge_badge_count"] = int(result[&"knowledge_badge_count"])
	return result


func _apply_settled_resources(settled_resources: Dictionary) -> Dictionary:
	var result := settled_resources.duplicate(true)
	result[&"knowledge_badge_count"] = int(result[&"knowledge_badge_count"])
	for resource_id in RESOURCE_IDS:
		_resources.set(resource_id, result[resource_id])
	return result


func _apply_allocation_to_settlement_input(
	settlement_input: Dictionary
) -> void:
	settlement_input["operation_allocation"] = _selected_allocation.duplicate(
		true
	)
	if settlement_input.has("available_transport_flow"):
		settlement_input["available_transport_flow"] = (
			float(settlement_input["available_transport_flow"])
			* float(_selected_allocation[&"transport"])
		)
	if settlement_input.has("available_development_signal_flow"):
		settlement_input["available_development_signal_flow"] = (
			float(settlement_input["available_development_signal_flow"])
			* float(_selected_allocation[&"signal"])
		)
	if settlement_input.has("available_waste_processing"):
		settlement_input["intervention_waste_removal"] = (
			float(settlement_input.get("intervention_waste_removal", 0.0))
			+ float(settlement_input["available_waste_processing"])
			* float(_selected_allocation[&"waste"])
		)


func _resource_deltas(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		result[resource_id] = (
			float(after[resource_id]) - float(before[resource_id])
		)
	return result


func _clamp_resource(resource_id: StringName, value: float) -> float:
	var minimum := float(_read_balance("operations.normalized.min", 0.0))
	if resource_id == &"waste" or resource_id == &"stability":
		minimum = float(
			_read_balance("resources.%s.min" % resource_id, minimum)
		)
	return clampf(
		value,
		minimum,
		float(_read_balance("resources.%s.max" % resource_id, INF))
	)


func _validation_values(operation_id: StringName) -> Dictionary:
	var cost := _validated_numeric_dictionary(
		"operations.options.%s.cost" % operation_id,
		INVESTABLE_RESOURCE_IDS
	)
	var outcome_dimensions: Array[StringName] = [
		&"transport_pressure",
		&"waste",
		&"stability",
		&"network_efficiency",
	]
	var outcome := _validated_numeric_dictionary(
		"operations.options.%s.outcome" % operation_id,
		outcome_dimensions
	)
	if cost.is_empty() or outcome.is_empty():
		return {}
	return {
		&"cost_nutrient_energy": cost[&"nutrient_energy"],
		&"cost_cell_material": cost[&"cell_material"],
		&"cost_development_signal": cost[&"development_signal"],
		&"outcome_transport_pressure": outcome[&"transport_pressure"],
		&"outcome_waste": outcome[&"waste"],
		&"outcome_stability": outcome[&"stability"],
		&"outcome_network_efficiency": outcome[&"network_efficiency"],
	}


func _validated_numeric_dictionary(
	path: String,
	required_keys: Array[StringName]
) -> Dictionary:
	var value: Variant = _read_balance(path, {})
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var result: Dictionary = {}
	for key in required_keys:
		var number: Variant = source.get(key, null)
		if not number is float and not number is int:
			return {}
		result[key] = float(number)
	return result


func _normalize_validation_scores(
	option_ids: Array[StringName],
	raw_scores: Dictionary
) -> Dictionary:
	var ranges: Dictionary = {}
	for dimension_id in VALIDATION_DIMENSIONS:
		var minimum := INF
		var maximum := -INF
		for option_id in option_ids:
			var raw_value := float(raw_scores[option_id][dimension_id])
			minimum = minf(minimum, raw_value)
			maximum = maxf(maximum, raw_value)
		ranges[dimension_id] = {"min": minimum, "max": maximum}
	var result: Dictionary = {}
	for option_id in option_ids:
		var option_scores: Dictionary = {}
		for dimension_id in VALIDATION_DIMENSIONS:
			var raw_value := float(raw_scores[option_id][dimension_id])
			var minimum := float(ranges[dimension_id]["min"])
			var maximum := float(ranges[dimension_id]["max"])
			var score := 1.0
			if not is_equal_approx(minimum, maximum):
				var lower_is_better := (
					String(dimension_id).begins_with("cost_")
					or dimension_id == &"outcome_transport_pressure"
					or dimension_id == &"outcome_waste"
				)
				score = (
					(maximum - raw_value) / (maximum - minimum)
					if lower_is_better
					else (raw_value - minimum) / (maximum - minimum)
				)
			option_scores[dimension_id] = score
		result[option_id] = option_scores
	return result


func _reject(
	reason_code: StringName,
	focus_element: StringName,
	detail: String = ""
) -> bool:
	var reason_text := String(reason_code) if detail.is_empty() else detail
	_feedback = "[OPERATION] Rejected: %s." % reason_text
	print(_feedback)
	_emit_event(&"action_rejected", [ACTION_ID, reason_code, focus_element])
	return false


func _read_balance(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for item in value:
		result.append(StringName(item))
	return result
