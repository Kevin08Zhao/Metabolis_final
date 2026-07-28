extends Node

## SaveManager · versioned local save writing.
##
## The save is three blocks. `main_progress` carries progression across stages,
## `chapter_snapshots` holds the complete city state as each stage was first
## entered, and `current_city_state` holds the live main line. A player replaying
## a finished stage reads from the snapshot, never from the live state, which is
## why the snapshot must be written once and then left alone.
##
## This singleton knows nothing about gameplay. It references no gameplay script
## and imports no type from one; every value arrives as a parameter and leaves as
## JSON. That is what lets it be tested without a running game, and what stops a
## save format change from rippling into the simulation.
##
## Writing is atomic in two senses. All three blocks go out in one call, never
## separately, so a save can never hold blocks from different moments. And the
## bytes land in a temporary file that replaces the real one only after it is
## fully written, so a failure midway leaves the previous save intact rather than
## truncated.
##
## Autoload registration:
## Project > Project Settings > Globals > Autoload
## Select res://autoload/save_manager.gd, set the name to SaveManager, enable it.
##
## Requires the `Balance` autoload for the save version.

const LOG_PREFIX := "[SAVE]"

## One save, no slots. The prompt rules out multiple slots and cloud sync.
const SAVE_PATH := "user://metabolis_save.json"
const TEMP_PATH := "user://metabolis_save.json.tmp"

## Where the version comes from. `save.*` is the configured alias for
## `chapters.save.*`, per docs/BALANCE_VALIDATION.md.
const VERSION_PATH := "save.version"

## The top-level keys this manager writes, in order. Every one is a field marked
## # SAVED in src/data/game_state.gd; nothing else is persisted.
const TOP_LEVEL_KEYS: Array[StringName] = [
	&"save_version",
	&"main_progress",
	&"chapter_snapshots",
	&"current_city_state",
	&"unlocked_knowledge_entry_ids",
	&"read_knowledge_entry_ids",
]

## Emitted after every write attempt so a caller can surface the outcome without
## polling. `path` is empty on failure.
signal save_written(succeeded: bool, milestone: StringName, path: String)

## Added by T-27. The four ways a load can end. Every one of them leaves the game
## playable; none of them is an error state the player has to resolve.
const OUTCOME_LOADED := &"loaded"
const OUTCOME_VERSION_MISMATCH := &"version_mismatch"
const OUTCOME_CORRUPT := &"corrupt"
const OUTCOME_ABSENT := &"absent"

## Added by T-27. The three fields table F1 requires in an opening snapshot. A
## snapshot missing any of them cannot start a replay, so its stage is marked
## un-enterable rather than trusted.
##
## They are required only of a stage that actually receives carryover. The first
## stage has no predecessor and therefore no carryover to carry, so demanding
## these of it would make the tutorial permanently unreplayable. Table F2 lists
## writes only for the three stages that receive carryover, but its subject is
## carryover mapping, not snapshot policy; T-26 and T-28 both speak of every
## started and every completed stage.
const REQUIRED_SNAPSHOT_FIELDS: Array[StringName] = [
	&"network_efficiency_coefficient",
	&"initial_operation_pressure",
	&"initial_waste_accumulation",
]

var _main_progress: Dictionary = {}
var _chapter_snapshots: Dictionary = {}
var _current_city_state: Dictionary = {}
var _unlocked_knowledge_entry_ids: Array = []
var _read_knowledge_entry_ids: Array = []

## The "snapshot already written for this stage" flag the prompt requires, kept
## as the set of stages that have one. It is rebuilt from the snapshot block
## whenever that block is adopted, so the flag and the data cannot drift apart.
var _snapshot_written_stage_ids: Array[StringName] = []

var _last_error: String = ""


# ---------------------------------------------------------------------------
# Feeding the blocks
# ---------------------------------------------------------------------------

func set_main_progress(main_progress: Dictionary) -> void:
	_main_progress = main_progress.duplicate(true)


func set_current_city_state(current_city_state: Dictionary) -> void:
	_current_city_state = current_city_state.duplicate(true)


func set_knowledge_entries(unlocked_ids: Array, read_ids: Array) -> void:
	_unlocked_knowledge_entry_ids = unlocked_ids.duplicate()
	_read_knowledge_entry_ids = read_ids.duplicate()


