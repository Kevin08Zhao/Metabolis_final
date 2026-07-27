# 建造决策候选方案规格

本文是七个建造决策候选、预览量纲、槽位输入、提交结算和科学映射的单一规格来源。候选只表达正常发育过程中的建造顺序、规格档位、槽位与资源配比差异；它们不是疾病分级，也不表示玩家能够改变真实人体的器官位置或左右轴。

所有可调数值均通过 `balance.build_options.*` 读取。本文只定义配置路径、计算关系和必须成立的不等式，不写入平衡常数。网格固定值由 `docs/GRID_BASELINE.md` 管理，段落与决策 ID 由 `docs/CHAPTER_TIMELINE.md` 管理。

## 表 D1：七个建造决策与下游接口

| `build_decision_id` | `stage_id` | 建造对象 | 候选来源 | 规格档位 | T-12 | T-13 | T-13a | T-15 | T-15a | T-19h | T-33a | D-13b | D-19a | T-35 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `build_cell_cluster` | `stage_origin` | 胚体细胞群 | 压实节律与资源配比 | `cluster_compact`、`cluster_wave` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_placenta_port` | `stage_harbor` | 胎盘基础 | 接口规格与资源配比 | `placenta_exchange`、`placenta_interface` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_germ_layer_districts` | `stage_harbor` | 三胚层功能分区 | 建造顺序与资源配比 | `layers_parallel`、`layers_staged` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_heart_pump` | `stage_circulation` | 心脏中央泵站 | 规格档位与资源配比 | `heart_reinforced`、`heart_early_flow` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_neural_network` | `stage_circulation` | 神经管及脑、脊髓基础 | 建造顺序与资源配比 | `neural_cranial`、`neural_distributed` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_lung_exchange` | `stage_birth` | 肺部气体交换区 | 规格档位与资源配比 | `lung_branching`、`lung_maturation` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |
| `build_pulmonary_interface` | `stage_birth` | 肺循环接口 | 建造顺序与接口规格 | `pulmonary_reserve`、`pulmonary_transition` | D3 | D4 | D8 | D5 | D5 | D6 | D7 | D8 | D9 | D9 |

下游必须按上表指定编号读取，不得复制全文后自行重命名字段。

## 表 D2：候选清单与硬差异

| 决策 | `build_option_id` | 允许的差异 | 玩家承担的取舍 | `slot_candidates` | `cost` |
|---|---|---|---|---|---|
| `build_cell_cluster` | `cluster_compact` | 规格档位、资源配比 | 更完整的早期连接换取更长施工 | `balance.build_options.build_cell_cluster.cluster_compact.slot_candidates` | `balance.build_options.build_cell_cluster.cluster_compact.cost` |
| `build_cell_cluster` | `cluster_wave` | 建造顺序、资源配比 | 更快展开换取较低的初始连接密度 | `balance.build_options.build_cell_cluster.cluster_wave.slot_candidates` | `balance.build_options.build_cell_cluster.cluster_wave.cost` |
| `build_placenta_port` | `placenta_exchange` | 规格档位、资源配比 | 更强交换主干换取更长成形时间 | `balance.build_options.build_placenta_port.placenta_exchange.slot_candidates` | `balance.build_options.build_placenta_port.placenta_exchange.cost` |
| `build_placenta_port` | `placenta_interface` | 建造顺序、资源配比 | 更早建立母胎接口换取较低初始吞吐 | `balance.build_options.build_placenta_port.placenta_interface.slot_candidates` | `balance.build_options.build_placenta_port.placenta_interface.cost` |
| `build_germ_layer_districts` | `layers_parallel` | 建造顺序、资源配比 | 同步分区提高互联，施工周期较长 | `balance.build_options.build_germ_layer_districts.layers_parallel.slot_candidates` | `balance.build_options.build_germ_layer_districts.layers_parallel.cost` |
| `build_germ_layer_districts` | `layers_staged` | 建造顺序、资源配比 | 分阶段成形更快，后续需要更多跨区连接 | `balance.build_options.build_germ_layer_districts.layers_staged.slot_candidates` | `balance.build_options.build_germ_layer_districts.layers_staged.cost` |
| `build_heart_pump` | `heart_reinforced` | 规格档位、资源配比 | 更强泵站接口换取更长施工 | `balance.build_options.build_heart_pump.heart_reinforced.slot_candidates` | `balance.build_options.build_heart_pump.heart_reinforced.cost` |
| `build_heart_pump` | `heart_early_flow` | 建造顺序、资源配比 | 更早形成流动换取较低初始余量 | `balance.build_options.build_heart_pump.heart_early_flow.slot_candidates` | `balance.build_options.build_heart_pump.heart_early_flow.cost` |
| `build_neural_network` | `neural_cranial` | 建造顺序、资源配比 | 优先头端信号覆盖，躯干延伸稍后补齐 | `balance.build_options.build_neural_network.neural_cranial.slot_candidates` | `balance.build_options.build_neural_network.neural_cranial.cost` |
| `build_neural_network` | `neural_distributed` | 建造顺序、资源配比 | 分布式闭合提高后续接入便利，初始主干效率较低 | `balance.build_options.build_neural_network.neural_distributed.slot_candidates` | `balance.build_options.build_neural_network.neural_distributed.cost` |
| `build_lung_exchange` | `lung_branching` | 规格档位、资源配比 | 优先分支覆盖，成熟支持稍后补齐 | `balance.build_options.build_lung_exchange.lung_branching.slot_candidates` | `balance.build_options.build_lung_exchange.lung_branching.cost` |
| `build_lung_exchange` | `lung_maturation` | 建造顺序、资源配比 | 优先交换区成熟，初始分支覆盖较低 | `balance.build_options.build_lung_exchange.lung_maturation.slot_candidates` | `balance.build_options.build_lung_exchange.lung_maturation.cost` |
| `build_pulmonary_interface` | `pulmonary_reserve` | 接口规格、资源配比 | 较高出生转换余量换取更长施工 | `balance.build_options.build_pulmonary_interface.pulmonary_reserve.slot_candidates` | `balance.build_options.build_pulmonary_interface.pulmonary_reserve.cost` |
| `build_pulmonary_interface` | `pulmonary_transition` | 建造顺序、资源配比 | 更快联通肺循环，后续扩容需求更高 | `balance.build_options.build_pulmonary_interface.pulmonary_transition.slot_candidates` | `balance.build_options.build_pulmonary_interface.pulmonary_transition.cost` |

## 表 D3：候选槽位坐标集与格子三态

| 输入或状态 | 唯一数据源 | 可执行规则 |
|---|---|---|
| 候选左上角坐标集 | `balance.build_options.<decision_id>.<option_id>.slot_candidates` | 每个元素为 `Vector2i(column, row)`；集合必须已经通过边界、占地和候选间距校验。 |
| 占地规格 | `balance.build_options.<decision_id>.<option_id>.footprint_id` | `standard_building` 映射到网格基线的标准建造物占地；`landmark_organ` 映射到地标器官占地。 |
| `UNAVAILABLE` | 运行时阻挡图、边界与已占用集合 | 候选占地越界、与 `occupied_cells` 相交、与 `blocked_cells` 相交，或候选之间未满足网格基线最小间距时成立。 |
| `CANDIDATE` | 当前决策的合法槽位集合 | 格子属于当前 `selected_build_option_id` 的某个完整合法占地，且不属于 `occupied_cells`。 |
| `OCCUPIED` | `occupied_cells` | 已确认建造的完整占地；优先级高于候选高亮。 |
| 状态优先级 | 固定判定顺序 | `OCCUPIED` 覆盖 `CANDIDATE`，`UNAVAILABLE` 覆盖未确认的候选；同一格不得同时渲染多态。 |

坐标展开规则：

```text
candidate_cells(slot, footprint_id) =
    all_grid_cells_covered_by(slot, GridBaseline[footprint_id])

