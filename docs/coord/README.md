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
| T-07 · Scientific-Statement Compression | `docs/SCIENCE_NOTES.md` | [`done/T-07.md`](done/T-07.md) |
