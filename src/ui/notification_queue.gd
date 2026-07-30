class_name NotificationQueue
extends Control

## Event-driven notification presentation layer for tables G1a-G1d and G4.
##
## Gameplay systems never enqueue notifications directly. Every notification
## starts at an EventBus signal named by EVENT_NOTIFICATION_MAP. Assist-mode
## handlers are presentation hooks reserved for T-33a integration; no gameplay
## or assembly script calls them in this task.

const LOG_PREFIX := "[UI]"
const TOP_UI_HEIGHT_PX := 40
const STACK_GAP_PX := 4
const FONT_SIZE_PX := 10
const RESOURCE_TARGET_X := {
	&"nutrient_energy": 20,
	&"cell_material": 124,
	&"development_signal": 228,
	&"waste": 332,
	&"stability": 436,
	&"knowledge_badges": 540,
}

const TIER_BROADCAST := &"broadcast"
const TIER_ATTRIBUTION := &"attribution"
const TIER_PRESSURE := &"pressure"
const TIER_ALERT := &"alert"

## Pixel geometry is transcribed from docs/UI_LAYOUT.md tables G1a-G1d.
## It is intentionally not Balance-configurable.
const TIER_SPECS := {
	TIER_BROADCAST: {
		&"size": Vector2(112, 32),
		&"border": 1,
		&"padding_h": 4,
		&"padding_v": 5,
		&"rail": 1,
		&"icon": 8,
		&"line_height": 10,
		&"max_lines": 1,
		&"max_chars": 9,
		&"entry_sec": 0.160,
		&"exit_sec": 0.180,
		&"shape": &"square",
		&"rail_color": Color("#73CD9B"),
	},
	TIER_ATTRIBUTION: {
		&"size": Vector2(128, 32),
		&"border": 1,
		&"padding_h": 4,
		&"padding_v": 5,
		&"rail": 2,
		&"icon": 8,
		&"line_height": 10,
		&"max_lines": 2,
		&"max_chars": 10,
		&"entry_sec": 0.260,
		&"exit_sec": 0.240,
		&"shape": &"rounded",
		&"rail_color": Color("#48A5CF"),
	},
	TIER_PRESSURE: {
		&"size": Vector2(128, 32),
		&"border": 2,
		&"padding_h": 4,
		&"padding_v": 4,
		&"rail": 3,
		&"icon": 16,
		&"line_height": 10,
		&"max_lines": 2,
		&"max_chars": 9,
		&"entry_sec": 0.220,
		&"exit_sec": 0.220,
		&"shape": &"cut",
		&"rail_color": Color("#404586"),
	},
	TIER_ALERT: {
		&"size": Vector2(144, 48),
		&"border": 3,
		&"padding_h": 4,
		&"padding_v": 11,
		&"rail": 4,
		&"icon": 16,
		&"line_height": 10,
		&"max_lines": 2,
		&"max_chars": 10,
		&"entry_sec": 0.240,
		&"exit_sec": 0.280,
		&"shape": &"cut",
		&"rail_color": Color("#C25453"),
	},
}

