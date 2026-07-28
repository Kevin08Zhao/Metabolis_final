# PixelLab 生成结果落盘流水线

本文件固定 ACCOUNT_D 从 PixelLab MCP 返回值到仓库 PNG 的唯一落盘路径。生成与落盘分离：MCP 负责产生真实 ID、状态响应、usage/cost 与 URL 或 base64；`tools/pixellab_fetch.py` 不调用生成接口，只读取已提交的 `fetch_plans/*.json`，因此自身消耗始终为 0 generation units。

## 1. Fetch plan 合同

每个任务分支提交一个 JSON plan。`source` 只接受 `url` 或 `base64`；真实 MCP 创建响应、状态响应、ID、seed 与 usage/cost 原样保留在 `generation`，缺失字段写 `UNREPORTED`，不得推测。URL 的查询串不会复制进报告；base64 不复制进报告，但 plan 保留原文，报告记录编码内容的 SHA-256。

```json
{
  "task_id": "D-06",
  "palette": "art/palette.gpl",
  "report": "docs/assets/D-06_LAND_REPORT.json",
  "manifest": "docs/assets/D-06_MANIFEST.md",
  "palette_distance_threshold": 12.0,
  "max_over_threshold_percent": 5.0,
  "items": [
    {
      "id": "style_master",
      "target": "art/reference/reference_style_master.png",
      "source": {"kind": "url", "url": "${PIXELLAB_RESULT_URL_FROM_STATUS_RESPONSE}"},
      "generation": {
        "tool": "create_image_pixflux",
        "job_id": "${PIXELLAB_JOB_ID_FROM_CREATE_RESPONSE}",
        "seed": 123,
        "usage": {"generation_units": 1},
        "create_response": "raw MCP response",
        "status_response": "raw MCP response"
      },
      "expected_size": {"width": 320, "height": 180},
      "alpha_threshold": 128,
      "operations": []
    }
  ]
}
```

Plan 必须位于 `fetch_plans/`，并且只能引用锁定的 `art/palette.gpl`。静态 PNG 的 `target` 必须位于 `art/`，且符合 `CONTEXT.md` 的 `{category}_{subject}_{variant}.png` 小写 snake_case 模板；report 与 MANIFEST 必须位于 `docs/assets/`。所有路径必须相对仓库、不得含 `..`。已存在的目标只有两种可写情况：新内容与现有文件逐字节相同；或 plan 的 `expected_existing_sha256` 精确等于现有文件哈希。其他情况一律失败，防止覆盖未知文件。

## 2. 确定性处理顺序

1. 立即读取 HTTPS URL 或解码 base64，单项上限 25 MiB，并记录字节数与 SHA-256。
2. 以 CIE76 Delta E 找到 `art/palette.gpl` 中最近的颜色；加载时必须恰好得到 22 个互不重复的色值。
3. 按 `alpha_threshold` 将 alpha 二值化为 0 或 255；完全透明像素统一为透明黑，只有可见像素参与色板验收。
4. 只执行 plan 明写的 `integer_scale`、`crop`、`nine_slice`。整数缩放只用 nearest-neighbor；九宫格固定角块并平铺边与中心，不做插值；未知操作直接失败。
5. 核对输出尺寸、文件名、透明度、色板外像素与超阈值占比，随后安全落盘 PNG。
6. 无论某项是否失败，都生成任务级 JSON report 和 Markdown MANIFEST；只要有一项失败，脚本退出码为 1。脚本永不创建 `docs/coord/done/` marker。

每项报告必须包含 `download`、`dimensions`、`transparency`、`palette`、`naming`、`source` 与 `generation`。`palette` 同时记录吸附前/后的色板外像素、距离阈值、超阈值像素与百分比；吸附后可见色板外像素必须为 0。

## 3. GitHub Action 行为

`.github/workflows/pixellab_land.yml` 仅监听非 `main` 分支的 `fetch_plans/**/*.json` 变更，也支持在任务分支手动指定单个 plan。权限只有 `contents: write`。Action 先处理全部 plan，再提交成功 PNG、所有 report 与 MANIFEST；输出提交不修改 `fetch_plans/`，所以不会递归触发。

混合结果按“保留成功、整体失败”处理：落盘步骤使用延迟失败，证据提交完成后再以非零退出码将工作流标红。待人工 VERIFY 通过后，ACCOUNT_D 才能另行创建 DONE marker；Action 对任何 `docs/coord/done/` 路径都会拒绝提交。

## 4. 本地复核命令

```text
python tools/pixellab_fetch.py land fetch_plans/D-06.json --repo-root .
python tools/pixellab_fetch.py palette-strip --palette art/palette.gpl --output art/reference/palette_strip.png
python tools/pixellab_fetch.py self-test --repo-root .
```

生产 plan 的 `max_over_threshold_percent` 必须由该任务验收标准明写；未写时脚本只报告、不以距离阻断，但吸附后色板外像素仍必须为 0。所有运行均须检查 JSON report，再检查 PNG 尺寸与透明度，最后才允许 SHIP。
