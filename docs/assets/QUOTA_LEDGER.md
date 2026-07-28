# PixelLab Quota Ledger

只记录真实 MCP/界面返回值。`actual_generation_units` 未返回时写 `UNREPORTED`，不得按图片或帧数推算。

| Recorded at (UTC) | Task | Tool/action | Generation calls | Actual generation units | Account used / remaining | Evidence |
|---|---|---|---:|---:|---:|---|
| `2026-07-28T14:41:01Z` | Baseline before D-05a | `get_balance({})` | 0 | 0 | `42 / 4958` | Real MCP response: total `5000`, subscription active Tier 2 Pixel Artisan |
| `2026-07-28T14:41:01Z` | D-05a | Schema inspection, pipeline implementation, synthetic local self-test | 0 | 0 | `42 / 4958` | No create/edit/animate PixelLab tool was called |
| `2026-07-28T15:13:16Z` | D-06 v3.1 candidate 01 | `create_image_pixflux` | 1 | 1 | `43 / 4957` | Job `b8352901-07c5-4b6a-b2ac-7165dd3061fa`; create response states `cost: 1 generation`; balance delta matches; rejected plan archived at `docs/assets/candidates/D-06_candidate_01_fetch_plan_rejected.json`, with index in `docs/assets/D-06_CANDIDATE_01_RECORD.json` |
| `2026-07-28T15:22:49Z` | D-06 v3.1 candidate 02 | `create_image_pixflux` with init image and forced palette | 1 | 1 | `44 / 4956` | Job `d6503641-d854-4439-a1e9-ff1fed9ff071`; create response states `cost: 1 generation`; delayed balance recheck confirms a one-unit delta; non-selected plan archived at `docs/assets/candidates/D-06_candidate_02_fetch_plan_not_selected.json`, with index in `docs/assets/D-06_CANDIDATE_02_RECORD.json` |
| `2026-07-28T15:36:19Z` | D-06 v3.1 candidate 03 | `create_image_pixflux` with weak init image and forced palette | 1 | 1 | `45 / 4955` | Job `d4c436c3-ed45-4490-92f0-749a2b87d9b2`; create response states `cost: 1 generation`; balance delta matches; active evidence in `fetch_plans/D-06_fetch_plan.json` and `docs/assets/D-06_CANDIDATE_03_RECORD.json` |

下一项生产任务必须增加一行：任务号、真实工具名、创建调用数、响应中的 actual usage/cost、调用后余额以及对应 fetch plan/MANIFEST 路径。余额变化与任务响应冲突时停止 SHIP 并保留两份原始证据。
