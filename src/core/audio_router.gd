extends Node

## Event-driven audio playback with a crossfaded ambient bed and reusable
## one-shot pool.
##
## Autoload registration:
## Project > Project Settings > Globals > Autoload
## Select res://core/audio_router.gd, set the name to AudioRouter, and enable it.
##
## Event sound paths are always derived by event_audio_path(). No event-to-file
## mapping is maintained in this script.

const LOG_PREFIX := "[AUDIO]"
const EVENT_AUDIO_ROOT := "res://../audio/events"
const AUDIO_EXTENSION := "wav"
const MAX_ONE_SHOTS_BALANCE_PATH := "assist.audio.max_concurrent_one_shots"
const HIGH_FREQUENCY_INTERVAL_BALANCE_PATH := "assist.audio.high_frequency_min_interval_sec"
const AMBIENT_FADE_SEC := 0.25
const AMBIENT_SILENCE_DB := -80.0
const AMBIENT_PLAYER_COUNT := 2
const AUDIO_RELEASE_GRACE_SEC := 0.10
const AMBIENT_AUDIO_PATHS_BY_STABILITY_BAND: Array[String] = [
	"res://../audio/ambient/heartbeat_bed.wav",
	"res://../audio/ambient/heartbeat_bed_strained.wav",
	"res://../audio/ambient/heartbeat_bed_critical.wav",
]
const AMBIENT_LOOP_DURATION_SEC_BY_STABILITY_BAND: Array[float] = [
	1.0,
	0.44,
	1.8,
]
const AMBIENT_VOLUME_DB_BY_STABILITY_BAND: Array[float] = [-16.0, -12.0, -8.0]

## EVENT_API marks these events as repeatable within one tick.
const HIGH_FREQUENCY_EVENTS: Array[StringName] = [
	&"organ_built",
	&"resource_priority_changed",
	&"transport_pressure_appeared",
	&"transport_pressure_cleared",
	&"waste_buildup_appeared",
	&"waste_buildup_cleared",
	&"signal_gap_appeared",
	&"signal_gap_cleared",
	&"resource_shortage_raised",
	&"resource_shortage_cleared",
	&"knowledge_entry_unlocked",
	&"knowledge_entry_opened",
	&"action_rejected",
]

var muted: bool:
	get:
		return _muted
	set(value):
		set_muted(value)

var _muted := false
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_cycle_timer: Timer
var _active_ambient_player_index := 0
var _ambient_band := 0
var _pending_ambient_band := -1
var _ambient_transition_count := 0
var _one_shot_players: Array[AudioStreamPlayer] = []
var _next_reuse_index := 0
var _high_frequency_interval_msec := 0
var _last_played_at_msec: Dictionary = {}
var _warned_paths: Dictionary = {}
var _ambient_tween: Tween
var _graceful_quit_started := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_read_configuration()
	_create_players()
	_connect_event_bus()
	_start_ambient()


func _exit_tree() -> void:
	_shutdown_audio()
	_release_audio_nodes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_graceful_quit()


## Return the only valid one-shot path for an event.
func event_audio_path(event_name: StringName) -> String:
	return "%s/%s.%s" % [EVENT_AUDIO_ROOT, event_name, AUDIO_EXTENSION]


## Return the deterministic heartbeat path for a D-21 stability band.
func ambient_audio_path(stability_band: int) -> String:
	if not _valid_ambient_band(stability_band):
		return ""
	return AMBIENT_AUDIO_PATHS_BY_STABILITY_BAND[stability_band]


func current_ambient_band() -> int:
	return _ambient_band


func pending_ambient_band() -> int:
	return _pending_ambient_band


func ambient_transition_count() -> int:
	return _ambient_transition_count


func ambient_player_count() -> int:
	return _ambient_players.size()


func ambient_crossfade_duration_sec() -> float:
	return AMBIENT_FADE_SEC


func ambient_loop_duration_sec(stability_band: int) -> float:
	if not _valid_ambient_band(stability_band):
		return 0.0
	return AMBIENT_LOOP_DURATION_SEC_BY_STABILITY_BAND[stability_band]


