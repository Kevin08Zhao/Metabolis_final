# Resource Economy and HUD Design

Scope: the resource model, the per-second economy, and the resource HUD for the
first two body-system maps, `system_nutrition` and `system_circulation`.

This document replaces the four-resource model currently used by
`src/game/system_city_prototype.gd`. It defines the new resource set, the tick
rules, a first-pass numeric table, the HUD layout, and the `ResourcePool`
interface. It does not change any gameplay mechanic outside the economy; the
placement, routing, and fault mechanics proposed in
`docs/SYSTEM_MAP_GAMEPLAY_DESIGN.md` remain unimplemented and out of scope here.

---

## 1. Why the current four resources fail

Observed in a full playthrough of `main` at `2af3cdd`.

### 1.1 Three of the four are the same thing

`nutrient_energy`, `cell_material`, and `development_signal` are all
"a number you accumulate and then spend." They differ only in name and icon.
A player cannot learn the difference between them, because there is no difference
in behaviour to learn.

### 1.2 Two of them are one-time gates

| Resource | Spent on | Earned from, maps 1–2 |
|---|---|---|
| `nutrient_energy` | Facility placement (10, then 15) | One completion reward of 24 |
| `cell_material` | Facility 18/22, road 1 per tile, repair 6 | Completion rewards 8 and 18 |
| `development_signal` | Facility 6/12, repair 8 | **Nothing** — the first grant is on map three |
| `stability` | Cannot be spent | Drains 1.5/s during a fault; +4 on map two |

Only Cell Material has a recurring role. Nutrient Energy and Development Signal
are thresholds the player crosses once, after which their numbers sit still for
the rest of the run. Development Signal is strictly negative-sum across the first
two maps.

### 1.3 Nothing changes with time

No production, no consumption, no upkeep. Between button presses every value is
frozen. There is no reason to look at the HUD, and no reason for a building to
feel like an asset rather than a purchase.

### 1.4 The names are invisible

`RESOURCE_DISPLAY_NAMES` and per-metric `tooltip_text` are both populated
correctly, but `_build_resource_status()` sets
`mouse_filter = Control.MOUSE_FILTER_IGNORE` on the status panel, on every metric
container, on every icon, and on every value label. Godot does not deliver hover
events to a control with `MOUSE_FILTER_IGNORE`, so **no tooltip in the resource
bar can ever appear.** The player sees four unlabelled icons and four bare
integers.

This is a bug, not a design choice, and it explains most of the "I have no idea
what these are" experience.

### 1.5 Confirmed design positions

Recorded from review, and treated as settled for this document:

- Placement position does not need a validity constraint. Placing a facility
  costs resources; where it goes does not need to be restricted.
- Road cost depends only on length in tiles. No other term.
- `throughput` and `pressure` have no understood purpose and are removed by this
  document. See section 6.
- The fault is not interesting: one click resolves it, and nothing on screen
  states that it exists. Out of scope here; recorded in
  `docs/SYSTEM_MAP_GAMEPLAY_DESIGN.md`.

---

## 2. The new model: three flows and one state

The body runs on three distinct behaviours — cells **eat**, **breathe**, and
**excrete** — and each behaviour has a different numeric shape. Giving each
resource a different *type* is what makes them learnable.

| | Type | Meaning |
|---|---|---|
| **Biomass** | Stock | The only spendable currency. Accumulates. |
| **Oxygen** | Supply vs demand | Never stockpiled. A ratio, evaluated every tick. |
| **Waste** | Accumulation | Rises with activity, falls with clearance. Wants to be low. |
| **Stability** | State, 0–100 | Not a resource. The consequence of the three above. |

Compared against the old set: Biomass replaces Nutrient Energy, Cell Material,
and Development Signal together. Oxygen and Waste are new. Stability stops being
displayed as a resource and becomes a bar.

### 2.1 Biomass — the stock

- Displayed as `BIO`.
- Produced per second by every operating facility.
- Spent on: facility placement, road tiles, fault repair.
- The single number the player budgets against. Nothing else is spendable.

### 2.2 Oxygen — the supply/demand pair

- Displayed as `OXY supply/demand`, for example `OXY 10/6`. The generated
  pixel font has no subscript glyph and its capital O reads as a zero, so the
  label spells out three letters rather than using a chemical symbol.
