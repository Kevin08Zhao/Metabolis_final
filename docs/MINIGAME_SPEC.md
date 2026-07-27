# Minigame Framework Specification

This document is the single source of truth for the three task minigames: their
mechanics, rating rules, reward ceiling, and failure handling. The main loop of
*Metabolis: City of Life — Birth* is building and operating. Minigames are content
garnish and a partial resource source, capped at twenty percent of operating time.

The first playable version contains exactly three runs, and their distribution is
locked by `docs/CHAPTER_TIMELINE.md`: prototype A "cell division" in stage one,
prototype B "material transport" in stage two, prototype C "signal transfer" in
stage three, and none in stage four. A player who skips every minigame must still
be able to reach birth, satisfy every completion condition, and see the full
ending.

Every tunable value is read through `balance.minigames.*`. This specification
defines configuration paths, formulas, and required inequalities; it does not
embed balance constants. The single exception is the per-run duration limit, whose
value is fixed at sixty seconds by the operating-time budget and is stated here as
a hard constraint on T-06.

Output tables are numbered M1 through M7. Downstream tasks must reference them by
number rather than pasting this document wholesale.

- T-19a reads the runtime contract from M2, the rating contract from M3, the
  failure contract from M5, and the skip contract from M6.
- T-29b reads the task panel states from M1 and M6.
- T-06 reads every configuration key from M7 and must satisfy the inequalities in
  M4 and the acceptance calculation at the end of this document.

## Table M1: Fixed distribution, identifiers, and task levels

| `stage_id` | `minigame_id` | Prototype | Task level | Duration limit |
|---|---|---|---|---|
| `stage_origin` | `minigame_cell_division` | A · cell division | `tutorial` | `balance.minigames.minigame_cell_division.duration_limit_sec` |
| `stage_harbor` | `minigame_material_transport` | B · material transport | `standard` | `balance.minigames.minigame_material_transport.duration_limit_sec` |
| `stage_circulation` | `minigame_signal_transfer` | C · signal transfer | `standard` | `balance.minigames.minigame_signal_transfer.duration_limit_sec` |
| `stage_birth` | `null` | None | Not applicable | Not applicable |

Task levels are exactly two: `tutorial` and `standard`. A challenge level and a
comprehensive level must not be designed, configured, or reserved as future keys.
Stage one is the tutorial chapter of `docs/CHAPTER_TIMELINE.md`, so its run is the
only `tutorial` level entry; stages two and three are `standard`.

All three `duration_limit_sec` values are fixed at sixty. This is a hard upper
bound derived from the operating-time budget, not a suggestion, and it must not be
raised to a two-to-five-minute range. When the timer reaches the limit the run
ends immediately and is rated on the progress achieved so far; a timeout is an
ordinary rating outcome, not a separate failure category.

Stage four has no minigame. `minigame_id` is `null` there and the task entry point
is not rendered at all, rather than rendered in a disabled state.

## Table M2: The three prototypes

Each prototype states five things, as required: the biological process it
represents, the player operation, the goal determination, the difficulty setting
that is completable within sixty seconds, and its relationship to the build
decision of its own stage.

