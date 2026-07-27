class_name MinigameRuntime
extends Node

## Task minigame runtime.
##
## Provides the six capabilities the three prototypes reuse: entry, timing, goal
## determination, exit, rating settlement, and failure handling. It implements no
## prototype's gameplay. A prototype drives it by reporting progress, asking for a
## hint, or declaring a failure; everything else is this framework's business.
##
## Contracts come from docs/MINIGAME_SPEC.md. Every tunable is read through
## `Balance` at `minigames.*`; nothing about a prototype is written as a literal
## here, including which goal field it counts.
##
## Two boundaries are deliberate and load-bearing:
##
## - The runtime holds no reference to ChapterData, ResourcePool, or the build
##   flow. It cannot write a blocking flag anywhere because it has nowhere to
##   write one. A rating result is offered through `pending_reward()` for the
##   resource settlement step to consume; this script never moves a resource.
## - Failure handling is scoped entirely inside a run. No failure path touches
##   stage progress, organs, or city state.
##
## Requires the `EventBus` and `Balance` autoloads.

enum State {
	IDLE,
	RUNNING,
	SETTLED,
	FAILED,
}

## Mirrors MinigameResolution and MinigameResult in docs/GAME_RULES.md.
## `RESOLUTION_IDS` is the persisted spelling stored in
## `ChapterData.minigame_resolution`; the integer is what
## `minigame_exited` carries.
enum Resolution {
	PENDING,
	SKIPPED,
	COMPLETED,
}

const RESOLUTION_IDS: Array[StringName] = [
	&"pending",
	&"skipped",
	&"completed",
]

## The three spendable resources a reward may contain. Knowledge badges settle
## separately because they are counted, never spent on building.
const SPENDABLE_RESOURCES: Array[StringName] = [
	&"nutrient_energy",
	&"cell_material",
	&"development_signal",
]

const LOG_PREFIX := "[MINIGAME]"

## Emitted when a run ends for any reason, after `minigame_exited`. Carries the
## resolution so a caller can update ChapterData without inspecting this node.
signal run_resolved(minigame_id: StringName, resolution: int)

var _state: int = State.IDLE
var _minigame_id: StringName = &""
var _stage_id: StringName = &""
var _resolution: int = Resolution.PENDING

var _time_limit_sec: float = 0.0
var _elapsed_sec: float = 0.0

var _goal_key: StringName = &""
var _target_units: float = 0.0
var _completed_units: float = 0.0

var _hint_usage_count: int = 0
var _difficulty_tier: StringName = &"base"
var _consecutive_failures: int = 0
var _retries_used: int = 0
var _last_failure_reason: StringName = &""

var _stars: int = 0
var _rating_detail: Dictionary = {}
var _pending_reward: Dictionary = {}


func _ready() -> void:
	# The enum and the configured initial value are two spellings of one state.
	# Warn rather than fail if they drift; the persisted spelling is authoritative.
	var configured := StringName(
		str(Balance.get_value("minigames.runtime.initial_resolution", RESOLUTION_IDS[Resolution.PENDING]))
	)
	if configured != RESOLUTION_IDS[Resolution.PENDING]:
		push_warning(
			"%s minigames.runtime.initial_resolution is '%s' but Resolution.PENDING spells '%s'."
			% [LOG_PREFIX, configured, RESOLUTION_IDS[Resolution.PENDING]]
		)


func _process(delta: float) -> void:
	if _state == State.RUNNING:
		advance_time(delta)


# ---------------------------------------------------------------------------
# 1 · Entry
# ---------------------------------------------------------------------------

