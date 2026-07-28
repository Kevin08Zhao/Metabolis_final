target_task: T-37
reported_by: ACCOUNT_D
blocking_task: D-25
status: OPEN
discovered_at_main_commit: 7464f53d7cadacb1239d05c8dc66ea880d246db4
completed_work:
  - docs/AUDIO_SFX_SPEC.md
  - docs/HEARTBEAT_AUDIO_SPEC.md
  - tools/build_d25_heartbeat_audio.py
  - tests/test_build_d25_heartbeat_audio.py
  - audio/ambient/heartbeat_bed.wav
failed_contract:
  - D-25 requires heartbeat cadence to equal the D-21 loop duration in all three stability bands.
  - D-21 durations are 1000 ms stable, 440 ms strained, and 1800 ms critical.
  - src/core/audio_router.gd loads one ambient file and changes only volume_db.
  - The router does not change cadence, switch state-specific loops, or crossfade two ambient streams.
  - Direct playback-rate conversion would shift pitch by approximately +14.2 or -10.2 semitones and is audibly unacceptable under D-25.
expected:
  - Stable, strained, and critical heartbeat intervals exactly match 1000, 440, and 1800 ms.
  - A 250 ms crossfade begins on relaxed animation frame 0.
  - Hysteresis prevents repeated switching inside the threshold margins.
  - Muting remains independent of gameplay and animation timing.
actual:
  - The stable 1000 ms fallback source exists and passes PCM, peak, determinism, and loop-boundary tests.
  - Runtime playback remains one fixed cadence for all three stability bands.
  - Godot 4.7.1 verbose headless shutdown reports one AudioStreamWAV and one AudioStreamPlaybackWAV instance still referenced after loading the ambient bed.
impact:
  - D-25 cannot truthfully receive a DONE marker.
  - D-27 and the final D-28 freeze remain downstream-blocked.
resolution_condition:
  - Add an approved pitch-preserving cadence implementation or three state-specific loops with deterministic path rules.
  - Pass live 1000/440/1800 ms cadence checks, 250 ms crossfade, hysteresis, mute, and no-clipping checks.
  - Confirm a normal project shutdown releases the loaded heartbeat stream without an ObjectDB leak warning.
opened_at: 2026-07-28T19:00:00Z
