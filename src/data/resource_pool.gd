class_name ResourcePool
extends RefCounted

## Runtime resource values and tick rates for the current body-city state.
##
## The active economy is the three-flow model of `docs/RESOURCE_ECONOMY_DESIGN.md`:
## biomass is the only stock the player spends, oxygen is a supply-versus-demand
## ratio that is never stockpiled, and waste accumulates against a capacity.
## Stability is a state value rather than a resource; it is the consequence of
## the other three.
##
## Contributors register themselves as named sources. A source is a completed
## facility or the committed road network of one map. The pool never inspects
## the map; it only sums what has been registered.

## Rates below are per second. Tick length is the unit those rates are
## expressed in, not a scheduling requirement: `apply_tick` integrates over
## whatever delta it is given.
const TICK_SEC := 1.0

## Must cover the first facility, its road, and one repair with margin left.
## At 120 a detoured first road left too little to repair the scripted fault,
## which stalled the run before the second map.
const BIOMASS_START := 180.0
const WASTE_CAPACITY := 60.0
## Fraction of capacity below which waste costs no stability.
const WASTE_SAFE := 0.5
const STABILITY_START := 100.0
const STABILITY_MAX := 100.0
const STABILITY_HEALTHY := 70.0
const STABILITY_STRAINED := 35.0
const STABILITY_RECOVERY := 1.5
const STABILITY_WASTE_WEIGHT := 2.0
const STABILITY_OXYGEN_WEIGHT := 4.0
const OXYGEN_DEMAND_FLOOR := 0.001

## Production multiplier by stability tier. Three steps rather than a curve, so
## that crossing a marked line on the bar produces a change the player can see.
const STABILITY_FACTOR_HEALTHY := 1.0
const STABILITY_FACTOR_STRAINED := 0.7
const STABILITY_FACTOR_CRITICAL := 0.4

## Every key a source specification may carry. Missing keys default to zero.
const SOURCE_RATE_KEYS: Array[StringName] = [
	&"biomass_output",
	&"oxygen_supply",
	&"oxygen_demand",
	&"waste_output",
	&"waste_clearance",
]

# Spendable stock; the only resource a build cost may name.
var biomass: float = BIOMASS_START # SAVED # SNAPSHOT
# Accumulated waste; initialize from balance.resources.waste.initial.
var waste: float = 0.0 # SAVED # SNAPSHOT
# Aggregate city stability; initialize from balance.resources.stability.initial.
var stability: float = STABILITY_START # SAVED # SNAPSHOT

# Derived every tick from the registered sources. Never saved: oxygen is not a
# stock, and the rates are recomputed from scratch on load.
var oxygen_supply: float = 0.0
var oxygen_demand: float = 0.0
var oxygen_ratio: float = 1.0
var stability_factor: float = STABILITY_FACTOR_HEALTHY
var biomass_rate: float = 0.0
var waste_rate: float = 0.0
var stability_rate: float = 0.0

# Per-source breakdown for the resource HUD hover panel. Keyed by source ID.
# `per_tick_output` holds what a source gives the city, `per_tick_consumption`
# what it takes. Both are rebuilt by `apply_tick`.
var per_tick_output: Dictionary = {} # SAVED # SNAPSHOT
var per_tick_consumption: Dictionary = {} # SAVED # SNAPSHOT

# Legacy fields retained for the four-stage chapter flow in
# `src/ui/gameplay_controller.gd`, which has not been migrated to the biomass
# economy. Nothing in the system-map prototype reads them.
var nutrient_energy: float = 0.0 # SAVED # SNAPSHOT
var cell_material: float = 0.0 # SAVED # SNAPSHOT
var development_signal: float = 0.0 # SAVED # SNAPSHOT
var knowledge_badge_count: int = 0 # SAVED # SNAPSHOT

var _sources: Dictionary = {}


func initialize_from_balance(_balance_data: Dictionary) -> void:
	pass


## Return the pool to its starting state and drop every registered source.
func reset_economy() -> void:
	biomass = BIOMASS_START
	waste = 0.0
	stability = STABILITY_START
	_sources.clear()
	_recompute_derived()


## Add or replace a contributor. `spec` may carry any key of `SOURCE_RATE_KEYS`
## plus an optional `label` used by the HUD breakdown. Values are per second.
func register_source(source_id: StringName, spec: Dictionary) -> void:
	var entry: Dictionary = {
		&"label": String(spec.get(&"label", String(source_id))),
	}
	for key in SOURCE_RATE_KEYS:
		entry[key] = float(spec.get(key, 0.0))
	_sources[source_id] = entry
	_recompute_derived()


func unregister_source(source_id: StringName) -> void:
	if not _sources.has(source_id):
		return
	_sources.erase(source_id)
	_recompute_derived()


func has_source(source_id: StringName) -> bool:
	return _sources.has(source_id)


func sources() -> Dictionary:
	return _sources.duplicate(true)


