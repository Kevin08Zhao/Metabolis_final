extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_main := load("res://main.tscn") as PackedScene
	_expect(packed_main != null, "main scene must load")
	if packed_main == null:
		_finish()
		return

	var main := packed_main.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var router := main.get_node_or_null("SceneRouter")
	_expect(router != null, "main scene must contain SceneRouter")
	if router == null:
		_finish()
		return

	_test_new_game_button_is_deferred(main, router)
	await get_tree().process_frame
	await _test_space_advances_gameplay(main)
	await _test_first_stage_interactions(main)

	main.queue_free()
	await get_tree().process_frame
	_finish()


func _test_new_game_button_is_deferred(main: Node, router: Node) -> void:
	var new_game_button := main.find_child("Entry_new_game", true, false) as Button
	_expect(new_game_button != null, "title must expose the New Game button")
	if new_game_button == null:
		return

	new_game_button.pressed.emit()
	_expect(
		router.current_route() == SceneRouter.ROUTE_TITLE,
		"New Game handler must not free its emitting button synchronously"
	)
	await get_tree().process_frame
	_expect(
		router.current_route() == SceneRouter.ROUTE_GAME,
		"New Game must enter the game route on the deferred callback"
	)


func _test_space_advances_gameplay(main: Node) -> void:
	var game := main.find_child("Game", true, false)
	_expect(game != null, "game route must instantiate the Game scene")
	if game == null:
		return

	var city_map := game.get_node_or_null("CityMap")
	_expect(
		city_map != null and _count_landed_textures(city_map) > 0,
		"The playable city map must render landed pixel-art terrain textures"
	)

	var flow := game.get_node_or_null("ChapterFlow")
	_expect(flow != null, "Game scene must contain ChapterFlow")
	if flow == null:
		return

	var gameplay_status := game.get_node_or_null("GuidanceLayer/GameplayStatus") as Label
	_expect(gameplay_status != null, "Game scene must expose a visible gameplay status label")
	var step_before: StringName = flow.current_step_id()
	var visible_text_before := _visible_text_signature(game)
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	game.call("_unhandled_input", event)
	await get_tree().process_frame
	var step_after: StringName = flow.current_step_id()
	var visible_text_after := _visible_text_signature(game)
	_expect(step_after != step_before, "Space must advance the current gameplay step")
	_expect(
		visible_text_after != visible_text_before,
		"Space must produce a visible text change when the gameplay step advances"
	)
	if gameplay_status != null:
		_expect(
			gameplay_status.text.contains("Receive Targets"),
			"Gameplay status must describe the newly entered step"
		)


