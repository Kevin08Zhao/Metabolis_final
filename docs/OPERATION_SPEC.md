# Operation Loop and Bottleneck Specification

This document defines operation settlement, transport coverage, thresholds, birth checks, bottleneck location, and immediate knowledge hints. Completed organs continuously produce and consume resources. The player confirms one resource priority per stage. Bottlenecks emerge from actual allocation and network state; stage scripts never insert them unconditionally.

Every gameplay value is read through `balance.*`. In formulas, `clamp`, `min`, `max`, `sum`, `weighted_mean`, and set operations are implementation operations rather than balance constants. The six resources remain `nutrient_energy`, `cell_material`, `development_signal`, `waste`, `stability`, and `knowledge_badge_count`. Stability and knowledge badges do not flow through the transport network.

Direct downstream interface ownership is fixed as follows:

- T-15 reads the capacity increment from E1.
- T-15a reads coverage radius and specification tier from E2.
- T-17 implements the direct stability, waste, pressure, and coverage formulas in E3.
- T-18 reads threshold, hysteresis, waste maximum, and low-resource lines from E4.
- T-19e reads the four reachable birth thresholds from E5.
- T-19f reads the operation option count, effect, and per-stage limit from E6.
- T-19g reads all three bottleneck detection and location contracts from E7.
- T-29 reads the three operational metric ranges and units from E8.
- D-16 reads the non-color bottleneck distinctions from E9.
- D-19a reads the cooperation observation trigger from E10.

## Table E1: Transport capacity intervention

| Input or output | Configuration or formula | Rule |
|---|---|---|
| Target edge | `selected_transport_edge_id` | Must belong to both `active_transport_edge_ids` and `mutable_transport_edge_ids`; intervention must not disconnect a required organ. |
| Base increment | `balance.transport.intervention.capacity_increment` | Increases only the selected edge's effective capacity. It does not alter organ demand, coverage radius, or resource balances directly. |
| Tier multiplier | `balance.transport.intervention.spec_multiplier[edge.spec_tier_id]` | Read from the selected edge's current tier. |
| Pressure response | `balance.transport.intervention.pressure_response(transport_pressure)` | Converts current pressure into a clamped unitless multiplier. |
| Applied increment | `capacity_delta = capacity_increment * spec_multiplier * pressure_response` | Calculated inside one atomic intervention. |
| Resulting capacity | `capacity_after = clamp(capacity_before + capacity_delta, balance.transport.capacity.min, balance.transport.capacity.max)` | Written to runtime capacity; original tier capacity remains in configuration. |
| Path capacity | `path_capacity = min(edge.effective_capacity for edge in active_route)` | The bottleneck edge limits throughput; edge capacities are not added. |
| Cost | `balance.transport.intervention.cost.development_signal` | Deducted in the same transaction after all preconditions pass. |

The per-stage usage limit is `balance.transport.intervention.max_uses_per_stage`. Capacity and resources remain unchanged when the limit is reached, resources are insufficient, or connectivity validation fails.

## Table E2: Coverage radius and specification tier

| `spec_tier_id` | Coverage radius | Capacity multiplier | Extension length | Consumers |
|---|---|---|---|---|
| `baseline` | `balance.transport.coverage_radius_by_spec.baseline` | `balance.transport.capacity_multiplier_by_spec.baseline` | `balance.build_options.<decision_id>.<option_id>.network.extension_length_by_spec.baseline` | T-15a, T-16 |
| `extended` | `balance.transport.coverage_radius_by_spec.extended` | `balance.transport.capacity_multiplier_by_spec.extended` | `balance.build_options.<decision_id>.<option_id>.network.extension_length_by_spec.extended` | T-15a, T-16 |
| `reinforced` | `balance.transport.coverage_radius_by_spec.reinforced` | `balance.transport.capacity_multiplier_by_spec.reinforced` | `balance.build_options.<decision_id>.<option_id>.network.extension_length_by_spec.reinforced` | T-15a, T-16 |

An edge stores its radius as `edge.coverage_radius` when generated. Runtime capacity intervention does not expand it. Organ-to-edge distance uses grid coordinates and a deterministic implemented metric selected by `balance.transport.distance_metric`.

## Table E3: Stability, waste, pressure, and coverage formulas

