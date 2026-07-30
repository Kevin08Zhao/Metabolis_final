extends Control

## Eight-second layered title intro.
##
## The six visual layers stay as independent 320x180 frame sequences under
## art/animations/title_layers. They are loaded through the same res://../art
## boundary used by AssetLoader, then advanced together at exactly 8 FPS.
## Native Godot labels and buttons remain separate so routing, focus, save-state
## entries, and future localization do not become baked image assets.
##
## The layer directories are deduplicated: a PNG exists only for the first frame
## that introduces new pixels, and manifest.json's "frame_maps" says which file
## backs each of the 64 logical frames. Each distinct PNG becomes exactly one
## ImageTexture that every frame mapped to it shares. When the manifest is
## missing or malformed the loader falls back to the identity map, so a fully
## populated directory keeps working unchanged.

signal intro_finished

const FPS := 8
const FRAME_COUNT := 64
const INTRO_DURATION_SECONDS := 8.0
const FRAME_DURATION_SECONDS := 1.0 / float(FPS)
const ANIMATION_ROOT := "res://../art/animations/title_layers"
const MANIFEST_PATH := "res://../art/animations/title_layers/manifest.json"

const TITLE_START_SECONDS := 5.25
const TITLE_END_SECONDS := 6.25
const SUBTITLE_START_SECONDS := 5.75
const SUBTITLE_END_SECONDS := 6.75
const MENU_START_SECONDS := 6.50
const MENU_END_SECONDS := 7.50

const LAYER_SPECS := [
	["Sky", "01_sky"],
	["Terrain", "02_terrain"],
	["MainBuilding", "03_main_building"],
	["SmallBuildings", "04_small_buildings"],
	["VehicleCargo", "05_vehicle_cargo"],
	["RoadsideProps", "06_roadside_props"],
]

## The layer PNGs are 320x180 while the canvas is 800x450, a fractional 2.5x.
## Stretching across that gap makes neighbouring source pixels 2 and 3 screen
## pixels wide, which reads as uneven noise beside integer-scaled pixel text.
## The stack is instead drawn at the smallest integer scale that covers the
## canvas and clipped by the parent, so every source pixel stays square.
const LAYER_SOURCE_SIZE := Vector2(320.0, 180.0)

## Whole multiples of UiTheme.NATIVE_FONT_SIZE. Anything else samples the glyph
## atlas at a fractional scale and breaks the pixel grid.
const MENU_FONT_SIZE := 20
const PROMPT_FONT_SIZE := 10
## "Body-System City Builder" needs 286px at MENU_FONT_SIZE including padding.
const MENU_BUTTON_SIZE := Vector2(290.0, 36.0)

const COLOR_OUTLINE := Color("#140F1D")
const COLOR_BLUE_DARK := Color("#29314A")
const COLOR_BLUE := Color("#404586")
const COLOR_TISSUE_DARK := Color("#91465F")
const COLOR_CORAL := Color("#BA3A3F")
const COLOR_AMBER_LIGHT := Color("#DDAD7E")
const COLOR_CREAM := Color("#E8DCCF")
const COLOR_MINT := Color("#B1FFD1")

@onready var _fallback_background: TextureRect = $Background
@onready var _animation_layers: Control = $AnimationLayers
@onready var _title_band: Label = $TitleBand
@onready var _subtitle: Label = $Subtitle
@onready var _menu_anchor: VBoxContainer = $MenuAnchor

var _layers: Array[Dictionary] = []
var _elapsed_seconds := 0.0
var _current_frame := -1
var _intro_complete := false
var _menu_interactive := false
var _title_base_position := Vector2.ZERO
var _subtitle_base_position := Vector2.ZERO
var _menu_base_position := Vector2.ZERO
var _normal_button_style: StyleBoxFlat
var _hover_button_style: StyleBoxFlat
var _pressed_button_style: StyleBoxFlat
var _focus_button_style: StyleBoxFlat


