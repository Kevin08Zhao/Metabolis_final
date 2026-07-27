# 事件与信号清单

本文件是《Metabolis：生命之城·诞生》动画与音频接入游戏的**唯一挂载点**。任何动效、音效、界面反馈都只能挂在本清单定义的事件上；本清单之外的时刻不提供挂载。

事件全部来自 [`docs/GAME_RULES.md`](GAME_RULES.md) 的六个玩家动作与其立即效果、延迟效果、玩家可见反馈、拒绝反馈四列，以及 [`docs/CONTEXT.md`](CONTEXT.md) 的核心循环十步。规则表中不存在的时刻不得在此定义事件。

## 使用约定

- **命名**：遵循 `docs/CONTEXT.md` 命名规范中的「事件与信号名」一类，模板为 `{subject}_{past_tense}`，全小写 `snake_case`，描述已发生的事实，长度不超过三个词。
- **参数**：一律带完整类型标注。`StringName` 用于各类标识符，`int` 用于枚举序号与计数，`float` 用于连续量与秒数，`Dictionary` 用于键集合由下游规格定义的成组数值。
- **成组数值的键**：`spent`、`deltas`、`totals` 的键为 `docs/CONTEXT.md` 六种资源的内部变量名；`outcome`、`rating_detail`、`carryover`、`snapshot` 的键由对应下游规格定义（见每行备注），本文件不预先假定。
- **枚举**：`phase` 取 `docs/GAME_RULES.md` 中的 `Phase`；`resolution` 取 `MinigameResolution`／`MinigameResult`；`*_band` 为稳定度三档的档位序号。本文件只引用，不重新定义。
- **触发频率**列的取值只有四种：`每局一次`、`每段落一次`、`每 tick 至多一次`、`同一 tick 内可重复`。取值为 `同一 tick 内可重复` 的事件，监听方必须能处理一帧内的多次回调，动效需要排队或合并，不得假设一次结算只到达一条。
- 事件只描述「发生了什么」，不携带界面节点引用，也不规定接收方。动效列与音效列是**建议**，实现方可替换资源名，但不得改变挂载点。

---

## 一 · 段落推进与快照写入

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `stage_advanced` | `advance_to_next_stage` 前置条件成立、锁定当前段落输入并把流程切换到 `Phase.STAGE_TRANSITION` 的瞬间 | `from_stage_id: StringName`、`to_stage_id: StringName` | 每段落一次 | `stage_transition_wipe` 转场擦除；`DevelopmentTimeline` 当前节点滑向下一段落 | `sfx_stage_advance` |
| `stage_snapshot_written` | 同一动作中生成结转快照、快照落盘完成时；先于 `stage_advanced` 的转场结束 | `stage_id: StringName`、`snapshot_slot: int`、`snapshot: Dictionary`（键由 `docs/CARRYOVER_SPEC.md` 表 F2 的快照归属定义） | 每段落一次 | `StageSummaryPanel` 结转项目逐行落位 | `sfx_snapshot_write`（轻，不得盖过转场） |
| `stage_loaded` | 转场结束、`next_stage_id` 对应段落加载完毕、可玩区恢复交互时 | `stage_id: StringName`、`stage_index: int` | 每段落一次 | `stage_intro_fade` 城市图淡入 | `bgm_stage_theme` 切轨 |
| `phase_changed` | `Phase` 发生任何一次变化时；`docs/GAME_RULES.md` 全部六个动作的前置条件都以 `phase` 为首项 | `previous_phase: int`、`current_phase: int` | 每 tick 至多一次 | 无独立动效；用于关闭上一阶段面板、打开下一阶段面板 | 无 |

