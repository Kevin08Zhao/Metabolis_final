class_name OrganCheck
extends RefCounted

## Checks whether a completed organ can operate and records one E10
## cooperation observation without owning any animation.
##
## A failed operational check reports one of three distinct primary reasons:
## transport_coverage_insufficient, upstream_resources_insufficient, or
## dependency_organs_inactive. Once operational, the E10 runtime-transfer,
## metric-change, modal, path, and archive conditions decide whether observation
## can start.
##
## Each observation record contains:
## observation_id, build_decision_id, organ_id, stage_id,
## participant_organ_ids, resource_path_edge_ids, archive_entry_id,
## runtime_transfer_observed, metric_change_observed, and completed.

const ORGAN_ID_BY_DECISION: Dictionary = {
	&"build_cell_cluster": &"cell_cluster",
	&"build_placenta_port": &"placenta_port",
	&"build_germ_layer_districts": &"germ_layer_districts",
	&"build_heart_pump": &"heart_pump",
	&"build_neural_network": &"neural_network",
	&"build_lung_exchange": &"lung_exchange",
	&"build_pulmonary_interface": &"pulmonary_interface",
}
const REQUIRED_PARTNER_IDS_BY_DECISION: Dictionary = {
	&"build_cell_cluster": [],
	&"build_placenta_port": [&"cell_cluster"],
	&"build_germ_layer_districts": [&"placenta_port"],
	&"build_heart_pump": [&"placenta_port"],
	&"build_neural_network": [&"germ_layer_districts"],
	&"build_lung_exchange": [&"heart_pump", &"neural_network"],
	&"build_pulmonary_interface": [&"heart_pump", &"lung_exchange"],
}
const OPERATING_STATE := &"operating"

var observation_records: Dictionary:
	get:
		return _observation_records.duplicate(true)

var observation_in_progress: bool:
	get:
		return not _active_observation_id.is_empty()

var _balance_access: Node
var _event_bus: Node
var _observation_records: Dictionary = {}
var _active_observation_id := StringName()
var _active_decision_id := StringName()


func configure(balance_access: Node, event_bus: Node) -> void:
	_balance_access = balance_access
	_event_bus = event_bus


func check_and_observe(
	build_decision_id: StringName,
	stage_id: StringName,
	context: Dictionary
) -> Dictionary:
	if not _is_configured():
		return _failure(&"not_configured")
	if not ORGAN_ID_BY_DECISION.has(build_decision_id):
		return _failure(&"unknown_build_decision")
	if _observation_records.has(build_decision_id):
		return {
			"operational": true,
			"failure_reason": StringName(),
			"observation_started": false,
			"observation_status": &"already_recorded",
			"observation": (
				_observation_records[build_decision_id] as Dictionary
			).duplicate(true),
		}

	var organ_id := StringName(ORGAN_ID_BY_DECISION[build_decision_id])
	var organ_states: Dictionary = context.get("organ_states", {})
	var active_organ_ids := _to_string_name_array(
		context.get("active_organ_ids", [])
	)
	var coverage_by_organ: Dictionary = context.get(
		"organ_transport_coverage",
		{}
	)
	var upstream_sufficiency: Dictionary = context.get(
		"upstream_resources_sufficient_by_organ",
		{}
	)
	var runtime_transfer: Dictionary = context.get(
		"observed_runtime_transfer",
		{}
	)
	var metric_change: Dictionary = context.get(
		"observed_metric_change",
		{}
	)

	if (
		StringName(organ_states.get(organ_id, &""))
		!= OPERATING_STATE
	):
		return _failure(
			&"dependency_organs_inactive",
			organ_id,
			{"inactive_organ_ids": [organ_id]}
		)
	var coverage := float(coverage_by_organ.get(organ_id, 0.0))
	var coverage_threshold := float(
		_read_balance(
			(
				"operations.bottlenecks.transport_pressure."
				+ "organ_coverage_recover"
			),
			0.0
		)
	)
	if coverage < coverage_threshold:
		return _failure(
			&"transport_coverage_insufficient",
			organ_id,
			{
				"current_coverage": coverage,
				"required_coverage": coverage_threshold,
				"gap": coverage_threshold - coverage,
			}
		)
	if not bool(upstream_sufficiency.get(organ_id, false)):
		return _failure(
			&"upstream_resources_insufficient",
			organ_id
		)

	var required_partners := _required_partner_ids(build_decision_id)
	var inactive_partners: Array[StringName] = []
	for partner_id in required_partners:
		if (
			not active_organ_ids.has(partner_id)
			or StringName(organ_states.get(partner_id, &""))
			!= OPERATING_STATE
		):
			inactive_partners.append(partner_id)
	if not inactive_partners.is_empty():
		return _failure(
			&"dependency_organs_inactive",
			organ_id,
			{"inactive_organ_ids": inactive_partners}
		)

	if not bool(runtime_transfer.get(organ_id, false)):
		return _waiting(organ_id, &"waiting_for_runtime_transfer")
	if not bool(metric_change.get(organ_id, false)):
		return _waiting(organ_id, &"waiting_for_metric_change")
	if bool(context.get("blocking_modal_open", false)):
		return _waiting(organ_id, &"blocking_modal_open")

	var path_ids := _to_string_name_array(
		context.get("resource_path_edge_ids", [])
	)
	if path_ids.is_empty():
		return _waiting(organ_id, &"waiting_for_concrete_resource_path")
	var archive_entry_id := StringName(
		context.get("archive_entry_id", &"")
	)
	if archive_entry_id.is_empty():
		return _waiting(organ_id, &"waiting_for_archive_entry_id")

	var participant_ids := required_partners.duplicate()
	if not participant_ids.has(organ_id):
		participant_ids.append(organ_id)
	var observation_id := StringName("observe_%s" % organ_id)
	var observation := {
		"observation_id": observation_id,
		"build_decision_id": build_decision_id,
		"organ_id": organ_id,
		"stage_id": stage_id,
		"participant_organ_ids": participant_ids,
		"resource_path_edge_ids": path_ids,
		"archive_entry_id": archive_entry_id,
		"runtime_transfer_observed": true,
		"metric_change_observed": true,
		"completed": false,
	}
	_observation_records[build_decision_id] = observation
	_active_observation_id = observation_id
	_active_decision_id = build_decision_id
	_emit_event(
		&"system_observation_started",
		[organ_id, observation_id]
	)
	print(
		"[ORGAN CHECK] observation started organ=",
		organ_id,
		" participants=",
		participant_ids,
		" path=",
		path_ids
	)
	return {
		"operational": true,
		"failure_reason": StringName(),
		"observation_started": true,
		"observation_status": &"in_progress",
		"observation": observation.duplicate(true),
	}


