class_name OptionPreview
extends VBoxContainer

## Displays the three Table D8 outcome metrics for a hovered build candidate.
##
## Scene setup:
## 1. Add a VBoxContainer named OptionPreview below the HUD layer.
## 2. Attach res://ui/option_preview.gd and leave its children empty.
## 3. Call configure(Balance, grid_manager).
## 4. Call set_candidates() with slot IDs mapped to decision_id and option_id.
##
## Acceptance walk, using the canonical Balance values:
## - cluster_compact: 1.12 coefficient, 31.00 seconds, 0.98 coefficient;
##   bar ratios 80%, 45%, 45%.
## - heart_early_flow: 1.00 coefficient, 24.00 seconds, 1.06 coefficient;
##   bar ratios 50%, 80%, 65%.
## - lung_branching: 1.12 coefficient, 32.00 seconds, 1.08 coefficient;
##   bar ratios 80%, 40%, 70%.
## Hover slots mapped to these options in that order and verify the three rows.
## If a raw metric exceeds its configured range, its number remains visible while
## its comparison bar clamps to the nearest range boundary. For example, 1.40
## network efficiency displays as 1.40 coefficient with a 100% bar.

const DIMENSIONS: Array[StringName] = [
	&"network_efficiency",
	&"build_duration",
	&"future_convenience",
]
const ROW_NAMES: Array[StringName] = [
	&"NetworkEfficiency",
	&"BuildDuration",
	&"FutureConvenience",
]
const DISPLAY_NAMES: Array[String] = [
	"Network efficiency",
	"Build duration",
	"Future convenience",
]

var _balance_access: Node
var _grid_manager: Node
var _candidate_contexts: Dictionary = {}
var _value_labels: Array[Label] = []
var _comparison_bars: Array[ProgressBar] = []
var _displayed_values := Vector3.ZERO
var _bar_ratios := Vector3.ZERO
var _hovered_slot_id := StringName()


func _ready() -> void:
	if get_child_count() == 0:
		_build_default_layout()
	hide()


func configure(balance_access: Node, grid_manager: Node) -> void:
	_disconnect_grid()
	_balance_access = balance_access
	_grid_manager = grid_manager
	if _grid_manager == null:
		push_warning("[OPTION_PREVIEW] Cannot listen without a grid manager.")
		return
	if not _grid_manager.has_signal("slot_hovered") or not _grid_manager.has_signal("slot_unhovered"):
		push_warning("[OPTION_PREVIEW] Grid manager is missing hover signals.")
		return
	_grid_manager.connect("slot_hovered", _on_slot_hovered)
	_grid_manager.connect("slot_unhovered", _on_slot_unhovered)


func set_candidates(candidate_contexts: Dictionary) -> void:
	_candidate_contexts = candidate_contexts.duplicate(true)
	_hovered_slot_id = StringName()
	hide()


func displayed_values() -> Vector3:
	return _displayed_values


func bar_ratios() -> Vector3:
	return _bar_ratios


func show_candidate(candidate_id: StringName) -> bool:
	if _balance_access == null:
		push_warning("[OPTION_PREVIEW] Cannot show metrics without Balance.")
		hide()
		return false
	if not _candidate_contexts.has(candidate_id):
		push_warning("[OPTION_PREVIEW] Unknown candidate '%s'." % candidate_id)
		hide()
		return false

	var context: Variant = _candidate_contexts[candidate_id]
	if not context is Dictionary:
		push_warning("[OPTION_PREVIEW] Candidate '%s' has invalid context." % candidate_id)
		hide()
		return false
	var decision_id := StringName(context.get("decision_id", ""))
	var option_id := StringName(context.get("option_id", ""))
	if decision_id.is_empty() or option_id.is_empty():
		push_warning("[OPTION_PREVIEW] Candidate '%s' is missing decision or option ID." % candidate_id)
		hide()
		return false

	if _value_labels.size() != DIMENSIONS.size():
		_build_default_layout()

	var raw_values: Array[float] = []
	var ratios: Array[float] = []
	for index in range(DIMENSIONS.size()):
		var dimension := DIMENSIONS[index]
		var range := _read_range(dimension)
		if range.is_empty():
			hide()
			return false

		var metric_path := "build_options.%s.%s.metrics.%s" % [
			decision_id,
			option_id,
			dimension,
		]
		var raw_value_variant: Variant = _balance_access.call("get_value", metric_path, null)
		if not raw_value_variant is float and not raw_value_variant is int:
			push_warning("[OPTION_PREVIEW] Missing numeric metric '%s'." % metric_path)
			hide()
			return false
		var raw_value := float(raw_value_variant)
		var unit := String(
			_balance_access.call(
				"get_value",
				"build_options.metric_units.%s" % dimension,
				""
			)
		)
		var ratio := _normalized_ratio(raw_value, range, dimension == &"build_duration")
		_update_row(index, raw_value, unit, range, ratio)
		raw_values.append(raw_value)
		ratios.append(ratio)

	_displayed_values = Vector3(raw_values[0], raw_values[1], raw_values[2])
	_bar_ratios = Vector3(ratios[0], ratios[1], ratios[2])
	_hovered_slot_id = candidate_id
	show()
	print("[OPTION_PREVIEW] candidate=", candidate_id, " values=", _displayed_values)
	return true


