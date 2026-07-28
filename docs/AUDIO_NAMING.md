# Audio Naming and Directory Contract

T-37 uses one deterministic path formula for every EventBus event:

```text
audio/events/<event_name>.wav
```

At runtime the same repository-relative file is addressed as
`res://../audio/events/<event_name>.wav`. The router never stores an event-to-file
mapping. Missing files are optional: the router prints one `[AUDIO]` warning per
missing path and continues gameplay.

The ambient heartbeat bed is the only non-event file:
`audio/ambient/heartbeat_bed.wav`. It loops through a dedicated player. Stability
band changes use fades only to move its level; they do not alter gameplay timing.

## Directory Layout

```text
audio/
├── ambient/
│   └── heartbeat_bed.wav
└── events/
    └── <event_name>.wav
```

Use lowercase `snake_case`, uncompressed PCM WAV, and the exact event name from
`docs/EVENT_API.md`. Do not add aliases, numbered variants, or shared filenames.
An event intentionally left silent simply has no file.

## Exact Event Paths

`High frequency` means EVENT_API marks the event as `repeatable within one tick`.
The router applies `assist.audio.high_frequency_min_interval_sec` independently
per high-frequency event name.

| Event | High frequency | Exact repository path |
|---|---:|---|
| `stage_advanced` | No | `audio/events/stage_advanced.wav` |
| `stage_loaded` | No | `audio/events/stage_loaded.wav` |
| `stage_snapshot_written` | No | `audio/events/stage_snapshot_written.wav` |
| `phase_changed` | No | `audio/events/phase_changed.wav` |
| `build_options_presented` | No | `audio/events/build_options_presented.wav` |
| `build_decision_confirmed` | No | `audio/events/build_decision_confirmed.wav` |
| `organ_construction_started` | No | `audio/events/organ_construction_started.wav` |
| `organ_built` | Yes | `audio/events/organ_built.wav` |
| `resource_priority_changed` | Yes | `audio/events/resource_priority_changed.wav` |
| `operation_decision_confirmed` | No | `audio/events/operation_decision_confirmed.wav` |
| `transport_network_intervened` | No | `audio/events/transport_network_intervened.wav` |
| `operation_result_settled` | No | `audio/events/operation_result_settled.wav` |
| `resources_settled` | No | `audio/events/resources_settled.wav` |
| `transport_pressure_appeared` | Yes | `audio/events/transport_pressure_appeared.wav` |
| `transport_pressure_cleared` | Yes | `audio/events/transport_pressure_cleared.wav` |
| `waste_buildup_appeared` | Yes | `audio/events/waste_buildup_appeared.wav` |
| `waste_buildup_cleared` | Yes | `audio/events/waste_buildup_cleared.wav` |
| `signal_gap_appeared` | Yes | `audio/events/signal_gap_appeared.wav` |
| `signal_gap_cleared` | Yes | `audio/events/signal_gap_cleared.wav` |
| `stability_band_changed` | No | `audio/events/stability_band_changed.wav` |
| `waste_overflowed` | No | `audio/events/waste_overflowed.wav` |
| `resource_shortage_raised` | Yes | `audio/events/resource_shortage_raised.wav` |
| `resource_shortage_cleared` | Yes | `audio/events/resource_shortage_cleared.wav` |
| `minigame_entered` | No | `audio/events/minigame_entered.wav` |
| `minigame_exited` | No | `audio/events/minigame_exited.wav` |
| `minigame_rated` | No | `audio/events/minigame_rated.wav` |
| `system_observation_started` | No | `audio/events/system_observation_started.wav` |
| `system_observation_ended` | No | `audio/events/system_observation_ended.wav` |
| `knowledge_entry_unlocked` | Yes | `audio/events/knowledge_entry_unlocked.wav` |
| `knowledge_entry_opened` | Yes | `audio/events/knowledge_entry_opened.wav` |
| `knowledge_entry_closed` | No | `audio/events/knowledge_entry_closed.wav` |
| `carryover_applied` | No | `audio/events/carryover_applied.wav` |
| `save_loaded` | No | `audio/events/save_loaded.wav` |
| `season_completed` | No | `audio/events/season_completed.wav` |
| `delayed_feedback_shown` | No | `audio/events/delayed_feedback_shown.wav` |
| `action_rejected` | Yes | `audio/events/action_rejected.wav` |
| `birth_sequence_started` | No | `audio/events/birth_sequence_started.wav` |
| `birth_state_changed` | No | `audio/events/birth_state_changed.wav` |
| `birth_sequence_completed` | No | `audio/events/birth_sequence_completed.wav` |
| `birth_rolled_back` | No | `audio/events/birth_rolled_back.wav` |

## Scene and Mute Wiring

`AudioRouter` is registered in `src/project.godot`. A mute button needs no audio
UI or gameplay dependency: connect its `pressed` signal directly to
`AudioRouter.toggle_muted`. Muting stops the ambient player and all one-shots;
unmuting restarts the ambient bed if its file exists. EventBus and game state keep
running in both states.

## Acceptance Walk

1. Leave `audio/ambient/` and `audio/events/` empty and play a complete run.
   Trigger representative low- and high-frequency events. Expect only `[AUDIO]`
   missing-file warnings; no error, crash, blocked transition, or stopped game
   logic is acceptable.
2. Put any valid PCM waveform at
   `audio/events/build_decision_confirmed.wav`, restart, and emit
   `build_decision_confirmed`. The one-shot pool must play that file.
3. Emit a high-frequency event twice inside
   `assist.audio.high_frequency_min_interval_sec`. Only the first playback may
   start. Emit it again after the interval; playback must start again.
4. Call `AudioRouter.toggle_muted()`. Every router player must stop. Emit another
   gameplay event and confirm its gameplay listener still runs while no player
   starts. Toggle again and confirm the ambient bed resumes when present.