## 二 · 建造候选呈现、选定、建造开始、建造完成

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `build_options_presented` | 进入 `Phase.BUILD_DECISION`、`available_build_option_ids` 与 `available_build_slot_ids` 填充完毕时 | `decision_id: StringName`、`option_ids: Array[StringName]`、`slot_ids: Array[StringName]` | 每段落一次（段落一为教学章，全局共七次） | `build_card_deal` 候选卡依次展开；`BuildSlotOverlay` 候选槽位呼吸高亮 | `sfx_build_options_open` |
| `build_decision_confirmed` | `confirm_build_decision` 前置条件成立、扣除资源并锁定选项与槽位、写入 `confirmed_build_decision_ids` 的瞬间。确认后不可回滚 | `decision_id: StringName`、`option_id: StringName`、`slot_id: StringName`、`spent: Dictionary` | 每段落一次（全局七次） | `BuildSlotOverlay` 仅保留已选槽位并锁定确认按钮；`ResourceBar` 三项资源读数滚动扣减 | `sfx_build_confirm` |
| `organ_construction_started` | 器官蓝图生成、进入建造中状态时；紧随 `build_decision_confirmed` | `organ_id: StringName`、`slot_id: StringName`、`option_id: StringName` | 每段落一次（全局七次） | `organ_blueprint_construct` 蓝图逐格填充 | `sfx_build_start`（可与 `sfx_build_confirm` 合并为一次播放） |
| `organ_built` | `Phase.BUILD_COMPLETION` 中该器官由建造中转为已完成、运输网络按所选走向延伸完毕时 | `organ_id: StringName`、`slot_id: StringName`、`option_id: StringName` | 同一 tick 内可重复（同段落两个建造决策可能在同一结算 tick 完成） | `organ_build_complete` 器官定版；`transport_route_extend` 运输道路延伸 | `sfx_build_complete` |

## 三 · 运营决策提交与资源优先级变更

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `resource_priority_changed` | 玩家在 `OperationPanel` 中改动优先级分配、`allocation_total` 重算完成时。这是同一动作事务内的参数变更，不是独立玩家动作 | `decision_id: StringName`、`allocation: Dictionary`、`allocation_total: float` | 同一 tick 内可重复（连续拖动会连发） | `AllocationMeter` 指针跟随；缺口或溢出时刻度变红 | `sfx_allocation_tick`（需节流，同一 tick 只播一次） |
| `operation_decision_confirmed` | `confirm_operation_decision` 前置条件成立、扣除资源并锁定运营方案、写入 `confirmed_operation_decision_ids` 的瞬间。确认后不可回滚 | `decision_id: StringName`、`operation_id: StringName`、`spent: Dictionary` | 每段落一次（全局四次） | `operation_flow_pulse` 优先级控件锁定并沿运输网络推出一次脉冲；`CityStatusPanel` 由预测标记切为待结算标记 | `sfx_operation_confirm` |
| `transport_network_intervened` | `intervene_transport_network` 前置条件成立、备用走向生效并完成一次路由重算、`transport_intervention_used` 置为 `true` 的瞬间 | `edge_id: StringName`、`plan_id: StringName`、`capacity: float` | 每段落一次（每段落至多一次干预） | `transport_route_reflow` 所选运输边重绘并更新容量徽标；`ResourceBar` 发育信号读数扣减 | `sfx_transport_intervene` |
| `operation_result_settled` | `Phase.SYSTEM_ACTIVATION` 中运输压力、废物、稳定度与网络效率按运营结果完成结算时 | `decision_id: StringName`、`outcome: Dictionary`（键由 `docs/OPERATION_SPEC.md` 定义） | 每段落一次 | `operation_result_reveal` 城市图上逐项揭示变化 | `sfx_operation_settle` |
| `resources_settled` | `Phase.RESOURCE_SETTLEMENT` 结束、本段落可用资源（含小游戏奖励，跳过时不含）写入资源池时 | `stage_id: StringName`、`deltas: Dictionary`、`totals: Dictionary` | 每段落一次 | `resource_counter_roll` `ResourceBar` 六项读数滚动到新值 | `sfx_resource_settle` |

