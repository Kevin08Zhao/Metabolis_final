# Balance Key Dictionary and Validation

This document validates `docs/BALANCE.json` against `docs/GAME_RULES.md`, `docs/GRID_BASELINE.md`, Tables M1–M7, Tables D1–D11, Tables E1–E11, Table F1, and the T-09 and T-12 runtime data contracts. It contains no authoritative gameplay values of its own; every value quoted here is read from `BALANCE.json`.

## Closed Expansion Sets and Runtime Aliases

The path dictionary below uses closed placeholders only:

- `{stage_id}` = `stage_origin`, `stage_harbor`, `stage_circulation`, `stage_birth`
- `{resource}` = `nutrient_energy`, `cell_material`, `development_signal`
- `{organ_id}` = `cell_cluster`, `placenta_port`, `germ_layer_districts`, `heart_pump`, `neural_network`, `lung_exchange`, `pulmonary_interface`
- `{spec_tier_id}` = `baseline`, `extended`, `reinforced`
- `{operation_option_id}` = `transport_priority`, `waste_priority`, `signal_priority`, `balanced_support`
- `{minigame_id}` = `minigame_cell_division`, `minigame_material_transport`, `minigame_signal_transfer`
- `{decision_id}.{option_id}` expands to the fourteen pairs declared in Table D2 and stored under `build_options`

The JSON has exactly the thirteen required top-level keys. The Balance access layer resolves older logical specification paths without duplicating data:

- `balance.operation.*` resolves to `operations.*`.
- `balance.transport.*` and `balance.signal.*` resolve to `network.transport.*` and `network.signal.*`.
- `balance.stability.*`, `balance.thresholds.*`, `balance.bottlenecks.*`, `balance.birth_check.*`, `balance.normalized.*`, `balance.ui.*`, and `balance.validation.*` resolve to their namesakes under `operations`.
- `balance.minigame.*` resolves through `minigames[active_minigame_id]`; `time_limit` resolves to `duration_limit_sec`.
- `balance.minigame.initial_resolution` resolves to `minigames.runtime.initial_resolution`.
- `balance.build.cost[selected_build_option_id]` resolves to the selected pair under `build_options`.
- `balance.build.selection_policy` and `balance.build.slot_selection_policy` resolve to the matching `build_options` keys.
- `balance.operation.cost[selected_operation_id]` and `balance.operation.outcome[selected_operation_id]` resolve under `operations.options`.
- `balance.transport.intervention.capacity` resolves to `network.transport.intervention.capacity_increment`.
- Legacy `balance.stage.carryover.*` resolves to `carryover.*`; Table F1’s `balance.carryover.*` is canonical.
- T-09 logical paths `balance.save.*`, `balance.progress.*`, and `balance.knowledge.*` resolve to `chapters.save.*`, `chapters.progress.*`, and `assist.knowledge.*`.
- T-12 reads the canonical paths `build_options.grid.columns`, `build_options.grid.rows`, and `build_options.grid.tile_size_px` directly through `Balance.get_value`; no alias or script constant is permitted for these values.

## Complete Key-Path Dictionary

