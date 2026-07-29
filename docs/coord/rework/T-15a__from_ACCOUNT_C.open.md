target_task: T-15a
reported_by: ACCOUNT_C
status: OPEN
discovered_at_main_commit: 959ef0ddd3d3672d7836efc3c4721ce42701655c
subject: |
  src/game/game_assembly.gd now drives a complete run through all four stages.
  Five of the seven items in T-38's acceptance method are demonstrable, measured
  by events that fired during the run. Two are not, and both fail for the same
  cause: no transport graph is ever instantiated, so nothing carries flow and
  nothing processes waste.

  This is not a defect in T-15a's own delivery. NetworkBuilder generates an
  extension when asked and its acceptance passed. What is missing is the step
  that instantiates the resulting nodes and edges into a graph the settlement
  can read, and no task declares it.
what_the_run_shows:
  - 7 build decisions confirmed, which is the total in acceptance table two of
    docs/CHAPTER_TIMELINE.md.
  - 4 operation decisions confirmed, which is that table's total.
  - 14 organ_built events, 3 stage_advanced, 4 stage_loaded.
  - 1 birth_sequence_started.
  - 0 transport_pressure_appeared, 0 waste_buildup_appeared, 0 signal_gap_appeared.
  - 0 season_completed.
blocked_item_3:
  item: T-38 acceptance item three, handling one bottleneck.
  cause: |
    BottleneckDetector.evaluate reads transport_pressure, organ_transport_coverage,
    edge_flow_by_id and the waste generation and processing maps. The assembly
    supplies each from ResourceTick's settled outputs, and every one of them is
    empty or zero, because ResourceTick settles against a transport graph that
    was never built. No threshold is ever crossed, so no bottleneck appears and
    none can be handled.
blocked_item_7:
  item: T-38 acceptance item seven, reaching an ending state.
  cause: |
    The birth gate is reached and evaluated. Three of its four table E5 checks
    pass and one fails, measured:

      transport_coverage  1.00 against a minimum of 0.70   PASS
      stability         100.00 against a minimum of 55.00  PASS
      birth_readiness     1.00 against a minimum of 0.70   PASS
      waste              77.76 against a maximum of 50.00  FAIL, gap 27.76

    Waste accumulates at resources.waste.accumulation_per_tick across the 1068
    configured ticks of the run and nothing removes it, because
    resources.waste.recovery_by_coverage is a function of transport coverage and
    the waste routes, which need the same graph.

    The machine then does what docs/BIRTH_STATES.md requires: it unwinds to
    failure_rollback and waits for the player to acknowledge. That is correct
    behaviour for a failed check, not a crash, and the run still reaches its
    terminal state. What is missing is a run in which the check can pass.
expected: |
  A step that instantiates the generated extension into the running transport
  graph, so that ResourceTick settles against real nodes and edges. Once flow
  and waste routes exist, both items above should follow without further
  assembly work: the detector already reads the fields ResourceTick would then
  populate, and waste processing already has its configured recovery path.
what_account_c_has_done:
  - Wired every system and panel, and registered a handler for all ten steps.
  - Verified a complete four-stage run headless, 42 checks passing.
  - Asserted both blocked items as blocked rather than skipping them, so the
    acceptance fails and says so on the day either starts working.
impact:
  - T-38 cannot be marked DONE, which was already true for a second reason:
    docs/FALLBACK_SPEC.md does not exist, and T-38's prompt pastes it in full.
  - T-39 and T-40 sit behind T-38.
  - The five demonstrable items are demonstrable now, where none was before.
opened_at: 2026-07-29T00:20:00-04:00