- **Not a stock.** There is no oxygen balance to save or carry.
- Supply comes from exchange facilities. Demand comes from every operating
  facility and every road tile.
- When demand exceeds supply, *all* Biomass production scales down by the ratio.
  The city browns out rather than stopping.

This is where the removed `throughput` value goes. Oxygen ratio is the throughput
multiplier, it is visible, and it has a cause the player can point at.

### 2.3 Waste — the accumulation

- Displayed as `WST` with its net rate.
- Every operating facility and every road tile generates waste per second.
- Clearance capacity removes it per second.
- Net rate is what the HUD shows. A positive rate is bad and renders red.
- Above the waste capacity fraction, stability begins to fall.

### 2.4 Stability — the state bar

- Displayed as a horizontal bar with a numeric value, visually separated from the
  three metrics.
- Cannot be spent, cannot be stockpiled, is never a build cost.
- Falls when waste is high or oxygen is short. Recovers when both are healthy.
- Low stability multiplies Biomass production down. It is a feedback loop, and it
  is always recoverable — there is no loss state.

---

## 3. Tick rules

Tick length is 1.0 second of real time. All rates below are per second.
Every constant named in capitals belongs in `docs/BALANCE.json`; the values in
section 4 are a first pass, not a locked balance.

### 3.1 Order of evaluation

Fixed, and evaluated once per tick:

1. Recompute `oxygen_supply` and `oxygen_demand` from the registered sources.
2. Compute `oxygen_ratio`.
3. Compute `stability_factor` from the *previous* tick's stability.
4. Settle Biomass.
5. Settle Waste.
6. Settle Stability.

Stability is settled last so that a tick's production always reflects the state
the player could see at the start of that tick.

### 3.2 Oxygen

```
oxygen_supply = Σ source.oxygen_supply
oxygen_demand = Σ source.oxygen_demand
oxygen_ratio  = clamp(oxygen_supply / max(oxygen_demand, OXYGEN_DEMAND_FLOOR), 0, 1)
```

`oxygen_ratio` is capped at 1. Excess supply is headroom, not a bonus.

### 3.3 Stability factor

```
stability_factor =
    1.0   if stability >= STABILITY_HEALTHY      (70)
    0.7   if stability >= STABILITY_STRAINED     (35)
    0.4   otherwise
```

Three tiers, not a continuous curve, so the player can see a discrete change
happen and connect it to the bar crossing a marked line.

### 3.4 Biomass

```
biomass_rate = (Σ source.biomass_output) * oxygen_ratio * stability_factor
biomass      = max(biomass + biomass_rate * dt, 0)
```

Biomass has no cap in this pass.

### 3.5 Waste

```
waste_in    = Σ source.waste_output
waste_out   = Σ source.waste_clearance
waste_rate  = waste_in - waste_out
waste       = clamp(waste + waste_rate * dt, 0, WASTE_CAPACITY)
waste_ratio = waste / WASTE_CAPACITY
```

Waste clamps at capacity rather than growing without bound; the damage comes from
sitting at capacity, not from the number itself.

### 3.6 Stability

```
stability_rate = STABILITY_RECOVERY                                  (+1.5)
               - STABILITY_WASTE_WEIGHT * max(waste_ratio - WASTE_SAFE, 0) / (1 - WASTE_SAFE)
               - STABILITY_OXYGEN_WEIGHT * (1 - oxygen_ratio)

stability = clamp(stability + stability_rate * dt, 0, 100)
```

With the section 4 values, a city inside both safe bands recovers at +1.5/s and
pins at 100. A city at full waste and no oxygen falls at −4.5/s.

---

## 4. First-pass numbers

### 4.1 Constants

| Constant | Value |
|---|---|
| `TICK_SEC` | 1.0 |
| `BIOMASS_START` | 180 |
| `WASTE_CAPACITY` | 60 |
| `WASTE_SAFE` | 0.5 |
| `STABILITY_START` | 100 |
| `STABILITY_HEALTHY` | 70 |
| `STABILITY_STRAINED` | 35 |
| `STABILITY_RECOVERY` | 1.5 |
| `STABILITY_WASTE_WEIGHT` | 2.0 |
| `STABILITY_OXYGEN_WEIGHT` | 4.0 |
| `OXYGEN_DEMAND_FLOOR` | 0.001 |

