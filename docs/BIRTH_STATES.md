# Birth Transition States

Birth is the climax of the first playable version and is built as a controlled
state machine, never as a dynamic simulation. Seven states, a fixed legal
transition graph, and a fixed millisecond timeline. Nothing here is decided at
runtime.

The ending sequence occupies 45 seconds of the operating-time budget: three
observable phases plus the ending picture. `src/sim/birth_machine.gd` implements
the graph in this document; every state body is left empty for T-21-1 through
T-21-7 to fill, one state per task.

Stage four configuration comes from `docs/CHAPTER_TIMELINE.md`. The entry gate is
the four birth checks of table E5 in `docs/OPERATION_SPEC.md`, already implemented
by T-19e as `src/sim/birth_check.gd`; this machine consumes that verdict and does
not re-derive it.

## Table B1: The seven states

| State | `state_id` | Entry condition | Performed on entry | Exit condition | Player actions forbidden | Event | Window on the 45 s timeline |
|---|---|---|---|---|---|---|---|
| Readiness check | `ready_check` | `start()` is called while the machine is `IDLE`, in `stage_birth`, with `final_completion_ready` otherwise satisfied | Read the four E5 verdicts from T-19e and hold them as the gate result | All four checks pass, or any check fails | All six. The stage is closed to input from here until the sequence resolves | `birth_sequence_started`, `birth_state_changed` | Off timeline. The gate is evaluated before the sequence begins and animates nothing |
| Umbilical supply stops | `umbilical_stop` | `ready_check` exited with all four checks passing | Placeholder for T-21-2 | The state's configured duration elapses | All six | `birth_state_changed` | 0 – 10000 ms |
| Pulmonary blood flow rises | `pulmonary_flow` | `umbilical_stop` exited | Placeholder for T-21-3 | The state's configured duration elapses | All six | `birth_state_changed` | 10000 – 20000 ms |
| Fetal shunts change function | `fetal_shunts` | `pulmonary_flow` exited | Placeholder for T-21-4 | The state's configured duration elapses | All six | `birth_state_changed` | 20000 – 30000 ms |
| Major systems light up | `systems_online` | `fetal_shunts` exited | Placeholder for T-21-5 | The state's configured duration elapses | All six | `birth_state_changed` | 30000 – 35000 ms |
| Ending picture | `ending` | `systems_online` exited | Placeholder for T-21-6 | Terminal. The state does not exit | All six except viewing the knowledge archive, which T-25 may reopen | `birth_state_changed`, `birth_sequence_completed` | 35000 – 45000 ms |
| Failure rollback | `failure_rollback` | Any non-terminal state reports that its precondition no longer holds, or `ready_check` found a failing check | Placeholder for T-21-7 | The player acknowledges, returning the machine to `ready_check` | All six while the rollback plays | `birth_state_changed`, `birth_rolled_back` | Off timeline. An interrupt, not a beat |

`failure_rollback` never ends the run. `docs/OPERATION_SPEC.md` guarantees that a
failed check does not lock the flow: the player may operate again, wait for ticks,
and retry. This machine honours that by routing rollback back to `ready_check`
rather than to a terminal state.

## Table B2: The 45-second timeline

| Block | State | Start (ms) | End (ms) | Duration (ms) |
|---|---|---:|---:|---:|
| Observable phase 1 | `umbilical_stop` | 0 | 10000 | 10000 |
| Observable phase 2 | `pulmonary_flow` | 10000 | 20000 | 10000 |
| Observable phase 3 | `fetal_shunts` | 20000 | 30000 | 10000 |
| Ending picture, part 1 | `systems_online` | 30000 | 35000 | 5000 |
| Ending picture, part 2 | `ending` | 35000 | 45000 | 10000 |
| **Total** | | **0** | **45000** | **45000** |

Three observable phases at exactly 10000 ms each total 30000 ms. The ending
picture is the remaining 15000 ms, split so that systems lighting up reads as its
own beat before the final image settles. The sum is 45000 ms, which meets the
budget exactly rather than exceeding it.

