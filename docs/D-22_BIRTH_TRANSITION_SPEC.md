# D-22 Birth Transition Animation Spec

## Timeline (45,000 ms total)

| Time (ms) | Stage | Duration | Visual event | Audio cue |
|---|---:|---|---|---|
| 0–10,000 | **1. Umbilical Stop** | 10,000 ms | Placental transport lines fade from arterial coral to neutral; umbilical interface ring contracts and seals; last nutrient-energy particles reach organs and settle | `birth_state_changed` (D-26, gated) |
| 10,000–20,000 | **2. Pulmonary Flow** | 10,000 ms | Lung exchange regions light up in mint green; pulmonary circulation edges switch from blue violet to arterial coral; first oxygen-blue pulse travels from lungs to heart | `birth_state_changed` (circulation switch beat) |
| 20,000–30,000 | **3. Fetal Shunt Closure** | 10,000 ms | Ductus arteriosus bypass fades; foramen ovale seal closes; pulmonary trunk and aortic arch route independently; waste counter drops as fetal-waste route dissolves | `birth_state_changed` |
| 30,000–35,000 | **4. Systems Online** | 5,000 ms | All organs show stable mint-green operating state; heart beats independently; lungs cycle; neural network pulses steady; stability meter rises to normal range (67+) | `stage_advanced` |
| 35,000–45,000 | **5. Ending Screen** | 10,000 ms | Full-frame birth-complete overlay; first-inhale visual (lung expansion); "City of Life" title; stability settles; credits-adjacent summary; fade to title scene | `birth_sequence_completed` (priority 1) |

## Stage 1: Umbilical Stop (0–10,000 ms)

### PixelLab visual description

**Umbilical seal overlay**: Create one 640×320 px top-down PixelLab overlay for the
birth transition umbilical-stop stage. The placental disc (center-left, approximately
x=180–300, y=140–260) shows its radial transport branches fading from arterial coral
#BA3A3F to neutral dark #817582. The umbilical interface ring at the disc edge
contracts inward over the 10-second stage — represent this as a concentric ring
sequence at 2,500 ms intervals (4 frames). Nutrient-energy particles (2×2 px warm
amber #E2953A squares) travel their final paths along transport edges and settle at
organ sites. The heart pump remains in operating coral but without new inflow.
Forbidden: blood, dripping, torn tissue, text, labels, gradients, anti-aliasing,
colors outside the 22-color locked palette.

**Frame sequence**: 4 keyframes at t=0, 3333, 6666, 10000 ms show progressive
ring contraction and coral-to-neutral color transition along placental edges.

## Stage 2: Pulmonary Flow (10,000–20,000 ms)

### PixelLab visual description

**Pulmonary activation overlay**: Create one 640×320 px top-down PixelLab overlay
showing the lung exchange regions (paired, approximately x=120–240 and x=400–520,
y=200–280) transitioning from dormant tissue pink #BE6E87 to active mint green
#B1FFD1. Pulmonary circulation edges (from heart to lungs) switch color from blue
violet #404586 to arterial coral #BA3A3F. One oxygen-blue #7AD1FD pulse wave
travels from the lungs back to the heart along the pulmonary vein route over
10 seconds — represent this as a traveling highlight along the vessel edge.

**Frame sequence**: 4 keyframes at t=10000, 13333, 16666, 20000 show progressive
lung activation and pulmonary-vein pulse travel.

## Stage 3: Fetal Shunt Closure (20,000–30,000 ms)

### PixelLab visual description

**Shunt closure overlay**: Create one 640×320 px top-down PixelLab overlay for
fetal-to-neonatal circulatory transition. Two shunt pathways fade to transparent
over 10 seconds: the ductus arteriosus bypass (pulmonary artery to aorta) and the
foramen ovale (right-to-left atrial passage). Represent each as a fading dotted
line in blue violet #404586 with decreasing opacity (from full to zero across
4 keyframes). The waste route dissolves — waste counter display area shows
declining neutral-dark #514854 particles. The pulmonary trunk and aortic arch
emerge as independent arterial coral routes.

**Frame sequence**: 4 keyframes at t=20000, 23333, 26666, 30000 show progressive
shunt dissolution.

## Stage 4: Systems Online (30,000–35,000 ms)

### PixelLab visual description

**Systems-online confirmation**: Create one 640×320 px top-down PixelLab overlay.
All transport edges display stable mint green #B1FFD1 operating state. The heart
pump shows a steady rhythmic contraction highlight (two coral pulses at 500 ms
interval, repeated twice during the 5-second stage). Lungs display paired cycling
highlights. Neural network shows a coordinated pulse along the cranial-to-trunk
axis. The stability meter (HUD element, runtime-rendered) rises visually to the
normal range — represent this as a progress highlight along the stability bar
from amber #E2953A to mint green #B1FFD1.

**Frame sequence**: 2 keyframes at t=30000 and 35000.

## Stage 5: Ending Screen (35,000–45,000 ms)

### PixelLab visual description

**Birth-complete frame**: Create one 640×360 px full-frame PixelLab ending image.
The 640×320 map area shows all organs in stable mint green #B1FFD1 operating state
with arterial coral #BA3A3F circulation routes. The top 40-pixel UI strip carries
the runtime "Chapter Complete" label space. Over the map, a subtle first-inhale
visual: lungs expand once (paired air sacs enlarge by 2 pixels outward, then
return, over 1,500 ms — 3 frame sequence). The "City of Life" title area reserves
a 320×40 px centered band near the top of the map for runtime text rendering. No
baked title text. A single mint-green pulse radiates once from the heart to all
organs at t=42,000 ms (one frame highlight on all operating edges).

**Frame sequence**: 3 frames for first-inhale lung expansion at t=36000, 37500, 39000
plus one full-map pulse highlight frame at t=42000. Static ending background
holds for remaining duration.

## Delivery summary

| Stage | PixelLab frames | Frame dimensions | Total PNGs |
|---|---:|---|---:|
| Umbilical stop | 4 | 640×320 | 4 |
| Pulmonary flow | 4 | 640×320 | 4 |
| Fetal shunt closure | 4 | 640×320 | 4 |
| Systems online | 2 | 640×320 | 2 |
| Ending screen | 4 | 640×360 | 4 |
| **Total** | | | **18** |

All frames use the 22-color locked palette, binary alpha, 1-pixel #140F1D
exterior outlines, #514854 internal structure lines, integer-pixel placement.

## Verification

1. Play the 45s sequence with all 18 PixelLab frames swapped at their timeline marks.
2. At 10s, 20s, 30s, and 35s, verify that only the active stage's visual elements differ.
3. Pause at any frame and remove color — organ identity and stage must remain clear.
4. Verify that no frame contains baked text, baked values, or out-of-palette colors.
5. Verify that the ending screen's first-inhale lung expansion is visible in grayscale.
6. Confirm that the `birth_sequence_completed` audio cue fires at t=35,000 ms and aligns
   with the ending screen appearance.
