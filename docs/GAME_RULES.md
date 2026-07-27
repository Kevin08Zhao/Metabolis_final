# 玩家动作规则表

本文定义《Metabolis：生命之城·诞生》的玩家可执行动作全集。系统只接受下表六种动作；观察状态、接收目标、资源结算、完成建造、系统协作观察、解锁科普和时间结转均为系统步骤，不是额外的玩家动作。

## 判定约定

- 每次动作请求先完整计算“前置条件”；表达式为 `true` 时原子执行消耗与效果，为 `false` 时不改变游戏状态并执行对应拒绝反馈。
- `&&` 表示逻辑与，`!` 表示逻辑非，`in` 表示集合包含，`is_subset_of` 表示左侧集合中的成员全部存在于右侧集合，`null` 表示未选择对象。
- `balance.*` 是只读平衡配置路径。表内涉及的所有可调数值均从该路径读取。
- “进入并跳过或完成小游戏”是一项完整动作事务；进入、跳过和完成不拆成额外动作。
- `selected_*` 与 `requested_*` 字段是动作请求携带的参数；玩家在同一动作界面中的选择与预览不登记为额外动作。

## 动作全集

| 动作名 | 内部动作 ID | 前置条件 | 消耗 | 立即效果 | 延迟效果 | 玩家可见反馈 | 条件不满足时的拒绝反馈 |
|---|---|---|---|---|---|---|---|
| 进入并跳过或完成小游戏 | `resolve_optional_minigame` | `(phase == Phase.MINIGAME_OPTIONAL) && (stage_minigame_id != null) && (minigame_resolution == MinigameResolution.PENDING) && (requested_minigame_result in [MinigameResult.SKIPPED, MinigameResult.COMPLETED])` | 不消耗城市资源；任务计时上限读取 `balance.minigame.time_limit`。 | 将 `minigame_resolution` 写为 `requested_minigame_result`，锁定本段任务入口并记录结算标记。 | 在 `Phase.RESOURCE_SETTLEMENT`：完成时向资源结算加入 `balance.minigame.reward.nutrient_energy`、`balance.minigame.reward.cell_material`、`balance.minigame.reward.development_signal` 与 `balance.minigame.reward.knowledge_badge_count`；跳过时不加入任务奖励。 | 顶部 `TaskPanel` 将状态改为“已完成”或“已跳过”；完成时播放 `minigame_reward_fly` 动效并播放 `sfx_minigame_complete`，跳过时播放 `minigame_panel_collapse` 动效并播放 `sfx_minigame_skip`。 | `TaskPanel` 保持展开并左右抖动，具体失败条件显示为“当前不是任务阶段”“本段没有任务”“任务已经处理”或“任务结果无效”，同时播放 `sfx_action_denied`。 |
| 做出建造决策 | `confirm_build_decision` | `(phase == Phase.BUILD_DECISION) && (active_build_decision_id != null) && (!(active_build_decision_id in confirmed_build_decision_ids)) && (selected_build_option_id in available_build_option_ids) && (selected_build_slot_id in available_build_slot_ids) && (nutrient_energy >= balance.build.cost[selected_build_option_id].nutrient_energy) && (cell_material >= balance.build.cost[selected_build_option_id].cell_material) && (development_signal >= balance.build.cost[selected_build_option_id].development_signal)` | 扣除 `balance.build.cost[selected_build_option_id].nutrient_energy`、`balance.build.cost[selected_build_option_id].cell_material`、`balance.build.cost[selected_build_option_id].development_signal`。 | 锁定当前决策的建造选项与候选槽位，生成器官蓝图，将 `active_build_decision_id` 加入 `confirmed_build_decision_ids`。确认后不可回滚。 | 建造结果在本段 `Phase.BUILD_COMPLETION` 呈现为已完成器官；功能后果在紧接的 `Phase.SYSTEM_ACTIVATION` 通过器官与运输系统协作呈现，并在推进段落时结转。 | 地图 `BuildSlotOverlay` 仅保留已选槽位并锁定确认按钮，顶部 `ResourceBar` 的三项资源读数同步扣减；播放 `organ_blueprint_construct` 动效与 `sfx_build_confirm`，完成建造时再播放 `organ_build_complete` 动效与 `sfx_build_complete`。 | 无有效选项时对应建造卡红框抖动；无有效槽位时地图槽位显示红色叉号；资源不足时 `ResourceBar` 中不足的项目红色闪烁。`BuildDecisionPanel` 同时显示具体原因并播放 `sfx_action_denied`。 |
| 做出运营决策 | `confirm_operation_decision` | `(phase == Phase.OPERATION_DECISION) && (active_operation_decision_id != null) && (!(active_operation_decision_id in confirmed_operation_decision_ids)) && (selected_operation_id in available_operation_ids) && (allocation_total == balance.operation.allocation.required_total) && (nutrient_energy >= balance.operation.cost[selected_operation_id].nutrient_energy) && (cell_material >= balance.operation.cost[selected_operation_id].cell_material) && (development_signal >= balance.operation.cost[selected_operation_id].development_signal)` | 扣除 `balance.operation.cost[selected_operation_id].nutrient_energy`、`balance.operation.cost[selected_operation_id].cell_material`、`balance.operation.cost[selected_operation_id].development_signal`。 | 锁定当前决策的资源优先级和运营方案，将 `active_operation_decision_id` 加入 `confirmed_operation_decision_ids` 并生成待结算运营结果。确认后不可回滚。 | 运营后果在紧接的 `Phase.SYSTEM_ACTIVATION` 呈现：运输压力、废物、稳定度与网络效率按 `balance.operation.outcome[selected_operation_id].*` 结算；持续状态在推进段落时结转。 | `OperationPanel` 的优先级控件锁定，顶部 `ResourceBar` 同步扣减，`CityStatusPanel` 从预测标记切换为待结算标记；播放 `operation_flow_pulse` 动效与 `sfx_operation_confirm`，系统激活时播放 `operation_result_reveal` 动效与 `sfx_operation_settle`。 | 方案无效时对应运营卡红框抖动；分配总量不符时 `AllocationMeter` 显示缺口或溢出；资源不足时 `ResourceBar` 对应项目红色闪烁。`OperationPanel` 显示具体原因并播放 `sfx_action_denied`。 |
| 干预运输网络 | `intervene_transport_network` | `(phase == Phase.OPERATION_DECISION) && (active_operation_decision_id != null) && (!(active_operation_decision_id in confirmed_operation_decision_ids)) && (transport_intervention_used == false) && (selected_transport_edge_id != null) && (selected_transport_edge_id in active_transport_edge_ids) && (selected_transport_edge_id in mutable_transport_edge_ids) && (transport_pressure >= balance.transport.intervention.unlock_pressure) && (development_signal >= balance.transport.intervention.cost.development_signal) && (disconnects_required_organs[selected_transport_edge_id] == false)` | 扣除 `balance.transport.intervention.cost.development_signal`。 | 对所选运输边应用 `transport_intervention_plan_by_edge[selected_transport_edge_id]` 中的预置备用走向，将备用边容量设为 `balance.transport.intervention.capacity`，重新计算当前路由，并将 `transport_intervention_used` 设为 `true`。 | 在本段下一次运营结果结算时，运输压力、废物生成与稳定度变化分别应用 `balance.transport.intervention.outcome.transport_pressure`、`balance.transport.intervention.outcome.waste`、`balance.transport.intervention.outcome.stability`；网络状态在推进段落时结转。 | 地图 `TransportOverlay` 高亮所选运输边并更新容量徽标，顶部 `ResourceBar` 的发育信号读数同步扣减；播放 `transport_route_reflow` 动效与 `sfx_transport_intervene`。 | 没有当前运营决策时 `OperationPanel` 显示“没有可处理的运营决策”；运营决策已经确认时干预入口显示“本轮已锁定”；已经干预时显示“本段干预已使用”。未选择或运输边不可用时，该边显示红色断线标记；压力未达条件时 `TransportPressureMeter` 标出解锁刻度；发育信号不足时对应资源读数红色闪烁；会切断必需器官时显示禁止图标。`TransportPanel` 显示具体原因并播放 `sfx_action_denied`。 |
| 查看科普档案 | `view_knowledge_archive` | `(phase != Phase.STAGE_TRANSITION) && (blocking_modal_open == false) && (selected_knowledge_entry_id != null) && (selected_knowledge_entry_id in unlocked_knowledge_entry_ids)` | 无。 | 打开所选档案详情；首次打开时将该条目的 `is_read` 设为 `true`。 | 无延迟数值效果；已读状态随存档持久化。 | `KnowledgeArchivePanel` 展开到所选条目，时间轴对应档案标记从“新”切换为“已读”；播放 `knowledge_card_unfold` 动效与 `sfx_knowledge_open`。 | 未解锁时档案卡的锁图标抖动；过渡中或存在阻塞弹窗时面板显示对应原因。拒绝提示出现于 `KnowledgeArchivePanel` 顶部并播放 `sfx_action_denied`。 |
| 推进到下一段落 | `advance_to_next_stage` | `(phase == Phase.STAGE_COMPLETE) && (required_build_decision_ids.is_subset_of(confirmed_build_decision_ids)) && (required_operation_decision_ids.is_subset_of(confirmed_operation_decision_ids)) && (system_observation_complete == true) && (knowledge_unlock_resolved == true) && (blocking_modal_open == false) && (next_stage_id != null)` | 无直接消耗；资源、网络与压力的结转比例读取 `balance.stage.carryover.*`。 | 锁定当前段落输入，生成结转快照并将流程切换到 `Phase.STAGE_TRANSITION`。 | 转场结束后加载 `next_stage_id`；资源、网络效率、运营压力与废物按 `balance.stage.carryover.*` 写入新段落，发育时间轴切换到下一节点。 | 顶部 `DevelopmentTimeline` 的当前节点移动到下一段落，`StageSummaryPanel` 展示结转项目；播放 `stage_transition_wipe` 动效与 `sfx_stage_advance`。 | `StageSummaryPanel` 将未完成的系统步骤逐项标红；存在阻塞弹窗时该弹窗边框闪烁；没有下一段落时显示“当前内容已结束”。推进按钮抖动并播放 `sfx_action_denied`。 |

