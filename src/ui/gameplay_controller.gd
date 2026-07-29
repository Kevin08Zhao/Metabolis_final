class_name GameplayController
extends Control

## Connects the existing gameplay modules to one compact, keyboard-and-button
## driven prototype panel. The underlying decision modules remain authoritative
## for validation, costs, irreversible confirmation, settlement, and events.

signal visual_state_changed()

const LOG_PREFIX := "[PLAY]"
const RESOURCE_IDS: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
	&"waste",
	&"stability",
	&"knowledge_badge_count",
]

var _flow: ChapterFlow = null
var _resources: ResourcePool = null
var _resource_bar: ResourceBar = null

var _build_decision: BuildDecision = null
var _operation_decision: OperationDecision = null
var _minigame_runtime: MinigameRuntime = null
var _network_coverage: NetworkCoverage = null
var _resource_tick: ResourceTick = null
var _threshold_watcher: ThresholdWatcher = null

var _panel: PanelContainer = null
var _title: Label = null
var _body: Label = null
var _options: GridContainer = null
var _slots: HBoxContainer = null
var _feedback: Label = null
var _actions: HBoxContainer = null

var _resource_settled := false
var _build_presented_id: StringName = &""
var _selected_build_option_id: StringName = &""
var _operation_presented_id: StringName = &""


func _ready() -> void:
	_build_panel()
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.phase_changed.connect(_on_phase_changed)


func configure(
	flow: ChapterFlow,
	resources: ResourcePool,
	resource_bar: ResourceBar
) -> void:
	_flow = flow
	_resources = resources
	_resource_bar = resource_bar

	_build_decision = BuildDecision.new()
	_build_decision.name = "BuildDecision"
	add_child(_build_decision)

	_operation_decision = OperationDecision.new()
	_operation_decision.name = "OperationDecision"
	add_child(_operation_decision)

	_minigame_runtime = MinigameRuntime.new()
	_minigame_runtime.name = "MinigameRuntime"
	_minigame_runtime.run_resolved.connect(_on_minigame_resolved)
	add_child(_minigame_runtime)

	_network_coverage = NetworkCoverage.new()
	_network_coverage.configure(Balance)
	_resource_tick = ResourceTick.new()
	_resource_tick.configure(Balance, _network_coverage)
	_threshold_watcher = ThresholdWatcher.new()
	_threshold_watcher.configure(Balance, EventBus)
	_threshold_watcher.initialize(_resource_snapshot())
	_refresh()


func request_advance() -> bool:
	if _flow == null or _flow.chapter == null:
		return false
	var step_id := _flow.current_step_id()
	if step_id == &"resource_settlement" and not _resource_settled:
		_set_feedback("Settle stage resources before continuing.")
		return false
	if (
		step_id == &"build_decision"
		and not _flow.chapter.confirmed_build_decision_ids.has(
			_flow.chapter.active_build_decision_id
		)
	):
		_set_feedback("Choose a candidate and slot, then confirm twice.")
		return false
	if (
		step_id == &"operation_decision"
		and not _flow.chapter.confirmed_operation_decision_ids.has(
			_flow.chapter.active_operation_decision_id
		)
	):
		_set_feedback("Choose an operation priority, then confirm twice.")
		return false

	var changed := _flow.advance()
	if changed:
		_refresh()
		visual_state_changed.emit()
	return changed


func _on_stage_loaded(_stage_id: StringName, _stage_index: int) -> void:
	if _flow == null or _flow.chapter == null:
		return
	_resource_settled = false
	_build_presented_id = &""
	_selected_build_option_id = &""
	_operation_presented_id = &""
	_build_decision.configure(Balance, EventBus, _flow.chapter, _resources)
	_operation_decision.configure(
		Balance,
		EventBus,
		_flow.chapter,
		_resources,
		_resource_tick,
		_threshold_watcher
	)
	_threshold_watcher.initialize(_resource_snapshot())
	_refresh()
	visual_state_changed.emit()


func _on_phase_changed(_previous_phase: int, _current_phase: int) -> void:
	_refresh()
	visual_state_changed.emit()


