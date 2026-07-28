class_name Carryover
extends Node

## Calculates, stores, restores, and summarizes the three cross-stage values.
##
## Generation is deliberately separate from persistence. Call
## generate_transition_record() when the stage advance is locked, then call
## commit_first_visit() only after the destination stage has loaded. Call
## complete_runtime_application() only after the network multiplier, operating
## pressure, and waste have reached their Table F1 runtime positions.
##
## Manual acceptance:
## 1. Generate and commit stage_harbor -> stage_circulation with the lowest
##    legal network-efficiency choices. Print the returned record and the
##    three-line summary.
## 2. Advance to stage_birth, change current_city_state, then call
##    apply_replay_snapshot() for stage_circulation. Confirm the restored
##    values exactly match the stored stage_circulation snapshot.
## 3. Generate from stage_birth. Confirm the result is empty and neither save
##    block changes.

const CARRYOVER_FIELDS: Array[StringName] = [
	&"network_efficiency_coefficient",
	&"initial_operation_pressure",
	&"initial_waste_accumulation",
]

var _balance_access: Node
var _event_bus: Node
var _game_state: Object
var _pending_application_from_stage_id := StringName()
var _pending_application_to_stage_id := StringName()
var _pending_application_record: Dictionary = {}


func configure(
	balance_access: Node,
	event_bus: Node,
	game_state: Object
) -> void:
	_balance_access = balance_access
	_event_bus = event_bus
	_game_state = game_state


func generate_transition_record(
	from_stage_id: StringName,
	to_stage_id: StringName,
	build_decision_records: Dictionary,
	operation_settlement: Dictionary
) -> Dictionary:
	if not _is_configured():
		return _reject_record("not configured")
	if not _stage_exists(from_stage_id):
		return _reject_record("source stage is not configured")
	var configured_next := _configured_next_stage(from_stage_id)
	if configured_next.is_empty():
		print("[CARRYOVER] Final stage produces no carryover.")
		return {}
	if configured_next != to_stage_id:
		return _reject_record("destination does not match the stage chain")

	var build_deltas := _calculate_build_deltas(
		from_stage_id,
		build_decision_records
	)
	if build_deltas.is_empty():
		return _reject_record("invalid build decision records")
	if not _valid_operation_settlement(operation_settlement):
		return _reject_record("invalid operation settlement")

	var record := {
		&"network_efficiency_coefficient": _calculate_output(
			&"network_efficiency",
			float(build_deltas[&"network_efficiency_delta"]),
			float(operation_settlement[&"transport_coverage_settled"]),
			"source_transport_coverage_range"
		),
		&"initial_operation_pressure": _calculate_output(
			&"operation_pressure",
			float(build_deltas[&"operation_pressure_delta"]),
			float(operation_settlement[&"transport_pressure_settled"]),
			"source_transport_pressure_range"
		),
		&"initial_waste_accumulation": _calculate_output(
			&"waste",
			float(build_deltas[&"waste_delta"]),
			float(operation_settlement[&"waste_settled"]),
			"source_waste_range"
		),
	}
	if not _valid_carryover_record(record):
		return _reject_record("calculated record is outside configured ranges")
	print(
		"[CARRYOVER] generated from=",
		from_stage_id,
		" to=",
		to_stage_id,
		" values=",
		record
	)
	return record


