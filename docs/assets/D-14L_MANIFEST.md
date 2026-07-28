# D-14L UI Asset Manifest

- Status: `PASS`
- Derivation: `DERIVED_DETERMINISTIC_NINE_SLICE`
- Shared PixelLab source job: `3a44ef17-752e-4d36-95b8-6f096a52fdf7`
- Additional PixelLab calls: `0`
- Validation: `docs/assets/D-14L_VALIDATION_REPORT.json`

| File | Size | SHA-256 |
|---|---:|---|
| `art/ui/ui_frame_shared_nine_slice.png` | `16x16` | `e146de713b4937a5c568beaa3fe2608ad39b857b874ba666cefe21d30a9b8533` |
| `art/ui/ui_main_city_map_frame.png` | `640x320` | `6bb52d7fa803db819ff7e818da3ff2db10e9c11596e39d62be57d2a6a827dc5a` |
| `art/ui/ui_development_timeline_frame.png` | `640x8` | `036158bb21d1fc11a55fc3e9f53509f644d9ecf94201e8e2dad253c9c3be4b68` |
| `art/ui/ui_task_operations_panel_frame.png` | `608x16` | `548e917b921a0d02ec9417b38ff1fe66c3f8754cd0c43eeb6c14ee1c4f1adcda` |
| `art/ui/ui_resource_status_bar_frame.png` | `640x16` | `77b79a8049d58e9139ba49c9963e1819748264b6a6495be4b3fc334cc264a07b` |
| `art/ui/ui_organ_archive_button.png` | `16x16` | `e9c18f992dbf14117169a7f8e41b2e722aa78195e4c8bdaecfd3ffa456e089f8` |
| `art/ui/ui_chapter_recap_button.png` | `16x16` | `f77affdff3cdef8a74c40fd516043240f1bb43862ca26e030c63ddd51d5af6b5` |

The two 16x16 entry buttons use one normal-state PNG each; pressed state is a runtime one-pixel inward translation and does not require duplicate art.
All six UI regions retain the exact rectangles in `docs/UI_LAYOUT.md`.
