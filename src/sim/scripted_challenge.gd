class_name ScriptedChallenge
extends RefCounted

## Injects each configured teaching challenge at most once.
##
## The caller owns runtime state and supplies one atomic apply-and-detect
## transaction. That transaction applies the returned Balance values, invokes
## BottleneckDetector, and returns true only after the canonical E7 appearance
## event and marker data exist. This class never creates a fourth bottleneck,
## chooses a random target, or implements visuals.
## The E7 integration must call record_bottleneck_appearance for every detector
## appearance and pass its source; scripted appearances are never learned as
## natural. Resolution likewise uses one clear-and-detect transaction. Snapshot
## export is rejected while either external transaction is in flight.
##
## Manual acceptance:
## - Enter each configured stable trigger with no natural history. The selected
##   target is deterministic, [CHALLENGE] reports injection, and the normal E7
##   marker appears through the callback.
## - First call record_bottleneck_appearance with a non-scripted source for the
##   matching E7 ID. At the trigger, no runtime value changes; the challenge
##   enters skipped_ids and [CHALLENGE] reports already_learned_naturally.
## - Enter stage_birth. No challenge is selected or injected.

const VALID_BOTTLENECK_IDS: Array[StringName] = [
	&"transport_pressure",
	&"waste_accumulation",
	&"signal_coverage_low",
]

const OPERATION_BY_CHALLENGE := {
	&"transport_pressure_intro": &"operate_cleavage_allocation",
	&"waste_accumulation_intro": &"operate_placental_transport",
	&"signal_coverage_intro": &"operate_circulation_signal_priority",
}
const STAGE_BY_CHALLENGE := {
	&"transport_pressure_intro": &"stage_origin",
	&"waste_accumulation_intro": &"stage_harbor",
	&"signal_coverage_intro": &"stage_circulation",
}
const BOTTLENECK_BY_CHALLENGE := {
	&"transport_pressure_intro": &"transport_pressure",
	&"waste_accumulation_intro": &"waste_accumulation",
	&"signal_coverage_intro": &"signal_coverage_low",
}

var challenge_history: Dictionary:
	get:
		if _transaction_active():
			return {}
		return _history.duplicate(true)

var _balance_access: Node
var _in_flight_challenges: Dictionary = {}
var _in_flight_stages: Dictionary = {}
var _resolving_challenges: Dictionary = {}
var _history := {
	"injected_ids": [],
	"resolved_ids": [],
	"skipped_ids": [],
	"skip_reasons": {},
	"natural_bottlenecks_seen": [],
	"injected_by_stage": {},
	"records": {},
}


func configure(balance_access: Node) -> void:
	_balance_access = balance_access


func record_bottleneck_appearance(
	bottleneck_id: StringName,
	source: StringName
) -> void:
	if (
		source != &"scripted_challenge"
		and VALID_BOTTLENECK_IDS.has(bottleneck_id)
		and not _id_array("natural_bottlenecks_seen").has(bottleneck_id)
	):
		_history["natural_bottlenecks_seen"].append(bottleneck_id)
		var challenge_id := _challenge_for_bottleneck(bottleneck_id)
		if (
			not challenge_id.is_empty()
			and not _id_array("injected_ids").has(challenge_id)
			and not _id_array("resolved_ids").has(challenge_id)
			and not _id_array("skipped_ids").has(challenge_id)
			and not _in_flight_challenges.has(challenge_id)
		):
			_skip(challenge_id, &"already_learned_naturally")


func try_inject(
	stage_id: StringName,
	context: Dictionary,
	apply_and_detect: Callable
) -> Dictionary:
	if _balance_access == null or not apply_and_detect.is_valid():
		return {}
	if stage_id == &"stage_birth":
		print("[CHALLENGE] stage_birth has no scripted challenge.")
		return {}
	var challenge_id := _challenge_for_stage(stage_id)
	if challenge_id.is_empty():
		return {}
	var bottleneck_id := StringName(
		_read("challenges.%s.bottleneck_id" % challenge_id, "")
	)
	if (
		not VALID_BOTTLENECK_IDS.has(bottleneck_id)
		or bottleneck_id != BOTTLENECK_BY_CHALLENGE.get(challenge_id, &"")
		or stage_id != STAGE_BY_CHALLENGE.get(challenge_id, &"")
	):
		push_warning("[CHALLENGE] Invalid configured challenge contract.")
		return {}
	if (
		_id_array("resolved_ids").has(challenge_id)
		or _id_array("skipped_ids").has(challenge_id)
		or _id_array("injected_ids").has(challenge_id)
		or _in_flight_challenges.has(challenge_id)
		or _in_flight_stages.has(stage_id)
	):
		return {}
	if _id_array("natural_bottlenecks_seen").has(bottleneck_id):
		_skip(challenge_id, &"already_learned_naturally")
		return {}
	if not _eligible(challenge_id, stage_id, context):
		return {}
	var target := _select_target(challenge_id, context)
	if target.is_empty():
		print("[CHALLENGE] skipped %s: no deterministic target." % challenge_id)
		return {}
	var intensity := _intensity(challenge_id)
	_in_flight_challenges[challenge_id] = true
	_in_flight_stages[stage_id] = true
	var transaction_result: Variant = apply_and_detect.call(
		challenge_id,
		bottleneck_id,
		target.duplicate(true),
		intensity.duplicate(true)
	)
	_in_flight_challenges.erase(challenge_id)
	_in_flight_stages.erase(stage_id)
	if transaction_result != true:
		print("[CHALLENGE] injection transaction failed for %s." % challenge_id)
		return {}
	var record := {
		"challenge_id": challenge_id,
		"stage_id": stage_id,
		"bottleneck_id": bottleneck_id,
		"target": target,
		"intensity": intensity,
		"source": &"scripted_challenge",
	}
	_history["injected_ids"].append(challenge_id)
	_history["injected_by_stage"][stage_id] = challenge_id
	_history["records"][challenge_id] = record.duplicate(true)
	print(
		"[CHALLENGE] injected %s bottleneck=%s target=%s"
		% [challenge_id, bottleneck_id, target]
	)
	return record


