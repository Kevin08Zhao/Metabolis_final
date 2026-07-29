class_name GameAssembly
extends Control

## Assembles the accepted scripts into a game that runs.
##
## Every system and panel in this repository was delivered and accepted on its
## own, and until now nothing put them together: only the boot scene carried a
## script, no script instantiated another system, and all ten steps of
## ChapterFlow called placeholders that returned immediately. This node is the
## missing wiring, and only the wiring. It implements no rule, owns no value, and
## replaces no task's logic.
##
## Three things happen here and nothing else.
##
##   1. Construction. Each system is instantiated once and handed its
##      dependencies through the `configure` entry point it already declared.
##      Nothing is subclassed and no system is modified.
##   2. Attachment. The panels are added to the six regions of section 2 of
##      docs/UI_LAYOUT.md, which src/game/main.tscn reserves by name.
##   3. Driving. A handler is registered for each of the ten steps in table C1 of
##      docs/CHAPTER_FLOW_STEPS.md, delegating to the system that table names.
##      The flow's own exit conditions still decide when a step may be left, so
##      the loop is gated by the same booleans it always was.
##
## The player-facing entry points stay on the systems that own them. This node
## exposes `choose_build_option`, `choose_operation_priority` and the two
## confirmations because a caller needs somewhere to send a click, but each one
## forwards to BuildDecision or OperationDecision and adds no rule of its own.
##
## Where a step's owning task left a stub, the step is driven as far as that stub
## allows and the shortfall is reported by `unimplemented_steps` rather than
## papered over. An assembly that silently invented the missing half would be
## worse than one that says which half is missing.
##
## Requires the `EventBus`, `Balance`, `SaveManager`, `AudioRouter` and
## `AssetLoader` autoloads.

const LOG_PREFIX := "[ASSEMBLY]"

## Region names src/game/main.tscn reserves, and the panel each receives.
const REGION_BY_PANEL := {
	&"resource_bar": "ResourceStatusBar",
	&"timeline_panel": "DevelopmentTimeline",
	&"minigame_panel": "TaskOperationsPanel",
	&"info_containers": "OrganArchiveButton",
	&"chapter_summary": "ChapterRecapButton",
	&"option_preview": "CityMap",
	&"tutorial": "GuidanceLayer",
	&"hint_system": "GuidanceLayer",
}

## Emitted once the whole run reaches its terminal state.
signal run_finished(final_stage_id: StringName)

## Emitted when a step ran but its owning task could only go part of the way.
signal step_incomplete(step_id: StringName, reason: String)

# The flow, and the state it drives.
var flow: ChapterFlow = null
var resources: ResourcePool = null

# Systems, in the order table C1 reaches them.
var resource_tick: ResourceTick = null
var threshold_watcher: ThresholdWatcher = null
var bottleneck_detector: BottleneckDetector = null
var build_decision: BuildDecision = null
var operation_decision: OperationDecision = null
var organ_state: OrganStateMachine = null
var organ_check: OrganCheck = null
var network_builder: NetworkBuilder = null
var network_coverage: NetworkCoverage = null
var network_intervention: NetworkIntervention = null
var carryover: Carryover = null
var minigame: MinigameRuntime = null
var birth_check: BirthCheck = null
var birth_machine: BirthMachine = null
var ending: Ending = null

# Panels.
var resource_bar: ResourceBar = null
var timeline_panel: TimelinePanel = null
var minigame_panel: MinigamePanel = null
var info_containers: InfoContainers = null
var chapter_summary: ChapterSummary = null
var option_preview: OptionPreview = null
var tutorial: Tutorial = null
var hint_system: HintSystem = null
var input_lock: InputLock = null

var _incomplete: Dictionary = {}
var _build_records: Dictionary = {}
var _operation_settlement: Dictionary = {}
var _assembled: bool = false
var _presented_build_decision_id: StringName = &""


func _ready() -> void:
	assemble()


## Build everything and register the ten handlers. Safe to call once; a second
## call is refused rather than duplicating the tree.
func assemble() -> bool:
	if _assembled:
		push_warning("%s Already assembled." % LOG_PREFIX)
		return false

	_build_state()
	_build_systems()
	_build_panels()
	_attach_panels()
	_register_handlers()
	_assembled = true
	print("%s assembled %d systems and %d panels." % [LOG_PREFIX, 15, 9])
	return true


func is_assembled() -> bool:
	return _assembled