func _refresh() -> void:
	if _flow == null or _flow.chapter == null or _title == null:
		return
	_clear_container(_options)
	_clear_container(_slots)
	_clear_container(_actions)
	_feedback.text = ""
	if _flow.is_run_complete():
		_title.text = "Run Complete"
		_body.text = "All four development stages are complete."
		return

	var step_id := _flow.current_step_id()
	_title.text = "Stage %d - %s" % [
		_flow.stage_number(),
		str(step_id).replace("_", " ").capitalize(),
	]
	match step_id:
		&"observe_state":
			_body.text = "Review the city state, then continue to receive this stage's targets."
			_add_continue_button()
		&"receive_targets":
			_body.text = "Build targets: %s" % _joined_names(
				_flow.chapter.required_build_decision_ids
			)
			_add_continue_button()
		&"optional_minigame":
			_render_minigame()
		&"resource_settlement":
			_render_resource_settlement()
		&"build_decision":
			_render_build_decision()
		&"build_completion":
			_body.text = "Construction is complete. Continue to the next required action."
			_add_continue_button()
		&"operation_decision":
			_render_operation_decision()
		&"system_activation":
			_body.text = "The new system is active and collaborating with the city."
			_add_continue_button()
		&"knowledge_unlock":
			_body.text = "A knowledge entry has been unlocked for this stage."
			_add_continue_button()
		&"stage_complete":
			_body.text = "Stage requirements are complete. Continue to the next stage."
			_add_continue_button()


func _render_minigame() -> void:
	var minigame_id := _flow.chapter.stage_minigame_id
	if minigame_id == &"":
		_body.text = "This stage has no optional task."
		_add_continue_button()
		return
	var resolution := _flow.chapter.minigame_resolution
	_body.text = (
		"Optional task: %s\nResolution: %s"
		% [_display_name(minigame_id), _display_name(resolution)]
	)
	if resolution == &"pending":
		if _minigame_runtime.state() == MinigameRuntime.State.RUNNING:
			_add_action_button("CompleteTask", "Complete Task", _complete_minigame)
		else:
			_add_action_button("StartTask", "Start Task", _start_minigame)
		_add_action_button("SkipTask", "Skip Task", _skip_minigame)
	_add_continue_button()


func _render_resource_settlement() -> void:
	_body.text = (
		"Stage resources are ready."
		if _resource_settled
		else "Settle city production before making an irreversible build choice."
	)
	if not _resource_settled:
		_add_action_button(
			"SettleResources",
			"Settle Resources",
			_settle_stage_resources
		)
	_add_continue_button(not _resource_settled)


func _render_build_decision() -> void:
	var decision_id := _flow.chapter.active_build_decision_id
	if decision_id != _build_presented_id:
		_build_presented_id = decision_id
		_selected_build_option_id = &""
		var sequence := _flow.chapter.required_build_decision_ids.find(decision_id) + 1
		_build_decision.present_decision(
			_flow.stage_number(),
			sequence,
			decision_id
		)

	_body.text = "Build: %s\nChoose a candidate and a legal map slot." % _display_name(
		decision_id
	)
	for option_id in _flow.chapter.available_build_option_ids:
		var cost := _dictionary_value(
			"build_options.%s.%s.cost" % [decision_id, option_id]
		)
		var label := "%s  [N %.0f / C %.0f / S %.0f]" % [
			_display_name(option_id),
			float(cost.get("nutrient_energy", 0.0)),
			float(cost.get("cell_material", 0.0)),
			float(cost.get("development_signal", 0.0)),
		]
		_add_option_button(
			option_id,
			label,
			func() -> void: _choose_build_option(option_id)
		)

	if _selected_build_option_id != &"":
		var slots := _string_name_array(
			Balance.get_value(
				"build_options.%s.%s.available_slot_ids"
				% [decision_id, _selected_build_option_id],
				[]
			)
		)
		for slot_id in slots:
			_add_slot_button(
				slot_id,
				func() -> void: _choose_build_slot(slot_id)
			)

	var confirmed := _flow.chapter.confirmed_build_decision_ids.has(decision_id)
	if not confirmed:
		_add_action_button(
			"ConfirmBuild",
			"Confirm Build",
			_confirm_build,
			_flow.chapter.selected_build_slot_id == &""
		)
	else:
		_feedback.text = "Build confirmed and resources deducted."
	_add_continue_button(not confirmed)