func try_mark_resolved(
	challenge_id: StringName,
	clear_and_detect: Callable
) -> bool:
	if (
		not _id_array("injected_ids").has(challenge_id)
		or _id_array("resolved_ids").has(challenge_id)
		or _resolving_challenges.has(challenge_id)
		or not clear_and_detect.is_valid()
	):
		return false
	var record: Dictionary = _history["records"].get(challenge_id, {})
	var bottleneck_id := StringName(record.get("bottleneck_id", ""))
	if bottleneck_id != BOTTLENECK_BY_CHALLENGE.get(challenge_id, &""):
		return false
	_resolving_challenges[challenge_id] = true
	var result: Variant = clear_and_detect.call(
		challenge_id,
		bottleneck_id,
		record.duplicate(true)
	)
	_resolving_challenges.erase(challenge_id)
	if not result is Dictionary:
		return false
	var recovery: Dictionary = result
	if (
		StringName(recovery.get("bottleneck_id", "")) != bottleneck_id
		or not bool(recovery.get("e7_recovery_complete", false))
		or bool(recovery.get("scripted_effect_active", true))
	):
		return false
	if (
		challenge_id == &"signal_coverage_intro"
		and not bool(
			recovery.get("all_required_neural_targets_recovered", false)
		)
	):
		return false
	_history["resolved_ids"].append(challenge_id)
	return true


func snapshot_state() -> Dictionary:
	if _transaction_active():
		push_warning(
			"[CHALLENGE] Snapshot rejected during an active transaction."
		)
		return {}
	return _history.duplicate(true)


func restore_state(state: Dictionary) -> void:
	if _transaction_active():
		push_warning(
			"[CHALLENGE] Restore rejected during an active transaction."
		)
		return
	for key in _history:
		if not state.has(key):
			push_warning("[CHALLENGE] Incomplete snapshot rejected.")
			return
	_history = state.duplicate(true)


func _transaction_active() -> bool:
	return (
		not _in_flight_challenges.is_empty()
		or not _resolving_challenges.is_empty()
	)


func _eligible(
	challenge_id: StringName,
	stage_id: StringName,
	context: Dictionary
) -> bool:
	if not _enabled_ids().has(challenge_id):
		return false
	if StringName(_read("challenges.%s.stage_id" % challenge_id, "")) != stage_id:
		return false
	if (
		_id_array("resolved_ids").has(challenge_id)
		or _id_array("skipped_ids").has(challenge_id)
		or _id_array("injected_ids").has(challenge_id)
	):
		return false
	if bool(context.get("blocking_modal_open", false)):
		return false
	if not bool(
		context.get("stable_trigger_ready_by_challenge", {}).get(
			challenge_id,
			false
		)
	):
		return false
	if not bool(
		context.get("required_systems_active_by_challenge", {}).get(
			challenge_id,
			false
		)
	):
		return false
	var operation_id := StringName(OPERATION_BY_CHALLENGE.get(challenge_id, ""))
	if context.get("confirmed_operation_decision_ids", []).has(operation_id):
		return false
	if _history["injected_by_stage"].has(stage_id):
		return false
	if (
		_in_flight_challenges.has(challenge_id)
		or _in_flight_stages.has(stage_id)
	):
		return false
	if _id_array("injected_ids").size() >= _max_total():
		return false
	return _max_per_stage() > 0


func _challenge_for_stage(stage_id: StringName) -> StringName:
	for challenge_id in _enabled_ids():
		if StringName(
			_read("challenges.%s.stage_id" % challenge_id, "")
		) == stage_id:
			return challenge_id
	return &""


func _challenge_for_bottleneck(bottleneck_id: StringName) -> StringName:
	for challenge_id: Variant in BOTTLENECK_BY_CHALLENGE:
		if BOTTLENECK_BY_CHALLENGE[challenge_id] == bottleneck_id:
			return StringName(challenge_id)
	return &""


