extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	AudioRouter.set_muted(true)
	await _test_required_same_tick_sequence()
	await _test_capacity_and_e11_downgrade()
	await _test_stability_recovery_does_not_consume_first_drop()
	await _test_neural_tube_override_isolated_from_merge()
	await _test_assist_alert_and_truncation()
	await _test_existing_organ_target_resolution()
	await _test_measured_character_capacity()
	AudioRouter.set_muted(false)

	if _failures.is_empty():
		print("[NOTIFICATION TEST] RESULT PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("[NOTIFICATION TEST] %s" % failure)
	print("[NOTIFICATION TEST] RESULT FAIL count=", _failures.size())
	get_tree().quit(1)


func _test_required_same_tick_sequence() -> void:
	var queue := await _fresh_queue("RequiredSameTickSequence")
	EventBus.resource_shortage_raised.emit(&"nutrient_energy", 2.0, 10.0)
	EventBus.resource_shortage_raised.emit(&"cell_material", 3.0, 10.0)
	EventBus.resource_shortage_raised.emit(&"development_signal", 4.0, 10.0)
	EventBus.organ_built.emit(&"heart_pump", &"heart_slot", &"heart_early_flow")
	EventBus.delayed_feedback_shown.emit(
		&"initial_operation_pressure",
		&"stage_origin",
		[&"build_heart"]
	)
	EventBus.stability_band_changed.emit(1, 2, 24.0)
	await _wait_for_merge_window()

	var visible := queue.visible_notifications()
	var waiting := queue.queued_notifications()
	_expect(
		visible.size() == 3,
		"three shortages, one build, one tutorial, and one alert must produce three visible cards"
	)
	if visible.size() == 3:
		_expect(
			StringName(visible[0].get("tier", &"")) == &"alert",
			"the critical stability alert must be first"
		)
		_expect(
			StringName(visible[1].get("event_name", &""))
			== &"resource_shortage_raised",
			"the three shortages must occupy one pressure card"
		)
		_expect(
			int(visible[1].get("merged_count", 0)) == 3,
			"the merged pressure card must retain all three shortages"
		)
		_expect(
			StringName(visible[2].get("event_name", &"")) == &"organ_built",
			"the build broadcast must remain visible below higher-priority cards"
		)
	print(
		"[NOTIFICATION TEST] visible=",
		visible.size(),
		" order=",
		_tier_order(visible),
		" queued=",
		waiting.size(),
		" queued_order=",
		_event_order(waiting)
	)
	_expect(
		waiting.size() == 1
		and StringName(waiting[0].get("event_name", &""))
		== &"delayed_feedback_shown",
		"an alert on screen must defer the tutorial attribution"
	)
	_expect(
		queue.visible_card_sizes()
		== [Vector2(144, 48), Vector2(128, 32), Vector2(112, 32)],
		"rendered cards must use the locked G1d, G1c, and G1a pixel sizes"
	)
	EventBus.waste_overflowed.emit(100.0, 5.0)
	EventBus.birth_rolled_back.emit(3, &"readiness")
	await get_tree().process_frame
	visible = queue.visible_notifications()
	waiting = queue.queued_notifications()
	_expect(
		_count_tier(visible, &"alert") == 1,
		"only one alert may be visible"
	)
	_expect(
		_count_tier(waiting, &"alert") == 2,
		"additional alerts must wait instead of displaying in parallel"
	)
	_expect(
		waiting.size() == 3,
		"the deferred tutorial and two waiting alerts must all remain queued"
	)
	if waiting.size() >= 3:
		_expect(
			StringName(waiting[0].get("event_name", &""))
			== &"delayed_feedback_shown"
			and StringName(waiting[1].get("event_name", &""))
			== &"waste_overflowed"
			and StringName(waiting[2].get("event_name", &""))
			== &"birth_rolled_back",
			"waiting alerts must retain FIFO order behind the deferred tutorial"
		)
	await _dispose_queue(queue)


func _test_capacity_and_e11_downgrade() -> void:
	var queue := await _fresh_queue("CapacityAndDowngrade")
	EventBus.organ_built.emit(&"heart", &"slot", &"option")
	EventBus.transport_pressure_cleared.emit(&"edge_a")
	EventBus.waste_buildup_cleared.emit(&"kidney")
	EventBus.signal_gap_cleared.emit(&"brain")
	await _wait_for_merge_window()
	var visible := queue.visible_notifications()
	_expect(
		_count_tier(visible, &"broadcast") == 3,
		"a fourth broadcast must drop the oldest instead of entering the wait queue"
	)
	_expect(
		queue.queued_notifications().is_empty(),
		"overflow broadcasts must never be queued"
	)
	await _dispose_queue(queue)

	queue = await _fresh_queue("E11Downgrade")
	EventBus.transport_pressure_appeared.emit(&"edge_a", 0.7)
	await _wait_for_merge_window()
	EventBus.transport_pressure_appeared.emit(&"edge_b", 0.8)
	await _wait_for_merge_window()
	visible = queue.visible_notifications()
	_expect(
		visible.size() == 2,
		"two separated E11 episodes must both display"
	)
	if visible.size() == 2:
		_expect(
			StringName(visible[0].get("tier", &"")) == &"attribution",
			"the first E11 occurrence must use the two-line attribution tier"
		)
		_expect(
			StringName(visible[1].get("tier", &"")) == &"broadcast",
			"a repeat in the same runtime segment must downgrade to broadcast"
		)
	await _dispose_queue(queue)


func _test_stability_recovery_does_not_consume_first_drop() -> void:
	var queue := await _fresh_queue("StabilityDirection")
	EventBus.stability_band_changed.emit(1, 0, 75.0)
	EventBus.stability_band_changed.emit(0, 1, 55.0)
	await get_tree().process_frame
	var visible := queue.visible_notifications()
	_expect(
		visible.size() == 2,
		"a recovery and a later first drop must each display once"
	)
	if visible.size() == 2:
		_expect(
			StringName(visible[0].get(&"tier", &"")) == &"broadcast"
			and not bool(visible[0].get(&"tutorial", true)),
			"a stability recovery must be a non-tutorial broadcast"
		)
		_expect(
			StringName(visible[1].get(&"tier", &"")) == &"attribution"
			and bool(visible[1].get(&"tutorial", false)),
			"a preceding recovery must not consume the first downward E11 attribution"
		)
	await _dispose_queue(queue)


func _test_neural_tube_override_isolated_from_merge() -> void:
	var queue := await _fresh_queue("NeuralTubeOverride")
	EventBus.signal_gap_appeared.emit(&"neural_network", 0.6)
	EventBus.knowledge_entry_unlocked.emit(
		&"hint_neural_tube_compensation",
		&"neural_network",
		&"stage_circulation"
	)
	EventBus.knowledge_entry_unlocked.emit(
		&"heart_archive",
		&"heart_pump",
		&"stage_circulation"
	)
	await _wait_for_merge_window()
	var visible := queue.visible_notifications()
	_expect(
		visible.size() == 2,
		"the neural hint must replace generic signal copy and remain separate from other unlocks"
	)
	_expect(
		_notification_with_copy(
			visible,
			&"notification.signal_coordination"
		).is_empty(),
		"the compensation case must suppress its pending generic signal hint"
	)
	var neural := _notification_with_copy(
		visible,
		&"notification.neural_tube_compensation"
	)
	_expect(
		not neural.is_empty()
		and StringName(neural.get(&"tier", &"")) == &"attribution"
		and int(neural.get(&"merged_count", 0)) == 1,
		"the authoritative neural-tube unlock must use an unmerged attribution"
	)
	_expect(
		int(neural.get(&"target_argument_index", -1)) == 1,
		"the neural-tube attribution must fly to its organ argument"
	)
	var generic := _notification_with_copy(
		visible,
		&"notification.knowledge_unlocked"
	)
	_expect(
		not generic.is_empty()
		and StringName(generic.get(&"tier", &"")) == &"broadcast",
		"other knowledge unlocks must keep the generic broadcast presentation"
	)
	await _dispose_queue(queue)


func _test_assist_alert_and_truncation() -> void:
	var queue := await _fresh_queue("AssistAndTruncation")
	EventBus.waste_overflowed.emit(100.0, 5.0)
	await get_tree().create_timer(0.30).timeout
	queue.call("_on_assist_mode_entered", &"minigame", {})
	queue.call("_process", 100.0)
	_expect(
		_count_tier(queue.visible_notifications(), &"alert") == 1,
		"assist mode must keep an alert until manual dismissal"
	)
	queue.call("_on_assist_mode_left", &"minigame")
	queue.call("_process", 100.0)
	_expect(
		_count_tier(queue.visible_notifications(), &"alert") == 0,
		"leaving assist mode must restore automatic alert dismissal"
	)

	var fitted: String = queue.call(
		"_fit_text",
		&"notification.acceptance_overflow",
		"[placeholder text that is deliberately too long]\n[line two]\n[line three]",
		&"broadcast"
	)
	_expect(
		fitted.split("\n").size() == 1 and fitted.length() <= 9,
		"overflow placeholder copy must be truncated to the G1a hard capacity"
	)
	await _dispose_queue(queue)


func _test_measured_character_capacity() -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)
	await get_tree().process_frame
	var font := label.get_theme_font("font")
	var cases := [
		{"tier": "G1a", "available": 91.0, "maximum": 9},
		{"tier": "G1b", "available": 106.0, "maximum": 10},
		{"tier": "G1c", "available": 95.0, "maximum": 9},
		{"tier": "G1d", "available": 108.0, "maximum": 10},
	]
	for capacity in cases:
		var maximum := int(capacity["maximum"])
		var measured := font.get_string_size(
			"测".repeat(maximum),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10
		).x
		var overflow := font.get_string_size(
			"测".repeat(maximum + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10
		).x
		print(
			"[NOTIFICATION TEST] ",
			capacity["tier"],
			" measured=",
			measured,
			" overflow=",
			overflow,
			" available=",
			capacity["available"]
		)
		_expect(
			measured <= float(capacity["available"])
			and overflow > float(capacity["available"]),
			"%s character maximum must fit the project 10 px pixel font"
			% capacity["tier"]
		)
	label.queue_free()
	await get_tree().process_frame


func _test_existing_organ_target_resolution() -> void:
	var organ := Sprite2D.new()
	organ.name = "Organ_heart_pump"
	organ.centered = false
	organ.position = Vector2(96, 112)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("#73CD9B"))
	organ.texture = ImageTexture.create_from_image(image)
	add_child(organ)
	var queue := await _fresh_queue("TargetResolution")
	var target: Vector2 = queue.call(
		"_exit_target_position",
		{
			&"exit_target": &"map_organ",
			&"arguments": [&"heart_pump", &"slot", &"option"],
		},
		Vector2.ZERO
	)
	_expect(
		target == Vector2(104, 120),
		"map-organ exit targets must resolve the existing Organ_<id> sprite"
	)
	await _dispose_queue(queue)
	organ.queue_free()
	await get_tree().process_frame

	var network := NetworkBuilder.new()
	network.name = "CityNetwork"
	network.position = Vector2(8, 16)
	var nodes: Array[Dictionary] = [
		{
			&"node_id": &"route_node_01",
			&"grid_position": Vector2i(3, 4),
		},
	]
	var edges: Array[Dictionary] = [
		{
			&"edge_id": &"route_edge_00",
			&"end_node_id": &"route_node_01",
		},
	]
	network.set("_nodes", nodes)
	network.set("_edges", edges)
	var vessel_root := Node2D.new()
	vessel_root.name = "VesselTiles"
	network.add_child(vessel_root)
	var vessel := Sprite2D.new()
	vessel.name = "Vessel_03_04"
	vessel.position = Vector2(56, 72)
	vessel_root.add_child(vessel)
	add_child(network)
	queue = await _fresh_queue("EdgeTargetResolution")
	target = queue.call(
		"_exit_target_position",
		{
			&"exit_target": &"map_organ",
			&"arguments": [&"route_edge_00", 0.9],
		},
		Vector2.ZERO
	)
	_expect(
		target == Vector2(64, 88),
		"map targets carrying edge_id must resolve the matching vessel tile"
	)
	await _dispose_queue(queue)
	network.queue_free()
	await get_tree().process_frame