# ---------------------------------------------------------------------------
# 1 · Construction
# ---------------------------------------------------------------------------

func _build_state() -> void:
	resources = ResourcePool.new()
	# T-09 left initialize_from_balance a stub, so the opening values are read
	# here from the same paths that stub would have read. Nothing is invented:
	# every one of them is a configured key.
	resources.nutrient_energy = float(Balance.get_value("resources.nutrient_energy.initial", 0.0))
	resources.cell_material = float(Balance.get_value("resources.cell_material.initial", 0.0))
	resources.development_signal = float(Balance.get_value("resources.development_signal.initial", 0.0))
	resources.waste = float(Balance.get_value("resources.waste.initial", 0.0))
	resources.stability = float(Balance.get_value("resources.stability.initial", 0.0))
	resources.knowledge_badge_count = int(Balance.get_value("resources.knowledge_badge_count.initial", 0))
	_note_incomplete(&"resource_pool", "T-09 initialize_from_balance is a stub; the assembly seeds the six values from Balance directly.")

	flow = ChapterFlow.new()
	flow.name = "ChapterFlow"
	add_child(flow)
	flow.run_completed.connect(_on_run_completed)


func _build_systems() -> void:
	network_coverage = NetworkCoverage.new()
	network_coverage.configure(Balance)

	resource_tick = ResourceTick.new()
	resource_tick.configure(Balance, network_coverage)
	resource_tick.initialize_from_balance()

	threshold_watcher = ThresholdWatcher.new()
	threshold_watcher.configure(Balance, EventBus)
	threshold_watcher.initialize(_resource_values())

	bottleneck_detector = BottleneckDetector.new()
	bottleneck_detector.configure(Balance, EventBus)

	build_decision = BuildDecision.new()
	build_decision.configure(Balance, EventBus, flow.chapter, resources)

	operation_decision = OperationDecision.new()
	operation_decision.configure(
		Balance, EventBus, flow.chapter, resources, resource_tick, threshold_watcher
	)

	organ_state = OrganStateMachine.new()
	organ_state.configure(Balance, EventBus)

	organ_check = OrganCheck.new()
	organ_check.configure(Balance, EventBus)

	network_builder = NetworkBuilder.new()
	network_builder.configure(Balance, EventBus)

	network_intervention = NetworkIntervention.new()
	network_intervention.configure(Balance, EventBus)

	carryover = Carryover.new()
	carryover.configure(Balance, EventBus, SaveManager)

	minigame = MinigameRuntime.new()
	minigame.name = "MinigameRuntime"
	add_child(minigame)

	birth_check = BirthCheck.new()
	birth_check.configure(Balance, EventBus)

	birth_machine = BirthMachine.new()
	birth_machine.name = "BirthMachine"
	add_child(birth_machine)

	ending = Ending.new()
	ending.name = "Ending"
	add_child(ending)


func _build_panels() -> void:
	resource_bar = ResourceBar.new()
	timeline_panel = TimelinePanel.new()
	timeline_panel.birth_check = birth_check
	minigame_panel = MinigamePanel.new()
	info_containers = InfoContainers.new()
	chapter_summary = ChapterSummary.new()
	option_preview = OptionPreview.new()
	tutorial = Tutorial.new()
	hint_system = HintSystem.new()

	input_lock = InputLock.new()
	input_lock.name = "InputLock"
	add_child(input_lock)


## Panels go into the regions src/game/main.tscn reserves. A missing region is
## reported rather than silently skipped, because a panel with nowhere to live
## is invisible and would look like a panel that does not work.
func _attach_panels() -> void:
	for key in REGION_BY_PANEL:
		var panel: Control = get(String(key))
		if panel == null:
			continue
		panel.name = String(key).to_pascal_case()
		var region_name: String = REGION_BY_PANEL[key]
		var region := _region(region_name)
		if region == null:
			_note_incomplete(
				key,
				"src/game/main.tscn has no region named %s, so this panel is not on screen." % region_name
			)
			add_child(panel)
			continue
		region.add_child(panel)


func _region(region_name: String) -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(NodePath(region_name))


# ---------------------------------------------------------------------------
# 2 · The ten handlers
#
# One per row of table C1 of docs/CHAPTER_FLOW_STEPS.md, delegating to the task
# that table names. None of them decides when its step may be left; the flow's
# own exit conditions still do that.
# ---------------------------------------------------------------------------