## Table G4. Adding a notification means adding a data row, not an event-type
## branch. `first_tier`/`repeat_tier` encode the E11 downgrade rule in data.
## `merge_group` appears only on EVENT_API rows whose frequency is
## "repeatable within one tick".
const EVENT_NOTIFICATION_MAP: Array[Dictionary] = [
	{
		&"event_name": &"organ_built",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.organ_built",
		&"placeholder": "[built]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"map_organ",
		&"merge_group": &"organ_built",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"operation_result_settled",
		&"tier": TIER_ATTRIBUTION,
		&"copy_key": &"notification.operation_result",
		&"placeholder": "[result]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"none",
		&"icon": &"knowledge_impulse",
	},
	{
		&"event_name": &"transport_pressure_appeared",
		&"tier": TIER_ATTRIBUTION,
		&"first_tier": TIER_ATTRIBUTION,
		&"repeat_tier": TIER_BROADCAST,
		&"copy_key": &"notification.transport_pressure",
		&"placeholder": "[press]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"map_organ",
		&"merge_group": &"transport_pressure_appeared",
		&"icon": &"knowledge_impulse",
		&"tutorial": true,
	},
	{
		&"event_name": &"waste_buildup_appeared",
		&"tier": TIER_ATTRIBUTION,
		&"first_tier": TIER_ATTRIBUTION,
		&"repeat_tier": TIER_BROADCAST,
		&"copy_key": &"notification.waste_processing",
		&"placeholder": "[waste]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"map_organ",
		&"merge_group": &"waste_buildup_appeared",
		&"icon": &"knowledge_impulse",
		&"tutorial": true,
	},
	{
		&"event_name": &"signal_gap_appeared",
		&"tier": TIER_ATTRIBUTION,
		&"first_tier": TIER_ATTRIBUTION,
		&"repeat_tier": TIER_BROADCAST,
		&"copy_key": &"notification.signal_coordination",
		&"placeholder": "[signal]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"map_organ",
		&"merge_group": &"signal_gap_appeared",
		&"icon": &"knowledge_impulse",
		&"tutorial": true,
	},
	{
		&"event_name": &"transport_pressure_cleared",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.transport_recovered",
		&"placeholder": "[clear]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"map_organ",
		&"merge_group": &"transport_pressure_cleared",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"waste_buildup_cleared",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.waste_recovered",
		&"placeholder": "[clear]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"map_organ",
		&"merge_group": &"waste_buildup_cleared",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"signal_gap_cleared",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.signal_recovered",
		&"placeholder": "[clear]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"map_organ",
		&"merge_group": &"signal_gap_cleared",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"stability_band_changed",
		&"tier": TIER_ALERT,
		&"first_tier": TIER_ATTRIBUTION,
		&"repeat_tier": TIER_BROADCAST,
		&"alert_when": {&"argument_index": 1, &"minimum": 2},
		&"heartbeat_band_argument_index": 1,
		&"copy_key": &"notification.stability_response",
		&"placeholder": "[stable]",
		&"dwell_path": "notifications.dwell_sec.alert",
		&"exit_target": &"resource_stability",
		&"icon": &"ui_bottleneck_transport_pressure",
		&"tutorial": true,
		&"presentation_rules": [
			{
				&"conditions": [
					{
						&"argument_index": 1,
						&"less_than_argument_index": 0,
					},
				],
				&"tier": TIER_BROADCAST,
				&"first_tier": TIER_BROADCAST,
				&"repeat_tier": TIER_BROADCAST,
				&"dwell_path": "notifications.dwell_sec.broadcast",
				&"icon": &"cell_division",
				&"tutorial": false,
				&"counts_for_occurrence": false,
			},
		],
	},
	{
		&"event_name": &"waste_overflowed",
		&"tier": TIER_ALERT,
		&"copy_key": &"notification.waste_overflow",
		&"placeholder": "[overflow]",
		&"dwell_path": "notifications.dwell_sec.alert",
		&"exit_target": &"resource_waste",
		&"icon": &"ui_bottleneck_waste_accumulation",
	},
	{
		&"event_name": &"resource_shortage_raised",
		&"tier": TIER_PRESSURE,
		&"copy_key": &"notification.resource_shortage",
		&"placeholder": "[low]",
		&"dwell_path": "notifications.dwell_sec.pressure",
		&"exit_target": &"resource_argument_0",
		&"merge_group": &"investable_resource_shortage",
		&"icon": &"ui_bottleneck_transport_pressure",
	},
	{
		&"event_name": &"resource_shortage_cleared",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.resource_recovered",
		&"placeholder": "[restore]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"resource_argument_0",
		&"merge_group": &"resource_shortage_cleared",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"minigame_exited",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.minigame_resolved",
		&"placeholder": "[done]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"none",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"minigame_rated",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.minigame_rated",
		&"placeholder": "[rated]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"none",
		&"icon": &"cell_division",
	},
	{
		&"event_name": &"system_observation_ended",
		&"tier": TIER_ATTRIBUTION,
		&"copy_key": &"notification.system_observed",
		&"placeholder": "[observed]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"map_organ",
		&"icon": &"knowledge_impulse",
	},
	{
		&"event_name": &"knowledge_entry_unlocked",
		&"tier": TIER_BROADCAST,
		&"copy_key": &"notification.knowledge_unlocked",
		&"placeholder": "[unlock]",
		&"dwell_path": "notifications.dwell_sec.broadcast",
		&"exit_target": &"resource_knowledge_badges",
		&"merge_group": &"knowledge_entry_unlocked",
		&"icon": &"cell_division",
		&"presentation_rules": [
			{
				&"conditions": [
					{
						&"argument_index": 0,
						&"equals": &"hint_neural_tube_compensation",
					},
					{
						&"argument_index": 2,
						&"equals": &"stage_circulation",
					},
				],
				&"tier": TIER_ATTRIBUTION,
				&"copy_key": &"notification.neural_tube_compensation",
				&"placeholder": "[tube]",
				&"dwell_path": "notifications.dwell_sec.attribution",
				&"exit_target": &"map_organ",
				&"target_argument_index": 1,
				&"merge_group": &"",
				&"supersedes_merge_groups": [&"signal_gap_appeared"],
				&"icon": &"knowledge_impulse",
				&"tutorial": true,
			},
		],
	},
	{
		&"event_name": &"delayed_feedback_shown",
		&"tier": TIER_ATTRIBUTION,
		&"copy_key": &"notification.delayed_feedback",
		&"placeholder": "[carry]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"none",
		&"icon": &"knowledge_impulse",
		&"tutorial": true,
	},
	{
		&"event_name": &"action_rejected",
		&"tier": TIER_PRESSURE,
		&"copy_key": &"notification.action_rejected",
		&"placeholder": "[blocked]",
		&"dwell_path": "notifications.dwell_sec.pressure",
		&"exit_target": &"none",
		&"merge_group": &"action_rejected",
		&"icon": &"ui_bottleneck_transport_pressure",
	},
	{
		&"event_name": &"birth_sequence_started",
		&"tier": TIER_ATTRIBUTION,
		&"first_tier": TIER_ATTRIBUTION,
		&"repeat_tier": TIER_BROADCAST,
		&"copy_key": &"notification.birth_transition",
		&"placeholder": "[shift]",
		&"dwell_path": "notifications.dwell_sec.attribution",
		&"exit_target": &"none",
		&"icon": &"knowledge_impulse",
		&"tutorial": true,
	},
	{
		&"event_name": &"birth_rolled_back",
		&"tier": TIER_ALERT,
		&"copy_key": &"notification.birth_retry",
		&"placeholder": "[retry]",
		&"dwell_path": "notifications.dwell_sec.alert",
		&"exit_target": &"none",
		&"icon": &"ui_bottleneck_signal_coverage_low",
	},
]

var _visible: Array[Dictionary] = []
var _waiting: Array[Dictionary] = []
var _pending_merges: Dictionary = {}
var _seen_events: Dictionary = {}
var _merge_timer_active := false
var _assist_mode_active := false
var _alert_phase_sec := 0.0
var _leader_points := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_events()
	if not EventBus.stage_loaded.is_connected(_on_stage_loaded):
		EventBus.stage_loaded.connect(_on_stage_loaded)
	set_process(true)


func _process(delta: float) -> void:
	_update_dwell(delta)
	_update_alert_heartbeat(delta)


## Read-only snapshots for acceptance tests and debug overlays.
func visible_notifications() -> Array[Dictionary]:
	return _public_snapshots(_visible)


