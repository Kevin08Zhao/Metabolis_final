class_name ResourceBar
extends Control

## Six-resource status bar.
##
## Scene assembly:
## 1. Add one Control named ResourceBar under the persistent CanvasLayer.
## 2. Anchor it TOP_WIDE in the top resource region and attach this script.
## 3. Add no positioned children. This script creates a MarginContainer and an
##    HBoxContainer, so the six cells stay equal while the window stretches.
## 4. Resource cells appear in the locked order from docs/UI_LAYOUT.md. At the
##    640-pixel reference width, 12-pixel side margins and 8-pixel container
##    separation produce six 96-pixel cells without storing any x coordinate.
##
## Every D-15 state has its own named TextureRect. Replacing a PNG at the same
## path replaces that icon without changing this script. State distinctions use
## D-15's silhouettes and fill patterns plus text; color is never the only cue.
##
## Values update only through public setters and EventBus signals. There is no
## per-frame resource poll.

const LOG_PREFIX := "[RESOURCE BAR]"
const HIGHLIGHT_DURATION_BALANCE_PATH := "assist.ui.resource_change_highlight_sec"
const RESOURCE_ICON_ROOT := "res://../art/icons"
const OUTER_MARGIN_PX := 12
const CELL_SEPARATION_PX := 8
const ICON_SIZE_PX := 16

const RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
	&"waste",
	&"stability",
	&"knowledge_badge_count",
]
const SPENDABLE_RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]

const NODE_PREFIXES := {
	&"nutrient_energy": "NutrientEnergy",
	&"cell_material": "CellMaterial",
	&"development_signal": "DevelopmentSignal",
	&"waste": "Waste",
	&"stability": "Stability",
	&"knowledge_badge_count": "KnowledgeBadge",
}

const ICON_PATHS := {
	&"nutrient_energy": {
		&"sufficient": "ui_resource_nutrient_energy_sufficient.png",
		&"insufficient": "ui_resource_nutrient_energy_insufficient.png",
	},
	&"cell_material": {
		&"sufficient": "ui_resource_cell_material_sufficient.png",
		&"insufficient": "ui_resource_cell_material_insufficient.png",
	},
	&"development_signal": {
		&"sufficient": "ui_resource_developmental_signal_sufficient.png",
		&"insufficient": "ui_resource_developmental_signal_insufficient.png",
	},
	&"waste": {
		&"normal": "ui_resource_waste_normal.png",
		&"overflow": "ui_resource_waste_overflow.png",
	},
	&"stability": {
		&"normal": "ui_resource_stability_normal.png",
		&"warning": "ui_resource_stability_warning.png",
		&"critical": "ui_resource_stability_critical.png",
	},
	&"knowledge_badge_count": {
		&"count": "ui_resource_knowledge_badge_count.png",
	},
}

enum StabilityBand {
	STABLE,
	STRAINED,
	CRITICAL,
}

var _values: Dictionary = {}
var _shortage_active: Dictionary = {}
var _stability_band := StabilityBand.STABLE
var _waste_overflow_active := false
var _value_labels: Dictionary = {}
var _icon_nodes: Dictionary = {}
var _highlight_panels: Dictionary = {}
var _highlight_tweens: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = ICON_SIZE_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect_events()
	_initialize_from_balance()
	if highlight_duration_sec() <= 0.0:
		push_warning(
			"%s Balance path '%s' must be positive."
			% [LOG_PREFIX, HIGHLIGHT_DURATION_BALANCE_PATH]
		)


func set_resources(values: Dictionary, highlight_changes: bool = true) -> void:
	for resource_id in RESOURCE_IDS:
		if not values.has(resource_id) and not values.has(String(resource_id)):
			continue
		var value: Variant = values.get(resource_id, values.get(String(resource_id)))
		_set_resource_value(resource_id, value, highlight_changes)


func set_resource(
	resource_id: StringName,
	value: Variant,
	highlight_change: bool = true
) -> bool:
	if not RESOURCE_IDS.has(resource_id):
		push_warning("%s Unknown resource '%s'." % [LOG_PREFIX, resource_id])
		return false
	return _set_resource_value(resource_id, value, highlight_change)


func resource_values() -> Dictionary:
	return _values.duplicate(true)


func displayed_text(resource_id: StringName) -> String:
	var label: Label = _value_labels.get(resource_id)
	return "" if label == null else label.text


func displayed_icon_state(resource_id: StringName) -> StringName:
	if SPENDABLE_RESOURCE_IDS.has(resource_id):
		return &"insufficient" if bool(_shortage_active.get(resource_id, false)) else &"sufficient"
	if resource_id == &"waste":
		return &"overflow" if _waste_warning_active() else &"normal"
	if resource_id == &"stability":
		match _stability_band:
			StabilityBand.STRAINED:
				return &"warning"
			StabilityBand.CRITICAL:
				return &"critical"
		return &"normal"
	return &"count"


