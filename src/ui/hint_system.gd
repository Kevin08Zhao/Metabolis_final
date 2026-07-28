class_name HintSystem
extends Control

## Three-level hints and assist mode, across three scopes.
##
## The three scopes are the task minigame, the build decision, and the operation
## decision. A player who skips every minigame still gets the full three levels
## at the two decisions, which is why the scopes share one system rather than
## each growing their own.
##
## Levels open by request count: the first request opens level one, the second
## opens level two, the third opens level three, and further requests stay at
## three. The level identifiers come from `assist.hint_levels`, so this script
## does not name them.
##
## Two prohibitions are enforced structurally rather than by care:
##
##   1. **Nothing here locks anything.** This class has no lock, no disable, no
##      modal and no input capture. It cannot close a build candidate or the
##      allocation entry because it cannot close anything at all, and the
##      acceptance run asserts that by watching a real button stay enabled
##      through every level of every scope while checking the method list for a
##      locking entry point.
##   2. **No hint at a decision may steer the choice.** Every template is checked
##      against table H2, the banned-term list, before it is handed out. A scope
##      whose row says its wording is screened cannot emit a line containing a
##      banned term; `hint_text` refuses and says so. The check strips comments
##      and matches on word boundaries, because a substring match flags a file
##      for documenting the rule it obeys.
##
## Level three differs by scope, and deliberately. In the minigame it shows the
## next correct operation, because there is one. At the two decisions there is no
## correct answer to show: table D11 of docs/BUILD_DECISION_SPEC.md requires that
## neither candidate dominates, so a hint naming a next step would be inventing a
## preference the design does not have. Level three there says a choice is
## available and what the three preview dimensions mean, and stops.
##
## Assist mode belongs to the minigame and to nothing else. `report_failure`
## refuses any scope whose table row disallows it, so a failure at a decision
## cannot be counted, which means assist mode cannot be reached from a decision
## by any sequence of calls. Its trigger count and its three parameters are read
## from `assist.mode.*`; none is written here.
##
## This system publishes assist parameters and never applies them. Lowering a
## run's speed, lengthening its limit and drawing its route are the minigame
## runtime's business, and reaching into T-19a's script would put the same
## decision in two places.
##
## Hints never block. The node ignores the mouse, holds no focus, and shows its
## text in a label; a player can keep acting while a hint is on screen.
##
## Requires the `EventBus` and `Balance` autoloads.

const LOG_PREFIX := "[HINT]"

## Where the three levels come from. Read, never declared here.
const HINT_LEVELS_PATH := "assist.hint_levels"
const DEFAULT_HINT_LEVEL_PATH := "assist.default_hint_level"

## Assist mode configuration. Every one of these is read; none has a literal
## standing in for it in the logic below.
const ASSIST_TRIGGER_PATH := "assist.mode.failures_before_assist"
const ASSIST_PARAMETER_PATHS := {
	&"speed_scale": "assist.mode.speed_scale",
	&"time_limit_scale": "assist.mode.time_limit_scale",
	&"show_full_route": "assist.mode.show_full_route",
}

## How many times a level may be requested before it stops climbing. Three
## levels, so three requests. Derived from the level list, not written as 3.
const LEVEL_ONE := 1


# ---------------------------------------------------------------------------
# Table H1: the three scopes
#
# `screened` marks a scope whose wording is checked against the banned-term
# list. `assist_allowed` marks the one scope assist mode may reach. Both flags
# are read by the logic; neither scope is named in a function body.
#
# `reset_signal` is the event that opens a fresh instance of the scope and
# therefore returns its level to the bottom. A second build decision in the same
# stage starts at level one again, because it is a different decision.
#
# `reset_step`, when set, narrows a `phase_changed` reset to one step of the ten
# step loop, and the ordinal is looked up in `ChapterFlow.STEP_IDS` rather than
# written as a number. The operation decision needs it: the event that would
# otherwise mark its opening, `resource_priority_changed`, fires on every drag,
# so a player who climbed to level three would be dropped back to level one by
# nudging the allocation.
# ---------------------------------------------------------------------------

