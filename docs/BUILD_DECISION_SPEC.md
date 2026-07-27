# Build Decision Candidate Specification

This document is the single source of truth for seven build decisions, their candidates, preview dimensions, slot inputs, confirmation settlement, and science mappings. Candidates vary only in normal developmental sequence, specification tier, legal slot, and resource allocation. They are not disease grades and do not imply that a player can alter real organ topology, position, or the left-right body axis.

Every tunable value is read through `balance.build_options.*`. This specification defines configuration paths, formulas, and required inequalities without embedding balance constants. Fixed grid values come from `docs/GRID_BASELINE.md`; stage and decision IDs come from `docs/CHAPTER_TIMELINE.md`.

## Table D1: Seven build decisions and downstream interfaces

| `build_decision_id` | `stage_id` | Build target | Candidate basis | Specification tiers | T-12 | T-13 | T-13a | T-15 | T-15a | T-19h | T-33a | D-13b | D-19a | T-35 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `build_cell_cluster` | `stage_origin` | Embryonic cell cluster | Compaction sequence and resource mix | `cluster_compact`, `cluster_wave` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_placenta_port` | `stage_harbor` | Placental foundation | Interface tier and resource mix | `placenta_exchange`, `placenta_interface` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_germ_layer_districts` | `stage_harbor` | Three germ-layer districts | Build order and resource mix | `layers_parallel`, `layers_staged` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_heart_pump` | `stage_circulation` | Central heart pump | Specification tier and resource mix | `heart_reinforced`, `heart_early_flow` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_neural_network` | `stage_circulation` | Neural tube, brain, and spinal cord foundation | Build order and resource mix | `neural_cranial`, `neural_distributed` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_lung_exchange` | `stage_birth` | Lung gas-exchange region | Specification tier and resource mix | `lung_branching`, `lung_maturation` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_pulmonary_interface` | `stage_birth` | Pulmonary circulation interface | Build order and interface tier | `pulmonary_reserve`, `pulmonary_transition` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |

Downstream tasks must read the numbered tables listed above. They must not copy and rename fields independently.

## Table D2: Candidate list and hard differences

| Decision | `build_option_id` | Allowed difference | Player tradeoff | `slot_candidates` | `cost` |
|---|---|---|---|---|---|
| `build_cell_cluster` | `cluster_compact` | Tier and resource mix | Denser early connections for a longer build | `balance.build_options.build_cell_cluster.cluster_compact.slot_candidates` | `balance.build_options.build_cell_cluster.cluster_compact.cost` |
| `build_cell_cluster` | `cluster_wave` | Sequence and resource mix | Faster expansion for lower initial connection density | `balance.build_options.build_cell_cluster.cluster_wave.slot_candidates` | `balance.build_options.build_cell_cluster.cluster_wave.cost` |
| `build_placenta_port` | `placenta_exchange` | Tier and resource mix | Stronger exchange trunk for a longer formation time | `balance.build_options.build_placenta_port.placenta_exchange.slot_candidates` | `balance.build_options.build_placenta_port.placenta_exchange.cost` |
| `build_placenta_port` | `placenta_interface` | Sequence and resource mix | Earlier maternal-fetal interface for lower initial throughput | `balance.build_options.build_placenta_port.placenta_interface.slot_candidates` | `balance.build_options.build_placenta_port.placenta_interface.cost` |
| `build_germ_layer_districts` | `layers_parallel` | Sequence and resource mix | Greater interconnection for a longer coordinated build | `balance.build_options.build_germ_layer_districts.layers_parallel.slot_candidates` | `balance.build_options.build_germ_layer_districts.layers_parallel.cost` |
| `build_germ_layer_districts` | `layers_staged` | Sequence and resource mix | Faster staged formation with more later cross-district links | `balance.build_options.build_germ_layer_districts.layers_staged.slot_candidates` | `balance.build_options.build_germ_layer_districts.layers_staged.cost` |
| `build_heart_pump` | `heart_reinforced` | Tier and resource mix | Stronger pump interface for a longer build | `balance.build_options.build_heart_pump.heart_reinforced.slot_candidates` | `balance.build_options.build_heart_pump.heart_reinforced.cost` |
| `build_heart_pump` | `heart_early_flow` | Sequence and resource mix | Earlier flow with lower initial reserve | `balance.build_options.build_heart_pump.heart_early_flow.slot_candidates` | `balance.build_options.build_heart_pump.heart_early_flow.cost` |
| `build_neural_network` | `neural_cranial` | Sequence and resource mix | Earlier cranial signal coverage with later trunk extension | `balance.build_options.build_neural_network.neural_cranial.slot_candidates` | `balance.build_options.build_neural_network.neural_cranial.cost` |
| `build_neural_network` | `neural_distributed` | Sequence and resource mix | Easier distributed access with lower initial trunk efficiency | `balance.build_options.build_neural_network.neural_distributed.slot_candidates` | `balance.build_options.build_neural_network.neural_distributed.cost` |
| `build_lung_exchange` | `lung_branching` | Tier and resource mix | Earlier branch coverage with later maturation support | `balance.build_options.build_lung_exchange.lung_branching.slot_candidates` | `balance.build_options.build_lung_exchange.lung_branching.cost` |
| `build_lung_exchange` | `lung_maturation` | Sequence and resource mix | Earlier exchange-region maturation with lower branch coverage | `balance.build_options.build_lung_exchange.lung_maturation.slot_candidates` | `balance.build_options.build_lung_exchange.lung_maturation.cost` |
| `build_pulmonary_interface` | `pulmonary_reserve` | Interface tier and resource mix | Greater birth-transition reserve for a longer build | `balance.build_options.build_pulmonary_interface.pulmonary_reserve.slot_candidates` | `balance.build_options.build_pulmonary_interface.pulmonary_reserve.cost` |
| `build_pulmonary_interface` | `pulmonary_transition` | Sequence and resource mix | Faster pulmonary connection with greater later expansion demand | `balance.build_options.build_pulmonary_interface.pulmonary_transition.slot_candidates` | `balance.build_options.build_pulmonary_interface.pulmonary_transition.cost` |