available_build_slot_ids =
    slots where every cell in candidate_cells is in bounds
    && candidate_cells does not intersect occupied_cells
    && candidate_cells does not intersect blocked_cells
    && spacing_is_valid(slot, sibling_candidate_slots)
```

## 表 D4：选定、投入结算与不可回滚

| 步骤 | 规则 |
|---|---|
| 选定 | `selected_build_option_id` 必须属于 `available_build_option_ids`；`selected_build_slot_id` 必须属于该选项的 `available_build_slot_ids`。预览不修改资源和占地。 |
| 成本读取 | `selected_cost = balance.build_options.<decision_id>.<option_id>.cost`，字段固定为 `nutrient_energy`、`cell_material`、`development_signal`。 |
| 可提交 | 三种当前资源分别不低于 `selected_cost`，当前阶段为 `Phase.BUILD_DECISION`，且 `decision_id` 未进入 `confirmed_build_decision_ids`。 |
| 原子扣除 | `resource_after.<resource> = resource_before.<resource> - selected_cost.<resource>`；任一前置条件失败时三项均不改变。 |
| 锁定 | 将选项、槽位、成本快照和预览快照写入 `ConfirmedBuildDecision`，再把 `decision_id` 加入 `confirmed_build_decision_ids`。 |
| 不可回滚 | 确认后禁用选项、槽位和再次提交入口；读档只恢复确认快照，不重新计算当时成本，不提供撤销、拆除或重选动作。 |
| 防重复 | 若 `decision_id in confirmed_build_decision_ids`，请求返回 `already_confirmed`，不得再次扣除资源或生成蓝图。 |

## 表 D5：运输主干映射与网络延伸输入

| 决策 | 起点 | 终点 | 主干走向 | T-15a 延伸输入 |
|---|---|---|---|---|
| `build_cell_cluster` | `balance.build_options.build_cell_cluster.<option_id>.network.start_anchor` | `balance.build_options.build_cell_cluster.<option_id>.network.end_anchor` | `balance.build_options.build_cell_cluster.<option_id>.network.trunk_route_id` | `extension_profile_id`、`spec_tier_id`、`network_capacity`、`extension_length` |
| `build_placenta_port` | `balance.build_options.build_placenta_port.<option_id>.network.start_anchor` | `balance.build_options.build_placenta_port.<option_id>.network.end_anchor` | `balance.build_options.build_placenta_port.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |
| `build_germ_layer_districts` | `balance.build_options.build_germ_layer_districts.<option_id>.network.start_anchor` | `balance.build_options.build_germ_layer_districts.<option_id>.network.end_anchor` | `balance.build_options.build_germ_layer_districts.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |
| `build_heart_pump` | `balance.build_options.build_heart_pump.<option_id>.network.start_anchor` | `balance.build_options.build_heart_pump.<option_id>.network.end_anchor` | `balance.build_options.build_heart_pump.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |
| `build_neural_network` | `balance.build_options.build_neural_network.<option_id>.network.start_anchor` | `balance.build_options.build_neural_network.<option_id>.network.end_anchor` | `balance.build_options.build_neural_network.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |
| `build_lung_exchange` | `balance.build_options.build_lung_exchange.<option_id>.network.start_anchor` | `balance.build_options.build_lung_exchange.<option_id>.network.end_anchor` | `balance.build_options.build_lung_exchange.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |
| `build_pulmonary_interface` | `balance.build_options.build_pulmonary_interface.<option_id>.network.start_anchor` | `balance.build_options.build_pulmonary_interface.<option_id>.network.end_anchor` | `balance.build_options.build_pulmonary_interface.<option_id>.network.trunk_route_id` | 同上，路径位于本候选 `network.*` |

