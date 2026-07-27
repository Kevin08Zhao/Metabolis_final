# Four-Stage Development Timeline Baseline

This document is the single source of configuration for the first playable version of Metabolis: Birth of the City of Life. The stage-flow state machine, Development Timeline, Stage Summary, and construction-zone visuals must consume the locked four-stage order and content assignments defined here. A fifth stage may not be derived.

## Time Basis

The game uses post-fertilization developmental time throughout. Let `t` be the number of weeks elapsed since fertilization. The four stages use these non-overlapping intervals:

| Stage | Mathematical Interval | Timeline Label |
|---|---|---|
| One · Origin | `0 ≤ t < 1` | Post-fertilization week 1 |
| Two · Harbor | `1 ≤ t < 3` | Post-fertilization weeks 2–3 |
| Three · Circulation | `3 ≤ t < 8` | Post-fertilization weeks 4–8 |
| Four · Birth | `8 ≤ t ≤ 38` | Post-fertilization weeks 9–38, through birth |

Clinical gestational age is usually counted from the first day of the last menstrual period and is approximately two weeks greater than post-fertilization developmental time. The conversion rule is “clinical gestational age is approximately post-fertilization age plus two weeks.” This explanation appears when the player enters Stage One for the first time, on the time-basis card in `StageIntroPanel` and beneath the time label in `DevelopmentTimeline`. It is non-blocking information displayed by the system with the stage introduction and creates no new player action.

“Formed in this stage” means the structure first appears on the game map, in the construction zone, or in a background animation. It does not mean the structure is biologically mature. Real development overlaps; the four-stage order is a linear teaching sequence, not a claim that all organs begin developing in strict succession.

## Fixed Order and Internal Identifiers

| Order | Display Name | `stage_id` | Section Eighteen Content | `next_stage_id` |
|---:|---|---|---|---|
| 1 | Stage One · Origin | `stage_origin` | Item 1 | `stage_harbor` |
| 2 | Stage Two · Harbor | `stage_harbor` | Items 2 and 3 | `stage_circulation` |
| 3 | Stage Three · Circulation | `stage_circulation` | Items 4, 5, and 6 | `stage_birth` |
| 4 | Stage Four · Birth | `stage_birth` | Items 7, 8, and 9 | `null` |

## Stage-Exit Evaluation

The first three stages share this directly executable Boolean evaluation:

```text
stage_exit_ready(stage_id) =
    (current_stage_id == stage_id)
    && (phase == Phase.STAGE_COMPLETE)
    && (StageDefinition[stage_id].required_build_decision_ids
        .is_subset_of(confirmed_build_decision_ids))
    && (StageDefinition[stage_id].required_operation_decision_ids
        .is_subset_of(confirmed_operation_decision_ids))
    && (system_observation_complete == true)
    && (knowledge_unlock_resolved == true)
    && (blocking_modal_open == false)
```

Minigames do not appear in stage-exit evaluation. Skipping, completing, or never entering a minigame cannot block main-path progression. The current `StageDefinition.next_stage_id` must also match the target specified below.

## Stage One · Origin

| Configuration | Locked Value |
|---|---|
| `stage_id` | `stage_origin` |
| Post-fertilization time | `0 ≤ t < 1`; post-fertilization week 1 |
| Section Eighteen assignment | Item 1: zygote and cell division |
| Building decision | `build_cell_cluster`: embryonic cell cluster, the “Core of the City of Life”; this tutorial stage has only this one building decision |
| Operations decision | `operate_cleavage_allocation`: priority between the rhythm of cell division and allocation of Cell Material |
| Minigame | Yes; Prototype A, “Cell Division”; `minigame_cell_division` |
| Organs or structures formed | No differentiated organs; zygote, blastomeres, morula, and blastocyst precursor form |
| Construction-zone visual | One cell expands into a compact cell cluster; the selected candidate slot becomes the later city core and the other slots withdraw |
| Enter next stage | `stage_exit_ready(stage_origin) && (next_stage_id == stage_harbor)` |
| Cross-stage carryover | Carries network efficiency, operating pressure, and waste state into `stage_harbor` |

## Stage Two · Harbor