| Item | Prototype A · `minigame_cell_division` | Prototype B · `minigame_material_transport` | Prototype C · `minigame_signal_transfer` |
|---|---|---|---|
| **Biological process represented** | Cleavage of the fertilized egg: one cell divides repeatedly into an increasingly dense cluster, with divisions timed rather than simultaneous. Matches item 1 of stage one. | Material exchange across the placental foundation: nutrients and materials move from the maternal-fetal interface along a transport route to the structures that consume them. Matches item 2 of stage two. | Propagation of developmental signals along the neural tube foundation towards its cranial and caudal targets. Matches item 5 of stage three. |
| **Player operation** | The player taps a cell that is ready to divide, at the moment its readiness indicator fills. Correct timing splits it into two daughter cells; the cluster grows. | The player assigns each arriving material packet to one of the open delivery lanes, so that packets reach the district that requests that material. | The player relays a travelling signal pulse by tapping the next node before the pulse decays, keeping a continuous chain from origin to target. |
| **Goal determination** | `accuracy = completed_divisions / balance.minigames.minigame_cell_division.goal.target_divisions`, where a division counts only if the tap fell inside the readiness window. The run resolves when the target is reached or the timer expires. | `accuracy = correct_deliveries / balance.minigames.minigame_material_transport.goal.target_deliveries`. A delivery counts only when the packet type matches the receiving district's request. | `accuracy = relayed_nodes / balance.minigames.minigame_signal_transfer.goal.target_nodes`, counted along the longest unbroken chain of the run. A broken chain restarts the count from the origin; earlier chains are retained for the maximum. |
| **Difficulty setting completable within sixty seconds** | The readiness window and the interval between readiness events are read from `balance.minigames.minigame_cell_division.difficulty.<difficulty_tier>`. T-06 must satisfy `target_divisions * (readiness_interval_sec + readiness_window_sec) <= duration_limit_sec * balance.minigames.validation.completion_headroom`. | Packet arrival interval and lane count come from `balance.minigames.minigame_material_transport.difficulty.<difficulty_tier>`. T-06 must satisfy `target_deliveries * packet_interval_sec <= duration_limit_sec * balance.minigames.validation.completion_headroom`. | Pulse decay time and node spacing come from `balance.minigames.minigame_signal_transfer.difficulty.<difficulty_tier>`. T-06 must satisfy `target_nodes * node_step_sec <= duration_limit_sec * balance.minigames.validation.completion_headroom`. |
| **Relationship to the stage's build decision** | Thematically previews `build_cell_cluster`: both are about how a cell cluster becomes dense. It grants no information about which candidate is better and does not gate the decision. | Thematically previews `operate_placental_transport` and the exchange trunk of `build_placenta_port`. It does not reveal candidate metrics and does not gate the decision. | Thematically previews `build_neural_network` and the signal coverage metric of the operation loop. It does not reveal candidate metrics and does not gate the decision. |

`completion_headroom` is a unitless factor strictly below one, so that the target
of every prototype is reachable inside the sixty-second limit with time to spare
rather than exactly at the buzzer.

`difficulty_tier` is a runtime state of the minigame only. It takes the values
`base` and `eased`, is set exclusively by the repeated-failure rule in M5, and
resets to `base` on every fresh stage entry. It is not a task level, is never shown
as a difficulty choice, and never persists into the save.

## Table M3: Rating

Rating uses exactly three criteria. Nothing else may enter the calculation.

| Criterion | Runtime field | Source | Direction |
|---|---|---|---|
| Completion accuracy | `completion_accuracy` | The `accuracy` formula of the prototype in M2, clamped to `balance.normalized.min` and `balance.normalized.max` | Higher is better |
| Completion efficiency | `completion_efficiency` | `clamp((duration_limit_sec - elapsed_sec) / duration_limit_sec, balance.normalized.min, balance.normalized.max)`, evaluated at the moment the goal resolves | Higher is better |
| Hint usage count | `hint_usage_count` | Number of in-minigame hints the player opened during the run, an integer counter | Lower is better |

Resource loss and body stability are explicitly **not** rating inputs. Those two
belong to the operation loop and are governed by tables E3 and E4 of
`docs/OPERATION_SPEC.md`. A minigame run must never read or write
`stability`, `waste`, `transport_pressure`, or `signal_coverage`.

```text
rating_score =
    balance.minigames.rating.weights.accuracy * completion_accuracy
    + balance.minigames.rating.weights.efficiency * completion_efficiency
    - balance.minigames.rating.weights.hint_penalty * min(
        hint_usage_count,
        balance.minigames.rating.hint_penalty_cap
      ) / max(balance.minigames.rating.hint_penalty_cap, 1)

stars = star_tier(rating_score, balance.minigames.rating.star_thresholds)
```

`star_tier` maps the score onto the ascending thresholds and returns the count of
thresholds met. The result is emitted through `minigame_rated(minigame_id, stars,
rating_detail)` in `docs/EVENT_API.md`. The keys of `rating_detail` are fixed by
this table and are exactly `completion_accuracy`, `completion_efficiency`, and
`hint_usage_count`; no fourth key may be added.

A skipped run produces no rating and does not emit `minigame_rated`. It emits only
`minigame_exited` with `resolution` set to the skipped value.

## Table M4: Rewards and the reward ceiling

| Reward component | Configuration path | Enters build cost |
|---|---|---|
| Nutrient energy | `balance.minigames.<minigame_id>.reward.nutrient_energy` | Yes |
| Cell material | `balance.minigames.<minigame_id>.reward.cell_material` | Yes |
| Development signal | `balance.minigames.<minigame_id>.reward.development_signal` | Yes |
| Knowledge badges | `balance.minigames.<minigame_id>.reward.knowledge_badge_count` | No |
| Star scaling | `balance.minigames.<minigame_id>.reward.star_multiplier[stars]` | Applied to the three spendable components only |

