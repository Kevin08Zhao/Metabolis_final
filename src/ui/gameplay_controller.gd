class_name GameplayController
extends Control

## Connects the existing gameplay modules to one compact, keyboard-and-button
## driven prototype panel. The underlying decision modules remain authoritative
## for validation, costs, irreversible confirmation, settlement, and events.

signal visual_state_changed()
signal birth_retry_requested()

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
var _grid_manager: GridManager = null
var _city_art: Node2D = null
var _network_builder: NetworkBuilder = null
var _birth_art: TextureRect = null
var _option_preview: OptionPreview = null

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
var _minigame_progress := 0.0
var _built_organs: Array[Dictionary] = []
var _stage_start_conditions: Dictionary = {}
var _birth_gate_report: Dictionary = {}
var _birth_retry_available := false


func _ready() -> void:
	_build_panel()
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if (
		_minigame_runtime != null
		and _minigame_runtime.state() == MinigameRuntime.State.RUNNING
	):
		_minigame_runtime.advance_time(delta)


func configure(
	flow: ChapterFlow,
	resources: ResourcePool,
	resource_bar: ResourceBar,
	grid_manager: GridManager,
	city_art: Node2D,
	network_builder: NetworkBuilder,
	birth_art: TextureRect
) -> void:
	_flow = flow
	_resources = resources
	_resource_bar = resource_bar
	_grid_manager = grid_manager
	_city_art = city_art
	_network_builder = network_builder
	_birth_art = birth_art

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
	if step_id == &"build_completion" and _city_art != null:
		var completed_organ_id := StringName(
			str(_flow.chapter.active_build_decision_id).trim_prefix("build_")
		)
		_city_art.set_organ_state(completed_organ_id, &"completed")
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


## Integration surface for the lifecycle layer. These methods expose copies or
## already-public simulation objects; they do not transfer input ownership.
func attach_option_preview(option_preview: OptionPreview) -> void:
	_option_preview = option_preview
	if _option_preview != null:
		_option_preview.configure(Balance, _grid_manager)


func resource_tick_system() -> ResourceTick:
	return _resource_tick


func threshold_watcher_system() -> ThresholdWatcher:
	return _threshold_watcher


func build_decision_records() -> Dictionary:
	return (
		{}
		if _build_decision == null
		else _build_decision.confirmed_decisions
	)


func operation_settlement_snapshot() -> Dictionary:
	return (
		{}
		if _resource_tick == null
		else _resource_tick.carryover_source_snapshot
	)


func built_organs_snapshot() -> Array[Dictionary]:
	return _built_organs.duplicate(true)


func resource_snapshot() -> Dictionary:
	return _resource_snapshot()


func apply_stage_start_conditions(record: Dictionary) -> void:
	_stage_start_conditions = record.duplicate(true)
	if _resources != null and record.has(&"initial_waste_accumulation"):
		_resources.waste = float(record[&"initial_waste_accumulation"])
	_sync_resource_bar()


func stage_start_conditions_readback() -> Dictionary:
	if _stage_start_conditions.is_empty():
		return {}
	return {
		&"network_efficiency_coefficient": float(
			_stage_start_conditions.get(
				&"network_efficiency_coefficient",
				0.0
			)
		),
		&"transport_pressure": float(
			_stage_start_conditions.get(
				&"initial_operation_pressure",
				0.0
			)
		),
		&"waste": float(
			_stage_start_conditions.get(
				&"initial_waste_accumulation",
				0.0
			)
		),
	}