func highlight_duration_sec() -> float:
	var value: Variant = Balance.get_value(HIGHLIGHT_DURATION_BALANCE_PATH, null)
	if not value is int and not value is float:
		return 0.0
	return float(value)


func highlight_visible(resource_id: StringName) -> bool:
	var panel: Panel = _highlight_panels.get(resource_id)
	return panel != null and panel.visible


func _initialize_from_balance() -> void:
	var initial_values: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		initial_values[resource_id] = Balance.get_value(
			"resources.%s.initial" % resource_id,
			0
		)
	set_resources(initial_values, false)
	_stability_band = _initial_stability_band(float(_values[&"stability"]))
	_refresh_resource(&"stability")


func _connect_events() -> void:
	EventBus.resources_settled.connect(_on_resources_settled)
	EventBus.build_decision_confirmed.connect(_on_build_decision_confirmed)
	EventBus.stability_band_changed.connect(_on_stability_band_changed)
	EventBus.waste_overflowed.connect(_on_waste_overflowed)
	EventBus.resource_shortage_raised.connect(_on_resource_shortage_raised)
	EventBus.resource_shortage_cleared.connect(_on_resource_shortage_cleared)


func _set_resource_value(
	resource_id: StringName,
	value: Variant,
	highlight_change: bool
) -> bool:
	if not value is int and not value is float:
		push_warning("%s Resource '%s' requires a numeric value." % [LOG_PREFIX, resource_id])
		return false

	var normalized: Variant = int(value) if resource_id == &"knowledge_badge_count" else float(value)
	var had_previous := _values.has(resource_id)
	var changed := had_previous and not is_equal_approx(
		float(_values[resource_id]),
		float(normalized)
	)
	_values[resource_id] = normalized

	if resource_id == &"waste":
		var waste_max := _resource_max(&"waste")
		if waste_max > 0.0 and float(normalized) < waste_max:
			_waste_overflow_active = false

	_refresh_resource(resource_id)
	if highlight_change and changed:
		_flash(resource_id)
	return true


func _refresh_resource(resource_id: StringName) -> void:
	var label: Label = _value_labels.get(resource_id)
	if label == null or not _values.has(resource_id):
		return

	var value := float(_values[resource_id])
	var state := displayed_icon_state(resource_id)
	_show_icon_state(resource_id, state)

	if SPENDABLE_RESOURCE_IDS.has(resource_id):
		var prefix := "[low] " if state == &"insufficient" else ""
		label.text = "%s%s/%s" % [
			prefix,
			_number_text(value),
			_number_text(_resource_max(resource_id)),
		]
	elif resource_id == &"waste":
		var waste_prefix := ""
		if _waste_overflow_active:
			waste_prefix = "[overflow] "
		elif _waste_warning_active():
			waste_prefix = "[near-cap] "
		label.text = "%s%s/%s" % [
			waste_prefix,
			_number_text(value),
			_number_text(_resource_max(resource_id)),
		]
	elif resource_id == &"stability":
		label.text = "%s %s/%s" % [
			_stability_band_text(),
			_number_text(value),
			_number_text(_resource_max(resource_id)),
		]
	else:
		label.text = str(int(round(value)))


func _show_icon_state(resource_id: StringName, visible_state: StringName) -> void:
	var variants: Dictionary = _icon_nodes.get(resource_id, {})
	for state in variants:
		var icon: TextureRect = variants[state]
		icon.visible = StringName(state) == visible_state


func _flash(resource_id: StringName) -> void:
	var duration := highlight_duration_sec()
	if duration <= 0.0:
		return
	var panel: Panel = _highlight_panels.get(resource_id)
	if panel == null:
		return

	var previous: Tween = _highlight_tweens.get(resource_id)
	if previous != null:
		previous.kill()

	panel.visible = true
	panel.modulate.a = 0.55
	var tween := create_tween()
	_highlight_tweens[resource_id] = tween
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	tween.tween_callback(_finish_flash.bind(resource_id, panel))


func _finish_flash(resource_id: StringName, panel: Panel) -> void:
	panel.visible = false
	_highlight_tweens.erase(resource_id)


func _on_resources_settled(
	_stage_id: StringName,
	_deltas: Dictionary,
	totals: Dictionary
) -> void:
	set_resources(totals, true)


func _on_build_decision_confirmed(
	_decision_id: StringName,
	_option_id: StringName,
	_slot_id: StringName,
	spent: Dictionary
) -> void:
	var updated: Dictionary = {}
	for resource_id in SPENDABLE_RESOURCE_IDS:
		if not spent.has(resource_id) or not _values.has(resource_id):
			continue
		updated[resource_id] = maxf(
			0.0,
			float(_values[resource_id]) - float(spent[resource_id])
		)
	set_resources(updated, true)