## Table D3: Candidate coordinates and three grid states

| Input or state | Single data source | Executable rule |
|---|---|---|
| Candidate top-left coordinates | `balance.build_options.<decision_id>.<option_id>.slot_candidates` | Every entry is `Vector2i(column, row)` and must pass boundary, footprint, and candidate-spacing validation. |
| Footprint | `balance.build_options.<decision_id>.<option_id>.footprint_id` | `standard_building` and `landmark_organ` map to the fixed footprints in the grid baseline. |
| `UNAVAILABLE` | Runtime blockers, bounds, and occupied set | True when the footprint is out of bounds, intersects `occupied_cells` or `blocked_cells`, or violates minimum candidate spacing. |
| `CANDIDATE` | Legal slots for the selected option | True for the complete legal footprint of `selected_build_option_id` when no cell is occupied. |
| `OCCUPIED` | `occupied_cells` | Complete footprint of a confirmed build; this state has priority over candidate highlighting. |
| State priority | Fixed order | `OCCUPIED` overrides `CANDIDATE`; `UNAVAILABLE` overrides an unconfirmed candidate. One cell never renders multiple states. |

Expand a footprint from `(column, row)` through `column + width_tiles - 1` and `row + height_tiles - 1`. Compare complete cell sets, never sprite rectangles or anchor points.

## Table D4: Selection, settlement, and non-reversibility

| Step | Rule |
|---|---|
| Select | `selected_build_option_id` belongs to `available_build_option_ids`; its slot belongs to that option's `available_build_slot_ids`. Preview changes no resources or cells. |
| Read cost | `selected_cost = balance.build_options.<decision_id>.<option_id>.cost` with `nutrient_energy`, `cell_material`, and `development_signal`. |
| Validate | Each resource covers its cost, phase is `Phase.BUILD_DECISION`, and the decision is not confirmed. |
| Atomic deduction | `resource_after.<resource> = resource_before.<resource> - selected_cost.<resource>`. If any precondition fails, all resources remain unchanged. |
| Lock | Store the option, slot, cost snapshot, and preview snapshot in `ConfirmedBuildDecision`, then add the decision ID to `confirmed_build_decision_ids`. |
| No rollback | Disable option, slot, and submission controls. Loading restores the snapshot without recalculating cost and exposes no undo, demolition, or reselection action. |
| Duplicate defense | A confirmed ID returns `already_confirmed` without charging resources or creating another blueprint. |