| Configuration | Locked Value |
|---|---|
| `stage_id` | `stage_harbor` |
| Post-fertilization time | `1 ≤ t < 3`; post-fertilization weeks 2–3 |
| Section Eighteen assignment | First half: Item 2, “Blastocyst and Placental Foundation”; second half: Item 3, “Formation of the Three Germ Layers” |
| First building decision | `build_placenta_port`: placental foundation, the “Life Harbor” |
| Second building decision | `build_germ_layer_districts`: ectoderm, mesoderm, and endoderm as “City Function Districts” |
| Operations decision | `operate_placental_transport`: supply priority for placental material transport |
| Minigame | Yes; Prototype B, “Material Transport”; `minigame_material_transport` |
| Organs or structures formed | Placental foundation, ectoderm, mesoderm, and endoderm |
| Construction-zone visual | The first half shows blastocyst positioning and Life Harbor construction; the second half unfolds the three functional layers at the same map node without creating a new stage map |
| Enter next stage | `stage_exit_ready(stage_harbor) && (next_stage_id == stage_circulation)` |
| Cross-stage carryover | Carries network efficiency, operating pressure, and waste state into `stage_circulation` |

## Stage Two Dual-Content Load and Summary Limit

Stage Two has exactly one stage node, `stage_harbor`; formation of the three germ layers may not be split into a separate stage. It uses exactly two internal system phases:

| Subphase | Time | Content | Completion Marker |
|---|---|---|---|
| `harbor_placenta_phase` | `1 ≤ t < 2`; post-fertilization week 2 | Blastocyst positioning, placental foundation, and material transport | `placenta_phase_complete` |
| `harbor_germ_layers_phase` | `2 ≤ t < 3`; post-fertilization week 3 | Formation of ectoderm, mesoderm, and endoderm | `germ_layers_phase_complete` |

The Stage Two summary in `StageSummaryPanel` is fixed to the following six items. A seventh item may not be added:

1. Blastocyst positioning is complete.
2. The placental foundation, “Life Harbor,” is established.
3. The settlement result for placental material-transport priority.
4. Ectoderm has formed.
5. Mesoderm has formed.
6. Endoderm has formed.

Content beyond these six items—including chorionic villi, amnion, yolk sac, primitive streak, and later differentiation of each germ layer—may appear only in the construction-zone `ConstructionArchive`. It may not enter the stage summary or create an additional timeline node.

## Stage Three · Circulation

| Configuration | Locked Value |
|---|---|
| `stage_id` | `stage_circulation` |
| Post-fertilization time | `3 ≤ t < 8`; post-fertilization weeks 4–8 |
| Section Eighteen assignment | Item 4, “Heart and Early Circulation”; Item 5, “Nervous-System Foundation”; Item 6, “Background Animations for Other Organs” |
| First building decision | `build_heart_pump`: heart, the “Central Pumping Station” |
| Second building decision | `build_neural_network`: neural tube and foundations of the brain and spinal cord, the “Information Network” |
| Operations decision | `operate_circulation_signal_priority`: priority between early-circulation supply and neural-signal coverage |
| Minigame | Yes; Prototype C, “Signal Transfer”; `minigame_signal_transfer` |
| Organs or structures formed | Heart, early blood vessels, neural tube, brain foundation, and spinal-cord foundation; liver, kidneys, digestive tract, limb buds, and eye and ear primordia appear as background structures |
| Construction-zone visual | The heart and neural network use selectable construction slots; vessels extend automatically along the selected route; other organs play background formation animations without candidates or decisions |
| Enter next stage | `stage_exit_ready(stage_circulation) && (next_stage_id == stage_birth)` |
| Cross-stage carryover | Carries network efficiency, operating pressure, and waste state into `stage_birth` |

## Stage Four · Birth