func queued_notifications() -> Array[Dictionary]:
	return _public_snapshots(_waiting)


func visible_card_sizes() -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	for notification in _visible:
		var card: Control = notification.get(&"card")
		if card != null and is_instance_valid(card):
			sizes.append(card.size)
	return sizes


func _connect_events() -> void:
	for row in EVENT_NOTIFICATION_MAP:
		var event_name: StringName = row[&"event_name"]
		if not EventBus.has_signal(event_name):
			push_error("%s Table G4 names unknown EventBus signal '%s'." % [LOG_PREFIX, event_name])
			continue
		var relay := Callable(
			self,
			"_capture_%d" % _signal_argument_count(event_name)
		).bind(event_name)
		if not EventBus.is_connected(event_name, relay):
			EventBus.connect(event_name, relay)


func _signal_argument_count(event_name: StringName) -> int:
	for signal_info in EventBus.get_signal_list():
		if StringName(signal_info["name"]) == event_name:
			return (signal_info["args"] as Array).size()
	return 0


func _on_stage_loaded(
	_stage_id: StringName,
	_stage_index: int
) -> void:
	# E11's first/repeat downgrade is scoped to one developmental segment.
	_seen_events.clear()


func _capture_1(a0: Variant, event_name: StringName) -> void:
	_accept_event(event_name, [a0])


func _capture_2(a0: Variant, a1: Variant, event_name: StringName) -> void:
	_accept_event(event_name, [a0, a1])


func _capture_3(a0: Variant, a1: Variant, a2: Variant, event_name: StringName) -> void:
	_accept_event(event_name, [a0, a1, a2])


func _capture_4(
	a0: Variant,
	a1: Variant,
	a2: Variant,
	a3: Variant,
	event_name: StringName
) -> void:
	_accept_event(event_name, [a0, a1, a2, a3])


func _accept_event(event_name: StringName, arguments: Array) -> void:
	var row := _mapping_for(event_name)
	if row.is_empty():
		return
	row = _resolved_presentation(row, arguments)
	_apply_pending_supersession(row)

	var occurrence := int(_seen_events.get(event_name, 0))
	if bool(row.get(&"counts_for_occurrence", true)):
		_seen_events[event_name] = occurrence + 1
	var tier: StringName = row.get(
		&"first_tier" if occurrence == 0 else &"repeat_tier",
		row[&"tier"]
	)
	tier = _conditional_alert_tier(row, arguments, tier)
	var dwell_path := String(row[&"dwell_path"])
	if tier != StringName(row[&"tier"]):
		dwell_path = "notifications.dwell_sec.%s" % tier
	var notification := {
		&"event_name": event_name,
		&"tier": tier,
		&"copy_key": row[&"copy_key"],
		&"placeholder": row[&"placeholder"],
		&"dwell_path": dwell_path,
		&"exit_target": row[&"exit_target"],
		&"target_argument_index": int(
			row.get(&"target_argument_index", 0)
		),
		&"icon": row[&"icon"],
		&"tutorial": bool(row.get(&"tutorial", false)),
		&"heartbeat_band_argument_index": int(
			row.get(&"heartbeat_band_argument_index", -1)
		),
		&"arguments": arguments.duplicate(true),
		&"merged_count": 1,
		&"remaining_sec": _dwell_seconds(dwell_path),
	}

	var merge_group: StringName = row.get(&"merge_group", &"")
	if merge_group == &"":
		_publish(notification)
		return
	if _pending_merges.has(merge_group):
		var pending: Dictionary = _pending_merges[merge_group]
		pending[&"merged_count"] = int(pending[&"merged_count"]) + 1
		(pending[&"arguments"] as Array).append(arguments.duplicate(true))
		return
	notification[&"arguments"] = [arguments.duplicate(true)]
	_pending_merges[merge_group] = notification
	_start_merge_timer()


func _apply_pending_supersession(row: Dictionary) -> void:
	for merge_group: Variant in row.get(&"supersedes_merge_groups", []):
		_pending_merges.erase(StringName(merge_group))


func _resolved_presentation(row: Dictionary, arguments: Array) -> Dictionary:
	var resolved := row.duplicate(true)
	for rule in row.get(&"presentation_rules", []):
		if not _rule_matches(rule, arguments):
			continue
		for key: Variant in rule:
			if key != &"conditions":
				resolved[key] = rule[key]
		break
	return resolved


func _rule_matches(rule: Dictionary, arguments: Array) -> bool:
	for condition in rule.get(&"conditions", []):
		var index := int(condition.get(&"argument_index", -1))
		if index < 0 or index >= arguments.size():
			return false
		if (
			condition.has(&"equals")
			and arguments[index] != condition[&"equals"]
		):
			return false
		if condition.has(&"less_than_argument_index"):
			var other_index := int(condition[&"less_than_argument_index"])
			if (
				other_index < 0
				or other_index >= arguments.size()
				or float(arguments[index]) >= float(arguments[other_index])
			):
				return false
	return true


func _conditional_alert_tier(
	row: Dictionary,
	arguments: Array,
	fallback: StringName
) -> StringName:
	var rule: Dictionary = row.get(&"alert_when", {})
	if rule.is_empty():
		return fallback
	var index := int(rule.get(&"argument_index", -1))
	if index < 0 or index >= arguments.size():
		return fallback
	if (
		rule.has(&"minimum")
		and float(arguments[index]) >= float(rule[&"minimum"])
	):
		return TIER_ALERT
	if (
		rule.has(&"maximum")
		and float(arguments[index]) <= float(rule[&"maximum"])
	):
		return TIER_ALERT
	return fallback


func _mapping_for(event_name: StringName) -> Dictionary:
	for row in EVENT_NOTIFICATION_MAP:
		if StringName(row[&"event_name"]) == event_name:
			return row
	return {}


