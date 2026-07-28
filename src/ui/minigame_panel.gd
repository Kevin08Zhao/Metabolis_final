class_name MinigamePanel
extends Control

## Task panel.
##
## Shows the current stage's optional minigame: what it is, what it asks, what it
## pays, when it is done, and where the hints are. Five readings, fixed.
##
## Two absences are as deliberate as anything it displays. Stage four has no
## minigame, so the panel hides itself entirely rather than showing an empty frame
## or the words "no task" - an empty frame still reads as a thing the player is
## missing out on. And once the stage's run is resolved, the entry stops being
## offered, because an entry that does nothing is worse than no entry.
##
## The panel never gates anything. It says out loud that the task is skippable and
## that skipping does not hold the main line back, which is true: nothing in the
## flow waits on a minigame.
##
## Layout is by anchor. docs/UI_LAYOUT.md section 2 places the task row at
## Rect2(0, 24, 608, 16); that rectangle belongs to whoever assembles the scene.
## This script writes no coordinate.
##
## Every string is a bracketed placeholder. T-31 owns docs/UI_COPY.md.
##
## Requires the `EventBus` and `Balance` autoloads.

const LOG_PREFIX := "[TASK]"

## The five readings, in display order. Fixed.
const READINGS: Array[StringName] = [
	&"minigame_name",
	&"goal",
	&"available_resources",
	&"completion_condition",
	&"hint_entry",
]

## Stated on the entry itself, not buried in a tooltip. The player should be able
## to tell it is optional without opening anything.
const SKIPPABLE_NOTICE := "[optional] Skipping this task does not hold the main line back."

signal entry_offered(minigame_id: StringName)
signal entry_withdrawn(minigame_id: StringName)

var _stage_id: StringName = &""
var _minigame_id: StringName = &""
var _resolved: bool = false
var _labels: Dictionary = {}
var _entry_button: Button = null
var _skip_button: Button = null
var _notice: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_build()
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	refresh()


# ---------------------------------------------------------------------------
# What the panel says
# ---------------------------------------------------------------------------

## The five readings. Empty when the panel is hidden, because a hidden panel
## reports nothing rather than reporting blanks.
func readings() -> Dictionary:
	if not should_display():
		return {}
	return {
		&"minigame_name": "[task:%s]" % _minigame_id,
		&"goal": "[goal:%s]" % _goal_field(),
		&"available_resources": "[reward:%s]" % ", ".join(_reward_fields()),
		&"completion_condition": "[complete-at:%s %s]" % [_goal_field(), _goal_target()],
		&"hint_entry": "[hints:%s]" % _minigame_id,
	}


## The panel is shown only when this stage has a minigame and it is unresolved.
## Stage four fails the first test; a skipped or finished run fails the second.
func should_display() -> bool:
	return _minigame_id != &"" and not _resolved


func entry_offered_now() -> bool:
	return should_display()


func current_minigame_id() -> StringName:
	return _minigame_id


func refresh() -> void:
	var display := should_display()
	visible = display

	if not display:
		return

	var values := readings()
	for key in READINGS:
		var label: Label = _labels.get(key)
		if label != null and is_instance_valid(label):
			label.text = "%s: %s" % [key, values[key]]
	_notice.text = SKIPPABLE_NOTICE


# ---------------------------------------------------------------------------
# Configuration reads
#
# Which field a prototype counts is its own business; docs/MINIGAME_SPEC.md gives
# each one a single goal field and the panel uses whichever that is rather than
# naming target_divisions, target_deliveries and target_nodes here.
# ---------------------------------------------------------------------------

func _goal_field() -> String:
	var goal := _goal_dictionary()
	if goal.size() != 1:
		return "unknown"
	return str(goal.keys()[0])


func _goal_target() -> String:
	var goal := _goal_dictionary()
	if goal.size() != 1:
		return "?"
	return str(goal[goal.keys()[0]])


func _goal_dictionary() -> Dictionary:
	var value: Variant = Balance.get_value("minigames.%s.goal" % _minigame_id, {})
	if not value is Dictionary:
		return {}
	var goal: Dictionary = value
	return goal


## Which resources this task can pay, not how much. The amount depends on the
## star rating, and table M4 scales it, so quoting a number here would promise
## something the player has not earned yet.
func _reward_fields() -> PackedStringArray:
	var out := PackedStringArray()
	var value: Variant = Balance.get_value("minigames.%s.reward" % _minigame_id, {})
	if not value is Dictionary:
		return out
	var reward: Dictionary = value
	for key in reward:
		var name := str(key)
		if name == "star_multiplier":
			continue
		out.append(name)
	return out


## The stage's minigame id, or empty when the stage has none. Stage four's
## configured null becomes the empty name, which is what hides the panel; no
## stage is named in this script.
func _minigame_for(stage_id: StringName) -> StringName:
	var value: Variant = Balance.get_value("chapters.%s.minigame_id" % stage_id, null)
	return &"" if value == null else StringName(str(value))


# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------

## Skip the task. The entry stops being offered for this stage, and nothing else
## happens: the main line was never waiting on it.
func skip() -> bool:
	if not should_display():
		return false
	var skipped := _minigame_id
	_resolved = true
	print("%s '%s' skipped; the entry is withdrawn and the main line is unaffected."
		% [LOG_PREFIX, skipped])
	refresh()
	entry_withdrawn.emit(skipped)
	return true


func open_hints() -> StringName:
	if not should_display():
		return &""
	return _minigame_id


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_stage_loaded(stage_id: StringName, _stage_index: int) -> void:
	_stage_id = stage_id
	_minigame_id = _minigame_for(stage_id)
	_resolved = false
	refresh()
	if should_display():
		print("%s '%s' offered in %s." % [LOG_PREFIX, _minigame_id, stage_id])
		entry_offered.emit(_minigame_id)
	else:
		print("%s no task in %s; the panel is hidden." % [LOG_PREFIX, stage_id])


## A run resolved elsewhere, through T-19a, withdraws the entry just as a skip
## from this panel does. Either way the stage's task is done with.
func _on_minigame_exited(minigame_id: StringName, _resolution: int, _elapsed_sec: float) -> void:
	if minigame_id != _minigame_id or _resolved:
		return
	_resolved = true
	refresh()
	entry_withdrawn.emit(minigame_id)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var row := VBoxContainer.new()
	row.name = "TaskRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	for key in READINGS:
		var label := Label.new()
		label.name = "Reading_%s" % key
		label.text = "%s: [pending]" % key
		row.add_child(label)
		_labels[key] = label

	_notice = Label.new()
	_notice.name = "SkippableNotice"
	_notice.text = SKIPPABLE_NOTICE
	row.add_child(_notice)

	_entry_button = Button.new()
	_entry_button.name = "EnterTask"
	_entry_button.text = "[enter task]"
	row.add_child(_entry_button)

	_skip_button = Button.new()
	_skip_button.name = "SkipTask"
	_skip_button.text = "[skip task]"
	_skip_button.pressed.connect(func() -> void: skip())
	row.add_child(_skip_button)