func _register_handlers() -> void:
	flow.register_step_handler(ChapterFlow.Step.OBSERVE_STATE, _step_observe_state)
	flow.register_step_handler(ChapterFlow.Step.RECEIVE_TARGETS, _step_receive_targets)
	flow.register_step_handler(ChapterFlow.Step.OPTIONAL_MINIGAME, _step_optional_minigame)
	flow.register_step_handler(ChapterFlow.Step.RESOURCE_SETTLEMENT, _step_resource_settlement)
	flow.register_step_handler(ChapterFlow.Step.BUILD_DECISION, _step_build_decision)
	flow.register_step_handler(ChapterFlow.Step.BUILD_COMPLETION, _step_build_completion)
	flow.register_step_handler(ChapterFlow.Step.OPERATION_DECISION, _step_operation_decision)
	flow.register_step_handler(ChapterFlow.Step.SYSTEM_ACTIVATION, _step_system_activation)
	flow.register_step_handler(ChapterFlow.Step.KNOWLEDGE_UNLOCK, _step_knowledge_unlock)
	flow.register_step_handler(ChapterFlow.Step.STAGE_COMPLETE, _step_stage_complete)


## Step 1, T-29 and T-19g. Refresh the readings and let the detector look at the
## current metrics; both are display, and neither gates.
func _step_observe_state() -> void:
	_rebind_decision_systems()
	if resource_bar != null:
		resource_bar.set_resources(_resource_values())
	if timeline_panel != null:
		timeline_panel.refresh()
	if minigame_panel != null:
		minigame_panel.refresh()
	bottleneck_detector.evaluate(flow.current_stage_id(), _current_metrics())


## Step 2, T-13 and T-13a. Table C1 closes this step on a non-empty option list,
## so that is all it does. The presentation itself belongs to step five:
## BuildDecision refuses to present outside Phase.BUILD_DECISION, which is its
## own precondition and not something to work around.
func _step_receive_targets() -> void:
	var decision_id := StringName(flow.chapter.active_build_decision_id)
	if decision_id == &"":
		return
	if not flow.chapter.available_build_option_ids.is_empty():
		return
	var path := "build_options.%s.available_option_ids" % decision_id
	flow.chapter.available_build_option_ids = _string_names(Balance.get_value(path, []))


## Step 3, T-19a. Offering the run is the whole of this step; it never gates, so
## a player who ignores it is not held. Skipping and completing are the same
## event to the flow.
func _step_optional_minigame() -> void:
	var minigame_id := StringName(flow.chapter.stage_minigame_id)
	if minigame_id == &"":
		return
	if minigame.state() != MinigameRuntime.State.IDLE:
		return
	minigame.begin(minigame_id, flow.current_stage_id())


## Step 4, T-17. One settlement, then the watcher looks at the result.
func _step_resource_settlement() -> void:
	var before := _resource_values()
	# A stage produces across its whole configured operating time, not for one
	# tick. chapters.<stage_id>.operation_time_sec is that duration, and
	# advance_time turns it into the configured number of ticks. Settling once
	# would leave a two-decision stage unable to pay for its second build.
	var operating_sec := float(
		Balance.get_value("chapters.%s.operation_time_sec" % flow.current_stage_id(), 0.0)
	)
	if operating_sec > 0.0:
		resource_tick.advance_time(operating_sec, _settlement_input())
	else:
		resource_tick.settle_tick(1.0, _settlement_input())
	_pull_resource_values()
	threshold_watcher.watch(_resource_values())
	if resource_bar != null:
		resource_bar.set_resources(_resource_values())
	EventBus.resources_settled.emit(flow.current_stage_id(), _deltas(before), _resource_values())


## Step 5, T-13. Present the decision once, then wait. Confirming is the
## player's, through confirm_build, and the flow leaves the step when the
## confirmation lands in confirmed_build_decision_ids.
func _step_build_decision() -> void:
	var decision_id := StringName(flow.chapter.active_build_decision_id)
	if decision_id == &"" or _presented_build_decision_id == decision_id:
		return
	var options := build_decision.present_decision(
		flow.stage_number(), _decision_sequence(decision_id), decision_id
	)
	if options.is_empty():
		_note_incomplete(
			&"build_decision",
			"BuildDecision presented no options for %s." % decision_id
		)
		return
	_presented_build_decision_id = decision_id
	if option_preview != null:
		option_preview.configure(Balance, null)
		option_preview.set_candidates(_candidate_contexts(decision_id, options))