| Complete JSON Path | Meaning | Unit |
|---|---|---|
| `version` | Balance schema and data version | Semantic version |
| `tick_interval_sec` | Duration of one settlement tick | seconds |
| `chapters.{stage_id}.operation_time_sec` | Active-operation time budget for one stage | seconds |
| `chapters.{stage_id}.tick_count` | Settlement ticks budgeted for one stage | ticks |
| `chapters.{stage_id}.{id\|next_stage_id\|initial_phase}` | Stage identity, successor, and opening phase | identifier |
| `chapters.{stage_id}.{required_build_decision_ids\|required_operation_decision_ids\|required_organ_ids}` | Required IDs for completion and graph validation | identifier list |
| `chapters.{stage_id}.{build_confirmation_policy\|operation_confirmation_policy}` | Irreversible confirmation policies | identifier |
| `chapters.{stage_id}.{first_build_decision_id\|operation_decision_id\|minigame_id}` | Opening action and optional task IDs | identifier or null |
| `chapters.{stage_id}.{system_observation_complete_initial\|knowledge_unlock_resolved_initial}` | Initial completion flags | Boolean |
| `operations.ui.input_lock_timeout_sec` | Watchdog ceiling for the T-22 input lock; exceeding it forces an unlock. Must stay above `chapters.stage_birth.birth_sequence.total_budget_ms` | seconds |
| `chapters.stage_birth.birth_sequence.{umbilical_stop_ms\|pulmonary_flow_ms\|fetal_shunts_ms\|systems_online_ms\|ending_ms}` | Window length of each beat on the birth timeline, per table B2 of `docs/BIRTH_STATES.md` | milliseconds |
| `chapters.stage_birth.birth_sequence.total_budget_ms` | Ending-sequence budget the five windows must sum to | milliseconds |
| `chapters.total_operation_time_sec` | Sum of the four active-operation budgets | seconds |
| `chapters.save.{version\|current_city_state_schema\|chapter_snapshot_policy}` | T-09 save schema and snapshot policy | integer, identifier list, or identifier |
| `chapters.progress.initial` | Initial main-progression block | object |
| `resources.{resource}.initial` | Starting amount of an investable resource | resource units |
| `resources.{resource}.max` | Investable-resource capacity | resource units |
| `resources.{resource}.per_tick_output` | City production of an investable resource | resource units per tick |
| `resources.{resource}.per_tick_consumption` | Baseline city consumption | resource units per tick |
| `resources.{resource}.low_threshold` | Low-resource warning line | resource units |
| `resources.waste.initial` | Initial waste pool | waste units |
| `resources.waste.min` | Waste lower clamp | waste units |
| `resources.waste.max` | Waste upper clamp | waste units |
| `resources.waste.accumulation_per_tick` | Baseline waste generation | waste units per tick |
| `resources.waste.recovery_by_coverage.base` | Base waste recovery | waste units per tick |
| `resources.waste.recovery_by_coverage.coverage_factor` | Additional recovery at full transport coverage | waste units per tick |
| `resources.waste.overflow_stability_penalty` | Stability loss applied at overflow | stability units |
| `resources.waste.warning_threshold` | Waste warning line | waste units |
| `resources.stability.initial` | Initial stability | stability units |
| `resources.stability.min` | Stability lower clamp | stability units |
| `resources.stability.max` | Stability upper clamp | stability units |
| `resources.stability.warning_line` | Strained-state warning line | stability units |
| `resources.stability.critical_line` | Critical-state entry line | stability units |
| `resources.stability.hysteresis` | Minimum recovery separation | stability units |
| `resources.stability.decay_per_unmet_demand` | Stability decay per unmet-demand unit | stability units |
| `resources.knowledge_badge_count.initial` | Initial badge count | badges |
| `resources.knowledge_badge_count.max` | Badge count cap | badges |
| `organs.required_ids_by_stage.{stage_id}` | Required organ IDs active by a stage | identifier list |
| `organs.{organ_id}.{id\|initial_state\|spec_tier_id\|footprint_id}` | T-09 organ identity and initial presentation fields | identifier |
| `organs.{organ_id}.grid_origin` | Initial top-left grid cell | grid coordinate |
| `organs.{organ_id}.active` | Initial settlement participation | Boolean |
| `organs.{organ_id}.resources` | Initial organ-local resource object | object |
| `organs.{organ_id}.required_flow` | Organ transport demand | flow units per tick |
| `organs.{organ_id}.required_development_signal` | Organ development-signal demand | signal units per tick |
| `organs.{organ_id}.{transport_coverage\|signal_coverage}.initial` | Initial settled coverage | ratio |
| `organs.{organ_id}.per_tick_output.{nutrient_energy\|cell_material\|development_signal\|waste}` | Organ-local tick output | corresponding resource units per tick |
| `organs.{organ_id}.per_tick_consumption.{nutrient_energy\|cell_material\|development_signal\|waste}` | Organ-local tick consumption or processing | corresponding resource units per tick |
| `build_options.grid.columns` | Number of playable grid columns read by T-12 | tiles |
| `build_options.grid.rows` | Number of playable grid rows read by T-12 | tiles |
| `build_options.grid.tile_size_px` | Side length of one square grid tile read by T-12 | reference pixels |
| `build_options.metric_ranges.network_efficiency` | Normalization interval for preview efficiency | coefficient range |
| `build_options.metric_ranges.build_duration` | Normalization interval for build duration | seconds range |
| `build_options.metric_ranges.future_convenience` | Normalization interval for future convenience | coefficient range |
| `build_options.metric_units.{network_efficiency\|build_duration\|future_convenience}` | Player-visible unit label | text |
| `build_options.normalized_min` | Normalized-score lower clamp | unitless |
| `build_options.normalized_max` | Normalized-score upper clamp | unitless |
| `build_options.normalized_sum_max` | Maximum equal-weight score across three dimensions | unitless |
| `build_options.carryover.decision_weights.{decision_id}` | Stage-convenience weight for a confirmed decision | weight |
| `build_options.carryover.network_efficiency_factor` | D6 convenience-to-efficiency conversion | coefficient |
| `build_options.carryover.operation_pressure_factor` | D6 inconvenience-to-pressure conversion | pressure units |
| `build_options.carryover.waste_factor` | D6 inconvenience-to-waste conversion | waste units |
| `build_options.validation.equal_weight_tolerance` | D8/D11 relative score tolerance | ratio |
| `build_options.{selection_policy\|slot_selection_policy}` | Empty-until-player-selection initialization policies | identifier |
| `build_options.{decision_id}.available_option_ids` | Legal candidate IDs for a decision | identifier list |
| `build_options.{decision_id}.{option_id}.available_slot_ids` | Legal candidate-slot IDs | identifier list |
| `build_options.{decision_id}.{option_id}.cost.{resource}` | Candidate confirmation cost | resource units |
| `build_options.{decision_id}.{option_id}.slot_candidates` | Legal top-left candidate cells | grid-coordinate list |
| `build_options.{decision_id}.{option_id}.footprint_id` | Fixed grid-footprint selector | identifier |
| `build_options.{decision_id}.{option_id}.metrics.network_efficiency` | Candidate preview efficiency | coefficient |
| `build_options.{decision_id}.{option_id}.metrics.build_duration` | Candidate preview duration | seconds |
| `build_options.{decision_id}.{option_id}.metrics.future_convenience` | Candidate preview convenience | coefficient |
| `build_options.{decision_id}.{option_id}.carryover.convenience_weight` | D6 candidate contribution weight | weight |
| `build_options.{decision_id}.{option_id}.network.start_anchor` | Deterministic network start | grid coordinate |
| `build_options.{decision_id}.{option_id}.network.end_anchor` | Deterministic network end | grid coordinate |
| `build_options.{decision_id}.{option_id}.network.trunk_route_id` | Deterministic trunk route | identifier |
| `build_options.{decision_id}.{option_id}.network.extension_profile_id` | Extension behavior profile | identifier |
| `build_options.{decision_id}.{option_id}.network.spec_tier_id` | Candidate specification tier | identifier |
| `build_options.{decision_id}.{option_id}.network.network_capacity` | Initial candidate-network capacity | flow units per tick |
| `build_options.{decision_id}.{option_id}.network.extension_length_by_spec.{spec_tier_id}` | Extension length for a tier | tiles |
| `operations.allocation.required_total` | Required sum of allocation weights | ratio |
| `operations.allocation.initial_total` | Initial unallocated operations total | ratio |
| `operations.selection_policy` | Empty-until-player-selection initialization policy | identifier |
| `operations.max_confirms_per_stage` | Operations confirmations allowed in one stage | count |
| `operations.available_options_by_stage.{stage_id}` | Legal operations-priority IDs | identifier list |
| `operations.option_count_by_stage.{stage_id}` | Number of legal operations priorities | count |
| `operations.options.{operation_option_id}.allocation_weights.{transport\|waste\|signal}` | Allocation direction for a priority | ratio |
| `operations.options.{operation_option_id}.cost.{resource}` | Operations confirmation cost | resource units |
| `operations.options.{operation_option_id}.outcome.transport_pressure` | Immediate pressure delta | pressure units |
| `operations.options.{operation_option_id}.outcome.waste` | Immediate waste delta | waste units |
| `operations.options.{operation_option_id}.outcome.stability` | Immediate stability delta | stability units |
| `operations.options.{operation_option_id}.outcome.network_efficiency` | Immediate efficiency delta | coefficient |
| `operations.normalized.{min\|max}` | Shared E3 normalization bounds | unitless |
| `operations.stability.base_recovery` | Stability recovery independent of coverage | stability units per tick |
| `operations.stability.{transport_weight\|signal_weight\|waste_weight\|pressure_weight}` | E3 stability-rate weights | weight |
| `operations.thresholds.stability.{stable_enter\|stable_exit\|strained_recover\|critical_enter\|critical_recover\|hysteresis}` | E4 stability transition lines | stability units |
| `operations.thresholds.waste.warning` | E4 waste warning line | waste units |
| `operations.thresholds.resources.{nutrient_energy_low\|cell_material_low\|development_signal_low}` | E4 resource warning lines | resource units |
| `operations.bottlenecks.transport_pressure.{enter\|recover}` | Pressure activation and recovery lines | pressure units |
| `operations.bottlenecks.transport_pressure.organ_coverage_recover` | Required organ coverage for recovery | ratio |
| `operations.bottlenecks.waste.{enter\|recover}` | Waste activation and recovery lines | waste units |
| `operations.bottlenecks.waste.{net_rate_enter\|net_rate_recover}` | Net-rate activation and recovery lines | waste units per tick |
| `operations.bottlenecks.signal_coverage.{enter\|recover\|organ_recovery_ratio}` | Signal activation and recovery lines | ratio |
| `operations.birth_check.{transport_coverage_min\|birth_readiness_min}` | Minimum birth-check coverage values | ratio |
| `operations.birth_check.waste_max` | Maximum passing waste value | waste units |
| `operations.birth_check.stability_min` | Minimum passing stability value | stability units |
| `operations.birth_check.weights.{transport\|signal\|pulmonary}` | Birth-readiness weights | weight |
| `operations.birth_check.range.{min\|max}` | Birth-readiness clamp | ratio |
| `operations.ui.blocking_modal_open_initial` | Initial blocking-modal state | Boolean |
| `operations.ui.units.{transport_pressure\|waste\|signal_coverage}` | E8 display-unit labels | text |
| `operations.validation.zero_reward` | Reward value used by zero-reward validation | resource units |
| `operations.validation.baseline_build.transport_coverage` | Zero-reward baseline coverage result | ratio |
| `operations.validation.baseline_build.waste_steady_state` | Zero-reward baseline waste result | waste units |
| `operations.validation.baseline_build.stability_equilibrium` | Zero-reward baseline stability result | stability units |
| `operations.validation.baseline_build.birth_readiness` | Zero-reward baseline birth-readiness result | ratio |
| `operations.validation.operation.minimum_affordable_option_by_stage.{stage_id}` | Known affordable recovery option | identifier |
| `operations.validation.operation.zero_reward_recovery` | Whether every bottleneck recovers without minigame rewards | Boolean |
| `network.transport.distance_metric` | Deterministic organ-to-edge distance metric | identifier |
| `network.{nodes_by_stage\|edges_by_stage\|active_edges_by_stage\|mutable_edges_by_stage}.{stage_id}` | T-09 initial graph collections | record or identifier list |
| `network.efficiency.initial` | Initial settled network efficiency | coefficient |
| `network.transport.selection_policy` | Empty-until-player-selection initialization policy | identifier |
| `network.transport.coverage_radius_by_spec.{spec_tier_id}` | Coverage radius for a tier | tiles |
| `network.transport.capacity_multiplier_by_spec.{spec_tier_id}` | Capacity multiplier for a tier | coefficient |
| `network.transport.capacity.{min\|max}` | Effective-capacity clamp | flow units per tick |
| `network.transport.capacity.denominator_floor` | Utilization denominator floor | flow units per tick |
| `network.transport.coverage.denominator_floor` | Coverage denominator floor | flow units per tick |
| `network.transport.coverage.no_demand_value` | Coverage for an organ with no demand | ratio |
| `network.transport.coverage.initial` | Initial city transport coverage | ratio |
| `network.transport.coverage.organ_weights.{organ_id}` | City transport-coverage weight | weight |
| `network.transport.pressure.{base\|coverage_weight\|utilization_weight}` | E3 pressure formula values | pressure units |
| `network.transport.pressure.initial` | Initial transport pressure | pressure units |
| `network.transport.pressure.{min\|max}` | Pressure clamp | pressure units |
| `network.transport.intervention.capacity_increment` | E1 capacity increase and GAME_RULES intervention capacity | flow units per tick |
| `network.transport.intervention.used_initial` | Initial per-stage intervention flag | Boolean |
| `network.transport.intervention.plan_by_edge` | Initial alternate-route plan map | object |
| `network.transport.intervention.spec_multiplier.{spec_tier_id}` | Intervention multiplier by tier | coefficient |
| `network.transport.intervention.pressure_response.input_range` | Pressure-response input interval | pressure range |
| `network.transport.intervention.pressure_response.output_range` | Pressure-response output interval | coefficient range |
| `network.transport.intervention.cost.development_signal` | Intervention cost | signal units |
| `network.transport.intervention.max_uses_per_stage` | Intervention limit in one stage | count |
| `network.transport.intervention.unlock_pressure` | Pressure needed to unlock intervention | pressure units |
| `network.transport.intervention.outcome.transport_pressure` | Intervention pressure delta | pressure units |
| `network.transport.intervention.outcome.waste` | Intervention waste delta | waste units |
| `network.transport.intervention.outcome.stability` | Intervention stability delta | stability units |
| `network.signal.denominator_floor` | Signal-demand denominator floor | signal units per tick |
| `network.signal.coverage.{min\|max}` | Signal-coverage clamp | ratio |
| `network.signal.coverage.initial` | Initial signal coverage | ratio |
| `network.signal.organ_weights.{organ_id}` | City signal-coverage weight | weight |
| `carryover.network_efficiency.{base\|build_delta_weight\|operation_weight}` | F1 efficiency formula values | coefficient or weight |
| `carryover.network_efficiency.source_transport_coverage_range` | F1 coverage normalization interval | ratio range |
| `carryover.network_efficiency.range.{min\|max}` | Next-stage efficiency clamp | coefficient |
| `carryover.operation_pressure.{base\|build_delta_weight\|operation_weight}` | F1 pressure formula values | pressure units or weight |
| `carryover.operation_pressure.source_transport_pressure_range` | F1 pressure normalization interval | pressure range |
| `carryover.operation_pressure.range.{min\|max}` | Next-stage pressure clamp | pressure units |
| `carryover.waste.{base\|build_delta_weight\|operation_weight}` | F1 waste formula values | waste units or weight |
| `carryover.waste.source_waste_range` | F1 waste normalization interval | waste range |
| `carryover.waste.range.{min\|max}` | Next-stage waste clamp | waste units |
| `carryover.summary.{network_efficiency_format\|operation_pressure_format\|waste_format}` | Step-Ten formatting pattern | text |
| `carryover.summary.{network_efficiency\|operation_pressure\|waste}.reference` | Plain-language direction reference | corresponding metric unit |
| `carryover.validation.perceptible_gap_floor` | Minimum perceptible validation gap | normalized gap |
| `carryover.validation.stage_harbor_to_circulation.{network_efficiency_gap\|operation_pressure_gap\|waste_gap}.{min\|max}` | Closed Stage Two comparison intervals | corresponding metric unit |
| `carryover.validation.stage_circulation.recoverable_start_range.{network_efficiency_coefficient\|initial_operation_pressure\|initial_waste_accumulation}` | Legal replay/start intervals | corresponding metric range |
| `carryover.validation.stage_circulation.completion_reachable` | Whether the lowest legal carryover remains completable | Boolean |
| `minigames.runtime.initial_resolution` | Initial optional-task resolution state | identifier |
| `minigames.rating.weights.{accuracy\|efficiency\|hint_penalty}` | M3 rating weights | weight |
| `minigames.rating.hint_penalty_cap` | Maximum hint count entering rating | count |
| `minigames.rating.star_thresholds` | Ascending star thresholds | ratio list |
| `minigames.failure.reason_codes` | Specific task-failure messages | identifier list |
| `minigames.failure.{max_retries_per_stage\|failures_before_ease}` | Retry and easing limits | count |
| `minigames.validation.completion_headroom` | Target-completion headroom | ratio |
| `minigames.validation.reward_cost_ratio_max` | Maximum task-reward/build-cost ratio | ratio |
| `minigames.{minigame_id}.duration_limit_sec` | Active minigame time limit | seconds |
| `minigames.{minigame_id}.task_level` | Tutorial or standard task level | identifier |
| `minigames.{minigame_id}.goal.*` | Prototype target quantity | count |
| `minigames.{minigame_id}.difficulty.{base\|eased}.*` | Prototype timing, density, and target modifier | seconds, count, or ratio |
| `minigames.{minigame_id}.reward.{nutrient_energy\|cell_material\|development_signal}` | Optional completion reward | resource units |
| `minigames.{minigame_id}.reward.knowledge_badge_count` | Optional completion badge reward | badges |
| `minigames.{minigame_id}.reward.star_multiplier` | Spendable-reward multiplier by star count | coefficient list |
| `challenges.enabled_ids` | Enabled deterministic scripted challenges | identifier list |
| `challenges.{max_injections_per_stage\|max_injections_total}` | Scripted-injection limits | count |
| `challenges.transport_pressure_intro.{stage_id\|bottleneck_id}` | Stage and E7 type for the pressure introduction | identifier |
| `challenges.transport_pressure_intro.{capacity_multiplier\|pressure_target}` | Pressure-introduction intensity | coefficient or pressure units |
| `challenges.transport_pressure_intro.max_recovery_ticks` | Required maximum recovery time | ticks |
| `challenges.waste_accumulation_intro.{stage_id\|bottleneck_id}` | Stage and E7 type for the waste introduction | identifier |
| `challenges.waste_accumulation_intro.{waste_delta\|maximum_self_recoverable_delta}` | Waste-introduction amount and recovery cap | waste units |
| `challenges.waste_accumulation_intro.processing_multiplier` | Temporary processing multiplier | coefficient |
| `challenges.waste_accumulation_intro.max_recovery_ticks` | Required maximum recovery time | ticks |
| `challenges.signal_coverage_intro.{stage_id\|bottleneck_id}` | Stage and E7 type for the signal introduction | identifier |
| `challenges.signal_coverage_intro.{delivery_multiplier\|coverage_target}` | Signal-introduction intensity | ratio |
| `challenges.signal_coverage_intro.max_recovery_ticks` | Required maximum recovery time | ticks |
| `challenges.by_stage.stage_birth` | Locked empty Stage Four challenge list | identifier list |
| `notifications.dwell_sec.{broadcast\|attribution\|pressure\|alert}` | D-17a dwell duration for each notification tier. Entry and exit animation lengths remain locked by tables G1a–G1d | seconds |
| `notifications.max_stack.broadcast` | Maximum number of simultaneous broadcast cards; locked to the three-card G1a stack proof | cards |
| `notifications.max_stack.alert` | Maximum simultaneous alert cards; additional alerts wait in the queue | cards |
| `notifications.max_stack.shared` | Shared visible capacity used first-in-first-out by attribution and pressure cards | cards |
| `notifications.merge_window_ms` | Coalescing window used only by EVENT_API rows marked `repeatable within one tick` | milliseconds |
| `notifications.alert_bpm.{stable\|warning\|critical}` | Alert-border heartbeat cadence by stability display band | beats per minute |
| `notifications.assist.dwell_multiplier` | Assist-mode multiplier applied to dwell duration without changing tier, order, or copy | coefficient |
| `assist.hint_levels` | D7 hint levels available to assistance UI | identifier list |
| `assist.default_hint_level` | Default D7 hint level | identifier |
| `assist.mode.failures_before_assist` | Consecutive failures inside one stage after which T-33a offers assist mode. Held equal to `minigames.failure.failures_before_ease` so the assist offer and the table M5 eased tier arrive together rather than at two different moments | failures |
| `assist.mode.speed_scale` | Factor T-33a publishes for the assist-mode speed reduction. Greater than zero and less than one, since assist mode only ever slows a run down | unitless factor |
| `assist.mode.time_limit_scale` | Factor T-33a publishes for the assist-mode time-limit extension. At least one, since assist mode only ever lengthens a run. It scales the effective limit of a running attempt; the configured `minigames.<id>.duration_limit_sec` is unchanged, exactly as the table M5 eased tier changes windows and targets without rewriting the configured value | unitless factor |
| `assist.mode.show_full_route` | Whether assist mode publishes the complete operation route for a minigame prototype. Boolean | flag |
| `assist.knowledge.{initial_unlocked_entry_ids\|read_tracking_policy\|selection_policy}` | T-09 knowledge initialization and tracking policies | identifier list or identifier |
| `assist.audio.max_concurrent_one_shots` | Maximum number of reusable one-shot players created by T-37. The value is a positive integer; six permits short overlaps while keeping the soundscape restrained | players |
| `assist.audio.high_frequency_min_interval_sec` | Minimum interval between playbacks of the same event whose EVENT_API frequency is `repeatable within one tick`. The value is positive and no greater than one settlement tick | seconds |
| `assist.ui.resource_change_highlight_sec` | Duration of the T-29 resource-cell change highlight. The value is positive and shorter than one settlement tick so adjacent updates remain distinguishable | seconds |