`ready_check` and `failure_rollback` carry no window. The gate resolves before the
sequence starts and the rollback is an interrupt; neither consumes ending-sequence
time. Placing either on the timeline would push the total past 45000 ms.

## Table B3: Legal transitions

```text
IDLE             -> ready_check          start()
ready_check      -> umbilical_stop       all four E5 checks passed
ready_check      -> failure_rollback     any E5 check failed
umbilical_stop   -> pulmonary_flow       window elapsed
umbilical_stop   -> failure_rollback     precondition lost
pulmonary_flow   -> fetal_shunts         window elapsed
pulmonary_flow   -> failure_rollback     precondition lost
fetal_shunts     -> systems_online       window elapsed
fetal_shunts     -> failure_rollback     precondition lost
systems_online   -> ending               window elapsed
systems_online   -> failure_rollback     precondition lost
failure_rollback -> ready_check          player acknowledged
ending           -> (terminal)
```

## Table B4: Illegal transitions and why

| Attempt | Verdict | Reason |
|---|---|---|
| Skipping any state, for example `ready_check -> pulmonary_flow` | Rejected | The physiological order is the teaching content. A skipped beat is a skipped explanation |
| Any backwards move, for example `fetal_shunts -> umbilical_stop` | Rejected | The sequence is one-way. Rewinding would replay a transition the body performs once |
| Anything out of `ending` | Rejected | `ending` is terminal. The run is over and T-25 owns what follows |
| `ending -> failure_rollback` | Rejected | Success cannot be revoked after the fact |
| `failure_rollback -> anything but ready_check` | Rejected | A rollback returns the player to the gate so the four checks are re-evaluated honestly. Resuming mid-sequence would skip that |
| Re-entering the current state | Rejected | A no-op transition would emit a change event when nothing changed |
| Any transition while `IDLE` other than through `start()` | Rejected | The machine has no stage context before it starts |

Every rejection prints a `[BIRTH]` line, emits `action_rejected`, and leaves the
current state untouched.

## Required Balance keys

State durations are read through `Balance`. **These keys do not exist in
`docs/BALANCE.json` yet.** T-06 owns that file; the values below are the ones
table B2 fixes.

| Path | Value |
|---|---|
| `chapters.stage_birth.birth_sequence.umbilical_stop_ms` | 10000 |
| `chapters.stage_birth.birth_sequence.pulmonary_flow_ms` | 10000 |
| `chapters.stage_birth.birth_sequence.fetal_shunts_ms` | 10000 |
| `chapters.stage_birth.birth_sequence.systems_online_ms` | 5000 |
| `chapters.stage_birth.birth_sequence.ending_ms` | 10000 |
| `chapters.stage_birth.birth_sequence.total_budget_ms` | 45000 |

Until they are added, `birth_machine.gd` reports every missing path through a
`[BIRTH]` warning and `state_duration_ms()` returns zero. The state graph, the
transition rules, and the rejection behaviour do not depend on these keys, so the
machine is fully usable and testable without them. T-21-2 onward do depend on
them, because that is where a window actually elapses.

## Events

Section 9 of `docs/EVENT_API.md` carries the birth sequence. Four events:

| Event | Emitted at |
|---|---|
| `birth_sequence_started` | Every entry into `ready_check`, whether from `start()` or from an acknowledged rollback, before the per-beat event. A retry is a fresh attempt and must close input again, so this fires once per attempt rather than once per run |
| `birth_state_changed` | Every accepted transition, from `transition_to`. Carries `window_ms`, which is zero for `ready_check` and `failure_rollback` |
| `birth_sequence_completed` | Entering `ending` |
| `birth_rolled_back` | Entering `failure_rollback`, with `gate_check_failed` or `precondition_lost` |

`birth_state_changed` is the generic per-beat mount point, structurally the same
as `phase_changed`: D-22 and D-26 switch on `current_state` rather than expecting
one event per beat, and each beat must finish inside the `window_ms` it is handed.

Illegal transitions get no event of their own. They reuse `action_rejected` with
`action_id` set to `birth_transition`.

`birth_rolled_back` must never be presented as a death, a game over, or a lost
run. The rollback returns the player to the gate.