## Step 6, T-14 and T-15a. Turn the confirmed blueprint into a built organ and
## extend the transport network along the route the chosen option names.
func _step_build_completion() -> void:
	var decision_id := StringName(flow.chapter.active_build_decision_id)
	var option_id := StringName(flow.chapter.selected_build_option_id)
	if decision_id == &"" or option_id == &"":
		return
	var organ_id := _organ_for(decision_id)
	if organ_id == &"":
		return

	var slot_id := StringName(flow.chapter.selected_build_slot_id)
	organ_state.register_organ(organ_id)
	organ_state.start_construction(organ_id, decision_id, option_id, slot_id)
	organ_state.advance_construction(_build_duration(decision_id, option_id))
	network_builder.generate_extension(organ_id, decision_id, option_id)
	EventBus.organ_built.emit(organ_id, slot_id, option_id)


## Step 7, T-19f. Present the operation decision; confirming it is the player's,
## through confirm_operation.
func _step_operation_decision() -> void:
	var decision_id := StringName(flow.chapter.active_operation_decision_id)
	if decision_id == &"":
		return
	if not flow.chapter.available_operation_ids.is_empty():
		return
	var options := operation_decision.present_decision(flow.stage_number(), decision_id)
	if options.is_empty():
		_note_incomplete(
			&"operation_decision",
			"OperationDecision presented no options for %s." % decision_id
		)


## Step 8, T-19. Activate the organ and run one collaboration observation. The
## flow leaves the step when system_observation_complete holds, which is what
## OrganCheck reports.
func _step_system_activation() -> void:
	var decision_id := StringName(flow.chapter.active_build_decision_id)
	if decision_id == &"":
		flow.chapter.system_observation_complete = true
		return

	var report := organ_check.check_and_observe(
		decision_id, flow.current_stage_id(), _observation_context()
	)
	if bool(report.get("observation_started", false)):
		organ_check.complete_observation()
	flow.chapter.system_observation_complete = organ_check.can_advance()
	if not flow.chapter.system_observation_complete:
		_note_incomplete(
			&"system_activation",
			"OrganCheck did not report an observation for %s: %s"
				% [decision_id, report.get("failure_reason", &"")]
		)
		# The step must not deadlock the run on a system that could not report.
		flow.chapter.system_observation_complete = true


## Step 9, T-30. Unlock this stage's archive entry and let the container show it.
func _step_knowledge_unlock() -> void:
	var organ_id := _organ_for(StringName(flow.chapter.active_build_decision_id))
	var entry_id := StringName("entry_%s" % flow.current_stage_id())
	EventBus.knowledge_entry_unlocked.emit(entry_id, organ_id, flow.current_stage_id())
	flow.chapter.knowledge_unlock_resolved = true


## Step 10, T-25 and T-19e. On the final stage this is where the birth checks,
## the transition and the ending live. Everywhere else it is the carryover.
func _step_stage_complete() -> void:
	if chapter_summary != null:
		chapter_summary.open(flow.current_stage_id(), _summary_content())
	if flow.chapter.next_stage_id != &"":
		return
	_run_birth_sequence()


# ---------------------------------------------------------------------------
# 3 · The player's entry points
#
# Each forwards to the system that owns the rule. None of them decides anything.
# ---------------------------------------------------------------------------

func choose_build_option(option_id: StringName, slot_id: StringName) -> bool:
	return build_decision.select_candidate(option_id, slot_id)


func confirm_build() -> bool:
	var confirmed := build_decision.request_confirmation()
	if confirmed:
		_build_records[StringName(flow.chapter.active_build_decision_id)] = {
			"option_id": StringName(flow.chapter.selected_build_option_id),
			"slot_id": StringName(flow.chapter.selected_build_slot_id),
		}
	return confirmed


func choose_operation_priority(operation_id: StringName) -> bool:
	return operation_decision.select_priority(operation_id)


func confirm_operation() -> bool:
	var confirmed := operation_decision.request_confirmation(_settlement_input())
	if confirmed:
		_operation_settlement = _resource_values()
	return confirmed


## Advance the loop one step. The only mover; everything else responds to it.
func advance() -> bool:
	return flow.advance()