`extension_length` 必须读取 `balance.build_options.<decision_id>.<option_id>.network.extension_length_by_spec.<spec_tier_id>`。T-15a 以确定性的 `trunk_route_id`、起止锚点、容量和延伸长度生成节点与边；不得从显示名称、精灵位置或随机数推断走向。

## 表 D6：后续便利度与跨段落结转

| 输出 | 公式 |
|---|---|
| 候选便利度原值 | `convenience_raw = balance.build_options.<decision_id>.<option_id>.metrics.future_convenience` |
| 便利度归一化 | `convenience_norm = normalize_benefit(convenience_raw, balance.build_options.metric_ranges.future_convenience)` |
| 决策便利度贡献 | `decision_convenience = convenience_norm * balance.build_options.<decision_id>.<option_id>.carryover.convenience_weight` |
| 段落便利度 | `stage_convenience = weighted_mean(confirmed decision_convenience, balance.build_options.carryover.decision_weights)` |
| 网络效率结转修正 | `network_efficiency_delta = stage_convenience * balance.build_options.carryover.network_efficiency_factor` |
| 初始运营压力修正 | `operation_pressure_delta = (balance.build_options.normalized_max - stage_convenience) * balance.build_options.carryover.operation_pressure_factor` |
| 初始废物修正 | `waste_delta = (balance.build_options.normalized_max - stage_convenience) * balance.build_options.carryover.waste_factor` |