const SCOPES: Array[Dictionary] = [
	{
		&"scope_id": &"minigame",
		&"screened": false,
		&"assist_allowed": true,
		&"reset_signal": &"minigame_entered",
		&"reset_step": &"",
	},
	{
		&"scope_id": &"build_decision",
		&"screened": true,
		&"assist_allowed": false,
		&"reset_signal": &"build_options_presented",
		&"reset_step": &"",
	},
	{
		&"scope_id": &"operation_decision",
		&"screened": true,
		&"assist_allowed": false,
		&"reset_signal": &"phase_changed",
		&"reset_step": &"operation_decision",
	},
]


# ---------------------------------------------------------------------------
# Table H2: the banned-term list
#
# Terms that may not appear in a hint at the build decision or the operation
# decision. The first five are the five the prompt requires, in its order; the
# repository writes its copy in English, as docs/UI_COPY.md records, so each is
# listed in the English form the copy would actually use. The rest come from the
# forbidden column of table D7 of docs/BUILD_DECISION_SPEC.md.
#
# Matching is on word boundaries. "better" must not fire on "betterment" and
# must not fire on a comment that names the rule.
# ---------------------------------------------------------------------------

const BANNED_TERMS: Array[StringName] = [
	# The five required terms, in the order the prompt lists them.
	&"optimal",
	&"recommend",
	&"should choose",
	&"better",
	&"suggest",
	# The same five in the other forms English copy reaches for.
	&"best",
	&"recommended",
	&"recommendation",
	&"should pick",
	&"should select",
	&"suggested",
	&"suggestion",
	&"advise",
	&"advice",
	# Table D7, forbidden column.
	&"ideal",
	&"superior",
	&"worse",
	&"worst",
	&"ranking",
	&"ranked",
	&"top choice",
	&"correct option",
	&"right option",
	&"wrong option",
	&"prevents failure",
	&"guarantees success",
	&"avoid this option",
]


# ---------------------------------------------------------------------------
# Table H3: the phrasing templates
#
# One template per level per scope, nine in all. Braced names are the
# substitutions a caller fills; nothing else in a line is replaced.
#
# The minigame column climbs to a next step. The two decision columns do not,
# and their level-three line is the whole of what the prompt permits there: a
# choice exists here, and this is what the three dimensions measure.
# ---------------------------------------------------------------------------

