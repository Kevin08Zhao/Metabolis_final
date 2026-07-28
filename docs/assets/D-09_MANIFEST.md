# D-09 Transport-Network Variant Manifest

- Task status: `BLOCKED_RUNTIME_CONTRACT`
- Art production: deterministic local build, `tools/build_d09_vessel_variants.py`
- PixelLab calls: `0`
- Validation: `docs/assets/D-09_VALIDATION_REPORT.json`
- Native canvas: `16 × 16 px`, top-left anchor `(0,0)`
- Palette: exactly the locked project palette; binary alpha

## Quantity and reduction

The complete baked matrix contains:

`11 undirected logical geometries × 2 flow directions × 2 route roles × 3 passage states = 132 PNGs`

The eleven lossless logical geometries are `straight_ns`, `straight_ew`,
`corner_ne`, `corner_es`, `corner_sw`, `corner_wn`, `tee_nes`, `tee_esw`,
`tee_swn`, `tee_wne`, and `fourway_nesw`. They are quarter-turn derivatives
of the four D-08 canonical PNGs and introduce no new topology.

For runtime reduction, the same 132 appearances can be composed from four
D-08 canonical geometry masks plus these semantic layers:

- flow layer: outbound or return, with a locked semantic color and static
  chevrons oriented at every connected interface;
- route-role layer: a solid `2 × 2` center stud for trunk or a hollow
  four-corner stud for branch;
- passage layer: continuous fill for open, repeating `2 on / 1 off` gaps for
  restricted, or continuous fill plus a full crossbar on every connected arm
  for blocked.

The committed baked PNGs are proof images and a no-shader fallback. A runtime
implementation may compose the layers to reduce loaded images, but it must
produce pixel-identical results.

## Semantic matrix

Each cell is applied to one of the eleven geometry masks.

| Passage state | Outbound trunk | Outbound branch | Return trunk | Return branch |
|---|---|---|---|---|
| Open | geometry + outbound chevrons + solid trunk stud + continuous fill | geometry + outbound chevrons + hollow branch stud + continuous fill | geometry + return chevrons + solid trunk stud + continuous fill | geometry + return chevrons + hollow branch stud + continuous fill |
| Restricted | geometry + outbound chevrons + solid trunk stud + 2-on/1-off dash | geometry + outbound chevrons + hollow branch stud + 2-on/1-off dash | geometry + return chevrons + solid trunk stud + 2-on/1-off dash | geometry + return chevrons + hollow branch stud + 2-on/1-off dash |
| Blocked | geometry + outbound chevrons + solid trunk stud + continuous fill/crossbars | geometry + outbound chevrons + hollow branch stud + continuous fill/crossbars | geometry + return chevrons + solid trunk stud + continuous fill/crossbars | geometry + return chevrons + hollow branch stud + continuous fill/crossbars |

## English production descriptions

### Flow-direction layer

Create a native `16 × 16 px` transparent pixel-art overlay for each connected
transport interface. Outbound flow uses arterial coral `#BA3A3F`; return flow
uses blue violet `#404586`. Add integer-pixel neutral chevrons at every
connected interface, pointing away from the tile center for outbound and toward
the center for return, so direction remains legible in grayscale. Preserve the
D-08 pixels 5 through 12 edge interface. Forbidden: text, labels, particles
standing in for direction, gradients, anti-aliasing, blur, glow, anatomical
blood vessels, colors outside the locked palette, and subpixel placement.

### Passage-state layer

Create exactly three passage textures on the unchanged D-08 geometry. Open is
a continuous solid line. Restricted repeats two filled pixels followed by one
transparent gap and shows at least two gaps per tile. Blocked retains the
continuous base and adds one complete dark crossbar to every connected arm.
Keep identical line width and geometry in all three states. Forbidden: using
color, thickness, opacity, or animation speed as the only state signal;
gradients, semi-transparent pixels, resampling, and additional states.

### Trunk/branch layer

Create two same-color, non-text road studs at the tile center. Trunk uses one
solid `2 × 2 px` square; branch uses four separated corner pixels around a
transparent center. Both remain distinct in grayscale and do not alter the
D-08 interfaces. Forbidden: color-only distinction, letters, numbers, lane
labels, width changes, glow, anti-aliasing, or new route topology.

## Open runtime blocker

T-15a's published edge record does not contain `flow_direction`,
`passage_state`, or `route_role`. Every edge has `trunk_route_id`; no branch
relation is exposed. Tee and four-way undirected masks also lack a unique
directed entry/exit assignment.

Consequently, the required one-to-one selection rule cannot be implemented or
proven without inventing runtime fields. The art matrix is complete and
validated, but D-09 is not marked DONE until the three missing selectors and
junction direction rule are added upstream.
