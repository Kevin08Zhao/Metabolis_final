# 四段落与发育时间轴基线

本文是《Metabolis：生命之城·诞生》首个可玩版本的章节单一配置来源。章节流程状态机、发育时间轴界面、章节总结界面和施工区视觉必须读取本文锁定的四段落顺序与内容归属，不得派生第五个段落。

## 时间计算口径

游戏统一使用受精后发育时间。设 `t` 为自受精时刻起经过的周数，四段落采用以下互不重叠的区间：

| 段落 | 数学区间 | 时间轴显示文字 |
|---|---|---|
| 一·起源 | `0 ≤ t < 1` | 受精后第 1 周 |
| 二·港口 | `1 ≤ t < 3` | 受精后第 2–3 周 |
| 三·循环 | `3 ≤ t < 8` | 受精后第 4–8 周 |
| 四·诞生 | `8 ≤ t ≤ 38` | 受精后第 9–38 周，至出生 |

临床孕周通常从末次月经第一天计算，比受精后发育时间约多两周；换算口径为“临床孕周约等于受精后发育周数加两周”。这段说明固定在玩家首次进入段落一时呈现，显示于 `StageIntroPanel` 的时间说明卡和 `DevelopmentTimeline` 的时间标签下方；它是非阻塞信息，由系统随段落介绍显示，不新增玩家动作。

本文中的“本段形成”指结构第一次进入游戏地图、施工区或背景动画的表现清单，不表示该结构已达到生物学成熟状态。真实发育过程存在重叠，四段落顺序是线性教学编排，不代表所有器官严格依次开始发育。

## 固定顺序与内部标识

| 顺序 | 显示名 | `stage_id` | 第十八节内容 | `next_stage_id` |
|---:|---|---|---|---|
| 1 | 段落一·起源 | `stage_origin` | 项 1 | `stage_harbor` |
| 2 | 段落二·港口 | `stage_harbor` | 项 2、项 3 | `stage_circulation` |
| 3 | 段落三·循环 | `stage_circulation` | 项 4、项 5、项 6 | `stage_birth` |
| 4 | 段落四·诞生 | `stage_birth` | 项 7、项 8、项 9 | `null` |

## 过章判定

前三个段落共用以下可直接执行的布尔判定：

```text
stage_exit_ready(stage_id) =
    (current_stage_id == stage_id)
    && (phase == Phase.STAGE_COMPLETE)
    && (StageDefinition[stage_id].required_build_decision_ids
        .is_subset_of(confirmed_build_decision_ids))
    && (StageDefinition[stage_id].required_operation_decision_ids
        .is_subset_of(confirmed_operation_decision_ids))
    && (system_observation_complete == true)
    && (knowledge_unlock_resolved == true)
    && (blocking_modal_open == false)
```

小游戏不出现在过章判定中；玩家跳过、完成或未进入小游戏均不阻止主线推进。具体下一段落还必须满足当前 `StageDefinition.next_stage_id` 与下表目标一致。

## 段落一·起源

| 配置项 | 锁定值 |
|---|---|
| `stage_id` | `stage_origin` |
| 受精后发育时间 | `0 ≤ t < 1`；受精后第 1 周 |
| 第十八节归属 | 项 1：受精卵与细胞分裂 |
| 建造决策 | `build_cell_cluster`：胚体细胞群“生命城核心”；教学章仅此一个建造决策 |
| 运营决策 | `operate_cleavage_allocation`：细胞分裂节律与细胞材料分配优先级 |
| 小游戏 | 有；原型 A“细胞分裂”；`minigame_cell_division` |
| 本段形成的器官或结构 | 无分化器官；形成受精卵、卵裂球、桑椹胚与囊胚前体 |
| 施工区视觉 | 单一细胞扩展为紧密细胞群；被选中的候选槽位成为后续城市核心，其余候选槽位退出 |
| 进入下一段落 | `stage_exit_ready(stage_origin) && (next_stage_id == stage_harbor)` |
| 跨章结转 | 将网络效率、运营压力与废物状态结转到 `stage_harbor` |

