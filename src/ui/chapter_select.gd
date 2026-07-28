class_name ChapterSelect
extends VBoxContainer

## Chapter select and replay.
##
## A player may re-enter a finished stage from its beginning without disturbing
## the main line. The single rule that makes replay honest is this: the starting
## conditions come from the snapshot written when that stage was first entered,
## never from Balance and never from the live save. Reading the live values would
## replay the stage as it is now rather than as it was, which is the opposite of
## what a replay is for.
##
## Nothing that happens in a replay reaches disk. The three saved blocks are read
## through SaveManager and never written, minigame stars earned here are not
## recorded, and leaving discards the scratch state entirely.
##
## The list is plain buttons on purpose. Styling belongs to D-14 and D-17; this
## script decides what is selectable and what a selection means.
##
## Requires the `EventBus`, `Balance`, and `SaveManager` autoloads.

const LOG_PREFIX := "[REPLAY]"

## Shown while a replay is in progress. Wording is provisional: T-31 owns
## docs/UI_COPY.md and should take it over once D-17 unblocks that task. It lives
## here so no build can present a replay without saying it is one.
const REPLAY_BANNER_TEXT := "Replay — nothing here is saved. Your main progress is untouched."

## Emitted on entering and leaving a replay, so the rest of the UI can lock,
## dim, or badge itself without asking this node anything.
signal replay_started(stage_id: StringName, start_conditions: Dictionary)
signal replay_ended(stage_id: StringName)

## True for the whole time a replay is running. Read-only from outside.
var replay_mode: bool:
	get:
		return _replay_stage_id != &""

## The scratch state a replay mutates. Discarded on exit; never persisted.
var replay_state: Dictionary = {}

var _replay_stage_id: StringName = &""
var _banner: Label = null
var _buttons: Dictionary = {}


func _ready() -> void:
	_build_banner()
	rebuild()


# ---------------------------------------------------------------------------
# Building the list
# ---------------------------------------------------------------------------

## Rebuild the button list from the save. Call after a load, or after the main
## line finishes a stage.
func rebuild() -> void:
	# Removed from the tree before being freed, not just queue_free'd. queue_free
	# is deferred, so an old button would still be holding its name when the new
	# one is added, Godot would silently rename the new node, and any caller
	# doing get_node("Replay_<stage>") would be handed the stale, disabled one.
	for child in _buttons.values():
		if is_instance_valid(child):
			remove_child(child)
			child.queue_free()
	_buttons.clear()

	for stage_id in _stage_order():
		var button := Button.new()
		button.name = "Replay_%s" % stage_id
		var selectable := _is_selectable(stage_id)
		button.text = "%s%s" % [stage_id, "" if selectable else "  (unavailable)"]
		button.disabled = not selectable
		button.pressed.connect(_on_stage_pressed.bind(stage_id))
		add_child(button)
		_buttons[stage_id] = button

	_refresh_banner()


## Only stages the player has finished. The current stage and anything not yet
## reached stay unselectable, and so does a stage whose snapshot is missing or
## malformed, which SaveManager reports through can_replay_stage.
func _is_selectable(stage_id: StringName) -> bool:
	if replay_mode:
		return false
	if not _completed_stage_ids().has(stage_id):
		return false
	return SaveManager.can_replay_stage(stage_id)


## Stages before the current one in the configured chain. A stage is finished
## when the main line has moved past it.
func _completed_stage_ids() -> Array[StringName]:
	var finished: Array[StringName] = []
	var progress: Dictionary = SaveManager.build_payload().get("main_progress", {})
	var current := StringName(str(progress.get("current_stage_id", "")))
	if current == &"":
		return finished
	for stage_id in _stage_order():
		if stage_id == current:
			break
		finished.append(stage_id)
	return finished


## Walk next_stage_id from the configured starting stage, exactly as the chapter
## flow does, rather than listing the four stages here.
func _stage_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var stage_id := StringName(str(Balance.get_value("progress.initial.current_stage_id", "")))
	while stage_id != &"" and not order.has(stage_id):
		order.append(stage_id)
		var value: Variant = Balance.get_value("chapters.%s.next_stage_id" % stage_id, null)
		stage_id = &"" if value == null else StringName(str(value))
	return order


# ---------------------------------------------------------------------------
# Entering and leaving a replay
# ---------------------------------------------------------------------------

func _on_stage_pressed(stage_id: StringName) -> void:
	enter_replay(stage_id)


## Enter a replay of a finished stage. The starting conditions come from that
## stage's opening snapshot and from nowhere else.
func enter_replay(stage_id: StringName) -> bool:
	if replay_mode:
		push_warning("%s Already replaying %s." % [LOG_PREFIX, _replay_stage_id])
		return false
	if not _is_selectable(stage_id):
		push_warning("%s '%s' cannot be replayed." % [LOG_PREFIX, stage_id])
		return false

	var snapshot := SaveManager.stage_snapshot(stage_id)
	if snapshot.is_empty():
		push_warning("%s No usable snapshot for '%s'." % [LOG_PREFIX, stage_id])
		return false

	_replay_stage_id = stage_id
	replay_state = snapshot.duplicate(true)

	var conditions: Dictionary = replay_state.get("operation_start_conditions", {})
	print("%s Entered %s. Start conditions from the snapshot: %s" % [LOG_PREFIX, stage_id, conditions])
	rebuild()
	replay_started.emit(stage_id, conditions.duplicate(true))
	return true


## Leave the replay. The scratch state goes; nothing about it is written.
func exit_replay() -> bool:
	if not replay_mode:
		return false

	var stage_id := _replay_stage_id
	_replay_stage_id = &""
	replay_state = {}
	print("%s Left %s. Scratch state discarded; the main line is untouched." % [LOG_PREFIX, stage_id])
	rebuild()
	replay_ended.emit(stage_id)
	return true


## The conditions the current replay started from, for a caller that wants to
## compare them against the first visit.
func current_start_conditions() -> Dictionary:
	var conditions: Dictionary = replay_state.get("operation_start_conditions", {})
	return conditions.duplicate(true)


# ---------------------------------------------------------------------------
# The persistent replay banner
# ---------------------------------------------------------------------------

func _build_banner() -> void:
	_banner = Label.new()
	_banner.name = "ReplayBanner"
	_banner.text = REPLAY_BANNER_TEXT
	_banner.visible = false
	add_child(_banner)
	move_child(_banner, 0)


## Visible for the whole replay, not a toast that fades. The prompt requires a
## persistent marker that progress is not being saved.
func _refresh_banner() -> void:
	if _banner == null or not is_instance_valid(_banner):
		return
	_banner.visible = replay_mode
	move_child(_banner, 0)
