# Scripted Challenge Specification

Scripted challenges introduce an operation bottleneck only when the player has not already encountered that bottleneck through normal allocation and network behavior. Natural bottlenecks remain the primary path. A script may expose an existing E7 bottleneck type, but it may not create a fourth type, simulate pathology, increase difficulty for its own sake, or extend play time.

All challenge values are read from `balance.challenges.*`. No challenge uses a medical condition label, a random target, or an embedded intensity. Runtime selection is deterministic and recorded in the stage snapshot.

## Global injection contract

```text
scripted_challenge_eligible(challenge_id) =
    challenge_id in balance.challenges.enabled_ids
    && current_stage_id == balance.challenges.<challenge_id>.stage_id
    && challenge_id not in challenge_history.resolved_ids
    && challenge_id not in challenge_history.skipped_ids
    && balance.challenges.<challenge_id>.bottleneck_id
       not in challenge_history.natural_bottlenecks_seen
    && required_systems_active(challenge_id)
    && required_operation_decision_not_confirmed(challenge_id)
    && blocking_modal_open == false
```

When the E7 detector activates a bottleneck without `source == scripted_challenge`, add its ID to `challenge_history.natural_bottlenecks_seen`. If that happens before the matching scripted trigger, record the challenge in `skipped_ids` with reason `already_learned_naturally`. A skipped challenge is never rescheduled in another stage.

At most one scripted challenge can activate in a stage:

```text
assert count(active scripted challenges in current_stage_id)
       <= balance.challenges.max_injections_per_stage
assert count(challenge_history.injected_ids)
       <= balance.challenges.max_injections_total
```

Balance validation must lock `max_injections_per_stage` to one or less and `max_injections_total` to three or less. `stage_birth` must have an empty challenge list.

Every injection runs before the stage's required operation decision is confirmed. The normal operation controls and E7 map marker are visible before control returns to the player. Recovery never requires a knowledge hint, minigame reward, paid retry, or hidden interaction.

## Challenge C1: Transport pressure introduction

| Required field | Contract |
|---|---|
| Challenge ID | `transport_pressure_intro` |
| Stage | `balance.challenges.transport_pressure_intro.stage_id`, validated as `stage_origin` |
| Timing | First stable operation tick after the cell-cluster internal transport nodes become active and before `operate_cleavage_allocation` is confirmed |
| Injected E7 state | `balance.challenges.transport_pressure_intro.bottleneck_id`, validated as `transport_pressure` |
| Deterministic target | The active mutable edge with the highest utilization; break ties by ascending `edge_id` |
| Intensity | Apply `balance.challenges.transport_pressure_intro.capacity_multiplier` to the target edge and clamp the resulting pressure to `balance.challenges.transport_pressure_intro.pressure_target`; both remain configuration placeholders |
| Independent recovery | Select an operation option whose E6 effect improves transport, or apply the available E1 capacity intervention; no hint action is required |
| Clear condition | The complete E7 `transport_pressure` recovery condition is true and the target edge no longer carries the scripted multiplier |
| Intended causal understanding | When demand approaches network capacity, coverage falls and pressure rises; changing allocation or capacity relieves the same measured bottleneck |

Before release, T-06 must prove that baseline stage-one production can afford at least one recovery path and that the path reaches the recovery line within `balance.challenges.transport_pressure_intro.max_recovery_ticks`. The temporary multiplier is removed atomically when recovery succeeds; removing it alone must not force the detector to report recovery if actual pressure remains high.

## Challenge C2: Waste accumulation introduction

