class_name GameAssembly
extends Node

## Lifecycle and integration layer for the playable game scene.
##
## GameplayController is the sole owner of player input, visible action
## presentation, build/operation decisions, minigames, and resource settlement.
## This node adopts those live systems and wires the lifecycle that surrounds
## them: bottlenecks, organ cooperation, carryover, birth, ending, input lock,
## and the event-driven auxiliary UI.

const LOG_PREFIX := "[ASSEMBLY]"

signal integration_failed(reason: String)

var flow: ChapterFlow = null
var resources: ResourcePool = null
var controller: GameplayController = null
var grid_manager: GridManager = null
var network_builder: NetworkBuilder = null

var resource_tick: ResourceTick = null
var threshold_watcher: ThresholdWatcher = null
var bottleneck_detector: BottleneckDetector = null
var organ_state: OrganStateMachine = null
var organ_check: OrganCheck = null
var network_intervention: NetworkIntervention = null
var carryover: Carryover = null
var game_state: GameState = null
var birth_check: BirthCheck = null
var birth_machine: BirthMachine = null
var ending: Ending = null
var input_lock: InputLock = null

var timeline_panel: TimelinePanel = null
var minigame_panel: MinigamePanel = null
var info_containers: InfoContainers = null
var chapter_summary: ChapterSummary = null
var option_preview: OptionPreview = null
var tutorial: Tutorial = null
var hint_system: HintSystem = null

var _assembled := false
var _bottleneck_evaluations := 0
var _organ_observations := 0
var _carryover_applications := 0
var _birth_attempts := 0


func configure(
	chapter_flow: ChapterFlow,
	resource_pool: ResourcePool,
	gameplay_controller: GameplayController,
	city_grid: GridManager,
	city_network: NetworkBuilder
) -> bool:
	if _assembled:
		push_warning("%s Already configured." % LOG_PREFIX)
		return false
	if (
		chapter_flow == null
		or resource_pool == null
		or gameplay_controller == null
		or city_grid == null
		or city_network == null
	):
		return _fail("A required main-scene dependency is missing.")

	flow = chapter_flow
	resources = resource_pool
	controller = gameplay_controller
	grid_manager = city_grid
	network_builder = city_network
	resource_tick = controller.resource_tick_system()
	threshold_watcher = controller.threshold_watcher_system()
	if resource_tick == null or threshold_watcher == null:
		return _fail("GameplayController did not expose its settlement systems.")

	_build_lifecycle_systems()
	_build_auxiliary_ui()
	_connect_lifecycle()
	_assembled = true
	print("%s Lifecycle integration ready; GameplayController remains the input owner." % LOG_PREFIX)
	return true


func is_assembled() -> bool:
	return _assembled


func integration_snapshot() -> Dictionary:
	return {
		"assembled": _assembled,
		"bottleneck_evaluations": _bottleneck_evaluations,
		"active_bottlenecks": (
			{} if bottleneck_detector == null else bottleneck_detector.active_results
		),
		"organ_observations": _organ_observations,
		"carryover_applications": _carryover_applications,
		"birth_attempts": _birth_attempts,
		"birth_state": (
			&"unavailable"
			if birth_machine == null
			else birth_machine.current_state_id()
		),
		"ending_complete": ending != null and ending.is_ended(),
	}


func reevaluate_bottlenecks() -> Array[Dictionary]:
	if not _assembled or flow.chapter == null:
		return []
	_bottleneck_evaluations += 1
	return bottleneck_detector.evaluate(
		flow.current_stage_id(),
		controller.lifecycle_metrics()
	)


func retry_birth() -> bool:
	if (
		birth_machine == null
		or birth_machine.current_state() != BirthMachine.State.FAILURE_ROLLBACK
	):
		return false
	birth_machine.city_metrics = controller.birth_metrics()
	_birth_attempts += 1
	return birth_machine.acknowledge_rollback()


func _process(_delta: float) -> void:
	if (
		ending != null
		and not ending.is_ended()
		and birth_machine != null
		and birth_machine.first_breath_complete
	):
		ending.try_close()


func _build_lifecycle_systems() -> void:
	bottleneck_detector = BottleneckDetector.new()
	bottleneck_detector.configure(Balance, EventBus)

	organ_state = OrganStateMachine.new()
	organ_state.name = "OrganState"
	add_child(organ_state)
	organ_state.configure(Balance, EventBus)

	organ_check = OrganCheck.new()
	organ_check.configure(Balance, EventBus)

	network_intervention = NetworkIntervention.new()
	network_intervention.configure(Balance, EventBus)

	game_state = GameState.new()
	game_state.name = "GameState"
	game_state.save_version = int(Balance.get_value("save.version", 0))
	var initial_progress: Variant = Balance.get_value("progress.initial", {})
	game_state.main_progress = (
		initial_progress.duplicate(true)
		if initial_progress is Dictionary
		else {}
	)
	game_state.current_city_state = {
		"resources": controller.resource_snapshot(),
		"organs": [],
		"network": {},
		"chapter": {},
	}
	game_state.chapter_snapshots = {}
	add_child(game_state)

	carryover = Carryover.new()
	carryover.name = "Carryover"
	add_child(carryover)
	carryover.configure(Balance, EventBus, game_state)

	birth_check = BirthCheck.new()
	birth_check.configure(Balance, EventBus)

	birth_machine = BirthMachine.new()
	birth_machine.name = "BirthMachine"
	birth_machine.birth_check = birth_check
	add_child(birth_machine)

	ending = Ending.new()
	ending.name = "Ending"
	ending.chapter_flow = flow
	ending.birth_machine = birth_machine
	ending.freeze_targets = [controller]
	add_child(ending)

	input_lock = InputLock.new()
	input_lock.name = "InputLock"
	add_child(input_lock)


