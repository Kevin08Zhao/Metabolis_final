# Metabolis Interactive City-Builder Rework Plan

## 1. Product Direction

Metabolis should be a map-first, highly interactive city-building game set inside a stylized developing human body. The player should personally place organ-buildings, connect transport and signal routes, allocate resources, solve visible bottlenecks, and watch the body-city operate.

The intended inspiration from Township is the feeling of direct construction, persistent spatial ownership, visible production, and continuous city growth. Metabolis will not copy Township's art, interface, economy, or content.

The development timeline and scientific constraints remain important, but they guide what can be built and where it can be built. They should not turn the game into a sequence of slides.

Reference: the official Township store description centers its experience on building houses, factories, and community buildings, growing production, and arranging the town according to the player's choices: <https://play.google.com/store/apps/details?id=com.playrix.township>.

## 2. Current Build Diagnosis

The current game is technically playable from title to ending, but its interaction model does not deliver the intended city-builder experience.

| Current behavior | Evidence in the implementation | Player-facing result |
|---|---|---|
| A large modal action panel dominates the screen | `GameplayController` creates a 520 × 228 panel at `(60, 116)` inside a 640 × 360 viewport | The map becomes background decoration instead of the main play surface |
| The chapter loop exposes ten sequential states | `ChapterFlow` is presented through repeated `Continue` actions | Progress feels like advancing slides |
| Building options and slot IDs are selected through buttons | `GameplayController` creates option buttons and slot buttons | The player does not directly touch, drag, or place a building on the map |
| Candidate map cells only support hover events | `GridManager` emits `slot_hovered` and `slot_unhovered`, but no placement click or drag event | The visible grid is informational rather than interactive |
| Routes are generated automatically after construction | `NetworkBuilder` computes a deterministic line from configured anchors when `organ_built` fires | The player never lays a vessel, nerve, or transport track |
| Network intervention logic is not connected to the live player interface | `NetworkIntervention` is instantiated, but its actions are not exposed by `GameplayController` | A specified player action exists in code but is not playable |
| Art size and logical footprint size disagree | Standard footprints are 2 × 2 tiles (32 × 32 px), landmark footprints are 3 × 3 tiles (48 × 48 px), while construction art is 64 × 64 and 80 × 80 px | Buildings overlap neighboring cells and appear inconsistent in scale |
| Several organs fall back to generic construction graphics or no completed art | `CityArtLayer` has dedicated families only for placenta, heart, and lungs | The city becomes visually inconsistent as more systems are built |

The existing simulation, resource data, save system, chapter content, and scientific notes are useful foundations. The presentation and direct-manipulation layer require a substantial redesign.

## 3. Target Player Experience

The map must remain visible and usable during normal play.

1. The player receives a concise construction goal without leaving the map.
2. A build tray presents the currently unlocked organ-buildings.
3. Selecting a building creates a translucent blueprint under the pointer.
4. The blueprint snaps to the 16 px grid.
5. Valid cells are green/teal; blocked or anatomically invalid cells are red.
6. The player moves the blueprint inside a scientifically valid body region and clicks to place it.
7. Before final confirmation, the player may reposition the blueprint.
8. After placement, organ ports become visible.
9. The player selects a vessel or signal route tool and draws an orthogonal path between compatible ports.
10. Construction consumes resources and visibly progresses on the map.
11. When the route becomes operational, particles and status indicators show flow.
12. Poor layouts create visible pressure, signal gaps, waste buildup, or low stability.
13. The player responds by extending a route, upgrading a segment, changing an allocation, or prioritizing a bottleneck.
14. Scientific explanations appear as short contextual notes attached to the event the player just caused.
15. The development timeline advances only after the required city systems are operational.

## 4. Guided Freedom

The game should use **guided free placement**, not unlimited sandbox placement and not fixed slot buttons.

- Each organ has one or more anatomically valid construction zones.
- The player may choose any unoccupied tile position inside the active zone.
- The complete footprint must fit inside the zone.
- Buildings cannot overlap.
- Every building has visible connection ports.
- Routes may be drawn only through buildable tissue cells.
- Important anatomical relationships are protected by zone and port rules rather than predetermined coordinates.

This gives the player meaningful spatial control without suggesting that organs may develop anywhere in the body.

## 5. Revised Core Loop