func _render_operation_decision() -> void:
	var decision_id := _flow.chapter.active_operation_decision_id
	if decision_id != _operation_presented_id:
		_operation_presented_id = decision_id
		_operation_decision.present_decision(_flow.stage_number(), decision_id)

	_body.text = "Operations: %s\nChoose the city's resource priority." % _display_name(
		decision_id
	)
	for option_id in _flow.chapter.available_operation_ids:
		var cost := _dictionary_value("operations.options.%s.cost" % option_id)
		var label := "%s  [N %.0f / C %.0f / S %.0f]" % [
			_display_name(option_id),
			float(cost.get("nutrient_energy", 0.0)),
			float(cost.get("cell_material", 0.0)),
			float(cost.get("development_signal", 0.0)),
		]
		_add_option_button(
			option_id,
			label,
			func() -> void: _choose_operation(option_id)
		)

	var confirmed := _flow.chapter.confirmed_operation_decision_ids.has(
		decision_id
	)
	if not confirmed:
		_add_action_button(
			"ConfirmOperation",
			"Confirm Operation",
			_confirm_operation,
			_flow.chapter.selected_operation_id == &""
		)
	else:
		_feedback.text = "Operation confirmed and settled."
	_add_continue_button(not confirmed)


func _start_minigame() -> void:
	if _minigame_runtime.begin(
		_flow.chapter.stage_minigame_id,
		_flow.chapter.stage_id
	):
		_refresh()


func _complete_minigame() -> void:
	_minigame_runtime.report_progress(INF)


func _skip_minigame() -> void:
	if _minigame_runtime.state() != MinigameRuntime.State.RUNNING:
		_minigame_runtime.begin(
			_flow.chapter.stage_minigame_id,
			_flow.chapter.stage_id
		)
	_minigame_runtime.skip()


func _on_minigame_resolved(
	_minigame_id: StringName,
	_resolution: int
) -> void:
	if _flow == null or _flow.chapter == null:
		return
	_flow.chapter.minigame_resolution = _minigame_runtime.resolution_id()
	var reward := _minigame_runtime.pending_reward()
	for resource_id in RESOURCE_IDS:
		if not reward.has(resource_id):
			continue
		if resource_id == &"knowledge_badge_count":
			_resources.knowledge_badge_count += int(reward[resource_id])
		else:
			_resources.set(
				resource_id,
				float(_resources.get(resource_id)) + float(reward[resource_id])
			)
	_sync_resource_bar()
	_refresh()
	visual_state_changed.emit()


func _settle_stage_resources() -> void:
	if _resource_settled:
		return
	var before := _resource_snapshot()
	_resource_tick.initialize_from_balance(before)
	var duration := float(
		Balance.get_value(
			"chapters.%s.operation_time_sec" % _flow.chapter.stage_id,
			0.0
		)
	)
	var settled := _resource_tick.settle_tick(
		maxf(duration, float(Balance.get_value("tick_interval_sec", 1.0))),
		_empty_settlement_input()
	)
	_apply_resource_snapshot(settled)
	_resource_settled = true
	var after := _resource_snapshot()
	EventBus.resources_settled.emit(
		_flow.chapter.stage_id,
		_resource_deltas(before, after),
		after.duplicate(true)
	)
	_sync_resource_bar()
	_refresh()
	visual_state_changed.emit()


func _choose_build_option(option_id: StringName) -> void:
	_selected_build_option_id = option_id
	_flow.chapter.selected_build_option_id = &""
	_flow.chapter.selected_build_slot_id = &""
	_refresh()


func _choose_build_slot(slot_id: StringName) -> void:
	_build_decision.select_candidate(_selected_build_option_id, slot_id)
	_feedback.text = _build_decision.feedback_text()
	_refresh()


func _confirm_build() -> void:
	var confirmed := _build_decision.request_confirmation()
	if confirmed:
		_sync_resource_bar()
	_feedback.text = _build_decision.feedback_text()
	_refresh()
	visual_state_changed.emit()


