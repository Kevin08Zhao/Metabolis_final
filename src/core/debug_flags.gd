extends Node

## Runtime-only presentation switches used to verify the no-art success
## criterion. Game state, timers, and scene routing are never paused here.

signal flags_changed(
	animations_disabled: bool,
	audio_disabled: bool,
	formal_art_disabled: bool
)

const LOG_PREFIX := "[DEBUG FLAGS]"
const PANEL_TOGGLE_KEY := KEY_F12
const ANIMATION_TOGGLE_KEY := KEY_F8
const AUDIO_TOGGLE_KEY := KEY_F9
const ART_TOGGLE_KEY := KEY_F10
const DEFAULT_ANIMATION := &"default"
const PLACEHOLDER_PRIMARY := Color("#D12A94")
const PLACEHOLDER_SECONDARY := Color("#140F1D")
const PLACEHOLDER_MINIMUM_SIZE := Vector2i(2, 2)
const BUILD_COMPLETION_STEP := 5
const SYSTEM_ACTIVATION_STEP := 7
const BUILD_COMPLETION_WINDOW_MSEC := 8000
const SYSTEM_ACTIVATION_WINDOW_MSEC := 12000
const HEARTBEAT_FALLBACK_FRAMES := {
	&"heart_pump_active": 0,
	&"heart_pump_stable": 0,
	&"heart_pump_strained": 2,
	&"heart_pump_critical": 1,
}
const BIRTH_FALLBACK_BY_STATE := {
	2: &"stage1_umbilical_stop_09999",
	3: &"stage2_pulmonary_flow_19999",
	4: &"stage3_shunt_closure_29999",
	5: &"stage4_systems_online_34999",
	6: &"stage5_ending_42000",
}
const TEXTURE_PROPERTIES_BY_CLASS := {
	&"TextureRect": [&"texture"],
	&"Sprite2D": [&"texture"],
	&"NinePatchRect": [&"texture"],
	&"TextureButton": [
		&"texture_normal",
		&"texture_pressed",
		&"texture_hover",
		&"texture_disabled",
		&"texture_focused",
	],
	&"TextureProgressBar": [
		&"texture_under",
		&"texture_progress",
		&"texture_over",
	],
}

var animations_disabled: bool:
	get:
		return _animations_disabled
	set(value):
		set_animations_disabled(value)

var audio_disabled: bool:
	get:
		return _audio_disabled
	set(value):
		set_audio_disabled(value)

var formal_art_disabled: bool:
	get:
		return _formal_art_disabled
	set(value):
		set_formal_art_disabled(value)