func complete_observation() -> bool:
	if _active_observation_id.is_empty():
		return false
	var observation: Dictionary = _observation_records[
		_active_decision_id
	]
	observation["completed"] = true
	_observation_records[_active_decision_id] = observation
	_emit_event(
		&"system_observation_ended",
		[
			StringName(observation["organ_id"]),
			_active_observation_id,
		]
	)
	print(
		"[ORGAN CHECK] observation completed organ=",
		observation["organ_id"],
		" observation=",
		_active_observation_id
	)
	_active_observation_id = StringName()
	_active_decision_id = StringName()
	return true


func can_advance() -> bool:
	return _active_observation_id.is_empty()


func restore_observation_records(records: Dictionary) -> void:
	_observation_records = records.duplicate(true)
	_active_observation_id = StringName()
	_active_decision_id = StringName()


func _failure(
	reason: StringName,
	organ_id: StringName = &"",
	details: Dictionary = {}
) -> Dictionary:
	print(
		"[ORGAN CHECK] not operational organ=",
		organ_id,
		" reason=",
		reason,
		" details=",
		details
	)
	return {
		"operational": false,
		"failure_reason": reason,
		"failure_details": details.duplicate(true),
		"observation_started": false,
		"observation_status": &"not_ready",
		"observation": {},
	}


func _waiting(organ_id: StringName, status: StringName) -> Dictionary:
	print(
		"[ORGAN CHECK] operational organ=",
		organ_id,
		" observation_status=",
		status
	)
	return {
		"operational": true,
		"failure_reason": StringName(),
		"observation_started": false,
		"observation_status": status,
		"observation": {},
	}


func _required_partner_ids(
	build_decision_id: StringName
) -> Array[StringName]:
	return _to_string_name_array(
		REQUIRED_PARTNER_IDS_BY_DECISION.get(build_decision_id, [])
	)


func _is_configured() -> bool:
	return _balance_access != null and _event_bus != null


func _emit_event(event_name: StringName, arguments: Array) -> void:
	if not _event_bus.has_signal(event_name):
		return
	_event_bus.callv("emit_signal", [event_name] + arguments)


func _read_balance(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for item in value:
		result.append(StringName(item))
	return result