## Zero-Reward Production and Reachability Calculation

The three minigame reward objects are treated as zero. With `tick_interval_sec = 1.0`, the four chapter budgets contain `1068` settlement ticks. The baseline build chooses `cluster_wave`, `placenta_interface`, `layers_staged`, `heart_early_flow`, `neural_distributed`, `lung_maturation`, and `pulmonary_transition`, then confirms `balanced_support` once per stage.

| Resource | Initial + Gross Production | Baseline Consumption | Net Available | Baseline Build Cost | Four Operations Costs | Total Required | Surplus |
|---|---:|---:|---:|---:|---:|---:|---:|
| Nutrient Energy | `80 + 0.30 × 1068 = 400.40` | `0.05 × 1068 = 53.40` | `347.00` | `246.00` | `28.00` | `274.00` | `73.00` |
| Cell Material | `75 + 0.28 × 1068 = 374.04` | `0.04 × 1068 = 42.72` | `331.32` | `246.00` | `28.00` | `274.00` | `57.32` |
| Development Signal | `65 + 0.22 × 1068 = 299.96` | `0.03 × 1068 = 32.04` | `267.92` | `182.00` | `28.00` | `210.00` | `57.92` |

All three investable resources remain positive after every baseline build and all four required operations decisions, without any minigame reward. The zero-reward baseline results also satisfy every birth check: transport coverage `0.80 ≥ 0.70`, waste `45.00 ≤ 50.00`, stability `70.00 ≥ 55.00`, and birth readiness `0.78 ≥ 0.70`. `operations.validation.operation.zero_reward_recovery` is `true`, so optional rewards are never a completion prerequisite.

