class_name ThresholdWatcher
extends RefCounted

## Watches the three independent E4 threshold categories.
##
## Stability uses hysteresis and emits stability_band_changed only when the
## band changes. Waste overflow and each resource shortage use simple two-state
## latches. EVENT_API defines no waste-overflow recovery event, so recovery
## silently rearms waste_overflowed for the next overflow episode.

enum StabilityBand {
	STABLE,
	STRAINED,
	CRITICAL,
}

const INVESTABLE_RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]
const REQUIRED_EVENT_NAMES: Array[StringName] = [
	&"stability_band_changed",
	&"waste_overflowed",
	&"resource_shortage_raised",
	&"resource_shortage_cleared",
]

var stability_band: StabilityBand:
	get:
		return _stability_band

var waste_overflow_active: bool:
	get:
		return _waste_overflow_active

var resource_shortages: Dictionary:
	get:
		return _resource_shortages.duplicate(true)

var _balance_access: Node
var _event_bus: Node
var _initialized := false
var _stability_band := StabilityBand.STABLE
var _waste_overflow_active := false
var _resource_shortages: Dictionary = {}


func configure(balance_access: Node, event_bus: Node) -> void:
	_balance_access = balance_access
	_event_bus = event_bus
	_initialized = false
	for event_name in REQUIRED_EVENT_NAMES:
		if _event_bus == null or not _event_bus.has_signal(event_name):
			push_warning(
				"[THRESHOLD] Event bus is missing '%s'." % event_name
			)


func initialize(resource_values: Dictionary) -> bool:
	if not _dependencies_are_ready():
		return false
	if not _has_required_values(resource_values):
		push_warning("[THRESHOLD] Initialization is missing resource values.")
		return false
	var stability := float(resource_values[&"stability"])
	_stability_band = _initial_stability_band(stability)
	_waste_overflow_active = (
		float(resource_values[&"waste"])
		>= float(_read_balance("resources.waste.max", INF))
	)
	_resource_shortages = {}
	for resource_id in INVESTABLE_RESOURCE_IDS:
		_resource_shortages[resource_id] = (
			float(resource_values[resource_id])
			< _resource_shortage_threshold(resource_id)
		)
	_initialized = true
	return true


func watch(resource_values: Dictionary) -> Array[Dictionary]:
	var emitted_events: Array[Dictionary] = []
	if not _dependencies_are_ready():
		return emitted_events
	if not _initialized:
		initialize(resource_values)
		return emitted_events
	if not _has_required_values(resource_values):
		push_warning("[THRESHOLD] Tick is missing resource values.")
		return emitted_events

	_watch_stability(float(resource_values[&"stability"]), emitted_events)
	_watch_waste(float(resource_values[&"waste"]), emitted_events)
	for resource_id in INVESTABLE_RESOURCE_IDS:
		_watch_resource_shortage(
			resource_id,
			float(resource_values[resource_id]),
			emitted_events
		)
	return emitted_events


func run_acceptance_test() -> Array[Dictionary]:
	if not _dependencies_are_ready():
		return []
	var values := {
		&"stability": float(
			_read_balance("resources.stability.initial", 0.0)
		),
		&"waste": float(_read_balance("resources.waste.initial", 0.0)),
		&"nutrient_energy": float(
			_read_balance("resources.nutrient_energy.initial", 0.0)
		),
		&"cell_material": float(
			_read_balance("resources.cell_material.initial", 0.0)
		),
		&"development_signal": float(
			_read_balance("resources.development_signal.initial", 0.0)
		),
	}
	initialize(values)
	var all_events: Array[Dictionary] = []
	var stability_samples: Array[float] = [
		float(_read_balance("thresholds.stability.stable_exit", 0.0)) - 1.0,
		float(_read_balance("thresholds.stability.critical_enter", 0.0)) - 1.0,
		float(_read_balance("thresholds.stability.critical_recover", 0.0)) + 1.0,
		float(_read_balance("thresholds.stability.strained_recover", 0.0)) + 1.0,
	]
	for stability in stability_samples:
		values[&"stability"] = stability
		all_events.append_array(watch(values))
		all_events.append_array(watch(values))

	values[&"waste"] = float(_read_balance("resources.waste.max", INF))
	all_events.append_array(watch(values))
	all_events.append_array(watch(values))
	values[&"waste"] = float(_read_balance("resources.waste.max", INF)) - 1.0
	all_events.append_array(watch(values))

	for resource_id in INVESTABLE_RESOURCE_IDS:
		var threshold := _resource_shortage_threshold(resource_id)
		values[resource_id] = threshold - 1.0
		all_events.append_array(watch(values))
		all_events.append_array(watch(values))
		values[resource_id] = threshold
		all_events.append_array(watch(values))

	for event in all_events:
		print("[THRESHOLD TEST] ", event)
	return all_events


