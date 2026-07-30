# System Map Gameplay Design — Nutrient Exchange and Circulation

Scope: the first two body-system maps of the current build, `system_nutrition`
(Nutrient Exchange) and `system_circulation` (Circulatory System). Maps three and
four are out of scope for this document.

This document records a playtest diagnosis of the shipped loop, then proposes a
replacement loop for the first two maps. It is a design document. It defines no
balance constants and changes no existing specification.

Everything in section 1 was observed in a full playthrough of `main` at commit
`2af3cdd`, run from the Godot editor, plus a read of
`src/game/system_city_prototype.gd`, `src/world/route_tool.gd`, and
`src/world/network_operation_tool.gd`.

The resource economy and the resource HUD have since been split into
`docs/RESOURCE_ECONOMY_DESIGN.md`, which is the active work item. That document
supersedes this one on resources, `throughput`, and `pressure`. Everything else
here remains a proposal.

---

## 1. Playtest diagnosis

### 1.1 What the player actually does

The observed loop, identical on every map:

1. Press **Place Facility**. A 6 × 6 blueprint follows the pointer.
2. Click anywhere. Resources are deducted, construction runs for 3 seconds.
3. Click the facility's output port, then click the right boundary gate.
4. Press **Commit Network**. A vehicle drives to the edge.
5. On maps one and three only: a fault appears on the road. Find it, click it,
   press **Repair Segment**.
6. The next map unlocks. Return to step 1.

Total distinct player verbs across the whole game: place, click-to-route, commit,
click-fault, repair. All five repeat unchanged four times.

### 1.2 Placement carries no decision

`FULL_MAP_BUILD_ZONE := Rect2i(Vector2i.ZERO, GRID_SIZE)` makes the entire grid
buildable. The objective string confirms it: *"Place \<facility\> anywhere it fits
on the map."* The only blocked cells are the entry route and the last column.

The one consequence of position is `_facility_support_distance()`, the Manhattan
distance from grid centre, which contributes at most a few points to a `pressure`
value that is never read by any rule. Placement is therefore free of consequence.

### 1.3 Routing is two clicks, and the optimum is automatic

`RouteTool.extend_to()` walks X first, then Y, appending every intermediate cell.
Clicking the destination therefore generates the complete path in one action. In
the playtest the road was finished with exactly two clicks — the source port and
the boundary gate — producing a 19-tile, one-turn path.

Because the generated path is always near-minimal, the penalties in
`_route_plan_metrics()` are effectively unreachable:

```
throughput = clamp(100 - excess * 4 - turns * 6, 35, 100)
pressure   = clamp(18 + turns * 10 + excess * 3 + max(support_distance - 4, 0) * 2, 0, 100)
```

`excess` is near zero and `turns` is one by construction. There is no route the
player would prefer over the one the tool draws for free, so there is no routing
decision.

### 1.4 The two derived metrics do almost nothing

- `throughput` is read in exactly one place, `_scaled_completion_reward()`, where
  it scales a one-time completion payout. At the observed value of 94 the
  difference against a perfect route is one or two resource points.
- `pressure` is never read by any rule. It is displayed and discarded.

The game shows the player two numbers and then ignores them.

### 1.5 The bottleneck is scripted, not emergent

`NetworkOperationTool.trigger_bottleneck()` always places the fault at the
midpoint index of the route. Coverage and pressure are hardcoded to 45 and 82.
Repair costs a fixed 6 Cell Material and 8 Development Signal. Which systems fault
at all is a literal flag, `bottleneck_required`, set true on maps one and three.

This contradicts `docs/OPERATION_SPEC.md`, which states that bottlenecks emerge
from actual allocation and network state and that stage scripts never insert them
unconditionally.

Because the fault position is independent of what the player built, the repair
teaches nothing. It is a hidden-object task.

### 1.6 The fault is punishing and unexplained

Stability drains at `BOTTLENECK_STABILITY_DRAIN_PER_SEC = 1.5` from the moment the
fault appears. In the playtest, stability fell from 100 to 50 during the time it
took to locate an unlabelled pink circle roughly six logical pixels across, and to
31 by the end of the map. No on-screen text stated that a fault existed, where to
look, or what stability does when it reaches zero.

