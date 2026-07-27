## Project Positioning

Metabolis: Birth of the City of Life is a Godot 4 and GDScript 2D pixel-art building and operations game. It uses human development mechanisms to build a “City of Life”: the placenta is the life harbor, the heart is the central pumping station, blood vessels are transport roads, the brain and nerves are the information network, and the lungs are the air-exchange facility. Players advance through four linear stages on a post-fertilization developmental timeline, from the zygote to birth and the first breath. Building and operations decisions are the core of each stage; task minigames are accents only.

## Ten-Step Core Loop

1. Enter the city and read its current operating indicators.
2. Receive the stage objective and two to four building candidates.
3. Optionally enter one sixty-second task minigame to earn a small amount of additional resources and Knowledge Badges.
4. Settle the resources available for the stage, primarily from the city’s own production.
5. Make a building decision: compare candidates and invest the three buildable resources; confirmation is irreversible.
6. The organ progresses from blueprint to under construction to complete, while the transport network automatically extends along the selected route.
7. Make an operations decision: prioritize limited resources and address a bottleneck; confirmation settles immediately and is irreversible.
8. Activate the organ and observe one collaboration with existing systems.
9. Unlock the corresponding organ archive entry and timeline entry.
10. Advance to the next stage and carry over network efficiency, operating pressure, and accumulated waste.

## Gameplay Weights

Building and operations account for at least sixty-five percent of active play time, task minigames account for no more than twenty percent, and observation plus immediate prompts account for approximately fifteen percent. All three are proportions of active play time; time spent reading science content is excluded.

## In Scope

The first playable version includes four linear stages, seven building decisions, four operations decisions, and three skippable task minigames. It includes six resources; three operating bottlenecks—transport pressure, waste accumulation, and insufficient signal coverage; limited intervention in the transport network; organ archives and immediate knowledge prompts; a simplified whole-body check before birth; and birth plus the first breath.

## Out of Scope

Post-birth gameplay, free building, complex production chains, random maps, a large technology tree, combat, disease simulation, multiple endings, and online features.

## Six Resources

| Display Name | Internal Variable | Rule |
|---|---|---|
| Nutrient Energy | `nutrient_energy` | May be invested in building |
| Cell Material | `cell_material` | May be invested in building |
| Development Signal | `development_signal` | May be invested in building |
| Waste | `waste` | Independent measurable pool; accumulation creates operating pressure |
| Stability | `stability` | Capped continuous value; displayed in three UI bands |
| Knowledge Badge | `knowledge_badge_count` | Counted only in the first playable version; never spent to unlock content |

## Four-Stage Structure

| Stage | Covered Content | Building / Operations Decisions | Task Minigame |
|---|---|---|---|
| One · Origin | Zygote and cell division | 1 tutorial / 1 | Cell Division |
| Two · Harbor | Blastocyst, placental foundation, and three germ layers | 2 / 1 | Material Transport |
| Three · Circulation | Heart, early circulation, nervous-system foundation, and background animations for other organs | 2 / 1 | Signal Transfer |
| Four · Birth | Lung preparation for birth, whole-body check, birth, and first breath | 2 / 1 | None |

## Naming Conventions

The display name is fixed as Metabolis: Birth of the City of Life. The internal project identifier, repository name, and export-file basename must use `Metabolis`.

| Category | Template | Three Positive Examples | One Negative Example |
|---|---|---|---|
| File names | `{domain}_{purpose}.{ext}` in lowercase `snake_case` | `organ_controller.gd`, `stage_harbor.tscn`, `resource_balance.tres` | `Stage Harbor.tscn` |
| GDScript variables and class names | Variables/functions use `snake_case`; classes use `PascalCase` | `nutrient_energy`, `allocate_resources`, `OrganController` | `organ-controller` |
| Event and signal names | `{subject}_{past_tense}` in `snake_case`, describing a fact that has occurred | `organ_built`, `resource_allocated`, `stage_completed` | `OnOrganBuilt` |
| Static-image file names | `{category}_{subject}_{variant}.png` | `organ_heart_base.png`, `tile_vessel_straight.png`, `ui_resource_waste.png` | `Heart Final 2.png` |
| Animation file names | `{subject}_{action}_{state}.tres` | `heart_pump_active.tres`, `lung_first_breath.tres`, `cell_divide_loop.tres` | `anim01_final.tres` |

## Directory Structure

`docs/` documentation; `art/tiles/` map tiles; `art/organs/` organ art; `art/ui/` interface art; `art/icons/` icons; `anim/` animations; `audio/` music and sound effects; `src/` Godot scenes and GDScript source; `tools/` validation scripts; `builds/` exported builds.

| Questions This Document Answers | Questions It Deliberately Does Not Answer |
|---|---|
| What the game is and what its core experience is | Exact formulas and final balance values |
| What the first version does and does not include | The specific candidates in the seven building decisions |
| What the core loop, gameplay weights, and resource semantics are | Detailed control specifications for the three task minigames |
| How the four stages are divided | Final art, audio, and level content |
| How names and files are written and where content belongs | Code implementation details and complete interface definitions |