func _test_first_stage_interactions(main: Node) -> void:
	var game := main.find_child("Game", true, false)
	if game == null:
		return
	var flow := game.get_node_or_null("ChapterFlow")
	if flow == null:
		return

	if not await _press_button(game, "ContinueAction"):
		return
	_expect(
		flow.current_step_id() == &"optional_minigame",
		"Continue must enter the optional minigame step"
	)
	if not await _press_button(game, "StartTask"):
		return
	var resource_bar := game.get_node_or_null("ResourceStatusBar")
	var badges_before_task := int(
		resource_bar.resource_values()[&"knowledge_badge_count"]
	)
	var task_actions := 0
	while flow.chapter.minigame_resolution == &"pending" and task_actions < 100:
		task_actions += 1
		if not await _press_button(game, "ProgressTask"):
			return
	_expect(
		flow.chapter.minigame_resolution == &"completed",
		"Repeated task actions must settle the runtime result"
	)
	_expect(
		int(resource_bar.resource_values()[&"knowledge_badge_count"])
		== badges_before_task,
		"Minigame rewards must remain pending until resource settlement"
	)

	if not await _press_button(game, "ContinueAction"):
		return
	_expect(
		flow.current_step_id() == &"resource_settlement",
		"Continue must enter resource settlement"
	)
	if not await _press_button(game, "SettleResources"):
		return
	_expect(
		int(resource_bar.resource_values()[&"knowledge_badge_count"])
		> badges_before_task,
		"Resource settlement must apply the completed minigame reward"
	)
	if not await _press_button(game, "ContinueAction"):
		return
	_expect(
		flow.current_step_id() == &"build_decision",
		"Settled resources must unlock the build decision step"
	)

	var resources_before: Dictionary = resource_bar.resource_values()
	if not await _press_button(game, "Option_cluster_compact"):
		return
	if not await _press_button(game, "Slot_slot_2_3"):
		return
	if not await _press_button(game, "ConfirmBuild"):
		return
	if not await _press_button(game, "ConfirmBuild"):
		return
	_expect(
		flow.chapter.confirmed_build_decision_ids.has(&"build_cell_cluster"),
		"Double confirmation must commit the selected build decision"
	)
	var resources_after_build: Dictionary = resource_bar.resource_values()
	_expect(
		float(resources_after_build[&"nutrient_energy"])
		< float(resources_before[&"nutrient_energy"]),
		"Build confirmation must visibly deduct resources"
	)
	var city_art := game.get_node_or_null("CityArt")
	_expect(
		city_art != null and _count_landed_textures(city_art) > 0,
		"Confirmed construction must add a landed pixel-art visual to the city"
	)
	var city_map := game.get_node_or_null("CityMap") as GridManager
	_expect(
		city_map != null
		and city_map.cell_state(Vector2i(2, 3)) == GridManager.CellState.OCCUPIED,
		"Confirmed build footprint must become occupied on the city grid"
	)
	var network_builder := game.get_node_or_null("CityNetwork") as NetworkBuilder
	_expect(
		network_builder != null and not network_builder.edges.is_empty(),
		"Confirmed build must publish a visible transport extension"
	)
	_expect(
		network_builder != null
		and _count_landed_textures(network_builder) > 0,
		"Published transport routes must use landed pixel-art vessel tiles"
	)

	if not await _press_button(game, "ContinueAction"):
		return
	if not await _press_button(game, "ContinueAction"):
		return
	_expect(
		flow.current_step_id() == &"operation_decision",
		"Build completion must lead to an operation decision"
	)
	if not await _press_button(game, "Option_transport_priority"):
		return
	if not await _press_button(game, "ConfirmOperation"):
		return
	if not await _press_button(game, "ConfirmOperation"):
		return
	_expect(
		flow.chapter.confirmed_operation_decision_ids.has(&"operate_cleavage_allocation"),
		"Double confirmation must commit the selected operation decision"
	)
	await _complete_remaining_run(game, flow)