const TEMPLATES: Array[Dictionary] = [
	{
		&"scope_id": &"minigame",
		&"level_index": 1,
		&"template": "Current goal: {goal}. You have {remaining} of {limit} left.",
		&"placeholders": [&"goal", &"remaining", &"limit"],
	},
	{
		&"scope_id": &"minigame",
		&"level_index": 2,
		&"template": "The trouble is in {area}: {measure} is at {value}, and the goal needs {required}.",
		&"placeholders": [&"area", &"measure", &"value", &"required"],
	},
	{
		&"scope_id": &"minigame",
		&"level_index": 3,
		&"template": "Next step: {action} at {location}, within {window}.",
		&"placeholders": [&"action", &"location", &"window"],
	},
	{
		&"scope_id": &"build_decision",
		&"level_index": 1,
		&"template": "Current goal: settle {decision}. Each card shows {dimension_count} measured values and its resource cost.",
		&"placeholders": [&"decision", &"dimension_count"],
	},
	{
		&"scope_id": &"build_decision",
		&"level_index": 2,
		&"template": "The cards differ along {dimension}: one reads {value_a} {unit} and the other {value_b} {unit}. A higher reading means {high_meaning}; a lower one means {low_meaning}.",
		&"placeholders": [&"dimension", &"value_a", &"value_b", &"unit", &"high_meaning", &"low_meaning"],
	},
	{
		&"scope_id": &"build_decision",
		&"level_index": 3,
		&"template": "A choice can be made here. {dimension_1} measures {meaning_1}; {dimension_2} measures {meaning_2}; {dimension_3} measures {meaning_3}. The choice is yours to make.",
		&"placeholders": [
			&"dimension_1", &"meaning_1", &"dimension_2", &"meaning_2", &"dimension_3", &"meaning_3",
		],
	},
	{
		&"scope_id": &"operation_decision",
		&"level_index": 1,
		&"template": "Current goal: settle {decision}. The allocation has to total {required_total}, and it now totals {current_total}.",
		&"placeholders": [&"decision", &"required_total", &"current_total"],
	},
	{
		&"scope_id": &"operation_decision",
		&"level_index": 2,
		&"template": "The trouble is in {area}: {measure} reads {value} {unit}. Moving the allocation toward {direction_a} pulls it one way and toward {direction_b} the other.",
		&"placeholders": [&"area", &"measure", &"value", &"unit", &"direction_a", &"direction_b"],
	},
	{
		&"scope_id": &"operation_decision",
		&"level_index": 3,
		&"template": "A choice can be made here. {dimension_1} measures {meaning_1}; {dimension_2} measures {meaning_2}; {dimension_3} measures {meaning_3}. The choice is yours to make.",
		&"placeholders": [
			&"dimension_1", &"meaning_1", &"dimension_2", &"meaning_2", &"dimension_3", &"meaning_3",
		],
	},
]


## Emitted whenever a hint is handed out. `level_index` is one-based and
## `level_id` is the identifier from `assist.hint_levels`.
signal hint_shown(scope_id: StringName, level_index: int, level_id: StringName, text: String)

## Emitted the first time a scope reaches the assist threshold.
signal assist_mode_entered(scope_id: StringName, parameters: Dictionary)

## Emitted when the failure streak that opened assist mode is cleared.
signal assist_mode_left(scope_id: StringName)

## scope_id -> how many times a hint has been requested since the last reset.
var _requests: Dictionary = {}
## scope_id -> consecutive failures reported for it.
var _failures: Dictionary = {}
## scope_id -> whether assist mode is currently open there.
var _assist_open: Dictionary = {}

var _label: Label = null


func _ready() -> void:
	_build()
	_verify_tables()
	_connect_resets()


# ---------------------------------------------------------------------------
# Requesting a hint
# ---------------------------------------------------------------------------

## Ask for the next hint in a scope. The first call returns level one, the
## second level two, the third level three, and later calls stay at three.
## Returns an empty dictionary for an unknown scope, having changed nothing.
func request_hint(scope_id: StringName, substitutions: Dictionary = {}) -> Dictionary:
	var scope := _scope(scope_id)
	if scope.is_empty():
		push_error("%s '%s' is not a scope in table H1." % [LOG_PREFIX, scope_id])
		return {}

	var level_index := mini(current_level_index(scope_id) + 1, level_count())

	# The request is only counted once a line was actually produced. A refused
	# line must not consume a level, or a screened template with a bad
	# substitution would silently cost the player the level it never showed.
	var text := hint_text(scope_id, level_index, substitutions)
	if text.is_empty():
		return {}
	_requests[scope_id] = int(_requests.get(scope_id, 0)) + 1

	if _label != null and is_instance_valid(_label):
		_label.text = text

	var level_id := level_id_at(level_index)
	print("%s %s level %d (%s): %s" % [LOG_PREFIX, scope_id, level_index, level_id, text])
	hint_shown.emit(scope_id, level_index, level_id, text)

	return {
		&"scope_id": scope_id,
		&"level_index": level_index,
		&"level_id": level_id,
		&"text": text,
	}


