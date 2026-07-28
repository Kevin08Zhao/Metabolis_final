# Metabolis Resource and State Encoding Specification

> This file defines only shapes, textures, and state combinations. Color names reference the final D-02 palette in `PALETTE.md`; this file does not define or replace hex values.

## 1. Six Fixed Resource Shapes

The minimum usable size is `8 × 8` native pixels. The bitmaps below are the only permitted silhouettes for the six resources: `#` is opaque and `.` is transparent. Scaling uses integer nearest-neighbor factors only. Notches, corners, holes, and arms must not be added or removed.

**Nutrient energy: solid diamond**

```text
...##...
..####..
.######.
########
########
.######.
..####..
...##...
```

**Cell material: square with a two-step lower-right notch**

```text
........
.######.
.######.
.######.
.######.
.#####..
.####...
........
```

**Developmental signal: solid upward triangle**

```text
...##...
..####..
..####..
.######.
.######.
########
########
........
```

**Waste: hollow hexagon**

```text
..####..
.##..##.
##....##
##....##
##....##
##....##
.##..##.
..####..
```

**Stability: flat-top, downward-pointing shield**

```text
.######.
########
########
########
.######.
..####..
...##...
...##...
```

**Knowledge badge: four-long-arm star**

```text
...##...
#..##..#
.######.
..####..
########
.######.
#..##..#
...##...
```

The six silhouettes must remain pairwise distinguishable on a transparent background, with a single-color fill, and in grayscale. Checkmarks, exclamation marks, drops, dots, emblems, and any other resource silhouette are forbidden. State may change only an existing shape’s fill texture, border, repetition count, or motion.

## 2. Transport Particles and Network Textures

Nutrient energy, cell material, developmental signal, and waste use their fixed `8 × 8` shapes as transport particles. A moving particle remains screen-facing and does not rotate, tilt, stretch, or use motion blur. Every frame preserves its key feature: vertical diamond symmetry, lower-right square notch, flat-bottom upward triangle, or hexagonal center hole.

Stability and knowledge badges never become transport particles and never appear on network flow lines. Their shapes are limited to status bars, counters, and icons.

Resource particles encode identity only; they do not encode sufficient, insufficient, normal, or overflow states. Those states appear in the corresponding status bar or facility panel. The network itself uses exactly these three passage states:

| Passage state | Fixed texture | Grayscale test |
|---|---|---|
| Open | Continuous solid line | No gap or crossbar in any `1T` length |
| Restricted | Dashed line repeating 2 pixels on / 1 pixel off | At least two visible gaps in any `1T` length |
| Blocked | Continuous base line with a crossbar at least once per `1T` | At least one complete crossbar in any `1T` length |

All three textures use the same line width. Line width, color, and particle speed may not replace the solid, dashed, and crossed distinction.

## 3. Fixed State Encoding

Every state simultaneously uses at least three of color, fill texture, motion, and border. Fill texture, motion, and border are non-color signals. Pulses change only integer-pixel borders or integer scale and never use alpha gradients. Flashing may not exceed three changes per second.

### 3.1 Stability: Normal / Warning / Critical

| Tier | Color | Fill texture | Motion | Border |
|---|---|---|---|---|
| Normal | D-02 mint green | Solid | Static | 1-pixel continuous border |
| Warning | D-02 warm amber | 2-pixel diagonal hatch | One inward-outward pulse every 2 seconds | 2-pixel continuous border |
| Critical | D-02 arterial coral | 1:1 crosshatch | Two inward-outward pulses every 1 second | 3-pixel clipped-corner border |

Every tier uses the same stability shield. No tier may add or substitute another icon.

### 3.2 Spendable Resources: Sufficient / Insufficient

This rule applies to nutrient energy, cell material, and developmental signal. It does not add intermediate states such as low or nearly sufficient.

| State | Color | Fill texture | Motion |
|---|---|---|---|
| Sufficient | The resource’s D-02 main color | Solid | Static |
| Insufficient | The resource’s D-02 dark color | 1-pixel hollow interior | Shrinks inward and restores once per second |

The resource silhouette never changes. The insufficient state retains the diamond symmetry, square notch, or triangle base.

### 3.3 Waste: Normal / Overflow

| State | Color | Fill texture | Repetition and motion |
|---|---|---|---|
| Normal | D-02 waste body color | Hollow, preserving the transparent center hole | One static hexagon |
| Overflow | Existing D-02 warning color | 1:1 crosshatch inside the hexagon while preserving outline and center hole | Three offset copies of the same hexagon, with two outward pulses every second |

Overflow repeats the waste hexagon only. It may not add a new alert shape or a third waste state.

## 4. Delivery Acceptance Matrix

Not applicable means the resource is forbidden from displaying that tier; it is not missing information. Every applicable cell lists all simultaneous visual signals.

| Resource | Sufficient | Insufficient | Stability normal | Stability warning | Stability critical | Waste normal | Waste overflow | Count only |
|---|---|---|---|---|---|---|---|---|
| Nutrient energy | Diamond + main color + solid + static | Diamond + dark color + hollow + one inward shrink per second | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden |
| Cell material | Notched square + main color + solid + static | Notched square + dark color + hollow + one inward shrink per second | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden |
| Developmental signal | Upward triangle + main color + solid + static | Upward triangle + dark color + hollow + one inward shrink per second | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden |
| Waste | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Hollow hexagon + waste body color + one copy + static | Crosshatched hexagon with hole + existing warning color + three offset copies + two outward pulses per second | Not applicable; forbidden |
| Stability | Not applicable; forbidden | Not applicable; forbidden | Shield + mint green + solid + static + 1-pixel continuous border | Shield + warm amber + diagonal hatch + one pulse every 2 seconds + 2-pixel continuous border | Shield + arterial coral + crosshatch + two pulses per second + 3-pixel clipped-corner border | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden |
| Knowledge badge | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Not applicable; forbidden | Four-long-arm star + D-02 oxygen blue + solid + static + adjacent count |

At minimum size, the solid nutrient-energy diamond and the stability shield are the easiest pair to confuse. The fixed distinction is that the diamond is vertically symmetric with its widest point at the vertical center, while the shield has a 6-pixel flat top and a 2-pixel-long central lower point. Stability does not enter the transport network, so a moving particle can never be a shield.

For acceptance, render all six `8 × 8` bitmaps side by side with one color and compare all 15 pairs. Reject any pair that cannot be distinguished by silhouette alone. Convert the set to grayscale and hide text, then confirm that all three stability tiers, sufficient versus insufficient, and normal versus overflowing waste remain distinguishable. Finally, confirm that every matrix cell contains text.
