extends Node

## Unified access to replaceable static art and sprite-sheet animations.
##
## Autoload registration:
## Project > Project Settings > Globals > Autoload
## Select res://core/asset_loader.gd, set the name to AssetLoader, and enable it.
##
## The two public methods accept logical names rather than physical paths:
##   AssetLoader.get_static_texture(&"organ_heart_completed")
##   AssetLoader.get_animation_frames(&"heart_pump_active")
##
## Static names follow {category}_{subject}_{variant}. Animation names follow
## {subject}_{action}_{state}; D-18 pairs that stem with one PNG and one JSON.

const LOG_PREFIX := "[ASSET]"
const STATIC_ART_ROOT := "res://../art"
const ANIMATION_ROOT := "res://../anim"
const EXPECTED_MANIFEST_ROOT := "res://../docs/assets"
const DEFAULT_ANIMATION := &"default"
const PLACEHOLDER_SIZE := Vector2i(16, 16)
const PLACEHOLDER_COLOR := Color(0.82, 0.16, 0.58, 1.0)
const SKIPPED_ART_DIRECTORIES := [
	"candidates",
	"reference",
	"source",
]
const SKIPPED_EXPECTED_PREFIXES := [
	"art/candidates/",
	"art/reference/",
	"art/source/",
]

var _placeholder_texture: ImageTexture


func _ready() -> void:
	_check_expected_assets_at_startup()


## Returns the texture named by {category}_{subject}_{variant}.
## Missing, ambiguous, or unreadable files return one solid-color placeholder.
func get_static_texture(logical_name: StringName) -> Texture2D:
	var stem := String(logical_name)
	var expected_pattern := "%s/**/%s.png" % [STATIC_ART_ROOT, stem]
	if not _is_valid_static_name(stem):
		_warn("Invalid static logical name '%s'; expected {category}_{subject}_{variant}." % stem)
		return _get_placeholder_texture()

	var matches := _find_static_matches("%s.png" % stem)
	if matches.is_empty():
		_warn("Missing file matching %s." % expected_pattern)
		return _get_placeholder_texture()
	if matches.size() > 1:
		_warn("Ambiguous static logical name '%s'; matched %s." % [stem, ", ".join(matches)])
		return _get_placeholder_texture()

	var image := Image.load_from_file(matches[0])
	if image == null or image.is_empty():
		_warn("Could not read image file %s." % _display_path(matches[0]))
		return _get_placeholder_texture()

	return ImageTexture.create_from_image(image)


## Returns a SpriteFrames resource built from D-18's same-stem PNG and JSON.
## Missing or invalid input returns one solid-color, non-looping fallback frame.
func get_animation_frames(logical_name: StringName) -> SpriteFrames:
	var stem := String(logical_name)
	if not _is_valid_animation_name(stem):
		_warn("Invalid animation logical name '%s'; expected {subject}_{action}_{state}." % stem)
		return _make_placeholder_frames()

	var sheet_path := "%s/%s.png" % [ANIMATION_ROOT, stem]
	var metadata_path := "%s/%s.json" % [ANIMATION_ROOT, stem]
	if not FileAccess.file_exists(sheet_path):
		_warn("Missing file: %s." % sheet_path)
		return _make_placeholder_frames()
	if not FileAccess.file_exists(metadata_path):
		_warn("Missing file: %s." % metadata_path)
		return _make_placeholder_frames()

	var metadata := _read_animation_metadata(metadata_path)
	if metadata.is_empty():
		return _make_placeholder_frames()

	var sheet_image := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	if sheet_image == null or sheet_image.is_empty():
		_warn("Could not read image file %s." % sheet_path)
		return _make_placeholder_frames()

	var frame_size: Vector2i = metadata["frame_size"]
	var frame_count: int = metadata["frame_count"]
	var expected_size := Vector2i(frame_size.x * frame_count, frame_size.y)
	if sheet_image.get_size() != expected_size:
		_warn(
			"Sprite sheet %s is %sx%s; metadata requires %sx%s."
			% [
				sheet_path,
				sheet_image.get_width(),
				sheet_image.get_height(),
				expected_size.x,
				expected_size.y,
			]
		)
		return _make_placeholder_frames()

	return _build_animation_frames(sheet_image, metadata)


