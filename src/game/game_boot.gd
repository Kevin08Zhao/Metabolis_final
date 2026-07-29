extends Control
## Game scene boot script.
##
## Attached to the root Game node. On ready it triggers ChapterFlow and wires
## keyboard input so the player can step through the stage loop with Space.
## All game logic lives in ChapterFlow and the simulation scripts; this file
## boots them, provides a debug advance key, and keeps the visible step status
## synchronized with ChapterFlow.

const LOG_PREFIX := "[GAME]"
const STEP_LABELS := {
	&"observe_state": "Observe State",
	&"receive_targets": "Receive Targets",
	&"optional_minigame": "Optional Minigame",
	&"resource_settlement": "Resource Settlement",
	&"build_decision": "Build Decision",
	&"build_completion": "Build Completion",
	&"operation_decision": "Operation Decision",
	&"system_activation": "System Activation",
	&"knowledge_unlock": "Knowledge Unlock",
	&"stage_complete": "Stage Complete",
}

var _flow: Node = null
var _status_label: Label = null
var _controller: Node = null
var _resources: ResourcePool = null
var _birth_machine: BirthMachine = null


func _ready() -> void:
	# Enable unhandled input for keyboard events.
	set_process_unhandled_input(true)

	_flow = get_node_or_null("ChapterFlow")
	if _flow == null:
		push_error("%s No ChapterFlow node found; game cannot start." % LOG_PREFIX)
		return

	_status_label = get_node_or_null("GuidanceLayer/GameplayStatus") as Label
	if _status_label == null:
		push_error("%s No GameplayStatus label found; gameplay changes will not be visible." % LOG_PREFIX)
		return

	_controller = get_node_or_null("GuidanceLayer")
	var resource_bar := get_node_or_null("ResourceStatusBar") as ResourceBar
	var grid_manager := get_node_or_null("CityMap") as GridManager
	var city_art := get_node_or_null("CityArt") as Node2D
	var network_builder := get_node_or_null("CityNetwork") as NetworkBuilder
	var birth_art := get_node_or_null("BirthArt") as TextureRect
	_birth_machine = get_node_or_null("BirthMachine") as BirthMachine
	if (
		_controller == null
		or resource_bar == null
		or grid_manager == null
		or city_art == null
		or network_builder == null
		or birth_art == null
		or _birth_machine == null
	):
		push_error(
			"%s Gameplay controller, map art, network, birth art, or resource bar is missing."
			% LOG_PREFIX
		)
		return

	if not _flow.has_method("start_new_run"):
		push_error("%s ChapterFlow node has no start_new_run method." % LOG_PREFIX)
		return

	_resources = ResourcePool.new()
	_initialize_resources()
	network_builder.configure(Balance, EventBus)
	_configure_birth_machine()
	_controller.call(
		"configure",
		_flow,
		_resources,
		resource_bar,
		grid_manager,
		city_art,
		network_builder,
		birth_art,
		_birth_machine
	)
	_controller.connect("visual_state_changed", _refresh_status)
	_flow.start_new_run()
	_refresh_status()
	print("%s Run started. Use the action panel or press Space to continue." % LOG_PREFIX)


func _configure_birth_machine() -> void:
	var birth_check := BirthCheck.new()
	birth_check.configure(Balance, EventBus)
	_birth_machine.birth_check = birth_check
	_birth_machine.first_breath_completed.connect(_on_first_breath_completed)


func _on_first_breath_completed() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is SceneRouter:
			ancestor.call_deferred("go_to_title")
			return
		ancestor = ancestor.get_parent()
	push_warning("%s Birth sequence ended without a SceneRouter ancestor." % LOG_PREFIX)


func _unhandled_input(event: InputEvent) -> void:
	if _flow == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.shift_pressed:
				_jump_to_build()
			else:
				_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if _controller == null:
		return
	var ok: bool = _controller.call("request_advance")
	if ok:
		var stage: int = _flow.call("stage_number") if _flow.has_method("stage_number") else 0
		var step: StringName = _flow.call("current_step_id") if _flow.has_method("current_step_id") else &""
		_refresh_status()
		print("%s stage %d  step=%s" % [LOG_PREFIX, stage, step])
	else:
		print("%s Cannot advance yet." % LOG_PREFIX)


func _jump_to_build() -> void:
	if _controller != null:
		_advance()
		return
	if not _flow.has_method("advance_to"):
		print("%s ChapterFlow does not support jump-to-build." % LOG_PREFIX)
		return
	while _flow.has_method("current_step") and int(_flow.call("current_step")) < 4:
		if not _flow.has_method("can_exit_current_step") or not _flow.call("can_exit_current_step"):
			print("%s Blocked at step %s; cannot jump to build." % [LOG_PREFIX, _flow.call("current_step_id")])
			return
		_flow.advance()
	_flow.call("advance_to", 4)
	_refresh_status()
	print("%s Jumped to build decision step." % LOG_PREFIX)


func _initialize_resources() -> void:
	for resource_id in ResourceBar.RESOURCE_IDS:
		var initial: Variant = Balance.get_value(
			"resources.%s.initial" % resource_id,
			0
		)
		if resource_id == &"knowledge_badge_count":
			_resources.set(resource_id, int(initial))
		else:
			_resources.set(resource_id, float(initial))


func _refresh_status() -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	var stage: int = _flow.call("stage_number") if _flow.has_method("stage_number") else 0
	var step_id: StringName = _flow.call("current_step_id") if _flow.has_method("current_step_id") else &""
	var step_label := str(STEP_LABELS.get(step_id, str(step_id).capitalize()))
	_status_label.text = (
		"Stage %d - %s\nSPACE: Continue or use the action panel"
		% [stage, step_label]
	)