func _ready() -> void:
	_title_base_position = _title_band.position
	_subtitle_base_position = _subtitle.position
	_menu_base_position = _menu_anchor.position
	_build_menu_styles()
	_prepare_intro_ui()

	if _load_layer_frames():
		_fallback_background.hide()
		_animation_layers.show()
		_layout_animation_layers()
		_animation_layers.resized.connect(_layout_animation_layers)
		_set_animation_frame(0)
	else:
		_animation_layers.hide()
		_fallback_background.show()

	# SceneRouter adds the actual menu after this scene enters the tree.
	call_deferred("_refresh_dynamic_menu")


func _process(delta: float) -> void:
	if not _intro_complete:
		_elapsed_seconds = minf(
			_elapsed_seconds + delta,
			INTRO_DURATION_SECONDS
		)
		var next_frame := mini(
			int(floor(_elapsed_seconds / FRAME_DURATION_SECONDS)),
			FRAME_COUNT - 1
		)
		_set_animation_frame(next_frame)
		_update_intro_ui(_elapsed_seconds)
		if _elapsed_seconds >= INTRO_DURATION_SECONDS:
			_finish_intro()

	# Confirmation replaces the menu tree, so styling is intentionally cheap
	# and idempotent instead of assuming the first generated buttons live forever.
	_refresh_dynamic_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _intro_complete or not event.is_pressed() or event.is_echo():
		return
	if (
		event.is_action("ui_accept")
		or event.is_action("ui_cancel")
		or event.is_action("ui_select")
	):
		_elapsed_seconds = INTRO_DURATION_SECONDS
		_set_animation_frame(FRAME_COUNT - 1)
		_update_intro_ui(_elapsed_seconds)
		_finish_intro()
		get_viewport().set_input_as_handled()


func _load_layer_frames() -> bool:
	_layers.clear()
	var frame_maps := _load_frame_maps()
	for specification in LAYER_SPECS:
		var node_name: String = specification[0]
		var directory_name: String = specification[1]
		var layer_node := _animation_layers.get_node_or_null(node_name) as TextureRect
		if layer_node == null:
			push_error("[TITLE INTRO] Missing TextureRect layer '%s'." % node_name)
			_layers.clear()
			return false

		layer_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var frame_map := _frame_map_for(frame_maps, directory_name)
		var textures_by_source: Dictionary = {}
		var frames: Array[Texture2D] = []
		for frame_index in range(FRAME_COUNT):
			var source_index: int = frame_map[frame_index]
			if textures_by_source.has(source_index):
				# Duplicate frames share one GPU texture instead of a second upload.
				frames.append(textures_by_source[source_index])
				continue

			var resource_path := "%s/%s/frame_%03d.png" % [
				ANIMATION_ROOT,
				directory_name,
				source_index,
			]
			var absolute_path := ProjectSettings.globalize_path(resource_path)
			var image := Image.load_from_file(absolute_path)
			if image == null or image.is_empty():
				push_error("[TITLE INTRO] Could not load '%s'." % resource_path)
				_layers.clear()
				return false
			if image.get_size() != Vector2i(320, 180):
				push_error(
					"[TITLE INTRO] '%s' must be 320x180, found %sx%s."
					% [resource_path, image.get_width(), image.get_height()]
				)
				_layers.clear()
				return false
			var texture := ImageTexture.create_from_image(image)
			textures_by_source[source_index] = texture
			frames.append(texture)
		_layers.append({"node": layer_node, "frames": frames})
	return true


func _layout_animation_layers() -> void:
	var canvas := _animation_layers.size
	if canvas.x <= 0.0 or canvas.y <= 0.0:
		return

	# Cover rather than fit: an integer scale that leaves gaps would need a
	# backdrop, and the sky changes color across the eight seconds, so there is
	# no single color that could fill one.
	var cover := maxf(canvas.x / LAYER_SOURCE_SIZE.x, canvas.y / LAYER_SOURCE_SIZE.y)
	var scale := maxi(1, int(ceil(cover)))
	var scaled := LAYER_SOURCE_SIZE * float(scale)
	var origin := ((canvas - scaled) * 0.5).floor()

	for layer in _layers:
		var layer_node: TextureRect = layer["node"]
		layer_node.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		layer_node.position = origin
		layer_node.size = scaled