func _start_merge_timer() -> void:
	if _merge_timer_active:
		return
	_merge_timer_active = true
	var window_ms := maxi(
		0,
		int(Balance.get_value("notifications.merge_window_ms", 0))
	)
	get_tree().create_timer(float(window_ms) / 1000.0).timeout.connect(
		_flush_pending_merges
	)


func _flush_pending_merges() -> void:
	_merge_timer_active = false
	for merge_group in _pending_merges:
		_publish(_pending_merges[merge_group])
	_pending_merges.clear()


func _publish(notification: Dictionary) -> void:
	var tier: StringName = notification[&"tier"]
	if tier == TIER_ALERT:
		_defer_visible_tutorials()
		if _visible_count(TIER_ALERT) >= _balance_capacity(&"alert"):
			_waiting.append(notification)
		else:
			_show(notification, 0)
		return

	if bool(notification[&"tutorial"]) and _visible_count(TIER_ALERT) > 0:
		_waiting.append(notification)
		return

	if tier == TIER_BROADCAST:
		_drop_oldest_broadcast_if_full()
		_show(notification)
		return

	if _shared_visible_count() < _balance_capacity(&"shared"):
		_show(notification)
	else:
		_waiting.append(notification)


func _show(notification: Dictionary, insertion_index: int = -1) -> void:
	var shown := notification.duplicate(true)
	var card := _build_card(shown)
	shown[&"card"] = card
	add_child(card)
	if insertion_index >= 0:
		_visible.insert(insertion_index, shown)
	else:
		_visible.append(shown)
	_layout_visible()
	_animate_entry(shown)


func _drop_oldest_broadcast_if_full() -> void:
	var capacity := _balance_capacity(&"broadcast")
	if _visible_count(TIER_BROADCAST) < capacity:
		return
	for index in _visible.size():
		if StringName(_visible[index][&"tier"]) == TIER_BROADCAST:
			_remove_visible(index, false)
			return


func _defer_visible_tutorials() -> void:
	for index in range(_visible.size() - 1, -1, -1):
		if (
			bool(_visible[index].get(&"tutorial", false))
			and StringName(_visible[index][&"tier"]) != TIER_ALERT
		):
			var deferred := _visible[index].duplicate(true)
			var card: Control = deferred.get(&"card")
			deferred.erase(&"card")
			if card != null and is_instance_valid(card):
				card.queue_free()
			_visible.remove_at(index)
			_waiting.push_front(deferred)


func _update_dwell(delta: float) -> void:
	for index in range(_visible.size() - 1, -1, -1):
		var notification := _visible[index]
		var card: Control = notification.get(&"card")
		if (
			card != null
			and is_instance_valid(card)
			and bool(card.get_meta("entry_active", false))
		):
			continue
		if (
			_assist_mode_active
			and StringName(notification[&"tier"]) == TIER_ALERT
		):
			continue
		notification[&"remaining_sec"] = (
			float(notification[&"remaining_sec"]) - delta
		)
		if float(notification[&"remaining_sec"]) <= 0.0:
			_remove_visible(index, true)


func _remove_visible(index: int, animate: bool) -> void:
	if index < 0 or index >= _visible.size():
		return
	var notification := _visible[index]
	_visible.remove_at(index)
	var card: Control = notification.get(&"card")
	if card != null and is_instance_valid(card):
		if animate:
			_animate_exit(card, notification)
		else:
			card.queue_free()
	_promote_waiting()
	_layout_visible()


func _promote_waiting() -> void:
	var alert_index := _waiting_index_for_tier(TIER_ALERT)
	if (
		alert_index >= 0
		and _visible_count(TIER_ALERT) < _balance_capacity(&"alert")
	):
		var alert := _waiting[alert_index]
		_waiting.remove_at(alert_index)
		_show(alert, 0)
		return
	if _visible_count(TIER_ALERT) > 0:
		return
	var index := 0
	while (
		index < _waiting.size()
		and _shared_visible_count() < _balance_capacity(&"shared")
	):
		var tier: StringName = _waiting[index][&"tier"]
		if tier == TIER_ATTRIBUTION or tier == TIER_PRESSURE:
			var notification := _waiting[index]
			_waiting.remove_at(index)
			_show(notification)
		else:
			index += 1


func _waiting_index_for_tier(tier: StringName) -> int:
	for index in _waiting.size():
		if StringName(_waiting[index][&"tier"]) == tier:
			return index
	return -1


func _visible_count(tier: StringName) -> int:
	var count := 0
	for notification in _visible:
		if StringName(notification[&"tier"]) == tier:
			count += 1
	return count


func _shared_visible_count() -> int:
	return _visible_count(TIER_ATTRIBUTION) + _visible_count(TIER_PRESSURE)


func _balance_capacity(slot: StringName) -> int:
	return maxi(
		1,
		int(Balance.get_value("notifications.max_stack.%s" % slot, 1))
	)


func _dwell_seconds(path: String) -> float:
	var dwell := maxf(0.01, float(Balance.get_value(path, 0.01)))
	if _assist_mode_active:
		dwell *= maxf(
			1.0,
			float(Balance.get_value("notifications.assist.dwell_multiplier", 1.0))
		)
	return dwell


func _on_assist_mode_entered(
	_scope_id: StringName,
	_parameters: Dictionary
) -> void:
	_assist_mode_active = true
	_reset_dwell_for(_visible)
	_reset_dwell_for(_waiting)
	_update_alert_close_controls()


func _on_assist_mode_left(_scope_id: StringName) -> void:
	_assist_mode_active = false
	_reset_dwell_for(_visible)
	_reset_dwell_for(_waiting)
	_update_alert_close_controls()


func _reset_dwell_for(notifications: Array[Dictionary]) -> void:
	for notification in notifications:
		notification[&"remaining_sec"] = _dwell_seconds(
			String(notification[&"dwell_path"])
		)


