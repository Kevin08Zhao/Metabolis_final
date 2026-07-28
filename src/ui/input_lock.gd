class_name InputLock
extends Node

## Input lock for the birth transition.
##
## The birth sequence plays for 45 seconds and the player must not be able to act
## during it. This node closes and reopens input in one place. It works purely by
## listening to the events in section 9 of docs/EVENT_API.md; it never reaches
## into src/sim/birth_machine.gd and the machine has no idea it exists.
##
## Only one public entry point changes the lock: set_input_locked. Nothing else
## should ever ask "are we mid-birth?" - that is exactly the scattered judgement
## this node exists to prevent. `input_locked` is readable but not writable.
##
## Controls opt in by joining the "birth_lockable" group. That is the whole
## contract: a screen adds its buttons to the group and never thinks about the
## lock again. The lock keeps no list of its own and needs no registration API.
##
## Requires the `EventBus` and `Balance` autoloads.

## Controls in this group are disabled while the lock is closed.
const LOCKABLE_GROUP := &"birth_lockable"

const LOG_PREFIX := "[LOCK]"

## Watchdog ceiling. Read from Balance; see _timeout_sec.
const TIMEOUT_PATH := "ui.input_lock_timeout_sec"

## Read-only. Other code may look, but only set_input_locked may change it.
var input_locked: bool:
	get:
		return _locked

var _locked: bool = false
var _locked_for_sec: float = 0.0
## Interactive state each control had before the lock closed, keyed by control.
## Restoring from this rather than blanket-enabling means a button that was
## already disabled for its own reasons stays disabled afterwards.
var _previous_disabled: Dictionary = {}


func _ready() -> void:
	set_process(false)
	EventBus.birth_sequence_started.connect(_on_birth_sequence_started)
	EventBus.birth_sequence_completed.connect(_on_birth_sequence_completed)
	EventBus.birth_rolled_back.connect(_on_birth_rolled_back)


# ---------------------------------------------------------------------------
# The only public mutator
# ---------------------------------------------------------------------------

## Close or open input. Idempotent: locking a locked lock, or releasing an open
## one, does nothing and says so rather than double-applying.
func set_input_locked(locked: bool) -> void:
	if locked == _locked:
		return

	_locked = locked
	if _locked:
		_locked_for_sec = 0.0
		_disable_group()
		set_process(true)
		print("%s input closed for the birth transition." % LOG_PREFIX)
	else:
		set_process(false)
		_locked_for_sec = 0.0
		_restore_group()
		print("%s input reopened." % LOG_PREFIX)


# ---------------------------------------------------------------------------
# Guaranteed release
#
# GDScript has no finally block, so the release is layered three deep and each
# layer is independent of the others:
#
#   1. Events. The normal path. birth_sequence_completed and birth_rolled_back
#      both reopen input, and BIRTH_STATES guarantees the machine reaches one of
#      them from every non-terminal state.
#   2. The watchdog below. Covers a machine that hangs without emitting either.
#   3. _exit_tree and NOTIFICATION_PREDELETE. Godot calls _exit_tree whenever a
#      node leaves the tree, including as part of being freed, and sends
#      NOTIFICATION_PREDELETE immediately before deletion. Between them they
#      cover a lock torn down while closed, which is the case the first two
#      layers cannot see. These are the closest thing the language has to a
#      destructor, and they are what makes "the unlock is guaranteed to run"
#      true rather than hopeful.
# ---------------------------------------------------------------------------

func _exit_tree() -> void:
	if _locked:
		push_warning("%s Released on leaving the tree; the lock was still closed." % LOG_PREFIX)
		set_input_locked(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _locked:
		push_warning("%s Released on deletion; the lock was still closed." % LOG_PREFIX)
		_locked = false
		_previous_disabled.clear()


func _process(delta: float) -> void:
	if not _locked:
		return

	_locked_for_sec += delta
	var ceiling := _timeout_sec()
	if ceiling > 0.0 and _locked_for_sec >= ceiling:
		push_warning(
			"%s Held for %.1f s, past the %.1f s ceiling. Forcing release; the birth sequence never reported finishing."
			% [LOG_PREFIX, _locked_for_sec, ceiling]
		)
		set_input_locked(false)


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_birth_sequence_started(_stage_id: StringName, _total_budget_ms: int) -> void:
	set_input_locked(true)


func _on_birth_sequence_completed(_stage_id: StringName) -> void:
	set_input_locked(false)


func _on_birth_rolled_back(_from_state: int, _reason_code: StringName) -> void:
	set_input_locked(false)


# ---------------------------------------------------------------------------
# Group handling
# ---------------------------------------------------------------------------

## Disabling a BaseButton is what makes the lock visible: Godot renders the
## disabled state from the theme, so a locked button greys out rather than
## silently swallowing clicks. Styling stays the theme's business, which is
## D-14 and D-17's territory, not this node's.
func _disable_group() -> void:
	_previous_disabled.clear()
	var tree := get_tree()
	if tree == null:
		return

	for node in tree.get_nodes_in_group(LOCKABLE_GROUP):
		if node is BaseButton:
			var button: BaseButton = node
			_previous_disabled[button] = button.disabled
			button.disabled = true
		else:
			push_warning(
				"%s '%s' is in the lockable group but is not a BaseButton, so the lock cannot grey it out. Wrap it in a button or drop it from the group."
				% [LOG_PREFIX, node.name]
			)


func _restore_group() -> void:
	for key in _previous_disabled:
		if not is_instance_valid(key):
			continue
		var button: BaseButton = key
		button.disabled = bool(_previous_disabled[key])
	_previous_disabled.clear()


func _timeout_sec() -> float:
	var configured := float(Balance.get_value(TIMEOUT_PATH, 0.0))
	if configured > 0.0:
		return configured
	push_warning(
		"%s No timeout configured at '%s'; the watchdog is inactive and only the event and teardown releases remain."
		% [LOG_PREFIX, TIMEOUT_PATH]
	)
	return 0.0
