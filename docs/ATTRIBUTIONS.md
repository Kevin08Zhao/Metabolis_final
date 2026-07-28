# Metabolis Asset Attributions

This file records the origin of repository assets. It is an audit index, not a
replacement for the job ledgers, fetch plans, landing reports, manifests, or
license pages referenced below.

## External Assets

No third-party visual or audio asset is currently shipped in `art/`, `anim/`,
or `audio/`.

If an external asset is added, record all of the following before it is merged:

| Asset path | Creator | Source URL | License | Changes made | License checked on |
|---|---|---|---|---|---|
| None | - | - | - | - | - |

## AI-Generated Sources

PixelLab source jobs are governed by the PixelLab terms that applied on the
generation date. The exact request and status responses are retained in
`docs/assets/PF00_JOB_LEDGER.json`, task fetch plans, and task landing reports.
`UNREPORTED INDIVIDUALLY` means the service did not return a per-job usage
field; the authoritative P-F00 batch total is 91 generation units.

| Date (UTC) | Task and source | Tool | Job ID | Seed | Actual usage | Disposition |
|---|---|---|---|---:|---:|---|
| 2026-07-28 | D-06 accepted style master | `edit_image` | `ca5ffa91-0a59-4871-96be-5d76aca31592` | 60608 | 20 | Accepted and landed |
| 2026-07-28 | D-10 placenta canonical | `create_image_pixflux` | `e5f72fc6-40cb-46f6-8d08-9e16011b6c66` | 10001 | UNREPORTED INDIVIDUALLY | Accepted and landed |
| 2026-07-28 | D-11 heart canonical | `create_image_pixflux` | `f6688d85-ddf0-4f23-8360-8899ce255648` | 11001 | UNREPORTED INDIVIDUALLY | Accepted and landed |
| 2026-07-28 | D-12 original lungs canonical | `create_image_pixflux` | `372ec89c-213a-4e70-9f11-e8fdda15ca14` | 12001 | UNREPORTED INDIVIDUALLY | Rejected: realistic anatomy |
| 2026-07-28 | D-12 lungs repair 1 | `edit_image` | `0997def4-c79e-4e71-935d-d5431e46a86f` | 12002 | UNREPORTED INDIVIDUALLY | Rejected: still anatomical |
| 2026-07-28 | D-12 lungs repair 2 | `edit_image` | `166c6a8e-7854-4fa1-a84e-a80196fee2e2` | 12003 | UNREPORTED INDIVIDUALLY | Accepted urban facility source |
| 2026-07-28 | D-12 folded lungs source | `edit_image` | `c758eb58-236e-42a4-80a5-b79de4ebde16` | 12010 | UNREPORTED INDIVIDUALLY | Accepted folded source |
| 2026-07-28 | D-13a landmark construction source | `create_image_pixflux` | `6ea2fd7c-2e90-40e7-90e0-407e1f07ca05` | 13101 | UNREPORTED INDIVIDUALLY | Accepted and landed |
| 2026-07-28 | D-14L/D-17L shared nine-slice source | `create_ui_asset` | `3a44ef17-752e-4d36-95b8-6f096a52fdf7` | 141701 | UNREPORTED INDIVIDUALLY | Accepted style source |
| 2026-07-28 | D-15 nutrient-energy reference | `create_image_pixflux` | `6041c45d-0d09-4d25-aa39-e9f14cc0037a` | 15001 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-15 cell-material reference | `create_image_pixflux` | `d8564e3d-63ea-416b-b556-155d541c0adb` | 15002 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-15 developmental-signal reference | `create_image_pixflux` | `9bc51d08-3dea-4fcd-bd2c-6af77bebf5ba` | 15003 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-15 waste reference | `create_image_pixflux` | `e077e060-9ea6-4834-aff1-8ed3130a4551` | 15004 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-15 stability reference | `create_image_pixflux` | `9d05bf3a-7017-438b-a4db-726e1e25da87` | 15005 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-15 knowledge reference | `create_image_pixflux` | `14fc8cef-04b8-4063-986f-350161038466` | 15006 | UNREPORTED INDIVIDUALLY | Style reference |
| 2026-07-28 | D-29 title background source | `create_image_pixflux` | `f9979329-be15-4e32-bbe7-bdbcf88de454` | 29001 | UNREPORTED INDIVIDUALLY | Accepted background source |
| 2026-07-28 | D-20 heartbeat motion source | `animate_image` | `97436fcf-d7c1-44ba-84cd-5a66f44d0a6e` | 20001 | 1 | Accepted four generated frames |