func _on_stability_band_changed(
	_previous_band: int,
	current_band: int,
	stability: float
) -> void:
	if current_band < StabilityBand.STABLE or current_band > StabilityBand.CRITICAL:
		push_warning("%s Ignoring unknown stability band %s." % [LOG_PREFIX, current_band])
		return
	_stability_band = current_band
	_set_resource_value(&"stability", stability, true)


func _on_waste_overflowed(waste: float, _stability_penalty: float) -> void:
	_waste_overflow_active = true
	_set_resource_value(&"waste", waste, true)
	_refresh_resource(&"waste")


func _on_resource_shortage_raised(
	resource_id: StringName,
	amount: float,
	_threshold: float
) -> void:
	if not SPENDABLE_RESOURCE_IDS.has(resource_id):
		push_warning("%s Ignoring shortage for '%s'." % [LOG_PREFIX, resource_id])
		return
	_shortage_active[resource_id] = true
	_set_resource_value(resource_id, amount, true)
	_refresh_resource(resource_id)


func _on_resource_shortage_cleared(resource_id: StringName, amount: float) -> void:
	if not SPENDABLE_RESOURCE_IDS.has(resource_id):
		return
	_shortage_active[resource_id] = false
	_set_resource_value(resource_id, amount, true)
	_refresh_resource(resource_id)


func _initial_stability_band(stability: float) -> StabilityBand:
	var critical_enter := float(
		Balance.get_value("operations.thresholds.stability.critical_enter", 0.0)
	)
	var stable_enter := float(
		Balance.get_value("operations.thresholds.stability.stable_enter", INF)
	)
	if stability < critical_enter:
		return StabilityBand.CRITICAL
	if stability >= stable_enter:
		return StabilityBand.STABLE
	return StabilityBand.STRAINED


func _stability_band_text() -> String:
	match _stability_band:
		StabilityBand.STRAINED:
			return "[strained]"
		StabilityBand.CRITICAL:
			return "[critical]"
	return "[stable]"


func _waste_warning_active() -> bool:
	if not _values.has(&"waste"):
		return false
	var threshold := float(
		Balance.get_value("operations.thresholds.waste.warning", INF)
	)
	return _waste_overflow_active or float(_values[&"waste"]) >= threshold


func _resource_max(resource_id: StringName) -> float:
	return float(Balance.get_value("resources.%s.max" % resource_id, 0.0))


func _number_text(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%.1f" % value


func _build() -> void:
	var margins := MarginContainer.new()
	margins.name = "ResourceMargins"
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_theme_constant_override("margin_left", OUTER_MARGIN_PX)
	margins.add_theme_constant_override("margin_right", OUTER_MARGIN_PX)
	add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.name = "ResourceRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", CELL_SEPARATION_PX)
	margins.add_child(row)

	for resource_id in RESOURCE_IDS:
		_build_resource_cell(row, resource_id)


func _build_resource_cell(row: HBoxContainer, resource_id: StringName) -> void:
	var prefix := String(NODE_PREFIXES[resource_id])
	var cell := Control.new()
	cell.name = "%sCell" % prefix
	cell.custom_minimum_size.y = ICON_SIZE_PX
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell)

	var content := HBoxContainer.new()
	content.name = "%sContent" % prefix
	content.add_theme_constant_override("separation", 0)
	cell.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon_slot := Control.new()
	icon_slot.name = "%sIconSlot" % prefix
	icon_slot.custom_minimum_size = Vector2(ICON_SIZE_PX, ICON_SIZE_PX)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_slot)

	var variants: Dictionary = {}
	var resource_paths: Dictionary = ICON_PATHS[resource_id]
	for state in resource_paths:
		var icon := TextureRect.new()
		icon.name = "%sIcon%s" % [prefix, String(state).to_pascal_case()]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _load_icon_texture(String(resource_paths[state]))
		icon_slot.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		variants[StringName(state)] = icon
	_icon_nodes[resource_id] = variants

	var label := Label.new()
	label.name = "%sValue" % prefix
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.clip_text = true
	label.text = "[pending]"
	content.add_child(label)
	_value_labels[resource_id] = label

	var highlight := Panel.new()
	highlight.name = "%sChangeHighlight" % prefix
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.visible = false
	cell.add_child(highlight)
	highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight_panels[resource_id] = highlight


func _load_icon_texture(file_name: String) -> Texture2D:
	var path := "%s/%s" % [RESOURCE_ICON_ROOT, file_name]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		push_warning("%s Missing icon '%s'." % [LOG_PREFIX, path])
		return null
	return ImageTexture.create_from_image(image)