## Record a stage's opening snapshot. Called by the chapter flow state machine
## before it enters step one, and refused on every later call for that stage.
##
## The refusal is the point. An autosave later in the same stage must not
## overwrite the state the stage began with, or replaying that stage would resume
## from the middle of it. Returns false when the stage already has one.
func record_stage_snapshot(stage_id: StringName, snapshot: Dictionary) -> bool:
	if stage_id == &"":
		push_warning("%s Refused a snapshot with no stage id." % LOG_PREFIX)
		return false

	if has_stage_snapshot(stage_id):
		print(
			"%s '%s' already has an opening snapshot; leaving it untouched."
			% [LOG_PREFIX, stage_id]
		)
		return false

	_chapter_snapshots[String(stage_id)] = snapshot.duplicate(true)
	_snapshot_written_stage_ids.append(stage_id)
	print("%s Recorded the opening snapshot for '%s'." % [LOG_PREFIX, stage_id])
	return true


func has_stage_snapshot(stage_id: StringName) -> bool:
	return _snapshot_written_stage_ids.has(stage_id)


## Used by T-27 after a successful load, and by nothing else. Rebuilds the
## snapshot flags from the loaded block so the two cannot disagree.
func adopt_loaded_blocks(save_data: Dictionary) -> void:
	_main_progress = _dictionary_at(save_data, &"main_progress")
	_chapter_snapshots = _dictionary_at(save_data, &"chapter_snapshots")
	_current_city_state = _dictionary_at(save_data, &"current_city_state")
	_unlocked_knowledge_entry_ids = _array_at(save_data, &"unlocked_knowledge_entry_ids")
	_read_knowledge_entry_ids = _array_at(save_data, &"read_knowledge_entry_ids")

	_snapshot_written_stage_ids = []
	for key in _chapter_snapshots:
		_snapshot_written_stage_ids.append(StringName(str(key)))


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

## Write all three blocks in one atomic transaction. `milestone` labels why the
## save happened and is carried on the signal; it is not persisted.
## Returns false on any failure, having left the previous save untouched.
func save(milestone: StringName = &"manual") -> bool:
	var payload := build_payload()
	var text := JSON.stringify(payload, "\t")

	if not _write_temp(text):
		save_written.emit(false, milestone, "")
		return false

	if not _replace_real_file():
		_discard_temp()
		save_written.emit(false, milestone, "")
		return false

	print("%s Wrote %s (%s), %d bytes." % [LOG_PREFIX, SAVE_PATH, milestone, text.length()])
	save_written.emit(true, milestone, SAVE_PATH)
	return true


## The same write, labelled as an automatic one. Kept as a separate entry point
## so the log and the signal say which kind happened.
func autosave(milestone: StringName) -> bool:
	return save(milestone)


## The exact object that would be written. Exposed so a caller can inspect or
## test the shape without touching the disk.
func build_payload() -> Dictionary:
	return {
		"save_version": int(Balance.get_value(VERSION_PATH, 0)),
		"main_progress": _main_progress.duplicate(true),
		"chapter_snapshots": _chapter_snapshots.duplicate(true),
		"current_city_state": _current_city_state.duplicate(true),
		"unlocked_knowledge_entry_ids": _unlocked_knowledge_entry_ids.duplicate(),
		"read_knowledge_entry_ids": _read_knowledge_entry_ids.duplicate(),
	}


func last_error() -> String:
	return _last_error


func save_file_path() -> String:
	return SAVE_PATH


## The real location on disk, for a player who needs to find or clear the file.
func absolute_save_path() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)


# ---------------------------------------------------------------------------
# Atomic write internals
#
# The order matters: a fully written temporary file replaces the real one only
# once it is closed. A failure at any earlier point leaves the previous save
# exactly as it was, and leaves no temporary file behind either.
# ---------------------------------------------------------------------------

func _write_temp(text: String) -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		_fail(
			"Could not open the temporary file %s for writing (error %d). The previous save is untouched."
			% [TEMP_PATH, FileAccess.get_open_error()]
		)
		return false

	file.store_string(text)
	file.close()

	var written := FileAccess.get_open_error()
	if written != OK:
		_fail("Failed while writing %s (error %d). The previous save is untouched." % [TEMP_PATH, written])
		_discard_temp()
		return false

	if not FileAccess.file_exists(TEMP_PATH):
		_fail("The temporary file %s did not appear. The previous save is untouched." % TEMP_PATH)
		return false

	return true


