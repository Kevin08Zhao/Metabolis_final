class_name InfoContainers
extends Control

## The paused organ-archive information container.
##
## D-17a and T-30b moved every immediate prompt into NotificationQueue. This
## class now owns only the archive: opening it stops the world, and the player
## has to close it before the world starts again.
##
## It is size-locked. Art fixed the dimensions in docs/UI_LAYOUT.md table G2,
## and every pixel figure in this file is transcribed from that table.
## They are deliberately NOT configurable and deliberately NOT in Balance: a
## container that can be resized at runtime cannot be guaranteed to hold the text
## the tables say it holds.
##
## Which is why overflow truncates. When content does not fit, this script cuts
## it and prints a `[UI]` line naming the offending content. It never shrinks the
## font, never adds a scrollbar, and never paginates, because all three would
## quietly break the size lock instead of reporting it.
##
## Every string is a bracketed placeholder. T-31 owns the real copy.
##
## Requires the `EventBus` autoload.

const LOG_PREFIX := "[UI]"

# ---------------------------------------------------------------------------
# Table G2 - organ archive capacity
# ---------------------------------------------------------------------------

const G2_WIDTH_PX := 560
const G2_HEIGHT_PX := 304
const G2_BORDER_PX := 2
const G2_PADDING_H_PX := 12
const G2_PADDING_V_PX := 8
const G2_HEADER_PX := 20
const G2_HEADER_GAP_PX := 4
const G2_FIELD_GAP_PX := 6
const G2_FONT_PX := 8
const G2_LINE_HEIGHT_PX := 10
const G2_FIELD_COUNT := 7
const G2_LINES_PER_FIELD := 3
const G2_MAX_LINES_TOTAL := 21
const G2_MAX_CHARS_PER_LINE := 66

## The seven slots, top to bottom. docs/UI_LAYOUT.md numbers them G2-1 through
## G2-7 and stops there; it does not name them. Naming them here would be
## inventing a spec, so the identifiers stay positional and the caller decides
## what goes in each slot. The visible labels are placeholders for T-31.
const G2_FIELD_IDS: Array[StringName] = [
	&"g2_1",
	&"g2_2",
	&"g2_3",
	&"g2_4",
	&"g2_5",
	&"g2_6",
	&"g2_7",
]

## Placeholder copy. All of it belongs to T-31.
const ARCHIVE_HEADER_PLACEHOLDER := "[archive:%s]"
const FIELD_LABEL_PLACEHOLDER := "[field:%s]"
const FIELD_EMPTY_PLACEHOLDER := "[empty]"

## Shown for the whole time the archive holds the game. Table G2's header carries
## a two-bar pause symbol; art forbids an invisible pause state, so this label is
## the code-side guarantee that something is always on screen while paused.
const PAUSE_INDICATOR_PLACEHOLDER := "[paused] Operation time and resource settlement are stopped."

signal archive_opened(entry_id: StringName)
signal archive_closed(entry_id: StringName)

var _archive_root: PanelContainer = null
var _archive_header: Label = null
var _archive_pause_indicator: Label = null
var _archive_field_lines: Dictionary = {}
var _archive_entry_id: StringName = &""
var _archive_organ_id: StringName = &""
var _read_entry_ids: Dictionary = {}

var _paused := false
var _tree_paused_before := false

## Counts the seconds this gate has swallowed while the archive was open. It has
## no gameplay effect; it exists so an acceptance run can prove that settlement
## time was withheld rather than merely that the screen stopped moving.
var _withheld_seconds := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_archive()


# ---------------------------------------------------------------------------
# The organ archive
# ---------------------------------------------------------------------------

## Open the archive on one entry. `fields` maps the seven G2 slot ids to their
## placeholder content; a slot the caller omits shows the empty placeholder
## rather than borrowing another slot's lines.
##
## Opening pauses operation time and resource settlement, and raises the pause
## indicator. Both stay that way until close_organ_archive().
func open_organ_archive(entry_id: StringName, organ_id: StringName, fields: Dictionary) -> bool:
	if entry_id == &"" or _archive_entry_id != &"":
		return false

	_archive_entry_id = entry_id
	_archive_organ_id = organ_id
	_archive_header.text = ARCHIVE_HEADER_PLACEHOLDER % organ_id

	for field_id in G2_FIELD_IDS:
		var supplied: Variant = fields.get(field_id, null)
		var content := _as_lines(supplied)
		var fitted := _fit(
			content,
			G2_LINES_PER_FIELD,
			G2_MAX_CHARS_PER_LINE,
			"archive '%s' field %s" % [entry_id, field_id]
		)
		var labels: Array = _archive_field_lines[field_id]
		for index in G2_LINES_PER_FIELD:
			var label: Label = labels[index]
			if index < fitted.size():
				label.text = fitted[index]
			elif index == 0:
				label.text = FIELD_EMPTY_PLACEHOLDER
			else:
				label.text = ""

	_archive_root.visible = true
	_set_paused(true)

	var first_read := not _read_entry_ids.has(entry_id)
	_read_entry_ids[entry_id] = true

	print("%s archive '%s' opened; the game is paused." % [LOG_PREFIX, entry_id])
	EventBus.knowledge_entry_opened.emit(entry_id, first_read)
	archive_opened.emit(entry_id)
	return true


## Close the archive and resume. Emits the closing half of the pair, so a
## listener does not have to infer the resume from the absence of an event.
func close_organ_archive() -> bool:
	if _archive_entry_id == &"":
		return false

	var closed := _archive_entry_id
	_archive_entry_id = &""
	_archive_organ_id = &""
	_archive_root.visible = false
	_set_paused(false)

	print("%s archive '%s' closed; the game resumes." % [LOG_PREFIX, closed])
	EventBus.knowledge_entry_closed.emit(closed)
	archive_closed.emit(closed)
	return true