## Table D5: Transport trunk mapping and network extension inputs

| Decision | Start | End | Trunk route | T-15a inputs |
|---|---|---|---|---|
| `build_cell_cluster` | `balance.build_options.build_cell_cluster.<option_id>.network.start_anchor` | `balance.build_options.build_cell_cluster.<option_id>.network.end_anchor` | `balance.build_options.build_cell_cluster.<option_id>.network.trunk_route_id` | `extension_profile_id`, `spec_tier_id`, `network_capacity`, `extension_length` |
| `build_placenta_port` | `balance.build_options.build_placenta_port.<option_id>.network.start_anchor` | `balance.build_options.build_placenta_port.<option_id>.network.end_anchor` | `balance.build_options.build_placenta_port.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |
| `build_germ_layer_districts` | `balance.build_options.build_germ_layer_districts.<option_id>.network.start_anchor` | `balance.build_options.build_germ_layer_districts.<option_id>.network.end_anchor` | `balance.build_options.build_germ_layer_districts.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |
| `build_heart_pump` | `balance.build_options.build_heart_pump.<option_id>.network.start_anchor` | `balance.build_options.build_heart_pump.<option_id>.network.end_anchor` | `balance.build_options.build_heart_pump.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |
| `build_neural_network` | `balance.build_options.build_neural_network.<option_id>.network.start_anchor` | `balance.build_options.build_neural_network.<option_id>.network.end_anchor` | `balance.build_options.build_neural_network.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |
| `build_lung_exchange` | `balance.build_options.build_lung_exchange.<option_id>.network.start_anchor` | `balance.build_options.build_lung_exchange.<option_id>.network.end_anchor` | `balance.build_options.build_lung_exchange.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |
| `build_pulmonary_interface` | `balance.build_options.build_pulmonary_interface.<option_id>.network.start_anchor` | `balance.build_options.build_pulmonary_interface.<option_id>.network.end_anchor` | `balance.build_options.build_pulmonary_interface.<option_id>.network.trunk_route_id` | Same fields under this candidate's `network.*` |

`extension_length` reads `balance.build_options.<decision_id>.<option_id>.network.extension_length_by_spec.<spec_tier_id>`. T-15a creates nodes and edges from the deterministic route ID, anchors, capacity, and extension length. It must not infer direction from display names, sprite positions, or randomness.

## Table D6: Future convenience and cross-stage carryover

| Output | Formula |
|---|---|
| Raw convenience | `convenience_raw = balance.build_options.<decision_id>.<option_id>.metrics.future_convenience` |
| Normalized convenience | `convenience_norm = normalize_benefit(convenience_raw, balance.build_options.metric_ranges.future_convenience)` |
| Decision contribution | `decision_convenience = convenience_norm * balance.build_options.<decision_id>.<option_id>.carryover.convenience_weight` |
| Stage convenience | `stage_convenience = weighted_mean(confirmed decision_convenience, balance.build_options.carryover.decision_weights)` |
| Network carryover | `network_efficiency_delta = stage_convenience * balance.build_options.carryover.network_efficiency_factor` |
| Pressure carryover | `operation_pressure_delta = (balance.build_options.normalized_max - stage_convenience) * balance.build_options.carryover.operation_pressure_factor` |
| Waste carryover | `waste_delta = (balance.build_options.normalized_max - stage_convenience) * balance.build_options.carryover.waste_factor` |

T-19h sends these three deltas to the cross-stage layer. Resource retention and final clamping remain under `balance.stage.carryover.*`.

## Table D7: Three hint levels

| Level | Allowed | Forbidden |
|---|---|---|
| `hint_observe` | Explain the displayed connection efficiency, build duration, future convenience, and resource cost. | Recommendations, rankings, or claims that one option is best. |
| `hint_compare` | Explain opposing tradeoff directions and what high or low values mean. | A total score, hidden disadvantages, or a science mapping presented as success probability. |
| `hint_consequence` | Describe possible later pressure, expansion demand, or build-time effects without naming an option. | Option IDs, confirmation-button emphasis, or claims that an option prevents failure. |

Hints may repeat visible numbers, formula meaning, and causal direction only. They do not display the equal-weight sum `S`, validation tolerance, or a player-history-based candidate order.

## Table D8: Preview dimensions, units, and normalization

| Dimension | Configuration | Unit | Benefit direction | Range | Formula | Card display |
|---|---|---|---|---|---|---|
| Network efficiency | `balance.build_options.<decision_id>.<option_id>.metrics.network_efficiency` | `balance.build_options.metric_units.network_efficiency` | Higher | `balance.build_options.metric_ranges.network_efficiency` | `N = (value - min) / (max - min)` | Raw value, unit, comparison bar |
| Build duration | `balance.build_options.<decision_id>.<option_id>.metrics.build_duration` | `balance.build_options.metric_units.build_duration` | Lower | `balance.build_options.metric_ranges.build_duration` | `T = (max - value) / (max - min)` | Raw value, unit, reversed comparison bar |
| Future convenience | `balance.build_options.<decision_id>.<option_id>.metrics.future_convenience` | `balance.build_options.metric_units.future_convenience` | Higher | `balance.build_options.metric_ranges.future_convenience` | `C = (value - min) / (max - min)` | Raw value, unit, comparison bar |
| Equal-weight sum | Runtime-derived | Unitless internal validation | Validation only | `balance.build_options.normalized_min` to `.normalized_sum_max` | `S = N + T + C` | Never shown |

Validate `max > min` before normalization and clamp results to the normalized range. For every unordered pair:

```text
abs(S_a - S_b)
<= balance.build_options.validation.equal_weight_tolerance * max(S_a, S_b)
```

T-06 supplies the tolerance and all concrete values.

## Table D9: Animation tiers and science-review mappings

| Candidate | Tier | Distinct completion behavior | Developmental mapping | Review source |
|---|---|---|---|---|
| `cluster_compact` | `reinforced` | Contact surfaces tighten before the cluster lights | Human embryo compaction involves contractility and adhesion | Firmin et al., *Nature*, DOI `10.1038/s41586-024-07351-x` |
| `cluster_wave` | `baseline` | Light propagates outward from local contacts | A timing expression of the same compaction process | Same source |
| `placenta_exchange` | `reinforced` | Exchange trunk completes before pulsing | Placental development includes trophoblast differentiation and villous exchange | Turco and Moffett, *Development*, PMID `31049600` |
| `placenta_interface` | `baseline` | Interface closes before connecting to the trunk | Implantation coordinates apposition, adhesion, and trophoblast differentiation | Huang et al., *Front Cell Dev Biol*, DOI `10.3389/fcell.2023.1200330` |
| `layers_parallel` | `extended` | Three outlines expand together, then connect | Gastrulation organizes ectoderm, mesoderm, and endoderm | Tyser, *Semin Cell Dev Biol*, DOI `10.1016/j.semcdb.2022.05.004` |
| `layers_staged` | `baseline` | Layers expand sequentially, then cross-connect | A teaching representation of formation timing; every layer completes | Same source |
| `heart_reinforced` | `reinforced` | Tube bending, pumping, and interface ring complete in order | The embryonic heart tube bends, lengthens, and remodels | Hikspoors et al., *J Anat*, PMID `35277594` |
| `heart_early_flow` | `baseline` | Pumping appears before the interface ring completes | Early cardiac pumping is shown without changing real pacemaking timing | Manner, *J Cardiovasc Dev Dis*, DOI `10.3390/jcdd9060187` |
| `neural_cranial` | `extended` | Cranial folds close before trunkward signaling | Neural tube closure coordinates convergence, extension, and apical constriction | Nikolopoulou et al., *Development*, PMID `28196803` |
| `neural_distributed` | `baseline` | Multiple closure lights join into one trunk | Spatial coordination only; no disputed human initiation model is asserted | Greene and Copp, *J Pathol*, PMID `23790957` |
| `lung_branching` | `extended` | Airway branches appear before exchange tips light | Lung development uses signal-regulated branching morphogenesis | Morrisey and Hogan, *Dev Cell*, PMID `24449833` |
| `lung_maturation` | `reinforced` | Exchange tips pulse before branch coverage completes | Epithelial, mesenchymal, and stage coordination forms exchange structures | Same source |
| `pulmonary_reserve` | `reinforced` | The vascular interface expands with a wider capacity ring | Fetal pulmonary vessels prepare for lower resistance and greater postnatal flow | Gao and Raj, *Physiol Rev*, PMID `27942377` |
| `pulmonary_transition` | `baseline` | The interface connects quickly, then shows expansion demand | First breathing lowers pulmonary vascular resistance and raises pulmonary flow | Holmes et al., *Clin Perinatol*, DOI `10.1016/j.clp.2023.11.003` |

Animations use only `baseline`, `extended`, and `reinforced`. Color is never the sole distinction; outline sequence, pulse rhythm, or capacity-ring shape must also change.

## Table D10: Boundaries for four allowed difference types

| Difference | Three allowed examples | Three forbidden examples |
|---|---|---|
| Build order | Trunk before interface; exchange tips before branches; parallel districts before final links | Skip a required structure; build a later-stage organ early; replace a slower sequence with failure or malformation |
| Specification tier | Baseline versus reinforced trunk; standard versus reserve capacity; baseline versus extended coverage | Missing organ; reversed body axis; pathological closure, implantation, or malformation as a selectable tier |
| Slot | Legal cells within one anatomical region; adjacent legal anchors in one corridor; display offset that preserves topology | Heart in the head; lungs in the pelvis; placenta detached from the maternal-fetal interface |
| Resource mix | More nutrient energy with less material; more material with longer duration; more signal with greater later convenience | Zero cost; paying directly with waste or stability; lower cost plus better values in all three dimensions |

Delete a candidate before D11 if it changes required organ identity, normal topology, left-right axis, stage membership, or presents pathology as an advantage. Science mappings explain normal timing and engineering analogies; they do not predict pregnancy outcomes.

## Table D11: Non-dominance and equal-weight balance matrix

| Decision | Candidate A | Candidate B | A advantage | B advantage | Three-dimension result | Delete flag | Equal-weight `S` | Tolerance result |
|---|---|---|---|---|---|---|---|---|
| `build_cell_cluster` | `cluster_compact` | `cluster_wave` | `network_efficiency` | `build_duration`, `future_convenience` | Neither dominates | `KEEP_BOTH` | `S_A=N_A+T_A+C_A`; `S_B=N_B+T_B+C_B` | Required `true` |
| `build_placenta_port` | `placenta_exchange` | `placenta_interface` | `network_efficiency` | `build_duration`, `future_convenience` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |
| `build_germ_layer_districts` | `layers_parallel` | `layers_staged` | `network_efficiency` | `build_duration`, `future_convenience` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |
| `build_heart_pump` | `heart_reinforced` | `heart_early_flow` | `network_efficiency` | `build_duration`, `future_convenience` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |
| `build_neural_network` | `neural_cranial` | `neural_distributed` | `network_efficiency` | `build_duration`, `future_convenience` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |
| `build_lung_exchange` | `lung_branching` | `lung_maturation` | `network_efficiency`, `future_convenience` | `build_duration` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |
| `build_pulmonary_interface` | `pulmonary_reserve` | `pulmonary_transition` | `network_efficiency`, `future_convenience` | `build_duration` | Neither dominates | `KEEP_BOTH` | Normalize per D8 and sum | Required `true` |

```text
for each decision:
    for each unordered option pair (a, b):
        a_scores = normalized_benefit_scores(a, TableD8)
        b_scores = normalized_benefit_scores(b, TableD8)
        a_dominates_b = all(a_scores[d] >= b_scores[d]) && any(a_scores[d] > b_scores[d])
        b_dominates_a = all(b_scores[d] >= a_scores[d]) && any(b_scores[d] > a_scores[d])
        S_a = sum(a_scores)
        S_b = sum(b_scores)
        balanced = abs(S_a - S_b) <= balance.build_options.validation.equal_weight_tolerance * max(S_a, S_b)
        assert a_dominates_b == false
        assert b_dominates_a == false
        assert balanced == true
```

T-06 must run this validation after concrete Balance values are added. Delete and synchronize a candidate across D1, D2, D5, D9, and D11 if it becomes strictly worse in all dimensions. If only equal-weight balance fails, redesign its resource mix or tier instead of hiding the problem with normalization weights.
