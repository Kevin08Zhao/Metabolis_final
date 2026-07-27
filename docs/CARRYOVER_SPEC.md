# Cross-Stage Carryover Specification

This document is the single source of truth for consequences that pass from one stage into the operating start conditions of the next stage. Confirmed building and operations decisions are irreversible. Their only persistent gameplay weight is expressed through the three carryover values defined here; no fourth carryover value may be added.

Stages One through Three each calculate one carryover record during Step Ten. Stage Four calculates no carryover because it has no next stage. A carryover record contains exactly:

- `network_efficiency_coefficient`
- `initial_operation_pressure`
- `initial_waste_accumulation`

All tunable values, weights, ranges, validation gaps, formatting thresholds, and clamping limits in this specification use `balance.carryover.*`. Table D6 supplies the three build-choice deltas. Tables E3 and E6 supply the final settlement produced by the confirmed operations priority. T-19h combines those inputs exactly once at the stage boundary.

## Table F1: Carryover Values and Mapping Rules

| Carryover Value | Previous-Stage Decision Source | Calculation | Value Range | Next-Stage Mapping and Application Position |
|---|---|---|---|---|
| Network efficiency coefficient, `network_efficiency_coefficient` | Table D6 aggregates the completed stage’s confirmed building decisions listed in Table F2 into one stage-level `network_efficiency_delta`. The completed stage’s confirmed operations decision contributes the final E3 `transport_coverage` produced after applying its E6 operations priority. | `network_efficiency_coefficient_out = clamp(balance.carryover.network_efficiency.base + balance.carryover.network_efficiency.build_delta_weight * network_efficiency_delta + balance.carryover.network_efficiency.operation_weight * normalize(transport_coverage_settled, balance.carryover.network_efficiency.source_transport_coverage_range), balance.carryover.network_efficiency.range.min, balance.carryover.network_efficiency.range.max)` | `balance.carryover.network_efficiency.range.min` through `balance.carryover.network_efficiency.range.max` | Before the next stage’s first production or E3 settlement tick: `current_city_state.operation_start_conditions.network_efficiency_coefficient = carryover_record.network_efficiency_coefficient`. Network capacity and delivered-flow calculations read this coefficient as their starting multiplier. |
| Initial operating pressure, `initial_operation_pressure` | Table D6 aggregates the completed stage’s confirmed building decisions listed in Table F2 into one stage-level `operation_pressure_delta`. The completed stage’s confirmed operations decision contributes the final E3 `transport_pressure` produced after applying its E6 operations priority. | `initial_operation_pressure_out = clamp(balance.carryover.operation_pressure.base + balance.carryover.operation_pressure.build_delta_weight * operation_pressure_delta + balance.carryover.operation_pressure.operation_weight * normalize(transport_pressure_settled, balance.carryover.operation_pressure.source_transport_pressure_range), balance.carryover.operation_pressure.range.min, balance.carryover.operation_pressure.range.max)` | `balance.carryover.operation_pressure.range.min` through `balance.carryover.operation_pressure.range.max` | After the next stage’s base network is instantiated but before its first E3 settlement tick: `current_city_state.operation_start_conditions.initial_operation_pressure = carryover_record.initial_operation_pressure`, then `current_city_state.transport_pressure` is initialized from that value. |
| Initial waste accumulation, `initial_waste_accumulation` | Table D6 aggregates the completed stage’s confirmed building decisions listed in Table F2 into one stage-level `waste_delta`. The completed stage’s confirmed operations decision contributes the final E3 `waste_next` produced after applying its E6 operations priority. | `initial_waste_accumulation_out = clamp(balance.carryover.waste.base + balance.carryover.waste.build_delta_weight * waste_delta + balance.carryover.waste.operation_weight * normalize(waste_settled, balance.carryover.waste.source_waste_range), balance.carryover.waste.range.min, balance.carryover.waste.range.max)` | `balance.carryover.waste.range.min` through `balance.carryover.waste.range.max` | After the next stage’s organs and waste routes are instantiated but before its first E3 settlement tick: `current_city_state.operation_start_conditions.initial_waste_accumulation = carryover_record.initial_waste_accumulation`, then `current_city_state.waste` is initialized from that value. |

`normalize(value, configured_range)` converts the input to the configured `balance.carryover.*` normalized range. T-19h must validate all three source settlements, calculate all three outputs, clamp them, and commit the record atomically. A failed validation writes none of the three values.

## Table F2: Stage Production, Storage, and Replay Mapping

