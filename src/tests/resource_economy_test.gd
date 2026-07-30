extends Node

## Check that the biomass economy reproduces the worked states of
## `docs/RESOURCE_ECONOMY_DESIGN.md` section 4.4 to two decimal places.
##
## Run headless:
##   godot --headless --path src res://tests/resource_economy_test.tscn
##
## Or open `res://tests/resource_economy_test.tscn` in the editor and press
## "Run Current Scene". Exits non-zero when any expectation fails.

const TOLERANCE := 0.005

## Section 4.3 of the design. Duplicated here on purpose: the test asserts the
## documented numbers, not whatever the scene happens to be configured with.
const EXCHANGE_DEPOT := {
	&"label": "Nutrient Exchange Depot",
	&"biomass_output": 3.0,
	&"oxygen_supply": 10.0,
	&"oxygen_demand": 2.0,
	&"waste_output": 0.40,
	&"waste_clearance": 0.40,
}
const HEART_STATION := {
	&"label": "Central Heart Transit Station",
	&"biomass_output": 1.5,
	&"oxygen_supply": 0.0,
	&"oxygen_demand": 3.0,
	&"waste_output": 0.30,
	&"waste_clearance": 1.10,
}
const ROAD_OXYGEN_DEMAND_PER_TILE := 0.03
const ROAD_WASTE_OUTPUT_PER_TILE := 0.01
## The route length the observed playthrough produced on each map.
const ROAD_TILES_PER_MAP := 19

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_map_one_only()
	_test_both_maps()
	_test_oxygen_shortfall_throttles_production()
	_test_stability_tiers()
	_test_spending()

	if _failures.is_empty():
		print("[ECONOMY TEST] RESULT PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("[ECONOMY TEST] %s" % failure)
	print("[ECONOMY TEST] RESULT FAIL count=", _failures.size())
	get_tree().quit(1)


## Map one alone: biomass climbs, oxygen is comfortable, and waste drifts up
## because nothing on this map can clear it.
func _test_map_one_only() -> void:
	var pool := _pool_with_maps(1)
	pool.apply_tick(0.0)

	_expect_near(pool.biomass_rate, 3.00, "map one biomass rate")
	_expect_near(pool.oxygen_supply, 10.00, "map one oxygen supply")
	_expect_near(pool.oxygen_demand, 2.57, "map one oxygen demand")
	_expect_near(pool.oxygen_ratio, 1.00, "map one oxygen ratio")
	_expect_near(pool.waste_rate, 0.19, "map one waste rate")
	_expect(
		pool.waste_rate > 0.0,
		"map one alone must accumulate waste it cannot clear"
	)


## Both maps: production rises and the waste trend reverses. This is the
## teaching moment of the first two maps.
func _test_both_maps() -> void:
	var pool := _pool_with_maps(2)
	pool.apply_tick(0.0)

	_expect_near(pool.biomass_rate, 4.50, "both maps biomass rate")
	_expect_near(pool.oxygen_supply, 10.00, "both maps oxygen supply")
	_expect_near(pool.oxygen_demand, 6.14, "both maps oxygen demand")
	_expect_near(pool.oxygen_ratio, 1.00, "both maps oxygen ratio")
	_expect_near(pool.waste_rate, -0.42, "both maps waste rate")
	_expect(
		pool.waste_rate < 0.0,
		"building the heart must reverse the waste trend"
	)

	## Integrating for ten seconds must move the stock by ten times the rate.
	var before := pool.biomass
	for step in range(10):
		pool.apply_tick(1.0)
	_expect_near(pool.biomass - before, 45.0, "ten seconds of biomass")


## An oxygen shortfall scales all production down rather than stopping it.
func _test_oxygen_shortfall_throttles_production() -> void:
	var pool := ResourcePool.new()
	pool.reset_economy()
	pool.register_source(&"supply", {&"oxygen_supply": 5.0})
	pool.register_source(
		&"consumer",
		{&"biomass_output": 4.0, &"oxygen_demand": 10.0}
	)
	pool.apply_tick(0.0)

	_expect_near(pool.oxygen_ratio, 0.5, "throttled oxygen ratio")
	_expect_near(pool.biomass_rate, 2.0, "throttled biomass rate")
	_expect(pool.is_oxygen_short(), "demand above supply must report short")

	## Section 3.6: a full oxygen deficit costs four stability per second
	## against the baseline recovery of one and a half.
	pool.unregister_source(&"supply")
	pool.apply_tick(0.0)
	_expect_near(pool.oxygen_ratio, 0.0, "unsupplied oxygen ratio")
	_expect_near(pool.stability_rate, -2.5, "unsupplied stability rate")


func _test_stability_tiers() -> void:
	var pool := ResourcePool.new()
	pool.reset_economy()
	pool.register_source(&"producer", {&"biomass_output": 10.0})

	pool.stability = 100.0
	pool.apply_tick(0.0)
	_expect_near(pool.biomass_rate, 10.0, "healthy tier production")

	pool.stability = 50.0
	pool.apply_tick(0.0)
	_expect_near(pool.biomass_rate, 7.0, "strained tier production")

	pool.stability = 10.0
	pool.apply_tick(0.0)
	_expect_near(pool.biomass_rate, 4.0, "critical tier production")

	## A healthy city recovers and pins at the maximum.
	pool.stability = 90.0
	for step in range(60):
		pool.apply_tick(1.0)
	_expect_near(pool.stability, 100.0, "healthy stability pins at maximum")


func _test_spending() -> void:
	var pool := ResourcePool.new()
	pool.reset_economy()
	var start := ResourcePool.BIOMASS_START
	_expect_near(pool.biomass, start, "starting biomass")
	_expect(pool.spend(60.0), "an affordable cost must be spendable")
	_expect_near(pool.biomass, start - 60.0, "biomass after a facility")
	_expect(
		not pool.can_afford(start),
		"an unaffordable cost must be rejected"
	)
	_expect(not pool.spend(start), "an unaffordable cost must not deduct")
	_expect_near(
		pool.biomass,
		start - 60.0,
		"a rejected cost must leave biomass alone"
	)
	pool.refund(60.0)
	_expect_near(pool.biomass, start, "a refund must restore biomass")

	## The opening position must fund the first facility, its road, and one
	## repair, or the first map cannot be finished.
	_expect(
		start >= 60.0 + 50.0 + NetworkOperationTool.REPAIR_BIOMASS_COST,
		"starting biomass must cover facility, road and one repair"
	)


func _pool_with_maps(map_count: int) -> ResourcePool:
	var pool := ResourcePool.new()
	pool.reset_economy()
	var facilities := [EXCHANGE_DEPOT, HEART_STATION]
	for index in range(map_count):
		pool.register_source(
			StringName("facility_%d" % index),
			facilities[index]
		)
		pool.register_source(
			StringName("roads_%d" % index),
			{
				&"label": "Roads, %d tiles" % ROAD_TILES_PER_MAP,
				&"oxygen_demand": (
					ROAD_OXYGEN_DEMAND_PER_TILE * float(ROAD_TILES_PER_MAP)
				),
				&"waste_output": (
					ROAD_WASTE_OUTPUT_PER_TILE * float(ROAD_TILES_PER_MAP)
				),
			}
		)
	return pool


func _expect_near(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) <= TOLERANCE:
		return
	_failures.append(
		"%s: expected %.4f, got %.4f" % [label, expected, actual]
	)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures.append(label)