func commit_first_visit(
	from_stage_id: StringName,
	to_stage_id: StringName,
	record: Dictionary
) -> bool:
	if not _is_configured():
		return _reject_commit("not configured")
	if (
		not _stage_exists(from_stage_id)
		or to_stage_id.is_empty()
		or not _stage_exists(to_stage_id)
	):
		return _reject_commit("invalid stage transition")
	if _configured_next_stage(from_stage_id) != to_stage_id:
		return _reject_commit("destination does not match the stage chain")
	if not _valid_carryover_record(record):
		return _reject_commit("invalid carryover record")
	if (
		String(
			_read_balance("save.chapter_snapshot_policy", "")
		)
		!= "write_once_on_first_entry"
	):
		return _reject_commit("unsupported snapshot policy")

	var snapshots_value: Variant = _game_state.get("chapter_snapshots")
	var city_value: Variant = _game_state.get("current_city_state")
	if not snapshots_value is Dictionary or not city_value is Dictionary:
		return _reject_commit("invalid save blocks")

	var snapshots: Dictionary = snapshots_value.duplicate(true)
	var destination_snapshot: Dictionary = {}
	if snapshots.has(to_stage_id):
		var existing_value: Variant = snapshots[to_stage_id]
		if not existing_value is Dictionary:
			return _reject_commit("invalid destination snapshot")
		destination_snapshot = existing_value.duplicate(true)
	if destination_snapshot.has(&"operation_start_conditions"):
		return _reject_commit("destination snapshot already contains carryover")

	var stored_record := _copy_record(record)
	destination_snapshot[&"operation_start_conditions"] = stored_record
	snapshots[to_stage_id] = destination_snapshot
	var current_city_state: Dictionary = city_value.duplicate(true)
	current_city_state[&"operation_start_conditions"] = stored_record.duplicate(
		true
	)

	_game_state.set("chapter_snapshots", snapshots)
	_game_state.set("current_city_state", current_city_state)
	_set_pending_application(from_stage_id, to_stage_id, stored_record)
	_emit_event(
		&"stage_snapshot_written",
		[to_stage_id, stored_record.duplicate(true)]
	)
	print(
		"[CARRYOVER] committed from=",
		from_stage_id,
		" to=",
		to_stage_id,
		" values=",
		stored_record
	)
	return true


func apply_replay_snapshot(
	from_stage_id: StringName,
	replay_stage_id: StringName
) -> Dictionary:
	if not _is_configured():
		return _reject_record("not configured")
	var snapshots_value: Variant = _game_state.get("chapter_snapshots")
	var city_value: Variant = _game_state.get("current_city_state")
	if not snapshots_value is Dictionary or not city_value is Dictionary:
		return _reject_record("invalid save blocks")
	var snapshots: Dictionary = snapshots_value
	var snapshot_value: Variant = snapshots.get(replay_stage_id, null)
	if not snapshot_value is Dictionary:
		return _reject_record("replay snapshot is missing")
	var snapshot: Dictionary = snapshot_value
	var record_value: Variant = snapshot.get(
		&"operation_start_conditions",
		null
	)
	if not record_value is Dictionary:
		return _reject_record("replay carryover is missing")
	var record: Dictionary = record_value
	if not _valid_carryover_record(record):
		return _reject_record("replay carryover is invalid")

	var stored_record := _copy_record(record)
	var current_city_state: Dictionary = city_value.duplicate(true)
	current_city_state[&"operation_start_conditions"] = stored_record.duplicate(
		true
	)
	_game_state.set("current_city_state", current_city_state)
	_set_pending_application(
		from_stage_id,
		replay_stage_id,
		stored_record
	)
	print(
		"[CARRYOVER] restored replay stage=",
		replay_stage_id,
		" values=",
		stored_record
	)
	return stored_record


