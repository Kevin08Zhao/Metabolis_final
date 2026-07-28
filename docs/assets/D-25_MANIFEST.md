# D-25 Heartbeat Audio Manifest

- Status: `PARTIAL - BLOCKED BY T-37 RUNTIME TIMING`
- PixelLab generation calls: `0`
- Source type: deterministic team-authored PCM synthesis
- Generator: `tools/build_d25_heartbeat_audio.py`
- Specification: `docs/HEARTBEAT_AUDIO_SPEC.md`
- Runtime rework:
  `docs/coord/rework/T-37__from_ACCOUNT_D_d25_heartbeat_timing.open.md`

| Output | Format | Duration | Peak | SHA-256 |
|---|---|---:|---:|---|
| `audio/ambient/heartbeat_bed.wav` | Mono 48 kHz signed PCM16 | 1000 ms | 7600 PCM16 (-12.7 dBFS) | `61e4237e2c9b9c0ab51b81c5416ace98d59cbc8eca08399950d4d8a3f72f422a` |

The file is the valid stable-band fallback. D-25 remains incomplete because the
current audio router cannot produce the required 440 ms strained cadence or
1800 ms critical cadence without audible pitch distortion.