### 1.7 The objective text is never displayed

`_objective_text()` returns a correct, useful string for every mode. The 640 × 90
region below the map — reserved for objective and feedback text by
`docs/SYSTEM_MAP_MODE.md` — rendered empty for the entire playthrough. Guidance
appears only in a small card that follows the pointer, showing values such as
`Road 19 tiles · CM 19`.

A player who has not read the source has no way to learn that the route must start
at the gold output port, or that a fault must be clicked before it can be repaired.

### 1.8 Nothing happens over time

Outside the bottleneck drain and the delivery animation, no value changes unless
the player presses a button. Facilities do not produce. Districts do not consume.
There is no reason to look at the map between actions, and no reason ever to
return to a map that has been completed.

### 1.9 The maps are not connected as systems

`Links 1/4` and the boundary-gate animation are presentation. Completing map one
grants a flat reward and unlocks map two. Map one's layout has no influence on map
two's economy. The system switcher bound to keys 1–4 has no use after a map is
finished.

### 1.10 Confirmed review positions

Settled in review after the playthrough. These narrow the proposals in sections 3
to 5 and are not open questions.

| Position | Effect on this document |
|---|---|
| Placement position needs no validity constraint. Placing a facility costs resources; where it goes may stay unrestricted. | **S2 is downgraded.** Tissue types are no longer required for placement. They may still be useful for route cost, which is section 5's concern, but the "guided free placement" framing is dropped. |
| Road cost depends only on length in tiles. No other term. | **Confirmed as correct.** The per-tile rule stays. The running cost of a long road — oxygen demand and waste — is where length gains an ongoing consequence. See `docs/RESOURCE_ECONOMY_DESIGN.md` section 4.3. |
| `throughput` and `pressure` have no understood purpose. | **Both are removed**, not repaired. Their replacement is the oxygen supply/demand ratio. See `docs/RESOURCE_ECONOMY_DESIGN.md` section 6. |
| The fault is boring: one click resolves it, and nothing states that it exists. | **Confirms 1.5 and 1.6.** S5 stands as written and remains unimplemented. |

### 1.11 Summary

The build is a functioning prototype of a *presentation*: four backdrops, a
placement tool, a routing tool, a repair tool, and a progression gate. It is not
yet a game, because none of the player's inputs change any outcome the player can
observe. The fix is not more content. It is to give the two maps different verbs
and to make their numbers move continuously.

---

## 2. Design principle

> **Each organ should be played the way it works.**

The Nutrient Exchange and the Circulatory System are opposites in biological
function, and the design should make them opposites in play:

| | Nutrient Exchange | Circulatory System |
|---|---|---|
| Organ identity | Absorptive interface | Closed-loop pump |
| What it optimises | **Surface area** in contact with a supply | **Coverage per unit of pressure** around a circuit |
| Shape that wins | Thin, spread, maximum frontage | Compact loop touching many districts |
| Player verb | **Grow** | **Route and tune** |
| Failure mode | The interface clogs | The circuit over-pressurises |
| Time pressure | Slow, economic | Fast, rhythmic |

Currently both maps use the identical verb — place a 6 × 6 box, draw one road.
That single fact explains most of section 1.

---

## 3. Shared changes

These five apply to both maps and are prerequisites for anything in sections 4 and
5.

### S1. Continuous tick

Introduce a slow simulation tick that runs whenever a map is open. Facilities
produce, districts consume, waste accumulates. Every number the interface shows
must be a number that moves.

Without this, no spatial decision can ever pay off, because nothing accrues.

### S2. Tissue types instead of a uniform grid

Replace `FULL_MAP_BUILD_ZONE` with per-map tissue data:

| Tissue | Rule |
|---|---|
| Open tissue | Buildable, normal route cost |
| Dense tissue | Buildable, higher route cost per tile |
| Supply region | Not buildable; adjacency to it is what the player wants |
| Blocked | Not buildable, not routable |

The existing map art already reads as regions. The nutrient map has large gold
pools; the circulatory map has distinct chambers and districts. The data should be
authored to match what is already drawn.

### S3. Routing must be drawn, not auto-completed