The M4 reward ceiling also passes at the maximum star multiplier. Cell Division grants `9.00`, below `0.30 × 58.00 = 17.40`; Material Transport grants `9.00`, below `0.30 × 198.00 = 59.40`; Signal Transfer grants `8.00`, below `0.30 × 206.00 = 61.80`. The three base-tier timing checks are respectively `40 ≤ 48`, `36 ≤ 48`, and `40 ≤ 48` seconds, so every target fits within the configured completion headroom.

## Candidate Non-Dominance and Equal-Weight Validation

Normalized benefit scores use D8: network efficiency and future convenience increase with value; build duration increases as duration falls. A candidate strictly dominates only if all three scores are at least as high and one is higher. Every pair below gives each candidate at least one advantage, and every equal-weight sum passes the relative tolerance `0.15`.

| Stage | Decision | Candidate A Scores `N/T/C; S` | Candidate B Scores `N/T/C; S` | A Advantage | B Advantage | Strict Dominance | Equal-Weight Result |
|---|---|---|---|---|---|---|---|
| Origin | `build_cell_cluster` | `cluster_compact: 0.80/0.45/0.45; 1.70` | `cluster_wave: 0.40/0.80/0.60; 1.80` | Network efficiency | Duration, convenience | Neither | PASS |
| Harbor | `build_placenta_port` | `placenta_exchange: 0.85/0.40/0.40; 1.65` | `placenta_interface: 0.45/0.75/0.65; 1.85` | Network efficiency | Duration, convenience | Neither | PASS |
| Harbor | `build_germ_layer_districts` | `layers_parallel: 0.75/0.50/0.45; 1.70` | `layers_staged: 0.40/0.85/0.60; 1.85` | Network efficiency | Duration, convenience | Neither | PASS |
| Circulation | `build_heart_pump` | `heart_reinforced: 0.90/0.40/0.45; 1.75` | `heart_early_flow: 0.50/0.80/0.65; 1.95` | Network efficiency | Duration, convenience | Neither | PASS |
| Circulation | `build_neural_network` | `neural_cranial: 0.80/0.45/0.45; 1.70` | `neural_distributed: 0.45/0.85/0.65; 1.95` | Network efficiency | Duration, convenience | Neither | PASS |
| Birth | `build_lung_exchange` | `lung_branching: 0.80/0.40/0.70; 1.90` | `lung_maturation: 0.50/0.90/0.45; 1.85` | Network efficiency, convenience | Duration | Neither | PASS |
| Birth | `build_pulmonary_interface` | `pulmonary_reserve: 0.85/0.35/0.70; 1.90` | `pulmonary_transition: 0.50/0.85/0.50; 1.85` | Network efficiency, convenience | Duration | Neither | PASS |

The largest relative equal-weight difference is below the configured tolerance, so no candidate is deleted or hidden. A second stage-wide pass compares every unordered option pair, including options belonging to different decisions: Origin has one pair, Harbor has six, Circulation has six, and Birth has six. All nineteen pairs return “neither dominates,” so the harder stage-wide requirement also passes.