func archive_open() -> bool:
	return _archive_entry_id != &""


func current_entry_id() -> StringName:
	return _archive_entry_id


## What one G2 slot currently reads, after truncation.
func archive_field_lines(field_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not _archive_field_lines.has(field_id):
		return out
	for label in _archive_field_lines[field_id] as Array:
		out.append((label as Label).text)
	return out


# ---------------------------------------------------------------------------
# The pause
#
# Two mechanisms, because the requirement has two halves. The scene tree pause
# stops timers and every node that processes. The settlement gate below stops
# the resource loop, which is driven by an explicit elapsed-seconds argument and
# would otherwise be handed the whole paused interval in one lump the moment the
# archive closed - the exact failure the acceptance has to be able to rule out.
# ---------------------------------------------------------------------------

## The seam a tick driver calls instead of using its own delta. While the archive
## is open this returns zero and the elapsed time is discarded, not banked.
func elapsed_for_settlement(delta: float) -> float:
	if _paused:
		_withheld_seconds += delta
		return 0.0
	return delta


func is_paused() -> bool:
	return _paused


## Total simulated seconds refused while the archive was open. An acceptance run
## compares this against unchanged resource totals: the pair together shows that
## settlement stopped and did not silently catch up afterwards.
func withheld_seconds() -> float:
	return _withheld_seconds


func pause_indicator_visible() -> bool:
	return _archive_pause_indicator != null and _archive_pause_indicator.visible


func _set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	_archive_pause_indicator.visible = paused

	var tree := get_tree()
	if tree == null:
		return
	if paused:
		_tree_paused_before = tree.paused
		tree.paused = true
	else:
		tree.paused = _tree_paused_before


# ---------------------------------------------------------------------------
# Capacity
# ---------------------------------------------------------------------------

## Cut `lines` down to the container's capacity and report every cut. Two limits
## apply independently: too many lines, and any single line too long. Both are
## reported by name so a `[UI]` line identifies which content overran and how.
func _fit(
	lines: PackedStringArray,
	max_lines: int,
	max_chars: int,
	content_label: String
) -> PackedStringArray:
	var out := PackedStringArray()

	if lines.size() > max_lines:
		print("%s %s overruns table capacity: %d lines given, %d allowed. The extra lines are cut."
			% [LOG_PREFIX, content_label, lines.size(), max_lines])

	for index in mini(lines.size(), max_lines):
		var line := lines[index]
		if line.length() > max_chars:
			print("%s %s line %d overruns table capacity: %d characters given, %d allowed. It is cut."
				% [LOG_PREFIX, content_label, index + 1, line.length(), max_chars])
			line = line.substr(0, max_chars)
		out.append(line)

	return out


func _as_lines(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	if value is Array:
		var out := PackedStringArray()
		for entry in value as Array:
			out.append(str(entry))
		return out
	if value == null:
		return PackedStringArray()
	return PackedStringArray([str(value)])


# ---------------------------------------------------------------------------
# Construction
#
# The size comes from table G2 and is applied as a minimum size on the archive.
# This is the one place in the UI layer that writes those pixel figures.
# ---------------------------------------------------------------------------

func _build_archive() -> void:
	_archive_root = PanelContainer.new()
	_archive_root.name = "OrganArchive"
	_archive_root.custom_minimum_size = Vector2(G2_WIDTH_PX, G2_HEIGHT_PX)
	_archive_root.size = Vector2(G2_WIDTH_PX, G2_HEIGHT_PX)
	_archive_root.visible = false
	add_child(_archive_root)

	var column := VBoxContainer.new()
	column.name = "ArchiveBody"
	column.add_theme_constant_override("separation", G2_FIELD_GAP_PX)
	_archive_root.add_child(column)

	var header_row := HBoxContainer.new()
	header_row.name = "ArchiveHeader"
	header_row.custom_minimum_size = Vector2(0, G2_HEADER_PX)
	column.add_child(header_row)

	_archive_header = Label.new()
	_archive_header.name = "HeaderTitle"
	_archive_header.text = ARCHIVE_HEADER_PLACEHOLDER % "pending"
	header_row.add_child(_archive_header)

	_archive_pause_indicator = Label.new()
	_archive_pause_indicator.name = "PauseIndicator"
	_archive_pause_indicator.text = PAUSE_INDICATOR_PLACEHOLDER
	_archive_pause_indicator.visible = false
	header_row.add_child(_archive_pause_indicator)

	var gap := Control.new()
	gap.name = "HeaderGap"
	gap.custom_minimum_size = Vector2(0, G2_HEADER_GAP_PX)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	for field_id in G2_FIELD_IDS:
		var field := VBoxContainer.new()
		field.name = "Field_%s" % field_id
		field.custom_minimum_size = Vector2(0, G2_LINES_PER_FIELD * G2_LINE_HEIGHT_PX)
		column.add_child(field)

		var labels: Array[Label] = []
		for index in G2_LINES_PER_FIELD:
			var label := Label.new()
			label.name = "%s_Line%d" % [field_id, index + 1]
			label.text = FIELD_LABEL_PLACEHOLDER % field_id if index == 0 else ""
			label.custom_minimum_size = Vector2(
				G2_WIDTH_PX - 2 * G2_BORDER_PX - 2 * G2_PADDING_H_PX,
				G2_LINE_HEIGHT_PX
			)
			field.add_child(label)
			labels.append(label)
		_archive_field_lines[field_id] = labels
