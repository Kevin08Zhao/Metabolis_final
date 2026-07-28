class_name BirthCheck
extends RefCounted

## Evaluates the four fixed E5 checks without blocking a failed attempt.
##
## Call check with transport_coverage, waste, stability, and either a current
## birth_readiness value or the signal_coverage and pulmonary_system_readiness
## inputs used by the E5 formula. The returned report always contains all four
## checks on one list so the UI can show them together.
##
## Manual acceptance:
## 1. Pass the Balance zero-reward baseline values: transport coverage 0.8,
##    waste 45, stability 70, and birth readiness 0.78.
## 2. Confirm that all four checks pass, birth_transition_unlocked becomes true,
##    and hint_birth_transition emits through knowledge_entry_unlocked once.
## 3. Lower every metric beyond its threshold. Confirm that every failed row
##    includes a positive gap and recovery direction and retry_allowed is true.

const HINT_ID := &"hint_birth_transition"
const HINT_ORGAN_ID := &"pulmonary_interface"
const BIRTH_STAGE_ID := &"stage_birth"

var last_report: Dictionary:
	get:
		return _last_report.duplicate(true)

var birth_transition_unlocked: bool:
	get:
		return _birth_transition_unlocked

var birth_hint_emitted: bool:
	get:
		return _birth_hint_emitted

var _balance_access: Node
var _event_bus: Node
var _last_report: Dictionary = {}
var _birth_transition_unlocked := false
var _birth_hint_emitted := false


func configure(balance_access: Node, event_bus: Node) -> void:
	_balance_access = balance_access
	_event_bus = event_bus


func check(
	metrics: Dictionary,
	birth_transition_complete: bool = false
) -> Dictionary:
	if not _is_configured():
		return _invalid_report(&"not_configured")
	if not _has_required_metrics(metrics):
		return _invalid_report(&"missing_metric")

	var current_values := {
		&"transport_coverage": float(metrics[&"transport_coverage"]),
		&"waste": float(metrics[&"waste"]),
		&"stability": float(metrics[&"stability"]),
		&"birth_readiness": _birth_readiness(metrics),
	}
	var checks: Array[Dictionary] = [
		_minimum_check(
			&"transport_coverage",
			current_values[&"transport_coverage"],
			float(
				_read_balance(
					"operations.birth_check.transport_coverage_min",
					0.0
				)
			),
			&"increase_transport_capacity_or_choose_transport_priority"
		),
		_maximum_check(
			&"waste",
			current_values[&"waste"],
			float(
				_read_balance(
					"operations.birth_check.waste_max",
					0.0
				)
			),
			&"increase_waste_priority_and_wait_for_processing"
		),
		_minimum_check(
			&"stability",
			current_values[&"stability"],
			float(
				_read_balance(
					"operations.birth_check.stability_min",
					0.0
				)
			),
			&"resolve_bottlenecks_and_wait_for_recovery"
		),
		_minimum_check(
			&"birth_readiness",
			current_values[&"birth_readiness"],
			float(
				_read_balance(
					"operations.birth_check.birth_readiness_min",
					0.0
				)
			),
			&"support_lung_exchange_and_pulmonary_interface"
		),
	]
	var passed := true
	for check_result in checks:
		if not bool(check_result["passed"]):
			passed = false
			break

	if passed:
		_birth_transition_unlocked = true
		if not birth_transition_complete and not _birth_hint_emitted:
			_birth_hint_emitted = _emit_event(
				&"knowledge_entry_unlocked",
				[HINT_ID, HINT_ORGAN_ID, BIRTH_STAGE_ID]
			)

	_last_report = {
		"passed": passed,
		"retry_allowed": not passed,
		"birth_transition_unlocked": _birth_transition_unlocked,
		"birth_hint_emitted": _birth_hint_emitted,
		"current_values": current_values.duplicate(true),
		"checks": checks.duplicate(true),
	}
	print(
		"[BIRTH CHECK] values=",
		current_values,
		" passed=",
		passed,
		" retry_allowed=",
		not passed
	)
	return last_report