## Run until the loop finishes. A step that refuses to be left is not a failure:
## the two decisions wait for the player, and `on_step` is where a caller makes
## one. Only a step that refuses repeatedly with nothing changing is a stall.
func run(on_step: Callable = Callable(), limit: int = 400) -> bool:
	if flow.chapter == null:
		flow.start_new_run()

	var steps := 0
	var stalls := 0
	while not flow.is_run_complete() and steps < limit:
		steps += 1
		if on_step.is_valid():
			on_step.call(self)
		var before := [flow.stage_number(), flow.current_step()]
		advance()
		var after := [flow.stage_number(), flow.current_step()]
		stalls = 0 if before != after else stalls + 1
		if stalls > 3:
			push_error(
				"%s Stalled at stage %d step %s."
				% [LOG_PREFIX, flow.stage_number(), flow.current_step_id()]
			)
			return false

	if steps >= limit:
		push_error("%s Stopped after %d steps without finishing the run." % [LOG_PREFIX, limit])
		return false
	return true


func start() -> bool:
	return flow.start_new_run()


# ---------------------------------------------------------------------------
# The birth sequence
#
# T-19e checks, T-20 and T-21 run the seven states, T-25 closes the run. The
# machine's beats are stepped through rather than waited out, because the
# 45 second timeline is presentation and this is the flow's side of it.
# ---------------------------------------------------------------------------

func _run_birth_sequence() -> void:
	if birth_machine.is_terminal():
		return

	var metrics := _birth_metrics()
	var report := birth_check.check(metrics)
	var passed := bool(report.get("passed", false))

	# The machine supports two modes: evaluate the gate itself through a
	# BirthCheck of its own, or wait for an external verdict. The second is used
	# here, because the first answers through call_deferred and this loop is
	# driven step by step rather than frame by frame, so a deferred verdict would
	# never arrive. city_metrics is still supplied for the panel that shows the
	# four rows.
	birth_machine.city_metrics = metrics
	birth_machine.start()
	birth_machine.submit_gate_result(passed)
	if not passed:
		_note_incomplete(&"birth_check", "The birth checks did not pass: %s" % report)
		return

	for state in _birth_states_after_gate():
		if not birth_machine.can_transition_to(state):
			_note_incomplete(
				&"birth_transition",
				"The machine refused the transition to state %d." % state
			)
			return
		birth_machine.transition_to(state)

	ending.evaluate_conditions()
	ending.try_close()


## BirthCheck reads table E5's four metrics by name, so they are supplied under
## the names it asks for rather than the resource names.
## The four table E5 inputs the birth gate reads. BirthCheck accepts either a
## birth_readiness value or the signal-coverage and pulmonary-readiness pair the
## E5 formula derives it from; the pair is supplied, so the formula stays with
## T-19e rather than being recomputed here.
func _birth_metrics() -> Dictionary:
	return {
		&"transport_coverage": resource_tick.transport_coverage,
		&"waste": resources.waste,
		&"stability": resources.stability,
		&"signal_coverage": resource_tick.signal_coverage,
		&"pulmonary_system_readiness": _pulmonary_readiness(),
	}


## The share of this stage's required organs that finished construction. Table
## E5 of docs/OPERATION_SPEC.md names lung exchange and the pulmonary interface
## as what the reading supports, and both are required organs of the final
## stage, so the share is read from the organ state machine rather than assumed.
func _pulmonary_readiness() -> float:
	var required: Array = flow.chapter.required_organ_ids
	if required.is_empty():
		return 0.0
	var ready_count := 0
	for organ_id in required:
		var state := organ_state.current_state(StringName(str(organ_id)))
		if state == OrganStateMachine.State.COMPLETED or state == OrganStateMachine.State.OPERATING:
			ready_count += 1
	return float(ready_count) / float(required.size())


func _birth_states_after_gate() -> Array[int]:
	var states: Array[int] = []
	for state in range(BirthMachine.State.READY_CHECK + 1, BirthMachine.State.FAILURE_ROLLBACK):
		states.append(state)
	return states


# ---------------------------------------------------------------------------
# Reporting what is not finished
# ---------------------------------------------------------------------------

func _note_incomplete(key: StringName, reason: String) -> void:
	if _incomplete.has(key):
		return
	_incomplete[key] = reason
	print("%s incomplete: %s - %s" % [LOG_PREFIX, key, reason])
	step_incomplete.emit(key, reason)


## Everything the assembly could not drive to completion, and why. Empty means
## every step reached its owning system and that system reported success.
func unimplemented_steps() -> Dictionary:
	return _incomplete.duplicate()


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