## 四 · 三类瓶颈的出现与解除

三类瓶颈固定为运输压力、废物累积、信号覆盖不足，与 `docs/CONTEXT.md` In scope 一节一致，不得增删。每类各有一个出现事件与一个解除事件。

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `transport_pressure_appeared` | 某条运输边的运输压力越过检测条件、该边首次被判定为瓶颈时 | `edge_id: StringName`、`severity: float` | 同一 tick 内可重复（多条边可在同一 tick 同时越线） | `TransportOverlay` 该边转为拥堵纹理并持续脉动；`TransportPressureMeter` 标出该边 | `sfx_bottleneck_transport`（同 tick 多条只播一次） |
| `transport_pressure_cleared` | 该边满足恢复判定、退出瓶颈状态时 | `edge_id: StringName` | 同一 tick 内可重复 | 拥堵纹理淡出，该边恢复常态流动 | `sfx_bottleneck_cleared` |
| `waste_buildup_appeared` | 某器官或分区的废物累积越过检测条件、首次被判定为瓶颈时 | `organ_id: StringName`、`severity: float` | 同一 tick 内可重复 | 该区域出现废物堆积图层并加深；地图标记为不依赖颜色的堆积图形 | `sfx_bottleneck_waste`（同 tick 多处只播一次） |
| `waste_buildup_cleared` | 该处满足恢复判定、废物回落到检测条件之下时 | `organ_id: StringName` | 同一 tick 内可重复 | 废物图层逐格消退 | `sfx_bottleneck_cleared` |
| `signal_gap_appeared` | 某器官或分区的信号覆盖不足越过检测条件、首次被判定为瓶颈时 | `organ_id: StringName`、`severity: float` | 同一 tick 内可重复 | 该区域信号纹理转为断续虚线并闪烁；标记为不依赖颜色的断线图形 | `sfx_bottleneck_signal`（同 tick 多处只播一次） |
| `signal_gap_cleared` | 该处满足恢复判定、覆盖恢复时 | `organ_id: StringName` | 同一 tick 内可重复 | 断续虚线接合为连续线 | `sfx_bottleneck_cleared` |

## 五 · 稳定度跨档、废物溢出、可投入资源不足

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `stability_band_changed` | 稳定度跨过界面三档中的任一分界并越过滞回幅度时。仅在档位真正改变时触发，档内变化不触发 | `previous_band: int`、`current_band: int`、`stability: float` | 每 tick 至多一次 | `ResourceBar` 稳定度控件整体换档，档位图形与文字同时变化 | 升档 `sfx_stability_up`；降档 `sfx_stability_down` |
| `waste_overflowed` | 废物达到上限、开始施加稳定度惩罚的瞬间 | `waste: float`、`stability_penalty: float` | 每 tick 至多一次 | `waste_overflow_spill` 废物读数满格并向城市图外溢出一次；稳定度控件同步下压 | `sfx_waste_overflow` |
| `resource_shortage_raised` | 营养能量、细胞材料、发育信号三种可投入资源中的某一种跌破不足提示线时 | `resource_id: StringName`、`amount: float`、`threshold: float` | 同一 tick 内可重复（三种资源可在同一 tick 同时跌破） | `ResourceBar` 该项目红色闪烁并保持低量标记 | `sfx_resource_low`（同 tick 多项只播一次） |
| `resource_shortage_cleared` | 该资源回升到不足提示线之上时 | `resource_id: StringName`、`amount: float` | 同一 tick 内可重复 | 该项目停止闪烁，低量标记移除 | 无 |