var _animations_disabled := false
var _audio_disabled := false
var _formal_art_disabled := false
var _audio_muted_before_disable := false
var _birth_state := -1
var _animated_sprite_states: Dictionary = {}
var _animation_player_states: Dictionary = {}
var _particle_states: Dictionary = {}
var _birth_presenter_states: Dictionary = {}
var _texture_states: Dictionary = {}
var _sprite_art_states: Dictionary = {}
var _placeholder_cache: Dictionary = {}
var _paused_tweens: Array[Tween] = []
var _presentation_window_step := -1
var _presentation_window_end_msec := 0
var _window_button_states: Dictionary = {}
var _debug_layer: CanvasLayer = null
var _debug_panel: PanelContainer = null
var _state_labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_unhandled_key_input(OS.is_debug_build())
	EventBus.birth_state_changed.connect(_on_birth_state_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	if OS.is_debug_build():
		_build_debug_panel()
	_update_debug_panel()


func _process(_delta: float) -> void:
	if _animations_disabled:
		_apply_animation_fallbacks()
	if _formal_art_disabled:
		_apply_formal_art_placeholders()
	if _audio_disabled and not AudioRouter.muted:
		AudioRouter.set_muted(true)
	_update_presentation_window()


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _presentation_window_active() and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		PANEL_TOGGLE_KEY:
			if _debug_panel != null:
				_debug_panel.visible = not _debug_panel.visible
		ANIMATION_TOGGLE_KEY:
			set_animations_disabled(not _animations_disabled)
		AUDIO_TOGGLE_KEY:
			set_audio_disabled(not _audio_disabled)
		ART_TOGGLE_KEY:
			set_formal_art_disabled(not _formal_art_disabled)
		_:
			return
	get_viewport().set_input_as_handled()


func set_animations_disabled(value: bool) -> void:
	if _animations_disabled == value:
		return
	_animations_disabled = value
	if value:
		_apply_animation_fallbacks()
		_start_window_for_current_phase()
	else:
		_finish_presentation_window()
		_restore_animations()
	_update_and_emit()


func set_audio_disabled(value: bool) -> void:
	if _audio_disabled == value:
		return
	if value:
		_audio_muted_before_disable = AudioRouter.muted
	_audio_disabled = value
	if value:
		AudioRouter.set_muted(true)
	else:
		AudioRouter.set_muted(_audio_muted_before_disable)
	_update_and_emit()


func set_formal_art_disabled(value: bool) -> void:
	if _formal_art_disabled == value:
		return
	_formal_art_disabled = value
	if value:
		_apply_formal_art_placeholders()
	else:
		_restore_formal_art()
		if _animations_disabled:
			_apply_animation_fallbacks()
	_update_and_emit()


func toggle_animations() -> bool:
	set_animations_disabled(not _animations_disabled)
	return _animations_disabled


func toggle_audio() -> bool:
	set_audio_disabled(not _audio_disabled)
	return _audio_disabled


func toggle_formal_art() -> bool:
	set_formal_art_disabled(not _formal_art_disabled)
	return _formal_art_disabled


func set_all_disabled(value: bool) -> void:
	set_animations_disabled(value)
	set_audio_disabled(value)
	set_formal_art_disabled(value)


func state_snapshot() -> Dictionary:
	return {
		"animations_disabled": _animations_disabled,
		"audio_disabled": _audio_disabled,
		"formal_art_disabled": _formal_art_disabled,
		"placeholder_node_count": _valid_record_count(_texture_states)
			+ _valid_record_count(_sprite_art_states),
	}


func debug_panel_visible() -> bool:
	return _debug_panel != null and _debug_panel.visible


func current_birth_fallback() -> StringName:
	return StringName(BIRTH_FALLBACK_BY_STATE.get(_birth_state, &""))


func presentation_window_remaining_sec() -> float:
	if not _presentation_window_active():
		return 0.0
	return maxf(
		0.0,
		float(_presentation_window_end_msec - Time.get_ticks_msec())
		/ 1000.0
	)


func _apply_animation_fallbacks() -> void:
	for node in _scene_nodes():
		if node is AnimatedSprite2D:
			_freeze_animated_sprite(node)
		elif node is AnimationPlayer:
			_freeze_animation_player(node)
		elif node is GPUParticles2D or node is CPUParticles2D:
			_disable_particles(node)
		elif _is_birth_presenter(node):
			_freeze_birth_presenter(node)
	_pause_new_tweens()


func _freeze_animated_sprite(sprite: AnimatedSprite2D) -> void:
	var instance_id := sprite.get_instance_id()
	if not _animated_sprite_states.has(instance_id):
		_animated_sprite_states[instance_id] = {
			"node": weakref(sprite),
			"animation": sprite.animation,
			"frame": sprite.frame,
			"frame_progress": sprite.frame_progress,
			"playing": sprite.is_playing(),
			"speed_scale": sprite.speed_scale,
		}
	if sprite.sprite_frames == null:
		return
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count < 1:
		return
	sprite.pause()
	sprite.frame = clampi(
		_fallback_frame_for(sprite),
		0,
		frame_count - 1
	)
	sprite.frame_progress = 0.0


func _fallback_frame_for(sprite: AnimatedSprite2D) -> int:
	var candidates := [
		StringName(sprite.animation),
		StringName(sprite.name),
		StringName("%s_%s" % [sprite.name, sprite.animation]),
	]
	for candidate in candidates:
		if HEARTBEAT_FALLBACK_FRAMES.has(candidate):
			return int(HEARTBEAT_FALLBACK_FRAMES[candidate])
	for heartbeat_id in HEARTBEAT_FALLBACK_FRAMES:
		for candidate in candidates:
			if String(candidate).contains(String(heartbeat_id)):
				return int(HEARTBEAT_FALLBACK_FRAMES[heartbeat_id])
	return maxi(
		0,
		sprite.sprite_frames.get_frame_count(sprite.animation) - 1
	)


func _freeze_animation_player(player: AnimationPlayer) -> void:
	var instance_id := player.get_instance_id()
	if not _animation_player_states.has(instance_id):
		_animation_player_states[instance_id] = {
			"node": weakref(player),
			"animation": player.current_animation,
			"position": player.current_animation_position,
			"playing": player.is_playing(),
			"speed_scale": player.speed_scale,
		}
	var animation_name := String(player.current_animation).to_lower()
	if (
		animation_name.contains("build")
		or animation_name.contains("complete")
		or animation_name.contains("collaboration")
		or animation_name.contains("observation")
	):
		player.seek(player.current_animation_length, true)
	player.pause()


func _disable_particles(particles: Node) -> void:
	var instance_id := particles.get_instance_id()
	if not _particle_states.has(instance_id):
		_particle_states[instance_id] = {
			"node": weakref(particles),
			"emitting": bool(particles.get("emitting")),
		}
	particles.set("emitting", false)


func _freeze_birth_presenter(presenter: Node) -> void:
	var instance_id := presenter.get_instance_id()
	if not _birth_presenter_states.has(instance_id):
		_birth_presenter_states[instance_id] = {
			"node": weakref(presenter),
			"processing": presenter.is_processing(),
		}
	var fallback := _birth_fallback_for_presenter(presenter)
	presenter.set_process(false)
	if not fallback.is_empty():
		presenter.call("show_frame", fallback)


func _birth_fallback_for_presenter(presenter: Node) -> StringName:
	var configured := current_birth_fallback()
	if not configured.is_empty():
		return configured
	var current := String(presenter.call("current_frame_id"))
	for fallback in BIRTH_FALLBACK_BY_STATE.values():
		var prefix := String(fallback).get_slice("_", 0)
		if current.begins_with(prefix):
			return StringName(fallback)
	if current.begins_with("stage1_"):
		return &"stage1_umbilical_stop_09999"
	if current.begins_with("stage2_"):
		return &"stage2_pulmonary_flow_19999"
	if current.begins_with("stage3_"):
		return &"stage3_shunt_closure_29999"
	if current.begins_with("stage4_"):
		return &"stage4_systems_online_34999"
	if current.begins_with("stage5_"):
		return &"stage5_ending_42000"
	return &""


func _pause_new_tweens() -> void:
	for tween in get_tree().get_processed_tweens():
		if _paused_tweens.has(tween):
			continue
		tween.pause()
		_paused_tweens.append(tween)


func _restore_animations() -> void:
	for state_value in _animated_sprite_states.values():
		var state: Dictionary = state_value
		var sprite := _node_from_state(state) as AnimatedSprite2D
		if sprite == null:
			continue
		sprite.animation = StringName(state["animation"])
		sprite.speed_scale = float(state["speed_scale"])
		var frame_count := sprite.sprite_frames.get_frame_count(
			sprite.animation
		)
		if frame_count > 0:
			sprite.frame = clampi(
				int(state["frame"]),
				0,
				frame_count - 1
			)
		sprite.frame_progress = float(state["frame_progress"])
		if bool(state["playing"]):
			sprite.play()
		else:
			sprite.pause()
	_animated_sprite_states.clear()

	for state_value in _animation_player_states.values():
		var state: Dictionary = state_value
		var player := _node_from_state(state) as AnimationPlayer
		if player == null:
			continue
		player.speed_scale = float(state["speed_scale"])
		var animation_name := StringName(state["animation"])
		if not animation_name.is_empty():
			player.play(animation_name)
			player.seek(float(state["position"]), true)
		if not bool(state["playing"]):
			player.pause()
	_animation_player_states.clear()

	for state_value in _particle_states.values():
		var state: Dictionary = state_value
		var particles := _node_from_state(state)
		if particles != null:
			particles.set("emitting", bool(state["emitting"]))
	_particle_states.clear()

	for state_value in _birth_presenter_states.values():
		var state: Dictionary = state_value
		var presenter := _node_from_state(state)
		if presenter == null:
			continue
		var should_process: bool = (
			bool(state["processing"])
			or (
				bool(presenter.get("visible"))
				and _birth_state >= 2
				and _birth_state <= 6
			)
		)
		presenter.set_process(should_process)
	_birth_presenter_states.clear()

	for tween in _paused_tweens:
		if tween != null and tween.is_valid():
			tween.play()
	_paused_tweens.clear()


func _apply_formal_art_placeholders() -> void:
	for node in _scene_nodes():
		if _is_debug_ui(node):
			continue
		_replace_texture_properties(node)
		if node is AnimatedSprite2D:
			_replace_sprite_frames(node)


func _replace_texture_properties(node: Node) -> void:
	var properties := _texture_properties_for(node)
	if properties.is_empty():
		return
	var instance_id := node.get_instance_id()
	var state: Dictionary = _texture_states.get(instance_id, {})
	if state.is_empty():
		state = {
			"node": weakref(node),
			"originals": {},
			"placeholders": {},
			"label": null,
		}
	var originals: Dictionary = state["originals"]
	var placeholders: Dictionary = state["placeholders"]
	var largest_size := Vector2i.ZERO
	for property_name in properties:
		var texture: Texture2D = node.get(property_name)
		var active_placeholder: Texture2D = placeholders.get(property_name)
		if texture == null:
			continue
		if active_placeholder == null or texture != active_placeholder:
			originals[property_name] = texture
			var size := _texture_size(texture)
			active_placeholder = _placeholder_texture(size)
			placeholders[property_name] = active_placeholder
		node.set(property_name, active_placeholder)
		var property_size := _texture_size(texture)
		if property_size.x * property_size.y > largest_size.x * largest_size.y:
			largest_size = property_size
	if originals.is_empty():
		return
	state["originals"] = originals
	state["placeholders"] = placeholders
	if largest_size != Vector2i.ZERO:
		state["label"] = _ensure_identifier_label(
			node,
			state.get("label"),
			largest_size
		)
	_texture_states[instance_id] = state


func _replace_sprite_frames(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null:
		return
	var instance_id := sprite.get_instance_id()
	var state: Dictionary = _sprite_art_states.get(instance_id, {})
	if state.is_empty():
		var animation_state: Dictionary = _animated_sprite_states.get(
			instance_id,
			{}
		)
		state = {
			"node": weakref(sprite),
			"frames": sprite.sprite_frames,
			"placeholder": null,
			"animation": animation_state.get(
				"animation",
				sprite.animation
			),
			"frame": animation_state.get("frame", sprite.frame),
			"playing": animation_state.get(
				"playing",
				sprite.is_playing()
			),
			"label": null,
		}
	var placeholder: SpriteFrames = state["placeholder"]
	if placeholder == null or sprite.sprite_frames != placeholder:
		if sprite.sprite_frames != state["frames"]:
			state["frames"] = sprite.sprite_frames
			state["animation"] = sprite.animation
			state["frame"] = sprite.frame
			state["playing"] = sprite.is_playing()
		placeholder = _placeholder_sprite_frames(state["frames"])
		state["placeholder"] = placeholder
		sprite.sprite_frames = placeholder
		sprite.animation = DEFAULT_ANIMATION
		if bool(state["playing"]) and not _animations_disabled:
			sprite.play()
	var size := _largest_sprite_frame_size(state["frames"])
	state["label"] = _ensure_identifier_label(
		sprite,
		state.get("label"),
		size
	)
	_sprite_art_states[instance_id] = state


func _restore_formal_art() -> void:
	for state_value in _texture_states.values():
		var state: Dictionary = state_value
		var node := _node_from_state(state)
		if node == null:
			continue
		var originals: Dictionary = state["originals"]
		for property_name in originals:
			node.set(property_name, originals[property_name])
		_remove_identifier_label(state.get("label"))
	_texture_states.clear()

	for state_value in _sprite_art_states.values():
		var state: Dictionary = state_value
		var sprite := _node_from_state(state) as AnimatedSprite2D
		if sprite == null:
			continue
		sprite.sprite_frames = state["frames"]
		sprite.animation = StringName(state["animation"])
		var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
		if frame_count > 0:
			sprite.frame = clampi(int(state["frame"]), 0, frame_count - 1)
		if bool(state["playing"]) and not _animations_disabled:
			sprite.play()
		else:
			sprite.pause()
		_remove_identifier_label(state.get("label"))
	_sprite_art_states.clear()


func _texture_properties_for(node: Node) -> Array:
	for class_name_value in TEXTURE_PROPERTIES_BY_CLASS:
		var texture_class_name := StringName(class_name_value)
		if node.is_class(texture_class_name):
			return TEXTURE_PROPERTIES_BY_CLASS[texture_class_name]
	return []


func _placeholder_texture(size: Vector2i) -> ImageTexture:
	var safe_size := Vector2i(
		maxi(size.x, PLACEHOLDER_MINIMUM_SIZE.x),
		maxi(size.y, PLACEHOLDER_MINIMUM_SIZE.y)
	)
	var cache_key := "%dx%d" % [safe_size.x, safe_size.y]
	var cached: ImageTexture = _placeholder_cache.get(cache_key)
	if cached != null:
		return cached
	var image := Image.create(
		safe_size.x,
		safe_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(PLACEHOLDER_PRIMARY)
	var border_width := 1 if mini(safe_size.x, safe_size.y) < 16 else 2
	for y in safe_size.y:
		for x in safe_size.x:
			if (
				x < border_width
				or y < border_width
				or x >= safe_size.x - border_width
				or y >= safe_size.y - border_width
				or (x + y) % 16 < 3
			):
				image.set_pixel(x, y, PLACEHOLDER_SECONDARY)
	cached = ImageTexture.create_from_image(image)
	_placeholder_cache[cache_key] = cached
	return cached


func _placeholder_sprite_frames(source: SpriteFrames) -> SpriteFrames:
	var largest_size := _largest_sprite_frame_size(source)
	var frames := SpriteFrames.new()
	for animation_name in frames.get_animation_names():
		frames.remove_animation(animation_name)
	frames.add_animation(DEFAULT_ANIMATION)
	frames.set_animation_loop(DEFAULT_ANIMATION, true)
	frames.set_animation_speed(DEFAULT_ANIMATION, 1.0)
	frames.add_frame(
		DEFAULT_ANIMATION,
		_placeholder_texture(largest_size),
		1.0
	)
	return frames


func _largest_sprite_frame_size(source: SpriteFrames) -> Vector2i:
	var largest := Vector2i(16, 16)
	for animation_name in source.get_animation_names():
		for frame_index in source.get_frame_count(animation_name):
			var texture := source.get_frame_texture(
				animation_name,
				frame_index
			)
			if texture == null:
				continue
			var size := _texture_size(texture)
			if size.x * size.y > largest.x * largest.y:
				largest = size
	return largest


func _texture_size(texture: Texture2D) -> Vector2i:
	var size := texture.get_size()
	return Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))


func _ensure_identifier_label(
	node: Node,
	label_value: Variant,
	texture_size: Vector2i
) -> Label:
	var label := label_value as Label
	if texture_size.x < 48 or texture_size.y < 16:
		return label
	if label == null or not is_instance_valid(label):
		label = Label.new()
		label.name = "DebugArtIdentifier"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 4095
		label.text = String(node.name).left(18)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", PLACEHOLDER_SECONDARY)
		label.add_theme_constant_override("outline_size", 2)
		node.add_child(label)
	if node is Sprite2D:
		label.position = Vector2(
			-texture_size.x * 0.5 if node.centered else 0.0,
			-texture_size.y * 0.5 if node.centered else 0.0
		)
		label.size = Vector2(texture_size)
	else:
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _remove_identifier_label(label_value: Variant) -> void:
	var label := label_value as Label
	if label == null or not is_instance_valid(label):
		return
	var parent := label.get_parent()
	if parent != null:
		parent.remove_child(label)
	label.free()


func _is_birth_presenter(node: Node) -> bool:
	return (
		node.has_method("current_frame_id")
		and node.has_method("show_frame")
		and node.has_method("hide_frame")
	)


func _is_debug_ui(node: Node) -> bool:
	return (
		node == self
		or node == _debug_layer
		or (
			_debug_layer != null
			and _debug_layer.is_ancestor_of(node)
		)
	)


func _scene_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	var root := get_tree().root
	if root == null:
		return nodes
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		nodes.append(node)
		for child in node.get_children():
			pending.append(child)
	return nodes


func _node_from_state(state: Dictionary) -> Node:
	var reference := state.get("node") as WeakRef
	if reference == null:
		return null
	return reference.get_ref() as Node


func _valid_record_count(records: Dictionary) -> int:
	var count := 0
	for state_value in records.values():
		var state: Dictionary = state_value
		if _node_from_state(state) != null:
			count += 1
	return count


func _on_birth_state_changed(
	_previous_state: int,
	current_state: int,
	_window_ms: int
) -> void:
	_birth_state = current_state
	if _animations_disabled:
		call_deferred("_freeze_current_birth_presenters")


func _on_phase_changed(
	_previous_phase: int,
	current_phase: int
) -> void:
	_finish_presentation_window()
	if not _animations_disabled:
		return
	_start_presentation_window(current_phase)


func _start_window_for_current_phase() -> void:
	for node in _scene_nodes():
		if not node.has_method("current_step"):
			continue
		_start_presentation_window(int(node.call("current_step")))
		return


func _start_presentation_window(step: int) -> void:
	var duration_msec := 0
	match step:
		BUILD_COMPLETION_STEP:
			duration_msec = BUILD_COMPLETION_WINDOW_MSEC
		SYSTEM_ACTIVATION_STEP:
			duration_msec = SYSTEM_ACTIVATION_WINDOW_MSEC
		_:
			return
	_presentation_window_step = step
	_presentation_window_end_msec = (
		Time.get_ticks_msec() + duration_msec
	)
	_disable_window_buttons()
	print(
		"%s static presentation window=%s duration_ms=%d"
		% [LOG_PREFIX, step, duration_msec]
	)


func _update_presentation_window() -> void:
	if _presentation_window_step < 0:
		return
	if Time.get_ticks_msec() >= _presentation_window_end_msec:
		_finish_presentation_window()
		return
	_disable_window_buttons()


func _presentation_window_active() -> bool:
	return (
		_presentation_window_step >= 0
		and _presentation_window_end_msec > Time.get_ticks_msec()
	)


func _disable_window_buttons() -> void:
	for node in _scene_nodes():
		if not node is BaseButton or node.name != &"ContinueAction":
			continue
		var instance_id := node.get_instance_id()
		if not _window_button_states.has(instance_id):
			_window_button_states[instance_id] = {
				"node": weakref(node),
				"disabled": node.disabled,
			}
		node.disabled = true


func _finish_presentation_window() -> void:
	for state_value in _window_button_states.values():
		var state: Dictionary = state_value
		var button := _node_from_state(state) as BaseButton
		if button != null:
			button.disabled = bool(state["disabled"])
	_window_button_states.clear()
	_presentation_window_step = -1
	_presentation_window_end_msec = 0


func _freeze_current_birth_presenters() -> void:
	if not _animations_disabled:
		return
	for node in _scene_nodes():
		if _is_birth_presenter(node):
			_freeze_birth_presenter(node)


func _build_debug_panel() -> void:
	_debug_layer = CanvasLayer.new()
	_debug_layer.name = "DebugFlagsLayer"
	_debug_layer.layer = 127
	add_child(_debug_layer)

	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugFlagsPanel"
	_debug_panel.position = Vector2(12, 12)
	_debug_panel.custom_minimum_size = Vector2(250, 0)
	_debug_panel.visible = false
	_debug_layer.add_child(_debug_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	_debug_panel.add_child(rows)

	var heading := Label.new()
	heading.text = "Runtime Presentation Flags"
	rows.add_child(heading)

	for label_text in ["Animations", "Audio", "Formal art"]:
		var state_label := Label.new()
		state_label.text = label_text
		rows.add_child(state_label)
		_state_labels.append(state_label)

	var shortcuts := Label.new()
	shortcuts.text = "F8 animation  F9 audio  F10 art\nF12 hide panel"
	rows.add_child(shortcuts)


func _update_debug_panel() -> void:
	if _state_labels.size() != 3:
		return
	_state_labels[0].text = "Animations: %s" % (
		"DISABLED" if _animations_disabled else "ENABLED"
	)
	_state_labels[1].text = "Audio: %s" % (
		"DISABLED" if _audio_disabled else "ENABLED"
	)
	_state_labels[2].text = "Formal art: %s" % (
		"PLACEHOLDERS" if _formal_art_disabled else "ENABLED"
	)


func _update_and_emit() -> void:
	_update_debug_panel()
	print(
		"%s animation=%s audio=%s formal_art=%s"
		% [
			LOG_PREFIX,
			"off" if _animations_disabled else "on",
			"off" if _audio_disabled else "on",
			"placeholder" if _formal_art_disabled else "on",
		]
	)
	flags_changed.emit(
		_animations_disabled,
		_audio_disabled,
		_formal_art_disabled
	)
