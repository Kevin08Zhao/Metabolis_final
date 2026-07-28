# Event and Signal API

This file is the **single mount point** through which animation and audio attach to
*Metabolis: Birth of the City of Life*. Every animation, sound effect, and UI reaction
must hang off an event defined here; moments outside this list offer no mount point.

Every event derives from [`docs/GAME_RULES.md`](GAME_RULES.md) — the six player
actions and their immediate effects, delayed effects, visible feedback, and
rejection feedback — and from the ten-step core loop in
[`docs/CONTEXT.md`](CONTEXT.md). Moments that do not exist in the rules table must
not receive an event here.

## Conventions

- **Naming**: follows the "event and signal names" category of the naming
  conventions in `docs/CONTEXT.md`. Template is `{subject}_{past_tense}`, all
  lowercase `snake_case`, stating a fact that already happened, at most three
  words long.
- **Parameters**: always fully type-annotated. `StringName` for identifiers, `int`
  for enum ordinals and counts, `float` for continuous values and durations in
  seconds, `Dictionary` for grouped values whose key set is defined by a
  downstream spec.
- **Keys of grouped values**: keys of `spent`, `deltas`, and `totals` are the
  internal variable names of the six resources in `docs/CONTEXT.md`. Keys of
  `outcome`, `rating_detail`, `carryover`, and `snapshot` are defined by the
  corresponding downstream spec (noted per row); this file does not presume them.
- **Enums**: `phase` is the `Phase` enum from `docs/GAME_RULES.md`; `resolution`
  comes from `MinigameResolution` / `MinigameResult`; `*_band` is the ordinal of
  the three stability bands. This file only references them, it does not redefine
  them.
- The **Frequency** column takes exactly four values: `once per run`,
  `once per stage`, `at most once per tick`, `repeatable within one tick`. Any
  event marked `repeatable within one tick` must be handled by listeners that can
  take several callbacks in a single frame — animations have to queue or coalesce,
  and no listener may assume a settlement delivers only one.
- Events describe only what happened. They carry no UI node references and do not
  prescribe a receiver. The animation and audio columns are **suggestions**:
  implementers may swap the asset names, but must not move the mount point.

---

## 1 · Stage advance and snapshot write

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `stage_advanced` | The instant `advance_to_next_stage` passes its preconditions, locks the stage inputs, **generates** the carryover record, and switches the flow to `Phase.STAGE_TRANSITION`. Generation is not persistence; see `stage_snapshot_written` | `from_stage_id: StringName`, `to_stage_id: StringName` | once per stage | `stage_transition_wipe`; the current node of `DevelopmentTimeline` slides to the next stage | `sfx_stage_advance` |
| `stage_loaded` | Transition finished, the stage behind `next_stage_id` is fully loaded, and the playable area accepts input again | `stage_id: StringName`, `stage_index: int` | once per stage | `stage_intro_fade` fades the city map in | `bgm_stage_theme` track switch |
| `stage_snapshot_written` | The atomic save transaction of table F2 in `docs/CARRYOVER_SPEC.md` has committed. Per F2 this happens when the entered stage is reached **for the first time**, so the event fires after `stage_loaded`, not during the transition. One transaction writes both `chapter_snapshots[snapshot_stage_id].operation_start_conditions` and `current_city_state.operation_start_conditions`; the event marks its commit | `snapshot_stage_id: StringName` (the stage whose `chapter_snapshots` entry was written, i.e. the stage just entered), `snapshot: Dictionary` (the three `operation_start_conditions` fields of table F1) | once per stage (three times across the run; never on `stage_origin`, which has no producing predecessor, and never on replay — see below) | Carryover rows settle into place in `StageSummaryPanel` | `sfx_snapshot_write` (light; must not cover the transition) |
| `phase_changed` | Any time `Phase` changes. Preconditions of all six actions in `docs/GAME_RULES.md` lead with `phase` | `previous_phase: int`, `current_phase: int` | at most once per tick | No animation of its own; used to close the previous phase panel and open the next | None |

**Generation versus persistence.** `advance_to_next_stage` in `docs/GAME_RULES.md`
generates the carryover record as an immediate effect, while table F2 of
`docs/CARRYOVER_SPEC.md` commits it when the next stage is entered for the first
time. These are two distinct moments and only the second one is an event.
Listeners must not treat `stage_advanced` as proof that anything reached the save.

