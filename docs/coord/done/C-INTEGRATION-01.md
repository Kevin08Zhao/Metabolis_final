task_id: C-INTEGRATION-01
task_name: Main gameplay architecture and lifecycle integration
owner: ACCOUNT_C
status: DONE
source: User-requested project audit actions 1 and 2
base_main_commit: 068854b
outputs:
  - src/core/chapter_flow.gd
  - src/core/scene_router.gd
  - src/game/game_assembly.gd
  - src/game/game_boot.gd
  - src/game/main.tscn
  - src/project.godot
  - src/tests/gameplay_entry_regression_test.gd
  - src/ui/gameplay_controller.gd
  - src/world/organ_state.gd
architecture: |
  GameplayController is the sole player-input, visible-action, decision,
  minigame, and resource-settlement owner. GameBoot owns scene startup and
  ending routing. GameAssembly is a lifecycle-only integration layer that
  adopts the controller's live settlement systems and wires bottlenecks, organ
  cooperation, carryover, birth, ending, InputLock, NetworkIntervention, and
  auxiliary UI without constructing duplicate decision or settlement systems.
checks:
  - The verifier first detected a deliberate `1 == 2` failure as FAIL-EXPECTED,
    then proved its comment stripper removes comments while preserving `#`
    inside a quoted string: PASS
  - Godot 4.7.1 headless editor import registered every changed global class
    without a script or scene parse failure: PASS
  - Fast interactive regression traversed all four stages through real buttons,
    double confirmations, settlement, builds, operations, system observations,
    carryover, and birth gate entry: PASS
  - Exactly three carryover records were generated before stage_advanced,
    committed after stage_loaded, applied to live start conditions, and recorded
    in SaveManager: PASS
  - Exactly four OrganCheck collaboration observations completed, one in each
    stage, using live route edges and settlement metrics: PASS
  - BottleneckDetector received live settlement and operation metrics; the
    configured NetworkIntervention and all auxiliary UI nodes are present in the
    main scene lifecycle: PASS
  - BirthCheck used the final city values: transport coverage
    0.85542168674699, waste 44.94434869248, stability 100.0, and birth readiness
    0.9421686746988; all four checks passed: PASS
  - Full real-time lifecycle ran the configured 45-second birth sequence,
    released InputLock, satisfied Ending's six conditions, generated an unscored
    five-group summary, and routed to res://ui/ending.tscn: PASS
  - The ending screen rendered all five summary groups and the summary contained
    no score, grade, or title: PASS
  - Godot import preserved window/dpi/allow_hidpi and
    window/stretch/aspect in src/project.godot: PASS
reported_not_fixed:
  - TimelinePanel and MinigamePanel remain event-active but hidden because their
    current multi-line specification layouts duplicate and overlap the compact
    playable action panel. A later visual-layout pass can give them dedicated
    non-overlapping space without changing lifecycle ownership.
  - AudioRouter intentionally warns for event WAV files not selected by the
    limited audio-production scope. The final regression mutes audio so these
    expected omissions do not obscure lifecycle verdicts.