## Stop and dereference audio before a programmatic SceneTree.quit().
## Callers should allow at least AUDIO_RELEASE_GRACE_SEC before quitting so the
## audio thread can retire its final playback reference.
func prepare_for_shutdown() -> void:
	_shutdown_audio()


## Toggle all audio controlled by this router. Gameplay signals continue normally.
func toggle_muted() -> bool:
	set_muted(not _muted)
	return _muted


func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value

	if _muted:
		_stop_ambient()
		for player in _one_shot_players:
			player.stop()
			player.stream = null
		return

	_start_ambient()


func active_one_shot_count() -> int:
	var active_count := 0
	for player in _one_shot_players:
		if player.playing:
			active_count += 1
	return active_count


func one_shot_pool_size() -> int:
	return _one_shot_players.size()


func _read_configuration() -> void:
	var pool_value: Variant = Balance.get_value(MAX_ONE_SHOTS_BALANCE_PATH, null)
	var interval_value: Variant = Balance.get_value(
		HIGH_FREQUENCY_INTERVAL_BALANCE_PATH,
		null
	)

	var pool_size := _positive_integer(pool_value)
	if pool_size < 1:
		_warn("Balance path '%s' must be a positive integer." % MAX_ONE_SHOTS_BALANCE_PATH)

	var interval_sec := _positive_number(interval_value)
	if interval_sec <= 0.0:
		_warn("Balance path '%s' must be positive." % HIGH_FREQUENCY_INTERVAL_BALANCE_PATH)
	else:
		_high_frequency_interval_msec = maxi(1, roundi(interval_sec * 1000.0))


func _create_players() -> void:
	var pool_value: Variant = Balance.get_value(MAX_ONE_SHOTS_BALANCE_PATH, null)
	var pool_size := _positive_integer(pool_value)
	if pool_size < 1:
		return

	for player_index in AMBIENT_PLAYER_COUNT:
		var ambient_player := AudioStreamPlayer.new()
		ambient_player.name = "AmbientBed%s" % String.chr(65 + player_index)
		ambient_player.volume_db = AMBIENT_SILENCE_DB
		add_child(ambient_player)
		_ambient_players.append(ambient_player)

	_ambient_cycle_timer = Timer.new()
	_ambient_cycle_timer.name = "AmbientCycleBoundary"
	_ambient_cycle_timer.one_shot = true
	_ambient_cycle_timer.timeout.connect(_on_ambient_cycle_boundary)
	add_child(_ambient_cycle_timer)

	for player_index in pool_size:
		var player := AudioStreamPlayer.new()
		player.name = "OneShot%02d" % (player_index + 1)
		add_child(player)
		_one_shot_players.append(player)


func _connect_event_bus() -> void:
	for signal_info in EventBus.get_signal_list():
		var event_name := StringName(signal_info["name"])
		if not EventBus.EVENT_NAMES.has(event_name):
			continue

		var argument_count: int = (signal_info["args"] as Array).size()
		if argument_count < 1 or argument_count > 4:
			_warn("Cannot route event '%s' with %s arguments." % [event_name, argument_count])
			continue

		var dispatcher := Callable(self, "_route_%d" % argument_count).bind(event_name)
		if not EventBus.is_connected(event_name, dispatcher):
			EventBus.connect(event_name, dispatcher)


func _route_event(event_name: StringName, arguments: Array) -> void:
	if event_name == &"stability_band_changed":
		_update_ambient_for_stability(int(arguments[1]))
	_play_event_sfx(event_name)


func _play_event_sfx(event_name: StringName) -> void:
	if _muted or _one_shot_players.is_empty():
		return
	if _is_debounced(event_name):
		return

	var stream := _load_wav(event_audio_path(event_name), false)
	if stream == null:
		return

	var player := _acquire_one_shot_player()
	if player == null:
		return
	player.stream = stream
	player.play()


