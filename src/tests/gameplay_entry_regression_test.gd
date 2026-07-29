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
	_test_space_advances_gameplay(main)

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

	var flow := game.get_node_or_null("ChapterFlow")
	_expect(flow != null, "Game scene must contain ChapterFlow")
	if flow == null:
		return

	var step_before: StringName = flow.current_step_id()
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	game.call("_unhandled_input", event)
	var step_after: StringName = flow.current_step_id()
	_expect(step_after != step_before, "Space must advance the current gameplay step")


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