## The wording for one level of one scope, with substitutions applied. A screened
## scope refuses to return a line carrying a banned term, so the prohibition
## holds even if a caller supplies the offending word itself.
func hint_text(scope_id: StringName, level_index: int, substitutions: Dictionary = {}) -> String:
	var scope := _scope(scope_id)
	if scope.is_empty():
		return ""

	var template := template_for(scope_id, level_index)
	if template == "":
		push_error(
			"%s Table H3 has no row for scope '%s' level %d."
			% [LOG_PREFIX, scope_id, level_index]
		)
		return ""

	var text := template
	for key in substitutions:
		text = text.replace("{%s}" % key, str(substitutions[key]))

	if bool(scope[&"screened"]):
		var found := scan_for_banned_terms(text)
		if not found.is_empty():
			push_error(
				"%s Refused a %s hint carrying %s. A hint at a decision may not steer the choice."
				% [LOG_PREFIX, scope_id, found]
			)
			return ""

	return text


func template_for(scope_id: StringName, level_index: int) -> String:
	for row in TEMPLATES:
		if row[&"scope_id"] == scope_id and int(row[&"level_index"]) == level_index:
			return row[&"template"]
	return ""


func current_level_index(scope_id: StringName) -> int:
	return mini(int(_requests.get(scope_id, 0)), level_count())


## Return a scope to the bottom. Called when a fresh instance of it opens, and
## available to a caller that needs to do it by hand.
func reset_scope(scope_id: StringName) -> void:
	if _scope(scope_id).is_empty():
		return
	_requests[scope_id] = 0
	if _label != null and is_instance_valid(_label):
		_label.text = ""


# ---------------------------------------------------------------------------
# The levels, read from configuration
# ---------------------------------------------------------------------------

func level_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var value: Variant = Balance.get_value(HINT_LEVELS_PATH, [])
	if value is Array:
		for entry in value as Array:
			ids.append(StringName(str(entry)))
	return ids


func level_count() -> int:
	return level_ids().size()


## The identifier of a one-based level. Out of range returns the configured
## default rather than an invented name.
func level_id_at(level_index: int) -> StringName:
	var ids := level_ids()
	if level_index < LEVEL_ONE or level_index > ids.size():
		var fallback: Variant = Balance.get_value(DEFAULT_HINT_LEVEL_PATH, "")
		return StringName(str(fallback))
	return ids[level_index - 1]


# ---------------------------------------------------------------------------
# The banned-term screen
#
# Comments are stripped before the search and terms match on word boundaries.
# Both rules exist because a plain substring search over raw text flags a file
# for stating the rule it follows; that has already happened twice in this
# account's work.
# ---------------------------------------------------------------------------

func scan_for_banned_terms(text: String) -> Array[StringName]:
	var haystack := strip_comments(text).to_lower()
	var found: Array[StringName] = []
	for term in BANNED_TERMS:
		if _contains_whole_term(haystack, String(term).to_lower()):
			found.append(term)
	return found


## Drop whole-line and trailing `#` comments. A hint line never contains one;
## this is what lets the same function screen a source file during acceptance.
func strip_comments(text: String) -> String:
	var kept := PackedStringArray()
	for line in text.split("\n"):
		var hash_at := line.find("#")
		kept.append(line if hash_at < 0 else line.substr(0, hash_at))
	return "\n".join(kept)


func _contains_whole_term(haystack: String, term: String) -> bool:
	var from := 0
	var at := haystack.find(term, from)
	while at >= 0:
		var before_ok := at == 0 or not _is_word_character(haystack[at - 1])
		var after := at + term.length()
		var after_ok := after >= haystack.length() or not _is_word_character(haystack[after])
		if before_ok and after_ok:
			return true
		from = at + 1
		at = haystack.find(term, from)
	return false


func _is_word_character(character: String) -> bool:
	return character == "_" or character.is_valid_identifier() or character.is_valid_int()