func _fresh_queue(node_name: String) -> NotificationQueue:
	var queue := NotificationQueue.new()
	queue.name = node_name
	add_child(queue)
	await get_tree().process_frame
	return queue


func _dispose_queue(queue: NotificationQueue) -> void:
	await get_tree().create_timer(0.35).timeout
	queue.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_for_merge_window() -> void:
	await get_tree().create_timer(
		float(Balance.get_value("notifications.merge_window_ms", 0)) / 1000.0
		+ 0.30
	).timeout


func _count_tier(notifications: Array[Dictionary], tier: StringName) -> int:
	var count := 0
	for notification in notifications:
		if StringName(notification.get("tier", &"")) == tier:
			count += 1
	return count


func _tier_order(notifications: Array[Dictionary]) -> PackedStringArray:
	var order := PackedStringArray()
	for notification in notifications:
		order.append(String(notification.get("tier", "")))
	return order


func _event_order(notifications: Array[Dictionary]) -> PackedStringArray:
	var order := PackedStringArray()
	for notification in notifications:
		order.append(String(notification.get("event_name", "")))
	return order


func _notification_with_copy(
	notifications: Array[Dictionary],
	copy_key: StringName
) -> Dictionary:
	for notification in notifications:
		if StringName(notification.get(&"copy_key", &"")) == copy_key:
			return notification
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
