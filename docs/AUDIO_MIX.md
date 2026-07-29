# Audio Mix Rules

The mix uses the D-25 heartbeat as the reference bed and the ten D-26/D-27
one-shots as short foreground cues. Values below are playback gain settings,
not post-processing. No compressor, limiter, reverb, equalizer, or queued
playback is used.

## Voice Table

Priority `1` is highest. `Ignore` means that a second instance is discarded
while the same cue is already playing; `Restart` means the active instance is
stopped and started again from sample zero.

| File | Gain | Priority | Rapid repeat |
|---|---:|---:|---|
| `birth_sequence_completed.wav` | -13 dB | 1 | Ignore |
| `birth_state_changed.wav` | -15 dB | 2 | Ignore |
| `resource_shortage_raised.wav` | -16 dB | 3 | Ignore for 100 ms |
| `build_decision_confirmed.wav` | -17 dB | 4 | Restart |
| `minigame_rated.wav` | -17 dB | 4 | Restart |
| `transport_pressure_appeared.wav` | -18 dB | 5 | Ignore for 100 ms |
| `waste_buildup_appeared.wav` | -18 dB | 5 | Ignore for 100 ms |
| `signal_gap_appeared.wav` | -18 dB | 5 | Ignore for 100 ms |
| `stage_advanced.wav` | -19 dB | 6 | Restart |
| `system_observation_started.wav` | -19 dB | 6 | Restart |

The heartbeat players retain the D-25 levels: stable -16 dB, strained -12 dB,
and critical -8 dB. Their authored PCM peak is much lower than the normalized
one-shot peak, so every one-shot remains perceptually in front of the bed even
when its playback gain number is lower.

## Voice Limit and Headroom

`assist.audio.max_concurrent_one_shots` is six. When all players are occupied,
an incoming cue replaces only a currently playing cue with a numerically lower
importance (a larger priority number). Otherwise the incoming cue is dropped;
it is never queued.

The loudest six-way one-shot sum uses the -16 dB row as the conservative bound.
With the authored one-shot peak at or below 28,000 PCM16, six coincident voices
remain at or below 0.811 linear amplitude. The worst D-25 crossfade adds less
than 0.185 linear amplitude, keeping the stated worst-case sum below 0.996.

The likely gameplay worst case is a resource-shortage cue plus one bottleneck
appearance plus a stage-advance cue. The player hears the shortage click first,
the bottleneck texture cue beneath it, and the softer transition impact; the
heartbeat remains audible.

## Listening Acceptance

Listen once on headphones and once on laptop speakers at the same system
volume. Confirm the heartbeat remains detectable under the three-cue worst
case, both birth cues remain clear, rapid high-frequency events do not chatter,
and no cue is delayed after its visual event.

## Runtime Implementation

`src/core/audio_router.gd` is the executable form of this table. It applies the
listed gain before playback, tracks the event and priority occupying every
one-shot player, replaces only a lower-importance voice when the six-player
pool is full, and applies Ignore/Restart behavior per cue. The minigame rating
stream is trimmed after one, two, or three authored stamps according to the
event's star argument. At the first-inhale event the active heartbeat player
ducks by 6 dB, remains beneath the 850 ms cue, and returns over 100 ms.