| Configuration | Locked Value |
|---|---|
| `stage_id` | `stage_birth` |
| Post-fertilization time | `8 ≤ t ≤ 38`; post-fertilization weeks 9–38, through birth |
| Section Eighteen assignment | Item 7, “Lung Preparation for Birth”; Item 8, “Simplified Whole-Body Check”; Item 9, “Birth and First Breath” |
| First building decision | `build_lung_exchange`: pulmonary gas-exchange region, the “Air-Exchange Facility” |
| Second building decision | `build_pulmonary_interface`: pulmonary-circulation interface, the “Air–Transport Link” |
| Operations decision | `operate_birth_readiness_check`: system-support priority in the simplified whole-body check |
| Minigame | None; `minigame_id = null` |
| Organs or structures formed | Pulmonary gas-exchange region and pulmonary-circulation interface; existing whole-body organ systems enter a pre-birth collaboration state |
| Construction-zone visual | The lungs and pulmonary-circulation interface use selectable construction slots, followed by the whole-body-check overlay, birth transition, and first-breath animation |
| Enter next stage | None; `next_stage_id = null`, and `advance_to_next_stage` may not be called |
| Final completion condition | `final_completion_ready(stage_birth)`; satisfying it enters the end state of the first playable version without creating a fifth stage |
| Cross-stage carryover | None. Step Ten only closes this stage flow and writes the ending state; it does not carry over network efficiency, operating pressure, waste, or any other stage snapshot |

The final condition is:

```text
final_completion_ready(stage_id) =
    (current_stage_id == stage_id)
    && (StageDefinition[stage_id].required_build_decision_ids
        .is_subset_of(confirmed_build_decision_ids))
    && (StageDefinition[stage_id].required_operation_decision_ids
        .is_subset_of(confirmed_operation_decision_ids))
    && (system_observation_complete == true)
    && (knowledge_unlock_resolved == true)
    && (blocking_modal_open == false)
    && (birth_check_passed == true)
    && (birth_transition_complete == true)
    && (first_breath_complete == true)
```

## Rules for the Four Consumers

| Consumer | Configuration It Must Read | Content It May Not Derive Independently |
|---|---|---|
| Stage-flow state machine | `stage_id`, fixed order, `next_stage_id`, decision-ID sets, minigame ID, stage-exit or final-completion condition, and cross-stage carryover rule | May not add branch stages or include minigame state in stage-exit conditions |
| Development Timeline | Display names, timeline labels, and Section Eighteen item numbers; Stage Two displays only one node | May not display the three germ layers as a fifth stage node |
| Stage Summary | Structures formed and decision-settlement results; Stage Two uses only the locked six items | May not expand construction-archive content into the Stage Two summary |
| Construction-zone visuals | Building objects, candidate slots, background-formation objects, and the two Stage Two subphases | May not turn background organs into building or operations decisions |

## Acceptance Table One: Assignment of the Nine Section Eighteen Items

| Item | Content | Sole Stage | Role in That Stage | Corresponding Configuration |
|---:|---|---|---|---|
| 1 | Zygote and cell division | Stage One · Origin | Building-decision object | `build_cell_cluster` |
| 2 | Blastocyst and placental foundation | First half of Stage Two · Harbor | Building-decision object | `build_placenta_port` |
| 3 | Formation of the three germ layers | Second half of Stage Two · Harbor | Building-decision object | `build_germ_layer_districts` |
| 4 | Heart and early circulation | Stage Three · Circulation | Building-decision object | `build_heart_pump` |
| 5 | Nervous-system foundation | Stage Three · Circulation | Building-decision object | `build_neural_network` |
| 6 | Background animations for other organs | Stage Three · Circulation | Non-decision content | `background_organogenesis` |
| 7 | Lung preparation for birth | Stage Four · Birth | Building-decision object | `build_lung_exchange`, `build_pulmonary_interface` |
| 8 | Simplified whole-body check | Stage Four · Birth | Operations-decision object | `operate_birth_readiness_check` |
| 9 | Birth and first breath | Stage Four · Birth | Non-decision content | `birth_transition`, `first_breath` |

## Acceptance Table Two: Decision and Minigame Counts

| Stage | Building Decisions | Operations Decisions | Minigames |
|---|---:|---:|---:|
| Stage One · Origin | 1 | 1 | 1 |
| Stage Two · Harbor | 2 | 1 | 1 |
| Stage Three · Circulation | 2 | 1 | 1 |
| Stage Four · Birth | 2 | 1 | 0 |
| Total | **7** | **4** | **3** |
