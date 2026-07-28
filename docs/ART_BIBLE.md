# Metabolis: City of Life — Birth Visual Bible

> Single source of truth: characters, environments, UI, and promotional art must pass Section 6.

## 1. Style Definition

**What it is:** Warm 16-bit- and 32-bit-inspired pixel art that maps body mechanisms to city roads, pump stations, industrial districts, and construction facilities. Silhouettes, turns, and animation keyframes land on integer pixels. At normal scale, every key organ is identifiable through silhouette, structure, and motion without labels.

**What it is not:**

- Not a medical illustration: no anatomical leader lines, realistic cross-sections, or proportional organ diagrams.
- Not gory: no wounds, dripping blood, exposed bones, or torn tissue.
- Not realistic rendering: no photographic textures, volumetric lighting, or continuous soft-focus shadows.
- Not a vector interface: no subpixel edges, smooth curves, or anti-aliased outlines.
- Not cyber-neon: no out-of-palette glow, chromatic fringes, or high-saturation gradients.
- Not a color-identification puzzle: every resource, direction, state, and bottleneck also has a non-color signal.

## 2. Palette and Use

The limit is 22 colors: six semantic groups with dark, main, and light values, plus one global outline and three neutral values. Sampling, interpolation, and additional colors are forbidden.

| Semantic group | Dark / main / light hex | Allowed use | Forbidden use |
|---|---|---|---|
| Arterial coral | `#340106` / `#BA3A3F` / `#C25453` | Transport trunks, heart emphasis, critical state | Waste, return flow, normal stability |
| Oxygen blue | `#48A5CF` / `#7AD1FD` / `#CDD9E1` | Teaching information, immediate prompts, knowledge badges | Decorative background, non-informational water |
| Blue violet | `#29314A` / `#404586` / `#53548C` | Return flow, fetal passages, developmental signals; the dark value also carries waste | Arteries, nutrients, ordinary roads |
| Tissue pink | `#91465F` / `#BE6E87` / `#C98197` | Organic walls, terrain, cell material | Direction, alerts, knowledge prompts |
| Warm amber | `#B26C09` / `#E2953A` / `#DDAD7E` | Nutrient energy, spendable material, warning state | Waste, return flow, completion marks |
| Mint green | `#73CD9B` / `#B1FFD1` / `#F4FFF8` | Good stability, completed construction | Critical state, incomplete construction, waste |
| Neutrals | `#140F1D` / `#514854` / `#817582` / `#E8DCCF` | Global outline and non-semantic dark, mid, and light surfaces | Resource, direction, or state encoding |

Shading within one semantic role may use only that group’s three values. Stability uses existing mint-green, warm-amber, and arterial-coral values; it never generates intermediate colors.

## 3. Outline Rules

- Every exterior outline uses the D-02 global outline `#140F1D`; object-specific colored outlines are forbidden.
- Ordinary objects use a 1-native-pixel exterior outline. A subject covering at least one quarter of the canvas width may use 2 native pixels, but one subject may not mix outline widths.
- When two objects of equal luminance touch, their shared edge must have a continuous outline or at least 1 native pixel of separation.
- Interior structure lines use neutral dark `#514854`; only exterior outlines and deepest occlusion seams use `#140F1D`.
- Semi-transparent edges, automatic anti-aliasing, and non-integer scaling are forbidden.

## 4. Composition and Camera

- Camera and object positions use integer pixels; runtime zoom uses integer factors only.
- At the normal camera position, UI may cover no more than 10% of an interactive subject’s complete silhouette.
- The placenta reads as a disc hub, radial transport branches, and an umbilical interface. The heart reads as paired pump chambers and rhythmic contraction. The lungs read as paired air sacs and a central airway. Missing any listed component fails acceptance.
- A construction zone simultaneously shows a closed boundary, unfinished hatch texture, and a construction-marker silhouette. All three disappear when construction completes.
- Transport direction appears through both arrow or node orientation and an animated sequence; it remains identifiable in a still grayscale screenshot.
- A bottleneck displays the Table E9 type-specific graphic at its runtime attachment: a narrow-neck hexagon with stacked directional arrows for transport pressure, a graduated angular container with a rising level for waste accumulation, or broken concentric circles with a gapped dotted wave for low signal coverage. A color-only change is forbidden.

## 5. Three Stability Tiers

Stability has a maximum of 100: normal is 67–100, warning is 34–66, and critical is 0–33. Boundary values use these inclusive ranges.

All tiers retain the fixed stability shield from `ENCODING_SPEC.md`; tiers may not substitute a new resource silhouette.

| Tier | Fill texture | Border | Motion |
|---|---|---|---|
| Normal | Solid | 1-pixel continuous border | Static |
| Warning | 2-pixel diagonal hatch | 2-pixel continuous border | One outward pulse every 2 seconds |
| Critical | 1:1 crosshatch | 3-pixel clipped-corner border | Two outward pulses every 1 second |

The three textures, borders, and rhythms are each pairwise distinct. With animation disabled, color removed, or text hidden, texture and border still identify every tier. Flashing may never exceed three changes per second.

## 6. Visual Acceptance Test

At normal game scale, hide text and remove color, then check every item. Any failure blocks integration:

- [ ] The placenta is identifiable.
- [ ] The heart is identifiable.
- [ ] The lungs are identifiable.
- [ ] A construction zone is identifiable.
- [ ] Transport-network direction is identifiable.
- [ ] The current stability tier is identifiable.
- [ ] The active bottleneck type is identifiable.

### Final Self-Check

| Rule most likely to be broken | Visible failure |
|---|---|
| Using a color outside the palette | One resource acquires multiple near-colors and cannot be read consistently across screenshots |
| Giving an object its own outline color | Scene boundaries loosen and equal-luminance objects merge in grayscale |
| Encoding stability tiers by color alone | Normal, warning, and critical cannot be distinguished pairwise under color-vision deficiency or grayscale |
| Encoding direction only with moving particles | Direction cannot be determined when paused or in a still screenshot |
| Identifying organs with text labels | The placenta, heart, or lungs become unrecognizable when text is hidden |
| Reusing one generic alert for every bottleneck | The player knows a problem exists but cannot distinguish transport pressure, waste accumulation, or low signal coverage |