## Call only after all three values have reached their Table F1 runtime
## positions. runtime_values must be read back from the live network and city
## systems, not copied from operation_start_conditions. This method maps those
## live fields back to the stored record before publishing the lifecycle event.
func complete_runtime_application(
	from_stage_id: StringName,
	to_stage_id: StringName,
	runtime_values: Dictionary
) -> bool:
	if not _is_configured():
		return _reject_commit("not configured")
	if not _stage_exists(to_stage_id):
		return _reject_commit("destination stage is not configured")
	if (
		_pending_application_from_stage_id != from_stage_id
		or _pending_application_to_stage_id != to_stage_id
		or _pending_application_record.is_empty()
	):
		return _reject_commit("no matching runtime application is pending")
	var city_value: Variant = _game_state.get("current_city_state")
	if not city_value is Dictionary:
		return _reject_commit("invalid current city state")
	var current_city_state: Dictionary = city_value
	var expected_value: Variant = current_city_state.get(
		&"operation_start_conditions",
		null
	)
	if not expected_value is Dictionary:
		return _reject_commit("starting conditions are missing")
	var expected_record: Dictionary = expected_value
	if not _valid_carryover_record(expected_record):
		return _reject_commit("starting conditions are invalid")
	var stored_record := _runtime_values_to_record(runtime_values)
	if stored_record.is_empty():
		return _reject_commit("runtime application evidence is invalid")
	if _copy_record(expected_record) != stored_record:
		return _reject_commit("runtime values do not match starting conditions")
	if _pending_application_record != stored_record:
		return _reject_commit("runtime values do not match the pending record")
	_pending_application_from_stage_id = StringName()
	_pending_application_to_stage_id = StringName()
	_pending_application_record = {}
	_emit_event(
		&"carryover_applied",
		[from_stage_id, to_stage_id, stored_record.duplicate(true)]
	)
	print(
		"[CARRYOVER] runtime application completed from=",
		from_stage_id,
		" to=",
		to_stage_id,
		" values=",
		stored_record
	)
	return true


func summary_text(
	to_stage_id: StringName,
	record: Dictionary
) -> String:
	if not _valid_carryover_record(record):
		return ""
	var stage_label := String(to_stage_id).trim_prefix("stage_").capitalize()
	return "\n".join([
		"Network start: %s - %s reference for %s" % [
			_format_value(
				float(record[&"network_efficiency_coefficient"]),
				String(
					_read_balance(
						"carryover.summary.network_efficiency_format",
						""
					)
				)
			),
			_direction(
				float(record[&"network_efficiency_coefficient"]),
				float(
					_read_balance(
						"carryover.summary.network_efficiency.reference",
						0.0
					)
				)
			),
			stage_label,
		],
		"Operating pressure: %s - %s reference for %s" % [
			_format_value(
				float(record[&"initial_operation_pressure"]),
				String(
					_read_balance(
						"carryover.summary.operation_pressure_format",
						""
					)
				)
			),
			_direction(
				float(record[&"initial_operation_pressure"]),
				float(
					_read_balance(
						"carryover.summary.operation_pressure.reference",
						0.0
					)
				)
			),
			stage_label,
		],
		"Waste carried forward: %s - %s reference for %s" % [
			_format_value(
				float(record[&"initial_waste_accumulation"]),
				String(
					_read_balance(
						"carryover.summary.waste_format",
						""
					)
				)
			),
			_direction(
				float(record[&"initial_waste_accumulation"]),
				float(
					_read_balance(
						"carryover.summary.waste.reference",
						0.0
					)
				)
			),
			stage_label,
		],
	])


func _calculate_build_deltas(
	stage_id: StringName,
	records: Dictionary
) -> Dictionary:
	var required_value: Variant = _read_balance(
		"chapters.%s.required_build_decision_ids" % stage_id,
		[]
	)
	if not required_value is Array or required_value.is_empty():
		return {}
	var weighted_total := 0.0
	var weight_total := 0.0
	for decision_value in required_value:
		var decision_id := StringName(decision_value)
		var record_value: Variant = records.get(decision_id, null)
		if not record_value is Dictionary:
			return {}
		var record: Dictionary = record_value
		if StringName(record.get("decision_id", &"")) != decision_id:
			return {}
		if StringName(record.get("stage_id", &"")) != stage_id:
			return {}
		var option_id := StringName(
			record.get("selected_candidate_id", &"")
		)
		if option_id.is_empty():
			return {}
		var normalized_convenience := _normalized_build_convenience(
			decision_id,
			option_id
		)
		if is_nan(normalized_convenience):
			return {}
		var option_weight_value: Variant = _read_balance(
			"build_options.%s.%s.carryover.convenience_weight" % [
				decision_id,
				option_id,
			],
			null
		)
		var decision_weight_value: Variant = _read_balance(
			"build_options.carryover.decision_weights.%s" % decision_id,
			null
		)
		if (
			not _is_number(option_weight_value)
			or not _is_number(decision_weight_value)
		):
			return {}
		var option_weight := float(option_weight_value)
		var decision_weight := float(decision_weight_value)
		if option_weight < 0.0 or decision_weight <= 0.0:
			return {}
		var decision_convenience := (
			normalized_convenience * option_weight
		)
		weighted_total += decision_convenience * decision_weight
		weight_total += decision_weight
	if weight_total <= 0.0:
		return {}

	var stage_convenience := weighted_total / weight_total
	var normalized_max := float(
		_read_balance("build_options.normalized_max", 0.0)
	)
	return {
		&"network_efficiency_delta": (
			stage_convenience
			* float(
				_read_balance(
					"build_options.carryover.network_efficiency_factor",
					0.0
				)
			)
		),
		&"operation_pressure_delta": (
			normalized_max - stage_convenience
		) * float(
			_read_balance(
				"build_options.carryover.operation_pressure_factor",
				0.0
			)
		),
		&"waste_delta": (
			normalized_max - stage_convenience
		) * float(
			_read_balance(
				"build_options.carryover.waste_factor",
				0.0
			)
		),
	}