| Step | Player action | Visible result |
|---|---|---|
| 1. Read the city | Inspect resources, active systems, coverage, and bottlenecks directly on the map | Buildings animate; routes carry particles; problem areas pulse |
| 2. Accept a goal | Open a compact objective card | Valid anatomical construction zone is highlighted |
| 3. Choose a building | Select an unlocked organ-building from the build tray | Blueprint attaches to the pointer |
| 4. Place the building | Move and click on a valid grid position | Footprint is reserved; construction scaffold appears |
| 5. Connect the system | Draw transport and/or signal routes between ports | Route preview follows the pointer and snaps to cells |
| 6. Commit construction | Confirm the complete building-and-route plan | Resources are deducted and construction begins |
| 7. Operate the city | Choose allocation priorities and intervene on visible routes | Flow, waste, stability, and coverage update in real time |
| 8. Complete the development goal | Bring required systems above their readiness thresholds | A short science note and timeline transition appear |

Minigames remain optional side activities. They must never replace city construction.

## 6. Map and Visual Rules

The first prototype keeps the 16 px logical tile size and expands the full interface canvas to 800 × 450 so controls no longer cover the locked map area.

- The top 40 px remains the compact resource and timeline HUD.
- The 640 × 320 body-city map remains visible during construction.
- A dedicated 160 px action rail sits to the right of the map.
- Objective and feedback text occupy the lower information region below the map.
- No action button or instructional label may overlap the map.
- Normal play must not use a centered panel larger than 35% of the map area.
- Standard structures use a 2 × 2 tile footprint and a 32 × 32 px logical sprite canvas.
- Prototype landmark organs use a 6 × 6 tile footprint and a 96 × 96 px logical sprite canvas.
- Larger district structures must declare their own footprint and matching sprite canvas.
- Every final sprite is aligned to a bottom-center anchor.
- Draw order is based on the bottom edge of the occupied footprint.
- A one-tile visual clearance is reserved around landmark silhouettes even when the logical collision footprint is smaller.
- Construction, completed, operating, and stressed states keep the same outer silhouette and canvas size.
- The map receives a subtle body silhouette and named developmental regions so placements look intentional.
- Vessel, return-flow, and signal routes must be visually distinct by both color and shape. Primary transport uses broad arterial-street tiles with curbs, center markings, rounded corners, and complete junction pieces.

Existing 64 × 64 and 80 × 80 construction images must be recropped or reassigned to matching larger footprints before reuse.

## 7. First Interactive Vertical Slice

The first implementation should prove the new interaction model in one contained scenario before all four stages are migrated.

### Scenario

Build and connect the early heart pump in the Circulation stage.

### Required interactions

1. The map is visible immediately after entering the scenario.
2. The player opens the build tray and selects the heart pump.
3. A 6 × 6 heart blueprint follows the pointer.
4. The player may place it anywhere inside the highlighted central-body zone.
5. Invalid and occupied positions are visibly rejected.
6. The player sees at least two connection ports.
7. The player draws a transport route from the existing source network to the heart.
8. The route preview supports pointer drag and orthogonal tile snapping.
9. The player can erase the uncommitted route or move the blueprint before confirmation.
10. Confirmation spends resources and changes the heart from blueprint to construction to operating.
11. Flow particles begin only after a valid route exists.
12. A deliberately incomplete route produces a visible transport-coverage warning.
13. The player repairs the route and sees coverage recover without leaving the map.
14. A short contextual science note appears after the system becomes operational.

### Acceptance criteria

- A new player can place the heart and connect it without pressing a sequence of `Continue` buttons.
- At least 70% of the map remains unobstructed throughout construction.
- The building position is chosen by clicking the map, not by clicking a slot-name button.
- Every occupied cell, port, and route segment is aligned to the 16 px grid.
- No sprite extends unexpectedly into another building's occupied cells.
- The player can explain that the chosen location and route affected system coverage.
- The existing title, resource data, and ending remain reachable after the prototype is integrated.

## 8. Implementation Architecture

### New local systems

| Proposed file | Responsibility |
|---|---|
| `src/world/build_tool.gd` | Pointer-following blueprint, footprint validation, placement, move, cancel, and commit |
| `src/world/build_zone.gd` | Anatomically valid placement regions and zone highlighting |
| `src/world/route_tool.gd` | Pointer-drawn orthogonal routes, waypoint preview, cost, erase, and commit |
| `src/world/connection_port.gd` | Typed organ ports for transport, return flow, and developmental signals |
| `src/ui/build_tray.gd` | Compact map-side building selection |
| `src/ui/objective_card.gd` | Non-blocking goal and contextual science presentation |

### Existing systems to revise