T-19h 只把上述三个修正量交给跨章结转层；资源保留比例与最终钳制仍由 `balance.stage.carryover.*` 负责，避免重复结算。

## 表 D7：三级提示边界

| 提示级别 | 可以说 | 不可以说 |
|---|---|---|
| `hint_observe` | 指出三个具体数字分别代表连接效率、预计施工时长和后续接入便利度；提醒查看资源成本。 | 不得出现“推荐”“最佳”“更优”“应该选”或任何候选排序。 |
| `hint_compare` | 指出两个候选在哪些维度存在方向相反的取舍，并解释高值或低值的含义。 | 不得替玩家计算总分，不得隐藏劣势，不得把科学映射描述成成功率。 |
| `hint_consequence` | 描述某类取舍可能在后续造成运输压力、扩容需求或更长施工，但不点名选项。 | 不得直接报出候选 ID，不得高亮确认按钮，不得声称某候选能够避免失败。 |

通用文案规则：提示只能复述已显示的数值、公式语义和因果方向；不显示等权和 `S`，不暴露验证容差，不根据玩家历史替换候选顺序。

## 表 D8：三个预估维度、量纲与归一化

| 维度 | 配置路径 | 量纲与单位 | 方向 | 极值范围 | 归一化公式 | 卡片显示 |
|---|---|---|---|---|---|---|
| 网络效率 | `balance.build_options.<decision_id>.<option_id>.metrics.network_efficiency` | 连续效率量；显示单位读取 `balance.build_options.metric_units.network_efficiency` | 越高越有利 | `balance.build_options.metric_ranges.network_efficiency.min` 至 `.max` | `N = (value - min) / (max - min)` | 具体原值、单位、按范围绘制的对比条 |
| 建造耗时 | `balance.build_options.<decision_id>.<option_id>.metrics.build_duration` | 发育时间量；显示单位读取 `balance.build_options.metric_units.build_duration` | 越低越有利 | `balance.build_options.metric_ranges.build_duration.min` 至 `.max` | `T = (max - value) / (max - min)` | 具体原值、单位、按反向范围绘制的对比条 |
| 后续便利度 | `balance.build_options.<decision_id>.<option_id>.metrics.future_convenience` | 连续便利量；显示单位读取 `balance.build_options.metric_units.future_convenience` | 越高越有利 | `balance.build_options.metric_ranges.future_convenience.min` 至 `.max` | `C = (value - min) / (max - min)` | 具体原值、单位、按范围绘制的对比条 |
| 等权和 | 运行时派生，不写入候选配置 | 无单位内部校验量 | 仅用于规格验收 | `balance.build_options.normalized_min` 至 `balance.build_options.normalized_sum_max` | `S = N + T + C` | 不向玩家显示 |

归一化前必须验证 `max > min`，归一化后按 `balance.build_options.normalized_min` 与 `balance.build_options.normalized_max` 钳制。等权和平衡条件固定写为：

```text
abs(S_i - S_j)
    <= balance.build_options.validation.equal_weight_tolerance * max(S_i, S_j)
```

`balance.build_options.validation.equal_weight_tolerance` 在 T-06 中写入 Prompt 冻结的容差，T-05d 不重复裸写平衡常数。

## 表 D9：规格动效与科学审校映射