**Replay.** In replay mode the T-19h rule of `docs/CARRYOVER_SPEC.md` reads the
stored record straight out of `chapter_snapshots` and recalculates nothing, so no
snapshot write occurs and `stage_snapshot_written` does **not** fire.
`carryover_applied` still fires, carrying the values read from the snapshot. This
is the distinction T-26, T-27, and T-28 rely on.

## 2 · Build options presented, selected, construction started, construction complete

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `build_options_presented` | `Phase.BUILD_DECISION` is entered and `available_build_option_ids` and `available_build_slot_ids` have been populated | `decision_id: StringName`, `option_ids: Array[StringName]`, `slot_ids: Array[StringName]` | once per stage (stage one is the tutorial; seven times across the run) | `build_card_deal` unfolds the option cards in sequence; `BuildSlotOverlay` breathes on candidate slots | `sfx_build_options_open` |
| `build_decision_confirmed` | The instant `confirm_build_decision` passes its preconditions, deducts resources, locks option and slot, and writes into `confirmed_build_decision_ids`. Irreversible once confirmed | `decision_id: StringName`, `option_id: StringName`, `slot_id: StringName`, `spent: Dictionary` | once per stage (seven times across the run) | `BuildSlotOverlay` keeps only the chosen slot and locks the confirm button; the three resource readouts in `ResourceBar` roll down | `sfx_build_confirm` |
| `organ_construction_started` | The organ blueprint is generated and enters the under-construction state; immediately follows `build_decision_confirmed` | `organ_id: StringName`, `slot_id: StringName`, `option_id: StringName` | once per stage (seven times across the run) | `organ_blueprint_construct` fills the blueprint cell by cell | `sfx_build_start` (may be merged into a single playback with `sfx_build_confirm`) |
| `organ_built` | During `Phase.BUILD_COMPLETION`, the organ turns from under-construction to complete and the transport network has finished extending along the chosen routing | `organ_id: StringName`, `slot_id: StringName`, `option_id: StringName` | repeatable within one tick (both build decisions of a stage may complete in the same settlement tick) | `organ_build_complete` locks in the organ art; `transport_route_extend` extends the transport roads | `sfx_build_complete` |

## 3 · Operation decisions and resource priority changes

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `resource_priority_changed` | The player alters the priority allocation in `OperationPanel` and `allocation_total` has been recomputed. This is a parameter change inside one action transaction, not a separate player action | `decision_id: StringName`, `allocation: Dictionary`, `allocation_total: float` | repeatable within one tick (continuous dragging fires repeatedly) | The `AllocationMeter` needle tracks the value; the scale turns red on shortfall or overflow | `sfx_allocation_tick` (must be throttled to one playback per tick) |
| `operation_decision_confirmed` | The instant `confirm_operation_decision` passes its preconditions, deducts resources, locks the operation plan, and writes into `confirmed_operation_decision_ids`. Irreversible once confirmed | `decision_id: StringName`, `operation_id: StringName`, `spent: Dictionary` | once per stage (four times across the run) | `operation_flow_pulse` locks the priority controls and pushes one pulse along the transport network; `CityStatusPanel` switches from forecast marker to pending-settlement marker | `sfx_operation_confirm` |
| `transport_network_intervened` | The instant `intervene_transport_network` passes its preconditions, the alternate routing takes effect, one route recomputation completes, and `transport_intervention_used` is set to `true` | `edge_id: StringName`, `plan_id: StringName`, `capacity: float` | once per stage (at most one intervention per stage) | `transport_route_reflow` redraws the chosen edge and updates its capacity badge; the development signal readout in `ResourceBar` drops | `sfx_transport_intervene` |
| `operation_result_settled` | During `Phase.SYSTEM_ACTIVATION`, transport pressure, waste, stability, and network efficiency have all been settled against the operation result | `decision_id: StringName`, `outcome: Dictionary` (keys defined by `docs/OPERATION_SPEC.md`) | once per stage | `operation_result_reveal` reveals each change on the city map in turn | `sfx_operation_settle` |
| `resources_settled` | `Phase.RESOURCE_SETTLEMENT` ends and the stage's available resources — including the minigame reward, excluded when skipped — are written into the resource pool | `stage_id: StringName`, `deltas: Dictionary`, `totals: Dictionary` | once per stage | `resource_counter_roll` rolls all six `ResourceBar` readouts to their new values | `sfx_resource_settle` |

