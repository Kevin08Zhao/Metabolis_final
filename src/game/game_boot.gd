extends Control
## Game scene boot script.
##
## Attached to the root Game node. On ready it triggers ChapterFlow and wires
## keyboard input so the player can step through the stage loop with Space.
## All game logic lives in ChapterFlow and the simulation scripts; this file
## only boots them and provides a debug advance key.

const LOG_PREFIX := "[GAME]"

var _flow: Node = null


func _ready() -> void:
	_flow = get_node_or_null("ChapterFlow")
	if _flow == null:
		push_error("%s No ChapterFlow node found; game cannot start." % LOG_PREFIX)
		return

	if not _flow.has_method("start_new_run"):
		push_error("%s ChapterFlow node has no start_new_run method." % LOG_PREFIX)
		return

	_flow.start_new_run()
	print("%s Run started. Press Space to advance, Shift+Space to jump to build step." % LOG_PREFIX)


func _input(event: InputEvent) -> void:
	if _flow == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.shift:
				_jump_to_build()
			else:
				_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if not _flow.has_method("advance"):
		return
	var ok: bool = _flow.advance()
	if ok:
		var stage: int = _flow.call("stage_number") if _flow.has_method("stage_number") else 0
		var step: StringName = _flow.call("current_step_id") if _flow.has_method("current_step_id") else &""
		print("%s stage %d  step=%s" % [LOG_PREFIX, stage, step])
	else:
		print("%s Cannot advance yet." % LOG_PREFIX)


func _jump_to_build() -> void:
	if not _flow.has_method("advance_to"):
		print("%s ChapterFlow does not support jump-to-build." % LOG_PREFIX)
		return
	while _flow.has_method("current_step") and int(_flow.call("current_step")) < 4:
		if not _flow.has_method("can_exit_current_step") or not _flow.call("can_exit_current_step"):
			print("%s Blocked at step %s; cannot jump to build." % [LOG_PREFIX, _flow.call("current_step_id")])
			return
		_flow.advance()
	_flow.call("advance_to", 4)
	print("%s Jumped to build decision step." % LOG_PREFIX)