func _complete_remaining_run(game: Node, flow: Node) -> void:
	var action_count := 0
	while not flow.is_run_complete() and action_count < 100:
		action_count += 1
		var step_id: StringName = flow.current_step_id()
		match step_id:
			&"optional_minigame":
				if (
					flow.chapter.stage_minigame_id != &""
					and flow.chapter.minigame_resolution == &"pending"
				):
					if not await _press_button(game, "SkipTask"):
						return
					_expect(
						flow.chapter.minigame_resolution == &"skipped",
						"Each stage's optional task must remain independently skippable"
					)
				if not await _press_button(game, "ContinueAction"):
					return
			&"resource_settlement":
				if game.find_child("SettleResources", true, false) != null:
					if not await _press_button(game, "SettleResources"):
						return
				if not await _press_button(game, "ContinueAction"):
					return
			&"build_decision":
				var decision_id: StringName = flow.chapter.active_build_decision_id
				if not flow.chapter.confirmed_build_decision_ids.has(decision_id):
					var options := _balance_ids(
						"build_options.%s.available_option_ids" % decision_id
					)
					_expect(not options.is_empty(), "Build decision must offer candidates")
					if options.is_empty():
						return
					var option_id := options[0]
					if not await _press_button(game, "Option_%s" % option_id):
						return
					var slots := _balance_ids(
						"build_options.%s.%s.available_slot_ids"
						% [decision_id, option_id]
					)
					_expect(not slots.is_empty(), "Build candidate must offer slots")
					if slots.is_empty():
						return
					if not await _press_button(game, "Slot_%s" % slots[0]):
						return
					if not await _press_button(game, "ConfirmBuild"):
						return
					if not await _press_button(game, "ConfirmBuild"):
						return
				if not await _press_button(game, "ContinueAction"):
					return
			&"operation_decision":
				var decision_id: StringName = flow.chapter.active_operation_decision_id
				if not flow.chapter.confirmed_operation_decision_ids.has(decision_id):
					var options := _balance_ids(
						"operations.available_options_by_stage.%s"
						% flow.chapter.stage_id
					)
					_expect(not options.is_empty(), "Operation decision must offer priorities")
					if options.is_empty():
						return
					if not await _press_button(game, "Option_%s" % options[0]):
						return
					if not await _press_button(game, "ConfirmOperation"):
						return
					if not await _press_button(game, "ConfirmOperation"):
						return
				if not await _press_button(game, "ContinueAction"):
					return
			_:
				if not await _press_button(game, "ContinueAction"):
					return

	_expect(action_count < 100, "Interactive run must not deadlock")
	_expect(flow.is_run_complete(), "Interactive controls must complete all four stages")
	var action_title := game.find_child("ActionTitle", true, false) as Label
	_expect(
		action_title != null
		and action_title.text in ["Run Complete", "Birth Readiness Recovery"],
		"Completing stage four must expose completion or a recoverable birth gate"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	var birth_art := game.get_node_or_null("BirthArt") as TextureRect
	var birth_machine := game.get_node_or_null("BirthMachine") as BirthMachine
	var gameplay_controller := game.get_node_or_null("GuidanceLayer")
	_expect(
		gameplay_controller != null,
		"Game scene must expose the authoritative gameplay controller"
	)
	if gameplay_controller == null:
		return
	var allocation_input: Dictionary = gameplay_controller.call(
		"_settlement_input"
	)
	var base_transport := float(allocation_input["available_transport_flow"])
	var base_signal := float(
		allocation_input["available_development_signal_flow"]
	)
	var base_waste_processing := float(
		allocation_input["available_waste_processing"]
	)
	var waste_allocation: Dictionary = gameplay_controller.call(
		"_dictionary_value",
		"operations.options.waste_priority.allocation_weights",
	)
	gameplay_controller.call(
		"_apply_operation_allocation",
		allocation_input,
		waste_allocation
	)
	_expect(
		is_equal_approx(
			float(allocation_input["available_transport_flow"]),
			base_transport * float(waste_allocation["transport"])
		)
		and is_equal_approx(
			float(allocation_input["available_development_signal_flow"]),
			base_signal * float(waste_allocation["signal"])
		)
		and base_waste_processing > 0.0
		and is_equal_approx(
			float(allocation_input["intervention_waste_removal"]),
			base_waste_processing * float(waste_allocation["waste"])
		),
		"Waste recovery must apply its allocation to the immediate E3 settlement"
	)
	var recovery_cycles := 0
	while (
		birth_machine != null
		and birth_machine.current_state() == BirthMachine.State.FAILURE_ROLLBACK
		and recovery_cycles < 20
	):
		recovery_cycles += 1
		if not await _press_button(game, "RecoverBirth"):
			return
	_expect(
		birth_art != null
		and birth_machine != null
		and birth_machine.gate_passed()
		and birth_machine.current_state() == BirthMachine.State.UMBILICAL_STOP
		and recovery_cycles > 0
		and recovery_cycles < 20
		and birth_art.visible
		and birth_art.texture != null
		and birth_art.texture.get_size() == Vector2(640, 320)
		and birth_art.call("current_frame_id") == &"stage1_umbilical_stop_00000",
		"Run completion must begin the timed PixelLab birth sequence"
	)
	var birth_states: Array[int] = []
	var birth_completions: Array[StringName] = []
	var state_receiver := func(
		_previous_state: int,
		current_state: int,
		_window_ms: int
	) -> void:
		birth_states.append(current_state)
	var completion_receiver := func(stage_id: StringName) -> void:
		birth_completions.append(stage_id)
	EventBus.birth_state_changed.connect(state_receiver)
	EventBus.birth_sequence_completed.connect(completion_receiver)

	birth_art.call("advance_time", 9.999)
	_expect(
		birth_machine.transition_to(BirthMachine.State.PULMONARY_FLOW),
		"BirthMachine must own the legal pulmonary-flow transition"
	)
	birth_art.call("advance_time", 9.999)
	_expect(
		birth_machine.transition_to(BirthMachine.State.FETAL_SHUNTS),
		"BirthMachine must own the legal fetal-shunt transition"
	)
	birth_art.call("advance_time", 9.999)
	_expect(
		birth_machine.transition_to(BirthMachine.State.SYSTEMS_ONLINE),
		"BirthMachine must own the legal systems-online transition"
	)
	birth_art.call("advance_time", 4.999)
	_expect(
		birth_machine.transition_to(BirthMachine.State.ENDING),
		"BirthMachine must own the legal ending transition"
	)
	_expect(
		birth_art.texture != null
		and birth_art.texture.get_size() == Vector2(640, 360)
		and birth_art.call("current_frame_id") == &"stage5_ending_35000",
		"The 35-second mark must display the landed first-breath ending"
	)
	_expect(
		birth_states == [3, 4, 5, 6],
		"Birth timeline must publish every visual state boundary"
	)
	_expect(
		birth_completions == [&"stage_birth"],
		"The first-breath frame must publish its dedicated completion cue"
	)
	EventBus.birth_state_changed.disconnect(state_receiver)
	EventBus.birth_sequence_completed.disconnect(completion_receiver)

	var router := game.get_parent().get_parent() as SceneRouter
	var first_breath_seen: Array[bool] = [false]
	birth_machine.first_breath_completed.connect(
		func() -> void: first_breath_seen[0] = true
	)
	Engine.time_scale = 1000.0
	var ending_frames := 0
	while not first_breath_seen[0] and ending_frames < 60:
		ending_frames += 1
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await get_tree().process_frame
	_expect(
		first_breath_seen[0]
		and ending_frames < 60
		and router != null
		and router.current_route() == SceneRouter.ROUTE_TITLE,
		"BirthMachine completion must fade back to the title route"
	)


func _balance_ids(path: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var value: Variant = Balance.get_value(path, [])
	if value is Array:
		for item in value:
			result.append(StringName(item))
	return result


func _press_button(root_node: Node, button_name: String) -> bool:
	var button := root_node.find_child(button_name, true, false) as Button
	_expect(button != null, "Expected interactive button '%s'" % button_name)
	if button == null:
		return false
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func _visible_text_signature(root_node: Node) -> PackedStringArray:
	var signature := PackedStringArray()
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if node is Label and node.is_visible_in_tree():
			signature.append("%s=%s" % [root_node.get_path_to(node), node.text])
		elif node is RichTextLabel and node.is_visible_in_tree():
			signature.append("%s=%s" % [root_node.get_path_to(node), node.text])
		elif node is Button and node.is_visible_in_tree():
			signature.append("%s=%s" % [root_node.get_path_to(node), node.text])
	signature.sort()
	return signature


func _count_landed_textures(root_node: Node) -> int:
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		var texture: Texture2D = null
		if node is TextureRect and node.is_visible_in_tree():
			texture = node.texture
		elif node is Sprite2D and node.is_visible_in_tree():
			texture = node.texture
		if texture != null and _texture_has_multiple_colors(texture):
			count += 1
	return count


func _texture_has_multiple_colors(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var first_color := image.get_pixel(0, 0)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y) != first_color:
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[REGRESSION] %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("[REGRESSION] PASS")
		get_tree().quit(0)
		return
	print("[REGRESSION] FAIL (%d): %s" % [_failures.size(), "; ".join(_failures)])
	get_tree().quit(1)
