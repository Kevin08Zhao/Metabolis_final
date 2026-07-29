class_name BirthArtPresenter
extends TextureRect

## Displays the five landed PixelLab birth frames over the 640x320 city map.

const FRAME_IDS: Array[StringName] = [
	&"stage1_umbilical_stop",
	&"stage2_pulmonary_flow",
	&"stage3_shunt_closure",
	&"stage4_systems_online",
	&"stage5_ending",
]
const FRAME_START_SECONDS := [0.0, 10.0, 20.0, 30.0, 35.0]
const TOTAL_DURATION_SECONDS := 45.0

var _current_frame_id: StringName = &""
var _elapsed_seconds := 0.0
var _sequence_started := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_time(delta)


func start_sequence() -> void:
	_elapsed_seconds = 0.0
	_sequence_started = true
	set_process(true)
	_show_frame_at_index(0)


func advance_time(seconds: float) -> void:
	if not _sequence_started or seconds <= 0.0:
		return
	_elapsed_seconds = minf(
		_elapsed_seconds + seconds,
		TOTAL_DURATION_SECONDS
	)
	var frame_index := 0
	for index in FRAME_START_SECONDS.size():
		if _elapsed_seconds >= FRAME_START_SECONDS[index]:
			frame_index = index
	_show_frame_at_index(frame_index)
	if _elapsed_seconds >= TOTAL_DURATION_SECONDS:
		set_process(false)


func show_frame(frame_id: StringName) -> bool:
	if not FRAME_IDS.has(frame_id):
		return false
	var logical_name := StringName("%s_2x" % frame_id)
	texture = AssetLoader.get_static_texture(logical_name)
	_current_frame_id = frame_id
	visible = texture != null
	if frame_id == &"stage5_ending":
		position = Vector2.ZERO
		size = Vector2(640, 360)
	else:
		position = Vector2(0, 40)
		size = Vector2(640, 320)
	return visible


func hide_frame() -> void:
	set_process(false)
	visible = false
	_current_frame_id = &""
	_sequence_started = false


func current_frame_id() -> StringName:
	return _current_frame_id


func _show_frame_at_index(index: int) -> void:
	show_frame(FRAME_IDS[clampi(index, 0, FRAME_IDS.size() - 1)])
