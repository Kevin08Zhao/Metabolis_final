# D-25 Heartbeat Audio Manifest

- Status: `RUNTIME REWORK RESOLVED - READY FOR D-25 REVALIDATION`
- PixelLab generation calls: `0`
- Source type: deterministic team-authored PCM synthesis
- Generator: `tools/build_d25_heartbeat_audio.py`
- Specification: `docs/HEARTBEAT_AUDIO_SPEC.md`
- Runtime: `src/core/audio_router.gd`
- Resolved rework:
  `docs/coord/rework/T-37__from_ACCOUNT_D_d25_heartbeat_timing.resolved.md`

| Output | Band | Format | Duration | Peak | SHA-256 |
|---|---|---|---:|---:|---|
| `audio/ambient/heartbeat_bed.wav` | stable | Mono 48 kHz signed PCM16 | 1,000 ms | 7,600 PCM16 | `61e4237e2c9b9c0ab51b81c5416ace98d59cbc8eca08399950d4d8a3f72f422a` |
| `audio/ambient/heartbeat_bed_strained.wav` | strained | Mono 48 kHz signed PCM16 | 440 ms | 7,600 PCM16 | `236f4de7af62c8e69d5b417bf82c05efed2cc39a3d4fa38f0f7cece8c0b981da` |
| `audio/ambient/heartbeat_bed_critical.wav` | critical | Mono 48 kHz signed PCM16 | 1,800 ms | 7,600 PCM16 | `20eca5830fcf548c550db16317bda14de52f18c5cfbbba74b0c460149a8ba89e` |

The stable file retains the exact previously accepted bytes. The new strained
and critical files use the same pulse frequencies and envelopes without runtime
pitch scaling. The asset-generator tests, repository asset checker, and real
Godot 4.7.1 runtime acceptance pass.

D-25 remains owned by Account D. This manifest records that the T-37 runtime
blocker is resolved and that D-25 can now perform its final owner revalidation.
