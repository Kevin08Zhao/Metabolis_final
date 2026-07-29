# No-Art Mode Validation

## Runtime controls

The debug build exposes four shortcuts:

| Shortcut | Action |
|---|---|
| F8 | Toggle all presentation animation |
| F9 | Toggle all audio |
| F10 | Toggle formal art and same-size placeholders |
| F12 | Show or hide the presentation-flags panel |

The panel starts hidden. It is not created in a release build. The three flags
default to off, can be changed independently, and take effect in the running
scene. Re-enabling a flag restores the prior presentation state without
restarting the scene.

When animation is disabled, the build-completion step holds its static state for
eight seconds and the system-collaboration step holds its static state for
twelve seconds. Their Continue control and the Space shortcut remain gated until
the window ends. Birth gameplay timers remain authoritative for the full
forty-five-second sequence.

## Operator worksheet

Run this table with all three flags active. Fill the final column during the
manual pass.

| Validation item | Operation | Pass standard | Actual result |
|---|---|---|---|
| Build decision | Select one candidate, select a legal slot, and confirm twice. | The selected option and slot remain readable, resources decrease, the footprint becomes occupied, and the static completed result holds for eight seconds. | |
| Operation decision | Select one available operating priority and confirm twice. | The selected priority settles, numeric resources update, and the next step becomes available without animated or audio feedback. | |
| Bottleneck handling | Reach a warning or bottleneck, read its named metric and value, then choose an offered legal response. | The reason remains textual, its route or metric remains identifiable, and the response changes the recorded state without requiring motion or sound. | |
| System collaboration | Activate the newly completed organ and remain on the observation step. | Participant, route, transferred resource, metric change, and observation status remain readable; Continue stays gated for twelve seconds. | |
| Stage carryover | Complete a stage and advance. | The next stage loads with its carryover record and the development status text changes. | |
| Birth readiness and recovery | Complete stage four and inspect the readiness report. If it fails, run recovery until it passes. | Failure remains recoverable; success enters the birth sequence without a restart. | |
| Birth and first breath | Observe all five birth state boundaries. | The specified fallback still changes at every boundary, forty-five seconds elapse, and the first-breath ending opens. | |
| Ending | Inspect the final screen. | All five unscored summary groups remain readable with placeholders and silence. | |
| Switch independence | Toggle F8, F9, and F10 separately, then together, while a scene is running. | Only the selected state changes; timers continue; art bounds remain stable; restoring a flag restores its prior state. | |
| Debug panel | Press F12 twice. | The panel accurately reports all three states, then hides; release builds do not create it. | |

The retired Connect, Test Supply, and Choose Maintenance mechanisms are
intentionally absent from this worksheet.

## Executed validation record

Environment: Godot `4.7.1.stable.official.a13da4feb`, macOS, compatibility
renderer. Date: 2026-07-29.

| Check | Observed result | Status |
|---|---|---|
| Verifier self-test | The deliberate false equality was detected as the expected failure. The comment stripper removed real comments while preserving a hash inside a quoted string. | PASS |
| Defaults and panel | All flags started false; the panel started hidden; F12 displayed it in the debug build. | PASS |
| Independent animation switch | A running strained-heart fixture stopped on fallback frame 2, particle emission stopped, audio remained unmuted, and a gameplay timer completed. | PASS |
| Fixed static windows | A real Continue button stayed disabled for the complete eight-second build window and complete twelve-second collaboration window, then restored its prior state. | PASS |
| Independent audio switch | The existing audio router muted immediately. Re-enabling audio restored its pre-test mute state. No timer or gameplay signal was stopped. | PASS |
| Formal-art replacement | Existing texture controls and sprites changed to high-contrast two-color placeholders with identical dimensions. Nodes created after the switch were also replaced. Large placeholders received text identifiers. | PASS |
| Instant restoration | Restoring formal art returned every original texture and removed debug identifiers. Restoring animation and audio did not change the other flags. | PASS |
| Birth fallback | The fetal-shunt fixture displayed `stage3_shunt_closure_29999`; the full run began on `stage1_umbilical_stop_09999` and followed the real state machine. | PASS |
| Full no-art playthrough | With all flags active, the real UI completed seven build decisions, four operation decisions, four system observations, three carryover applications, stage-four shortage feedback, the birth gate, all five timed birth states, first breath, and the ending route. | PASS |
| Real forty-five-second lifecycle | The headless run waited for the configured ten, ten, ten, five, and ten second windows. The ending opened only after first breath completed. | PASS |
| Visual readability | A rendered build-decision capture showed placeholder terrain and icons while the stage title, candidate names, costs, resource readings, instructions, and controls remained text-readable. | PASS |
| Shutdown and project settings | Focused and full runs exited successfully without leak warnings. Godot import retained high-DPI, aspect, integer-scale, and rendering settings. | PASS |

The automated playthrough emits button signals directly, which can bypass a
disabled visual control. The separate real-time fixed-window test therefore
uses an actual disabled Continue button and waits the full eight and twelve
seconds; the lifecycle pass is evidence for state-machine continuity, not the
window-duration measurement.