### 4.2 Costs, in Biomass

| Action | Cost |
|---|---|
| Place Nutrient Exchange Depot | 60 |
| Place Central Heart Transit Station | 80 |
| Road, per tile | 2 |
| Repair a faulted segment | 15 |

Road cost is length times two, and nothing else. This matches the confirmed
position in 1.5.

`BIOMASS_START` has a hard lower bound: it must fund the first facility, a
detoured first road, and one fault repair, or the opening map cannot be
finished. At 60 + 50 + 15 that floor is 125, and 180 leaves a working margin.
An acceptance run at 120 stalled on exactly this.

### 4.3 Per-second contribution by source

Both maps produce Biomass, as decided. They differ in what else they contribute:
the exchange facility is the city's oxygen source, and the heart is the city's
clearance capacity.

| Source | Biomass | Oxygen supply | Oxygen demand | Waste out | Clearance |
|---|---:|---:|---:|---:|---:|
| Nutrient Exchange Depot | +3.0 | +10.0 | 2.0 | +0.40 | +0.40 |
| Central Heart Transit Station | +1.5 | 0 | 3.0 | +0.30 | +1.10 |
| Road tile, each | 0 | 0 | 0.03 | +0.01 | 0 |

A facility contributes nothing until construction completes and its route is
committed. A route contributes from the tick after it is committed.

### 4.4 Worked states

Assuming a 19-tile road on each map, which is what the observed playthrough
produced.

**Map one only, depot operating:**

```
Biomass    +3.00/s        payback on the 60 + 38 build cost: ~33 s
Oxygen     10.0 / 2.57    ratio 1.00
Waste      in 0.59, out 0.40  ->  +0.19/s
Stability  100, holding
```

Waste drifts upward and cannot be fixed on map one. It reaches the `WASTE_SAFE`
line at 30 units after about 160 seconds, at which point stability begins a slow
decline. This is intentional: it is the problem the second map solves.

**Both maps operating, 38 road tiles total:**

```
Biomass    +4.50/s
Oxygen     10.0 / 6.14    ratio 1.00
Waste      in 1.08, out 1.50  ->  -0.42/s   (drains to zero)
Stability  100, holding
```

Building the heart visibly reverses the waste trend. This is the intended
teaching moment of the first two maps, and it is why the heart produces less
Biomass than the depot but is still worth 80: **the circulatory system is what
takes the rubbish out.**

### 4.5 The intended difficulty curve

Maps one and two are deliberately comfortable on oxygen. The first genuine
oxygen deficit should arrive on map three, where the nervous system's demand is
large, and be resolved on map four when the respiratory facility adds supply.
That is both a reasonable curve and biologically true — the brain is a large
share of the body's oxygen budget, and the lungs are what pay for it.

Those two maps are out of scope here and their numbers are not defined by this
document.

---

## 5. HUD design

### 5.1 Layout

The top bar is 800 × 40 in a 800 × 450 interface. The status panel currently
occupies `(416, 5)` at `374 × 30`. The new panel keeps that rectangle and splits
it into two rows.

```
 NUTRIENT EXCHANGE MAP           ◆ BIO 152 +2.4   ▲ OXY 10/6   ■ WST 18 +0.2
                                  ████████░░  STABILITY 82
```

- Row one, 18 px: three metrics, roughly 120 px each.
- Row two, 10 px: the stability bar plus its value.

The stability bar sits visually apart from the three metrics so that its
different nature is readable without explanation.

### 5.2 Metric format

| Metric | Format | Example |
|---|---|---|
| Biomass | `BIO <stock> <signed rate>` | `BIO 152 +2.4` |
| Oxygen | `OXY <supply>/<demand>` | `OXY 10/6` |
| Waste | `WST <stock> <signed rate>` | `WST 18 +0.2` |

The `/s` suffix is dropped in the top bar for width and appears in the hover
panel. Rates show one decimal place; stocks are integers.

### 5.3 Colour rules

| Condition | Colour |
|---|---|
| Biomass rate positive | positive accent |
| Biomass rate zero or negative | warning |
| Oxygen demand ≤ supply | neutral |
| Oxygen demand > supply | warning, and the demand figure blinks once on crossing |
| Waste rate negative, i.e. clearing | positive accent |
| Waste rate positive | warning |
| Waste at capacity | critical |
| Stability ≥ 70 / ≥ 35 / below | neutral / warning / critical |