| Calculation | Direct formula | Inputs and clamping |
|---|---|---|
| Organ transport coverage | `organ_coverage[organ_id] = clamp(delivered_flow[organ_id] / max(required_flow[organ_id], balance.transport.coverage.denominator_floor), balance.normalized.min, balance.normalized.max)` | `delivered_flow` is limited by effective path capacity and actual tick flow. No-demand organs use `balance.transport.coverage.no_demand_value`. |
| City transport coverage | `transport_coverage = weighted_mean(organ_coverage[organ_id], balance.transport.coverage.organ_weights[organ_id])` | Includes only current `required_organ_ids`; Balance validates the weights. |
| Waste accumulation | `waste_next = clamp(waste_current + tick_delta * (sum(organ_waste_generation[organ_id]) - sum(waste_processing[organ_id]) - intervention_waste_removal), balance.resources.waste.min, balance.resources.waste.max)` | Generation and processing first apply active-state, tier, and resource-satisfaction multipliers. Waste cannot become negative. |
| Transport pressure | `transport_pressure = clamp(balance.transport.pressure.base + balance.transport.pressure.coverage_weight * (balance.normalized.max - transport_coverage) + balance.transport.pressure.utilization_weight * max_route_utilization, balance.transport.pressure.min, balance.transport.pressure.max)` | `max_route_utilization = max(edge_flow / max(edge.effective_capacity, balance.transport.capacity.denominator_floor))`. |
| Signal coverage | `signal_coverage = weighted_mean(delivered_development_signal[organ_id] / max(required_development_signal[organ_id], balance.signal.denominator_floor), balance.signal.organ_weights[organ_id])`, then clamp to `balance.signal.coverage.min` and `.max` | Uses actual delivered signal, never planned allocation. |
| Stability rate | `stability_rate = balance.stability.base_recovery + balance.stability.transport_weight * transport_coverage + balance.stability.signal_weight * signal_coverage - balance.stability.waste_weight * normalized_waste - balance.stability.pressure_weight * normalized_transport_pressure` | Normalize waste and pressure against E8 ranges. |
| Stability settlement | `stability_next = clamp(stability_current + tick_delta * stability_rate, balance.resources.stability.min, balance.resources.stability.max)` | Runs after waste and coverage settlement for the same tick. |

The fixed tick order is city production, network transport, organ consumption, waste accumulation, then stability settlement. Knowledge badges do not enter these formulas.

## Table E4: Thresholds, hysteresis, and low-resource lines

| Monitor | Enter condition | Recovery condition | Configuration |
|---|---|---|---|
| Stability `stable` | `stability >= balance.thresholds.stability.stable_enter` | Reach the same entry line from a lower state | `balance.thresholds.stability.stable_enter` |
| Stability `strained` | `stability < balance.thresholds.stability.stable_exit && stability >= balance.thresholds.stability.critical_enter` | `stability >= balance.thresholds.stability.strained_recover` | `balance.thresholds.stability.*` |
| Stability `critical` | `stability < balance.thresholds.stability.critical_enter` | `stability >= balance.thresholds.stability.critical_recover` | `balance.thresholds.stability.*` |
| Stability hysteresis | Applied only to tier transitions | `recover_threshold - enter_threshold >= balance.thresholds.stability.hysteresis` | `balance.thresholds.stability.hysteresis` |
| Waste warning | `waste >= balance.thresholds.waste.warning` | `waste < balance.thresholds.waste.warning` | `balance.thresholds.waste.warning` |
| Waste maximum | `waste >= balance.resources.waste.max` | `waste < balance.resources.waste.max` | `balance.resources.waste.max` |
| Low nutrient energy | `nutrient_energy < balance.thresholds.resources.nutrient_energy_low` | Low condition clears | `balance.thresholds.resources.nutrient_energy_low` |
| Low cell material | `cell_material < balance.thresholds.resources.cell_material_low` | Low condition clears | `balance.thresholds.resources.cell_material_low` |
| Low development signal | `development_signal < balance.thresholds.resources.development_signal_low` | Low condition clears | `balance.thresholds.resources.development_signal_low` |

Waste and spendable-resource monitors do not use hysteresis and do not repeat events while state is unchanged. Stability emits once when moving down and once when recovering upward.

## Table E5: Birth thresholds and baseline reachability

| Check | Pass condition | Baseline reachability constraint | Recovery direction |
|---|---|---|---|
| Transport coverage | `transport_coverage >= balance.birth_check.transport_coverage_min` | `balance.validation.baseline_build.transport_coverage >= balance.birth_check.transport_coverage_min` | Increase target-edge capacity or choose transport priority. |
| Waste | `waste <= balance.birth_check.waste_max` | `balance.validation.baseline_build.waste_steady_state <= balance.birth_check.waste_max` | Increase waste priority and wait for later ticks. |
| Stability | `stability >= balance.birth_check.stability_min` | `balance.validation.baseline_build.stability_equilibrium >= balance.birth_check.stability_min` | Resolve bottlenecks and wait for recovery. |
| Birth readiness | `birth_readiness >= balance.birth_check.birth_readiness_min` | `balance.validation.baseline_build.birth_readiness >= balance.birth_check.birth_readiness_min` | Support lung exchange and pulmonary interface. |