## 段落二·港口

| 配置项 | 锁定值 |
|---|---|
| `stage_id` | `stage_harbor` |
| 受精后发育时间 | `1 ≤ t < 3`；受精后第 2–3 周 |
| 第十八节归属 | 前半段为项 2“囊胚与胎盘基础”，后半段为项 3“三胚层形成” |
| 建造决策一 | `build_placenta_port`：胎盘基础“生命港口” |
| 建造决策二 | `build_germ_layer_districts`：外胚层、中胚层、内胚层“城市功能分区” |
| 运营决策 | `operate_placental_transport`：胎盘物质运输的供给优先级 |
| 小游戏 | 有；原型 B“物质运输”；`minigame_material_transport` |
| 本段形成的器官或结构 | 胎盘基础、外胚层、中胚层、内胚层 |
| 施工区视觉 | 前半段显示囊胚定位与胎盘港口施工；后半段在同一地图节点展开三层功能分区，不创建新章节地图 |
| 进入下一段落 | `stage_exit_ready(stage_harbor) && (next_stage_id == stage_circulation)` |
| 跨章结转 | 将网络效率、运营压力与废物状态结转到 `stage_circulation` |

## 段落二的双内容承载与总结上限

段落二只有一个章节节点 `stage_harbor`，不得把三胚层形成拆成独立段落。其内部固定使用两个系统子阶段：

| 子阶段 | 时间 | 内容 | 完成标记 |
|---|---|---|---|
| `harbor_placenta_phase` | `1 ≤ t < 2`；受精后第 2 周 | 囊胚定位、胎盘基础与物质运输 | `placenta_phase_complete` |
| `harbor_germ_layers_phase` | `2 ≤ t < 3`；受精后第 3 周 | 外胚层、中胚层、内胚层形成 | `germ_layers_phase_complete` |

`StageSummaryPanel` 的段落二总结固定为以下六项，不得增加第七项：

1. 囊胚完成定位。
2. 胎盘基础“生命港口”建立。
3. 胎盘物质运输优先级的结算结果。
4. 外胚层形成。
5. 中胚层形成。
6. 内胚层形成。

绒毛、羊膜、卵黄囊、原条与各胚层后续分化等超出上述六项的内容，只能进入 `ConstructionArchive` 的施工区档案，不进入章节总结，也不在时间轴上新增节点。

## 段落三·循环

| 配置项 | 锁定值 |
|---|---|
| `stage_id` | `stage_circulation` |
| 受精后发育时间 | `3 ≤ t < 8`；受精后第 4–8 周 |
| 第十八节归属 | 项 4“心脏与早期循环”、项 5“神经系统基础”、项 6“其他器官背景动画” |
| 建造决策一 | `build_heart_pump`：心脏“中央泵站” |
| 建造决策二 | `build_neural_network`：神经管及脑、脊髓基础“信息网络” |
| 运营决策 | `operate_circulation_signal_priority`：早期循环供给与神经信号覆盖的优先级 |
| 小游戏 | 有；原型 C“信号传递”；`minigame_signal_transfer` |
| 本段形成的器官或结构 | 心脏、早期血管、神经管、脑基础、脊髓基础；肝、肾、消化道、肢芽、眼与耳原基作为背景结构 |
| 施工区视觉 | 心脏与神经网络使用可选施工槽位；血管按已选走向自动延伸；其他器官只播放背景形成动画，不提供候选与决策 |
| 进入下一段落 | `stage_exit_ready(stage_circulation) && (next_stage_id == stage_birth)` |
| 跨章结转 | 将网络效率、运营压力与废物状态结转到 `stage_birth` |

## 段落四·诞生

