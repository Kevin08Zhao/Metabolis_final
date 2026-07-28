# P-F00 AI Master Visual Review

Observed main at queue start: `7639ab751323c957cad65dd9e8f7a123f69f0875`

The D-06 style gate is the only global human style gate. These reviews apply the repository's automated visual contract and do not create a new per-image approval gate.

| Task/item | Job | Disposition | Review |
|---|---|---|---|
| D-10 placenta canonical | `e5f72fc6-40cb-46f6-8d08-9e16011b6c66` | ACCEPT CANONICAL | Reads as a civic harbor with an open exchange structure, radial supports, and an umbilical-like transport interface; no gore, text, or realistic placental anatomy. |
| D-11 heart canonical | `f6688d85-ddf0-4f23-8360-8899ce255648` | ACCEPT CANONICAL | Reads as a central municipal pump building with paired front chamber structures, a central mechanical body, and service ports; no anatomical heart or ECG mark. |
| D-12 lungs original | `372ec89c-213a-4e70-9f11-e8fdda15ca14` | REJECT / REPAIR | The lobe silhouette reads as realistic anatomical lungs despite the pipe treatment. |
| D-12 repair 1 | `0997def4-c79e-4e71-935d-d5431e46a86f` | REJECT / FINAL REPAIR | Added equipment detail, but the rounded paired lobe silhouette still reads anatomically. |
| D-12 repair 2 | `166c6a8e-7854-4fa1-a84e-a80196fee2e2` | ACCEPT CANONICAL | Two rectangular air-scrubber towers, squared bases, rigid manifolds, and one central intake read as urban exchange infrastructure while retaining the paired topology. |
| D-12 folded state | `c758eb58-236e-42a4-80a5-b79de4ebde16` | ACCEPT AI_EDIT SOURCE | The same two-tower topology is visibly narrower and closed for the inactive state; the final derived set must verify fixed branch connectivity and grayscale separation. |
| D-13a landmark construction master | `6ea2fd7c-2e90-40e7-90e0-407e1f07ca05` | ACCEPT STYLE SOURCE | Closed empty boundary, diagonal unfinished hatch, four corner pylons, and an empty center are readable. Final 64x64 and 80x80 contracts remain deterministic. |
| D-14L/D-17L shared UI source | `3a44ef17-752e-4d36-95b8-6f096a52fdf7` | ACCEPT SOURCE / FINAL CONTRACT BLOCKED | A text-free modular frame with neutral backing and information rail is usable as a style source. Main does not define the new L-task exact target list, source border, or nine-slice cuts, so this source alone cannot justify DONE. |
| D-15 six resource references | seeds `15001` through `15006` | STYLE REFERENCE ONLY | PixelLab's real minimum is 32x32, while final icons are locked 16x16 bitmaps. Final silhouettes and all 12 state PNGs must be deterministic; generated references never override the notch, hole, arm, or shield geometry in `docs/ENCODING_SPEC.md`. |
| D-29 title background | `f9979329-be15-4e32-bbe7-bdbcf88de454` | ACCEPT BACKGROUND MASTER | Text-free quiet harbor/city silhouette leaves readable runtime-title space and contains no people, UI, or medical imagery. Runtime title, subtitle, disclaimer, buttons, and pulse remain separate. |

## Repair Limit

D-12 used two targeted repairs for the same anatomical-read failure. Repair 2 passed, so D-12 is not blocked by the repair-limit stop rule. No other item used a targeted repair.