func _watch_stability(
	stability: float,
	emitted_events: Array[Dictionary]
) -> void:
	var next_band := _next_stability_band(stability)
	if next_band == _stability_band:
		return
	var previous_band := _stability_band
	_stability_band = next_band
	var event := {
		"event": &"stability_band_changed",
		"previous_band": int(previous_band),
		"current_band": int(next_band),
		"stability": stability,
	}
	emitted_events.append(event)
	_event_bus.emit_signal(
		"stability_band_changed",
		int(previous_band),
		int(next_band),
		stability
	)


func _watch_waste(waste: float, emitted_events: Array[Dictionary]) -> void:
	var waste_max := float(_read_balance("resources.waste.max", INF))
	var overflow_now := waste >= waste_max
	if overflow_now and not _waste_overflow_active:
		_waste_overflow_active = true
		var stability_penalty := float(
			_read_balance(
				"resources.waste.overflow_stability_penalty",
				0.0
			)
		)
		var event := {
			"event": &"waste_overflowed",
			"waste": waste,
			"stability_penalty": stability_penalty,
		}
		emitted_events.append(event)
		_event_bus.emit_signal(
			"waste_overflowed",
			waste,
			stability_penalty
		)
	elif not overflow_now and _waste_overflow_active:
		_waste_overflow_active = false


func _watch_resource_shortage(
	resource_id: StringName,
	amount: float,
	emitted_events: Array[Dictionary]
) -> void:
	var threshold := _resource_shortage_threshold(resource_id)
	var shortage_now := amount < threshold
	var shortage_before := bool(
		_resource_shortages.get(resource_id, false)
	)
	if shortage_now == shortage_before:
		return
	_resource_shortages[resource_id] = shortage_now
	if shortage_now:
		var raised_event := {
			"event": &"resource_shortage_raised",
			"resource_id": resource_id,
			"amount": amount,
			"threshold": threshold,
		}
		emitted_events.append(raised_event)
		_event_bus.emit_signal(
			"resource_shortage_raised",
			resource_id,
			amount,
			threshold
		)
	else:
		var cleared_event := {
			"event": &"resource_shortage_cleared",
			"resource_id": resource_id,
			"amount": amount,
		}
		emitted_events.append(cleared_event)
		_event_bus.emit_signal(
			"resource_shortage_cleared",
			resource_id,
			amount
		)


func _initial_stability_band(stability: float) -> StabilityBand:
	if stability < float(
		_read_balance("thresholds.stability.critical_enter", 0.0)
	):
		return StabilityBand.CRITICAL
	if stability >= float(
		_read_balance("thresholds.stability.stable_enter", INF)
	):
		return StabilityBand.STABLE
	return StabilityBand.STRAINED


func _next_stability_band(stability: float) -> StabilityBand:
	var stable_exit := float(
		_read_balance("thresholds.stability.stable_exit", 0.0)
	)
	var strained_recover := float(
		_read_balance("thresholds.stability.strained_recover", INF)
	)
	var critical_enter := float(
		_read_balance("thresholds.stability.critical_enter", 0.0)
	)
	var critical_recover := float(
		_read_balance("thresholds.stability.critical_recover", INF)
	)
	var hysteresis := float(
		_read_balance("thresholds.stability.hysteresis", 0.0)
	)
	strained_recover = maxf(
		strained_recover,
		stable_exit + hysteresis
	)
	critical_recover = maxf(
		critical_recover,
		critical_enter + hysteresis
	)
	match _stability_band:
		StabilityBand.STABLE:
			if stability < critical_enter:
				return StabilityBand.CRITICAL
			if stability < stable_exit:
				return StabilityBand.STRAINED
		StabilityBand.STRAINED:
			if stability < critical_enter:
				return StabilityBand.CRITICAL
			if stability >= strained_recover:
				return StabilityBand.STABLE
		StabilityBand.CRITICAL:
			if stability >= strained_recover:
				return StabilityBand.STABLE
			if stability >= critical_recover:
				return StabilityBand.STRAINED
	return _stability_band


func _resource_shortage_threshold(resource_id: StringName) -> float:
	return float(
		_read_balance("thresholds.resources.%s_low" % resource_id, 0.0)
	)


func _has_required_values(resource_values: Dictionary) -> bool:
	if (
		not resource_values.has(&"stability")
		or not resource_values.has(&"waste")
	):
		return false
	for resource_id in INVESTABLE_RESOURCE_IDS:
		if not resource_values.has(resource_id):
			return false
	return true


func _dependencies_are_ready() -> bool:
	if _balance_access == null or _event_bus == null:
		push_warning("[THRESHOLD] Configure Balance and EventBus first.")
		return false
	for event_name in REQUIRED_EVENT_NAMES:
		if not _event_bus.has_signal(event_name):
			return false
	return true


func _read_balance(path: String, default_value: Variant) -> Variant:
	return _balance_access.call("get_value", path, default_value)