## 六 · 小游戏进入与退出、星级结算

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `minigame_entered` | `resolve_optional_minigame` 事务开始、小游戏场景取得输入焦点时 | `minigame_id: StringName`、`stage_id: StringName`、`time_limit_sec: float` | 每段落一次（全局三次，段落四无） | `minigame_panel_expand` 任务面板展开为全屏 | `sfx_minigame_enter`；主城 BGM 压低 |
| `minigame_exited` | `minigame_resolution` 由 `PENDING` 写为 `SKIPPED` 或 `COMPLETED`、本段任务入口锁定时。跳过与完成走同一事件，由 `resolution` 区分 | `minigame_id: StringName`、`resolution: int`、`elapsed_sec: float` | 每段落一次（全局三次） | 完成 `minigame_reward_fly` 奖励飞向 `ResourceBar`；跳过 `minigame_panel_collapse` 面板收起。`TaskPanel` 状态改为「已完成」或「已跳过」 | 完成 `sfx_minigame_complete`；跳过 `sfx_minigame_skip`。主城 BGM 恢复 |
| `minigame_rated` | 完成路径下评价结算完毕、星级确定时。跳过路径不触发 | `minigame_id: StringName`、`stars: int`、`rating_detail: Dictionary`（键由 `docs/MINIGAME_SPEC.md` 的评价依据定义） | 每段落至多一次（全局至多三次） | `star_stamp` 星级逐颗盖章 | `sfx_star_stamp` 按星数逐颗升调 |

## 七 · 器官档案解锁、系统协作观察、跨章结转应用

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `system_observation_started` | `Phase.SYSTEM_ACTIVATION` 中器官激活、与既有系统的一次协作演示开始时 | `organ_id: StringName`、`observation_id: StringName` | 每段落一次 | `organ_activate_glow` 器官点亮；协作路径沿运输网络逐段推进 | `sfx_organ_activate`；协作过程铺环境层 |
| `system_observation_ended` | 该次协作演示播放完毕、`system_observation_complete` 置为 `true` 时 | `organ_id: StringName`、`observation_id: StringName` | 每段落一次 | 协作路径收束，城市图恢复常态循环 | 环境层淡出 |
| `knowledge_entry_unlocked` | 对应器官档案与时间轴条目解锁、写入 `unlocked_knowledge_entry_ids` 时 | `entry_id: StringName`、`organ_id: StringName`、`stage_id: StringName` | 同一 tick 内可重复（同一段落可一次解锁多条） | 时间轴对应档案标记出现「新」角标并弹一下 | `sfx_knowledge_unlock`（同 tick 多条只播一次） |
| `knowledge_entry_opened` | `view_knowledge_archive` 前置条件成立、档案详情打开时。`first_read` 为 `true` 表示本次把 `is_read` 由假置真 | `entry_id: StringName`、`first_read: bool` | 同一 tick 内可重复 | `knowledge_card_unfold` `KnowledgeArchivePanel` 展开到该条目；「新」角标切为「已读」 | `sfx_knowledge_open` |
| `carryover_applied` | 转场结束后，网络效率、运营压力与废物累积按结转规则写入新段落起始状态时；紧随 `stage_loaded` | `from_stage_id: StringName`、`to_stage_id: StringName`、`carryover: Dictionary`（键由 `docs/CARRYOVER_SPEC.md` 表 F1 定义） | 每段落一次（段落四不产生结转，因此全局三次） | `StageSummaryPanel` 的三行结转摘要逐行推入新段落起始读数 | `sfx_carryover_apply` |

## 八 · 动作拒绝

`docs/GAME_RULES.md` 中六个动作各有一列拒绝反馈，全部以「界面元素抖动或闪烁 ＋ `sfx_action_denied`」为共同形态，区别只在于聚焦的界面元素与显示的原因文案。因此拒绝合并为一个事件，由参数区分，不为六个动作各定义一个。

| 事件名 | 触发时机 | 携带参数及类型 | 触发频率 | 建议的动效反应 | 建议的音效反应 |
|---|---|---|---|---|---|
| `action_rejected` | 六个动作中任一动作的前置条件求值为 `false`、游戏状态不发生任何改变时 | `action_id: StringName`（六个内部动作 ID 之一）、`reason_code: StringName`（对应规则表拒绝反馈中的具体原因）、`focus_element: StringName`（应当抖动或闪烁的界面元素） | 同一 tick 内可重复（连点会连发） | 由 `focus_element` 决定：卡片红框抖动、槽位红色叉号、资源项目红色闪烁、面板边框闪烁等 | `sfx_action_denied`（需节流，同一 tick 只播一次） |