## 4 · The three bottleneck types appearing and clearing

The three bottleneck types are fixed as transport pressure, waste buildup, and
signal coverage gap, matching the In scope section of `docs/CONTEXT.md`. Neither
additions nor removals are allowed. Each type has one appearance event and one
clearing event.

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `transport_pressure_appeared` | Transport pressure on a transport edge crosses the detection condition and the edge is judged a bottleneck for the first time | `edge_id: StringName`, `severity: float` | repeatable within one tick (several edges may cross in the same tick) | The edge in `TransportOverlay` switches to a congestion texture and keeps pulsing; `TransportPressureMeter` marks it | `sfx_bottleneck_transport` (only one playback even if several edges cross in a tick) |
| `transport_pressure_cleared` | The edge meets the recovery condition and leaves the bottleneck state | `edge_id: StringName` | repeatable within one tick | The congestion texture fades out and the edge returns to normal flow | `sfx_bottleneck_cleared` |
| `waste_buildup_appeared` | Waste buildup on an organ or district crosses the detection condition and is judged a bottleneck for the first time | `organ_id: StringName`, `severity: float` | repeatable within one tick | A waste layer appears over the area and darkens; the map marker is a shape, not a colour, so it reads without colour | `sfx_bottleneck_waste` (only one playback per tick regardless of count) |
| `waste_buildup_cleared` | The area meets the recovery condition and waste falls back below the detection threshold | `organ_id: StringName` | repeatable within one tick | The waste layer recedes cell by cell | `sfx_bottleneck_cleared` |
| `signal_gap_appeared` | Signal coverage on an organ or district crosses the detection condition and is judged a bottleneck for the first time | `organ_id: StringName`, `severity: float` | repeatable within one tick | The signal texture of the area turns into a blinking broken dashed line; the marker is a shape, not a colour | `sfx_bottleneck_signal` (only one playback per tick regardless of count) |
| `signal_gap_cleared` | The area meets the recovery condition and coverage is restored | `organ_id: StringName` | repeatable within one tick | The dashed line rejoins into a continuous line | `sfx_bottleneck_cleared` |

## 5 · Stability band change, waste overflow, investable resource shortage

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `stability_band_changed` | Stability crosses one of the two boundaries of the three display bands and exceeds the hysteresis margin. Fires only when the band truly changes; movement inside a band does not fire | `previous_band: int`, `current_band: int`, `stability: float` | at most once per tick | The stability widget in `ResourceBar` changes band as a whole, shape and label together | `sfx_stability_up` on rise, `sfx_stability_down` on fall |
| `waste_overflowed` | The instant waste reaches its cap and the stability penalty starts applying | `waste: float`, `stability_penalty: float` | at most once per tick | `waste_overflow_spill` maxes the waste readout and spills once past the city map edge; the stability widget presses down in sync | `sfx_waste_overflow` |
| `resource_shortage_raised` | One of the three investable resources — nutrient energy, cell material, development signal — falls below its shortage warning line | `resource_id: StringName`, `amount: float`, `threshold: float` | repeatable within one tick (all three may fall below in the same tick) | The item in `ResourceBar` flashes red and keeps a low-level marker | `sfx_resource_low` (only one playback per tick regardless of count) |
| `resource_shortage_cleared` | The resource climbs back above its shortage warning line | `resource_id: StringName`, `amount: float` | repeatable within one tick | The item stops flashing and the low-level marker is removed | None |

