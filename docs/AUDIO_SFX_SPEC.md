# Audio SFX Specification

## Scope

The shipping list contains eleven sound designs. The three-state ambient design
uses three cadence files, so the list contains thirteen physical files. This
still remains below the twelve-sound-design limit because the state loops share
one role, synthesis grammar, priority, and mute behavior. Every event file
follows `docs/AUDIO_NAMING.md` exactly:

```text
audio/events/<event_name>.wav
```

All listed sounds use uncompressed PCM WAV. "Synthetic generation" means a
deterministic team-authored waveform or noise envelope created without an
external sample, instrument performance, voice, or recognizable melody.

## Sound List

| File | Event or role | Duration | Concrete sound structure | Priority | Acquisition | Missing-audio visual fallback | Debounce |
|---|---|---:|---|---:|---|---|---:|
| `audio/ambient/heartbeat_bed.wav`; `heartbeat_bed_strained.wav`; `heartbeat_bed_critical.wav` | One stability-linked ambient design | 1,000 / 440 / 1,800 ms loops | Two low-frequency impulses below 180 Hz; attack under 8 ms; second impulse quieter; no tonal tail | 9 | Deterministic synthetic generation, because pitch-preserving cadence must match all three D-21 loops | D-21 heartbeat sheet and stability-band shape remain visible | Not event-driven |
| `audio/events/build_decision_confirmed.wav` | `build_decision_confirmed` | 180 ms | Fast dry low-mid click followed by one 120 ms filtered settling tail | 5 | Synthetic generation, for deterministic transient length | Selected slot remains, confirm control locks, and resource values roll down | Not high frequency |
| `audio/events/transport_pressure_appeared.wav` | `transport_pressure_appeared` | 240 ms | Two dull low-band impacts, 70 ms apart, with a short downward-noise tail | 4 | Synthetic generation, to avoid a literal alarm sound | Edge changes to the congestion texture and the pressure meter marks it | 100 ms |
| `audio/events/waste_buildup_appeared.wav` | `waste_buildup_appeared` | 300 ms | Mid-low granular burst with a 180 ms downward filtered decay | 4 | Synthetic generation, because the cue must not resemble liquid or gore | Waste layer appears and the bottleneck marker changes shape | 100 ms |
| `audio/events/signal_gap_appeared.wav` | `signal_gap_appeared` | 220 ms | Two high-band dry ticks separated by 80 ms; second tick is shorter; no reverb | 4 | Synthetic generation, for a readable broken-link rhythm | Signal line changes to a blinking broken dash | 100 ms |
| `audio/events/system_observation_started.wav` | `system_observation_started` | 320 ms | Three rising low-mid pulses with 60 ms attacks and a 100 ms final decay; no scale or melody | 3 | Synthetic generation, to preserve a non-musical activation cue | Organ state lights and the collaboration path advances segment by segment | Not high frequency |
| `audio/events/stage_advanced.wav` | `stage_advanced` | 420 ms | Two broadband soft impacts, second 3 dB louder, followed by a 160 ms noise decay | 4 | Synthetic generation, to avoid a musical completion jingle | Development timeline advances and the current map input locks | Not high frequency |
| `audio/events/minigame_rated.wav` | `minigame_rated` | 360 ms | Up to three dry 70 ms stamps at 100 ms spacing; higher stars add stamps, not pitch | 5 | Synthetic generation, so one file remains valid for every rating | Star stamps appear one at a time in the result panel | Not high frequency |
| `audio/events/resource_shortage_raised.wav` | `resource_shortage_raised` | 180 ms | One high-mid click with a 40 ms attack and 120 ms band-limited noise decay | 6 | Synthetic generation, for a short cue that survives frequent play | The affected resource readout flashes and retains its low marker | 100 ms |
| `audio/events/birth_state_changed.wav` | `birth_state_changed`; reserved for the circulation-switch beat selected by D-26 | 450 ms | Low filtered flow narrows over 180 ms, pauses for 40 ms, then opens into a wider 230 ms noise band | 2 | Synthetic generation, to align the narrowing point to a specific birth frame | Placental supply closes and the pulmonary route visibly opens | Event fires per beat; D-26 must gate the selected state |
| `audio/events/birth_sequence_completed.wav` | `birth_sequence_completed`; first inhale | 850 ms | 120 ms soft air onset, 430 ms rising filtered-noise intake, 300 ms decay; no voice | 1 | Synthetic generation, to avoid human voice and external licensing | Lung expansion completes, the ending image settles, and the first-breath state remains visible | Not high frequency |

## Coverage Decisions

- Build confirmation is one cue; `organ_construction_started` intentionally
  remains silent to avoid two transients for one irreversible action.
- The three bottleneck appearances remain separate because their non-color
  visual grammars and recovery actions differ.
- Cleared bottleneck events remain silent; their visual layers already recede.
- Star settlement uses one file and varies stamp count in runtime behavior. It
  does not require three numbered variants.
- `birth_state_changed.wav` is reserved for the circulation-switch beat. The
  current generic per-beat routing is insufficient for D-26 and must be
  resolved before that file is produced.

## Priority and Muting

Priority 1 is highest. The two birth cues are never discarded in favor of a
lower-priority cue. The ambient bed is quieter than every one-shot and stops
when audio is muted. Missing audio never changes gameplay, event delivery,
animation timing, or save state.

## Acquisition and License Decision

All eleven planned files use deterministic synthetic generation. This is one
explicit acquisition route, not an interchangeable recommendation. It avoids
external sample ownership and permits exact timing. Generated scripts and WAV
files are team-created project outputs and must be recorded in
`docs/ATTRIBUTIONS.md`.

## Acceptance Answers

The one sound that cannot be cut is
`audio/events/birth_sequence_completed.wav`, because the first inhale is the
final causal confirmation of the birth transition.

If only three sounds can be produced, produce:

1. The three-state `audio/ambient/heartbeat_bed*.wav` design
2. `audio/events/birth_state_changed.wav`
3. `audio/events/birth_sequence_completed.wav`

These preserve the continuous stability signal and both core birth cues.
