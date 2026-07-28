class_name ChapterSummary
extends Control

## The chapter summary screen.
##
## It opens when a stage finishes, stops the world while the player reads, and
## closes on demand. Reading time is not operation time: the settlement gate
## below withholds every second the screen is up, so a long read cannot be
## charged to the player afterwards.
##
## The screen is size-locked. Art fixed the geometry in docs/UI_LAYOUT.md table
## G3, and every pixel figure in this file is transcribed from that table rather
## than chosen here. Overflow therefore truncates and prints a `[UI]` line naming
## the offending item. It never shrinks the font, never scrolls, never paginates,
## and never adds a seventh item, because each of those would quietly break the
## size lock instead of reporting it.
##
## Every string is a bracketed placeholder. T-31 owns the real copy.
##
## ---------------------------------------------------------------------------
## The six items and where each stage's content comes from
## ---------------------------------------------------------------------------
##
## The six slots are categories, fixed by table G3 and by the T-30a prompt. They
## are the same six in every stage; what changes is the content poured into them.
##
## | Item | Stage One (origin) | Stage Two (harbor) | Stage Three (circulation) | Stage Four (birth) |
## |---|---|---|---|---|
## | 1 current stage | stage_origin, week 1 | stage_harbor, weeks 2-3 | stage_circulation, weeks 4-8 | stage_birth, weeks 9-38 |
## | 2 structures formed | zygote, blastomeres, morula, blastocyst precursor | blastocyst positioning, placental foundation, ectoderm, mesoderm, endoderm | heart, early vessels, neural tube, brain and spinal-cord foundation; background organs | pulmonary gas-exchange region, pulmonary-circulation interface |
## | 3 new system connection | build_cell_cluster record | build_placenta_port and build_germ_layer_districts records | build_heart_pump and build_neural_network records | build_lung_exchange and build_pulmonary_interface records |
## | 4 three knowledge points | Section Eighteen item 1 | Section Eighteen items 2 and 3 | Section Eighteen items 4, 5, 6 | Section Eighteen items 7, 8, 9 |
## | 5 before/after change | construction-zone visual for the stage | construction-zone visual across both subphases | construction-zone visual for the stage | construction-zone visual for the stage |
## | 6 new encyclopedia | entries unlocked in the stage | entries unlocked in the stage | entries unlocked in the stage | entries unlocked in the stage |
##
## Item 3 is never written here. It is derived from the confirmed build-decision
## records, so two players who built differently read different text. See
## compose_system_connection_lines().
##
## ---------------------------------------------------------------------------
## How stage two fits two content groups into six items
## ---------------------------------------------------------------------------
##
## docs/CHAPTER_TIMELINE.md gives stage two two internal phases, the placenta
## phase and the germ-layer phase, and fixes six content facts it must convey:
## blastocyst positioning, the placental foundation, the transport-priority
## settlement, and the three germ layers. Those six facts are not six slots. They
## are distributed across the same six categories every other stage uses.
##
## Three categories carry only one group:
##   item 1 names the one stage node, `stage_harbor`, for both phases together;
##   item 4 spends its three knowledge points across both Section Eighteen items;
##   item 6 lists whatever unlocked, from either phase.
##
## Two categories are shared, and they are where the doubling actually lands:
##   item 2 holds the placental foundation and all three germ layers at once;
##   item 3 holds both build-decision records, `build_placenta_port` and
##   `build_germ_layer_districts`.
##
## Item 5 is shared in a weaker sense: the construction-zone visual runs across
## both subphases at one map node, so the before/after pair spans them.
##
## Everything past those six facts - chorionic villi, amnion, yolk sac, primitive
## streak, later germ-layer differentiation - is construction-archive material.
## It does not appear here and it does not earn a seventh item.

const LOG_PREFIX := "[UI]"

# ---------------------------------------------------------------------------
# Table G3 - chapter summary capacity
# docs/UI_LAYOUT.md section 7. Transcribed, not chosen.
# ---------------------------------------------------------------------------