func _normalized_build_convenience(
	decision_id: StringName,
	option_id: StringName
) -> float:
	var value: Variant = _read_balance(
		"build_options.%s.%s.metrics.future_convenience" % [
			decision_id,
			option_id,
		],
		null
	)
	var range_value: Variant = _read_balance(
		"build_options.metric_ranges.future_convenience",
		[]
	)
	if not _is_number(value) or not _valid_range(range_value):
		return NAN
	var source_range: Array = range_value
	var minimum := float(source_range[0])
	var maximum := float(source_range[1])
	var normalized_min := float(
		_read_balance("build_options.normalized_min", 0.0)
	)
	var normalized_max := float(
		_read_balance("build_options.normalized_max", 0.0)
	)
	if normalized_max <= normalized_min:
		return NAN
	return clampf(
		remap(
			float(value),
			minimum,
			maximum,
			normalized_min,
			normalized_max
		),
		normalized_min,
		normalized_max
	)


func _valid_operation_settlement(settlement: Dictionary) -> bool:
	return (
		_valid_source_value(
			settlement,
			&"transport_coverage_settled",
			"carryover.network_efficiency.source_transport_coverage_range"
		)
		and _valid_source_value(
			settlement,
			&"transport_pressure_settled",
			"carryover.operation_pressure.source_transport_pressure_range"
		)
		and _valid_source_value(
			settlement,
			&"waste_settled",
			"carryover.waste.source_waste_range"
		)
	)


func _valid_source_value(
	settlement: Dictionary,
	field: StringName,
	range_path: String
) -> bool:
	var value: Variant = settlement.get(field, null)
	var range_value: Variant = _read_balance(range_path, [])
	if not _is_number(value) or not _valid_range(range_value):
		return false
	var configured_range: Array = range_value
	return (
		float(value) >= float(configured_range[0])
		and float(value) <= float(configured_range[1])
	)


func _calculate_output(
	group: StringName,
	build_delta: float,
	operation_value: float,
	source_range_key: String
) -> float:
	var prefix := "carryover.%s" % group
	var source_range: Array = _read_balance(
		"%s.%s" % [prefix, source_range_key],
		[]
	)
	var normalized_operation := _normalize_source(operation_value, source_range)
	var minimum := float(_read_balance("%s.range.min" % prefix, 0.0))
	var maximum := float(_read_balance("%s.range.max" % prefix, 0.0))
	return clampf(
		float(_read_balance("%s.base" % prefix, 0.0))
		+ float(
			_read_balance("%s.build_delta_weight" % prefix, 0.0)
		) * build_delta
		+ float(
			_read_balance("%s.operation_weight" % prefix, 0.0)
		) * normalized_operation,
		minimum,
		maximum
	)


func _normalize_source(value: float, source_range: Array) -> float:
	return inverse_lerp(
		float(source_range[0]),
		float(source_range[1]),
		value
	)