## Start a run. `goal_key` may be omitted while a prototype's `goal` block holds
## a single field, which is the case for all three prototypes; the runtime then
## uses whatever that field is called rather than naming it here.
## Returns false and changes nothing when configuration is missing.
func begin(minigame_id: StringName, stage_id: StringName, goal_key: StringName = &"") -> bool:
	if minigame_id == &"":
		push_error("%s Refused to begin a run without a minigame id." % LOG_PREFIX)
		return false

	var config := _minigame_config(minigame_id)
	if config.is_empty():
		push_error("%s No configuration for '%s'; the run was not started." % [LOG_PREFIX, minigame_id])
		return false

	# The eased tier and the failure streak are scoped to one stage.
	if stage_id != _stage_id:
		_difficulty_tier = &"base"
		_consecutive_failures = 0
		_retries_used = 0

	_minigame_id = minigame_id
	_stage_id = stage_id
	_resolution = Resolution.PENDING
	_time_limit_sec = float(config.get("duration_limit_sec", 0.0))
	_elapsed_sec = 0.0
	_completed_units = 0.0
	_hint_usage_count = 0
	_last_failure_reason = &""
	_stars = 0
	_rating_detail = {}
	_pending_reward = {}

	_goal_key = goal_key if goal_key != &"" else _sole_goal_key(config)
	_target_units = _resolve_target(config)
	if _target_units <= 0.0:
		push_error("%s Resolved a non-positive target for '%s'; the run was not started." % [LOG_PREFIX, minigame_id])
		return false

	_state = State.RUNNING
	print(
		"%s begin %s stage=%s tier=%s limit=%.1fs target=%.2f"
		% [LOG_PREFIX, _minigame_id, _stage_id, _difficulty_tier, _time_limit_sec, _target_units]
	)
	EventBus.minigame_entered.emit(_minigame_id, _stage_id, _time_limit_sec)
	return true


# ---------------------------------------------------------------------------
# 2 · Timing
# ---------------------------------------------------------------------------

## Advance the run clock. Reaching the limit settles the run on the progress
## achieved so far. A timeout is an ordinary rating outcome, never a failure, so
## it does not touch the failure streak or the difficulty tier.
func advance_time(seconds: float) -> void:
	if _state != State.RUNNING or seconds <= 0.0:
		return

	_elapsed_sec = minf(_elapsed_sec + seconds, _time_limit_sec)
	if _elapsed_sec >= _time_limit_sec:
		print("%s time limit reached; settling on current progress." % LOG_PREFIX)
		_settle(_end_reason_code(&"timeout"))


# ---------------------------------------------------------------------------
# 3 · Goal determination
# ---------------------------------------------------------------------------

## A prototype reports its own countable progress. Reaching the target settles
## the run immediately; the runtime never inspects how the units were earned.
func report_progress(completed_units: float) -> void:
	if _state != State.RUNNING:
		return

	_completed_units = clampf(completed_units, 0.0, _target_units)
	if _completed_units >= _target_units:
		_settle(&"")


## Current accuracy, exposed so a prototype can drive its own display without
## recomputing the formula.
func completion_accuracy() -> float:
	if _target_units <= 0.0:
		return 0.0
	return clampf(_completed_units / _target_units, 0.0, 1.0)


func completion_efficiency() -> float:
	if _time_limit_sec <= 0.0:
		return 0.0
	return clampf((_time_limit_sec - _elapsed_sec) / _time_limit_sec, 0.0, 1.0)


## One of the three rating criteria. Counting a hint never fails a run and never
## blocks anything; it only lowers the score.
func use_hint() -> void:
	if _state != State.RUNNING:
		return
	_hint_usage_count += 1


# ---------------------------------------------------------------------------
# 4 · Exit
# ---------------------------------------------------------------------------

## Always available while a run is offered, including before it starts, while it
## runs, and after a failure. Returns immediately, costs nothing, grants nothing,
## and produces no rating.
func skip() -> bool:
	if _state == State.SETTLED:
		return false

	_state = State.SETTLED
	_resolution = Resolution.SKIPPED
	_pending_reward = {}
	_stars = 0
	_rating_detail = {}

	# The entry is available before a run starts, which is the case a stage with
	# no minigame lands in. Declining something that was never entered is a valid
	# skip, but there is no run to report exiting, so no event is emitted.
	if _minigame_id == &"":
		print("%s skipped before any run began; nothing to exit." % LOG_PREFIX)
		return true

	print("%s skipped %s; no reward, no resource change." % [LOG_PREFIX, _minigame_id])
	EventBus.minigame_exited.emit(_minigame_id, _resolution, _elapsed_sec)
	run_resolved.emit(_minigame_id, _resolution)
	return true


# ---------------------------------------------------------------------------
# 5 · Rating settlement
# ---------------------------------------------------------------------------

