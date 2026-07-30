extends Node

## Read-only access to gameplay values stored in docs/BALANCE.json.
##
## Autoload registration:
## Project > Project Settings > Globals > Autoload
## Select res://autoload/balance.gd, set the name to Balance, and enable it.

const BALANCE_PATH := "res://../docs/BALANCE.json"
const REQUIRED_PATHS: Array[String] = [
	"version",
	"tick_interval_sec",
	"chapters",
	"resources",
	"organs",
	"build_options",
	"operations",
	"network",
	"carryover",
	"minigames",
	"challenges",
	"notifications",
	"assist",
]
const PATH_PREFIX_ALIASES := {
	"operation": "operations",
	"transport": "network.transport",
	"signal": "network.signal",
	"stability": "operations.stability",
	"thresholds": "operations.thresholds",
	"bottlenecks": "operations.bottlenecks",
	"birth_check": "operations.birth_check",
	"normalized": "operations.normalized",
	"ui": "operations.ui",
	"validation": "operations.validation",
	"save": "chapters.save",
	"progress": "chapters.progress",
	"knowledge": "assist.knowledge",
}

var _config: Dictionary = {}
var _runtime_context: Dictionary = {}


func _ready() -> void:
	load_balance()


func load_balance(path: String = BALANCE_PATH) -> bool:
	_config = {}

	if not FileAccess.file_exists(path):
		push_error("[BALANCE] Could not read configuration file: %s. Continuing with an empty configuration." % path)
		validate_required_keys()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(
			"[BALANCE] Could not open configuration file: %s (error %s). Continuing with an empty configuration."
			% [path, FileAccess.get_open_error()]
		)
		validate_required_keys()
		return false

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		push_error(
			"[BALANCE] Could not parse configuration file: %s at line %s: %s. Continuing with an empty configuration."
			% [path, json.get_error_line(), json.get_error_message()]
		)
		validate_required_keys()
		return false

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_error("[BALANCE] Configuration root must be a JSON object: %s. Continuing with an empty configuration." % path)
		validate_required_keys()
		return false

	_config = parsed
	validate_required_keys()
	return true


func get_value(path: String, default_value: Variant = null) -> Variant:
	if path.is_empty():
		push_warning("[BALANCE] Empty key path requested; returning the caller default.")
		return default_value

	var canonical_path := _canonicalize_path(path)
	var current: Variant = _config
	for segment in canonical_path.split(".", false):
		if current is Dictionary:
			var current_dictionary: Dictionary = current
			if current_dictionary.has(segment):
				current = current_dictionary[segment]
				continue
		elif current is Array and segment.is_valid_int():
			var current_array: Array = current
			var index := segment.to_int()
			if index >= 0 and index < current_array.size():
				current = current_array[index]
				continue

		push_warning("[BALANCE] Missing key path '%s'; returning the caller default." % path)
		return default_value

	return current


func set_runtime_context(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


func validate_required_keys() -> PackedStringArray:
	var missing_paths := PackedStringArray()

	for required_path in REQUIRED_PATHS:
		if not _has_path(required_path):
			missing_paths.append(required_path)

	for missing_path in missing_paths:
		push_warning("[BALANCE] Missing required key: %s" % missing_path)

	return missing_paths


func _has_path(path: String) -> bool:
	var canonical_path := _canonicalize_path(path)
	var current: Variant = _config

	for segment in canonical_path.split(".", false):
		if current is Dictionary:
			var current_dictionary: Dictionary = current
			if current_dictionary.has(segment):
				current = current_dictionary[segment]
				continue
		elif current is Array and segment.is_valid_int():
			var current_array: Array = current
			var index := segment.to_int()
			if index >= 0 and index < current_array.size():
				current = current_array[index]
				continue

		return false

	return true


func _canonicalize_path(path: String) -> String:
	path = path.trim_prefix("balance.")

	if path.begins_with("build.cost["):
		return _canonicalize_build_cost_path(path)

	if path == "build.selection_policy" or path.begins_with("build.selection_policy."):
		return "build_options.selection_policy" + path.trim_prefix("build.selection_policy")

	if path == "build.slot_selection_policy" or path.begins_with("build.slot_selection_policy."):
		return "build_options.slot_selection_policy" + path.trim_prefix("build.slot_selection_policy")

	if path.begins_with("operation.cost[") or path.begins_with("operation.outcome["):
		return _canonicalize_operation_option_path(path)

	if path == "transport.intervention.capacity" or path.begins_with("transport.intervention.capacity."):
		return "network.transport.intervention.capacity_increment" + path.trim_prefix("transport.intervention.capacity")

	if path == "minigame.initial_resolution" or path.begins_with("minigame.initial_resolution."):
		return "minigames.runtime" + path.trim_prefix("minigame")

	if path == "minigame" or path.begins_with("minigame."):
		return _canonicalize_minigame_path(path)

	if path == "stage.carryover" or path.begins_with("stage.carryover."):
		return "carryover" + path.trim_prefix("stage.carryover")

	var first_separator := path.find(".")
	var prefix := path if first_separator < 0 else path.left(first_separator)
	if not PATH_PREFIX_ALIASES.has(prefix):
		return path

	var suffix := "" if first_separator < 0 else path.substr(first_separator)
	return String(PATH_PREFIX_ALIASES[prefix]) + suffix


func _canonicalize_build_cost_path(path: String) -> String:
	var closing_bracket := path.find("]")
	if closing_bracket < 0:
		return path

	var selector := path.substr("build.cost[".length(), closing_bracket - "build.cost[".length())
	var option_id := _resolve_selector(selector)
	var decision_id := _find_build_decision_id(option_id)
	if decision_id.is_empty():
		return path

	var suffix := path.substr(closing_bracket + 1)
	return "build_options.%s.%s.cost%s" % [decision_id, option_id, suffix]


func _canonicalize_operation_option_path(path: String) -> String:
	var outcome_path := path.begins_with("operation.outcome[")
	var prefix := "operation.outcome[" if outcome_path else "operation.cost["
	var closing_bracket := path.find("]")
	if closing_bracket < 0:
		return path

	var selector := path.substr(prefix.length(), closing_bracket - prefix.length())
	var option_id := _resolve_selector(selector)
	if option_id.is_empty():
		return path

	var value_group := "outcome" if outcome_path else "cost"
	var suffix := path.substr(closing_bracket + 1)
	return "operations.options.%s.%s%s" % [option_id, value_group, suffix]


func _canonicalize_minigame_path(path: String) -> String:
	var minigame_id := String(_runtime_context.get("active_minigame_id", ""))
	if minigame_id.is_empty():
		return path

	var suffix := path.trim_prefix("minigame")
	if suffix == ".time_limit" or suffix.begins_with(".time_limit."):
		suffix = ".duration_limit_sec" + suffix.trim_prefix(".time_limit")

	return "minigames.%s%s" % [minigame_id, suffix]


func _resolve_selector(selector: String) -> String:
	if _runtime_context.has(selector):
		return String(_runtime_context[selector])
	return selector


func _find_build_decision_id(option_id: String) -> String:
	if option_id.is_empty() or not _config.has("build_options"):
		return ""

	var build_options: Dictionary = _config["build_options"]
	for decision_id in build_options:
		var decision_value: Variant = build_options[decision_id]
		if decision_value is Dictionary and decision_value.has(option_id):
			return String(decision_id)

	return ""
