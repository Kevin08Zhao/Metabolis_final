# Metabolis UI Copy

## Scope and Capacity

This file replaces the placeholder copy owned by T-30 and T-30a. Repository
policy requires project artifacts to be written in English, so the copy below is
the English equivalent of the player-facing copy requested by T-31.

| Container | Maximum lines | Maximum characters per line |
|---|---:|---:|
| G1 immediate knowledge prompt | 2 | 26 |
| G2 organ archive field | 3 | 66 |
| G3 chapter summary item | 4 | 64 |

Character counts include spaces and punctuation. Braced runtime substitutions
are counted as written in this document; callers must shorten substituted values
when the completed line would exceed the same limit.

## Immediate Knowledge Prompts

Each E11 hint expands `PROMPT_PLACEHOLDER` with one exact key and two lines.
The copy describes feedback that has already occurred. It gives no prediction,
instruction, or ranking.

| Key | Copy | Actual character count |
|---|---|---:|
| `hint_neural_tube_compensation` | `Neural plate folds to tube`<br>`Brain, spinal cord arise` | 26 / 24 |
| `hint_transport_capacity` | `Tissue demand increased`<br>`Routes must grow with it` | 23 / 24 |
| `hint_waste_processing` | `Metabolic waste has risen`<br>`Routes and processing act` | 25 / 25 |
| `hint_signal_coordination` | `Signals coordinate cells`<br>`They guide growth, fate` | 24 / 23 |
| `hint_stability_response` | `Stability dropped a tier`<br>`It combines system effects` | 24 / 26 |
| `hint_birth_transition` | `First breath expands lungs`<br>`Resistance drops; flow up` | 26 / 25 |

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

## Closest to the Limit

The three lines closest to their applicable hard maximum are:

| Key and line | Character count | Limit |
|---|---:|---:|
| `hint_neural_tube_compensation`, line 1 | 26 | 26 |
| `hint_stability_response`, line 2 | 26 | 26 |
| `hint_birth_transition`, line 1 | 26 | 26 |

All three must render without truncation in the G1 container before this copy is
integrated into runtime labels.