## Settle and rate the run. `end_reason` is empty when the target was reached and
## carries a configured reason code when the run ended for another cause.
func _settle(end_reason: StringName) -> void:
	_state = State.SETTLED
	_resolution = Resolution.COMPLETED
	_consecutive_failures = 0

	var accuracy := completion_accuracy()
	var efficiency := completion_efficiency()
	var weights_value: Variant = _rating_config("weights", {})
	var weights: Dictionary = weights_value if weights_value is Dictionary else {}
	var penalty_cap := int(_rating_config("hint_penalty_cap", 1))
	var counted_hints := mini(_hint_usage_count, penalty_cap)

	var score := (
		float(weights.get("accuracy", 0.0)) * accuracy
		+ float(weights.get("efficiency", 0.0)) * efficiency
		- float(weights.get("hint_penalty", 0.0)) * (float(counted_hints) / float(maxi(penalty_cap, 1)))
	)

	_stars = _star_tier(score)
	_rating_detail = {
		&"completion_accuracy": accuracy,
		&"completion_efficiency": efficiency,
		&"hint_usage_count": _hint_usage_count,
	}
	_pending_reward = _build_reward(_stars)

	print(
		"%s settled %s reason=%s accuracy=%.2f efficiency=%.2f hints=%d score=%.3f stars=%d"
		% [
			LOG_PREFIX,
			_minigame_id,
			end_reason if end_reason != &"" else &"target_reached",
			accuracy,
			efficiency,
			_hint_usage_count,
			score,
			_stars,
		]
	)

	EventBus.minigame_exited.emit(_minigame_id, _resolution, _elapsed_sec)
	EventBus.minigame_rated.emit(_minigame_id, _stars, _rating_detail)
	run_resolved.emit(_minigame_id, _resolution)


## Star multiplier scales the three spendable components only. Knowledge badges
## are counted, not spent, so they settle at their configured amount.
func _build_reward(stars: int) -> Dictionary:
	var reward_value: Variant = _minigame_value("reward", {})
	if not reward_value is Dictionary:
		return {}

	var reward: Dictionary = reward_value
	var multipliers: Variant = reward.get("star_multiplier", [])
	var multiplier := 0.0
	if multipliers is Array and stars >= 0 and stars < (multipliers as Array).size():
		multiplier = float((multipliers as Array)[stars])

	var result: Dictionary = {}
	for resource_id in SPENDABLE_RESOURCES:
		result[resource_id] = float(reward.get(String(resource_id), 0.0)) * multiplier
	result[&"knowledge_badge_count"] = int(reward.get("knowledge_badge_count", 0))
	return result


func _star_tier(score: float) -> int:
	var thresholds: Variant = _rating_config("star_thresholds", [])
	if not thresholds is Array:
		return 0
	var tier := 0
	for threshold in thresholds as Array:
		if score >= float(threshold):
			tier += 1
	return tier


# ---------------------------------------------------------------------------
# 6 · Failure handling
#
# All six rules of table M5, scoped to the inside of a run:
#   no regression, organ never removed, no death ending, reason stated,
#   immediate retry, difficulty eased after repeated failures.
# ---------------------------------------------------------------------------

## Declared by a prototype when its own rule was broken. Timer expiry never
## arrives here. Nothing outside the run is touched: no stage progress, no organ,
## no resource, no ending.
func fail(reason_code: StringName) -> bool:
	if _state != State.RUNNING:
		return false

	_state = State.FAILED
	_last_failure_reason = _end_reason_code(reason_code)
	_consecutive_failures += 1

	if _consecutive_failures >= _failures_before_ease() and _difficulty_tier != &"eased":
		_difficulty_tier = &"eased"
		print("%s eased the difficulty after %d consecutive failures." % [LOG_PREFIX, _consecutive_failures])

	print(
		"%s failed %s reason=%s streak=%d tier=%s; progress kept, nothing outside the run changed."
		% [LOG_PREFIX, _minigame_id, _last_failure_reason, _consecutive_failures, _difficulty_tier]
	)
	return true