Rewards are added during `Phase.RESOURCE_SETTLEMENT` of the same stage, as defined
by the `resolve_optional_minigame` row of `docs/GAME_RULES.md`. A skipped run adds
nothing.

The reward magnitude of each stage must stay below three tenths of that stage's
build cost. The comparison uses the cheapest affordable path so the bound is strict
under every candidate choice:

```text
stage_reward_max(stage_id) =
    max over stars of sum over r in [nutrient_energy, cell_material, development_signal] of
        balance.minigames.<minigame_id>.reward[r]
        * balance.minigames.<minigame_id>.reward.star_multiplier[stars]

stage_build_cost_floor(stage_id) =
    sum over decision_id in StageDefinition[stage_id].required_build_decision_ids of
        min over option_id in decision_id of
            sum over r in [nutrient_energy, cell_material, development_signal] of
                balance.build_options.<decision_id>.<option_id>.cost[r]

assert stage_reward_max(stage_id)
       <  balance.minigames.validation.reward_cost_ratio_max
          * stage_build_cost_floor(stage_id)
```

`balance.minigames.validation.reward_cost_ratio_max` must itself be at most three
tenths. The assertion is evaluated for `stage_origin`, `stage_harbor`, and
`stage_circulation`. `stage_birth` has no minigame and is excluded. Knowledge badges
are outside the comparison because they are counted only and cannot be spent on
building, as fixed by `docs/CONTEXT.md`.

If T-06 cannot satisfy this assertion, the correct fix is to lower the reward, never
to raise `reward_cost_ratio_max`.

## Table M5: Failure handling

All six failure rules are retained in full. Their scope is strictly inside the
minigame; none of them may reach city state.

| Rule | Contract | Runtime effect |
|---|---|---|
| No regression | A failed run never rolls back stage progress, resource totals, confirmed decisions, or the timeline node | The city state at exit equals the city state at entry, minus nothing |
| Organ never removed | A failed run never deletes, downgrades, or un-builds any organ or transport edge | `occupied_cells`, `active_organ_ids`, and `active_transport_edge_ids` are untouched |
| No death ending | A failed run never produces a game-over, a death state, or an alternative ending | The ending path stays governed by `final_completion_ready` in `docs/CHAPTER_TIMELINE.md` |
| Reason stated | The result panel names the specific reason, drawn from `balance.minigames.failure.reason_codes` | Reasons cover timeout, target not reached, and chain broken; "you failed" alone is not acceptable |
| Immediate retry | The player may restart the run at once, with no cooldown, no cost, and no tick advance | Retry count is `balance.minigames.failure.max_retries_per_stage`; the entry closes only when the player skips or accepts a result |
| Difficulty eased after repeated failures | After `balance.minigames.failure.failures_before_ease` consecutive failures in one stage, `difficulty_tier` moves from `base` to `eased` | `eased` widens windows and lowers targets through `difficulty.eased`; it never changes the rating formula or the reward ceiling |

Rewards are granted from the accepted result only, so retries cannot be farmed for
repeated rewards. A run that ends in `eased` tier is rated by the same M3 formula;
the specification does not add a penalty for having been eased.

## Table M6: Skip and non-prerequisite guarantees

| Guarantee | Enforcement point |
|---|---|
| The skip entry is available whenever the task entry is available | `resolve_optional_minigame` accepts the skipped result as a valid `requested_minigame_result` in `docs/GAME_RULES.md` |
| A minigame is never a prerequisite for building any organ | `confirm_build_decision` preconditions in `docs/GAME_RULES.md` contain no minigame term, and this specification adds none |
| A minigame is never a prerequisite for advancing a stage | `stage_exit_ready` and `final_completion_ready` in `docs/CHAPTER_TIMELINE.md` contain no minigame term |
| A minigame is never a prerequisite for an operation decision | `confirm_operation_decision` preconditions contain no minigame term |
| Skipping every run still reaches the ending | Guaranteed by the zero-reward acceptance calculation at the end of this document, together with table E5 of `docs/OPERATION_SPEC.md` |
| A minigame never writes city state | A run reads and writes only its own runtime fields; resource changes happen exclusively through the reward path in M4 during resource settlement |

## Table M7: Configuration keys