const G3_WIDTH_PX := 544
const G3_HEIGHT_PX := 304
const G3_BORDER_PX := 2
const G3_PADDING_H_PX := 12
const G3_PADDING_V_PX := 8
const G3_HEADER_PX := 20
const G3_HEADER_GAP_PX := 4
const G3_ITEM_GAP_PX := 4
const G3_FONT_PX := 8
const G3_LINE_HEIGHT_PX := 10
const G3_ITEM_COUNT := 6
const G3_LINES_PER_ITEM := 4
const G3_MAX_LINES_TOTAL := 24
const G3_MAX_CHARS_PER_LINE := 64

## The six slots, top to bottom. Unlike table G2, which numbers its fields and
## stops, table G3 names all six, so these identifiers are transcription rather
## than invention. The order is the reading order and may not be rearranged.
const G3_ITEM_IDS: Array[StringName] = [
	&"g3_1_current_stage",
	&"g3_2_structures_formed",
	&"g3_3_system_connection",
	&"g3_4_knowledge_points",
	&"g3_5_city_change",
	&"g3_6_encyclopedia",
]

## The two slots that carry both of stage two's content groups. Named here rather
## than left to a comment so an acceptance run can check the claim instead of
## trusting the prose above.
const STAGE_TWO_SHARED_ITEM_IDS: Array[StringName] = [
	&"g3_2_structures_formed",
	&"g3_3_system_connection",
]

## Table G3 item 4 is three core knowledge points, not "some". The count is
## fixed; the label shares the same four-line allocation.
const KNOWLEDGE_POINT_COUNT := 3

## Placeholder copy. All of it belongs to T-31.
const SUMMARY_HEADER_PLACEHOLDER := "[summary:%s]"
const ITEM_LABEL_PLACEHOLDER := "[item:%s]"
const ITEM_EMPTY_PLACEHOLDER := "[empty]"
## Kept deliberately terse. The decision, option, and slot identifiers on this
## line are locked elsewhere and can be long - `build_germ_layer_districts` alone
## is 26 characters - so scaffolding here is charged directly against the
## 64-character line budget. A wordier wrapper pushed the stage two germ-layer
## line to 67 characters and truncated it. The nine characters below leave 55 for
## the three identifiers; the decision id leads so that it survives any cut.
const CONNECTION_LINE_PLACEHOLDER := "[conn:%s>%s@%s]"
const CONNECTION_NONE_PLACEHOLDER := "[conn:none]"
const KNOWLEDGE_POINT_PLACEHOLDER := "[point%d:%s]"
const KNOWLEDGE_POINT_MISSING_PLACEHOLDER := "[point%d:missing]"

## Shown for the whole time the summary holds the game. Table G3's header carries
## a two-bar pause symbol; art forbids an invisible pause state, so this label is
## the code-side guarantee that something is always on screen while paused.
const PAUSE_INDICATOR_PLACEHOLDER := "[paused] Operation time and resource settlement are stopped."

signal summary_opened(stage_id: StringName, reviewed: bool)
signal summary_closed(stage_id: StringName)

var _root: PanelContainer = null
var _header: Label = null
var _pause_indicator: Label = null
var _item_lines: Dictionary = {}
var _stage_id: StringName = &""

## Content is kept per stage after close so the chapter review entry can reopen a
## summary the player already dismissed, without the caller having to rebuild it.
var _archived_content: Dictionary = {}
var _seen_stage_ids: Dictionary = {}

var _paused := false
var _tree_paused_before := false

## Counts the seconds this gate has swallowed while the summary was open. It has
## no gameplay effect; it exists so an acceptance run can prove that settlement
## time was withheld rather than merely that the screen stopped moving.
var _withheld_seconds := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The summary itself must keep responding while it holds the tree paused,
	# otherwise the close it is waiting for could never arrive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


# ---------------------------------------------------------------------------
# Opening and closing
# ---------------------------------------------------------------------------

## Open the summary for one stage. `content` maps the six G3 item ids to their
## placeholder lines; an item the caller omits shows the empty placeholder rather
## than borrowing another item's lines.
##
## Opening pauses operation time and resource settlement and raises the pause
## indicator. Both stay that way until close().
func open(stage_id: StringName, content: Dictionary) -> bool:
	if stage_id == &"" or _stage_id != &"":
		return false

	_archived_content[stage_id] = content.duplicate(true)
	var reviewed: bool = _seen_stage_ids.has(stage_id)
	_seen_stage_ids[stage_id] = true
	_present(stage_id, content, reviewed)
	return true