## 6 · Minigame entry, exit, and star rating

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `minigame_entered` | The `resolve_optional_minigame` transaction begins and the minigame scene takes input focus | `minigame_id: StringName`, `stage_id: StringName`, `time_limit_sec: float` | once per stage (three times across the run; stage four has none) | `minigame_panel_expand` expands the task panel to full screen | `sfx_minigame_enter`; the city BGM ducks |
| `minigame_exited` | `minigame_resolution` moves from `PENDING` to `SKIPPED` or `COMPLETED` and the stage's task entry point locks. Skip and completion share one event, distinguished by `resolution` | `minigame_id: StringName`, `resolution: int`, `elapsed_sec: float` | once per stage (three times across the run) | On completion `minigame_reward_fly` sends the reward to `ResourceBar`; on skip `minigame_panel_collapse` folds the panel. `TaskPanel` switches to "completed" or "skipped" | `sfx_minigame_complete` on completion, `sfx_minigame_skip` on skip; the city BGM returns |
| `minigame_rated` | On the completion path only, once the rating has been settled and the star count is known. The skip path does not fire | `minigame_id: StringName`, `stars: int`, `rating_detail: Dictionary` (keys defined by the rating criteria in `docs/MINIGAME_SPEC.md`) | at most once per stage (at most three times across the run) | `star_stamp` stamps the stars one at a time | `sfx_star_stamp`, pitched up per star |

