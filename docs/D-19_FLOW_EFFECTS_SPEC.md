# D-19 Flow Effects: PixelLab vs Godot Particle Approach

## Context

Transport-network edges render one of four flowing substances in one of three
passage states. The visual contract requires:
- Direction identifiable in a still grayscale screenshot (ART_BIBLE.md §4)
- Non-color signal for substance identity (silhouette/shape)
- Non-color signal for passage state (continuous/dash/crossbar)
- Integer-pixel alignment, 22-color palette, no sub-pixel motion

## Substance identity (4 types)

| Substance | Semantic color | Particle shape | Pixel size |
|---|---|---|---|
| Nutrient energy | Warm amber #E2953A | Bright square, warm glow | 2×2 px |
| Cell material | Tissue pink #BE6E87 | Solid rectangle | 3×2 px |
| Developmental signal | Blue violet #404586 | Pulsing diamond | 2×2 px, offset phase |
| Waste | Neutral dark #514854 | Slow circle, accumulation | 2×2 px, dark |

## Passage state (3 states)

| State | Flow rate | Visual pattern | Particle behavior |
|---|---|---|---|
| Open | Full | Continuous stream | Particles flow at 1× edge speed |
| Restricted | Reduced | 2-on/1-off dash pattern | Particles flow at 0.5×, gaps visible |
| Blocked | Zero | Static crossbar + held particles | No movement, crossbar on each arm |

## Approach A: Pure Godot GPUParticles2D

- **Pros**: Native engine support, no asset files, deterministic at any resolution,
  substance identity encoded in particle texture shape, runtime-tuneable.
- **Cons**: GPU-dependent look may clash with pixel-art aesthetic; sub-pixel
  motion is the default and must be intentionally constrained.
- **Asset count**: 4 small texture files (one per substance, ~16×16 each).
- **PixelLab calls**: 0.
- **Verifiability**: Particle seed is deterministic; screenshots are reproducible.

## Approach B: PixelLab-Generated Flow Sprites

- **Pros**: Hand-crafted pixel-art flow textures, exact palette control, baked
  passage-state variants, no runtime particle simulation needed.
- **Cons**: Each substance–state combination requires a static sprite or
  animation strip; 4 substances × 3 states = 12 assets minimum. Direction
  variants would multiply further. Does not solve runtime flow along dynamic
  edge geometry.
- **Asset count**: 12+ sprite sheets.
- **PixelLab calls**: 12+.
- **Verifiability**: Each sprite is a static PNG; no runtime variables.

## Approach C: Hybrid — PixelLab Textures + Godot Animation (SELECTED)

PixelLab generates one reusable 16×16 particle texture per substance. Godot
GPUParticles2D spawns the texture along transport edges using deterministic
seeds. Substance identity is encoded in texture shape; passage state is
encoded in emission rate and pattern; direction is encoded in velocity sign.

- **Pros**: Combines PixelLab pixel-art quality with Godot's deterministic
  particle routing. One texture per substance (4 PixelLab calls). No runtime
  palette violations. Substance × state matrix is 4 × 3 = 12 configurations
  driven by parameters, not 12 separate assets.
- **Cons**: Requires pixel-snapping in the particle shader.
- **Asset count**: 4 PixelLab textures + 1 Godot particle material per substance.
- **PixelLab calls**: 4.
- **Verifiability**: Deterministic seed + locked palette = reproducible screenshots.

## Decision

Approach C is selected. PixelLab generates four 16×16 particle textures.
Godot routes them with GPUParticles2D constrained to integer-pixel positions,
D-09 edge interfaces, and the 22-color palette. No new asset files are
created for passage-state or direction variants — those are runtime parameters.

## Specification: Flow particle textures

### Nutrient energy particle (`particle_nutrient.png`)
- 16×16 px, binary alpha, 22-color palette
- Central 2×2 warm amber square (#E2953A)
- 1-pixel amber outline (#B26C09) on square perimeter
- Remaining pixels transparent
- Shape: square — distinct from diamond (signal) and circle (waste)

### Cell material particle (`particle_material.png`)  
- 16×16 px, binary alpha, 22-color palette
- Central 3×2 tissue pink rectangle (#BE6E87)
- 1-pixel tissue dark outline (#91465F) on rectangle perimeter
- Shape: wide rectangle — distinct from square (nutrient)

### Developmental signal particle (`particle_signal.png`)
- 16×16 px, binary alpha, 22-color palette  
- Central 2×2 blue violet diamond (#404586) — a diamond shape, not a square
- 1-pixel dark violet outline (#29314A) on diamond perimeter
- Shape: diamond — distinct from square and rectangle

### Waste particle (`particle_waste.png`)
- 16×16 px, binary alpha, 22-color palette
- Central 2×2 neutral dark circle (#514854)
- 1-pixel outline (#140F1D) — darker outline than others
- Shape: circle — distinct from square, rectangle, and diamond

### Authoritative silhouette correction

The global `docs/ENCODING_SPEC.md` resource silhouettes supersede the earlier
tiny square/rectangle/diamond/circle descriptions above. Each production
particle is a transparent 16 by 16 canvas containing the corresponding fixed
8 by 8 silhouette centered at `(4, 4)`, with one opaque locked-palette color:

- `particle_nutrient.png`: nutrient diamond in warm amber `#E2953A`
- `particle_material.png`: lower-right-notched square in tissue pink `#BE6E87`
- `particle_signal.png`: upward triangle in blue violet `#404586`
- `particle_waste.png`: hollow hexagon in neutral dark `#514854`

No outline color, glow, rotation, or partial alpha is added.

## Godot particle configuration (per substance)

| Parameter | Open | Restricted | Blocked |
|---|---|---|---|
| `amount` | 4 per edge | 2 per edge | 0 (hidden) |
| `lifetime` | 0.5 s | 0.8 s | — |
| `speed_scale` | 1.0 | 0.5 | 0.0 |
| `emitting` | true | true | false |
| Crossbar overlay | none | none | D-09 blocked crossbar |

Direction is encoded in `direction.x` sign per edge; outward = +1, return = −1.
The particle system snaps to integer pixels via a floor-round shader modifier.

## Verification

1. Generate 4 particle textures with PixelLab.
2. Open the Godot editor and attach the particle material to one transport edge.
3. Verify square/diamond/circle/rectangle remain distinct in grayscale.
4. Verify open/restricted/blocked states read correctly with color hidden.
5. Take still screenshots and confirm direction from particle position gradient.
