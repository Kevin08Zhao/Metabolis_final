# D-18 Animation Metadata Contract Manifest

- Status: `PASS`
- PixelLab generation calls: `0`
- Production animations created: `0`
- Authoritative events: `docs/EVENT_API.md` (39 current signal declarations)
- Authoritative sheet layout: `docs/ASSET_SPEC.md` section 4
- Authoritative naming: `docs/CONTEXT.md` naming conventions
- Validation: `docs/assets/D-18_VALIDATION_REPORT.json`

## Outputs

| File | Purpose |
|---|---|
| `docs/ANIM_META_SPEC.md` | Exact seven-field JSON contract, pairing rules, commands, and report format |
| `tools/check_anim.py` | Read-only recursive validator and in-memory negative self-test |
| `docs/examples/anim_meta/heart_pump_active.json` | Complete metadata example with unequal frame durations |
| `docs/assets/D-18_VALIDATION_REPORT.json` | Current repository scan and self-test results |
| `docs/coord/rework/D-18__from_ACCOUNT_D.resolved.md` | Pre-production contract gap and resolution |
| `docs/coord/done/D-18.md` | Completion marker |

The example has no PNG by design. It is outside `anim/`, cannot be mistaken for
a production pair, and satisfies the D-18 documentation requirement without
generating an animation.