func _replace_real_file() -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		_fail("Could not open the user data directory (error %d)." % DirAccess.get_open_error())
		return false

	var error := directory.rename(TEMP_PATH, SAVE_PATH)
	if error != OK:
		_fail(
			"Could not replace %s with the temporary file (error %d). The previous save is untouched."
			% [SAVE_PATH, error]
		)
		return false

	_last_error = ""
	return true


## Never leave a partial file lying next to a good save.
func _discard_temp() -> void:
	if not FileAccess.file_exists(TEMP_PATH):
		return
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	if directory.remove(TEMP_PATH) == OK:
		print("%s Removed the leftover temporary file." % LOG_PREFIX)


func _fail(message: String) -> void:
	_last_error = message
	push_error("%s %s" % [LOG_PREFIX, message])


# ---------------------------------------------------------------------------
# Reading, added by T-27
#
# Three rules shape all of it.
#
# Every field is read with a default, because a save on disk is untrusted input
# and a missing key must never be an exception.
#
# Nothing here writes to a gameplay script. The result is returned and the
# blocks are adopted into this manager; what the game does with them is the
# caller's business.
#
# No path deletes or rewrites the file. A corrupt save is kept exactly as found,
# because it is the only copy of whatever the player did and a future version may
# be able to read more of it than this one can.
# ---------------------------------------------------------------------------

## Read the save and report what could be recovered. Never throws, never crashes,
## and never leaves the game unplayable. The returned dictionary carries:
##   outcome                   one of the four OUTCOME_ constants
##   save_version              the version found on disk, 0 when unknown
##   main_progress             restored, or empty
##   chapter_snapshots         restored, or empty when discarded
##   current_city_state        restored, or empty when discarded
##   unlocked_knowledge_entry_ids / read_knowledge_entry_ids
##   chapter_select_available  false whenever the snapshots were not restored
##   unusable_stage_ids        stages whose snapshot is missing or malformed
##   explanation               one readable sentence, already printed
func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _load_result(
			OUTCOME_ABSENT, 0, {}, {}, {}, [], [], [],
			"No save file yet. Starting a new run."
		)

	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return _load_result(
			OUTCOME_CORRUPT, 0, {}, {}, {}, [], [], [],
			"The save file is empty or unreadable. It has been left on disk untouched and a new run has started."
		)

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _load_result(
			OUTCOME_CORRUPT, 0, {}, {}, {}, [], [], [],
			"The save file is not valid JSON. It has been left on disk untouched and a new run has started."
		)

	var data: Dictionary = parsed
	# Written as an integer, but Godot's JSON parser returns every number as a
	# float, so this must cast rather than compare types. A strict int equality
	# here would treat every healthy save as a mismatch.
	var found_version := int(float(data.get("save_version", 0)))
	var expected_version := int(Balance.get_value(VERSION_PATH, 0))

	var main_progress := _dictionary_at(data, &"main_progress")
	var unlocked := _array_at(data, &"unlocked_knowledge_entry_ids")
	var read := _array_at(data, &"read_knowledge_entry_ids")

	if found_version != expected_version:
		return _load_result(
			OUTCOME_VERSION_MISMATCH, found_version, main_progress, {}, {}, unlocked, read, [],
			(
				"Save version %d does not match this build's version %d. Progress between stages was kept; "
				+ "the stage snapshots and the live city state were discarded, so the current stage restarts "
				+ "from its beginning and chapter select is unavailable."
			) % [found_version, expected_version]
		)

	var snapshots := _dictionary_at(data, &"chapter_snapshots")
	var unusable := _unusable_stage_ids(snapshots)
	var current_city_state := _dictionary_at(data, &"current_city_state")

	var explanation := "Save loaded."
	if not unusable.is_empty():
		explanation = (
			"Save loaded. %d stage snapshot(s) are missing or malformed and those stages cannot be replayed: %s"
			% [unusable.size(), ", ".join(_names_of(unusable))]
		)

	return _load_result(
		OUTCOME_LOADED, found_version, main_progress, snapshots, current_city_state,
		unlocked, read, unusable, explanation
	)


