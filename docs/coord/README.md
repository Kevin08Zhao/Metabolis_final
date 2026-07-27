# 仓库协调握手

本目录记录完整 Prompt 清单中已经通过验收的任务，供后续会话和自动化流程判断上游依赖是否可用。任务定义的唯一来源是 [`docs/prompts/Metabolis_Prompts_Full_v2.md`](../prompts/Metabolis_Prompts_Full_v2.md)。

## Marker 规则

- A-00 握手阶段创建的 marker 保留为 `<任务 ID>.done`，例如 `T-01.done`。
- 并行开发阶段的 marker 固定为 `done/<任务 ID>.md`，例如 `done/T-03.md`；新增任务使用此格式。
- 只有任务产物存在且通过对应条目的验收方法后，才能创建 marker。
- marker 内记录任务 ID、状态、验收依据、产物与检查结论。
- 上游产物发生实质修改后，原 marker 视为失效；必须按源 Prompt 重新验收并更新 marker。
- marker 只表示该任务已验收，不表示其下游任务已经完成。

## 当前已验收任务

| 任务 | 已验收产物 | Marker |
|---|---|---|
| T-01 · 空仓库初始化与目录结构 | 约定目录及空 `.gitkeep`、`.gitignore`、`README.md` | [`T-01.done`](T-01.done) |
| T-02 · CONTEXT.md 项目基准文档 | `docs/CONTEXT.md` | [`T-02.done`](T-02.done) |
| T-03 · Godot 4 工程创建与项目设置 | `src/project.godot`、`docs/GODOT_SETUP.md` | [`done/T-03.md`](done/T-03.md) |
| T-04 · 网格尺寸、坐标系与 tile 像素基线 | `docs/GRID_BASELINE.md` | [`done/T-04.md`](done/T-04.md) |
| T-05 · GAME_RULES.md 玩法规则规格 | `docs/GAME_RULES.md` | [`T-05.done`](T-05.done) |
| T-05a · 章节与发育时间轴定义 | `docs/CHAPTER_TIMELINE.md` | [`done/T-05a.md`](done/T-05a.md) |