| 配置项 | 锁定值 |
|---|---|
| `stage_id` | `stage_birth` |
| 受精后发育时间 | `8 ≤ t ≤ 38`；受精后第 9–38 周，至出生 |
| 第十八节归属 | 项 7“肺部出生准备”、项 8“简化全身检查”、项 9“出生与第一次呼吸” |
| 建造决策一 | `build_lung_exchange`：肺部气体交换区“空气交换设施” |
| 建造决策二 | `build_pulmonary_interface`：肺循环接口“空气—运输联接” |
| 运营决策 | `operate_birth_readiness_check`：简化全身检查中的系统支持优先级 |
| 小游戏 | 无；`minigame_id = null` |
| 本段形成的器官或结构 | 肺部气体交换区、肺循环接口；既有全身器官系统进入出生前协作状态 |
| 施工区视觉 | 肺部与肺循环接口使用可选施工槽位；随后切换为全身检查覆盖层、出生转换和第一次呼吸动画 |
| 进入下一段落 | 无；`next_stage_id = null`，不得调用 `advance_to_next_stage` |
| 最终完成条件 | `final_completion_ready(stage_birth)`；满足后进入首个可玩版本结束状态，不创建第五段落 |
| 跨章结转 | 无。第 10 步只关闭本段流程并写入结局状态，不结转网络效率、运营压力、废物或其他章节快照 |

其中：

```text
final_completion_ready(stage_id) =
    (current_stage_id == stage_id)
    && (StageDefinition[stage_id].required_build_decision_ids
        .is_subset_of(confirmed_build_decision_ids))
    && (StageDefinition[stage_id].required_operation_decision_ids
        .is_subset_of(confirmed_operation_decision_ids))
    && (system_observation_complete == true)
    && (knowledge_unlock_resolved == true)
    && (blocking_modal_open == false)
    && (birth_check_passed == true)
    && (birth_transition_complete == true)
    && (first_breath_complete == true)
```

## 四处取用规则

| 取用方 | 必须读取的配置 | 禁止自行推导的内容 |
|---|---|---|
| 章节流程状态机 | `stage_id`、固定顺序、`next_stage_id`、决策 ID 集合、小游戏 ID、过章或最终完成条件、跨章结转规则 | 不得增加支线段落，不得把小游戏状态加入过章条件 |
| 发育时间轴界面 | 显示名、时间轴显示文字、第十八节内容编号；段落二只显示一个节点 | 不得把三胚层显示为第五个章节节点 |
| 章节总结界面 | 本段形成清单、决策结算结果；段落二只使用锁定的六项 | 不得把施工区档案内容扩充进段落二总结 |
| 施工区视觉 | 建造对象、候选槽位、背景形成对象、段落二两个子阶段 | 不得让背景器官成为建造或运营决策 |

## 验收表一：第十八节九项内容归属

| 项 | 内容 | 唯一段落 | 本项角色 | 对应配置 |
|---:|---|---|---|---|
| 1 | 受精卵与细胞分裂 | 段落一·起源 | 建造决策对象 | `build_cell_cluster` |
| 2 | 囊胚与胎盘基础 | 段落二·港口前半段 | 建造决策对象 | `build_placenta_port` |
| 3 | 三胚层形成 | 段落二·港口后半段 | 建造决策对象 | `build_germ_layer_districts` |
| 4 | 心脏与早期循环 | 段落三·循环 | 建造决策对象 | `build_heart_pump` |
| 5 | 神经系统基础 | 段落三·循环 | 建造决策对象 | `build_neural_network` |
| 6 | 其他器官背景动画 | 段落三·循环 | 非决策内容 | `background_organogenesis` |
| 7 | 肺部出生准备 | 段落四·诞生 | 建造决策对象 | `build_lung_exchange`、`build_pulmonary_interface` |
| 8 | 简化全身检查 | 段落四·诞生 | 运营决策对象 | `operate_birth_readiness_check` |
| 9 | 出生与第一次呼吸 | 段落四·诞生 | 非决策内容 | `birth_transition`、`first_breath` |

## 验收表二：决策与小游戏计数

| 段落 | 建造决策数 | 运营决策数 | 小游戏数 |
|---|---:|---:|---:|
| 段落一·起源 | 1 | 1 | 1 |
| 段落二·港口 | 2 | 1 | 1 |
| 段落三·循环 | 2 | 1 | 1 |
| 段落四·诞生 | 2 | 1 | 0 |
| 合计 | **7** | **4** | **3** |