---

## 已废除、不得保留的旧事件

以下四类事件属于旧版维护玩法，本清单不定义，实现方也不得自行补回：

| 旧事件类别 | 处理 |
|---|---|
| 路线手动连接 | 废除。运输网络按建造决策所选走向**自动延伸**，玩家不手动连线；仅保留每段落至多一次的 `transport_network_intervened` 干预。 |
| 供给测试 | 废除。供给结果由 `resources_settled` 与 `operation_result_settled` 直接呈现，没有独立的测试动作。 |
| 维护选择 | 废除。旧维护阶段（T-23）已作废，其位置由运营决策取代，对应事件为 `operation_decision_confirmed`。 |
| 维护延迟效果 | 废除。延迟后果统一由 `operation_result_settled` 与 `carryover_applied` 承载。 |

## 规则表反馈时刻与事件的对照

用于验收：`docs/GAME_RULES.md`「玩家可见反馈」与「拒绝反馈」两列中的每个时刻都能在本清单中找到挂载点。

| 规则表动作 | 反馈时刻 | 对应事件 |
|---|---|---|
| `resolve_optional_minigame` | 进入任务 | `minigame_entered` |
| `resolve_optional_minigame` | `TaskPanel` 改为已完成／已跳过，`minigame_reward_fly`／`minigame_panel_collapse` | `minigame_exited` |
| `resolve_optional_minigame` | 星级结算 | `minigame_rated` |
| `resolve_optional_minigame` | 奖励在资源结算阶段加入 | `resources_settled` |
| `resolve_optional_minigame` | `TaskPanel` 抖动 ＋ `sfx_action_denied` | `action_rejected` |
| `confirm_build_decision` | 候选与槽位呈现 | `build_options_presented` |
| `confirm_build_decision` | `organ_blueprint_construct` ＋ `sfx_build_confirm` | `build_decision_confirmed`、`organ_construction_started` |
| `confirm_build_decision` | `organ_build_complete` ＋ `sfx_build_complete` | `organ_built` |
| `confirm_build_decision` | 红框抖动／红色叉号／资源闪烁 | `action_rejected` |
| `confirm_operation_decision` | 优先级控件变动 | `resource_priority_changed` |
| `confirm_operation_decision` | `operation_flow_pulse` ＋ `sfx_operation_confirm` | `operation_decision_confirmed` |
| `confirm_operation_decision` | `operation_result_reveal` ＋ `sfx_operation_settle` | `operation_result_settled` |
| `confirm_operation_decision` | `AllocationMeter` 缺口或溢出、资源闪烁 | `action_rejected` |
| `intervene_transport_network` | `transport_route_reflow` ＋ `sfx_transport_intervene` | `transport_network_intervened` |
| `intervene_transport_network` | 断线标记、解锁刻度、禁止图标 | `action_rejected` |
| `view_knowledge_archive` | 档案解锁、时间轴出现新条目 | `knowledge_entry_unlocked` |
| `view_knowledge_archive` | `knowledge_card_unfold` ＋ `sfx_knowledge_open`，标记切为已读 | `knowledge_entry_opened` |
| `view_knowledge_archive` | 锁图标抖动 | `action_rejected` |
| `advance_to_next_stage` | 系统协作观察 | `system_observation_started`、`system_observation_ended` |
| `advance_to_next_stage` | 结转快照生成 | `stage_snapshot_written` |
| `advance_to_next_stage` | `stage_transition_wipe` ＋ `sfx_stage_advance`，时间轴节点移动 | `stage_advanced` |
| `advance_to_next_stage` | 下一段落加载、时间轴切换到下一节点 | `stage_loaded` |
| `advance_to_next_stage` | 结转项目写入新段落 | `carryover_applied` |
| `advance_to_next_stage` | 未完成步骤标红、推进按钮抖动 | `action_rejected` |
| 全部动作 | 阶段切换导致的面板开合 | `phase_changed` |
| 城市自身运转 | 稳定度换档、废物溢出、资源不足 | `stability_band_changed`、`waste_overflowed`、`resource_shortage_raised`／`_cleared` |
| 城市自身运转 | 三类瓶颈的出现与解除 | 第四节六个事件 |

