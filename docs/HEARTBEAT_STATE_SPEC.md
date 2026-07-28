# Heartbeat Stability-State Specification

## 1. Reuse decision

D-21 uses the D-20 heart animation as its only image source.

- `stable` and `strained` share the complete D-20 frame sheet. Their motion is
  distinguished only by timing.
- `critical` cannot use the D-20 peak frame because the required amplitude is
  smaller. It reuses the existing relaxed and shallow-contraction poses in the
  order `[0, 1, 1, 0]`. No frame is scaled, redrawn, or generated.
- PixelLab generation calls: `0`.

This keeps every frame anchored to the D-11 48 by 48 operating-heart canvas.

## 2. State timing and static fallbacks

| Stability state | Per-frame durations (ms) | Total loop | Fallback frame | Silent visual reading |
|---|---:|---:|---:|---|
| `stable` | `[420, 120, 100, 360]` | `1000 ms` | `0` | Relaxed operating pump; slow, regular cycle |
| `strained` | `[140, 60, 80, 160]` | `440 ms` | `2` | Maximum contraction; fast, deliberately uneven cycle |
| `critical` | `[680, 200, 220, 700]` | `1800 ms` | `1` | Shallow contraction; slow cycle with reduced amplitude |

The fallback images are pairwise different, so the three states remain
readable when animation and audio are disabled. Timing, peak depth, and the
fallback pose provide non-audio cues.

## 3. Authoritative stability transitions

The runtime uses `src/sim/threshold_watcher.gd`, backed by Table E4 in
`docs/OPERATION_SPEC.md` and the values in `docs/BALANCE.json`.

| Current state | Next state | Condition |
|---|---|---|
| Initial | `critical` | `stability < 30` |
| Initial | `stable` | `stability >= 75` |
| Initial | `strained` | Otherwise |
| `stable` | `critical` | `stability < 30` |
| `stable` | `strained` | `stability < 65` |
| `strained` | `critical` | `stability < 30` |
| `strained` | `stable` | `stability >= max(70, 65 + 5)`, therefore `>= 70` |
| `critical` | `stable` | `stability >= 70` |
| `critical` | `strained` | `stability >= max(40, 30 + 5)`, therefore `>= 40` |

The `65-70` and `30-40` recovery gaps are hysteresis zones. The heartbeat
controller must consume `stability_band_changed`; it must not recompute a
second state machine or switch repeatedly while stability remains in either
gap.

## 4. Frame-safe switching

1. Receive `stability_band_changed(previous_band, current_band, stability)`.
2. Store only the latest requested state while the current cycle finishes.
3. Apply the pending sheet and timing array when playback reaches relaxed
   frame `0`, then restart that frame with its full duration.
4. If animation is disabled, apply the target state's fallback frame
   immediately.

Waiting for the shared relaxed boundary prevents a change from maximum
contraction to a shallower or relaxed image mid-frame. Hysteresis suppresses
boundary chatter, and replacing the pending state prevents queued obsolete
transitions.

## 5. Runtime assets

| State | Sprite sheet | Metadata |
|---|---|---|
| `stable` | `anim/heart_pump_stable.png` | `anim/heart_pump_stable.json` |
| `strained` | `anim/heart_pump_strained.png` | `anim/heart_pump_strained.json` |
| `critical` | `anim/heart_pump_critical.png` | `anim/heart_pump_critical.json` |

All metadata objects follow `docs/ANIM_META_SPEC.md` exactly and use
`stability_band_changed` as their existing EVENT_API trigger.