| 决策与候选 | 动效规格档位 | 必须区分的完成表现 | 真实发育过程映射 | 审校来源 |
|---|---|---|---|---|
| `cluster_compact` | `reinforced` | 细胞接触面收紧后整体点亮 | 人胚压实依赖细胞收缩和黏附，个体间可表现不同压实节律；游戏只映射节律与力学取舍 | Firmin et al., *Nature*，DOI `10.1038/s41586-024-07351-x` |
| `cluster_wave` | `baseline` | 点亮从局部接触面向外传播 | 同一压实过程的时序表达，不表示不完全压实 | 同上 |
| `placenta_exchange` | `reinforced` | 绒毛交换主干先完成并产生脉冲 | 胎盘形成包含滋养层分化、绒毛与母胎交换界面建立 | Turco & Moffett, *Development*，PMID `31049600` |
| `placenta_interface` | `baseline` | 母胎接触边界先闭合，再连接交换主干 | 着床包含定位、黏附、滋养层分化和界面建立的协调过程 | Huang et al., *Front Cell Dev Biol*，DOI `10.3389/fcell.2023.1200330` |
| `layers_parallel` | `extended` | 三层轮廓同步展开后连通 | 原肠形成把细胞组织为外、中、内三个胚层，形态变化与细胞分化相互协调 | Tyser, *Semin Cell Dev Biol*，DOI `10.1016/j.semcdb.2022.05.004` |
| `layers_staged` | `baseline` | 三层依次展开，最后补跨层连接 | 仅映射教学中的成形时序差异，三层均必须完成 | 同上 |
| `heart_reinforced` | `reinforced` | 心管弯曲、泵动与接口环依次完成 | 人胚心管在发育中弯曲、延长并重塑，基础布局在连续阶段建立 | Hikspoors et al., *J Anat*，PMID `35277594` |
| `heart_early_flow` | `baseline` | 泵动先出现，接口环随后补齐 | 人胚心脏在受精后早期开始泵动；游戏不把提前显示解释为改变真实起搏时间 | Männer, *J Cardiovasc Dev Dis*，DOI `10.3390/jcdd9060187` |
| `neural_cranial` | `extended` | 头端折叠先闭合，信号向躯干传播 | 神经管闭合涉及会聚延伸、顶端收缩等协调机制；人类闭合顺序仍存在研究讨论 | Nikolopoulou et al., *Development*，PMID `28196803` |
| `neural_distributed` | `baseline` | 多段闭合光点汇合为连续主干 | 仅映射闭合过程的空间协调，不主张某一人类多起始点模型为定论 | Greene & Copp, *J Pathol*，PMID `23790957` |
| `lung_branching` | `extended` | 支气管树先分支，再点亮交换末端 | 肺发育依靠受信号调控的分支形态发生 | Morrisey & Hogan, *Dev Cell*，PMID `24449833` |
| `lung_maturation` | `reinforced` | 交换末端先出现成熟脉冲，再补分支覆盖 | 肺上皮、间质与发育阶段协调生成交换结构 | 同上 |
| `pulmonary_reserve` | `reinforced` | 肺血管接口扩展并显示较宽容量环 | 胎儿肺血管随发育建立，对出生后阻力下降和血流增加作准备 | Gao & Raj, *Physiol Rev*，PMID `27942377` |
| `pulmonary_transition` | `baseline` | 接口快速连通，随后显示待扩容标记 | 第一次呼吸后肺血管阻力下降、肺血流增加；候选只映射准备策略 | Holmes et al., *Clin Perinatol*，DOI `10.1016/j.clp.2023.11.003` |

动效只区分 `baseline`、`extended`、`reinforced` 三个规格 ID；颜色不是唯一差异，必须同时改变轮廓阶段、脉冲节律或容量环形状。

## 表 D10：四种允许差异的形态边界

