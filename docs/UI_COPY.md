# Metabolis UI Copy

## Scope and Capacity

This file replaces the placeholder copy owned by T-30 and T-30a. Repository
policy requires project artifacts to be written in English, so the copy below is
the English equivalent of the player-facing copy requested by T-31.

| Container | Maximum lines | Maximum characters per line |
|---|---:|---:|
| G1a broadcast notification | 1 | 9 |
| G1b attribution notification | 2 | 10 |
| G1c pressure notification | 2 | 9 |
| G1d alert notification | 2 | 10 |
| G2 organ archive field | 3 | 66 |
| G3 chapter summary item | 4 | 64 |
| Guidance line, added by T-34 | 1 | 26 |

Character counts include spaces and punctuation. Braced runtime substitutions
are counted as written in this document; callers must shorten substituted values
when the completed line would exceed the same limit.

## Immediate Knowledge Notifications

Each E11 hint enters the G4 notification mapping with one exact key. Its first
occurrence uses the two-line G1b attribution copy; a same-stage repeat uses the
one-line G1a broadcast copy. A critical stability transition uses the same two
lines in G1d. The copy describes feedback that has already occurred. It gives
no prediction, instruction, or ranking.

| Key | First / alert copy | Count | Repeat broadcast copy | Count |
|---|---|---:|---|---:|
| `hint_neural_tube_compensation` | `Neural map`<br>`Folds tube` | 10 / 10 | `Tube live` | 9 |
| `hint_transport_capacity` | `Cell load`<br>`Route grow` | 9 / 10 | `Route use` | 9 |
| `hint_waste_processing` | `Waste rose`<br>`Process it` | 10 / 10 | `Waste up` | 8 |
| `hint_signal_coordination` | `Signals on`<br>`Growth map` | 10 / 10 | `Sig gap` | 7 |
| `hint_stability_response` | `Sys strain`<br>`Effects on` | 10 / 10 | `Stability` | 9 |
| `hint_birth_transition` | `Breath one`<br>`Flow shift` | 10 / 10 | `Flow move` | 9 |

`hint_neural_tube_compensation` is the separate Stage Three compensation hint.
It appears only on the first signal-coverage competition described by E11 and
is never merged with another hint.

## Organ Archive Copy

The archive uses exactly the seven positional fields created by T-30. The labels
name how accepted scientific material is organized; they add no scientific
claim. Runtime field values must be adapted only from the matching
`SCIENCE_NOTES.md` player version, causal chain, visible in-game change, and
incorrect-claim boundary.

| Placeholder key | Copy | Actual character count |
|---|---|---:|
| `ARCHIVE_HEADER_PLACEHOLDER` | `Organ Archive: {organ}` | 22 |
| `FIELD_LABEL_PLACEHOLDER[g2_1]` | `Structure` | 9 |
| `FIELD_LABEL_PLACEHOLDER[g2_2]` | `Developmental origin` | 20 |
| `FIELD_LABEL_PLACEHOLDER[g2_3]` | `Formation sequence` | 18 |
| `FIELD_LABEL_PLACEHOLDER[g2_4]` | `System role` | 11 |
| `FIELD_LABEL_PLACEHOLDER[g2_5]` | `Collaborating systems` | 21 |
| `FIELD_LABEL_PLACEHOLDER[g2_6]` | `Visible body-city change` | 24 |
| `FIELD_LABEL_PLACEHOLDER[g2_7]` | `Model boundary` | 14 |
| `FIELD_EMPTY_PLACEHOLDER` | `No recorded content` | 19 |
| `PAUSE_INDICATOR_PLACEHOLDER` | `Paused: operation time and settlement are stopped.` | 50 |

The seven runtime value rules are fixed:

| Field | Accepted source in `SCIENCE_NOTES.md` |
|---|---|
| G2-1 | The theme's named structure |
| G2-2 | The first supported step of the causal chain |
| G2-3 | The remaining supported formation sequence |
| G2-4 | The one-sentence player version, shortened without adding a claim |
| G2-5 | Only partners named in the supported causal chain |
| G2-6 | The visible in-game change, explicitly identified as a teaching representation |
| G2-7 | The matching incorrect claim to avoid and the simplified-model boundary |