```text
birth_readiness =
    clamp(
        balance.birth_check.weights.transport * transport_coverage
        + balance.birth_check.weights.signal * signal_coverage
        + balance.birth_check.weights.pulmonary * pulmonary_system_readiness,
        balance.birth_check.range.min,
        balance.birth_check.range.max
    )
```

T-06 must prove all four constraints together with every organ at `baseline` tier and all minigame rewards set to `balance.validation.zero_reward`. A failed check never locks the flow; the player can operate again, wait for ticks, and retry.

## Table E6: Operation priority options

| `operation_option_id` | Focus | Weight source | Immediate effect |
|---|---|---|---|
| `transport_priority` | Effective transport of nutrient energy and cell material | `balance.operation.options.transport_priority.allocation_weights` | Recalculate routes, transport coverage, and pressure. |
| `waste_priority` | Waste processing | `balance.operation.options.waste_priority.allocation_weights` | Increase `waste_processing` for this settlement. |
| `signal_priority` | Development signal delivery | `balance.operation.options.signal_priority.allocation_weights` | Recalculate delivered signal and signal coverage. |
| `balanced_support` | Balanced support across all three needs | `balance.operation.options.balanced_support.allocation_weights` | Apply all weights without granting additional total input. |

`available_operation_ids` reads `balance.operation.available_options_by_stage[stage_id]`; its count equals `balance.operation.option_count_by_stage[stage_id]`. Player allocation must equal `balance.operation.allocation.required_total`. Confirmation applies the selected weights, then immediately performs one E3 settlement and one E4 threshold check.

The per-stage confirmation limit is `balance.operation.max_confirms_per_stage`. Confirmed IDs enter `confirmed_operation_decision_ids` and cannot be rolled back or charged twice. Every stage offers at least one option that can improve each possible active bottleneck, and baseline city production can afford at least one option.

## Table E7: Bottleneck detection, display, treatment, recovery, and location

| Bottleneck ID | Generation | City-map location | Visible behavior | Treatment | Recovery | Real mechanism |
|---|---|---|---|---|---|---|
| `transport_pressure` | `transport_pressure >= balance.bottlenecks.transport_pressure.enter` with an under-covered organ or overloaded edge | Lowest-coverage required organ; break ties with the highest `edge_flow / effective_capacity` edge | Blocked directional arrows and a neck marker on the edge; waiting badge on its organ | E1 capacity increase, `transport_priority`, or route-priority adjustment | Pressure at or below `.recover` and every required organ above `.organ_coverage_recover` | Transport-network capacity must match tissue demand; this is not a clinical ischemia diagnosis. |
| `waste_accumulation` | `waste >= balance.bottlenecks.waste.enter` or net waste rate above `.net_rate_enter` | Organ with greatest generation minus processing; for routing blockage, highest waste-route utilization | Graduated angular container beside the organ and an interrupted removal pulse at processing nodes | `waste_priority`, repair the waste route, or wait for processing ticks | Waste at or below `.recover` and net rate at or below `.net_rate_recover` | Metabolic products require transport and processing; the game value is not a real laboratory measurement. |
| `signal_coverage_low` | `signal_coverage <= balance.bottlenecks.signal_coverage.enter` with a required organ receiving insufficient signal | Organ with the lowest delivered-to-required ratio plus its weakest path edge | Broken concentric waves around the organ and intermittent path pulses | `signal_priority`, more signal allocation, or treatment of path pressure | Coverage at or above `.recover` and every required organ above its recovery ratio | Development relies on intercellular signaling that coordinates tissue differentiation; the game combines many real signals. |

The three bottlenecks are detected and recovered independently and may coexist in one tick. Each result includes `bottleneck_id`, `target_organ_id` or `target_edge_id`, current value, threshold, and first-occurrence flag.

## Table E8: Operational metrics, ranges, and units

| Metric | Runtime field | Range | Display unit | Benefit direction | UI reading |
|---|---|---|---|---|---|
| Transport pressure | `transport_pressure` | `balance.transport.pressure.min` to `.max` | `balance.ui.units.transport_pressure` | Lower | Raw value, unit, pressure scale, current target |
| Waste accumulation | `waste` | `balance.resources.waste.min` to `.max` | `balance.ui.units.waste` | Lower | Raw value, unit, maximum scale, net direction |
| Signal coverage | `signal_coverage` | `balance.signal.coverage.min` to `.max` | `balance.ui.units.signal_coverage` | Higher | Raw value, unit, coverage scale, lowest-coverage organ |

All three readings remain visible together. Stability remains one of the six resources and does not replace an E8 metric.

## Table E9: Non-color bottleneck distinctions

