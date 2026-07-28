class_name TimelinePanel
extends Control

## Development timeline panel.
##
## The visible carrier of step ten. It shows five things and only five: the
## current developmental time, which stages are finished, which stage is running,
## the next milestone, and birth readiness. The set is fixed by the prompt; a
## sixth reading does not belong here.
##
## It reads and never drives. Stage identity and the stage chain come from
## configuration, birth readiness comes from the table E5 evaluation T-19e
## already performs, and everything else arrives through docs/EVENT_API.md.
##
## Layout is by anchor. docs/UI_LAYOUT.md section 2 places this strip at
## Rect2(0, 16, 640, 8), but that rectangle belongs to whoever assembles the
## scene: this script anchors to the top edge and sets no pixel coordinate, so
## the layout can be retuned in the editor without a code change.
##
## Every string here is a placeholder marked with square brackets. T-31 owns
## docs/UI_COPY.md and supplies the real copy, including the post-fertilization
## week labels from the time-basis table in docs/CHAPTER_TIMELINE.md. This panel
## deliberately invents no week numbers of its own.
##
## Requires the `EventBus` and `Balance` autoloads.

const LOG_PREFIX := "[TIMELINE]"

## The five readings, in display order. Fixed: nothing is added or removed.
const READINGS: Array[StringName] = [
	&"current_time",
	&"completed_stages",
	&"current_stage",
	&"next_milestone",
	&"birth_readiness",
]

## Stage two carries two content groups in one node. Both must be shown; showing
## only one would misrepresent what the stage covers. The identifiers come from
## the stage-two sub-phase table in docs/CHAPTER_TIMELINE.md.
const DUAL_CONTENT_STAGE := &"stage_harbor"
const DUAL_CONTENT_PHASES: Array[StringName] = [
	&"harbor_placenta_phase",
	&"harbor_germ_layers_phase",
]

## Placeholder time labels, keyed by stage. T-31 replaces these with the real
## post-fertilization week strings; the keys are what matters here.
const TIME_LABEL_PLACEHOLDER := "[time:%s]"

## Shown once, the first time the panel displays the opening stage.
## docs/CHAPTER_TIMELINE.md requires the clinical-gestational-age difference to be
## explained there, non-blocking, alongside the stage introduction.
const TIME_BASIS_NOTE := (
	"[time-basis] Post-fertilization developmental time is used throughout. "
	+ "Clinical gestational age is about two weeks greater."
)

signal readings_changed(readings: Dictionary)

## Optional. Supplies the table E5 evaluation; birth readiness is read from its
## report rather than recomputed, because E5 is the only definition of it.
var birth_check: BirthCheck = null

var _current_stage_id: StringName = &""
var _completed: Array[StringName] = []
var _time_basis_shown: bool = false
var _time_basis_visible: bool = false
var _labels: Dictionary = {}
var _note_label: Label = null


func _ready() -> void:
	# Anchored, not positioned. No pixel coordinate is written by this script.
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	_build()
	EventBus.stage_loaded.connect(_on_stage_loaded)
	EventBus.stage_advanced.connect(_on_stage_advanced)
	refresh()


# ---------------------------------------------------------------------------
# The five readings
# ---------------------------------------------------------------------------

## What each reading currently says. Exposed so a caller, or an acceptance run,
## can compare the five against the stage table without scraping labels.
func readings() -> Dictionary:
	return {
		&"current_time": _current_time_text(),
		&"completed_stages": _completed.duplicate(),
		&"current_stage": _current_stage_text(),
		&"next_milestone": _next_milestone_text(),
		&"birth_readiness": _birth_readiness_text(),
	}


func refresh() -> void:
	var values := readings()
	for key in READINGS:
		var label: Label = _labels.get(key)
		if label != null and is_instance_valid(label):
			label.text = "%s: %s" % [key, _as_text(values[key])]
	_refresh_time_basis_note()
	readings_changed.emit(values)