## Chapter Summary Copy

These keys replace every T-30a placeholder scaffold. Dynamic decision, option,
slot, point, and stage values remain runtime data.

| Placeholder key | Copy | Actual character count |
|---|---|---:|
| `SUMMARY_HEADER_PLACEHOLDER` | `Stage Summary: {stage}` | 22 |
| `ITEM_LABEL_PLACEHOLDER[g3_1_current_stage]` | `Current developmental stage` | 27 |
| `ITEM_LABEL_PLACEHOLDER[g3_2_structures_formed]` | `Structures formed in this stage` | 31 |
| `ITEM_LABEL_PLACEHOLDER[g3_3_system_connection]` | `New system connection` | 21 |
| `ITEM_LABEL_PLACEHOLDER[g3_4_knowledge_points]` | `Three core knowledge points` | 27 |
| `ITEM_LABEL_PLACEHOLDER[g3_5_city_change]` | `Body-city change` | 16 |
| `ITEM_LABEL_PLACEHOLDER[g3_6_encyclopedia]` | `New archive entries` | 19 |
| `ITEM_EMPTY_PLACEHOLDER` | `No recorded content` | 19 |
| `CONNECTION_LINE_PLACEHOLDER` | `Connection: {decision}>{option}@{slot}` | 38 |
| `CONNECTION_NONE_PLACEHOLDER` | `No new system connection recorded` | 33 |
| `KNOWLEDGE_POINT_PLACEHOLDER` | `Point {index}: {text}` | 21 |
| `KNOWLEDGE_POINT_MISSING_PLACEHOLDER` | `Point {index}: not recorded` | 27 |
| `PAUSE_INDICATOR_PLACEHOLDER` | `Paused: operation time and settlement are stopped.` | 50 |

## Guidance Copy

Added by T-34. One line for every entry of the guidance step definition table in
`docs/coord/done/T-33.md`: five for each of the four stage guides, three for each
of the six action guides, and a separate minimal set for a player who skipped.
The keys are the ones `src/ui/tutorial.gd` currently fills with square-bracket
placeholders.

Four rules shape every line, and the fourth column records which of the two
permitted jobs it does.

- One sentence. No semicolon joining two things, no exclamation mark, no second
  person, and no address to the player.
- It may name a structure or point at an action, and nothing else. Principle and
  cause belong to the immediate knowledge notifications and to the visible
  consequence, not here.
- The guidance surface retains its own 26-character one-line capacity. If a
  later T-33a integration routes a guidance item through G1a-G1d, it must use
  the selected tier's smaller limit instead.
- At the build decision and the operation decision no line may indicate that one
  candidate or one plan is preferable, and the five terms banned by T-33a may not
  appear.

### Stage Guidance

The five readings each get their own line. They are never merged, so a stage
whose reading is empty shows an empty reading rather than a shortened set.

| Key | Copy | Characters | Job |
|---|---|---:|---|
| `TUTORIAL_STAGE[stage_origin.developmental_time]` | `Week 1: cell to cluster` | 23 | names a structure |
| `TUTORIAL_STAGE[stage_origin.existing_structures]` | `No structures stand yet` | 23 | names a structure |
| `TUTORIAL_STAGE[stage_origin.new_demands]` | `Open space for division` | 23 | points at an action |
| `TUTORIAL_STAGE[stage_origin.structures_to_form]` | `Build the cell cluster` | 22 | points at an action |
| `TUTORIAL_STAGE[stage_origin.decision_count]` | `Two decisions to settle` | 23 | points at an action |
| `TUTORIAL_STAGE[stage_harbor.developmental_time]` | `Weeks 2-3: disc to layers` | 25 | names a structure |
| `TUTORIAL_STAGE[stage_harbor.existing_structures]` | `The cell cluster stands` | 23 | names a structure |
| `TUTORIAL_STAGE[stage_harbor.new_demands]` | `A supply route is needed` | 24 | names a structure |
| `TUTORIAL_STAGE[stage_harbor.structures_to_form]` | `Build harbor, then layers` | 25 | points at an action |
| `TUTORIAL_STAGE[stage_harbor.decision_count]` | `Three decisions to settle` | 25 | points at an action |
| `TUTORIAL_STAGE[stage_circulation.developmental_time]` | `Weeks 4-8: the heart tube` | 25 | names a structure |
| `TUTORIAL_STAGE[stage_circulation.existing_structures]` | `Harbor and layers stand` | 23 | names a structure |
| `TUTORIAL_STAGE[stage_circulation.new_demands]` | `Carry supply to far cells` | 25 | points at an action |
| `TUTORIAL_STAGE[stage_circulation.structures_to_form]` | `Build the pump and network` | 26 | points at an action |
| `TUTORIAL_STAGE[stage_circulation.decision_count]` | `Three decisions to settle` | 25 | points at an action |
| `TUTORIAL_STAGE[stage_birth.developmental_time]` | `Weeks 9-38: lungs mature` | 24 | names a structure |
| `TUTORIAL_STAGE[stage_birth.existing_structures]` | `Pump and network stand` | 22 | names a structure |
| `TUTORIAL_STAGE[stage_birth.new_demands]` | `Ready the body for air` | 22 | points at an action |
| `TUTORIAL_STAGE[stage_birth.structures_to_form]` | `Build lungs, then the link` | 26 | points at an action |
| `TUTORIAL_STAGE[stage_birth.decision_count]` | `Three decisions to settle` | 25 | points at an action |