func _choose_operation(option_id: StringName) -> void:
	_operation_decision.select_priority(option_id)
	_feedback.text = _operation_decision.feedback_text()
	_refresh()


func _confirm_operation() -> void:
	var confirmed := _operation_decision.request_confirmation(
		_empty_settlement_input()
	)
	if confirmed:
		_sync_resource_bar()
	_feedback.text = _operation_decision.feedback_text()
	_refresh()
	visual_state_changed.emit()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GameplayActions"
	_panel.z_index = 20
	_panel.position = Vector2(60, 116)
	_panel.size = Vector2(520, 228)
	add_child(_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 6)
	_panel.add_child(content)

	_title = Label.new()
	_title.name = "ActionTitle"
	_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_title)

	_body = Label.new()
	_body.name = "ActionBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(488, 42)
	content.add_child(_body)

	_options = GridContainer.new()
	_options.name = "OptionButtons"
	_options.columns = 2
	content.add_child(_options)

	_slots = HBoxContainer.new()
	_slots.name = "SlotButtons"
	content.add_child(_slots)

	_feedback = Label.new()
	_feedback.name = "ActionFeedback"
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(488, 20)
	content.add_child(_feedback)

	_actions = HBoxContainer.new()
	_actions.name = "ActionButtons"
	content.add_child(_actions)


func _add_option_button(
	option_id: StringName,
	text: String,
	handler: Callable
) -> void:
	var button := Button.new()
	button.name = "Option_%s" % option_id
	button.text = text
	button.pressed.connect(handler, CONNECT_DEFERRED)
	_options.add_child(button)


func _add_slot_button(slot_id: StringName, handler: Callable) -> void:
	var button := Button.new()
	button.name = "Slot_%s" % slot_id
	button.text = _display_name(slot_id)
	button.pressed.connect(handler, CONNECT_DEFERRED)
	_slots.add_child(button)


func _add_action_button(
	button_name: String,
	text: String,
	handler: Callable,
	disabled: bool = false
) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.disabled = disabled
	button.pressed.connect(handler, CONNECT_DEFERRED)
	_actions.add_child(button)


func _add_continue_button(disabled: bool = false) -> void:
	_add_action_button(
		"ContinueAction",
		"Continue",
		request_advance,
		disabled
	)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _set_feedback(text: String) -> void:
	_feedback.text = text


func _sync_resource_bar() -> void:
	if _resource_bar != null:
		_resource_bar.set_resources(_resource_snapshot())


func _resource_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	if _resources == null:
		return snapshot
	for resource_id in RESOURCE_IDS:
		snapshot[resource_id] = _resources.get(resource_id)
	return snapshot


func _apply_resource_snapshot(values: Dictionary) -> void:
	for resource_id in RESOURCE_IDS:
		if values.has(resource_id):
			_resources.set(resource_id, values[resource_id])


func _resource_deltas(before: Dictionary, after: Dictionary) -> Dictionary:
	var deltas: Dictionary = {}
	for resource_id in RESOURCE_IDS:
		deltas[resource_id] = (
			float(after.get(resource_id, 0.0))
			- float(before.get(resource_id, 0.0))
		)
	return deltas


func _empty_settlement_input() -> Dictionary:
	return {
		"organs": [],
		"required_organ_ids": [],
		"nodes": [],
		"edges": [],
		"source_node_ids": [],
		"requested_flow_by_organ": {},
		"available_transport_flow": 0.0,
		"requested_development_signal_by_organ": {},
		"available_development_signal_flow": 0.0,
		"resource_satisfaction_by_organ": {},
		"intervention_waste_removal": 0.0,
	}


func _dictionary_value(path: String) -> Dictionary:
	var value: Variant = Balance.get_value(path, {})
	return value if value is Dictionary else {}


func _display_name(value: StringName) -> String:
	return str(value).replace("_", " ").capitalize()


func _joined_names(values: Array[StringName]) -> String:
	var names := PackedStringArray()
	for value in values:
		names.append(_display_name(value))
	return ", ".join(names)


func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value:
			result.append(StringName(item))
	return result