## Reopen a stage the player already closed, from the chapter review entry. Uses
## the content archived at the original open; a stage never opened cannot be
## reviewed and returns false.
func reopen(stage_id: StringName) -> bool:
	if stage_id == &"" or _stage_id != &"":
		return false
	if not _archived_content.has(stage_id):
		print("%s chapter summary '%s' has no archived content to review." % [LOG_PREFIX, stage_id])
		return false

	var content: Dictionary = _archived_content[stage_id]
	_present(stage_id, content, true)
	return true


## Close the summary and resume. Available at any time; nothing about the screen
## requires the player to read to the end.
func close() -> bool:
	if _stage_id == &"":
		return false

	var closed := _stage_id
	_stage_id = &""
	_root.visible = false
	_set_paused(false)

	print("%s chapter summary '%s' closed; the game resumes." % [LOG_PREFIX, closed])
	summary_closed.emit(closed)
	return true


func is_open() -> bool:
	return _stage_id != &""


func current_stage_id() -> StringName:
	return _stage_id


## Whether a stage has an archived summary the review entry can reopen.
func can_review(stage_id: StringName) -> bool:
	return _archived_content.has(stage_id)


## What one G3 slot currently reads, after truncation.
func item_lines(item_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not _item_lines.has(item_id):
		return out
	for label in _item_lines[item_id] as Array:
		out.append((label as Label).text)
	return out


func _present(stage_id: StringName, content: Dictionary, reviewed: bool) -> void:
	_stage_id = stage_id
	_header.text = SUMMARY_HEADER_PLACEHOLDER % stage_id

	for item_id in G3_ITEM_IDS:
		var supplied: Variant = content.get(item_id, null)
		var lines := _as_lines(supplied)
		var fitted := _fit(
			lines,
			G3_LINES_PER_ITEM,
			G3_MAX_CHARS_PER_LINE,
			"chapter summary '%s' item %s" % [stage_id, item_id]
		)
		var labels: Array = _item_lines[item_id]
		for index in G3_LINES_PER_ITEM:
			var label: Label = labels[index]
			if index < fitted.size():
				label.text = fitted[index]
			elif index == 0:
				label.text = ITEM_EMPTY_PLACEHOLDER
			else:
				label.text = ""

	_root.visible = true
	_set_paused(true)

	print("%s chapter summary '%s' opened; the game is paused." % [LOG_PREFIX, stage_id])
	summary_opened.emit(stage_id, reviewed)


# ---------------------------------------------------------------------------
# Item 3 - the new system connection
#
# The one item whose text depends on how the player built. Writing it as a
# constant would make every run read the same, which is the specific thing the
# prompt forbids, so it is composed from the confirmed build-decision records.
# ---------------------------------------------------------------------------

## Build item 3's lines from confirmed build-decision records. `records` is the
## `confirmed_decisions` dictionary of `BuildDecision`, keyed by decision id; each
## record carries `selected_candidate_id` and `selected_slot_id`, and one line is
## produced per record so a stage with two build decisions reads differently from
## a stage with one.
##
## Records are read in the file's decision order, which is insertion order, so
## the reading order matches the order the player confirmed them.
func compose_system_connection_lines(records: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(ITEM_LABEL_PLACEHOLDER % G3_ITEM_IDS[2])

	for decision_id in records:
		var record: Variant = records[decision_id]
		if not record is Dictionary:
			continue
		var fields: Dictionary = record
		var option_id: Variant = fields.get("selected_candidate_id", &"")
		var slot_id: Variant = fields.get("selected_slot_id", &"")
		out.append(CONNECTION_LINE_PLACEHOLDER % [
			str(decision_id),
			str(option_id),
			str(slot_id),
		])

	if out.size() == 1:
		out.append(CONNECTION_NONE_PLACEHOLDER)
	return out


## Build item 4's lines. Table G3 gives the item four lines and the label takes
## one, which leaves exactly three - the same three the item is named for. A
## caller that supplies more is reported here rather than silently cut later.
func compose_knowledge_point_lines(points: PackedStringArray) -> PackedStringArray:
	if points.size() > KNOWLEDGE_POINT_COUNT:
		print("%s chapter summary knowledge points overrun: %d given, %d allowed. The extra points are cut."
			% [LOG_PREFIX, points.size(), KNOWLEDGE_POINT_COUNT])

	var out := PackedStringArray()
	out.append(ITEM_LABEL_PLACEHOLDER % G3_ITEM_IDS[3])
	for index in KNOWLEDGE_POINT_COUNT:
		if index < points.size():
			out.append(KNOWLEDGE_POINT_PLACEHOLDER % [index + 1, points[index]])
		else:
			out.append(KNOWLEDGE_POINT_MISSING_PLACEHOLDER % (index + 1))
	return out


# ---------------------------------------------------------------------------
# The pause
#
# Two mechanisms, because the requirement has two halves. The scene tree pause
# stops timers and every node that processes. The settlement gate below stops the
# resource loop, which is driven by an explicit elapsed-seconds argument and
# would otherwise be handed the whole paused interval in one lump the moment the
# summary closed - the exact failure the acceptance has to be able to rule out.
# ---------------------------------------------------------------------------

## The seam a tick driver calls instead of using its own delta. While the summary
## is open this returns zero and the elapsed time is discarded, not banked.
func elapsed_for_settlement(delta: float) -> float:
	if _paused:
		_withheld_seconds += delta
		return 0.0
	return delta


func is_paused() -> bool:
	return _paused


## Total simulated seconds refused while the summary was open. An acceptance run
## compares this against unchanged resource totals: the pair together shows that
## settlement stopped and did not silently catch up afterwards.
func withheld_seconds() -> float:
	return _withheld_seconds


func pause_indicator_visible() -> bool:
	return _pause_indicator != null and _pause_indicator.visible


func _set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	_pause_indicator.visible = paused

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

## Cut `lines` down to the table's capacity and report every cut. Two limits
## apply independently: too many lines, and any single line too long. Both are
## reported by name so a `[UI]` line identifies which item overran and how.
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
# Sizes come from table G3 and are applied as minimum sizes on the container
# itself. This file writes pixel figures because the table says it must.
# ---------------------------------------------------------------------------

func _build() -> void:
	_root = PanelContainer.new()
	_root.name = "ChapterSummary"
	_root.custom_minimum_size = Vector2(G3_WIDTH_PX, G3_HEIGHT_PX)
	_root.size = Vector2(G3_WIDTH_PX, G3_HEIGHT_PX)
	_root.visible = false
	add_child(_root)

	var column := VBoxContainer.new()
	column.name = "SummaryBody"
	column.add_theme_constant_override("separation", G3_ITEM_GAP_PX)
	_root.add_child(column)

	var header_row := HBoxContainer.new()
	header_row.name = "SummaryHeader"
	header_row.custom_minimum_size = Vector2(0, G3_HEADER_PX)
	column.add_child(header_row)

	_header = Label.new()
	_header.name = "HeaderTitle"
	_header.text = SUMMARY_HEADER_PLACEHOLDER % "pending"
	header_row.add_child(_header)

	_pause_indicator = Label.new()
	_pause_indicator.name = "PauseIndicator"
	_pause_indicator.text = PAUSE_INDICATOR_PLACEHOLDER
	_pause_indicator.visible = false
	header_row.add_child(_pause_indicator)

	var gap := Control.new()
	gap.name = "HeaderGap"
	gap.custom_minimum_size = Vector2(0, G3_HEADER_GAP_PX)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	for item_id in G3_ITEM_IDS:
		var item := VBoxContainer.new()
		item.name = "Item_%s" % item_id
		item.custom_minimum_size = Vector2(0, G3_LINES_PER_ITEM * G3_LINE_HEIGHT_PX)
		column.add_child(item)

		var labels: Array[Label] = []
		for index in G3_LINES_PER_ITEM:
			var label := Label.new()
			label.name = "%s_Line%d" % [item_id, index + 1]
			label.text = ITEM_LABEL_PLACEHOLDER % item_id if index == 0 else ""
			label.custom_minimum_size = Vector2(
				G3_WIDTH_PX - 2 * G3_BORDER_PX - 2 * G3_PADDING_H_PX,
				G3_LINE_HEIGHT_PX
			)
			item.add_child(label)
			labels.append(label)
		_item_lines[item_id] = labels