P-F00 usage reconciliation: 65 used before the accelerated batch, 91 used by
the batch, and 156 used afterward. D-20 then used one additional generation.
The current live balance is recorded separately in
`docs/assets/D_FAST_STATUS.json`.

## Team-Created and Deterministically Derived Assets

These assets were produced by repository scripts from locked project geometry,
the 22-color palette, or an attributed source above. Each manifest contains
the exact output paths and hashes.

| Task | Method | Authoritative evidence |
|---|---|---|
| D-07/D-08 | Deterministic tile masks, rotations, seams, and interface pixels | `tools/build_core_tiles.py`, `docs/assets/D-07_MANIFEST.md`, `docs/assets/D-08_MANIFEST.md` |
| D-09 | Deterministic direction, passage-state, and route-role overlays | `tools/build_d09_vessel_variants.py`, `docs/assets/D-09_MANIFEST.md` |
| D-10/D-11 | Deterministic five-state organ derivatives from attributed canonical sources | `tools/build_organ_states.py`, task manifests |
| D-12/D-13a | Deterministic state matrices and construction progress derivatives | `tools/build_d12_d13a_assets.py`, task manifests |
| D-14L/D-17L | Deterministic nine-slice UI assembly | `tools/build_d14l_d17l_ui.py`, task manifests |
| D-15 | Deterministic semantic resource icons and states | `tools/build_d15_resource_icons.py`, `docs/assets/D-15_MANIFEST.md` |
| D-15a/D-16 | Deterministic task-rating and bottleneck icons | `tools/build_d15a_d16_icons.py`, task manifests |
| D-20/D-21 | Deterministic heartbeat sheet assembly and timing/state variants | `tools/build_d20_heartbeat.py`, `tools/build_d21_heartbeat_states.py`, task manifests |
| D-25 partial | Deterministic PCM heartbeat source with no external sample | `tools/build_d25_heartbeat_audio.py`, `docs/HEARTBEAT_AUDIO_SPEC.md` |
| D-29 | Quantized and validated title background derived from the attributed source | `fetch_plans/D-29_fetch_plan.json`, `docs/assets/D-29_MANIFEST.md` |

## License Rules

- **CC0:** the creator waives copyright and related rights to the extent
  legally possible. Modification and redistribution are allowed without an
  attribution requirement, but this project still records creator and source
  for auditability.
- **CC BY:** modification and redistribution are allowed only when appropriate
  credit, a license link, and an indication of changes are provided. The credit
  must not imply endorsement.
- **CC BY-SA:** includes the CC BY conditions and additionally requires
  adaptations to be distributed under the same or a compatible ShareAlike
  license. Do not merge a BY-SA adaptation until its compatibility with the
  intended game distribution has been reviewed.

## License Verification Checklist

- Open the original asset page rather than relying on a search-result summary.
- Record the creator, canonical source URL, exact license version, and check
  date.
- Confirm that commercial use, modification, and redistribution are permitted.
- Save evidence of any required attribution wording and ShareAlike condition.
- Record every crop, recolor, edit, conversion, and derivative output.
- Confirm that the uploader had authority to license the asset and that the
  page does not contain conflicting terms.
- If the license or ownership is unclear, do not use or redistribute the asset.
  Replace it with a verified source or obtain written permission first.