func _update_alert_close_controls() -> void:
	for notification in _visible:
		if StringName(notification[&"tier"]) != TIER_ALERT:
			continue
		var card: Control = notification.get(&"card")
		if card == null or not is_instance_valid(card):
			continue
		var close := card.get_node_or_null("Close") as Button
		if close != null:
			close.visible = _assist_mode_active
			close.mouse_filter = (
				Control.MOUSE_FILTER_STOP
				if _assist_mode_active
				else Control.MOUSE_FILTER_IGNORE
			)


func _dismiss_assist_alert(card: Control) -> void:
	if not _assist_mode_active:
		return
	for index in _visible.size():
		if _visible[index].get(&"card") == card:
			_remove_visible(index, true)
			return


func _build_card(notification: Dictionary) -> Control:
	var tier: StringName = notification[&"tier"]
	var spec: Dictionary = TIER_SPECS[tier]
	var card := Control.new()
	card.name = "Notification_%s" % notification[&"event_name"]
	card.size = spec[&"size"]
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("tier", tier)

	var background := Polygon2D.new()
	background.name = "OpaqueSurface"
	background.polygon = _shape_polygon(spec)
	background.color = Color("#514854")
	card.add_child(background)

	var border := Line2D.new()
	border.name = "TierBorder_%dpx" % int(spec[&"border"])
	border.points = _closed_points(background.polygon)
	border.width = float(spec[&"border"])
	border.default_color = Color("#140F1D")
	border.antialiased = false
	card.add_child(border)

	var rail := ColorRect.new()
	rail.name = "SemanticRail_%dpx" % int(spec[&"rail"])
	rail.color = spec[&"rail_color"]
	rail.position = Vector2(
		float(spec[&"border"] + spec[&"padding_h"]),
		float(spec[&"border"] + spec[&"padding_v"])
	)
	rail.size = Vector2(
		float(spec[&"rail"]),
		float(spec[&"size"].y - 2 * (
			spec[&"border"] + spec[&"padding_v"]
		))
	)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rail)

	var icon_position := Vector2(
		rail.position.x + rail.size.x + 2.0,
		floorf((float(spec[&"size"].y) - float(spec[&"icon"])) / 2.0)
	)
	_add_tier_icon(card, notification, icon_position, int(spec[&"icon"]))

	var label := Label.new()
	label.name = "PlaceholderCopy"
	label.text = _fit_text(
		StringName(notification[&"copy_key"]),
		String(notification[&"placeholder"]),
		tier
	)
	label.position = Vector2(
		icon_position.x + float(spec[&"icon"]) + 2.0,
		float(spec[&"border"] + spec[&"padding_v"])
	)
	label.size = Vector2(
		float(spec[&"size"].x) - label.position.x - float(
			spec[&"border"] + spec[&"padding_h"]
		),
		float(spec[&"max_lines"] * spec[&"line_height"])
	)
	label.add_theme_font_size_override("font_size", FONT_SIZE_PX)
	label.add_theme_color_override("font_color", Color("#F4FFF8"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)

	if tier == TIER_ATTRIBUTION:
		var impulse := ColorRect.new()
		impulse.name = "NeuralImpulsePixel"
		impulse.color = Color("#7AD1FD")
		impulse.position = Vector2(1, 1)
		impulse.size = Vector2.ONE
		impulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(impulse)
	if tier == TIER_PRESSURE:
		for particle_index in 3:
			var particle := ColorRect.new()
			particle.name = "SeepParticle%d" % (particle_index + 1)
			particle.color = Color("#404586")
			particle.position = Vector2(
				float(spec[&"size"].x) - 2.0,
				6.0 + float(particle_index * 8)
			)
			particle.size = Vector2.ONE
			particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(particle)

	if tier == TIER_ALERT:
		var close := Button.new()
		close.name = "Close"
		close.text = "x"
		close.position = Vector2(float(spec[&"size"].x) - 12.0, 3.0)
		close.size = Vector2(9, 9)
		close.flat = true
		close.visible = _assist_mode_active
		close.add_theme_font_size_override("font_size", FONT_SIZE_PX)
		close.add_theme_color_override("font_color", Color("#F4FFF8"))
		close.add_theme_color_override("font_hover_color", Color("#CDD9E1"))
		close.add_theme_color_override("font_pressed_color", Color("#E8DCCF"))
		close.pressed.connect(_dismiss_assist_alert.bind(card))
		card.add_child(close)
	return card


func _shape_polygon(spec: Dictionary) -> PackedVector2Array:
	var width: float = spec[&"size"].x
	var height: float = spec[&"size"].y
	var shape: StringName = spec[&"shape"]
	if shape == &"rounded":
		return PackedVector2Array([
			Vector2(2, 0), Vector2(width - 2, 0),
			Vector2(width, 2), Vector2(width, height - 2),
			Vector2(width - 2, height), Vector2(2, height),
			Vector2(0, height - 2), Vector2(0, 2),
		])
	if shape == &"cut":
		return PackedVector2Array([
			Vector2(5, 0), Vector2(width, 0), Vector2(width, height),
			Vector2(0, height), Vector2(0, 5),
		])
	return PackedVector2Array([
		Vector2(0, 0), Vector2(width, 0), Vector2(width, height),
		Vector2(0, height),
	])


func _closed_points(polygon: PackedVector2Array) -> PackedVector2Array:
	var closed := polygon.duplicate()
	if not polygon.is_empty():
		closed.append(polygon[0])
	return closed


func _add_tier_icon(
	card: Control,
	notification: Dictionary,
	icon_position: Vector2,
	icon_size: int
) -> void:
	var logical_name: StringName = notification[&"icon"]
	if String(logical_name).begins_with("ui_bottleneck_"):
		var texture_rect := TextureRect.new()
		texture_rect.name = "D16BottleneckIcon"
		texture_rect.texture = AssetLoader.get_static_texture(logical_name)
		texture_rect.position = icon_position
		texture_rect.size = Vector2(icon_size, icon_size)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(texture_rect)
		return
	if logical_name == &"knowledge_impulse":
		var knowledge_texture := AtlasTexture.new()
		knowledge_texture.atlas = AssetLoader.get_static_texture(
			&"ui_resource_knowledge_badge_count"
		)
		knowledge_texture.region = Rect2(4, 4, 8, 8)
		knowledge_texture.filter_clip = true
		var knowledge_icon := TextureRect.new()
		knowledge_icon.name = "KnowledgeStarGlyph"
		knowledge_icon.texture = knowledge_texture
		knowledge_icon.position = icon_position
		knowledge_icon.size = Vector2(8, 8)
		knowledge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		knowledge_icon.stretch_mode = TextureRect.STRETCH_KEEP
		knowledge_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		knowledge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(knowledge_icon)
		return

	var glyph := Control.new()
	glyph.name = "CellDivisionGlyph"
	glyph.position = icon_position
	glyph.size = Vector2(icon_size, icon_size)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glyph)
	var first := ColorRect.new()
	first.color = Color("#B1FFD1")
	first.position = Vector2(0, 2)
	first.size = Vector2(maxi(2, icon_size / 2 - 1), maxi(2, icon_size - 4))
	first.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(first)
	var second := ColorRect.new()
	second.color = first.color
	second.position = Vector2(float(icon_size / 2 + 1), 2)
	second.size = first.size
	second.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_child(second)