func lifecycle_metrics() -> Dictionary:
	var metrics := _settlement_input()
	var waste_generation: Dictionary = {}
	var waste_processing: Dictionary = {}
	var required_signal: Dictionary = {}
	var weakest_edges: Dictionary = {}
	var edges: Array = metrics.get("edges", [])
	for organ in _built_organs:
		var organ_id := StringName(organ.get("organ_id", ""))
		waste_generation[organ_id] = float(
			Balance.get_value(
				"organs.%s.per_tick_output.waste" % organ_id,
				0.0
			)
		)
		waste_processing[organ_id] = float(
			Balance.get_value(
				"organs.%s.per_tick_consumption.waste" % organ_id,
				0.0
			)
		)
		required_signal[organ_id] = float(
			organ.get("required_development_signal", 0.0)
		)
		for edge in edges:
			if StringName(edge.get("organ_id", "")) == organ_id:
				weakest_edges[organ_id] = StringName(edge.get("edge_id", ""))
				break
	metrics.merge({
		"transport_pressure": (
			0.0 if _resource_tick == null else _resource_tick.transport_pressure
		),
		"transport_coverage": (
			0.0 if _resource_tick == null else _resource_tick.transport_coverage
		),
		"signal_coverage": (
			0.0 if _resource_tick == null else _resource_tick.signal_coverage
		),
		"organ_transport_coverage": (
			{} if _resource_tick == null else _resource_tick.organ_transport_coverage
		),
		"edge_flow_by_id": (
			{} if _resource_tick == null else _resource_tick.settled_edge_flow
		),
		"delivered_development_signal_by_organ": (
			{}
			if _resource_tick == null
			else _resource_tick.settled_delivered_development_signal
		),
		"required_development_signal_by_organ": required_signal,
		"weakest_signal_edge_by_organ": weakest_edges,
		"organ_waste_generation": waste_generation,
		"organ_waste_processing": waste_processing,
		"waste": 0.0 if _resources == null else _resources.waste,
		"stability": 0.0 if _resources == null else _resources.stability,
		"net_waste_rate": (
			float(Balance.get_value("resources.waste.accumulation_per_tick", 0.0))
			+ _sum_values(waste_generation)
			- _sum_values(waste_processing)
		),
	}, true)
	return metrics


func birth_metrics() -> Dictionary:
	var built_ids: Array[StringName] = []
	for organ in _built_organs:
		built_ids.append(StringName(organ.get("organ_id", "")))
	var required: Array[StringName] = []
	var configured: Variant = Balance.get_value(
		"chapters.stage_birth.required_organ_ids",
		[]
	)
	if configured is Array:
		for organ_id in configured:
			required.append(StringName(organ_id))
	var ready_count := 0
	for organ_id in required:
		if built_ids.has(organ_id):
			ready_count += 1
	return {
		&"transport_coverage": (
			0.0 if _resource_tick == null else _resource_tick.transport_coverage
		),
		&"waste": 0.0 if _resources == null else _resources.waste,
		&"stability": 0.0 if _resources == null else _resources.stability,
		&"signal_coverage": (
			0.0 if _resource_tick == null else _resource_tick.signal_coverage
		),
		&"pulmonary_system_readiness": (
			0.0
			if required.is_empty()
			else float(ready_count) / float(required.size())
		),
	}


func show_birth_gate_report(report: Dictionary, retry_available: bool) -> void:
	_birth_gate_report = report.duplicate(true)
	_birth_retry_available = retry_available
	_refresh()
	visual_state_changed.emit()


func _on_stage_loaded(_stage_id: StringName, _stage_index: int) -> void:
	if _flow == null or _flow.chapter == null:
		return
	_resource_settled = false
	_build_presented_id = &""
	_selected_build_option_id = &""
	_operation_presented_id = &""
	_minigame_progress = 0.0
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
	_refresh_birth_art()
	if _flow.is_run_complete():
		_title.text = "Run Complete"
		if _birth_gate_report.is_empty():
			_body.text = "All four development stages are complete. Evaluating birth readiness."
		else:
			var passed := bool(_birth_gate_report.get("passed", false))
			_body.text = (
				"Birth readiness passed. The transition is in progress."
				if passed
				else "Birth readiness needs recovery before the transition can continue."
			)
		if _birth_retry_available:
			_add_action_button(
				"RecoverBirth",
				"Run Recovery Cycle",
				_recover_birth_readiness
			)
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
			_activate_stage_art()
			_body.text = "The new system is active and collaborating with the city."
			_add_continue_button()
		&"knowledge_unlock":
			_body.text = "A knowledge entry has been unlocked for this stage."
			_add_continue_button()
		&"stage_complete":
			_body.text = "Stage requirements are complete. Continue to the next stage."
			_add_continue_button()