## 最复杂前置条件：干预运输网络

六个动作中，`intervene_transport_network` 同时依赖流程状态、单段使用状态、玩家选择、图结构、运营指标、资源余额和平衡配置，并要求执行一次连通性校验，因此其前置条件最复杂。

```text
can_intervene_transport =
    (phase == Phase.OPERATION_DECISION)
    && (active_operation_decision_id != null)
    && (!(active_operation_decision_id in confirmed_operation_decision_ids))
    && (transport_intervention_used == false)
    && (selected_transport_edge_id != null)
    && (selected_transport_edge_id in active_transport_edge_ids)
    && (selected_transport_edge_id in mutable_transport_edge_ids)
    && (transport_pressure >= balance.transport.intervention.unlock_pressure)
    && (development_signal >= balance.transport.intervention.cost.development_signal)
    && (disconnects_required_organs[selected_transport_edge_id] == false)
```

| 子条件 | 数据来源 |
|---|---|
| `phase == Phase.OPERATION_DECISION` | `StageFlowState.phase`，由段落流程控制器维护。 |
| `active_operation_decision_id != null` | `StageFlowState.active_operation_decision_id`，来自当前段落正在处理的运营决策。 |
| `!(active_operation_decision_id in confirmed_operation_decision_ids)` | `StageActionState.confirmed_operation_decision_ids`，来自当前段落已经确认且不可回滚的运营决策集合。 |
| `transport_intervention_used == false` | `StageActionState.transport_intervention_used`，来自当前段落运行状态或读档状态。 |
| `selected_transport_edge_id != null` | `TransportPanelState.selected_transport_edge_id`，来自玩家在运输网络界面的当前选择。 |
| `selected_transport_edge_id in active_transport_edge_ids` | `TransportGraph.active_transport_edge_ids`，来自当前人体城市地图的运行时运输图。 |
| `selected_transport_edge_id in mutable_transport_edge_ids` | `TransportGraph.mutable_transport_edge_ids`，来自当前段落对运输边的可干预标记。 |
| `transport_pressure >= balance.transport.intervention.unlock_pressure` | 左值来自 `CityRuntimeStats.transport_pressure`；右值来自 `BalanceData.transport.intervention.unlock_pressure`。 |
| `development_signal >= balance.transport.intervention.cost.development_signal` | 左值来自 `ResourceState.development_signal`；右值来自 `BalanceData.transport.intervention.cost.development_signal`。 |
| `disconnects_required_organs[selected_transport_edge_id] == false` | `TransportGraphValidator.disconnects_required_organs`，由当前运输图和 `StageDefinition.required_organ_ids` 计算。 |