func _fit_text(
	copy_key: StringName,
	placeholder: String,
	tier: StringName
) -> String:
	var spec: Dictionary = TIER_SPECS[tier]
	var lines := placeholder.split("\n")
	var max_lines := int(spec[&"max_lines"])
	var max_chars := int(spec[&"max_chars"])
	var truncated := lines.size() > max_lines
	var fitted := PackedStringArray()
	for index in mini(lines.size(), max_lines):
		var line := lines[index]
		if line.length() > max_chars:
			line = line.substr(0, max_chars)
			truncated = true
		fitted.append(line)
	if truncated:
		push_warning(
			"%s copy key '%s' exceeds G1%s capacity and was truncated."
			% [LOG_PREFIX, copy_key, tier]
		)
	return "\n".join(fitted)


func _layout_visible() -> void:
	var y := float(TOP_UI_HEIGHT_PX)
	for notification in _visible:
		var card: Control = notification.get(&"card")
		if card == null or not is_instance_valid(card):
			continue
		var tier: StringName = notification[&"tier"]
		var locked_size: Vector2 = TIER_SPECS[tier][&"size"]
		card.position = Vector2(640.0 - locked_size.x, y)
		y += locked_size.y + float(STACK_GAP_PX)
	_update_leader_line()


func _animate_entry(notification: Dictionary) -> void:
	var card: Control = notification[&"card"]
	var tier: StringName = notification[&"tier"]
	var spec: Dictionary = TIER_SPECS[tier]
	card.set_meta("entry_active", true)
	if tier == TIER_BROADCAST:
		_unfold_broadcast(card, float(spec[&"entry_sec"]))
		return
	if tier == TIER_ATTRIBUTION:
		_trace_attribution_impulse(card, float(spec[&"entry_sec"]))
		return
	if tier == TIER_PRESSURE:
		_seep_pressure_particles(card, float(spec[&"entry_sec"]))
		return
	_pulse_alert_entry(card, float(spec[&"entry_sec"]))


func _unfold_broadcast(card: Control, duration: float) -> void:
	var full_size := card.size
	var full_position := card.position
	var frame_count := maxi(1, roundi(duration * 60.0))
	for frame_index in frame_count:
		if not is_instance_valid(card):
			return
		var progress := float(frame_index + 1) / float(frame_count)
		var width := roundf(lerpf(16.0, full_size.x, progress))
		card.size = Vector2(width, full_size.y)
		card.position = Vector2(
			roundf(full_position.x + full_size.x - width),
			full_position.y
		)
		await get_tree().process_frame
	if is_instance_valid(card):
		card.size = full_size
		card.position = full_position
		card.set_meta("entry_active", false)


func _trace_attribution_impulse(card: Control, duration: float) -> void:
	var impulse := card.get_node_or_null("NeuralImpulsePixel") as ColorRect
	var label := card.get_node_or_null("PlaceholderCopy") as Label
	if impulse == null:
		card.set_meta("entry_active", false)
		return
	if label != null:
		label.visible = false
	var frame_count := maxi(1, roundi(duration * 60.0))
	var perimeter := 2.0 * (card.size.x + card.size.y - 4.0)
	for frame_index in frame_count:
		if not is_instance_valid(impulse):
			return
		var distance := perimeter * float(frame_index + 1) / float(frame_count)
		impulse.position = _perimeter_position(card.size, distance)
		await get_tree().process_frame
	if label != null and is_instance_valid(label):
		label.show()
	if is_instance_valid(impulse):
		impulse.hide()
	if is_instance_valid(card):
		card.set_meta("entry_active", false)


func _perimeter_position(card_size: Vector2, distance: float) -> Vector2:
	var horizontal := card_size.x - 2.0
	var vertical := card_size.y - 2.0
	var wrapped := fmod(distance, 2.0 * (horizontal + vertical))
	if wrapped <= horizontal:
		return Vector2(roundf(1.0 + wrapped), 1)
	wrapped -= horizontal
	if wrapped <= vertical:
		return Vector2(card_size.x - 1.0, roundf(1.0 + wrapped))
	wrapped -= vertical
	if wrapped <= horizontal:
		return Vector2(roundf(card_size.x - 1.0 - wrapped), card_size.y - 1.0)
	wrapped -= horizontal
	return Vector2(1, roundf(card_size.y - 1.0 - wrapped))


