# Repository Coordination Handshake

This directory records tasks from the complete prompt list that have passed acceptance, allowing later sessions and automated processes to determine whether upstream dependencies are available. The sole source of task definitions is [`docs/prompts/Metabolis_Prompts_Full_v2.md`](../prompts/Metabolis_Prompts_Full_v2.md).

## Language Policy

- All generated project artifacts must be written in English from this migration onward.
- Internal IDs, repository names, file paths, formulas, and balance paths remain unchanged unless a task explicitly changes them.
- `docs/prompts/Metabolis_Prompts_Full_v2.md` is the verbatim source prompt supplied by the project owner. It remains in its original language and must stay byte-identical so its canonical content and checksum remain valid.

## Marker Rules

- Markers created during the A-00 handshake retain the form `<Task ID>.done`, such as `T-01.done`.
- Markers created during parallel development use `done/<Task ID>.md`, such as `done/T-03.md`; new tasks use this format.
- A marker may be created only after the task artifact exists and passes the acceptance method defined for that task.
- Every marker records the task ID, status, acceptance basis, artifacts, and check results.
- If an upstream artifact changes materially, its existing marker becomes invalid and must be revalidated against the source prompt and updated.
- A marker states only that its own task has passed acceptance; it does not imply completion of downstream tasks.

## Currently Accepted Tasks

| Task | Accepted Artifacts | Marker |
|---|---|---|
| T-01 · Empty-Repository Initialization and Directory Structure | Required directories and empty `.gitkeep` files, `.gitignore`, and `README.md` | [`T-01.done`](T-01.done) |
| T-02 · CONTEXT.md Project Baseline | `docs/CONTEXT.md` | [`T-02.done`](T-02.done) |
| T-03 · Godot 4 Project Creation and Project Settings | `src/project.godot`, `docs/GODOT_SETUP.md` | [`done/T-03.md`](done/T-03.md) |
| T-04 · Grid Dimensions, Coordinate System, and Tile-Pixel Baseline | `docs/GRID_BASELINE.md` | [`done/T-04.md`](done/T-04.md) |
| T-05 · GAME_RULES.md Gameplay Rules Specification | `docs/GAME_RULES.md` | [`T-05.done`](T-05.done) |
| T-05a · Stage and Development Timeline Definition | `docs/CHAPTER_TIMELINE.md` | [`done/T-05a.md`](done/T-05a.md) |
| T-05b · Minigame Framework Specification | `docs/MINIGAME_SPEC.md` | [`done/T-05b.md`](done/T-05b.md) |
| T-05c · Scripted Challenge Specification | `docs/SCRIPTED_CHALLENGE_SPEC.md` | [`done/T-05c.md`](done/T-05c.md) |
| T-05d · Build Decision Candidate Specification | `docs/BUILD_DECISION_SPEC.md` | [`done/T-05d.md`](done/T-05d.md) |
| T-05e · Operation Loop and Bottleneck Specification | `docs/OPERATION_SPEC.md` | [`done/T-05e.md`](done/T-05e.md) |
| T-05f · Cross-Stage Carryover Specification | `docs/CARRYOVER_SPEC.md` | [`done/T-05f.md`](done/T-05f.md) |
| T-06 · Balance Configuration and Validation | `docs/BALANCE.json`, `docs/BALANCE_VALIDATION.md` | [`done/T-06.md`](done/T-06.md) |
| T-07 · Scientific-Statement Compression | `docs/SCIENCE_NOTES.md` | [`done/T-07.md`](done/T-07.md) |
| T-08 · Event and Signal API | `docs/EVENT_API.md` | [`done/T-08.md`](done/T-08.md) |
| T-09 · Core Data Structure Definitions | `src/data/resource_pool.gd`, `src/data/organ_data.gd`, `src/data/network_data.gd`, `src/data/chapter_data.gd`, `src/data/game_state.gd` | [`done/T-09.md`](done/T-09.md) |
| T-10 · EventBus Singleton | `src/autoload/event_bus.gd`, `src/autoload/event_bus.gd.uid` | [`done/T-10.md`](done/T-10.md) |
| D-01 · Locked Palette and Hex Definitions | `art/palette.gpl`, `docs/PALETTE.md`, `docs/assets/D-01_MANIFEST.md` | [`done/D-01.md`](done/D-01.md) |
| D-02 · Color-Vision and Grayscale Validation | `docs/PALETTE_ACCESSIBILITY.md`, `docs/PALETTE_HEX_ADJUSTMENTS.md` | [`done/D-02.md`](done/D-02.md) |
| D-03 · Visual Bible | `docs/ART_BIBLE.md` | [`done/D-03.md`](done/D-03.md) |
| D-04 · Asset Technical Specification | `docs/ASSET_SPEC.md` | [`done/D-04.md`](done/D-04.md) |
| D-05 · Shape and State Encoding | `docs/ENCODING_SPEC.md` | [`done/D-05.md`](done/D-05.md) |
| D-06 · Single Concept-Scene Style Validation | `art/reference/STYLE_MASTER.png`, `docs/D-06_PIXELLAB_CONCEPT_PROMPT.md`, `docs/assets/D-06_MANIFEST.md` | [`done/D-06.md`](done/D-06.md) |
| D-14 · UI Framework and Six Regions | `docs/UI_LAYOUT.md` sections 1–6, `docs/assets/D-14_MANIFEST.md` | [`done/D-14.md`](done/D-14.md) |
| D-17 · Tooltip and Information-Panel Visual Style | `docs/UI_LAYOUT.md` sections 7–9, `docs/assets/D-17_MANIFEST.md` | [`done/D-17.md`](done/D-17.md) |

## Historical D-Track Rework

No D-track rework remains open after the 2026-07-29 audit. The two rows below
are retained as historical planning records; both linked records have been
resolved and renamed accordingly. See `docs/D_TRACK_AUDIT.md`.

| Task | Planning artifact retained | Blocking record |
|---|---|---|
| D-07 · Terrain and Tissue Tiles | `docs/D-07_TERRAIN_TILE_PROMPTS.md` | [`rework/D-07__from_ACCOUNT_D.resolved.md`](rework/D-07__from_ACCOUNT_D.resolved.md) |
| D-08 · Vessel Geometry Tiles | `docs/D-08_VESSEL_TILE_PROMPTS.md` | [`rework/D-08__from_ACCOUNT_D.resolved.md`](rework/D-08__from_ACCOUNT_D.resolved.md) |