func _select_target(
	challenge_id: StringName,
	context: Dictionary
) -> Dictionary:
	match challenge_id:
		&"transport_pressure_intro":
			return _highest_edge_utilization(
				context.get("active_mutable_edges", []),
				context.get("edge_flow_by_id", {})
			)
		&"waste_accumulation_intro":
			return _highest_organ_net_waste(
				context.get("active_organ_ids", []),
				context.get("organ_waste_generation", {}),
				context.get("organ_waste_processing", {})
			)
		&"signal_coverage_intro":
			return _lowest_neural_signal_ratio(
				context.get("required_neural_organ_ids", []),
				context.get("delivered_signal_by_organ", {}),
				context.get("required_signal_by_organ", {})
			)
	return {}


func _intensity(challenge_id: StringName) -> Dictionary:
	match challenge_id:
		&"transport_pressure_intro":
			return {
				"capacity_multiplier": _number(challenge_id, "capacity_multiplier"),
				"pressure_target": _number(challenge_id, "pressure_target"),
				"max_recovery_ticks": _count(challenge_id, "max_recovery_ticks"),
			}
		&"waste_accumulation_intro":
			return {
				"waste_delta": _number(challenge_id, "waste_delta"),
				"processing_multiplier": _number(challenge_id, "processing_multiplier"),
				"maximum_self_recoverable_delta": _number(
					challenge_id,
					"maximum_self_recoverable_delta"
				),
				"max_recovery_ticks": _count(challenge_id, "max_recovery_ticks"),
			}
		&"signal_coverage_intro":
			return {
				"delivery_multiplier": _number(challenge_id, "delivery_multiplier"),
				"coverage_target": _number(challenge_id, "coverage_target"),
				"max_recovery_ticks": _count(challenge_id, "max_recovery_ticks"),
			}
	return {}


func _highest_edge_utilization(edges: Array, flows: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_value := -INF
	for edge: Variant in edges:
		if not edge is Dictionary:
			continue
		var edge_id := StringName(edge.get("edge_id", ""))
		var capacity := float(edge.get("effective_capacity", 0.0))
		if edge_id.is_empty() or capacity <= 0.0:
			continue
		var value := float(flows.get(edge_id, 0.0)) / capacity
		if value > best_value or (
			is_equal_approx(value, best_value)
			and String(edge_id) < String(best.get("edge_id", ""))
		):
			best = {"edge_id": edge_id, "utilization": value}
			best_value = value
	return best


func _highest_organ_net_waste(
	organ_ids: Array,
	generation: Dictionary,
	processing: Dictionary
) -> Dictionary:
	var values: Dictionary = {}
	for value: Variant in organ_ids:
		var organ_id := StringName(value)
		values[organ_id] = (
			float(generation.get(organ_id, 0.0))
			- float(processing.get(organ_id, 0.0))
		)
	return _extreme_organ(values, false)


func _lowest_neural_signal_ratio(
	organ_ids: Array,
	delivered: Dictionary,
	required: Dictionary
) -> Dictionary:
	var values: Dictionary = {}
	for value: Variant in organ_ids:
		var organ_id := StringName(value)
		var required_value := float(required.get(organ_id, 0.0))
		if required_value > 0.0:
			values[organ_id] = (
				float(delivered.get(organ_id, 0.0)) / required_value
			)
	return _extreme_organ(values, true)


func _extreme_organ(values: Dictionary, lowest: bool) -> Dictionary:
	var result := &""
	var best := INF if lowest else -INF
	for key: Variant in values:
		var value := float(values[key])
		var better := value < best if lowest else value > best
		if better or (
			is_equal_approx(value, best)
			and String(key) < String(result)
		):
			result = StringName(key)
			best = value
	return {} if result.is_empty() else {"organ_id": result, "value": best}


func _skip(challenge_id: StringName, reason: StringName) -> void:
	if not _id_array("skipped_ids").has(challenge_id):
		_history["skipped_ids"].append(challenge_id)
	_history["skip_reasons"][challenge_id] = reason
	print("[CHALLENGE] skipped %s: %s." % [challenge_id, reason])


func _enabled_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var value: Variant = _read("challenges.enabled_ids", [])
	if value is Array:
		for item: Variant in value:
			result.append(StringName(item))
	return result


func _id_array(key: String) -> Array:
	var value: Variant = _history.get(key, [])
	return value if value is Array else []


func _max_per_stage() -> int:
	return mini(int(_read("challenges.max_injections_per_stage", 0)), 1)


func _max_total() -> int:
	return mini(int(_read("challenges.max_injections_total", 0)), 3)


func _number(challenge_id: StringName, key: String) -> float:
	return float(_read("challenges.%s.%s" % [challenge_id, key], 0.0))


func _count(challenge_id: StringName, key: String) -> int:
	return int(_read("challenges.%s.%s" % [challenge_id, key], 0))


func _read(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)
