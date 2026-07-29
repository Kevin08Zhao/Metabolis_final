# Static Fallback Specification

## Purpose and scope

This document defines the authoritative visual state shown when motion is
disabled. It covers every completed effect from D-19 through D-22, including
the two D-19a groups that do not have dedicated sprite sheets. Static feedback
must preserve the same game state, timing, controls, and text as the animated
presentation.

The D-19a completion record incorrectly describes that task as a variant of the
D-19 flow particles. No dedicated build-completion or system-collaboration
frames landed. Their rows below therefore use the accepted five-state organ
art, transport-route art, resource silhouettes, and labels already present in
the game. These are static treatments, not claims that missing frames exist.

## Fallback index

| Effect | Normal presentation | Static fallback frame or treatment | Why this state is representative |
|---|---|---|---|
| Nutrient-energy flow | Amber diamonds travel along an edge | Remove moving particles. Keep the edge, its directional arrow, its passage-state overlay, its numeric rate, and one amber diamond beside the rate label. | The arrow preserves direction, the overlay preserves capacity state, and the diamond preserves resource identity without implying motion. |
| Cell-material flow | Pink notched squares travel along an edge | Remove moving particles. Keep the edge, its directional arrow, its passage-state overlay, its numeric rate, and one pink notched square beside the rate label. | The notched silhouette distinguishes material in color-blind and grayscale views. |
| Developmental-signal flow | Violet upward triangles travel along an edge | Remove moving particles. Keep the edge, its directional arrow, its passage-state overlay, its numeric rate, and one upward triangle beside the rate label. | The triangle and numeric rate carry the signal meaning without a pulse. |
| Waste return flow | Dark hollow hexagons travel toward the exchange route | Remove moving particles. Keep the return arrow, passage-state overlay, numeric rate, and one hollow hexagon beside the rate label. | The reverse arrow preserves return direction and the hollow hexagon preserves waste identity. |
| Open passage | Four particles per edge move at full speed | Continuous edge plus directional arrow; no particles. | A continuous route is the strongest still indication of an open passage. |
| Restricted passage | Two particles per edge move slowly with gaps | Dashed restricted overlay plus directional arrow; no particles. | The dashed route remains distinct from both open and blocked states. |
| Blocked passage | Emission stops and a crossbar appears | Keep the blocked crossbar and zero-flow reading; no held or moving particles. | The crossbar and zero value state the bottleneck directly and do not resemble paused flow. |
| Active heart pump | Four-frame active loop | Frame 0 of `heart_pump_active`. | The relaxed operating pose has the full normal silhouette and reads as active when paired with the operating-state label. |
| Stable heart pump | Four-frame one-second loop | Frame 0 of `heart_pump_stable`. | This is the accepted relaxed stable pose and matches the normal operating silhouette. |
| Strained heart pump | Four-frame fast loop | Frame 2 of `heart_pump_strained`. | The peak-contraction pose makes strain visible in a still image and is deliberately not the first frame. |
| Critical heart pump | Four-frame reduced-amplitude slow loop | Frame 1 of `heart_pump_critical`. | The shallow-contraction pose distinguishes critical weakness from both stable relaxation and strained peak contraction. |
| Organ build confirmation | Blueprint construction followed by completion emphasis | Keep the chosen slot locked, keep the completed five-state organ image or the completed footprint, and show the completion label and selected option summary. Remove all pulse, sweep, brightness cycling, and moving particles. | The completed state, locked slot, and irreversible option summary communicate the result without relying on motion or color. |
| Build-completion tier distinction | Baseline, extended, or reinforced completion behavior | Keep the completed organ or footprint together with the selected tier label. Preserve route length, footprint shape, interface-ring shape, and completed substructures that already distinguish the selected option. Do not use color as the only distinction. | Static geometry and text preserve the choice even though the intended build-order animation has no dedicated landed frames. |
| System collaboration | Participating organs light and a resource path advances segment by segment | Keep all participant organs in their operating state. Add a steady outline to each participant, keep the complete collaboration path visible with directional arrows, place the relevant resource silhouette at its path endpoint, and keep the observation label and metric change visible. Remove path movement and pulsing. | The simultaneous organ outlines, complete path, endpoint shape, and text show who collaborates, through which route, and with what result. |
| Umbilical-flow stop | Birth frames from 0.000 through 9.999 seconds | `stage1_umbilical_stop_09999_2x.png`. | The last frame shows that placental flow has stopped rather than merely announcing that the transition is beginning. |
| Pulmonary-flow start | Birth frames from 10.000 through 19.999 seconds | `stage2_pulmonary_flow_19999_2x.png`. | The last frame shows established pulmonary flow and makes the new route readable in a still. |
| Fetal-shunt closure | Birth frames from 20.000 through 29.999 seconds | `stage3_shunt_closure_29999_2x.png`. | The last frame most clearly communicates closure of the fetal bypass paths. |
| Systems online | Birth frames from 30.000 through 34.999 seconds | `stage4_systems_online_34999_2x.png`. | The final systems-online frame shows the completed coordinated state before the ending card. |
| Ending and first breath | Birth frames from 35.000 through 45.000 seconds | `stage5_ending_42000_2x.png`, also supplied as `birth_fallback_end.png`. | The final frame is the only still that unambiguously states that birth and first breath are complete. |

