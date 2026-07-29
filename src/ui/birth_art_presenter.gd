class_name BirthArtPresenter
extends TextureRect

## Displays the D-22 PixelLab timeline while BirthMachine owns all state.

const TITLE_FADE_START_SECONDS := 44.0
const FRAME_IDS: Array[StringName] = [
	&"stage1_umbilical_stop_00000",
	&"stage1_umbilical_stop_03333",
	&"stage1_umbilical_stop_06666",
	&"stage1_umbilical_stop_09999",
	&"stage2_pulmonary_flow_10000",
	&"stage2_pulmonary_flow_13333",
	&"stage2_pulmonary_flow_16666",
	&"stage2_pulmonary_flow_19999",
	&"stage3_shunt_closure_20000",
	&"stage3_shunt_closure_23333",
	&"stage3_shunt_closure_26666",
	&"stage3_shunt_closure_29999",
	&"stage4_systems_online_30000",
	&"stage4_systems_online_34999",
	&"stage5_ending_35000",
	&"stage5_ending_37500",
	&"stage5_ending_39000",
	&"stage5_ending_42000",
]
const FRAME_START_SECONDS := [
	0.0,
	3.333,
	6.666,
	9.999,
	10.0,
	13.333,
	16.666,
	19.999,
	20.0,
	23.333,
	26.666,
	29.999,
	30.0,
	34.999,
	35.0,
	37.5,
	39.0,
	42.0,
]
const TOTAL_DURATION_SECONDS := 45.0

var _current_frame_id: StringName = &""
var _elapsed_seconds := 0.0
var _state_end_seconds := 0.0
var _sequence_started := false


func _ready() -> void:
	set_process(false)
	EventBus.birth_sequence_started.connect(_on_birth_sequence_started)
	EventBus.birth_state_changed.connect(_on_birth_state_changed)
	EventBus.birth_rolled_back.connect(_on_birth_rolled_back)


func _process(delta: float) -> void:
	advance_time(delta)


func start_sequence() -> void:
	_elapsed_seconds = 0.0
	_state_end_seconds = 9.999
	_sequence_started = true
	self_modulate.a = 1.0
	set_process(true)
	_show_frame_at_index(0)


func advance_time(seconds: float) -> void:
	if not _sequence_started or seconds <= 0.0:
		return
	_elapsed_seconds = minf(
		minf(_elapsed_seconds + seconds, _state_end_seconds),
		TOTAL_DURATION_SECONDS
	)
	var frame_index := 0
	for index in FRAME_START_SECONDS.size():
		if _elapsed_seconds >= FRAME_START_SECONDS[index]:
			frame_index = index
	_show_frame_at_index(frame_index)
	if _elapsed_seconds >= TITLE_FADE_START_SECONDS:
		self_modulate.a = clampf(
			TOTAL_DURATION_SECONDS - _elapsed_seconds,
			0.0,
			1.0
		)
	if _elapsed_seconds >= TOTAL_DURATION_SECONDS:
		_sequence_started = false
		set_process(false)


func show_frame(frame_id: StringName) -> bool:
	if not FRAME_IDS.has(frame_id):
		return false
	var logical_name := StringName("%s_2x" % frame_id)
	texture = AssetLoader.get_static_texture(logical_name)
	_current_frame_id = frame_id
	visible = texture != null
	if String(frame_id).begins_with("stage5_ending"):
		position = Vector2.ZERO
		size = Vector2(640, 360)
	else:
		position = Vector2(0, 40)
		size = Vector2(640, 320)
	return visible


func hide_frame() -> void:
	set_process(false)
	visible = false
	self_modulate.a = 1.0
	_current_frame_id = &""
	_sequence_started = false


func current_frame_id() -> StringName:
	return _current_frame_id


func _show_frame_at_index(index: int) -> void:
	show_frame(FRAME_IDS[clampi(index, 0, FRAME_IDS.size() - 1)])


func _on_birth_sequence_started(
	_stage_id: StringName,
	_total_budget_ms: int
) -> void:
	hide_frame()


func _on_birth_state_changed(
	_previous_state: int,
	current_state: int,
	_window_ms: int
) -> void:
	match current_state:
		BirthMachine.State.UMBILICAL_STOP:
			start_sequence()
		BirthMachine.State.PULMONARY_FLOW:
			_begin_state(10.0, 19.999)
		BirthMachine.State.FETAL_SHUNTS:
			_begin_state(20.0, 29.999)
		BirthMachine.State.SYSTEMS_ONLINE:
			_begin_state(30.0, 34.999)
		BirthMachine.State.ENDING:
			_begin_state(35.0, TOTAL_DURATION_SECONDS)


func _on_birth_rolled_back(
	_from_state: int,
	_reason_code: StringName
) -> void:
	hide_frame()


func _begin_state(start_seconds: float, end_seconds: float) -> void:
	_elapsed_seconds = start_seconds
	_state_end_seconds = end_seconds
	_sequence_started = true
	set_process(true)
	var frame_index := FRAME_START_SECONDS.find(start_seconds)
	_show_frame_at_index(maxi(frame_index, 0))