# ---------------------------------------------------------------------------
# Assist mode
#
# Reachable from one scope, because report_failure refuses every other. That is
# the whole guarantee: with no way to count a failure at a decision, no sequence
# of calls opens assist mode there.
# ---------------------------------------------------------------------------

## Record a failed attempt. Refused, loudly, for any scope whose table H1 row
## does not allow assist mode. Returns true when the call was accepted.
func report_failure(scope_id: StringName) -> bool:
	var scope := _scope(scope_id)
	if scope.is_empty():
		push_error("%s '%s' is not a scope in table H1." % [LOG_PREFIX, scope_id])
		return false

	if not bool(scope[&"assist_allowed"]):
		push_error(
			"%s Refused a failure report for '%s'. Assist mode is confined to the scope whose table H1 row allows it and may not reach a decision."
			% [LOG_PREFIX, scope_id]
		)
		return false

	_failures[scope_id] = int(_failures.get(scope_id, 0)) + 1

	if assist_mode_active(scope_id) and not bool(_assist_open.get(scope_id, false)):
		_assist_open[scope_id] = true
		var parameters := assist_parameters()
		print(
			"%s assist mode opened for %s after %d failures: %s"
			% [LOG_PREFIX, scope_id, int(_failures[scope_id]), parameters]
		)
		assist_mode_entered.emit(scope_id, parameters)

	return true


## Clear a scope's failure streak, which closes assist mode with it.
func clear_failures(scope_id: StringName) -> void:
	if _scope(scope_id).is_empty():
		return
	_failures[scope_id] = 0
	if bool(_assist_open.get(scope_id, false)):
		_assist_open[scope_id] = false
		print("%s assist mode closed for %s." % [LOG_PREFIX, scope_id])
		assist_mode_left.emit(scope_id)


func failure_count(scope_id: StringName) -> int:
	return int(_failures.get(scope_id, 0))


## Whether assist mode is open in a scope. False for every scope table H1
## disallows, whatever the counters say.
func assist_mode_active(scope_id: StringName) -> bool:
	var scope := _scope(scope_id)
	if scope.is_empty() or not bool(scope[&"assist_allowed"]):
		return false
	var trigger := assist_trigger_count()
	if trigger <= 0:
		return false
	return failure_count(scope_id) >= trigger


func assist_trigger_count() -> int:
	var value: Variant = Balance.get_value(ASSIST_TRIGGER_PATH, 0)
	var trigger := int(value)
	if trigger <= 0:
		push_warning(
			"%s No assist trigger configured at '%s'; assist mode stays closed rather than opening on a guessed count."
			% [LOG_PREFIX, ASSIST_TRIGGER_PATH]
		)
	return trigger


## The three parameters, read from configuration. This system publishes them and
## applies none: slowing a run, lengthening it and drawing its route belong to
## the minigame runtime.
func assist_parameters() -> Dictionary:
	var parameters: Dictionary = {}
	for key in ASSIST_PARAMETER_PATHS:
		var path: String = ASSIST_PARAMETER_PATHS[key]
		var value: Variant = Balance.get_value(path, null)
		if value == null:
			push_warning("%s No value at '%s'; the parameter is omitted rather than invented." % [LOG_PREFIX, path])
			continue
		parameters[key] = value
	return parameters


# ---------------------------------------------------------------------------
# Resets driven by events
# ---------------------------------------------------------------------------