func _seep_pressure_particles(card: Control, duration: float) -> void:
	var particles: Array[ColorRect] = []
	var start_x: Array[float] = []
	for particle_index in 3:
		var particle := card.get_node_or_null(
			"SeepParticle%d" % (particle_index + 1)
		) as ColorRect
		if particle != null:
			particles.append(particle)
			start_x.append(particle.position.x)
	var frame_count := maxi(1, roundi(duration * 60.0))
	for frame_index in frame_count:
		var progress := float(frame_index + 1) / float(frame_count)
		for particle_index in particles.size():
			var particle := particles[particle_index]
			if is_instance_valid(particle):
				particle.position.x = roundf(
					start_x[particle_index]
					- (4.0 + float(particle_index)) * progress
				)
		await get_tree().process_frame
	for particle in particles:
		if is_instance_valid(particle):
			particle.hide()
	if is_instance_valid(card):
		card.set_meta("entry_active", false)


func _pulse_alert_entry(card: Control, duration: float) -> void:
	card.set_meta("entry_pulse", true)
	_set_alert_inset(card, true)
	await get_tree().create_timer(duration / 2.0).timeout
	if not is_instance_valid(card):
		return
	_set_alert_inset(card, false)
	await get_tree().create_timer(duration / 2.0).timeout
	if is_instance_valid(card):
		card.set_meta("entry_pulse", false)
		card.set_meta("entry_active", false)


func _animate_exit(card: Control, notification: Dictionary) -> void:
	var tier: StringName = notification[&"tier"]
	var spec: Dictionary = TIER_SPECS[tier]
	var target := _exit_target_position(notification, card.global_position)
	_contract_and_fly(card, target, float(spec[&"exit_sec"]))


func _contract_and_fly(card: Control, target: Vector2, duration: float) -> void:
	var start_position := card.global_position
	var start_size := card.size
	var frame_count := maxi(1, roundi(duration * 60.0))
	for frame_index in frame_count:
		if not is_instance_valid(card):
			return
		var progress := float(frame_index + 1) / float(frame_count)
		card.global_position = start_position.lerp(target, progress).round()
		card.size = start_size.lerp(Vector2(16, 16), progress).round()
		await get_tree().process_frame
	if is_instance_valid(card):
		card.queue_free()


func _exit_target_position(
	notification: Dictionary,
	fallback: Vector2
) -> Vector2:
	var target: String = String(notification[&"exit_target"])
	if target == "none":
		return fallback + Vector2(_cardinal_sign(fallback.x - 320.0) * 16.0, 0)
	if target.begins_with("resource_"):
		var resource_id := StringName(target.trim_prefix("resource_"))
		if resource_id == &"argument_0":
			var arguments: Array = notification[&"arguments"]
			if not arguments.is_empty():
				var first: Variant = arguments[0]
				resource_id = StringName(str(
					first[0] if first is Array and not first.is_empty() else first
				))
		return Vector2(float(RESOURCE_TARGET_X.get(resource_id, 540)), 8)
	var target_node := _target_canvas_item(notification)
	if target_node is Control:
		var control := target_node as Control
		return control.global_position + control.size / 2.0
	if target_node is Node2D:
		var node_2d := target_node as Node2D
		if node_2d is Sprite2D and (node_2d as Sprite2D).texture != null:
			var sprite := node_2d as Sprite2D
			var half_size := Vector2(sprite.texture.get_size()) / 2.0
			return sprite.global_position if sprite.centered else sprite.global_position + half_size
		return node_2d.global_position
	return Vector2(320, 180)


func _target_canvas_item(notification: Dictionary) -> CanvasItem:
	var subject_id := _subject_id(notification)
	if subject_id == &"":
		return null
	var grouped := get_tree().get_first_node_in_group(
		"notification_target_%s" % subject_id
	) as CanvasItem
	if grouped != null:
		return grouped
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var edge_target := _edge_target_canvas_item(scene, subject_id)
	if edge_target != null:
		return edge_target
	var exact := scene.find_child("Organ_%s" % subject_id, true, false) as CanvasItem
	if exact != null:
		return exact
	var subject_text := String(subject_id)
	for candidate in scene.find_children("Organ_*", "", true, false):
		var organ_name := String(candidate.name).trim_prefix("Organ_")
		var family := organ_name.get_slice("_", 0)
		if subject_text.contains(organ_name) or subject_text.contains(family):
			return candidate as CanvasItem
	return null


func _edge_target_canvas_item(scene: Node, edge_id: StringName) -> CanvasItem:
	var network := scene.find_child("CityNetwork", true, false) as NetworkBuilder
	if network == null:
		return null
	var end_node_id := &""
	for edge_value: Variant in network.edges:
		if not edge_value is Dictionary:
			continue
		var edge := edge_value as Dictionary
		if StringName(edge.get(&"edge_id", &"")) == edge_id:
			end_node_id = StringName(edge.get(&"end_node_id", &""))
			break
	if end_node_id == &"":
		return null
	for node_value: Variant in network.nodes:
		if not node_value is Dictionary:
			continue
		var node_record := node_value as Dictionary
		if StringName(node_record.get(&"node_id", &"")) != end_node_id:
			continue
		var grid_position: Vector2i = node_record.get(
			&"grid_position",
			Vector2i(-1, -1)
		)
		return network.find_child(
			"Vessel_%02d_%02d" % [grid_position.x, grid_position.y],
			true,
			false
		) as CanvasItem
	return null


func _subject_id(notification: Dictionary) -> StringName:
	var arguments: Array = notification[&"arguments"]
	if arguments.is_empty():
		return &""
	var target_index := int(notification.get(&"target_argument_index", 0))
	if target_index < 0 or target_index >= arguments.size():
		return &""
	var first: Variant = arguments[target_index]
	return StringName(str(
		first[0] if first is Array and not first.is_empty() else first
	))