Colours come from `docs/PALETTE.md`. The bar carries tick marks at 35 and 70 so
the tier boundaries of 3.3 are visible rather than implied.

### 5.4 Hover detail

Hovering any of the three metrics opens a panel below the top bar listing every
contributing source. This is the "abbreviated in the bar, detail on hover"
decision.

```
BIOMASS                              152
  Nutrient Exchange Depot          +3.0/s
  Heart Transit Station            +1.5/s
  Oxygen efficiency                 x1.00
  Stability efficiency              x1.00
  ---------------------------------------
  Net                              +4.5/s
```

```
OXYGEN                            10 / 6
  Nutrient Exchange Depot   supply  +10.0
  Nutrient Exchange Depot   demand    2.0
  Heart Transit Station     demand    3.0
  Roads, 38 tiles           demand    1.1
  ---------------------------------------
  Ratio                             1.00
```

```
WASTE                                 18
  Nutrient Exchange Depot           +0.40
  Heart Transit Station             +0.30
  Roads, 38 tiles                   +0.38
  Heart clearance                   -1.10
  Depot clearance                   -0.40
  ---------------------------------------
  Net                               -0.42
  Capacity                          18/60
```

Every line is a source the player built. There is no line the player cannot act
on.

### 5.5 Required fix: hover must be possible

`_build_resource_status()` and `_build_resource_metric()` currently set
`mouse_filter = Control.MOUSE_FILTER_IGNORE` on:

- the `ResourceStatus` panel
- the `ResourceStatusRow` container
- every `*Metric` container
- every `*Icon`
- every `*Value` label

Every one of these blocks hover delivery. The new implementation must use:

- `MOUSE_FILTER_STOP` on each metric container, which is the hover target,
- `MOUSE_FILTER_PASS` on the panel and row so events reach the metric,
- `MOUSE_FILTER_IGNORE` may stay on the icon and label, since the parent metric
  is the target.

Without this change no detail panel and no tooltip can ever be shown, which is
the state the shipped build is in.

### 5.6 Icons

The three shapes in `docs/ENCODING_SPEC.md` are reused by role, not by old name:

| New resource | Reuse |
|---|---|
| Biomass | the diamond currently assigned to nutrient energy |
| Oxygen | the triangle currently assigned to development signal |
| Waste | the notched square currently assigned to cell material |

`ENCODING_SPEC.md` fixes the silhouettes but not which resource owns which
silhouette, so no new art is required for this pass. Renaming the asset keys is a
follow-up, not a blocker.

---

## 6. What this removes

| Removed | Reason |
|---|---|
| `nutrient_energy`, `cell_material`, `development_signal` | Merged into Biomass. Three identical behaviours collapsed into one. |
| `_route_plan_metrics().throughput` | Its only consumer was a one-time completion reward. Its role is taken by `oxygen_ratio`, which is visible and has an actionable cause. |
| `_route_plan_metrics().pressure` | Read by no rule at all. Route length now expresses itself as Biomass cost, oxygen demand, and waste. |
| `_facility_support_distance()` | Its only purpose was feeding `pressure`. Placement position carries no constraint, per 1.5. |
| `_scaled_completion_reward()` and all `completion_reward` entries | Income is continuous now. A one-time lump payment on map completion works against the whole point of a tick economy and makes a finished map inert. |
| `RESOURCE_ICON_ASSETS` warning state driven by `_resource_requirement_for_current_action()` | Superseded by the colour rules in 5.3, which are driven by the economy rather than by the pending action. |

Removing the completion reward means the player's incentive to finish a map is
that the new facility raises their permanent production, not that a popup grants
a lump sum. That is the correct incentive for a builder.

---

## 7. `ResourcePool` interface

The prototype currently keeps a local `_resources: Dictionary` and never touches
`src/data/resource_pool.gd`. `ResourcePool` already declares `per_tick_output`
and `per_tick_consumption` and an empty `apply_tick()`. The economy moves there.

### 7.1 State

