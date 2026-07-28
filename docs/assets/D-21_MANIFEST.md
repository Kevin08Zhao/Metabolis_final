# D-21 Heartbeat Stability-State Manifest

- Status: `PASS`
- PixelLab generation calls: `0`
- Source sheet: `anim/heart_pump_active.png`
- Generator and validator: `tools/build_d21_heartbeat_states.py`
- Switching contract: `docs/HEARTBEAT_STATE_SPEC.md`
- Validation report: `docs/assets/D-21_VALIDATION_REPORT.json`

## Reuse decision

The three states cannot all use the complete D-20 frame set because `critical`
requires visibly smaller amplitude. No new image generation is necessary:

- `stable` and `strained` are exact pixel copies of the complete D-20 sheet.
- `critical` reuses D-20 response poses `[0, 1, 1, 0]`, excluding the
  maximum-contraction pose and preserving the original 48 by 48 footprint.
- No frame is scaled, redrawn, recolored, or sent back to PixelLab.

## Outputs

| State | Sheet | Metadata | Durations (ms) | Total | Fallback |
|---|---|---|---:|---:|---:|
| `stable` | `anim/heart_pump_stable.png` | `anim/heart_pump_stable.json` | `[420, 120, 100, 360]` | `1000` | `0` |
| `strained` | `anim/heart_pump_strained.png` | `anim/heart_pump_strained.json` | `[140, 60, 80, 160]` | `440` | `2` |
| `critical` | `anim/heart_pump_critical.png` | `anim/heart_pump_critical.json` | `[680, 200, 220, 700]` | `1800` | `1` |

The three fallback poses are pairwise distinct. Every sheet is 192 by 48,
uses four 48 by 48 frames, preserves binary alpha, and contains only locked
palette colors. All metadata use the existing `stability_band_changed` event.

## Review

- Stable is slow and regular: `PASS`.
- Strained is fast and deliberately uneven: `PASS`.
- Critical is slow and lower-amplitude without whole-image scaling: `PASS`.
- Hysteresis-aware transitions match Table E4 and
  `src/sim/threshold_watcher.gd`: `PASS`.
- Sheet changes are queued until relaxed frame 0 to prevent a mid-pulse visual
  jump: `PASS`.
- D-18 batch validation and negative self-test: `PASS`.