## Integrate the economy over `tick_delta` seconds. Evaluation order is fixed by
## section 3.1 of the design: oxygen, stability factor, biomass, waste, then
## stability. Stability settles last so a tick's production always reflects the
## state the player could see when that tick began.
func apply_tick(tick_delta: float) -> void:
	if tick_delta <= 0.0:
		_recompute_derived()
		return

	_recompute_oxygen()
	stability_factor = _stability_factor_for(stability)

	var biomass_output := 0.0
	var waste_in := 0.0
	var waste_out := 0.0
	for source_id in _sources:
		var entry: Dictionary = _sources[source_id]
		biomass_output += float(entry[&"biomass_output"])
		waste_in += float(entry[&"waste_output"])
		waste_out += float(entry[&"waste_clearance"])

	biomass_rate = biomass_output * oxygen_ratio * stability_factor
	biomass = maxf(biomass + biomass_rate * tick_delta, 0.0)

	waste_rate = waste_in - waste_out
	waste = clampf(waste + waste_rate * tick_delta, 0.0, WASTE_CAPACITY)

	stability_rate = _stability_rate()
	stability = clampf(
		stability + stability_rate * tick_delta,
		0.0,
		STABILITY_MAX
	)

	_rebuild_breakdown()


func waste_ratio() -> float:
	if WASTE_CAPACITY <= 0.0:
		return 0.0
	return clampf(waste / WASTE_CAPACITY, 0.0, 1.0)


func is_oxygen_short() -> bool:
	return oxygen_demand > oxygen_supply


func can_afford(biomass_cost: float) -> bool:
	return biomass >= biomass_cost


func spend(biomass_cost: float) -> bool:
	if not can_afford(biomass_cost):
		return false
	biomass -= biomass_cost
	return true


func refund(biomass_amount: float) -> void:
	biomass += maxf(biomass_amount, 0.0)


func load_saved_fields(data: Dictionary) -> void:
	biomass = float(data.get("biomass", BIOMASS_START))
	waste = float(data.get("waste", 0.0))
	stability = float(data.get("stability", STABILITY_START))
	_recompute_derived()


func write_saved_fields(target: Dictionary) -> void:
	target["biomass"] = biomass
	target["waste"] = waste
	target["stability"] = stability


func _recompute_derived() -> void:
	_recompute_oxygen()
	stability_factor = _stability_factor_for(stability)
	var biomass_output := 0.0
	var waste_in := 0.0
	var waste_out := 0.0
	for source_id in _sources:
		var entry: Dictionary = _sources[source_id]
		biomass_output += float(entry[&"biomass_output"])
		waste_in += float(entry[&"waste_output"])
		waste_out += float(entry[&"waste_clearance"])
	biomass_rate = biomass_output * oxygen_ratio * stability_factor
	waste_rate = waste_in - waste_out
	stability_rate = _stability_rate()
	_rebuild_breakdown()


func _recompute_oxygen() -> void:
	oxygen_supply = 0.0
	oxygen_demand = 0.0
	for source_id in _sources:
		var entry: Dictionary = _sources[source_id]
		oxygen_supply += float(entry[&"oxygen_supply"])
		oxygen_demand += float(entry[&"oxygen_demand"])
	## No demand is not a shortage. Without this an empty city would sit at a
	## zero ratio and drain stability before the player has built anything.
	if oxygen_demand <= OXYGEN_DEMAND_FLOOR:
		oxygen_ratio = 1.0
		return
	oxygen_ratio = clampf(oxygen_supply / oxygen_demand, 0.0, 1.0)


func _stability_factor_for(value: float) -> float:
	if value >= STABILITY_HEALTHY:
		return STABILITY_FACTOR_HEALTHY
	if value >= STABILITY_STRAINED:
		return STABILITY_FACTOR_STRAINED
	return STABILITY_FACTOR_CRITICAL


func _stability_rate() -> float:
	var over_safe := maxf(waste_ratio() - WASTE_SAFE, 0.0)
	var waste_penalty := 0.0
	if WASTE_SAFE < 1.0:
		waste_penalty = (
			STABILITY_WASTE_WEIGHT * over_safe / (1.0 - WASTE_SAFE)
		)
	var oxygen_penalty := STABILITY_OXYGEN_WEIGHT * (1.0 - oxygen_ratio)
	return STABILITY_RECOVERY - waste_penalty - oxygen_penalty


func _rebuild_breakdown() -> void:
	per_tick_output.clear()
	per_tick_consumption.clear()
	for source_id in _sources:
		var entry: Dictionary = _sources[source_id]
		var label: String = String(entry[&"label"])
		var output: Dictionary = {&"label": label}
		var consumption: Dictionary = {&"label": label}
		var has_output := false
		var has_consumption := false
		if not is_zero_approx(float(entry[&"biomass_output"])):
			output[&"biomass"] = float(entry[&"biomass_output"])
			has_output = true
		if not is_zero_approx(float(entry[&"oxygen_supply"])):
			output[&"oxygen_supply"] = float(entry[&"oxygen_supply"])
			has_output = true
		if not is_zero_approx(float(entry[&"waste_clearance"])):
			output[&"waste_clearance"] = float(entry[&"waste_clearance"])
			has_output = true
		if not is_zero_approx(float(entry[&"oxygen_demand"])):
			consumption[&"oxygen_demand"] = float(entry[&"oxygen_demand"])
			has_consumption = true
		if not is_zero_approx(float(entry[&"waste_output"])):
			consumption[&"waste_output"] = float(entry[&"waste_output"])
			has_consumption = true
		if has_output:
			per_tick_output[source_id] = output
		if has_consumption:
			per_tick_consumption[source_id] = consumption
