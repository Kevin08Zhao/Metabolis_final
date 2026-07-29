target_task: none
reported_by: ACCOUNT_C
status: RESOLVED
discovered_at_main_commit: c0653d605ede2d0569f065e1fa9add07a2106e8c
subject: |
  Two accounts assembled the game in parallel, without either knowing the other
  had started. Both are real work and neither is wrong. They overlap in a way
  that cannot be resolved by merging files, because the overlap is in behaviour
  rather than in text.

  Account C stopped rather than reconciling them. The account C task guide is
  explicit: on a conflict, do not merge semantics unilaterally, stop and write a
  risk file. This is that file.
what_each_side_built:
  account_c:
    file: src/game/game_assembly.gd, on branch ai/c-godot-ui-release at 0d66d3e
    approach: |
      One node builds every system and panel, and registers a handler for each of
      the ten steps in table C1 of docs/CHAPTER_FLOW_STEPS.md through a new
      ChapterFlow.register_step_handler seam. A step with a handler never reaches
      its placeholder.
    size: 724 lines, 15 systems and 9 panels instantiated
    verified: |
      Headless run, 42 checks. A complete four-stage run with 7 build decisions
      confirmed and 4 operation decisions, which are the totals in acceptance
      table two of docs/CHAPTER_TIMELINE.md, 3 stage advances, and a real birth
      gate evaluation in which three of four table E5 checks pass.
  other_session:
    files: src/game/game_boot.gd, src/ui/gameplay_controller.gd, src/game/main.tscn
    approach: |
      Scripts attached directly to scene nodes, a Space key that advances the
      flow, an on-screen step label, and a gameplay controller that presents the
      build and operation decisions and handles the player's clicks.
    size: game_boot.gd 142 lines, gameplay_controller.gd presents and confirms
    note: |
      The ten placeholders in chapter_flow.gd are untouched, so the flow still
      auto-confirms both decisions from inside _placeholder_build_decision and
      _placeholder_operation_decision while the controller also drives them.
the_overlap:
  - Both sides call BuildDecision.present_decision, select_candidate and
    request_confirmation.
  - Both sides call OperationDecision.present_decision, select_priority and
    request_confirmation.
  - Only one side replaces the ten placeholders, so on the other side the flow
    confirms the decision itself in parallel with the controller confirming it.
  - src/game/main.tscn is the only textual conflict. Everything else merges
    cleanly, including chapter_flow.gd.
what_was_tried: |
  Account C merged main, resolved the scene in favour of the other session's
  version, added its own node beside theirs, and taught the assembly to adopt
  the scene's ChapterFlow, ResourceBar and NetworkBuilder rather than build
  duplicates. Adoption worked and is verified.

  The run then stalled at stage one's operation decision, because the controller
  had already presented it and the assembly's handler stepped aside for a
  presentation it had not made. Fixing that means deciding which side owns the
  presentation, which is a design decision about someone else's file.

  The merge was aborted rather than pushed. Branch ai/c-godot-ui-release is
  unchanged at its own work and no pull request was opened.
what_needs_deciding:
  - Which side owns presenting a decision: the step handler, or the controller.
  - Whether the ten placeholders are replaced. If they are not, the flow keeps
    confirming decisions the player has not made.
  - Whether one scene carries both nodes, or one of the two is retired.
a_separate_finding: |
  Unrelated to the collision, and worth recording while it is visible.

  docs/coord/done/D-23.md was added to main and says status DONE. Its declared
  output, docs/FALLBACK_SPEC.md, does not exist anywhere in the repository. The
  marker names two PNG files instead, which are frames rather than the fallback
  frame index table and switch behaviour specification the task declares.
  docs/coord/done/D-27.md is in the same position: its declared docs/AUDIO_MIX.md
  is absent.

  This matters beyond bookkeeping. T-38's prompt body pastes docs/FALLBACK_SPEC.md
  in full, and its constraints require each animation to stop on the fallback
  frame that specification names. With the marker present but the file absent,
  T-38 now reads as READY under the three gating conditions while remaining
  impossible to write correctly.
opened_at: 2026-07-29T00:45:00-04:00
resolved_at: 2026-07-29T10:00:00-04:00
resolution: |
  The project owner selected the two audit actions that resolve this decision.
  GameplayController is now the sole presentation and input owner. GameAssembly
  was refactored into a lifecycle-only layer that adopts the controller's
  ResourceTick and ThresholdWatcher instead of constructing duplicate build,
  operation, minigame, or settlement systems. ChapterFlow handlers are
  registered only for lifecycle-owned steps, and the complete interactive
  regression plus the 45-second birth-to-ending run pass.