func _current_time_text() -> String:
	if _current_stage_id == &"":
		return "[time:unknown]"
	return TIME_LABEL_PLACEHOLDER % _current_stage_id


## Stage two names both of its content groups. Every other stage names itself.
func _current_stage_text() -> String:
	if _current_stage_id == &"":
		return "[stage:none]"
	if _current_stage_id != DUAL_CONTENT_STAGE:
		return "[stage:%s]" % _current_stage_id
	var parts := PackedStringArray()
	for phase in DUAL_CONTENT_PHASES:
		parts.append(String(phase))
	return "[stage:%s carrying %s]" % [_current_stage_id, ", ".join(parts)]


## The stage after this one, or birth itself when there is none. Read from the
## chain rather than listed here.
func _next_milestone_text() -> String:
	if _current_stage_id == &"":
		return "[milestone:unknown]"
	var value: Variant = Balance.get_value("chapters.%s.next_stage_id" % _current_stage_id, null)
	if value == null:
		return "[milestone:birth]"
	return "[milestone:%s]" % StringName(str(value))


## Read from the table E5 report, never recomputed. Without a BirthCheck the
## panel says so rather than showing a number it made up.
func _birth_readiness_text() -> String:
	var minimum := float(Balance.get_value("birth_check.birth_readiness_min", 0.0))
	if birth_check == null:
		return "[readiness:unavailable, minimum %.2f]" % minimum
	var report := birth_check.last_report
	var values: Variant = report.get("current_values", {})
	if not values is Dictionary or not (values as Dictionary).has(&"birth_readiness"):
		return "[readiness:not yet evaluated, minimum %.2f]" % minimum
	var current := float((values as Dictionary)[&"birth_readiness"])
	return "[readiness:%.2f of minimum %.2f]" % [current, minimum]


# ---------------------------------------------------------------------------
# The time-basis explanation
# ---------------------------------------------------------------------------

## Shown the first time the opening stage is displayed, and only then. It leaves
## when the run moves past that stage, or when a caller dismisses it. It never
## blocks: it is a label in the panel, not a modal.
func _refresh_time_basis_note() -> void:
	var on_first_stage := _current_stage_id != &"" and _current_stage_id == _first_stage_id()
	if on_first_stage and not _time_basis_shown:
		_time_basis_shown = true
		_time_basis_visible = true
		print("%s time-basis explanation shown for %s." % [LOG_PREFIX, _current_stage_id])
	elif not on_first_stage:
		_time_basis_visible = false

	if _note_label != null and is_instance_valid(_note_label):
		_note_label.visible = _time_basis_visible


func dismiss_time_basis_note() -> void:
	_time_basis_visible = false
	if _note_label != null and is_instance_valid(_note_label):
		_note_label.visible = false


func time_basis_note_visible() -> bool:
	return _time_basis_visible


func time_basis_note_already_shown() -> bool:
	return _time_basis_shown


func _first_stage_id() -> StringName:
	var value: Variant = Balance.get_value("progress.initial.current_stage_id", null)
	return &"" if value == null else StringName(str(value))


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_stage_loaded(stage_id: StringName, _stage_index: int) -> void:
	_current_stage_id = stage_id
	refresh()


func _on_stage_advanced(from_stage_id: StringName, _to_stage_id: StringName) -> void:
	if from_stage_id != &"" and not _completed.has(from_stage_id):
		_completed.append(from_stage_id)
	refresh()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var column := VBoxContainer.new()
	column.name = "Readings"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	for key in READINGS:
		var label := Label.new()
		label.name = "Reading_%s" % key
		label.text = "%s: [pending]" % key
		column.add_child(label)
		_labels[key] = label

	_note_label = Label.new()
	_note_label.name = "TimeBasisNote"
	_note_label.text = TIME_BASIS_NOTE
	_note_label.visible = false
	column.add_child(_note_label)


func _as_text(value: Variant) -> String:
	if value is Array:
		var parts := PackedStringArray()
		for entry in value as Array:
			parts.append(String(entry))
		return "[%s]" % ", ".join(parts)
	return str(value)