The birth sequence may use `birth_fallback_start.png` before the first state has
settled. Once a state begins, its representative frame in the table replaces
that start image immediately.

## Switch behavior

### Motion and particles

- Disabling motion takes effect immediately for every visible and subsequently
  created effect. Enabling it again resumes the current state; it does not
  replay completed state changes.
- Sprite loops stop on the exact indexed frame in the table. A state change
  while motion is disabled replaces the still with the new state's fallback.
- Flow, celebration, trail, glow, and collaboration particles are removed.
  Static arrows, passage overlays, resource silhouettes, outlines, and text
  remain.
- Oscillating brightness, pulse, shake, sweep, travel, fade, and path-advance
  motion stop. A steady semantic highlight remains wherever the highlight
  indicates selection, warning, participation, or completion.
- Failure and bottleneck feedback keeps its specific reason text, affected
  metric, numeric value, and blocked or restricted route mark. It must never
  degrade to a generic paused appearance.

### Fixed presentation windows

- Build completion still occupies its full fixed eight-second presentation
  window. The completed organ, locked slot, tier label, and option summary stay
  visible for that window; game time and scheduled state changes continue.
- System collaboration still occupies its full fixed twelve-second observation
  window. The steady participant outlines, complete path, resource endpoint,
  observation label, and metric change stay visible for that window; completion
  occurs at the normal time.
- The five birth windows retain their normal boundaries and the full sequence
  retains its forty-five-second budget. Each boundary swaps to the next
  representative still. First breath, ending validation, and routing occur only
  after the normal state machine completes.
- Disabling audio is independent of disabling motion. Silence never pauses a
  timer, delays a transition, or changes a result.

### Formal-art removal

When formal art is disabled, each formal texture is replaced by a high-contrast
placeholder block that preserves the original node bounds. The block contains a
short text identifier when space permits. Resource identity remains available
through its shape and label; organ identity remains available through its name,
state label, footprint, and selected option summary. Motion fallback selection
still applies to any remaining structural presentation.

## Core-interaction replacement checklist

| Core interaction | Meaning formerly carried by motion | Required static replacement when motion is disabled | Pass condition |
|---|---|---|---|
| Build decision and completion | Construction order, completion flash, and tier-specific sequence | Locked selected slot, completed organ or footprint, selected option and tier text, visible resource deduction, and the full eight-second completion window | The chosen location, completed result, selected alternative, and resource cost can all be identified without watching motion. |
| Operation decision and bottleneck handling | Moving flow, rate change, warning pulse, and blocked particles | Directional arrows, numeric rates, resource silhouettes, restricted dashes or blocked crossbar, specific reason text, and affected metric | The player can submit an operation decision, identify one bottleneck, choose a legal response, and see the corrected state. |
| System collaboration and stage advance | Participant glow and path advancing between organs | Steady participant outlines, complete arrowed path, endpoint resource silhouette, observation label, metric change, and the full twelve-second window | The participating organs, route, transferred resource, observed change, and completed observation are readable before stage advance. |
| Birth transition | Five animated physiological changes and final fade | The five state-specific stills in order, unchanged state durations, current-state text, recovery feedback on a failed check, and the final first-breath ending still | The player can distinguish placental stop, pulmonary start, shunt closure, systems online, and completed first breath. |

## One-minute verification

Run each row with motion disabled; audio and formal art may be toggled
independently to prove the switches do not depend on one another.

| Time limit | Check | One-minute procedure | Pass evidence |
|---|---|---|---|
| 60 seconds | Build feedback | Confirm one available build option and slot, then inspect the completion presentation. | The slot stays locked, resources decrease, the completed state and option or tier label remain readable, and progression waits for the fixed completion window. |
| 60 seconds | Operation and bottleneck feedback | Submit the available operation decision, provoke or inspect one restricted or blocked route, and apply its offered response. | Arrows, numeric rate, resource shape, specific reason, and dash or crossbar identify the problem and its resolution without moving particles. |
| 60 seconds | Collaboration feedback | Activate the completed organ and inspect the observation state. | Every participant has a steady outline; the full arrowed path, endpoint resource, metric change, and observation label remain visible for the fixed observation window. |
| 60 seconds | Birth feedback | Enter the birth sequence in accelerated validation and inspect each state boundary. | The five representative stills appear in order, the ending still states first-breath completion, and no state completes early because motion is disabled. |
| 60 seconds | Independence and no-art readability | Toggle motion, audio, and formal-art removal separately and then together while a scene is running. | Each change is immediate, the other two states do not change, placeholder bounds remain stable, labels and controls remain usable, and gameplay timers continue. |

