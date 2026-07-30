# System Completion Notification Asset Manifest

- Status: `PASS`
- PixelLab UI source job: `47a1f75a-54f8-4f56-b605-198f10802f4c`
- Seed: `73194`
- Raw source: `art/candidates/system_completion_notification/ui_system_completion_notification_candidate01_raw.png`
- Derivation: removed only the repeated undecorated center rows, then mapped
  opaque source colors to the nearest color in the locked 22-color palette.
- Resampling: `NONE`
- Build script: `tools/build_system_completion_notification.py`
- Validation: `docs/assets/SYSTEM_COMPLETION_NOTIFICATION_VALIDATION.json`

| File | Size | SHA-256 |
|---|---:|---|
| `art/ui/ui_system_completion_notification.png` | `384x96` | `6cdc320c8bee36f33f4d6d308e62b13496adf4c574c6ed3125a530544866b7be` |

The final frame retains the generated icon well, oxygen-blue information tick,
mint completion rail, pixel outline, and binary transparent exterior. Runtime
labels and the existing resource icon are deliberately not baked into the art.