---

## GDScript signal 声明

以下三十二行可直接粘进 `src/autoload/event_bus.gd`。参数类型完整，无省略。

```gdscript
# 一 · 段落推进与快照写入
signal stage_advanced(from_stage_id: StringName, to_stage_id: StringName)
signal stage_snapshot_written(stage_id: StringName, snapshot_slot: int, snapshot: Dictionary)
signal stage_loaded(stage_id: StringName, stage_index: int)
signal phase_changed(previous_phase: int, current_phase: int)

# 二 · 建造候选呈现、选定、建造开始、建造完成
signal build_options_presented(decision_id: StringName, option_ids: Array[StringName], slot_ids: Array[StringName])
signal build_decision_confirmed(decision_id: StringName, option_id: StringName, slot_id: StringName, spent: Dictionary)
signal organ_construction_started(organ_id: StringName, slot_id: StringName, option_id: StringName)
signal organ_built(organ_id: StringName, slot_id: StringName, option_id: StringName)

# 三 · 运营决策提交与资源优先级变更
signal resource_priority_changed(decision_id: StringName, allocation: Dictionary, allocation_total: float)
signal operation_decision_confirmed(decision_id: StringName, operation_id: StringName, spent: Dictionary)
signal transport_network_intervened(edge_id: StringName, plan_id: StringName, capacity: float)
signal operation_result_settled(decision_id: StringName, outcome: Dictionary)
signal resources_settled(stage_id: StringName, deltas: Dictionary, totals: Dictionary)

# 四 · 三类瓶颈的出现与解除
signal transport_pressure_appeared(edge_id: StringName, severity: float)
signal transport_pressure_cleared(edge_id: StringName)
signal waste_buildup_appeared(organ_id: StringName, severity: float)
signal waste_buildup_cleared(organ_id: StringName)
signal signal_gap_appeared(organ_id: StringName, severity: float)
signal signal_gap_cleared(organ_id: StringName)

# 五 · 稳定度跨档、废物溢出、可投入资源不足
signal stability_band_changed(previous_band: int, current_band: int, stability: float)
signal waste_overflowed(waste: float, stability_penalty: float)
signal resource_shortage_raised(resource_id: StringName, amount: float, threshold: float)
signal resource_shortage_cleared(resource_id: StringName, amount: float)

# 六 · 小游戏进入与退出、星级结算
signal minigame_entered(minigame_id: StringName, stage_id: StringName, time_limit_sec: float)
signal minigame_exited(minigame_id: StringName, resolution: int, elapsed_sec: float)
signal minigame_rated(minigame_id: StringName, stars: int, rating_detail: Dictionary)

# 七 · 器官档案解锁、系统协作观察、跨章结转应用
signal system_observation_started(organ_id: StringName, observation_id: StringName)
signal system_observation_ended(organ_id: StringName, observation_id: StringName)
signal knowledge_entry_unlocked(entry_id: StringName, organ_id: StringName, stage_id: StringName)
signal knowledge_entry_opened(entry_id: StringName, first_read: bool)
signal carryover_applied(from_stage_id: StringName, to_stage_id: StringName, carryover: Dictionary)

# 八 · 动作拒绝
signal action_rejected(action_id: StringName, reason_code: StringName, focus_element: StringName)
```