func _build_default_layout() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_value_labels.clear()
	_comparison_bars.clear()

	for index in range(DIMENSIONS.size()):
		var row := VBoxContainer.new()
		row.name = ROW_NAMES[index]
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.text = "%s: --" % DISPLAY_NAMES[index]
		var comparison_bar := ProgressBar.new()
		comparison_bar.name = "ComparisonBar"
		comparison_bar.show_percentage = false
		comparison_bar.custom_minimum_size = Vector2(128.0, 12.0)
		row.add_child(value_label)
		row.add_child(comparison_bar)
		add_child(row)
		_value_labels.append(value_label)
		_comparison_bars.append(comparison_bar)


func _read_range(dimension: StringName) -> Array[float]:
	var range_variant: Variant = _balance_access.call(
		"get_value",
		"build_options.metric_ranges.%s" % dimension,
		[]
	)
	if not range_variant is Array or range_variant.size() != 2:
		push_warning("[OPTION_PREVIEW] Metric range '%s' must contain two values." % dimension)
		return []
	if (
		(not range_variant[0] is float and not range_variant[0] is int)
		or (not range_variant[1] is float and not range_variant[1] is int)
	):
		push_warning("[OPTION_PREVIEW] Metric range '%s' must be numeric." % dimension)
		return []
	var minimum := float(range_variant[0])
	var maximum := float(range_variant[1])
	if maximum <= minimum:
		push_warning("[OPTION_PREVIEW] Metric range '%s' requires max greater than min." % dimension)
		return []
	return [minimum, maximum]


func _normalized_ratio(raw_value: float, range: Array[float], reversed: bool) -> float:
	var minimum := range[0]
	var maximum := range[1]
	var ratio := (
		(maximum - raw_value) / (maximum - minimum)
		if reversed
		else (raw_value - minimum) / (maximum - minimum)
	)
	return clampf(ratio, 0.0, 1.0)


func _update_row(
	index: int,
	raw_value: float,
	unit: String,
	range: Array[float],
	ratio: float
) -> void:
	_value_labels[index].text = "%s: %.2f %s" % [DISPLAY_NAMES[index], raw_value, unit]
	var comparison_bar := _comparison_bars[index]
	comparison_bar.min_value = range[0]
	comparison_bar.max_value = range[1]
	comparison_bar.value = lerpf(range[0], range[1], ratio)


func _on_slot_hovered(slot_id: StringName) -> void:
	show_candidate(slot_id)


func _on_slot_unhovered(slot_id: StringName) -> void:
	if slot_id != _hovered_slot_id:
		return
	_hovered_slot_id = StringName()
	hide()


func _disconnect_grid() -> void:
	if not is_instance_valid(_grid_manager):
		return
	if _grid_manager.is_connected("slot_hovered", _on_slot_hovered):
		_grid_manager.disconnect("slot_hovered", _on_slot_hovered)
	if _grid_manager.is_connected("slot_unhovered", _on_slot_unhovered):
		_grid_manager.disconnect("slot_unhovered", _on_slot_unhovered)
