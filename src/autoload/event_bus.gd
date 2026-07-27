extends Node

## EventBus · 全局事件总线单例
##
## 本文件是 docs/EVENT_API.md 在代码中的唯一映射：任意节点无需互相引用即可收发事件。
## 文件内只包含信号声明与调试辅助，不包含任何游戏逻辑。
## 信号集合必须与 docs/EVENT_API.md 完全一致，不得在此新增清单中没有的信号。
##
## 用法：
##   EventBus.stage_advanced.emit(&"stage_01_origin", &"stage_02_harbor")
##   EventBus.stage_advanced.connect(_on_stage_advanced)
##   EventBus.debug_enabled = true   # 运行时开关，开启后每次信号发出都打印 [EVENT]

# ---------------------------------------------------------------------------
# 一 · 段落推进与快照写入
# ---------------------------------------------------------------------------
signal stage_advanced(from_stage_id: StringName, to_stage_id: StringName)
signal stage_snapshot_written(stage_id: StringName, snapshot_slot: int, snapshot: Dictionary)
signal stage_loaded(stage_id: StringName, stage_index: int)
signal phase_changed(previous_phase: int, current_phase: int)

# ---------------------------------------------------------------------------
# 二 · 建造候选呈现、选定、建造开始、建造完成
# ---------------------------------------------------------------------------
signal build_options_presented(decision_id: StringName, option_ids: Array[StringName], slot_ids: Array[StringName])
signal build_decision_confirmed(decision_id: StringName, option_id: StringName, slot_id: StringName, spent: Dictionary)
signal organ_construction_started(organ_id: StringName, slot_id: StringName, option_id: StringName)
signal organ_built(organ_id: StringName, slot_id: StringName, option_id: StringName)

# ---------------------------------------------------------------------------
# 三 · 运营决策提交与资源优先级变更
# ---------------------------------------------------------------------------
signal resource_priority_changed(decision_id: StringName, allocation: Dictionary, allocation_total: float)
signal operation_decision_confirmed(decision_id: StringName, operation_id: StringName, spent: Dictionary)
signal transport_network_intervened(edge_id: StringName, plan_id: StringName, capacity: float)
signal operation_result_settled(decision_id: StringName, outcome: Dictionary)
signal resources_settled(stage_id: StringName, deltas: Dictionary, totals: Dictionary)

# ---------------------------------------------------------------------------
# 四 · 三类瓶颈的出现与解除
# ---------------------------------------------------------------------------
signal transport_pressure_appeared(edge_id: StringName, severity: float)
signal transport_pressure_cleared(edge_id: StringName)
signal waste_buildup_appeared(organ_id: StringName, severity: float)
signal waste_buildup_cleared(organ_id: StringName)
signal signal_gap_appeared(organ_id: StringName, severity: float)
signal signal_gap_cleared(organ_id: StringName)

# ---------------------------------------------------------------------------
# 五 · 稳定度跨档、废物溢出、可投入资源不足
# ---------------------------------------------------------------------------
signal stability_band_changed(previous_band: int, current_band: int, stability: float)
signal waste_overflowed(waste: float, stability_penalty: float)
signal resource_shortage_raised(resource_id: StringName, amount: float, threshold: float)
signal resource_shortage_cleared(resource_id: StringName, amount: float)

# ---------------------------------------------------------------------------
# 六 · 小游戏进入与退出、星级结算
# ---------------------------------------------------------------------------
signal minigame_entered(minigame_id: StringName, stage_id: StringName, time_limit_sec: float)
signal minigame_exited(minigame_id: StringName, resolution: int, elapsed_sec: float)
signal minigame_rated(minigame_id: StringName, stars: int, rating_detail: Dictionary)

# ---------------------------------------------------------------------------
# 七 · 器官档案解锁、系统协作观察、跨章结转应用
# ---------------------------------------------------------------------------
signal system_observation_started(organ_id: StringName, observation_id: StringName)
signal system_observation_ended(organ_id: StringName, observation_id: StringName)
signal knowledge_entry_unlocked(entry_id: StringName, organ_id: StringName, stage_id: StringName)
signal knowledge_entry_opened(entry_id: StringName, first_read: bool)
signal carryover_applied(from_stage_id: StringName, to_stage_id: StringName, carryover: Dictionary)