func _is_valid_static_name(stem: String) -> bool:
	return _is_valid_stem(stem, 3, false)


func _is_valid_animation_name(stem: String) -> bool:
	return _is_valid_stem(stem, 3, true)


func _is_valid_stem(stem: String, minimum_parts: int, exact_parts: bool) -> bool:
	var parts := stem.split("_", false)
	if parts.size() < minimum_parts:
		return false
	if exact_parts and parts.size() != minimum_parts:
		return false

	for part in parts:
		if part.is_empty():
			return false
		for character in part:
			var code := character.unicode_at(0)
			var is_lowercase_letter := code >= 97 and code <= 122
			var is_digit := code >= 48 and code <= 57
			if not is_lowercase_letter and not is_digit:
				return false
	return true


func _find_static_matches(file_name: String) -> PackedStringArray:
	var matches := PackedStringArray()
	var absolute_root := ProjectSettings.globalize_path(STATIC_ART_ROOT)
	_collect_static_matches(absolute_root, file_name, matches, true)
	matches.sort()
	return matches


func _collect_static_matches(
	directory_path: String,
	file_name: String,
	matches: PackedStringArray,
	is_root: bool
) -> void:
	if not DirAccess.dir_exists_absolute(directory_path):
		return

	for candidate_file in DirAccess.get_files_at(directory_path):
		if candidate_file == file_name:
			matches.append(directory_path.path_join(candidate_file))

	for child_name in DirAccess.get_directories_at(directory_path):
		if child_name.begins_with("."):
			continue
		if is_root and SKIPPED_ART_DIRECTORIES.has(child_name):
			continue
		_collect_static_matches(directory_path.path_join(child_name), file_name, matches, false)