| Bottleneck | Outline | Internal pattern | Motion | Map attachment | Text prefix |
|---|---|---|---|---|---|
| `transport_pressure` | Narrow-neck hexagon | Directional arrows stack at the neck | Short pauses along edge direction | Transport edge first, organ second | `TRANSPORT` |
| `waste_accumulation` | Graduated angular container | Particles accumulate from the bottom | Rising level or removal pulse | Organ and processing node | `WASTE` |
| `signal_coverage_low` | Broken concentric circles | Dotted wave with a gap | Wave disappears intermittently | Organ and signal-path edge | `SIGNAL` |

The three types remain distinguishable in grayscale, with motion disabled, or as outlines only. Red, yellow, and blue must never be the sole distinction.

## Table E10: System cooperation observation

| New system | Required partners | Observation trigger | Completion record |
|---|---|---|---|
| `build_cell_cluster` | Cell-cluster production and internal transport nodes | One actual transfer changes a settlement value after build completion | `observed_cooperation.build_cell_cluster = true` |
| `build_placenta_port` | Cell cluster and placental exchange node | Placenta delivers a spendable resource that a built structure consumes | `observed_cooperation.build_placenta_port = true` |
| `build_germ_layer_districts` | Placental port and all three districts | Every district receives resources and at least one creates later transport demand | `observed_cooperation.build_germ_layer_districts = true` |
| `build_heart_pump` | Placental port and early trunk | Pumping changes active-edge flow and target-organ coverage | `observed_cooperation.build_heart_pump = true` |
| `build_neural_network` | Neural-tube foundation and signal path | Signal reaches a neural target and updates `signal_coverage` | `observed_cooperation.build_neural_network = true` |
| `build_lung_exchange` | Heart, network, and lung exchange region | Effective resource and signal delivery changes lung readiness | `observed_cooperation.build_lung_exchange = true` |
| `build_pulmonary_interface` | Heart, lung exchange region, and interface | An effective pulmonary path updates `pulmonary_system_readiness` | `observed_cooperation.build_pulmonary_interface = true` |

```text
cooperation_observation_ready(organ_id) =
    organ_state[organ_id] == OrganState.ACTIVE
    && required_partner_ids[organ_id].is_subset_of(active_organ_ids)
    && observed_runtime_transfer[organ_id] == true
    && observed_metric_change[organ_id] == true
    && blocking_modal_open == false
```

Record each new system only on its first qualifying observation, then unlock its archive entry. Animation playback, elapsed time, or opening the archive alone does not qualify.

## Table E11: Immediate knowledge hint hooks

| `knowledge_hint_id` | Operation feedback | Trigger | Real mechanism to explain | Deduplication |
|---|---|---|---|---|
| `hint_neural_tube_compensation` | First stage-three competition between signal and transport coverage | `stage_id == stage_circulation`, low signal coverage is detected for the first time, and transport coverage limits delivery in the same settlement | The neural plate folds and closes into the neural tube; its cranial region forms the foundation of the brain and its caudal region forms the foundation of the spinal cord. Developmental signals and material transport support this process together. | Once per save; never merge with another hint |
| `hint_transport_capacity` | Transport pressure enters bottleneck state | E7 `transport_pressure` moves from recovered to active | Network capacity and coverage must grow with tissue demand | Once per active episode; may trigger after recovery |
| `hint_waste_processing` | Waste enters bottleneck state | E7 `waste_accumulation` moves from recovered to active | Transport and processing jointly remove metabolic products | Once per active episode; may trigger after recovery |
| `hint_signal_coordination` | Low signal outside the stage-three compensation case | E7 locates a target and the compensation trigger is false | Cells coordinate proliferation, migration, and differentiation through many signals represented by one game resource | Once per stage |
| `hint_stability_response` | Stability drops one tier after settlement | E4 first transition from a higher to a lower tier | Stability summarizes multi-system cooperation and is not one real human measurement | Once per stage and tier transition |
| `hint_birth_transition` | Birth check passes | All E5 checks pass while `birth_transition_complete == false` | First breathing expands the lungs, lowers pulmonary vascular resistance, and increases pulmonary blood flow | Once per save |

Hints explain only the feedback that just occurred. They do not predict outcomes, recommend actions, or diagnose. Player-visible copy must be derived from `docs/SCIENCE_NOTES.md` and stay within its causal boundaries.

## No-deadlock guarantees

- Baseline production makes at least one E6 option affordable per stage, validated by `balance.validation.operation.minimum_affordable_option_by_stage`.
- Every bottleneck has a recovery path that does not depend on minigame rewards, validated by `balance.validation.operation.zero_reward_recovery`.
- A failed capacity intervention consumes no signal; a failed operation confirmation consumes no spendable resource.
- Critical stability does not end the game, delete organs, or reverse a stage. The player can wait, recover bottlenecks, and retry the birth check.
- Baseline maximum treatment capacity can reach every recovery line. T-06 jointly solves E5 and E7 and rejects unreachable configurations.
