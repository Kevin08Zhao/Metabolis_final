task_id: D-23
reported_by: ACCOUNT_C
status: RESOLVED
blocking_task: T-38
base_main_commit: 27a4f5a
failure_files:
  - docs/FALLBACK_SPEC.md
  - docs/coord/done/D-23.md
reproduction:
  - Read the D-23 task section in docs/prompts/Metabolis_Prompts_Full_v2.md.
  - Confirm that its declared output is docs/FALLBACK_SPEC.md.
  - Search the repository for docs/FALLBACK_SPEC.md.
  - Compare the required all-animation fallback table and switch behavior specification with the two birth-only PNGs listed in the D-23 done marker.
expected: |
  docs/FALLBACK_SPEC.md exists and covers every completed animation, including
  build completion and system collaboration. Each row identifies a
  representative fallback frame or static treatment. The document also defines
  particle, UI highlight, fixed-duration, replacement-feedback, and one-minute
  validation behavior for animation-disabled mode.
actual: |
  docs/FALLBACK_SPEC.md does not exist in any repository commit. The D-23 done
  marker instead lists only art/birth/birth_fallback_start.png and
  art/birth/birth_fallback_end.png. Those files cannot determine the fallback
  frame or switch behavior for the other completed animations.
impact: |
  T-38 cannot implement its animation-disabled switch without inventing
  upstream behavior. Its prompt requires the full D-23 specification and
  explicitly forbids stopping every animation on the first frame.
required_resolution:
  - Produce docs/FALLBACK_SPEC.md from the D-23 prompt and current landed animation metadata.
  - Cover build completion, system collaboration, blood flow, heartbeat states, birth, particles, UI highlights, and timing behavior.
  - Run the D-23 acceptance and update docs/coord/done/D-23.md with the real output and checks.
resolution: |
  Added the missing authoritative specification and corrected the original
  birth-only completion record without erasing its historical claim. The
  specification covers all D-19 through D-22 effects, including honest static
  treatments for the two D-19a groups that have no dedicated landed frames.
resolved_at: 2026-07-29