func _read_animation_metadata(metadata_path: String) -> Dictionary:
	var file := FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		_warn("Could not open metadata file %s (error %s)." % [metadata_path, FileAccess.get_open_error()])
		return {}

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		_warn(
			"Invalid metadata file %s at line %s: %s."
			% [metadata_path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		_warn("Invalid metadata file %s: root must be an object." % metadata_path)
		return {}
	var source: Dictionary = parsed

	var required_fields := [
		"frame_size",
		"frame_count",
		"frame_durations_ms",
		"loop",
	]
	for field_name in required_fields:
		if not source.has(field_name):
			_warn("Invalid metadata file %s: missing field '%s'." % [metadata_path, field_name])
			return {}

	var frame_size_value: Variant = source["frame_size"]
	if not frame_size_value is Dictionary:
		_warn("Invalid metadata file %s: frame_size must be an object." % metadata_path)
		return {}
	var frame_size_source: Dictionary = frame_size_value
	if not frame_size_source.has("width") or not frame_size_source.has("height"):
		_warn("Invalid metadata file %s: frame_size requires width and height." % metadata_path)
		return {}

	var frame_width := _positive_integer(frame_size_source["width"])
	var frame_height := _positive_integer(frame_size_source["height"])
	var frame_count := _positive_integer(source["frame_count"])
	if frame_width < 1 or frame_height < 1 or frame_count < 1:
		_warn("Invalid metadata file %s: frame dimensions and count must be positive integers." % metadata_path)
		return {}

	var durations_value: Variant = source["frame_durations_ms"]
	if not durations_value is Array:
		_warn("Invalid metadata file %s: frame_durations_ms must be an array." % metadata_path)
		return {}
	var durations_source: Array = durations_value
	if durations_source.size() != frame_count:
		_warn(
			"Invalid metadata file %s: expected %s frame durations, found %s."
			% [metadata_path, frame_count, durations_source.size()]
		)
		return {}

	var frame_durations_ms: Array[int] = []
	for duration_value in durations_source:
		var duration_ms := _positive_integer(duration_value)
		if duration_ms < 1:
			_warn("Invalid metadata file %s: frame durations must be positive integers." % metadata_path)
			return {}
		frame_durations_ms.append(duration_ms)

	if not source["loop"] is bool:
		_warn("Invalid metadata file %s: loop must be a boolean." % metadata_path)
		return {}

	return {
		"frame_size": Vector2i(frame_width, frame_height),
		"frame_count": frame_count,
		"frame_durations_ms": frame_durations_ms,
		"loop": bool(source["loop"]),
	}


func _positive_integer(value: Variant) -> int:
	if not value is int and not value is float:
		return -1
	var number := float(value)
	if number < 1.0 or not is_equal_approx(number, floor(number)):
		return -1
	return int(number)


func _build_animation_frames(sheet_image: Image, metadata: Dictionary) -> SpriteFrames:
	var sheet_texture := ImageTexture.create_from_image(sheet_image)
	var frames := SpriteFrames.new()
	frames.set_animation_loop(DEFAULT_ANIMATION, bool(metadata["loop"]))
	frames.set_animation_speed(DEFAULT_ANIMATION, 1.0)

	var frame_size: Vector2i = metadata["frame_size"]
	var frame_count: int = metadata["frame_count"]
	var frame_durations_ms: Array[int] = metadata["frame_durations_ms"]
	for frame_index in frame_count:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = sheet_texture
		frame_texture.region = Rect2i(
			Vector2i(frame_index * frame_size.x, 0),
			frame_size
		)
		frame_texture.filter_clip = true
		frames.add_frame(
			DEFAULT_ANIMATION,
			frame_texture,
			float(frame_durations_ms[frame_index]) / 1000.0
		)
	return frames


func _get_placeholder_texture() -> ImageTexture:
	if _placeholder_texture != null:
		return _placeholder_texture

	var image := Image.create(
		PLACEHOLDER_SIZE.x,
		PLACEHOLDER_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(PLACEHOLDER_COLOR)
	_placeholder_texture = ImageTexture.create_from_image(image)
	return _placeholder_texture


func _make_placeholder_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(DEFAULT_ANIMATION, false)
	frames.set_animation_speed(DEFAULT_ANIMATION, 1.0)
	frames.add_frame(DEFAULT_ANIMATION, _get_placeholder_texture(), 1.0)
	return frames


func _check_expected_assets_at_startup() -> PackedStringArray:
	var manifest_directory := ProjectSettings.globalize_path(EXPECTED_MANIFEST_ROOT)
	if not DirAccess.dir_exists_absolute(manifest_directory):
		_warn("Expected-asset manifest directory is unavailable: %s." % EXPECTED_MANIFEST_ROOT)
		return PackedStringArray()

	var path_pattern := RegEx.new()
	var compile_error := path_pattern.compile("(?:art|anim)/[a-zA-Z0-9_./-]+\\.(?:png|json)")
	if compile_error != OK:
		_warn("Could not compile the expected-asset manifest scanner.")
		return PackedStringArray()

	var expected_paths := PackedStringArray()
	for file_name in DirAccess.get_files_at(manifest_directory):
		if not file_name.ends_with("_MANIFEST.md"):
			continue
		var manifest_path := manifest_directory.path_join(file_name)
		var manifest := FileAccess.open(manifest_path, FileAccess.READ)
		if manifest == null:
			_warn("Could not read expected-asset manifest: %s." % _display_path(manifest_path))
			continue
		for path_match in path_pattern.search_all(manifest.get_as_text()):
			var relative_path := path_match.get_string()
			if _is_skipped_expected_path(relative_path):
				continue
			if not expected_paths.has(relative_path):
				expected_paths.append(relative_path)

	expected_paths.sort()
	var missing_paths := PackedStringArray()
	for relative_path in expected_paths:
		var repository_path := "res://../%s" % relative_path
		if not FileAccess.file_exists(repository_path):
			missing_paths.append(repository_path)

	for missing_path in missing_paths:
		_warn("Missing expected file: %s." % missing_path)
	print(
		"%s Startup check: %s expected file(s), %s missing."
		% [LOG_PREFIX, expected_paths.size(), missing_paths.size()]
	)
	return missing_paths


func _is_skipped_expected_path(relative_path: String) -> bool:
	for skipped_prefix in SKIPPED_EXPECTED_PREFIXES:
		if relative_path.begins_with(skipped_prefix):
			return true
	return false


func _display_path(absolute_path: String) -> String:
	var repository_root := ProjectSettings.globalize_path("res://../")
	if absolute_path.begins_with(repository_root):
		return "res://../%s" % absolute_path.trim_prefix(repository_root)
	return absolute_path


func _warn(message: String) -> void:
	push_warning("%s %s" % [LOG_PREFIX, message])