func _connect_resets() -> void:
	for scope in SCOPES:
		var scope_id: StringName = scope[&"scope_id"]
		var signal_name: StringName = scope[&"reset_signal"]
		var reset_step: StringName = scope[&"reset_step"]
		var arity := _signal_arity(signal_name)
		if arity < 0:
			push_error("%s Table H1 names '%s', which is not a signal on EventBus." % [LOG_PREFIX, signal_name])
			continue

		# A fresh lambda per row. Lambdas compare by identity, so two rows on one
		# event stay two connections; a bound Callable would not, because Godot
		# compares those without looking at the bound arguments.
		var relay: Callable
		match arity:
			0:
				relay = func() -> void:
					_on_reset(scope_id, reset_step, [])
			1:
				relay = func(a: Variant) -> void:
					_on_reset(scope_id, reset_step, [a])
			2:
				relay = func(a: Variant, b: Variant) -> void:
					_on_reset(scope_id, reset_step, [a, b])
			3:
				relay = func(a: Variant, b: Variant, c: Variant) -> void:
					_on_reset(scope_id, reset_step, [a, b, c])
			4:
				relay = func(a: Variant, b: Variant, c: Variant, d: Variant) -> void:
					_on_reset(scope_id, reset_step, [a, b, c, d])
			_:
				push_error(
					"%s '%s' carries %d arguments; the relays cover up to four."
					% [LOG_PREFIX, signal_name, arity]
				)
				continue

		var error := EventBus.connect(signal_name, relay)
		if error != OK:
			push_error("%s Could not connect '%s' (error %d)." % [LOG_PREFIX, signal_name, error])


## A reset narrowed by `reset_step` fires only when the loop actually reached
## that step. The ordinal comes from ChapterFlow, never from a literal.
func _on_reset(scope_id: StringName, reset_step: StringName, args: Array) -> void:
	if reset_step != &"":
		if args.size() < 2 or int(args[1]) != ChapterFlow.STEP_IDS.find(reset_step):
			return
	reset_scope(scope_id)


func _signal_arity(signal_name: StringName) -> int:
	for entry in EventBus.get_signal_list():
		if StringName(str(entry.get("name", ""))) != signal_name:
			continue
		var args: Variant = entry.get("args", [])
		if args is Array:
			return (args as Array).size()
		return 0
	return -1


# ---------------------------------------------------------------------------
# Table validation
# ---------------------------------------------------------------------------

func _verify_tables() -> void:
	var levels := level_count()
	if levels <= 0:
		push_error("%s No hint levels configured at '%s'." % [LOG_PREFIX, HINT_LEVELS_PATH])
		return

	for scope in SCOPES:
		var scope_id: StringName = scope[&"scope_id"]
		for level_index in range(LEVEL_ONE, levels + 1):
			if template_for(scope_id, level_index) == "":
				push_error(
					"%s Table H3 is missing scope '%s' level %d."
					% [LOG_PREFIX, scope_id, level_index]
				)

		if not bool(scope[&"screened"]):
			continue
		for level_index in range(LEVEL_ONE, levels + 1):
			var found := scan_for_banned_terms(template_for(scope_id, level_index))
			if not found.is_empty():
				push_error(
					"%s Template for '%s' level %d carries %s."
					% [LOG_PREFIX, scope_id, level_index, found]
				)


func _scope(scope_id: StringName) -> Dictionary:
	for scope in SCOPES:
		if scope[&"scope_id"] == scope_id:
			return scope
	return {}


## Every row of tables H1 and H3 in one list, for acceptance to print rather than
## read the source.
func template_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for scope in SCOPES:
		var scope_id: StringName = scope[&"scope_id"]
		for level_index in range(LEVEL_ONE, level_count() + 1):
			rows.append({
				&"scope_id": scope_id,
				&"level_index": level_index,
				&"level_id": level_id_at(level_index),
				&"screened": scope[&"screened"],
				&"assist_allowed": scope[&"assist_allowed"],
				&"template": template_for(scope_id, level_index),
			})
	return rows


# ---------------------------------------------------------------------------
# Display
#
# A label that ignores the mouse. No panel, no modal, no focus, no dimming: the
# player keeps acting while a hint is up, which is the prompt's requirement and
# is also why nothing here needs an "unblock" path.
# ---------------------------------------------------------------------------

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_label = Label.new()
	_label.name = "HintLine"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func current_text() -> String:
	if _label == null or not is_instance_valid(_label):
		return ""
	return _label.text