## Available immediately after a failure. Costs nothing, advances no tick, and
## grants nothing. The skip entry stays available instead of retrying.
func retry() -> bool:
	if _state != State.FAILED:
		return false
	if _retries_used >= _max_retries_per_stage():
		push_warning("%s Retry allowance for this stage is exhausted; the skip entry is still available." % LOG_PREFIX)
		return false

	_retries_used += 1
	print("%s retry %d of %d at tier %s." % [LOG_PREFIX, _retries_used, _max_retries_per_stage(), _difficulty_tier])
	return begin(_minigame_id, _stage_id, _goal_key)


# ---------------------------------------------------------------------------
# Read-only accessors
# ---------------------------------------------------------------------------

func state() -> int:
	return _state


func resolution() -> int:
	return _resolution


## The spelling stored in `ChapterData.minigame_resolution`.
func resolution_id() -> StringName:
	return RESOLUTION_IDS[_resolution]


func stars() -> int:
	return _stars


## Exactly the three criteria of table M3; no fourth key is ever added.
func rating_detail() -> Dictionary:
	return _rating_detail.duplicate()


## The reward the resource settlement step should apply. This script never moves
## a resource itself.
func pending_reward() -> Dictionary:
	return _pending_reward.duplicate()


func elapsed_sec() -> float:
	return _elapsed_sec


func time_limit_sec() -> float:
	return _time_limit_sec


func difficulty_tier() -> StringName:
	return _difficulty_tier


func hint_usage_count() -> int:
	return _hint_usage_count


func consecutive_failures() -> int:
	return _consecutive_failures


func last_failure_reason() -> StringName:
	return _last_failure_reason


## Timing and density parameters for the current tier, for a prototype to read.
func difficulty_parameters() -> Dictionary:
	var difficulty: Variant = _minigame_value("difficulty", {})
	if not difficulty is Dictionary:
		return {}
	var tier_value: Variant = (difficulty as Dictionary).get(String(_difficulty_tier), {})
	if not tier_value is Dictionary:
		return {}
	var tier: Dictionary = tier_value
	return tier.duplicate()


# ---------------------------------------------------------------------------
# Configuration access
# ---------------------------------------------------------------------------

func _minigame_config(minigame_id: StringName) -> Dictionary:
	var value: Variant = Balance.get_value("minigames.%s" % minigame_id, {})
	if not value is Dictionary:
		return {}
	var config: Dictionary = value
	return config


func _minigame_value(key: String, default_value: Variant) -> Variant:
	return Balance.get_value("minigames.%s.%s" % [_minigame_id, key], default_value)


func _rating_config(key: String, default_value: Variant) -> Variant:
	return Balance.get_value("minigames.rating.%s" % key, default_value)


func _failures_before_ease() -> int:
	return int(Balance.get_value("minigames.failure.failures_before_ease", 1))


func _max_retries_per_stage() -> int:
	return int(Balance.get_value("minigames.failure.max_retries_per_stage", 0))


## Reason codes are configured, so the result panel always names a specific cause
## rather than saying only that the run ended.
func _end_reason_code(requested: StringName) -> StringName:
	var codes: Variant = Balance.get_value("minigames.failure.reason_codes", [])
	if codes is Array and (codes as Array).has(String(requested)):
		return requested
	push_warning("%s Unconfigured reason code '%s'; recording it unchanged." % [LOG_PREFIX, requested])
	return requested


## Every prototype declares one countable goal field. The runtime uses whichever
## field that is instead of naming target_divisions, target_deliveries, or
## target_nodes here.
func _sole_goal_key(config: Dictionary) -> StringName:
	var goal: Variant = config.get("goal", {})
	if not goal is Dictionary:
		return &""
	var goal_dictionary: Dictionary = goal
	if goal_dictionary.size() != 1:
		push_error(
			"%s Goal block for '%s' has %d fields; pass goal_key explicitly."
			% [LOG_PREFIX, _minigame_id, goal_dictionary.size()]
		)
		return &""
	return StringName(str(goal_dictionary.keys()[0]))


func _resolve_target(config: Dictionary) -> float:
	if _goal_key == &"":
		return 0.0
	var goal: Variant = config.get("goal", {})
	if not goal is Dictionary:
		return 0.0

	var base_target := float((goal as Dictionary).get(String(_goal_key), 0.0))
	var multiplier := float(difficulty_parameters().get("target_multiplier", 1.0))
	return maxf(base_target * multiplier, 0.0)