func _refresh_birth_art() -> void:
	if _birth_art == null:
		return
	if not _flow.is_run_complete():
		_birth_art.call("hide_frame")


func _recover_birth_readiness() -> void:
	if not _birth_retry_available:
		return
	var option_path := "operations.options.waste_priority"
	var cost := _dictionary_value("%s.cost" % option_path)
	var outcome := _dictionary_value("%s.outcome" % option_path)
	var allocation := _dictionary_value("%s.allocation_weights" % option_path)
	var before := _resource_snapshot()
	var prepared := before.duplicate(true)
	var tick_delta := maxf(
		float(Balance.get_value("tick_interval_sec", 1.0)),
		0.001
	)
	_resource_tick.initialize_from_balance(prepared)
	var wait_ticks := 0
	while not _can_afford_recovery(prepared, cost) and wait_ticks < 120:
		var wait_result := _resource_tick.settle_tick(
			tick_delta,
			_settlement_input()
		)
		_apply_resource_snapshot(wait_result)
		prepared = _resource_snapshot()
		wait_ticks += 1
	var can_operate := _can_afford_recovery(prepared, cost)
	if can_operate:
		for resource_id in [
			&"nutrient_energy",
			&"cell_material",
			&"development_signal",
		]:
			prepared[resource_id] = (
				float(prepared[resource_id])
				- float(cost.get(resource_id, 0.0))
			)
		prepared[&"waste"] = clampf(
			float(prepared[&"waste"]) + float(outcome.get("waste", 0.0)),
			0.0,
			100.0
		)
		prepared[&"stability"] = clampf(
			float(prepared[&"stability"]) + float(outcome.get("stability", 0.0)),
			0.0,
			100.0
		)

	_resource_tick.initialize_from_balance(prepared)
	var settlement_input := _settlement_input()
	if can_operate:
		settlement_input["operation_id"] = &"waste_priority"
		_apply_operation_allocation(settlement_input, allocation)
	var settled := _resource_tick.settle_tick(tick_delta, settlement_input)
	_apply_resource_snapshot(settled)
	_sync_resource_bar()
	_request_birth_retry()


func _can_afford_recovery(resources: Dictionary, cost: Dictionary) -> bool:
	for resource_id in [
		&"nutrient_energy",
		&"cell_material",
		&"development_signal",
	]:
		if float(resources.get(resource_id, 0.0)) < float(cost.get(resource_id, INF)):
			return false
	return true


func _activate_stage_art() -> void:
	if _city_art == null:
		return
	for organ in _built_organs:
		if StringName(organ.get("stage_id", &"")) == _flow.chapter.stage_id:
			_city_art.set_organ_state(
				StringName(organ.get("organ_id", &"")),
				&"operating"
			)


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
			_body.text += "\nProgress: %.0f%%" % (
				_minigame_runtime.completion_accuracy() * 100.0
			)
			_add_action_button("ProgressTask", "Perform Task", _progress_minigame)
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
	_refresh_option_preview(decision_id)

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
	_minigame_progress = 0.0
	if _minigame_runtime.begin(
		_flow.chapter.stage_minigame_id,
		_flow.chapter.stage_id
	):
		_refresh()