```gdscript
class_name ResourcePool
extends RefCounted

# Saved state
var biomass: float = 0.0            # SAVED # SNAPSHOT
var waste: float = 0.0              # SAVED # SNAPSHOT
var stability: float = 0.0          # SAVED # SNAPSHOT

# Derived every tick, never saved
var oxygen_supply: float = 0.0
var oxygen_demand: float = 0.0
var oxygen_ratio: float = 1.0
var biomass_rate: float = 0.0
var waste_rate: float = 0.0
var stability_rate: float = 0.0

# Per-source breakdown, keyed by source id. Feeds the hover panel of 5.4.
var per_tick_output: Dictionary = {}       # SAVED # SNAPSHOT
var per_tick_consumption: Dictionary = {}  # SAVED # SNAPSHOT
```

`per_tick_output` and `per_tick_consumption` finally have a consumer: they are
exactly the breakdown the hover panel renders. They are not recomputed from
scratch by the HUD.

### 7.2 Source registration

```gdscript
func register_source(source_id: StringName, spec: Dictionary) -> void
func unregister_source(source_id: StringName) -> void
func sources() -> Dictionary
```

`spec` keys, all optional and defaulting to zero:

```
biomass_output, oxygen_supply, oxygen_demand, waste_output, waste_clearance
```

Callers:

| Event | Call |
|---|---|
| Facility construction completes | `register_source(system_id, facility spec)` |
| Route committed | `register_source("%s_roads" % system_id, road spec x tile count)` |
| Route cleared or redrawn | `unregister_source`, then re-register |
| Network reset | `unregister_source` for everything on that map |

Registering roads as a single aggregated source, scaled by tile count, keeps the
hover panel to one line per map rather than one line per tile.

### 7.3 Tick

```gdscript
func apply_tick(tick_delta: float) -> void
```

Implements section 3 exactly, in that order, and refreshes every derived field
and both breakdown dictionaries. It emits nothing; the HUD polls the pool each
frame.

### 7.4 Spending

```gdscript
func can_afford(biomass_cost: float) -> bool
func spend(biomass_cost: float) -> bool
```

Only Biomass is spendable, so these take a scalar rather than a cost dictionary.
Every call site that currently builds a three-key cost dictionary collapses to
one number.

### 7.5 Save

`biomass`, `waste`, and `stability` are saved. Oxygen is never saved, because it
is not a stock — it is recomputed from the registered sources on load. Sources
are rebuilt from placed facilities and committed routes rather than serialised
separately.

---

## 8. Implementation order

| # | Step | Verifiable result |
|---|---|---|
| 1 | Implement `ResourcePool` state, `register_source`, and `apply_tick` per sections 3 and 7 | Unit test: the two worked states of 4.4 reproduce to two decimal places |
| 2 | Migrate `system_city_prototype.gd` off `_resources` onto `ResourcePool`; single Biomass cost at every call site | The game still completes both maps, now with one currency |
| 3 | Drive a 1 s tick while a map is open | Biomass climbs on screen without the player pressing anything |
| 4 | Rebuild the top bar to 5.1–5.3, including the stability bar | Three labelled metrics with live signed rates |
| 5 | Fix `mouse_filter` per 5.5 and add the hover detail panel of 5.4 | Hovering Biomass lists every building that contributes to it |
| 6 | Delete the items in section 6 | No dead metric remains on screen |

Step 3 is the first point at which the player can see the thing that is currently
missing. Step 5 is the first point at which they can find out why.

---

## 9. Open items

- **Waste has no player-facing dial in this pass.** The player can only affect it
  by building the heart. The gate-allocation mechanic in section 4.3 of
  `docs/SYSTEM_MAP_GAMEPLAY_DESIGN.md` is the intended dial and is not
  implemented here.
- **Maps three and four are unbalanced against this model.** Their facility specs
  and the intended oxygen deficit of 4.5 need their own numbers.
- **Specification conflicts.** `docs/OPERATION_SPEC.md` and
  `docs/ENCODING_SPEC.md` both name the six-resource set
  (`nutrient_energy`, `cell_material`, `development_signal`, `waste`,
  `stability`, `knowledge_badge_count`). This document replaces the first three
  with Biomass and introduces Oxygen. Those specifications need a revision pass
  before or alongside implementation; nothing in them has been changed yet.
- **`knowledge_badge_count`** is declared in `ResourcePool` and used nowhere. It
  is left untouched and unrendered.
