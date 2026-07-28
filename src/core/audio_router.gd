extends Node

## Event-driven audio playback with one ambient bed and a reusable one-shot pool.
##
## Autoload registration:
## Project > Project Settings > Globals > Autoload
## Select res://core/audio_router.gd, set the name to AudioRouter, and enable it.
##
## Event sound paths are always derived by event_audio_path(). No event-to-file
## mapping is maintained in this script.

const LOG_PREFIX := "[AUDIO]"
const EVENT_AUDIO_ROOT := "res://../audio/events"
const AMBIENT_AUDIO_PATH := "res://../audio/ambient/heartbeat_bed.wav"
const AUDIO_EXTENSION := "wav"
const MAX_ONE_SHOTS_BALANCE_PATH := "assist.audio.max_concurrent_one_shots"
const HIGH_FREQUENCY_INTERVAL_BALANCE_PATH := "assist.audio.high_frequency_min_interval_sec"
const AMBIENT_FADE_SEC := 0.25
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
var _ambient_player: AudioStreamPlayer
var _one_shot_players: Array[AudioStreamPlayer] = []
var _next_reuse_index := 0
var _high_frequency_interval_msec := 0
var _last_played_at_msec: Dictionary = {}
var _warned_paths: Dictionary = {}
var _ambient_tween: Tween


func _ready() -> void:
	_read_configuration()
	_create_players()
	_connect_event_bus()
	_start_ambient()


## Return the only valid one-shot path for an event.
func event_audio_path(event_name: StringName) -> String:
	return "%s/%s.%s" % [EVENT_AUDIO_ROOT, event_name, AUDIO_EXTENSION]


## Toggle all audio controlled by this router. Gameplay signals continue normally.
func toggle_muted() -> bool:
	set_muted(not _muted)
	return _muted


func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value

	if _muted:
		if _ambient_tween != null:
			_ambient_tween.kill()
		_ambient_tween = null
		if _ambient_player != null:
			_ambient_player.stop()
		for player in _one_shot_players:
			player.stop()
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

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientBed"
	_ambient_player.volume_db = AMBIENT_VOLUME_DB_BY_STABILITY_BAND[0]
	add_child(_ambient_player)

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
	if _muted or _ambient_player == null:
		return
	if _ambient_player.stream == null:
		var stream := _load_wav(AMBIENT_AUDIO_PATH, true)
		if stream == null:
			return
		_ambient_player.stream = stream
	if not _ambient_player.playing:
		_ambient_player.play()


func _update_ambient_for_stability(stability_band: int) -> void:
	if stability_band < 0 or stability_band >= AMBIENT_VOLUME_DB_BY_STABILITY_BAND.size():
		_warn("Ignoring unknown stability band %s." % stability_band)
		return
	if _ambient_player == null or not _ambient_player.playing:
		return

	if _ambient_tween != null:
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(
		_ambient_player,
		"volume_db",
		AMBIENT_VOLUME_DB_BY_STABILITY_BAND[stability_band],
		AMBIENT_FADE_SEC
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