`Three decisions to settle` appears three times. Stages two, three, and four each
carry two build decisions and one operation decision, so the sentence is the same
sentence rather than three that happen to look alike. Stage one differs because
it carries one build decision.

The structure names here are the player-facing names of the structures whose
identifiers live in `organs.required_ids_by_stage`. Adding a structure to a stage
therefore requires a line here as well as a value there.

### Action Guidance

Three lines for each kind of action: the demonstration, the highlighted target,
and the path.

| Key | Copy | Characters | Job |
|---|---|---:|---|
| `TUTORIAL_ACTION[confirm_build_decision.demonstration]` | `Watch a card being chosen` | 25 | points at an action |
| `TUTORIAL_ACTION[confirm_build_decision.highlight]` | `The candidate cards` | 19 | names a structure |
| `TUTORIAL_ACTION[confirm_build_decision.path]` | `Panel, then map, then card` | 26 | points at an action |
| `TUTORIAL_ACTION[confirm_operation_decision.demonstration]` | `Watch shares being set` | 22 | points at an action |
| `TUTORIAL_ACTION[confirm_operation_decision.highlight]` | `The allocation entry` | 20 | names a structure |
| `TUTORIAL_ACTION[confirm_operation_decision.path]` | `Panel, then allocation` | 22 | points at an action |
| `TUTORIAL_ACTION[resolve_optional_minigame.demonstration]` | `Watch one task run through` | 26 | points at an action |
| `TUTORIAL_ACTION[resolve_optional_minigame.highlight]` | `The task entry` | 14 | names a structure |
| `TUTORIAL_ACTION[resolve_optional_minigame.path]` | `Panel, then task entry` | 22 | points at an action |
| `TUTORIAL_ACTION[intervene_transport_network.demonstration]` | `Watch one route reroute` | 23 | points at an action |
| `TUTORIAL_ACTION[intervene_transport_network.highlight]` | `The city map routes` | 19 | names a structure |
| `TUTORIAL_ACTION[intervene_transport_network.path]` | `Panel, then map route` | 21 | points at an action |
| `TUTORIAL_ACTION[view_knowledge_archive.demonstration]` | `Watch an entry open` | 19 | points at an action |
| `TUTORIAL_ACTION[view_knowledge_archive.highlight]` | `The archive button` | 18 | names a structure |
| `TUTORIAL_ACTION[view_knowledge_archive.path]` | `Timeline, then archive` | 22 | points at an action |
| `TUTORIAL_ACTION[advance_to_next_stage.demonstration]` | `Watch the stage close` | 21 | points at an action |
| `TUTORIAL_ACTION[advance_to_next_stage.highlight]` | `The recap button` | 16 | names a structure |
| `TUTORIAL_ACTION[advance_to_next_stage.path]` | `Timeline, then recap` | 20 | points at an action |