| Path | Meaning |
|---|---|
| `balance.minigames.<minigame_id>.duration_limit_sec` | Per-run hard limit, fixed at sixty for all three |
| `balance.minigames.<minigame_id>.task_level` | `tutorial` or `standard`; no other value is legal |
| `balance.minigames.<minigame_id>.goal.*` | Per-prototype target quantity used by the accuracy formula in M2 |
| `balance.minigames.<minigame_id>.difficulty.base.*` | Timing and density parameters at base tier |
| `balance.minigames.<minigame_id>.difficulty.eased.*` | Same fields at eased tier |
| `balance.minigames.<minigame_id>.reward.*` | The four reward components and the star multiplier table |
| `balance.minigames.rating.weights.*` | Accuracy weight, efficiency weight, hint penalty weight |
| `balance.minigames.rating.hint_penalty_cap` | Upper bound on the hint count that affects the score |
| `balance.minigames.rating.star_thresholds` | Ascending thresholds mapping score to stars |
| `balance.minigames.failure.reason_codes` | Reason codes shown on the result panel |
| `balance.minigames.failure.max_retries_per_stage` | Retry allowance inside one stage |
| `balance.minigames.failure.failures_before_ease` | Consecutive failures that move the tier to `eased` |
| `balance.minigames.validation.completion_headroom` | Unitless factor below one, guaranteeing the target fits inside the limit |
| `balance.minigames.validation.reward_cost_ratio_max` | Reward ceiling ratio, at most three tenths |

## Acceptance: zero-reward sufficiency calculation

The required check is whether the four stages' own city production still lets every
organ reach baseline specification when all three minigame rewards are zeroed. The
procedure below is executable and must be run by T-06 once concrete Balance values
exist.

```text
zero_reward_sufficiency():
    for minigame_id in [minigame_cell_division,
                        minigame_material_transport,
                        minigame_signal_transfer]:
        for r in [nutrient_energy, cell_material, development_signal,
                  knowledge_badge_count]:
            balance.minigames.<minigame_id>.reward[r] = balance.validation.zero_reward

    carried = starting_resources(balance.resources.<r>.initial)

    for stage_id in [stage_origin, stage_harbor, stage_circulation, stage_birth]:
        ticks = balance.chapters.<stage_id>.tick_count

        produced[r] = ticks * (
            balance.resources.<r>.per_tick_output
            + sum over organ_id in active_organ_ids of
                  balance.organs.<organ_id>.per_tick_output[r]
        )
        consumed[r] = ticks * sum over organ_id in active_organ_ids of
                  balance.organs.<organ_id>.per_tick_consumption[r]

        available[r] = carried[r] + produced[r] - consumed[r]

        required[r] = sum over decision_id in
                      StageDefinition[stage_id].required_build_decision_ids of
                          min over option_id in decision_id of
                              balance.build_options.<decision_id>.<option_id>.cost[r]

        assert available[r] >= required[r]           # per stage, per resource

        carried[r] = available[r] - required[r]
                     - operation_cost(stage_id)[r]

    assert baseline_birth_check_passes()             # table E5 of OPERATION_SPEC
```

`baseline_birth_check_passes()` is the check table E5 of `docs/OPERATION_SPEC.md`
already assigns to T-06: all four birth thresholds must hold with every organ at
`baseline` tier and every minigame reward set to `balance.validation.zero_reward`.
This specification deliberately reuses that key instead of introducing a second
zero-reward validation path.

**Current result.** `docs/BALANCE.json` does not exist yet — T-06 has not run — so
the assertions above cannot be evaluated numerically today. What this specification
fixes is the shape of the check and the direction of the remedy. The structural
conclusion already holds: because the reward ceiling in M4 keeps every stage's
reward strictly below three tenths of that stage's cheapest build cost, zeroing the
rewards can remove at most three tenths of one stage's build budget, and the
remaining seven tenths must come from city production either way. Minigames are
therefore a top-up, never a load-bearing supply.

**Remedy direction when an assertion fails.** If `available[r] >= required[r]` fails
for some stage and resource, raise the production of that specific stage — that is,
`balance.resources.<r>.per_tick_output` or the corresponding
`balance.organs.<organ_id>.per_tick_output[r]` for organs active in that stage — or
raise `balance.chapters.<stage_id>.tick_count`. Do **not** raise any
`balance.minigames.<minigame_id>.reward.*` value. Raising the reward would both
violate the M4 ceiling and make an optional, skippable activity load-bearing, which
contradicts the twenty-percent weight cap and the skip guarantee in M6.