func restore_state(
	transition_unlocked: bool,
	hint_emitted: bool,
	report: Dictionary = {}
) -> void:
	_birth_transition_unlocked = transition_unlocked
	_birth_hint_emitted = hint_emitted
	_last_report = report.duplicate(true)


func run_baseline_acceptance() -> Dictionary:
	if not _is_configured():
		return _invalid_report(&"not_configured")
	return check({
		&"transport_coverage": float(
			_read_balance(
				"operations.validation.baseline_build.transport_coverage",
				0.0
			)
		),
		&"waste": float(
			_read_balance(
				"operations.validation.baseline_build.waste_steady_state",
				0.0
			)
		),
		&"stability": float(
			_read_balance(
				"operations.validation.baseline_build.stability_equilibrium",
				0.0
			)
		),
		&"birth_readiness": float(
			_read_balance(
				"operations.validation.baseline_build.birth_readiness",
				0.0
			)
		),
	})


func _birth_readiness(metrics: Dictionary) -> float:
	if metrics.has(&"birth_readiness"):
		return float(metrics[&"birth_readiness"])
	var weighted_value := (
		float(
			_read_balance(
				"operations.birth_check.weights.transport",
				0.0
			)
		)
		* float(metrics[&"transport_coverage"])
		+ float(
			_read_balance(
				"operations.birth_check.weights.signal",
				0.0
			)
		)
		* float(metrics[&"signal_coverage"])
		+ float(
			_read_balance(
				"operations.birth_check.weights.pulmonary",
				0.0
			)
		)
		* float(metrics[&"pulmonary_system_readiness"])
	)
	return clampf(
		weighted_value,
		float(
			_read_balance("operations.birth_check.range.min", 0.0)
		),
		float(
			_read_balance("operations.birth_check.range.max", 1.0)
		)
	)


func _minimum_check(
	check_id: StringName,
	current_value: float,
	threshold: float,
	recovery_direction: StringName
) -> Dictionary:
	var passed := (
		current_value > threshold
		or is_equal_approx(current_value, threshold)
	)
	return {
		"check_id": check_id,
		"current_value": current_value,
		"threshold": threshold,
		"comparison": &"minimum",
		"passed": passed,
		"gap": maxf(threshold - current_value, 0.0),
		"recovery_direction": recovery_direction,
	}


func _maximum_check(
	check_id: StringName,
	current_value: float,
	threshold: float,
	recovery_direction: StringName
) -> Dictionary:
	var passed := (
		current_value < threshold
		or is_equal_approx(current_value, threshold)
	)
	return {
		"check_id": check_id,
		"current_value": current_value,
		"threshold": threshold,
		"comparison": &"maximum",
		"passed": passed,
		"gap": maxf(current_value - threshold, 0.0),
		"recovery_direction": recovery_direction,
	}


func _has_required_metrics(metrics: Dictionary) -> bool:
	for metric_id in [&"transport_coverage", &"waste", &"stability"]:
		if not _is_number(metrics.get(metric_id, null)):
			return false
	if _is_number(metrics.get(&"birth_readiness", null)):
		return true
	return (
		_is_number(metrics.get(&"signal_coverage", null))
		and _is_number(
			metrics.get(&"pulmonary_system_readiness", null)
		)
	)


func _invalid_report(reason: StringName) -> Dictionary:
	_last_report = {
		"passed": false,
		"retry_allowed": true,
		"birth_transition_unlocked": _birth_transition_unlocked,
		"birth_hint_emitted": _birth_hint_emitted,
		"current_values": {},
		"checks": [],
		"reason": reason,
	}
	return last_report


func _is_configured() -> bool:
	return _balance_access != null and _event_bus != null


func _is_number(value: Variant) -> bool:
	return value is float or value is int


func _emit_event(event_name: StringName, arguments: Array) -> bool:
	if not _event_bus.has_signal(event_name):
		return false
	_event_bus.callv("emit_signal", [event_name] + arguments)
	return true


func _read_balance(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)
