# Birth Transition Audio Specification

## Files

Both cues are deterministic, team-authored, mono 48 kHz signed PCM16 WAV files.
They contain no external sample, human voice, melody, or recognizable
instrument.

| File | Duration | Attack | Sustain | Decay |
|---|---:|---|---|---|
| `audio/events/birth_state_changed.wav` | 450 ms | A low filtered flow narrows for 180 ms | 40 ms of silence marks the route hand-off | A wider low-mid noise band opens and settles for 230 ms |
| `audio/events/birth_sequence_completed.wav` | 850 ms | Soft air noise rises for 120 ms | A broader intake rises for 430 ms | Filtered air and a quiet low tone decay for 300 ms |

## Timeline Alignment

`docs/BIRTH_STATES.md` is authoritative. The circulation cue is not played for
every generic `birth_state_changed` event.

| Time | Animation frame | Audio action |
|---:|---|---|
| 10,000 ms | Final umbilical-stop frame gives way to the first pulmonary-flow frame | Start `birth_state_changed.wav`; its 40 ms center pause marks the closed placental route before the pulmonary band opens |
| 35,000 ms | The ending picture appears and the first-inhale lung expansion begins | Start `birth_sequence_completed.wav`; the sound begins after the visual expansion has started on the same rendered frame |
| 35,850 ms | Ending picture remains visible | First-inhale cue ends |

The heartbeat bed continues through the first three stages. At 35,000 ms it
fades down by 6 dB over 100 ms, remains under the first-inhale cue, and returns
to the active stability-band level after the cue ends. Muting audio does not
change this timeline.

`AudioRouter` gates `birth_state_changed.wav` to entry into
`pulmonary_flow` (`current_state == 3`). `birth_sequence_completed.wav` is
routed from its dedicated completion event.

## Missing-Audio Acceptance

With both WAV files removed, the player can still identify that birth occurred:
the umbilical route seals, pulmonary flow opens, fetal bypass routes close,
systems illuminate, and the ending frame holds. Missing audio may produce one
warning per path but must not delay or cancel any visual transition.