func _is_debounced(event_name: StringName) -> bool:
	if not HIGH_FREQUENCY_EVENTS.has(event_name):
		return false
	if _high_frequency_interval_msec < 1:
		return true

	var now_msec := Time.get_ticks_msec()
	var previous_msec := int(
		_last_played_at_msec.get(event_name, now_msec - _high_frequency_interval_msec)
	)
	if now_msec - previous_msec < _high_frequency_interval_msec:
		return true
	_last_played_at_msec[event_name] = now_msec
	return false


func _acquire_one_shot_player() -> AudioStreamPlayer:
	for player in _one_shot_players:
		if not player.playing:
			return player

	var player := _one_shot_players[_next_reuse_index]
	_next_reuse_index = (_next_reuse_index + 1) % _one_shot_players.size()
	player.stop()
	return player


func _start_ambient() -> void:
	if _muted or _ambient_players.is_empty():
		return
	_stop_ambient()

	var stream := _load_ambient_stream(_ambient_band)
	if stream == null:
		return
	_active_ambient_player_index = 0
	var player := _ambient_players[_active_ambient_player_index]
	player.stream = stream
	player.volume_db = AMBIENT_VOLUME_DB_BY_STABILITY_BAND[_ambient_band]
	player.play()
	_start_ambient_cycle_timer()


func _update_ambient_for_stability(stability_band: int) -> void:
	if not _valid_ambient_band(stability_band):
		_warn("Ignoring unknown stability band %s." % stability_band)
		return
	if _muted or _ambient_players.is_empty():
		_ambient_band = stability_band
		_pending_ambient_band = -1
		return
	var active_player := _ambient_players[_active_ambient_player_index]
	if not active_player.playing:
		_ambient_band = stability_band
		_pending_ambient_band = -1
		_start_ambient()
		return

	if stability_band == _ambient_band:
		_pending_ambient_band = -1
		return
	_pending_ambient_band = stability_band


func _on_ambient_cycle_boundary() -> void:
	if _muted or _ambient_players.is_empty():
		return
	if (
		_valid_ambient_band(_pending_ambient_band)
		and _pending_ambient_band != _ambient_band
	):
		_begin_ambient_crossfade(_pending_ambient_band)
		return
	_pending_ambient_band = -1
	_start_ambient_cycle_timer()


func _begin_ambient_crossfade(target_band: int) -> void:
	var incoming_index := 1 - _active_ambient_player_index
	var outgoing_player := _ambient_players[_active_ambient_player_index]
	var incoming_player := _ambient_players[incoming_index]
	var incoming_stream := _load_ambient_stream(target_band)
	if incoming_stream == null:
		_pending_ambient_band = -1
		_start_ambient_cycle_timer()
		return

	incoming_player.stop()
	incoming_player.stream = incoming_stream
	incoming_player.volume_db = AMBIENT_SILENCE_DB
	incoming_player.play()

	_active_ambient_player_index = incoming_index
	_ambient_band = target_band
	_pending_ambient_band = -1
	_ambient_transition_count += 1
	_start_ambient_cycle_timer()

	if _ambient_tween != null:
		_ambient_tween.kill()
	_ambient_tween = create_tween().set_parallel(true)
	_ambient_tween.tween_property(
		outgoing_player,
		"volume_db",
		AMBIENT_SILENCE_DB,
		AMBIENT_FADE_SEC
	)
	_ambient_tween.tween_property(
		incoming_player,
		"volume_db",
		AMBIENT_VOLUME_DB_BY_STABILITY_BAND[target_band],
		AMBIENT_FADE_SEC
	)
	_ambient_tween.chain().tween_callback(
		_finish_ambient_crossfade.bind(outgoing_player)
	)


func _finish_ambient_crossfade(outgoing_player: AudioStreamPlayer) -> void:
	outgoing_player.stop()
	outgoing_player.stream = null
	outgoing_player.volume_db = AMBIENT_SILENCE_DB
	_ambient_tween = null