func _build_auxiliary_ui() -> void:
	timeline_panel = TimelinePanel.new()
	timeline_panel.name = "TimelinePanel"
	timeline_panel.birth_check = birth_check
	_mount_panel(timeline_panel, "DevelopmentTimeline")

	minigame_panel = MinigamePanel.new()
	minigame_panel.name = "MinigamePanel"
	_mount_panel(minigame_panel, "TaskOperationsPanel")
	var auxiliary_skip := minigame_panel.find_child("SkipTask", true, false)
	if auxiliary_skip != null:
		auxiliary_skip.name = "AuxiliarySkipTask"
		(auxiliary_skip as BaseButton).disabled = true
	var auxiliary_entry := minigame_panel.find_child("EnterTask", true, false)
	if auxiliary_entry != null:
		auxiliary_entry.name = "AuxiliaryEnterTask"
		(auxiliary_entry as BaseButton).disabled = true

	info_containers = InfoContainers.new()
	info_containers.name = "InfoContainers"
	_mount_panel(info_containers, "GuidanceLayer")

	chapter_summary = ChapterSummary.new()
	chapter_summary.name = "ChapterSummary"
	_mount_panel(chapter_summary, "GuidanceLayer")

	option_preview = OptionPreview.new()
	option_preview.name = "OptionPreview"
	option_preview.position = Vector2(432, 112)
	_mount_panel(option_preview, "GuidanceLayer")
	controller.attach_option_preview(option_preview)

	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	_mount_panel(tutorial, "GuidanceLayer")

	hint_system = HintSystem.new()
	hint_system.name = "HintSystem"
	_mount_panel(hint_system, "GuidanceLayer")

	# TimelinePanel and MinigamePanel are event-active specification surfaces.
	# Their content duplicates the compact playable panel, so the controller keeps
	# them hidden until a dedicated layout pass gives them non-overlapping space.
	timeline_panel.visible = false
	minigame_panel.visible = false


func _mount_panel(panel: Control, region_name: String) -> void:
	var game := get_parent()
	var region := null if game == null else game.get_node_or_null(region_name)
	if region == null:
		push_warning("%s Missing UI region '%s'; mounting under lifecycle node." % [LOG_PREFIX, region_name])
		add_child(panel)
		return
	region.add_child(panel)


func _connect_lifecycle() -> void:
	flow.register_step_handler(
		ChapterFlow.Step.OBSERVE_STATE,
		_on_observe_state
	)
	flow.register_step_handler(
		ChapterFlow.Step.SYSTEM_ACTIVATION,
		_on_system_activation
	)
	flow.register_step_handler(
		ChapterFlow.Step.KNOWLEDGE_UNLOCK,
		_on_knowledge_unlock
	)
	flow.register_step_handler(
		ChapterFlow.Step.STAGE_COMPLETE,
		_on_stage_complete
	)
	flow.register_carryover_handlers(
		_generate_carryover,
		_apply_carryover
	)
	flow.run_completed.connect(_on_run_completed)
	controller.birth_retry_requested.connect(retry_birth)
	EventBus.resources_settled.connect(_on_resources_settled)
	EventBus.operation_result_settled.connect(_on_operation_result_settled)
	EventBus.organ_built.connect(_on_organ_built)
	EventBus.birth_rolled_back.connect(_on_birth_rolled_back)
	EventBus.birth_sequence_completed.connect(_on_birth_sequence_completed)
	EventBus.stage_loaded.connect(_on_auxiliary_stage_loaded)


func _on_observe_state() -> void:
	reevaluate_bottlenecks()
	timeline_panel.refresh()
	minigame_panel.refresh()
	timeline_panel.hide()
	minigame_panel.hide()


func _on_auxiliary_stage_loaded(
	_stage_id: StringName,
	_stage_index: int
) -> void:
	timeline_panel.hide()
	minigame_panel.hide()