# ---------------------------------------------------------------------------
# 八 · 动作拒绝
# ---------------------------------------------------------------------------
signal action_rejected(action_id: StringName, reason_code: StringName, focus_element: StringName)


# ---------------------------------------------------------------------------
# 调试辅助
# ---------------------------------------------------------------------------

## 调试输出统一前缀。
const LOG_PREFIX := "[EVENT]"

## docs/EVENT_API.md 定义的全部事件名。顺序与文档一致。
## 该常量同时用于把调试记录器只挂到本清单内的信号上，避免污染 Node 自带信号。
const EVENT_NAMES := [
	&"stage_advanced",
	&"stage_snapshot_written",
	&"stage_loaded",
	&"phase_changed",
	&"build_options_presented",
	&"build_decision_confirmed",
	&"organ_construction_started",
	&"organ_built",
	&"resource_priority_changed",
	&"operation_decision_confirmed",
	&"transport_network_intervened",
	&"operation_result_settled",
	&"resources_settled",
	&"transport_pressure_appeared",
	&"transport_pressure_cleared",
	&"waste_buildup_appeared",
	&"waste_buildup_cleared",
	&"signal_gap_appeared",
	&"signal_gap_cleared",
	&"stability_band_changed",
	&"waste_overflowed",
	&"resource_shortage_raised",
	&"resource_shortage_cleared",
	&"minigame_entered",
	&"minigame_exited",
	&"minigame_rated",
	&"system_observation_started",
	&"system_observation_ended",
	&"knowledge_entry_unlocked",
	&"knowledge_entry_opened",
	&"carryover_applied",
	&"action_rejected",
]

## 运行时可随时修改的调试开关。为 true 时每次信号发出都打印一行 [EVENT]；
## 为 false 时本单例不产生任何输出。此处不使用条件编译。
var debug_enabled: bool = false


func _ready() -> void:
	_attach_debug_logger()


## 把统一的调试记录器挂到 EVENT_NAMES 中的每个信号上。
## 记录器本身不做任何游戏判断，只在 debug_enabled 为 true 时打印。
func _attach_debug_logger() -> void:
	for signal_info in get_signal_list():
		var event_name := StringName(signal_info["name"])
		if not EVENT_NAMES.has(event_name):
			continue
		var argument_count: int = (signal_info["args"] as Array).size()
		var logger := Callable(self, "_log_%d" % argument_count).bind(event_name)
		if not is_connected(event_name, logger):
			connect(event_name, logger)


## 自检：比对本脚本实际声明的信号与 EVENT_NAMES。
## 返回两个键：missing 为清单中有但脚本未声明，extra 为脚本声明但清单中没有。
## 供 T-44 冒烟测试与 docs/EVENT_API.md 变更后的复核使用。
func verify_signal_set() -> Dictionary:
	var declared: Array[StringName] = []
	for signal_info in get_signal_list():
		declared.append(StringName(signal_info["name"]))
	var missing: Array[StringName] = []
	for expected_name in EVENT_NAMES:
		if not declared.has(expected_name):
			missing.append(expected_name)
	var extra: Array[StringName] = []
	for declared_name in declared:
		if EVENT_NAMES.has(declared_name):
			continue
		if _is_builtin_signal(declared_name):
			continue
		extra.append(declared_name)
	return {"missing": missing, "extra": extra}


## Node 与 Object 自带的信号不参与自检。
func _is_builtin_signal(event_name: StringName) -> bool:
	return ClassDB.class_has_signal("Node", event_name)


func _log(event_name: StringName, arguments: Array) -> void:
	if not debug_enabled:
		return
	print(LOG_PREFIX, " ", event_name, " ", arguments)


# 按参数个数分发。绑定参数在 Godot 4 中追加在信号参数之后，
# 因此每个分发函数的最后一个形参都是事件名。
func _log_1(a0: Variant, event_name: StringName) -> void:
	_log(event_name, [a0])


func _log_2(a0: Variant, a1: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1])


func _log_3(a0: Variant, a1: Variant, a2: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1, a2])


func _log_4(a0: Variant, a1: Variant, a2: Variant, a3: Variant, event_name: StringName) -> void:
	_log(event_name, [a0, a1, a2, a3])
