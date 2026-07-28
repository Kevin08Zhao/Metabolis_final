# PixelLab Quota Ledger

只记录真实 MCP/界面返回值。`actual_generation_units` 未返回时写 `UNREPORTED`，不得按图片或帧数推算。

| Recorded at (UTC) | Task | Tool/action | Generation calls | Actual generation units | Account used / remaining | Evidence |
|---|---|---|---:|---:|---:|---|
| `2026-07-28T14:41:01Z` | Baseline before D-05a | `get_balance({})` | 0 | 0 | `42 / 4958` | Real MCP response: total `5000`, subscription active Tier 2 Pixel Artisan |
| `2026-07-28T14:41:01Z` | D-05a | Schema inspection, pipeline implementation, synthetic local self-test | 0 | 0 | `42 / 4958` | No create/edit/animate PixelLab tool was called |

下一项生产任务必须增加一行：任务号、真实工具名、创建调用数、响应中的 actual usage/cost、调用后余额以及对应 fetch plan/MANIFEST 路径。余额变化与任务响应冲突时停止 SHIP 并保留两份原始证据。