func _start_ambient_cycle_timer() -> void:
	if _ambient_cycle_timer == null or _muted:
		return
	_ambient_cycle_timer.start(
		AMBIENT_LOOP_DURATION_SEC_BY_STABILITY_BAND[_ambient_band]
	)


func _load_ambient_stream(stability_band: int) -> AudioStreamWAV:
	var stream := _load_wav(ambient_audio_path(stability_band), true)
	if stream == null:
		return null
	var expected_duration := AMBIENT_LOOP_DURATION_SEC_BY_STABILITY_BAND[stability_band]
	var frame_tolerance := 1.0 / float(stream.mix_rate)
	if absf(stream.get_length() - expected_duration) > frame_tolerance:
		_warn(
			"Heartbeat band %s must be %.0f ms, got %.3f ms."
			% [stability_band, expected_duration * 1000.0, stream.get_length() * 1000.0]
		)
		return null
	return stream


func _stop_ambient() -> void:
	if _ambient_cycle_timer != null:
		_ambient_cycle_timer.stop()
	if _ambient_tween != null:
		_ambient_tween.kill()
		_ambient_tween = null
	for player in _ambient_players:
		player.stop()
		player.stream = null
		player.volume_db = AMBIENT_SILENCE_DB


func _shutdown_audio() -> void:
	_stop_ambient()
	for player in _one_shot_players:
		player.stop()
		player.stream = null
	_last_played_at_msec.clear()
	_warned_paths.clear()


func _graceful_quit() -> void:
	if _graceful_quit_started:
		return
	_graceful_quit_started = true
	prepare_for_shutdown()
	await get_tree().create_timer(AUDIO_RELEASE_GRACE_SEC).timeout
	get_tree().quit()


func _release_audio_nodes() -> void:
	if _ambient_cycle_timer != null:
		if _ambient_cycle_timer.get_parent() == self:
			remove_child(_ambient_cycle_timer)
		_ambient_cycle_timer.free()
		_ambient_cycle_timer = null
	for player in _ambient_players:
		if player.get_parent() == self:
			remove_child(player)
		player.free()
	_ambient_players.clear()
	for player in _one_shot_players:
		if player.get_parent() == self:
			remove_child(player)
		player.free()
	_one_shot_players.clear()


func _valid_ambient_band(stability_band: int) -> bool:
	return (
		stability_band >= 0
		and stability_band < AMBIENT_AUDIO_PATHS_BY_STABILITY_BAND.size()
	)


func _load_wav(path: String, loop: bool) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		_warn_missing_once(path)
		return null

	var stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null:
		_warn("Could not read WAV file '%s'; skipping playback." % path)
		return null
	if loop:
		stream.loop_begin = 0
		stream.loop_end = maxi(1, roundi(stream.get_length() * float(stream.mix_rate)))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _warn_missing_once(path: String) -> void:
	if _warned_paths.has(path):
		return
	_warned_paths[path] = true
	_warn("Missing file '%s'; skipping playback." % path)


func _warn(message: String) -> void:
	push_warning("%s %s" % [LOG_PREFIX, message])


func _positive_integer(value: Variant) -> int:
	if not value is int and not value is float:
		return -1
	var number := float(value)
	if number < 1.0 or not is_equal_approx(number, floor(number)):
		return -1
	return int(number)


func _positive_number(value: Variant) -> float:
	if not value is int and not value is float:
		return -1.0
	return float(value)


# Bound event names are appended after the signal arguments.
func _route_1(a0: Variant, event_name: StringName) -> void:
	_route_event(event_name, [a0])


func _route_2(a0: Variant, a1: Variant, event_name: StringName) -> void:
	_route_event(event_name, [a0, a1])


func _route_3(a0: Variant, a1: Variant, a2: Variant, event_name: StringName) -> void:
	_route_event(event_name, [a0, a1, a2])


func _route_4(
	a0: Variant,
	a1: Variant,
	a2: Variant,
	a3: Variant,
	event_name: StringName
) -> void:
	_route_event(event_name, [a0, a1, a2, a3])