| Required field | Contract |
|---|---|
| Challenge ID | `waste_accumulation_intro` |
| Stage | `balance.challenges.waste_accumulation_intro.stage_id`, validated as `stage_harbor` |
| Timing | First stable tick after the placental exchange node and at least one germ-layer district become active, before `operate_placental_transport` is confirmed |
| Injected E7 state | `balance.challenges.waste_accumulation_intro.bottleneck_id`, validated as `waste_accumulation` |
| Deterministic target | Active organ with the highest `organ_waste_generation - waste_processing`; break ties by ascending `organ_id` |
| Intensity | Add `balance.challenges.waste_accumulation_intro.waste_delta` and apply `balance.challenges.waste_accumulation_intro.processing_multiplier` to the target, clamped by the E8 waste range |
| Independent recovery | Select an E6 option that improves waste processing and allow normal processing ticks to run |
| Clear condition | The complete E7 `waste_accumulation` recovery condition is true and the scripted processing multiplier has expired |
| Intended causal understanding | Waste rises when production exceeds transport and processing; increasing processing support reverses the net rate before lowering the stored amount |

T-06 must prove recovery without minigame rewards within `balance.challenges.waste_accumulation_intro.max_recovery_ticks`. The injected amount must be at or below `balance.challenges.waste_accumulation_intro.maximum_self_recoverable_delta`, derived from baseline processing capacity rather than entered as an unrelated constant.

## Challenge C3: Low signal coverage introduction

| Required field | Contract |
|---|---|
| Challenge ID | `signal_coverage_intro` |
| Stage | `balance.challenges.signal_coverage_intro.stage_id`, validated as `stage_circulation` |
| Timing | First stable tick after `build_neural_network` becomes active and before `operate_circulation_signal_priority` is confirmed |
| Injected E7 state | `balance.challenges.signal_coverage_intro.bottleneck_id`, validated as `signal_coverage_low` |
| Deterministic target | Required neural-system organ with the lowest delivered-to-required signal ratio; break ties by ascending `organ_id` |
| Intensity | Apply `balance.challenges.signal_coverage_intro.delivery_multiplier` and clamp the resulting coverage to `balance.challenges.signal_coverage_intro.coverage_target` |
| Independent recovery | Select an E6 option that improves delivered development signal and resolve any transport pressure on the located path |
| Clear condition | The complete E7 `signal_coverage_low` recovery condition is true and every required neural target meets its recovery ratio |
| Intended causal understanding | Developmental signaling depends on both signal allocation and a working delivery route; improving only the planned amount cannot compensate for blocked transport |

The normal E11 neural-tube knowledge hint may explain the science after feedback, but challenge recovery cannot read whether that hint was opened. T-06 must prove baseline recovery within `balance.challenges.signal_coverage_intro.max_recovery_ticks` with all minigame rewards set to zero.

## Final-stage exclusion

`balance.challenges.by_stage.stage_birth` must be empty. No scripted negative state may activate during the whole-body birth check, birth transition, first breath, or ending. A challenge still active when stage-three exit is requested blocks exit through its existing E7 state; it is never carried into stage four and never silently cleared.

## Acceptance and redundancy review

| Challenge | E7 bottleneck type | Has the type appeared naturally before trigger? | Runtime action | Redundant injection verdict |
|---|---|---|---|---|
| `transport_pressure_intro` | `transport_pressure` | Read `transport_pressure in challenge_history.natural_bottlenecks_seen` | If true, record `already_learned_naturally`; otherwise inject C1 | Not redundant because a prior natural encounter always cancels it |
| `waste_accumulation_intro` | `waste_accumulation` | Read `waste_accumulation in challenge_history.natural_bottlenecks_seen` | If true, record `already_learned_naturally`; otherwise inject C2 | Not redundant because a prior natural encounter always cancels it |
| `signal_coverage_intro` | `signal_coverage_low` | Read `signal_coverage_low in challenge_history.natural_bottlenecks_seen` | If true, record `already_learned_naturally`; otherwise inject C3 | Not redundant because a prior natural encounter always cancels it |

Acceptance requires all of the following:

- The configured total is no more than three and no stage contains more than one.
- `stage_birth` contains zero scripted challenges.
- Every injected `bottleneck_id` is exactly one of the three E7 IDs.
- Each independent recovery simulation succeeds without opening a hint or granting a minigame reward.
- A test that first produces each bottleneck naturally records the matching challenge as skipped and observes no scripted state change.
- Replaying a stage from its snapshot reproduces the same injected or skipped record without a second injection.