## 7 · Knowledge unlock, system observation, carryover application

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `system_observation_started` | During `Phase.SYSTEM_ACTIVATION`, the organ activates and the demonstration of one collaboration with the existing systems begins | `organ_id: StringName`, `observation_id: StringName` | once per stage | `organ_activate_glow` lights the organ; the collaboration path advances segment by segment along the transport network | `sfx_organ_activate`; an ambient layer under the collaboration |
| `system_observation_ended` | The collaboration demonstration finishes playing and `system_observation_complete` is set to `true` | `organ_id: StringName`, `observation_id: StringName` | once per stage | The collaboration path converges and the city map returns to its normal loop | The ambient layer fades out |
| `knowledge_entry_unlocked` | The matching organ archive entry and timeline entry unlock and are written into `unlocked_knowledge_entry_ids` | `entry_id: StringName`, `organ_id: StringName`, `stage_id: StringName` | repeatable within one tick (one stage may unlock several entries at once) | A "new" badge appears on the timeline archive marker and pops once | `sfx_knowledge_unlock` (only one playback per tick regardless of count) |
| `knowledge_entry_opened` | `view_knowledge_archive` passes its preconditions and the archive detail opens. `first_read` is `true` when this call flips `is_read` from false to true | `entry_id: StringName`, `first_read: bool` | repeatable within one tick | `knowledge_card_unfold` expands `KnowledgeArchivePanel` to the entry; the "new" badge switches to "read" | `sfx_knowledge_open` |
| `knowledge_entry_closed` | The archive detail closes. Pairs with `knowledge_entry_opened`: opening the archive pauses operation time and resource settlement, so a listener needs a definite moment at which both resume, and the pause indicator has to come down. Added by T-30, which is the first task that can leave the game paused | `entry_id: StringName` (the entry that was open) | once per `knowledge_entry_opened`, and never without one | `knowledge_card_fold` collapses `KnowledgeArchivePanel`; the header pause symbol clears | `sfx_knowledge_close` |
| `season_completed` | All six completion conditions of the first season hold and the run has been frozen. Distinct from `birth_sequence_completed`, which marks only the ending picture starting; this marks the whole run being over, with the summary built | `summary: Dictionary` (the fields fixed by T-25; contains no score, rating, or title) | once per run | The ending screen with the summary and the teaching-model disclaimer | The ending theme settles; no new cue |
| `delayed_feedback_shown` | A carryover value first actually bites in the stage that received it — not when the stage opens. One per carryover field per stage at most. Renders in the same non-blocking container as the immediate knowledge hints of table E11, so it never interrupts an action | `carryover_field: StringName` (one of the three table F1 names), `source_stage_id: StringName` (the stage whose decisions produced it), `source_decision_ids: Array[StringName]` (that stage's build decisions, so the player can connect cause to effect) | at most once per carryover field per stage, so at most three times in a stage and never in stage one, which has no predecessor | The hint card slides into the shared container and dismisses itself | `sfx_knowledge_open`, the same cue the immediate hints use |
| `save_loaded` | A load attempt has finished, whichever way it went. Fires for a clean load, a version mismatch, a corrupt file, and no file at all, so a listener never has to poll to learn the outcome | `outcome: StringName` (`loaded`, `version_mismatch`, `corrupt`, or `absent`), `chapter_select_available: bool` (false whenever the snapshots were discarded or never read) | once per load attempt | The title screen shows the degradation explanation when the outcome is not `loaded`, and greys out chapter select when it is unavailable | None; a degraded load is not a failure to announce with a sting |
| `carryover_applied` | All three table F1 values have reached `current_city_state.operation_start_conditions` at their respective application positions — network efficiency before the first production tick, operating pressure after the base network is instantiated, waste after organs and waste routes are instantiated — and before the first E3 settlement tick of the entered stage. On a first visit it follows `stage_snapshot_written` in the same transaction; on replay it fires alone, carrying values read from `chapter_snapshots` | `from_stage_id: StringName`, `to_stage_id: StringName`, `carryover: Dictionary` (the three values of table F1 of `docs/CARRYOVER_SPEC.md`: `network_efficiency_coefficient`, `initial_operation_pressure`, `initial_waste_accumulation`) | once per stage (three times across the run; `stage_birth` produces no record for a successor, and `stage_origin` receives none) | The three carryover summary lines of `StageSummaryPanel` push into the new stage's starting readouts | `sfx_carryover_apply` |

## 8 · Action rejection

Each of the six actions in `docs/GAME_RULES.md` has a rejection feedback column,
and all of them take the same shape: a UI element shakes or flashes plus
`sfx_action_denied`. They differ only in which element takes focus and which reason
string is shown. Rejection is therefore collapsed into a single event parameterised
by those differences, rather than one event per action.

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `action_rejected` | The precondition of any of the six actions evaluates to `false` and no game state changes | `action_id: StringName` (one of the six internal action IDs), `reason_code: StringName` (the specific reason from the rejection column of the rules table), `focus_element: StringName` (the UI element that should shake or flash) | repeatable within one tick (rapid clicking fires repeatedly) | Determined by `focus_element`: red card border shake, red cross on a slot, red flash on a resource item, panel border flash, and so on | `sfx_action_denied` (must be throttled to one playback per tick) |

## 9 · Birth transition

The birth sequence is a system sequence with no player action in it, so it does
not appear in the rules table of `docs/GAME_RULES.md`. Its moments are defined by
three other accepted documents: `final_completion_ready` in
`docs/CHAPTER_TIMELINE.md`, the four birth checks of table E5 in
`docs/OPERATION_SPEC.md`, and the seven states and timeline of
`docs/BIRTH_STATES.md`. The events below mount on those.

`birth_state_changed` is the generic per-beat mount point, structurally the same
as `phase_changed`: listeners switch on `current_state` rather than expecting one
event per beat. It carries the beat's window so animation and audio can time
themselves without reading Balance.

| Event | Trigger moment | Parameters and types | Frequency | Suggested animation | Suggested audio |
|---|---|---|---|---|---|
| `birth_sequence_started` | The machine enters `ready_check`, whether from `start()` or from a player acknowledging a rollback. An attempt at the ending sequence has begun and the stage is closed to input from here | `stage_id: StringName`, `total_budget_ms: int` | once per attempt, not once per run. A rollback followed by a retry is a new attempt and fires it again, because input has to close again | The city map pulls back to the whole-body view; the UI recedes | `bgm_birth_sequence` replaces the stage track |
| `birth_state_changed` | Every accepted transition of the birth machine, emitted from `transition_to`. `window_ms` is the beat's length on the 45-second timeline and is zero for `ready_check` and `failure_rollback`, which carry no window | `previous_state: int`, `current_state: int`, `window_ms: int` | once per run per beat | Determined by `current_state`, per table B1 of `docs/BIRTH_STATES.md`. Each beat must finish inside `window_ms` | One cue per beat, keyed the same way |
| `birth_sequence_completed` | The machine enters `ending`, which is terminal. Success cannot be revoked afterwards | `stage_id: StringName` | once per run | The ending picture settles and holds | `sfx_first_breath`, then the ending theme |
| `birth_rolled_back` | The machine enters `failure_rollback`, either because a birth check failed at the gate or because a beat lost its precondition. Never an ending: the machine returns to `ready_check` on acknowledgement | `from_state: int`, `reason_code: StringName` | repeatable within one tick is not possible; at most once per attempt | The sequence unwinds to the pre-birth city view; no failure imagery | `sfx_birth_rollback`, restrained; this is a retry prompt, not a loss |

`birth_rolled_back` must not be presented as a death, a game over, or a lost run.
`docs/OPERATION_SPEC.md` guarantees that a failed check never locks the flow, and
`docs/BIRTH_STATES.md` routes rollback back to the gate for exactly that reason.

Illegal transitions inside the machine do not get their own event. They reuse
`action_rejected` from section 8 with `action_id` set to `birth_transition`, which
fits without stretching its meaning.

---

## Retired events that must not be reintroduced

The four event families below belong to the retired maintenance gameplay. This list
does not define them, and implementers must not add them back.

| Retired event family | Disposition |
|---|---|
| Manual route connection | Retired. The transport network **extends automatically** along the routing chosen in the build decision; the player does not draw lines. Only `transport_network_intervened`, at most once per stage, remains. |
| Supply testing | Retired. Supply outcomes are presented directly by `resources_settled` and `operation_result_settled`; there is no separate test action. |
| Maintenance choice | Retired. The old maintenance phase (T-23) is void and its slot is taken by the operation decision, whose event is `operation_decision_confirmed`. |
| Maintenance delayed effect | Retired. Delayed consequences are carried entirely by `operation_result_settled` and `carryover_applied`. |

## Cross-check: rules-table feedback moments against events

Used for acceptance: every moment in the "visible feedback" and "rejection
feedback" columns of `docs/GAME_RULES.md` has a mount point in this list.

| Rules-table action | Feedback moment | Event |
|---|---|---|
| `resolve_optional_minigame` | Entering the task | `minigame_entered` |
| `resolve_optional_minigame` | `TaskPanel` switches to completed/skipped, `minigame_reward_fly` / `minigame_panel_collapse` | `minigame_exited` |
| `resolve_optional_minigame` | Star rating settlement | `minigame_rated` |
| `resolve_optional_minigame` | Reward added during resource settlement | `resources_settled` |
| `resolve_optional_minigame` | `TaskPanel` shake plus `sfx_action_denied` | `action_rejected` |
| `confirm_build_decision` | Options and slots presented | `build_options_presented` |
| `confirm_build_decision` | `organ_blueprint_construct` plus `sfx_build_confirm` | `build_decision_confirmed`, `organ_construction_started` |
| `confirm_build_decision` | `organ_build_complete` plus `sfx_build_complete` | `organ_built` |
| `confirm_build_decision` | Red border shake / red cross / resource flash | `action_rejected` |
| `confirm_operation_decision` | Priority controls change | `resource_priority_changed` |
| `confirm_operation_decision` | `operation_flow_pulse` plus `sfx_operation_confirm` | `operation_decision_confirmed` |
| `confirm_operation_decision` | `operation_result_reveal` plus `sfx_operation_settle` | `operation_result_settled` |
| `confirm_operation_decision` | `AllocationMeter` shortfall or overflow, resource flash | `action_rejected` |
| `intervene_transport_network` | `transport_route_reflow` plus `sfx_transport_intervene` | `transport_network_intervened` |
| `intervene_transport_network` | Broken-line marker, unlock tick mark, forbidden icon | `action_rejected` |
| `view_knowledge_archive` | Archive unlock, new timeline entry | `knowledge_entry_unlocked` |
| `view_knowledge_archive` | `knowledge_card_unfold` plus `sfx_knowledge_open`, badge switches to read | `knowledge_entry_opened` |
| `view_knowledge_archive` | `knowledge_card_fold` plus `sfx_knowledge_close`, the header pause symbol clears | `knowledge_entry_closed` |
| `view_knowledge_archive` | Lock icon shake | `action_rejected` |
| `advance_to_next_stage` | System collaboration observation | `system_observation_started`, `system_observation_ended` |
| `advance_to_next_stage` | `stage_transition_wipe` plus `sfx_stage_advance`, timeline node moves. The carryover record is generated here but not yet persisted | `stage_advanced` |
| `advance_to_next_stage` | Next stage loads, timeline switches to the next node | `stage_loaded` |
| `advance_to_next_stage` | Carryover record committed to `chapter_snapshots` on a first visit | `stage_snapshot_written` |
| `advance_to_next_stage` | Carryover written into the new stage's starting conditions | `carryover_applied` |
| `advance_to_next_stage` | Incomplete steps marked red, advance button shakes | `action_rejected` |
| All actions | Panel open/close driven by phase changes | `phase_changed` |
| City self-operation | Stability band change, waste overflow, resource shortage | `stability_band_changed`, `waste_overflowed`, `resource_shortage_raised` / `_cleared` |
| City self-operation | The three bottleneck types appearing and clearing | The six events in section 4 |

The birth sequence has no row here because it has no row in the rules table. Its
sources are named at the top of section 9.

---

## GDScript signal declarations

The thirty-nine lines below can be pasted straight into
`src/autoload/event_bus.gd`. Parameter types are complete, with nothing elided.

```gdscript
# 1 · Stage advance and snapshot write
signal stage_advanced(from_stage_id: StringName, to_stage_id: StringName)
signal stage_loaded(stage_id: StringName, stage_index: int)
signal stage_snapshot_written(snapshot_stage_id: StringName, snapshot: Dictionary)
signal phase_changed(previous_phase: int, current_phase: int)

# 2 · Build options presented, selected, construction started, construction complete
signal build_options_presented(decision_id: StringName, option_ids: Array[StringName], slot_ids: Array[StringName])
signal build_decision_confirmed(decision_id: StringName, option_id: StringName, slot_id: StringName, spent: Dictionary)
signal organ_construction_started(organ_id: StringName, slot_id: StringName, option_id: StringName)
signal organ_built(organ_id: StringName, slot_id: StringName, option_id: StringName)

# 3 · Operation decisions and resource priority changes
signal resource_priority_changed(decision_id: StringName, allocation: Dictionary, allocation_total: float)
signal operation_decision_confirmed(decision_id: StringName, operation_id: StringName, spent: Dictionary)
signal transport_network_intervened(edge_id: StringName, plan_id: StringName, capacity: float)
signal operation_result_settled(decision_id: StringName, outcome: Dictionary)
signal resources_settled(stage_id: StringName, deltas: Dictionary, totals: Dictionary)

# 4 · The three bottleneck types appearing and clearing
signal transport_pressure_appeared(edge_id: StringName, severity: float)
signal transport_pressure_cleared(edge_id: StringName)
signal waste_buildup_appeared(organ_id: StringName, severity: float)
signal waste_buildup_cleared(organ_id: StringName)
signal signal_gap_appeared(organ_id: StringName, severity: float)
signal signal_gap_cleared(organ_id: StringName)

# 5 · Stability band change, waste overflow, investable resource shortage
signal stability_band_changed(previous_band: int, current_band: int, stability: float)
signal waste_overflowed(waste: float, stability_penalty: float)
signal resource_shortage_raised(resource_id: StringName, amount: float, threshold: float)
signal resource_shortage_cleared(resource_id: StringName, amount: float)

# 6 · Minigame entry, exit, and star rating
signal minigame_entered(minigame_id: StringName, stage_id: StringName, time_limit_sec: float)
signal minigame_exited(minigame_id: StringName, resolution: int, elapsed_sec: float)
signal minigame_rated(minigame_id: StringName, stars: int, rating_detail: Dictionary)

# 7 · Knowledge unlock, system observation, carryover application
signal system_observation_started(organ_id: StringName, observation_id: StringName)
signal system_observation_ended(organ_id: StringName, observation_id: StringName)
signal knowledge_entry_unlocked(entry_id: StringName, organ_id: StringName, stage_id: StringName)
signal knowledge_entry_opened(entry_id: StringName, first_read: bool)
signal carryover_applied(from_stage_id: StringName, to_stage_id: StringName, carryover: Dictionary)
signal save_loaded(outcome: StringName, chapter_select_available: bool)
signal season_completed(summary: Dictionary)
signal delayed_feedback_shown(carryover_field: StringName, source_stage_id: StringName, source_decision_ids: Array[StringName])

# 8 · Action rejection
signal action_rejected(action_id: StringName, reason_code: StringName, focus_element: StringName)

# 9 · Birth transition
signal birth_sequence_started(stage_id: StringName, total_budget_ms: int)
signal birth_state_changed(previous_state: int, current_state: int, window_ms: int)
signal birth_sequence_completed(stage_id: StringName)
signal birth_rolled_back(from_state: int, reason_code: StringName)
```