| Completed Stage | Next Stage | Decisions That Produce the Record | `chapter_snapshots` Write | `current_city_state` Write and Step-Ten Summary |
|---|---|---|---|---|
| Stage One · Origin, `stage_origin` | Stage Two · Harbor, `stage_harbor` | `build_cell_cluster`; `operate_cleavage_allocation` and its confirmed E6 priority | Write the complete three-field record to `chapter_snapshots[stage_harbor].operation_start_conditions` when `stage_harbor` is entered for the first time. | Write the same record to `current_city_state.operation_start_conditions`; the Step-Ten summary describes the Stage Two starting conditions in the three locked summary lines. |
| Stage Two · Harbor, `stage_harbor` | Stage Three · Circulation, `stage_circulation` | `build_placenta_port`; `build_germ_layer_districts`; `operate_placental_transport` and its confirmed E6 priority | Write the complete three-field record to `chapter_snapshots[stage_circulation].operation_start_conditions` when `stage_circulation` is entered for the first time. | Write the same record to `current_city_state.operation_start_conditions`; the Step-Ten summary describes the Stage Three starting conditions in the three locked summary lines. |
| Stage Three · Circulation, `stage_circulation` | Stage Four · Birth, `stage_birth` | `build_heart_pump`; `build_neural_network`; `operate_circulation_signal_priority` and its confirmed E6 priority | Write the complete three-field record to `chapter_snapshots[stage_birth].operation_start_conditions` when `stage_birth` is entered for the first time. | Write the same record to `current_city_state.operation_start_conditions`; the Step-Ten summary describes the Stage Four starting conditions in the three locked summary lines. |
| Stage Four · Birth, `stage_birth` | None; `next_stage_id = null` | No producer set | Do not calculate or write a carryover record. | Do not replace `current_city_state.operation_start_conditions` and do not display a cross-stage carryover summary. |

The two writes for a transition are one atomic save transaction. The three fields are written to `chapter_snapshots` and `current_city_state`; they are never written to `main_progress`. `main_progress` may identify the unlocked or current stage, but it may not duplicate, derive, or override any carryover value.

## Player-Readable Step-Ten Summary

The summary contains exactly these three lines for a transition that produces carryover:

- `Network start: {network_efficiency_coefficient formatted with balance.carryover.summary.network_efficiency_format}`
- `Operating pressure: {initial_operation_pressure formatted with balance.carryover.summary.operation_pressure_format}`
- `Waste carried forward: {initial_waste_accumulation formatted with balance.carryover.summary.waste_format}`

Each line displays the runtime value and a plain-language direction relative to its `balance.carryover.summary.*.reference` threshold. It may not expose formulas, weights, option rankings, or additional state. The summary is part of the completing stage’s Step Ten and explicitly names the next stage whose starting conditions it describes.

## T-19h Replay Rule

In replay mode, T-19h must read the three carryover values directly from:

```text
chapter_snapshots[replay_stage_id].operation_start_conditions
```

It must copy that stored record into `current_city_state.operation_start_conditions` before the replay stage begins. T-19h must not rerun Table D6, E3, E6, or Table F1 calculations, and it must not read the latest values from `current_city_state` as calculation inputs.

Recalculation would introduce values from the current save state and violate the per-stage snapshot rule. Therefore, replaying a completed stage always restores exactly the operating start conditions captured when that stage was first entered, field for field.

## Stage-Two Lowest-versus-Best Network-Efficiency Validation

For the transition from Stage Two to Stage Three, compare the legal Stage Two candidate combination with the lowest resulting `network_efficiency_coefficient` against the legal combination with the highest result, while applying the same confirmed operations priority in both runs. Stage Three must start with:

- a network efficiency coefficient lower by the closed interval `[balance.carryover.validation.stage_harbor_to_circulation.network_efficiency_gap.min, balance.carryover.validation.stage_harbor_to_circulation.network_efficiency_gap.max]`;
- initial operating pressure higher by `[balance.carryover.validation.stage_harbor_to_circulation.operation_pressure_gap.min, balance.carryover.validation.stage_harbor_to_circulation.operation_pressure_gap.max]`;
- initial waste accumulation higher by `[balance.carryover.validation.stage_harbor_to_circulation.waste_gap.min, balance.carryover.validation.stage_harbor_to_circulation.waste_gap.max]`.

T-06 must resolve these endpoints to concrete numbers in `BALANCE.json`. Each minimum gap must meet its corresponding `balance.carryover.validation.perceptible_gap_floor`, while the worst legal Stage Two result must remain within `balance.carryover.validation.stage_circulation.recoverable_start_range` and satisfy `balance.carryover.validation.stage_circulation.completion_reachable`. This makes the difference perceptible without allowing the lowest-efficiency choice to block completion.