func _on_system_activation() -> void:
	var decision_id := flow.chapter.active_build_decision_id
	if decision_id == &"":
		flow.chapter.system_observation_complete = true
		return
	var report := organ_check.check_and_observe(
		decision_id,
		flow.current_stage_id(),
		_observation_context()
	)
	if bool(report.get("observation_started", false)):
		organ_check.complete_observation()
		_organ_observations += 1
	flow.chapter.system_observation_complete = organ_check.can_advance()
	if not flow.chapter.system_observation_complete:
		push_warning(
			"%s Organ observation is still pending for '%s': %s"
			% [LOG_PREFIX, decision_id, report]
		)


func _on_knowledge_unlock() -> void:
	var decision_id := flow.chapter.active_build_decision_id
	var organ_id := StringName(str(decision_id).trim_prefix("build_"))
	EventBus.knowledge_entry_unlocked.emit(
		StringName("entry_%s" % organ_id),
		organ_id,
		flow.current_stage_id()
	)
	flow.chapter.knowledge_unlock_resolved = true


func _on_stage_complete() -> void:
	reevaluate_bottlenecks()


func _generate_carryover(
	from_stage_id: StringName,
	to_stage_id: StringName
) -> Dictionary:
	return carryover.generate_transition_record(
		from_stage_id,
		to_stage_id,
		controller.build_decision_records(),
		controller.operation_settlement_snapshot()
	)


func _apply_carryover(
	from_stage_id: StringName,
	to_stage_id: StringName,
	record: Dictionary
) -> void:
	if record.is_empty():
		push_error("%s Carryover generation failed for %s -> %s." % [LOG_PREFIX, from_stage_id, to_stage_id])
		return
	if not carryover.commit_first_visit(from_stage_id, to_stage_id, record):
		return
	controller.apply_stage_start_conditions(record)
	if carryover.complete_runtime_application(
		from_stage_id,
		to_stage_id,
		controller.stage_start_conditions_readback()
	):
		_carryover_applications += 1
		var destination_snapshot: Dictionary = game_state.chapter_snapshots.get(
			to_stage_id,
			{}
		)
		SaveManager.record_stage_snapshot(to_stage_id, destination_snapshot)
		SaveManager.set_current_city_state(game_state.current_city_state)


func _on_resources_settled(
	_stage_id: StringName,
	_deltas: Dictionary,
	_totals: Dictionary
) -> void:
	reevaluate_bottlenecks()


func _on_operation_result_settled(
	_decision_id: StringName,
	_outcome: Dictionary
) -> void:
	reevaluate_bottlenecks()


func _on_organ_built(
	organ_id: StringName,
	_slot_id: StringName,
	_option_id: StringName
) -> void:
	organ_state.adopt_operating_organ(organ_id)


func _on_run_completed(_final_stage_id: StringName) -> void:
	if birth_machine.current_state() != BirthMachine.State.IDLE:
		return
	_birth_attempts += 1
	birth_machine.city_metrics = controller.birth_metrics()
	birth_machine.start()


func _on_birth_rolled_back(
	_from_state: int,
	_reason_code: StringName
) -> void:
	controller.show_birth_gate_report(birth_machine.gate_report, true)


func _on_birth_sequence_completed(_stage_id: StringName) -> void:
	controller.show_birth_gate_report(birth_machine.gate_report, false)


func _observation_context() -> Dictionary:
	var metrics := controller.lifecycle_metrics()
	var organ_states: Dictionary = {}
	var active_ids: Array[StringName] = []
	var upstream: Dictionary = {}
	var transfer: Dictionary = {}
	var metric_change: Dictionary = {}
	var coverage_by_organ: Dictionary = metrics.get(
		"organ_transport_coverage",
		{}
	).duplicate(true)
	for organ in controller.built_organs_snapshot():
		var organ_id := StringName(organ.get("organ_id", ""))
		organ_states[organ_id] = &"operating"
		active_ids.append(organ_id)
		var coverage := float(
			coverage_by_organ.get(
				organ_id,
				metrics.get("transport_coverage", 0.0)
			)
		)
		coverage_by_organ[organ_id] = coverage
		upstream[organ_id] = coverage > 0.0
		transfer[organ_id] = coverage > 0.0
		metric_change[organ_id] = not controller.operation_settlement_snapshot().is_empty()
	var path_ids: Array[StringName] = []
	for edge in metrics.get("edges", []):
		var edge_id := StringName(edge.get("edge_id", ""))
		if not edge_id.is_empty():
			path_ids.append(edge_id)
	return {
		"organ_states": organ_states,
		"active_organ_ids": active_ids,
		"organ_transport_coverage": coverage_by_organ,
		"upstream_resources_sufficient_by_organ": upstream,
		"observed_runtime_transfer": transfer,
		"observed_metric_change": metric_change,
		"blocking_modal_open": false,
		"resource_path_edge_ids": path_ids,
		"archive_entry_id": StringName(
			"entry_%s" % str(flow.chapter.active_build_decision_id).trim_prefix("build_")
		),
	}


func _fail(reason: String) -> bool:
	push_error("%s %s" % [LOG_PREFIX, reason])
	integration_failed.emit(reason)
	return false