func _valid_carryover_record(record: Dictionary) -> bool:
	if record.size() != CARRYOVER_FIELDS.size():
		return false
	for field in CARRYOVER_FIELDS:
		if not _is_number(record.get(field, null)):
			return false
	return (
		_value_in_output_range(
			float(record[&"network_efficiency_coefficient"]),
			&"network_efficiency"
		)
		and _value_in_output_range(
			float(record[&"initial_operation_pressure"]),
			&"operation_pressure"
		)
		and _value_in_output_range(
			float(record[&"initial_waste_accumulation"]),
			&"waste"
		)
	)


func _value_in_output_range(value: float, group: StringName) -> bool:
	return (
		value >= float(
			_read_balance("carryover.%s.range.min" % group, INF)
		)
		and value <= float(
			_read_balance("carryover.%s.range.max" % group, -INF)
		)
	)


func _copy_record(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in CARRYOVER_FIELDS:
		result[field] = float(record[field])
	return result


func _runtime_values_to_record(runtime_values: Dictionary) -> Dictionary:
	for field in [
		&"network_efficiency_coefficient",
		&"transport_pressure",
		&"waste",
	]:
		if not _is_number(runtime_values.get(field, null)):
			return {}
	var record := {
		&"network_efficiency_coefficient": float(
			runtime_values[&"network_efficiency_coefficient"]
		),
		&"initial_operation_pressure": float(
			runtime_values[&"transport_pressure"]
		),
		&"initial_waste_accumulation": float(runtime_values[&"waste"]),
	}
	return record if _valid_carryover_record(record) else {}


func _set_pending_application(
	from_stage_id: StringName,
	to_stage_id: StringName,
	record: Dictionary
) -> void:
	_pending_application_from_stage_id = from_stage_id
	_pending_application_to_stage_id = to_stage_id
	_pending_application_record = _copy_record(record)


func _configured_next_stage(stage_id: StringName) -> StringName:
	var next_value: Variant = _read_balance(
		"chapters.%s.next_stage_id" % stage_id,
		null
	)
	if next_value == null:
		return StringName()
	return StringName(next_value)


func _stage_exists(stage_id: StringName) -> bool:
	var configured_id: Variant = _read_balance(
		"chapters.%s.id" % stage_id,
		null
	)
	return configured_id != null and StringName(configured_id) == stage_id


func _format_value(value: float, pattern: String) -> String:
	if pattern.is_empty():
		return String.num(value)
	var decimal_count := 0
	var decimal_index := pattern.find(".")
	if decimal_index >= 0:
		var cursor := decimal_index + 1
		while cursor < pattern.length() and pattern[cursor] == "0":
			decimal_count += 1
			cursor += 1
	var suffix_start := decimal_index + decimal_count + 1
	if decimal_index < 0:
		suffix_start = 1
	var suffix := pattern.substr(suffix_start)
	return String.num(value, decimal_count) + suffix


func _direction(value: float, reference: float) -> String:
	if is_equal_approx(value, reference):
		return "at"
	return "above" if value > reference else "below"


func _valid_range(value: Variant) -> bool:
	return (
		value is Array
		and value.size() == 2
		and _is_number(value[0])
		and _is_number(value[1])
		and float(value[1]) > float(value[0])
	)


func _is_number(value: Variant) -> bool:
	return value is float or value is int


func _is_configured() -> bool:
	return (
		_balance_access != null
		and _event_bus != null
		and _game_state != null
	)


func _emit_event(event_name: StringName, arguments: Array) -> void:
	if not _event_bus.has_signal(event_name):
		return
	_event_bus.callv("emit_signal", [event_name] + arguments)


func _read_balance(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)


func _reject_record(reason: String) -> Dictionary:
	push_warning("[CARRYOVER] Rejected: %s." % reason)
	return {}


func _reject_commit(reason: String) -> bool:
	push_warning("[CARRYOVER] Rejected: %s." % reason)
	return false