| 差异维度 | 三个允许形态示例 | 三个禁止形态示例 |
|---|---|---|
| 建造顺序 | 先建立主干再补接口；先形成交换末端再补分支；同步铺开分区后统一连通 | 跳过必需结构；把后续段落器官提前建成；用失败或畸形替代较慢顺序 |
| 规格档位 | 基础主干与强化主干；标准容量与预留容量；基础覆盖与扩展覆盖 | 缺失必需器官；左右轴反转；把异常闭合、异常着床或畸形当作可选档位 |
| 槽位 | 同一解剖区域内满足边界的候选施工格；同一路径走廊内的相邻合法锚点；不改变器官拓扑关系的显示偏移 | 心脏放到头部；肺部放到盆腔；胎盘接口放到胚体内部并脱离母胎界面 |
| 资源配比 | 营养能量偏高且材料较低；细胞材料偏高且耗时较长；发育信号偏高且后续接入较方便 | 零成本候选；用废物或稳定度直接支付建造；资源更少且三个预估维度全部更优 |

解剖学删除规则：候选若改变必需器官身份、正常拓扑、左右轴、段落归属，或把病理状态包装成优势，必须在进入 D11 前删除。科学映射只解释正常过程的时序与工程类比，不用于预测妊娠结局。

## 表 D11：无严格劣势与等权和平衡验证矩阵

以下每行是一个决策的完整候选对。`A 优于 B` 与 `B 优于 A` 至少各有一个维度，因此不存在严格劣势；最终数值写入 BALANCE 时还必须使最后一列为 `true`。若任一条件失败，删除或重构候选，不得只改提示文案。

| 决策 | 候选 A | 候选 B | A 优于 B 的维度 | B 优于 A 的维度 | 三维同向比较结论 | 删除标记 | 归一化等权和 `S` | `abs(S_A-S_B)` 与容差结论 |
|---|---|---|---|---|---|---|---|---|
| `build_cell_cluster` | `cluster_compact` | `cluster_wave` | `network_efficiency` | `build_duration`、`future_convenience` | 双向各有优势，无严格支配 | `KEEP_BOTH` | `S_A=N_A+T_A+C_A`；`S_B=N_B+T_B+C_B` | `abs(S_A-S_B) <= balance.build_options.validation.equal_weight_tolerance * max(S_A,S_B)` 必须为 `true` |
| `build_placenta_port` | `placenta_exchange` | `placenta_interface` | `network_efficiency` | `build_duration`、`future_convenience` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |
| `build_germ_layer_districts` | `layers_parallel` | `layers_staged` | `network_efficiency` | `build_duration`、`future_convenience` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |
| `build_heart_pump` | `heart_reinforced` | `heart_early_flow` | `network_efficiency` | `build_duration`、`future_convenience` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |
| `build_neural_network` | `neural_cranial` | `neural_distributed` | `network_efficiency` | `build_duration`、`future_convenience` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |
| `build_lung_exchange` | `lung_branching` | `lung_maturation` | `network_efficiency`、`future_convenience` | `build_duration` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |
| `build_pulmonary_interface` | `pulmonary_reserve` | `pulmonary_transition` | `network_efficiency`、`future_convenience` | `build_duration` | 双向各有优势，无严格支配 | `KEEP_BOTH` | 同表 D8 逐项归一化后求和 | 同一验证表达式必须为 `true` |

可执行验证方法：

```text
for each decision:
    for each unordered option pair (a, b):
        a_scores = normalized_benefit_scores(a, TableD8)
        b_scores = normalized_benefit_scores(b, TableD8)

        a_dominates_b =
            all(a_scores[d] >= b_scores[d] for every dimension d)
            && any(a_scores[d] > b_scores[d] for any dimension d)

        b_dominates_a =
            all(b_scores[d] >= a_scores[d] for every dimension d)
            && any(b_scores[d] > a_scores[d] for any dimension d)

        S_a = sum(a_scores)
        S_b = sum(b_scores)
        balanced =
            abs(S_a - S_b)
            <= balance.build_options.validation.equal_weight_tolerance
               * max(S_a, S_b)

        assert a_dominates_b == false
        assert b_dominates_a == false
        assert balanced == true
```

T-06 写入实际 BALANCE 后必须重新运行该验证。任何候选出现全维度严格劣势，直接删除并同步更新 D1、D2、D5、D9 与 D11；任何候选对只违反等权和平衡条件，必须重构其资源配比或规格档位，不能通过改变归一化权重掩盖。
