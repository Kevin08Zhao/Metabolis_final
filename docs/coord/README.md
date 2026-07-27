# 仓库协调握手

本目录记录完整 Prompt 清单中已经通过验收的任务，供后续会话和自动化流程判断上游依赖是否可用。任务定义的唯一来源是 [`docs/prompts/Metabolis_Prompts_Full_v2.md`](../prompts/Metabolis_Prompts_Full_v2.md)。

## Marker 规则

- 文件名固定为 `<任务 ID>.done`，例如 `T-01.done`。
- 只有任务产物存在且通过对应条目的验收方法后，才能创建 marker。
- marker 内记录任务 ID、状态、验收依据、产物与检查结论。
- 上游产物发生实质修改后，原 marker 视为失效；必须按源 Prompt 重新验收并更新 marker。
- marker 只表示该任务已验收，不表示其下游任务已经完成。

## 当前已验收任务

| 任务 | 已验收产物 | Marker |
|---|---|---|
| T-01 · 空仓库初始化与目录结构 | 约定目录及空 `.gitkeep`、`.gitignore`、`README.md` | [`T-01.done`](T-01.done) |
| T-02 · CONTEXT.md 项目基准文档 | `docs/CONTEXT.md` | [`T-02.done`](T-02.done) |
| T-05 · GAME_RULES.md 玩法规则规格 | `docs/GAME_RULES.md` | [`T-05.done`](T-05.done) |