`RouteTool.extend_to()` should accept only cells adjacent to the current path end.
Long jumps are rejected rather than auto-filled. Drag-to-draw should work; the
observed press-move-release sequence currently produces no path because
`_route_dragging` is cleared on the first button release.

Once the player draws the path, the penalties for length and turns become real
choices rather than dead configuration.

### S4. Persistent objective and status region

Render `_objective_text()` and the current feedback string in the region below the
map, permanently. Add a short "why" line next to each live metric, for example
`Flow 68% — 4 extra turns`. The pointer card stays for hover detail only.

### S5. Emergent faults

Delete `bottleneck_required` and `trigger_bottleneck()`'s midpoint rule. A fault
occurs on the segment with the highest sustained utilisation, when utilisation
stays above a threshold for a period. The fault therefore appears exactly where
the player's layout is weakest, which makes the repair diagnostic instead of a
search task.

Warn before draining: a segment should visibly strain for several seconds before
it faults, and the strain should be legible at a glance.

---

## 4. Map one · Nutrient Exchange — the verb is GROW

### 4.1 Core mechanic: absorptive frontage

The organ's entire job is surface area against a supply. So the player's job
should be to buy surface area.

- The map contains **supply pools** (the gold regions already in the art).
- The player places the Exchange Depot, then grows **absorptive branches** from
  it. Branches are drawn tile by tile, like a road, but they are the production
  structure rather than a delivery route.
- **Income per tick is the number of branch tiles orthogonally adjacent to a
  supply pool.** Branch length that is not adjacent to a pool produces nothing.
- Each branch tile costs Cell Material to build and a small amount of upkeep per
  tick.
- Branches may not run adjacent to each other. Crowded branches block each other,
  which forces the player to spread rather than to blob.

The resulting optimisation is legible and organ-accurate: sprawl thin along pool
frontage; do not build a fat trunk.

### 4.2 The decision this creates

Every branch tile is a purchase with a payback period. Frontage tiles pay for
themselves; connector tiles never do. The player is choosing how much of the map's
available frontage to buy, and in which order, against a Cell Material budget that
also has to fund map two.

Depot placement now matters directly, because it determines how much connector
tile the player must pay for to reach each pool.

### 4.3 Second decision: gate allocation

The interface is two-way. Give the depot a small fixed number of gate slots that
the player assigns between **intake** and **clearance**:

- Intake-heavy: higher Nutrient Energy income, waste rises.
- Clearance-heavy: waste stays low, income is poor.

Waste above a threshold reduces effective frontage — the interface clogs.
Recoverable by re-allocating gates and waiting, never a game over.

This is the first point in the game where `waste` has a consequence the player can
feel, and it is a live dial rather than a one-time modal question.

### 4.4 Why this map first

It needs no new art. The pools are drawn. The branch renderer can reuse the
existing road tile set. It introduces the tick, the frontage number, and the
waste dial, all of which map two depends on.

---

## 5. Map two · Circulatory System — the verb is ROUTE AND TUNE

### 5.1 Core mechanic: the loop must close

The most important fact about circulation, and the one the current build misses
completely, is that **blood comes back**. A one-way road to the right edge is the
wrong shape for this organ.

- The heart facility exposes two ports: an **outflow** and an **inflow**.
- The player draws a circuit from outflow, through the map, back to inflow.
- The circuit runs only when it is closed. An open path delivers nothing.
- Districts sit around the map and consume. A district is **served** when the
  circuit passes orthogonally adjacent to it.
- **Coverage** is the fraction of districts served.

This turns routing into a real spatial problem: one closed loop must touch many
scattered districts, while every extra tile costs Cell Material and every turn
costs pressure. There is no free optimum for the tool to generate.

### 5.2 Second mechanic: rate

The heart has a beat rate the player sets and can change at any time.

- Higher rate: more flow per tick, more districts fully supplied, **pressure rises**
  on the longest straight run and on tight turns.
- Lower rate: safe, but distant districts starve.

Sustained pressure above a threshold strains, then faults, the highest-utilisation
segment — the emergent fault of S5. The player's remedy is to lower the rate, to
shorten the loop, or to spend on capacity for that segment.

Rate gives the map its own rhythm and makes `pressure` a two-sided dial for the
first time.