| Existing file | Required change |
|---|---|
| `src/game/main.tscn` | Make the map the primary interaction surface and mount compact edge HUD panels |
| `src/ui/gameplay_controller.gd` | Replace the central sequential panel with tool modes and non-blocking objective presentation |
| `src/core/chapter_flow.gd` | Advance from observable construction and operation conditions instead of manual `Continue` actions |
| `src/world/grid_manager.gd` | Add pointer-to-cell selection, footprint preview, placement events, and blocked/zone states |
| `src/world/network_builder.gd` | Accept a player-authored grid path instead of always generating a route from fixed anchors |
| `src/world/network_intervention.gd` | Expose capacity, priority, and repair actions on selectable live route segments |
| `src/world/city_art_layer.gd` | Enforce footprint-matched canvases, bottom-edge ordering, and consistent state sizing |
| `src/data/game_state.gd` | Persist placed buildings, player-authored paths, construction state, and operation state |
| `docs/BALANCE.json` | Add build zones, route costs, port types, construction duration, and path constraints |

The existing simulation modules should remain authoritative for resources, stability, coverage, waste, bottlenecks, carryover, birth checks, and ending conditions.

## 9. Migration Order

### Milestone A: Interaction proof

- Build the Circulation vertical slice.
- Use temporary geometric visuals if an asset is missing.
- Validate placement, routing, flow feedback, and save/load before expanding content.

### Milestone B: Visual normalization

- Assign every structure an explicit footprint.
- Normalize every state image to its footprint canvas.
- Add missing dedicated visuals for the cell cluster, germ-layer districts, and neural network.
- Establish deterministic draw ordering and clearance checks.

### Milestone C: Four-stage migration

- Origin: place the initial cell district and connect local resource flow.
- Harbor: establish the placental port and lay the first exchange route.
- Circulation: place the heart and neural structures, then balance transport and signal networks.
- Birth: place lung-related infrastructure, complete the final connections, and pass the readiness check.

### Milestone D: Operations

- Make production and consumption visibly continuous.
- Put bottleneck interventions directly on map objects.
- Keep stage operation decisions, but express them as live allocations and upgrades rather than modal questions.

### Milestone E: Polish and verification

- Improve construction feedback, route readability, particles, sound, and contextual science notes.
- Verify save/load for all player-authored layouts.
- Run the complete game from title to first breath and ending.

## 10. Scope Boundaries for the Rework

- Do not copy Township assets, interface layouts, text, economy, or progression.
- Do not begin by creating a massive scrolling world.
- Do not preserve the ten-step click-through presentation merely because its simulation code already exists.
- Do not allow anatomically impossible placement.
- Do not add decorative systems before direct building and routing are enjoyable.
- Do not migrate all four stages until the vertical slice is proven.

The first goal is not “more content.” It is to make one building-and-routing sequence feel like a real city-building game.

## 11. Immediate Next Action

Continue the stage-by-stage migration behind the separate interactive title entry. Keep the existing complete game available as a fallback until the connected builder sequence covers all four stages and passes a full playthrough.

## 12. Local Prototype Progress

The separate title entry now begins a connected map-first sequence.

The Origin slice provides:

- direct 2 × 2 cell-district placement inside a guided developmental zone;
- a player-drawn nutrient conduit from the visible source core;
- resource-funded construction and an operating transition;
- three player-triggered division cycles that visibly increase the cell count;
- a development gate that unlocks the next builder slice only after the cycles complete.

The Circulation slice provides:

- direct 6 × 6 heart placement inside a guided anatomical zone;
- invalid-position rejection and map-aligned footprint feedback;
- a player-drawn orthogonal body-city road between visible ports;
- pre-commit move and erase actions;
- construction resource cost and blueprint-to-operating transition;
- live flow particles on the player-authored route;
- a route stress scenario that lowers coverage, raises transport pressure, and drains stability;
- direct selection of the flashing failed route segment;
- a resource-funded repair that restores flow and network values.

The next migration target is Harbor: place the placental port, draw the first exchange route, and express the germ-layer content as visible district development instead of a modal sequence.

## 13. Visual Cohesion Pass

The local builder sequence now uses one shared map language:

- a continuous peach-pink tissue ground replaces the permanent checkerboard;
- raised organic tissue districts frame the playable construction corridor;
- the logical grid appears only while a build or unfinished route tool is active;
- confirmed buildings no longer retain rectangular footprint outlines;
- an 18-configuration PixelLab arterial-road set supplies matched endpoints, straights, corners, branches, and junctions;
- route pieces are selected from their north, east, south, and west neighbors, so paths meet without visible stamp seams;
- new 32 × 32 and 48 × 48 PixelLab organ-city sprites share the same coral, berry, cream, and cyan palette.

The exact palette, mask rules, scale rules, PixelLab IDs, local paths, and prompt summaries are recorded in `docs/VISUAL_COHESION_GUIDE.md`. Harbor remains the next gameplay migration after this reusable visual layer is accepted.