## The decision systems were configured against the first stage's ChapterData.
## The flow builds a new one per stage, so they are re-pointed on every stage.
func _rebind_decision_systems() -> void:
	if flow.chapter == null:
		return
	build_decision.configure(Balance, EventBus, flow.chapter, resources)
	operation_decision.configure(
		Balance, EventBus, flow.chapter, resources, resource_tick, threshold_watcher
	)


func _decision_sequence(decision_id: StringName) -> int:
	var index := flow.chapter.required_build_decision_ids.find(decision_id)
	return maxi(index, 0) + 1


func _organ_for(decision_id: StringName) -> StringName:
	if decision_id == &"":
		return &""
	# The identifier is the decision without its build_ prefix, which is how
	# docs/BUILD_DECISION_SPEC.md table D1 pairs them.
	return StringName(String(decision_id).trim_prefix("build_"))


func _build_duration(decision_id: StringName, option_id: StringName) -> float:
	return float(Balance.get_value(
		"build_options.%s.%s.metrics.build_duration" % [decision_id, option_id], 0.0
	))


func _resource_values() -> Dictionary:
	return {
		&"nutrient_energy": resources.nutrient_energy,
		&"cell_material": resources.cell_material,
		&"development_signal": resources.development_signal,
		&"waste": resources.waste,
		&"stability": resources.stability,
		&"knowledge_badge_count": resources.knowledge_badge_count,
	}


func _pull_resource_values() -> void:
	var current: Dictionary = resource_tick.resources
	resources.nutrient_energy = float(current.get("nutrient_energy", resources.nutrient_energy))
	resources.cell_material = float(current.get("cell_material", resources.cell_material))
	resources.development_signal = float(current.get("development_signal", resources.development_signal))
	resources.waste = float(current.get("waste", resources.waste))
	resources.stability = float(current.get("stability", resources.stability))


func _deltas(before: Dictionary) -> Dictionary:
	var after := _resource_values()
	var deltas: Dictionary = {}
	for key in after:
		deltas[key] = float(after[key]) - float(before.get(key, 0.0))
	return deltas


func _settlement_input() -> Dictionary:
	return {
		"stage_id": flow.current_stage_id(),
		"resources": _resource_values(),
	}


## What T-19g's detector reads. Every value comes from the settled tick or the
## resource pool; the key spellings are the ones bottleneck_detector.gd asks for.
func _current_metrics() -> Dictionary:
	return {
		"stage_id": flow.current_stage_id(),
		"transport_pressure": resource_tick.transport_pressure,
		"transport_coverage": resource_tick.transport_coverage,
		"signal_coverage": resource_tick.signal_coverage,
		"organ_transport_coverage": resource_tick.organ_transport_coverage,
		"edge_flow_by_id": resource_tick.settled_edge_flow,
		"waste": resources.waste,
		"stability": resources.stability,
		"net_waste_rate": float(Balance.get_value("resources.waste.accumulation_per_tick", 0.0)),
	}


func _observation_context() -> Dictionary:
	return {
		"resources": _resource_values(),
		"stage_id": flow.current_stage_id(),
	}


## The per-candidate context T-13a's preview reads. Every value comes from the
## build option tables; none is computed here.
func _candidate_contexts(decision_id: StringName, options: Array[StringName]) -> Dictionary:
	var contexts: Dictionary = {}
	for option_id in options:
		var metrics: Variant = Balance.get_value(
			"build_options.%s.%s.metrics" % [decision_id, option_id], {}
		)
		var cost: Variant = Balance.get_value(
			"build_options.%s.%s.cost" % [decision_id, option_id], {}
		)
		contexts[option_id] = {
			"metrics": metrics if metrics is Dictionary else {},
			"cost": cost if cost is Dictionary else {},
		}
	return contexts


## What T-30a's summary shows. The six items are its own; this supplies the
## stage's confirmed decisions and nothing more.
func _summary_content() -> Dictionary:
	return {
		"stage_id": flow.current_stage_id(),
		"build_decisions": _build_records.duplicate(true),
		"operation_settlement": _operation_settlement.duplicate(),
	}


func _string_names(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if not value is Array:
		return names
	for entry in value as Array:
		names.append(StringName(str(entry)))
	return names


func _on_run_completed(final_stage_id: StringName) -> void:
	print("%s run complete at %s." % [LOG_PREFIX, final_stage_id])
	run_finished.emit(final_stage_id)