func _cardinal_sign(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0


func _update_alert_heartbeat(delta: float) -> void:
	var alert := _visible_notification(TIER_ALERT)
	if alert.is_empty():
		_alert_phase_sec = 0.0
		_leader_points = PackedVector2Array()
		queue_redraw()
		return
	var card: Control = alert.get(&"card")
	if card == null or not is_instance_valid(card):
		return
	var arguments: Array = alert[&"arguments"]
	var band := 0
	var band_index := int(alert.get(&"heartbeat_band_argument_index", -1))
	if band_index >= 0 and band_index < arguments.size():
		band = int(arguments[band_index])
	var bpm_keys: Array[StringName] = [&"stable", &"warning", &"critical"]
	var bpm_key: StringName = bpm_keys[clampi(band, 0, 2)]
	var bpm := maxf(
		1.0,
		float(Balance.get_value("notifications.alert_bpm.%s" % bpm_key, 60.0))
	)
	var period := 60.0 / bpm
	_alert_phase_sec = fmod(_alert_phase_sec + delta, period)
	var contracted := _alert_phase_sec < period * 0.18
	if not bool(card.get_meta("entry_pulse", false)):
		_set_alert_inset(card, contracted)
	_update_leader_line()


func _set_alert_inset(card: Control, contracted: bool) -> void:
	var background := card.get_node_or_null("OpaqueSurface") as Polygon2D
	var border := card.get_node_or_null("TierBorder_3px") as Line2D
	if background == null or border == null:
		return
	var spec: Dictionary = TIER_SPECS[TIER_ALERT]
	var polygon := _shape_polygon(spec)
	if contracted:
		polygon = PackedVector2Array([
			Vector2(6, 1),
			Vector2(card.size.x - 1, 1),
			Vector2(card.size.x - 1, card.size.y - 1),
			Vector2(1, card.size.y - 1),
			Vector2(1, 6),
		])
	background.polygon = polygon
	border.points = _closed_points(polygon)


func _visible_notification(tier: StringName) -> Dictionary:
	for notification in _visible:
		if StringName(notification[&"tier"]) == tier:
			return notification
	return {}


func _update_leader_line() -> void:
	var alert := _visible_notification(TIER_ALERT)
	if alert.is_empty():
		_leader_points = PackedVector2Array()
		queue_redraw()
		return
	var card: Control = alert.get(&"card")
	if card == null or not is_instance_valid(card):
		return
	var start := card.position + Vector2(0, card.size.y / 2.0)
	var target := _exit_target_position(alert, start)
	var target_item := _target_canvas_item(alert)
	var target_rect := _canvas_item_rect(target_item)
	if target_rect.size != Vector2.ZERO:
		target = Vector2(target_rect.end.x + 1.0, target_rect.get_center().y)
	_leader_points = _leader_route(start.round(), target.round(), target_item)
	queue_redraw()


func _leader_route(
	start: Vector2,
	target: Vector2,
	target_item: CanvasItem
) -> PackedVector2Array:
	var elbow_x := start.x - 8.0
	var min_y := minf(start.y, target.y)
	var max_y := maxf(start.y, target.y)
	for rect in _organ_rects(target_item):
		if (
			elbow_x >= rect.position.x
			and elbow_x <= rect.end.x
			and max_y >= rect.position.y
			and min_y <= rect.end.y
		):
			elbow_x = rect.end.x + 1.0
	var route := PackedVector2Array([
		start,
		Vector2(elbow_x, start.y).round(),
		Vector2(elbow_x, target.y).round(),
		target,
	])
	for rect in _organ_rects(target_item):
		if _horizontal_segment_hits(route[2], route[3], rect):
			var detour_y := rect.position.y - 1.0
			return PackedVector2Array([
				start,
				Vector2(elbow_x, start.y).round(),
				Vector2(elbow_x, detour_y).round(),
				Vector2(target.x, detour_y).round(),
				target,
			])
	return route


func _horizontal_segment_hits(
	first: Vector2,
	second: Vector2,
	rect: Rect2
) -> bool:
	return (
		first.y >= rect.position.y
		and first.y <= rect.end.y
		and maxf(first.x, second.x) >= rect.position.x
		and minf(first.x, second.x) <= rect.end.x
	)


func _organ_rects(excluded: CanvasItem) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var scene := get_tree().current_scene
	if scene == null:
		return rects
	for candidate in scene.find_children("Organ_*", "", true, false):
		var canvas_item := candidate as CanvasItem
		if canvas_item == null or canvas_item == excluded:
			continue
		var rect := _canvas_item_rect(canvas_item)
		if rect.size != Vector2.ZERO:
			rects.append(rect)
	return rects


func _canvas_item_rect(item: CanvasItem) -> Rect2:
	if item is Control:
		var control := item as Control
		return Rect2(control.global_position, control.size)
	if item is Sprite2D:
		var sprite := item as Sprite2D
		if sprite.texture == null:
			return Rect2()
		var size := Vector2(sprite.texture.get_size())
		var origin := (
			sprite.global_position - size / 2.0
			if sprite.centered
			else sprite.global_position
		)
		return Rect2(origin, size)
	if item is Node2D:
		return Rect2((item as Node2D).global_position - Vector2(8, 8), Vector2(16, 16))
	return Rect2()


func _draw() -> void:
	if _leader_points.size() >= 2:
		draw_polyline(_leader_points, Color("#C25453"), 1.0, false)


func _public_snapshots(source: Array[Dictionary]) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for notification in source:
		var snapshot := notification.duplicate(true)
		snapshot.erase(&"card")
		snapshots.append(snapshot)
	return snapshots