## Whether a stage can be entered in replay. False for a stage with no snapshot
## and for one whose snapshot is malformed, which is what keeps a damaged entry
## from being handed to the replay path as if it were sound.
func can_replay_stage(stage_id: StringName) -> bool:
	if not _chapter_snapshots.has(String(stage_id)):
		return false
	return _is_valid_snapshot(stage_id, _chapter_snapshots[String(stage_id)])


## The opening snapshot for a stage, or an empty dictionary when there is none
## that can be trusted. This is the only sanctioned source for a replay's
## starting conditions; the live state must never be used for that.
func stage_snapshot(stage_id: StringName) -> Dictionary:
	if not can_replay_stage(stage_id):
		return {}
	var value: Variant = _chapter_snapshots[String(stage_id)]
	var snapshot: Dictionary = value
	return snapshot.duplicate(true)


func _unusable_stage_ids(snapshots: Dictionary) -> Array[StringName]:
	var unusable: Array[StringName] = []
	for key in snapshots:
		var stage_id := StringName(str(key))
		if not _is_valid_snapshot(stage_id, snapshots[key]):
			unusable.append(stage_id)
	return unusable


## A snapshot is sound when it is a non-empty dictionary, and, for any stage that
## receives carryover, when it also carries an operation_start_conditions
## dictionary holding all three table F1 fields.
##
## The first stage is judged on the first clause alone. It has no predecessor, so
## it has no carryover, and requiring carryover fields of it would mark the
## tutorial permanently unreplayable while looking like a data integrity check.
func _is_valid_snapshot(stage_id: StringName, value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var snapshot: Dictionary = value
	if snapshot.is_empty():
		return false

	if _is_first_stage(stage_id):
		return true

	var conditions_value: Variant = snapshot.get("operation_start_conditions", null)
	if not conditions_value is Dictionary:
		return false
	var conditions: Dictionary = conditions_value
	for field in REQUIRED_SNAPSHOT_FIELDS:
		if not conditions.has(String(field)):
			return false
	return true


## The stage the run opens on, read from configuration rather than named here.
func _is_first_stage(stage_id: StringName) -> bool:
	var value: Variant = Balance.get_value("progress.initial.current_stage_id", null)
	if value == null:
		return false
	return StringName(str(value)) == stage_id


func _load_result(
	outcome: StringName,
	save_version: int,
	main_progress: Dictionary,
	chapter_snapshots: Dictionary,
	current_city_state: Dictionary,
	unlocked_ids: Array,
	read_ids: Array,
	unusable_stage_ids: Array[StringName],
	explanation: String
) -> Dictionary:
	var chapter_select_available := outcome == OUTCOME_LOADED and not chapter_snapshots.is_empty()

	_main_progress = main_progress.duplicate(true)
	_chapter_snapshots = chapter_snapshots.duplicate(true)
	_current_city_state = current_city_state.duplicate(true)
	_unlocked_knowledge_entry_ids = unlocked_ids.duplicate()
	_read_knowledge_entry_ids = read_ids.duplicate()
	_snapshot_written_stage_ids = []
	for key in _chapter_snapshots:
		_snapshot_written_stage_ids.append(StringName(str(key)))

	print("[LOAD] %s" % explanation)
	EventBus.save_loaded.emit(outcome, chapter_select_available)

	return {
		&"outcome": outcome,
		&"save_version": save_version,
		&"main_progress": _main_progress.duplicate(true),
		&"chapter_snapshots": _chapter_snapshots.duplicate(true),
		&"current_city_state": _current_city_state.duplicate(true),
		&"unlocked_knowledge_entry_ids": _unlocked_knowledge_entry_ids.duplicate(),
		&"read_knowledge_entry_ids": _read_knowledge_entry_ids.duplicate(),
		&"chapter_select_available": chapter_select_available,
		&"unusable_stage_ids": unusable_stage_ids.duplicate(),
		&"explanation": explanation,
	}


func _names_of(ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(id))
	return out


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

func _dictionary_at(source: Dictionary, key: StringName) -> Dictionary:
	var value: Variant = source.get(String(key), {})
	if not value is Dictionary:
		return {}
	var result: Dictionary = value
	return result.duplicate(true)


func _array_at(source: Dictionary, key: StringName) -> Array:
	var value: Variant = source.get(String(key), [])
	if not value is Array:
		return []
	var result: Array = value
	return result.duplicate()