func _load_frame_maps() -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(MANIFEST_PATH)
	if not FileAccess.file_exists(absolute_path):
		push_warning(
			"[TITLE INTRO] '%s' is missing; assuming one PNG per frame."
			% MANIFEST_PATH
		)
		return {}
	var text := FileAccess.get_file_as_string(absolute_path)
	if text.is_empty():
		push_warning("[TITLE INTRO] '%s' is empty." % MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[TITLE INTRO] '%s' is not a JSON object." % MANIFEST_PATH)
		return {}
	var maps: Variant = (parsed as Dictionary).get("frame_maps", {})
	if typeof(maps) != TYPE_DICTIONARY:
		push_warning("[TITLE INTRO] '%s' has no usable frame_maps." % MANIFEST_PATH)
		return {}
	return maps as Dictionary


func _frame_map_for(frame_maps: Dictionary, directory_name: String) -> PackedInt32Array:
	var identity := PackedInt32Array()
	for frame_index in range(FRAME_COUNT):
		identity.append(frame_index)

	var raw: Variant = frame_maps.get(directory_name, null)
	if typeof(raw) != TYPE_ARRAY:
		return identity
	var entries := raw as Array
	if entries.size() != FRAME_COUNT:
		push_warning(
			"[TITLE INTRO] frame_maps['%s'] has %s entries, expected %s."
			% [directory_name, entries.size(), FRAME_COUNT]
		)
		return identity

	var mapped := PackedInt32Array()
	for frame_index in range(FRAME_COUNT):
		var entry: Variant = entries[frame_index]
		if typeof(entry) != TYPE_INT and typeof(entry) != TYPE_FLOAT:
			push_warning(
				"[TITLE INTRO] frame_maps['%s'][%s] is not a number."
				% [directory_name, frame_index]
			)
			return identity
		var source_index := int(entry)
		# A representative frame can never come after the frame it stands in
		# for, so anything forward-pointing means the manifest is out of sync.
		if source_index < 0 or source_index > frame_index:
			push_warning(
				"[TITLE INTRO] frame_maps['%s'][%s] = %s is out of range."
				% [directory_name, frame_index, source_index]
			)
			return identity
		mapped.append(source_index)
	return mapped


func _set_animation_frame(frame_index: int) -> void:
	if frame_index == _current_frame:
		return
	_current_frame = clampi(frame_index, 0, FRAME_COUNT - 1)
	for layer in _layers:
		var layer_node: TextureRect = layer["node"]
		var frames: Array = layer["frames"]
		layer_node.texture = frames[_current_frame]


func _prepare_intro_ui() -> void:
	_title_band.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_menu_anchor.modulate.a = 0.0
	_title_band.position = _title_base_position + Vector2(0.0, -26.0)
	_subtitle.position = _subtitle_base_position + Vector2(0.0, -10.0)
	_menu_anchor.position = _menu_base_position + Vector2(0.0, 18.0)
	_set_menu_interactive(false)


func _update_intro_ui(time_seconds: float) -> void:
	var stepped_time := floorf(time_seconds * FPS) / float(FPS)
	var title_progress := _stepped_progress(
		stepped_time,
		TITLE_START_SECONDS,
		TITLE_END_SECONDS
	)
	var subtitle_progress := _stepped_progress(
		stepped_time,
		SUBTITLE_START_SECONDS,
		SUBTITLE_END_SECONDS
	)
	var menu_progress := _stepped_progress(
		stepped_time,
		MENU_START_SECONDS,
		MENU_END_SECONDS
	)

	_title_band.modulate.a = title_progress
	_subtitle.modulate.a = subtitle_progress
	_menu_anchor.modulate.a = menu_progress

	var title_offset := roundf(lerpf(-26.0, 0.0, _arrival_curve(title_progress)))
	var subtitle_offset := roundf(lerpf(-10.0, 0.0, subtitle_progress))
	var menu_offset := roundf(lerpf(18.0, 0.0, _arrival_curve(menu_progress)))
	_title_band.position = _title_base_position + Vector2(0.0, title_offset)
	_subtitle.position = _subtitle_base_position + Vector2(0.0, subtitle_offset)
	_menu_anchor.position = _menu_base_position + Vector2(0.0, menu_offset)

	if menu_progress >= 1.0 and not _menu_interactive:
		_set_menu_interactive(true)
		call_deferred("_focus_first_menu_button")


func _stepped_progress(time_seconds: float, start: float, finish: float) -> float:
	if time_seconds <= start:
		return 0.0
	if time_seconds >= finish:
		return 1.0
	var progress := (time_seconds - start) / (finish - start)
	return floorf(progress * 8.0) / 8.0


func _arrival_curve(progress: float) -> float:
	# A one-pixel overshoot near the end gives the title and menu a restrained
	# landing beat without introducing sub-pixel scaling or blurred motion.
	if progress < 0.75:
		return (progress / 0.75) * 0.96
	if progress < 0.875:
		return lerpf(0.96, 1.06, (progress - 0.75) / 0.125)
	return lerpf(1.06, 1.0, (progress - 0.875) / 0.125)


func _finish_intro() -> void:
	if _intro_complete:
		return
	_intro_complete = true
	_elapsed_seconds = INTRO_DURATION_SECONDS
	_update_intro_ui(INTRO_DURATION_SECONDS)
	_set_menu_interactive(true)
	call_deferred("_focus_first_menu_button")
	intro_finished.emit()


func _build_menu_styles() -> void:
	_normal_button_style = _make_button_style(
		Color(COLOR_BLUE_DARK, 0.90),
		COLOR_OUTLINE
	)
	_hover_button_style = _make_button_style(
		Color(COLOR_TISSUE_DARK, 0.96),
		COLOR_MINT
	)
	_pressed_button_style = _make_button_style(
		Color(COLOR_CORAL, 0.96),
		COLOR_AMBER_LIGHT
	)
	_focus_button_style = _make_button_style(
		Color(COLOR_BLUE, 0.96),
		COLOR_MINT
	)


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(COLOR_OUTLINE, 0.75)
	style.shadow_size = 2
	style.shadow_offset = Vector2(2.0, 2.0)
	return style


func _refresh_dynamic_menu() -> void:
	var title_menu := _menu_anchor.get_node_or_null("TitleMenu") as VBoxContainer
	if title_menu == null:
		return
	title_menu.add_theme_constant_override("separation", 7)

	# The font itself comes from the global UiTheme, so only the sizes and the
	# title-specific styling are set here.
	for descendant in title_menu.find_children("*", "", true, false):
		if descendant is Button:
			_style_button(descendant as Button)
		elif descendant is Label:
			_style_prompt(descendant as Label)


func _style_button(button: Button) -> void:
	if not button.has_meta("metabolis_pixel_styled"):
		button.set_meta("metabolis_pixel_styled", true)
		button.custom_minimum_size = MENU_BUTTON_SIZE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		button.add_theme_color_override("font_color", COLOR_CREAM)
		button.add_theme_color_override("font_hover_color", COLOR_MINT)
		button.add_theme_color_override("font_pressed_color", COLOR_AMBER_LIGHT)
		button.add_theme_color_override("font_focus_color", COLOR_MINT)
		button.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		button.add_theme_constant_override("outline_size", 1)
		button.add_theme_stylebox_override("normal", _normal_button_style)
		button.add_theme_stylebox_override("hover", _hover_button_style)
		button.add_theme_stylebox_override("pressed", _pressed_button_style)
		button.add_theme_stylebox_override("focus", _focus_button_style)
	button.disabled = not _menu_interactive


func _style_prompt(label: Label) -> void:
	if label.has_meta("metabolis_pixel_styled"):
		return
	label.set_meta("metabolis_pixel_styled", true)
	label.custom_minimum_size = Vector2(MENU_BUTTON_SIZE.x, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_CREAM)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 1)


func _set_menu_interactive(enabled: bool) -> void:
	_menu_interactive = enabled
	for button in _menu_anchor.find_children("*", "Button", true, false):
		(button as Button).disabled = not enabled
	_menu_anchor.mouse_filter = (
		Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
	)


func _focus_first_menu_button() -> void:
	if not _menu_interactive:
		return
	for button in _menu_anchor.find_children("*", "Button", true, false):
		var menu_button := button as Button
		if not menu_button.disabled and menu_button.visible:
			menu_button.grab_focus()
			return
