# Metabolis Animation Metadata Contract

## 1. Scope and Pairing

Every delivered animation is exactly one single-row PNG sprite sheet and one same-directory, same-stem JSON metadata file:

```text
anim/heart_pump_active.png
anim/heart_pump_active.json
```

The stem follows the animation template from `docs/CONTEXT.md`:
`{subject}_{action}_{state}`. Each component is a non-empty lowercase
ASCII letter/digit token. Spaces, uppercase letters, hyphens, revision suffixes,
and extra underscore-separated components are invalid.

The JSON is runtime/import metadata. It does not contain image data, bones,
event tracks, blend trees, transitions, transforms, physics, audio, or any
other animation system.

## 2. Exact JSON Object

The top level is one JSON object containing exactly these seven fields. Every
field is required and unknown fields fail validation.

| Field | Type | Contract |
|---|---|---|
| `frame_size` | object | Contains exactly `width` and `height`, both positive integer native pixels. |
| `frame_count` | integer | Positive number of frames in the single sprite-sheet row. |
| `frame_durations_ms` | integer array | Exactly `frame_count` positive millisecond values, one per frame from left to right. Values may differ. |
| `loop` | boolean | `true` repeats after the final frame; `false` holds the fallback frame when playback is not active. |
| `trigger_event` | string | Exact signal name already declared in `docs/EVENT_API.md`. |
| `fallback_frame_index` | integer | Zero-based static fallback frame, from `0` through `frame_count - 1`. |
| `palette_checked` | boolean | Must be `true` before delivery, attesting that visible pixels passed the locked palette check. |

The image dimensions are an invariant:

```text
sheet_width  = frame_size.width * frame_count
sheet_height = frame_size.height
```

This enforces the `docs/ASSET_SPEC.md` layout: one row, left-to-right time
order, no frame padding, identical native frame canvases, and stable anchors.
The PNG must have an alpha channel. Individual frames must not be trimmed.

## 3. Complete Example

The standalone example is
`docs/examples/anim_meta/heart_pump_active.json`. It intentionally has unequal
durations so contraction and relaxation do not collapse into a uniform tempo:

```json
{
  "frame_size": {
    "width": 48,
    "height": 48
  },
  "frame_count": 4,
  "frame_durations_ms": [
    120,
    80,
    200,
    400
  ],
  "loop": true,
  "trigger_event": "system_observation_started",
  "fallback_frame_index": 0,
  "palette_checked": true
}
```

The example is documentation only. D-18 creates no production animation and
no example PNG.

## 4. Trigger-Event Authority

`tools/check_anim.py` reads signal declarations directly from
`docs/EVENT_API.md` using the form `signal event_name(...)`. The current
contract exposes 39 event names. The checker does not keep a second copied
allowlist, so additive accepted EVENT_API changes become available without
editing the checker.

An animation may listen to one existing event through `trigger_event`. D-18
does not invent animation-only events and does not add event tracks.

## 5. Batch Validator

Run the repository scan from the repository root:

```text
python3 tools/check_anim.py anim --event-api docs/EVENT_API.md
```

Machine-readable output and the read-only contract self-test:

```text
python3 tools/check_anim.py anim --event-api docs/EVENT_API.md --self-test --format json
```

The checker recursively scans `anim/` and only reads files. It never writes,
renames, repairs, or deletes an asset. It uses the Python standard library; the
contract also permits Pillow, but the current header-level size and alpha
checks do not require it.

The scan validates:

1. JSON syntax, exact field set, field types, ranges, and array length.
2. Same-directory, same-stem PNG/JSON pairing in both directions.
3. `{subject}_{action}_{state}` filename shape.
4. `frame_count` and `frame_size` against PNG width and height.
5. `trigger_event` against current EVENT_API signal declarations.
6. PNG validity and the presence of an explicit alpha channel.
7. `palette_checked` is exactly `true`.

Exit code `0` means PASS. Any contract error or inability to read the
authoritative inputs returns nonzero.

## 6. Report Format

Text output begins with status and counts, then groups every issue by severity:

```text
FAIL: 1 pair(s), 1 JSON, 1 PNG, 39 allowed event(s)
ERROR (2)
  [SHEET_DIMENSION_MISMATCH] anim/heart_pump_active.json: PNG is 144x48; expected 192x48
  [UNKNOWN_TRIGGER_EVENT] anim/heart_pump_active.json: trigger_event must match a signal in docs/EVENT_API.md
WARNING (0)
INFO (0)
```

JSON output uses `status`, file/pair/event counts, and `issues.ERROR`,
`issues.WARNING`, and `issues.INFO`. Every issue includes a stable `code`, the
specific `file`, and a human-readable `message`.

## 7. Acceptance and Explicit Exclusions

The in-memory self-test proves four independent cases without creating
repository animation files:

- A complete example passes.
- Removing a required field reports `MISSING_FIELD`.
- A wrong frame count reports `SHEET_DIMENSION_MISMATCH` (and a duration-count
  mismatch when applicable).
- A nonexistent event reports `UNKNOWN_TRIGGER_EVENT`.

This metadata contract deliberately excludes skeletons, bones, event tracks,
blend trees, state machines, interpolation curves, resampling settings, audio
tracks, and embedded image data. Those additions would exceed D-18 and fail as
unknown fields.