The two decision demonstrations describe the act of choosing and never the thing
chosen. `Watch a card being chosen` shows that a card can be picked; it does not
say which, and could not, because table D11 of `docs/BUILD_DECISION_SPEC.md`
requires that neither candidate dominate the other.

### Minimal Set Shown After a Skip

Three lines, and only three. Each carries something a player cannot begin without
and cannot read off the screen.

| Key | Copy | Characters | Job |
|---|---|---:|---|
| `TUTORIAL_SKIP[1]` | `Map cards are the choices` | 25 | names a structure |
| `TUTORIAL_SKIP[2]` | `Confirm settles a decision` | 26 | points at an action |
| `TUTORIAL_SKIP[3]` | `The task can be skipped` | 23 | points at an action |

The third line is here because nothing on screen says the task is optional, and a
player who believes it is required may stall on it. `docs/MINIGAME_SPEC.md` table
M6 guarantees that it is not.

Everything else a beginning player needs is already visible: the six resource
readings, the timeline, the three operational metrics, the candidate cards with
their values and costs, and the confirm control.

### Playing Stage One With the Guidance Copy Deleted

Required by the acceptance of T-34, and answered by running it rather than by
argument.

With every line above replaced by an empty string, the stage-one build decision
can still be completed. The guidance never gated it: `src/ui/tutorial.gd` refuses
to lock the build candidates or the allocation entry under any circumstances, and
its skip path leaves both open as well. The candidate cards keep their three
measured values, their units, their comparison bars, and their resource cost from
table D8, all of which are runtime data rather than copy. The confirm control and
its rejection feedback are unchanged.

What is lost without the copy is the naming, not the ability. A player can still
pick a card, place it, and confirm, but nothing says the cluster is a cluster or
that the stage wants one built.

## Title Screen Copy

The title screen is not one of the three information containers, so its lines
are bounded by the rectangles in the layout table of
`docs/D-29_TITLE_SCENE_INTEGRATION.md` rather than by a character count. The
widths below were measured with the engine default font at `8 px`, the size that
document specifies, and are recorded because the disclaimer band has almost no
margin.

| Placeholder key | Copy | Measured width | Band |
|---|---|---:|---:|
| `TITLE_HEADING_PLACEHOLDER` | `Metabolis: Birth of the City of Life` | 130 px | 320 px |
| `TITLE_SUBTITLE_PLACEHOLDER` | `Birth of the City of Life` | 90 px | 320 px |
| `TITLE_DISCLAIMER_PLACEHOLDER` | `A simplified educational model of human development. Not for medical judgement, diagnosis, or treatment.` | 418 px | 480 px |

The disclaimer must say three things and may not drop any of them: that the
model is simplified, that it is educational, and that it is not for medical
judgement, diagnosis, or treatment. `docs/D-29_TITLE_SCENE_INTEGRATION.md`
requires it on one line inside `Rect2(80, 300, 480, 20)`.

The longer wording the scene first carried, `This game is a simplified
educational model of human development. It is not for medical judgement,
diagnosis, or treatment.`, measures 481 px and does not fit that band by one
pixel. It was shortened rather than wrapped, because the band is 20 px tall and a
second line would be clipped rather than shown.

## Closest to the Limit

The notification lines closest to their applicable hard maximum are:

| Key and line | Character count | Limit |
|---|---:|---:|
| `hint_neural_tube_compensation`, both attribution lines | 10 | 10 |
| `hint_waste_processing`, both attribution lines | 10 | 10 |
| `hint_signal_coordination`, both attribution lines | 10 | 10 |

All must render without truncation in their G1 variant before this copy is
integrated into runtime labels.

Five guidance lines also sit exactly at 26, and carry the same requirement:

| Key | Character count | Limit |
|---|---:|---:|
| `TUTORIAL_STAGE[stage_circulation.structures_to_form]` | 26 | 26 |
| `TUTORIAL_STAGE[stage_birth.structures_to_form]` | 26 | 26 |
| `TUTORIAL_ACTION[confirm_build_decision.path]` | 26 | 26 |
| `TUTORIAL_ACTION[resolve_optional_minigame.demonstration]` | 26 | 26 |
| `TUTORIAL_SKIP[2]` | 26 | 26 |