func _progress_minigame() -> void:
	_minigame_progress += 1.0
	_minigame_runtime.report_progress(_minigame_progress)
	_refresh()


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
		_settlement_input()
	)
	var reward := _minigame_runtime.pending_reward()
	for resource_id in RESOURCE_IDS:
		if not reward.has(resource_id):
			continue
		if resource_id == &"knowledge_badge_count":
			settled[resource_id] = (
				int(settled.get(resource_id, 0))
				+ int(reward[resource_id])
			)
		else:
			settled[resource_id] = (
				float(settled.get(resource_id, 0.0))
				+ float(reward[resource_id])
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
	if _grid_manager != null:
		_grid_manager.present_candidates(
			_flow.chapter.active_build_decision_id,
			option_id,
			_grid_manager.occupied_cells(),
			[]
		)
	_refresh()


func _choose_build_slot(slot_id: StringName) -> void:
	_build_decision.select_candidate(_selected_build_option_id, slot_id)
	_feedback.text = _build_decision.feedback_text()
	_refresh()


func _confirm_build() -> void:
	var decision_id := _flow.chapter.active_build_decision_id
	var option_id := _flow.chapter.selected_build_option_id
	var slot_id := _flow.chapter.selected_build_slot_id
	var confirmed := _build_decision.request_confirmation()
	if confirmed:
		_register_built_organ(decision_id, option_id, slot_id)
		_sync_resource_bar()
	elif (
		_city_art != null
		and option_id != &""
		and slot_id != &""
	):
		var preview_organ_id := StringName(
			str(decision_id).trim_prefix("build_")
		)
		var preview_config := _dictionary_value(
			"organs.%s" % preview_organ_id
		)
		_city_art.place_organ(
			preview_organ_id,
			_slot_grid_origin(decision_id, option_id, slot_id),
			StringName(
				preview_config.get("footprint_id", &"standard_building")
			),
			&"blueprint"
		)
	_feedback.text = _build_decision.feedback_text()
	_refresh()
	visual_state_changed.emit()


func _choose_operation(option_id: StringName) -> void:
	_operation_decision.select_priority(option_id)
	_feedback.text = _operation_decision.feedback_text()
	_refresh()


func _confirm_operation() -> void:
	var confirmed := _operation_decision.request_confirmation(
		_settlement_input()
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
	_title.add_theme_font_size_override("font_size", 20)
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
	button.add_to_group(InputLock.LOCKABLE_GROUP)
	button.add_to_group("tutorial_target_build_candidate_cards")
	button.pressed.connect(handler, CONNECT_DEFERRED)
	_options.add_child(button)


func _add_slot_button(slot_id: StringName, handler: Callable) -> void:
	var button := Button.new()
	button.name = "Slot_%s" % slot_id
	button.text = _display_name(slot_id)
	button.add_to_group(InputLock.LOCKABLE_GROUP)
	button.add_to_group("tutorial_target_build_candidate_cards")
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
	button.add_to_group(InputLock.LOCKABLE_GROUP)
	if button_name == "ConfirmOperation":
		button.add_to_group("tutorial_target_resource_allocation_entry")
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


func _request_birth_retry() -> void:
	_birth_retry_available = false
	birth_retry_requested.emit()
	_refresh()
	visual_state_changed.emit()


func _refresh_option_preview(decision_id: StringName) -> void:
	if _option_preview == null:
		return
	var contexts: Dictionary = {}
	for option_id in _flow.chapter.available_build_option_ids:
		var slots := _string_name_array(
			Balance.get_value(
				"build_options.%s.%s.available_slot_ids"
				% [decision_id, option_id],
				[]
			)
		)
		for slot_id in slots:
			contexts[slot_id] = {
				"decision_id": decision_id,
				"option_id": option_id,
			}
	_option_preview.set_candidates(contexts)


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


func _settlement_input() -> Dictionary:
	var nodes: Array = [] if _network_builder == null else _network_builder.nodes
	var edges: Array = [] if _network_builder == null else _network_builder.edges
	var requested_flow: Dictionary = {}
	var requested_signal: Dictionary = {}
	var satisfaction: Dictionary = {}
	for organ in _built_organs:
		var organ_id := StringName(organ.get("organ_id", ""))
		requested_flow[organ_id] = float(organ.get("required_flow", 0.0))
		requested_signal[organ_id] = float(
			organ.get("required_development_signal", 0.0)
		)
		satisfaction[organ_id] = 1.0
	var transport_capacity := 0.0
	for edge in edges:
		transport_capacity += float(edge.get("effective_capacity", 0.0))
	var waste_processing_capacity := 0.0
	for organ in _built_organs:
		if StringName(organ.get("state", organ.get("state_id", ""))) != &"operating":
			continue
		var organ_id := StringName(organ.get("organ_id", ""))
		waste_processing_capacity += (
			float(
				Balance.get_value(
					"organs.%s.per_tick_consumption.waste" % organ_id,
					0.0
				)
			)
			* maxf(float(organ.get("active_multiplier", 1.0)), 0.0)
			* maxf(float(organ.get("tier_multiplier", 1.0)), 0.0)
		)
	var source_ids: Array[StringName] = []
	for node in nodes:
		if int(node.get("sequence", -1)) == 0:
			source_ids.append(StringName(node.get("node_id", "")))
	return {
		"organs": _built_organs.duplicate(true),
		"required_organ_ids": _flow.chapter.required_organ_ids.duplicate(),
		"nodes": nodes,
		"edges": edges,
		"source_node_ids": source_ids,
		"requested_flow_by_organ": requested_flow,
		"available_transport_flow": transport_capacity,
		"requested_development_signal_by_organ": requested_signal,
		"available_development_signal_flow": maxf(
			float(_resources.development_signal),
			0.0
		),
		"available_waste_processing": waste_processing_capacity,
		"resource_satisfaction_by_organ": satisfaction,
		"intervention_waste_removal": 0.0,
	}


func _apply_operation_allocation(
	settlement_input: Dictionary,
	allocation: Dictionary
) -> void:
	settlement_input["operation_allocation"] = allocation.duplicate(true)
	if settlement_input.has("available_transport_flow"):
		settlement_input["available_transport_flow"] = (
			float(settlement_input["available_transport_flow"])
			* float(allocation.get("transport", 0.0))
		)
	if settlement_input.has("available_development_signal_flow"):
		settlement_input["available_development_signal_flow"] = (
			float(settlement_input["available_development_signal_flow"])
			* float(allocation.get("signal", 0.0))
		)
	if settlement_input.has("available_waste_processing"):
		settlement_input["intervention_waste_removal"] = (
			float(settlement_input.get("intervention_waste_removal", 0.0))
			+ float(settlement_input["available_waste_processing"])
			* float(allocation.get("waste", 0.0))
		)


func _register_built_organ(
	decision_id: StringName,
	option_id: StringName,
	slot_id: StringName
) -> void:
	var organ_id := StringName(str(decision_id).trim_prefix("build_"))
	var organ_config := _dictionary_value("organs.%s" % organ_id)
	var cells: Array[Vector2i] = []
	if _grid_manager != null:
		cells = _grid_manager.commit_slot(decision_id, option_id, slot_id)
	var grid_position := Vector2i.ZERO if cells.is_empty() else cells[0]
	var organ := organ_config.duplicate(true)
	organ["organ_id"] = organ_id
	organ["stage_id"] = _flow.chapter.stage_id
	organ["state"] = &"operating"
	organ["state_id"] = &"operating"
	organ["grid_position"] = grid_position
	organ["grid_origin"] = grid_position
	organ["active_multiplier"] = 1.0
	organ["tier_multiplier"] = 1.0
	_built_organs.append(organ)
	if _city_art != null:
		_city_art.place_organ(
			organ_id,
			grid_position,
			StringName(organ.get("footprint_id", &"standard_building")),
			&"under_construction"
		)
	EventBus.organ_built.emit(organ_id, slot_id, option_id)


func _slot_grid_origin(
	decision_id: StringName,
	option_id: StringName,
	slot_id: StringName
) -> Vector2i:
	var option_path := "build_options.%s.%s" % [decision_id, option_id]
	var slot_ids: Variant = Balance.get_value(
		"%s.available_slot_ids" % option_path,
		[]
	)
	var coordinates: Variant = Balance.get_value(
		"%s.slot_candidates" % option_path,
		[]
	)
	if not slot_ids is Array or not coordinates is Array:
		return Vector2i.ZERO
	var index := (slot_ids as Array).find(String(slot_id))
	if index < 0 or index >= (coordinates as Array).size():
		return Vector2i.ZERO
	var coordinate: Variant = (coordinates as Array)[index]
	if not coordinate is Array or coordinate.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(coordinate[0]), int(coordinate[1]))


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


func _sum_values(values: Dictionary) -> float:
	var total := 0.0
	for value in values.values():
		total += float(value)
	return total
