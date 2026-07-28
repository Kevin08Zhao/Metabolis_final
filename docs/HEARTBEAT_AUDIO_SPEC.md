# Heartbeat Audio Bed Specification

## Sources

The heartbeat bed is one sound design rendered into three deterministic
team-authored PCM loops by `tools/build_d25_heartbeat_audio.py`.

| Stability band | File | Duration | Pulse starts | Peak | SHA-256 |
|---|---|---:|---:|---:|---|
| `stable` | `audio/ambient/heartbeat_bed.wav` | 1,000 ms | 100, 320 ms | 7,600 PCM16 | `61e4237e2c9b9c0ab51b81c5416ace98d59cbc8eca08399950d4d8a3f72f422a` |
| `strained` | `audio/ambient/heartbeat_bed_strained.wav` | 440 ms | 44, 141 ms | 7,600 PCM16 | `236f4de7af62c8e69d5b417bf82c05efed2cc39a3d4fa38f0f7cece8c0b981da` |
| `critical` | `audio/ambient/heartbeat_bed_critical.wav` | 1,800 ms | 180, 576 ms | 7,600 PCM16 | `20eca5830fcf548c550db16317bda14de52f18c5cfbbba74b0c460149a8ba89e` |

Every file is mono, 48 kHz, signed PCM16. Every loop uses the same two
low-frequency damped impulses at 72 Hz and 56 Hz, with the second impulse
quieter. Only their positions and the silent tail change. The first and final
5 ms are silent, so every state can loop without a boundary click.

The waveforms contain no melody, harmony, recognizable instrument, external
sample, or voice.

## Required Stability Mapping

D-21 is authoritative for visual timing.

| Stability band | D-21 frame durations | Audio loop interval | Runtime file | Target bed level | Level relative to a 0 dB one-shot |
|---|---|---:|---|---:|---:|
| `stable` | 420, 120, 100, 360 ms | 1,000 ms | `heartbeat_bed.wav` | -16 dB | 0.158 amplitude |
| `strained` | 140, 60, 80, 160 ms | 440 ms | `heartbeat_bed_strained.wav` | -12 dB | 0.251 amplitude |
| `critical` | 680, 200, 220, 700 ms | 1,800 ms | `heartbeat_bed_critical.wav` | -8 dB | 0.398 amplitude |

The audio interval and the corresponding D-21 animation-loop total are
identical in every row.

## Pitch-Distortion Decision

Changing the 1,000 ms source to 440 ms by playback rate would shift pitch by
about 14.2 semitones. Changing it to 1,800 ms would shift pitch by about
-10.2 semitones. Both changes are plainly audible.

The accepted implementation therefore uses three separately rendered loops
with unchanged 72 Hz and 56 Hz pulse frequencies. Runtime `pitch_scale` is
never used. This preserves the low-frequency character while matching each
D-21 cadence exactly.

## Transition Rules

- Consume `stability_band_changed`; do not recompute a second stability state
  machine. Table E4 and `ThresholdWatcher` remain the only hysteresis authority.
- Retain only the latest pending band until the active loop reaches its next
  relaxed-frame-0 boundary.
- At that boundary, start the target loop from sample zero and crossfade the two
  ambient players for 250 ms.
- Do not hard-cut the outgoing loop. Release its stream after the crossfade.
- Keep the target levels at -16, -12, and -8 dB. Even two simultaneous critical
  streams at the generated peak remain below full-scale PCM and below a 0 dB
  one-shot.
- Muting stops and dereferences both ambient streams and every one-shot without
  stopping gameplay events or animation timing. An event received while muted
  selects the band that starts after unmuting.
- Normal window-close shutdown stops audio, allows a 100 ms audio-thread release
  grace, and then exits. Programmatic quit callers use
  `AudioRouter.prepare_for_shutdown()` before their equivalent grace period.

## Runtime Integration

`src/core/audio_router.gd` derives the three ambient paths by stability-band
index, uses two reusable `AudioStreamPlayer` nodes, and uses a one-shot timer for
the active D-21 loop duration. A band event replaces the pending target; it does
not switch immediately. The timer boundary is the shared relaxed frame 0 where
the incoming stream begins and the 250 ms crossfade starts.

The runtime validates every loaded WAV length to within one PCM frame. A missing
or incorrectly sized target file warns with the `[AUDIO]` prefix and leaves the
current bed playing.

## Validation

```powershell
python -m unittest tests.test_build_d25_heartbeat_audio -v
python tools/build_d25_heartbeat_audio.py --output-dir audio/ambient
python -m unittest tests.test_check_assets -v
python tools/check_assets.py --repo-root . --format text
```

The waveform tests verify deterministic bytes, the exact 1,000/440/1,800 ms
durations, mono PCM16 format, 48 kHz sample rate, safe peak, low DC offset,
silent loop boundaries, and worst-case crossfade headroom. The live Godot
acceptance additionally verifies frame-boundary switching, 250 ms overlap,
latest-pending replacement, Table E4 hysteresis, mute independence, and clean
normal shutdown.
