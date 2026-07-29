extends SceneTree

const OUTPUT_ROOT := "res://../art/screenshots"


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	root.size = Vector2i(640, 360)
	var main_scene: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	await process_frame

	_save("title_idle.png")
	await create_timer(1.5).timeout
	_save("title_disclaimer.png")

	var buttons := _title_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()
		await process_frame
		_save("title_hover_start.png")
	if buttons.size() > 1:
		buttons[1].grab_focus()
		await process_frame
		_save("title_hover_continue.png")

	var new_game := _button_with_text("New Game")
	if new_game != null:
		new_game.pressed.emit()
		await process_frame
		await process_frame
		await process_frame
		_save("transition_to_game.png")

	main_scene.queue_free()
	await process_frame
	var ending: Node = (load("res://ui/ending.tscn") as PackedScene).instantiate()
	root.add_child(ending)
	await process_frame
	await process_frame
	_save("ending_with_title.png")
	ending.queue_free()
	await process_frame
	quit()


func _save(filename: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_ROOT, filename])
	if error != OK:
		push_error("Could not save D-29 screenshot %s: %s" % [filename, error])


func _title_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node in root.find_children("*", "Button", true, false):
		if node is Button and String(node.name).begins_with("Entry_"):
			result.append(node)
	return result


func _button_with_text(label: String) -> Button:
	for button in _title_buttons():
		if button.text == label:
			return button
	return null