### 5.3 Third mechanic: order along the loop

Districts earlier in the circuit draw flow first. A district placed late in a long
loop starves when upstream demand is high, even at full coverage.

This is true of real vasculature and it adds a dimension that pure shape does not:
the same loop traversed in the other direction produces a different result. The
remedy is to re-route, to reorder, or to raise the rate — three different costs for
the same symptom.

### 5.4 What the player learns

That coverage, pressure, and starvation are three different failures with three
different fixes, and that they trade against each other. That is a systems lesson,
and it is the thing the current build's single scripted fault cannot teach.

---

## 6. Connecting the two maps

Today the link is cosmetic. It should be economic.

- Map one's frontage produces Nutrient Energy per tick.
- Map two's heart and every district on it consume Nutrient Energy per tick.
- If map one's frontage is thin, map two runs starved. The symptom appears on map
  two; the cause and the fix are on map one.

This gives the system switcher its purpose. The player leaves a finished map,
finds map two constrained by it, and goes back to buy more frontage. That
round trip is the loop the current build is missing entirely, and it costs no new
art or content to create.

It also replaces the flat completion reward, which currently makes a finished map
inert.

---

## 7. Failure model

No game over. Falling short produces a **carried deficit** rather than a reset:

| Shortfall | Consequence |
|---|---|
| Waste over the clog line | Effective frontage reduced until cleared |
| Coverage below target | Districts visibly idle; production reduced |
| Sustained over-pressure | A segment strains, then faults, then drains stability |
| Stability at zero | Production floor, not a loss screen |

The build's current 1.5-per-second stability drain during an unlabelled fault is
harsher than any of these and communicates less. It should be replaced by the
strain-then-fault warning of S5.

---

## 8. Implementation order

Each step should be playable before the next begins.

| # | Step | Proves |
|---|---|---|
| 1 | Tick, persistent objective region, live income readout (S1, S4) | The player watches a number that moves |
| 2 | Tissue data for map one; frontage branch growing and income (S2, 4.1) | Where and how much you build changes that number |
| 3 | Gate allocation and the waste clog line (4.3) | A live dial with a two-sided cost |
| 4 | Adjacent-only route drawing (S3) | Routing is an action, not a click |
| 5 | Closed circuit, districts, coverage on map two (5.1) | Loop shape is a real puzzle |
| 6 | Rate, utilisation, strain-then-fault (5.2, S5) | Faults are diagnostic |
| 7 | Order-along-loop starvation (5.3) | Three failures, three fixes |
| 8 | Cross-map economy (section 6) | A finished map stays alive |

Step 2 is the highest-value, lowest-cost slice and should be built first after
step 1. It reuses existing art entirely and tests the single riskiest assumption in
this document: that *"where and how much I build changes a number I watch"* is more
engaging than *"place box, draw line, press continue."*

If step 2 does not read to a first-time player, nothing later in this list will
save it.

---

## 9. Relationship to existing specifications

This design conflicts with several locked documents. The conflicts are listed here
for a decision; nothing has been changed.

| Document | Conflict |
|---|---|
| `docs/GAME_RULES.md` | Defines exactly six player actions. Growing a branch, allocating gates, and setting a heart rate are not among them. |
| `docs/MINIGAME_SPEC.md` | Caps minigames at twenty percent of operating time and forbids a minigame from reading `stability`, `waste`, `transport_pressure`, or `signal_coverage`. Sections 4 and 5 promote that kind of interaction into the core loop. |
| `docs/CHAPTER_TIMELINE.md` | Locks a four-stage embryonic timeline with seven build decisions and four operation decisions. The shipped build already uses four body-system maps instead. The two structures have not been reconciled. |
| `docs/OPERATION_SPEC.md` | Table E7 requires emergent bottleneck detection. The shipped `bottleneck_required` flag violates it. S5 restores compliance. |
| `docs/SYSTEM_MAP_MODE.md` | States that objective and feedback text stay below the map. The shipped build renders that region empty. S4 restores compliance. |

Two of these — the `OPERATION_SPEC` and `SYSTEM_MAP_MODE` conflicts — are the
implementation diverging from its own specification and should be fixed regardless
of whether this design is adopted.
