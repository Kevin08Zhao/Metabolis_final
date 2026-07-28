# PixelLab MCP Tool Snapshot

- Snapshot time: `2026-07-28T14:41:01Z`
- Source: 当前会话实际暴露的 MCP schema；不是根据任务 PDF 推测
- Exposed tools: `65`
- Return declaration: 所有工具当前声明均为 `Promise<CallToolResult>`，未声明结构化 JSON 返回 schema；因此必须保存真实原始响应，不能假设字段
- Read-only verification: `get_balance({})` 返回 `$0.00` credits、`4958` remaining、`42` used、`5000` total、active Tier 2 Pixel Artisan
- D-05a calls: 只调用 `get_balance`，生成工具调用数 `0`

## 实际工具清单

```text
agent_feedback
agent_help
agent_inspect
agent_list
agent_talk
animate_character
animate_image
animate_object
create_1_direction_object
create_8_direction_object
create_building_kit
create_character
create_character_state
create_font
create_image_pixen
create_image_pixflux
create_image_pro
create_isometric_tile
create_map_object
create_object_state
create_path_tiles
create_portrait_character
create_sidescroller_tileset
create_talking_gif
create_tiles_pro
create_topdown_tileset
create_ui_asset
create_vocal_animation
delete_animation
delete_character
delete_isometric_tile
delete_object
delete_sidescroller_tileset
delete_tiles_pro
delete_topdown_tileset
delete_ui_asset
dismiss_review
edit_image
get_balance
get_character
get_font
get_image
get_isometric_tile
get_lip_sync
get_map_object
get_object
get_portrait_character
get_sidescroller_tileset
get_tiles_pro
get_topdown_tileset
get_ui_asset
get_vocal_animation
inpaint_image
list_characters
list_isometric_tiles
list_objects
list_projects
list_sidescroller_tilesets
list_tiles_pro
list_topdown_tilesets
list_ui_assets
select_object_frames
set_character_portrait
update_character_tags
update_object_tags
```

## D 轨常用创建接口的当前参数

问号表示可选；枚举和值域仍以调用当刻 MCP schema 为准，执行每个生产任务前必须重新读取。

| 创建工具 | 当前参数键 | 创建返回与成本提示 | 状态查询 |
|---|---|---|---|
| `create_image_pixen` | `description`; `detail?`, `direction?`, `height?`, `no_background?`, `outline?`, `seed?`, `view?`, `width?` | 异步 raw-image job；工具说明为 1 generation | `get_image(job_id)` |
| `create_image_pixflux` | `description`; `color_image_base64?`, `detail?`, `direction?`, `height?`, `init_image_base64?`, `init_image_strength?`, `isometric?`, `no_background?`, `outline?`, `seed?`, `shading?`, `text_guidance_scale?`, `view?`, `width?` | 异步 raw-image job；工具说明为 1 generation | `get_image(job_id)` |
| `create_image_pro` | `description`; `height?`, `no_background?`, `reference_images?`, `seed?`, `style_copy?`, `style_image_base64?`, `width?` | 异步 raw-image job；工具说明为 20–40 generations | `get_image(job_id)` |
| `edit_image` | `images_base64`; `description?`, `height?`, `no_background?`, `reference_image_base64?`, `seed?`, `width?` | 异步 raw-image job；保存真实创建响应 | `get_image(job_id)` |
| `inpaint_image` | `description`, `image_base64`; `crop_to_mask?`, `mask_height?`, `mask_image_base64?`, `mask_width?`, `mask_x?`, `mask_y?`, `no_background?`, `seed?` | 异步 raw-image job；保存真实创建响应 | `get_image(job_id)` |
| `create_tiles_pro` | `description`; `oblique_lean?`, `outline_mode?`, `seed?`, `style_images?`, `style_options?`, `tile_depth_ratio?`, `tile_feature?`, `tile_flat_top_px?`, `tile_height?`, `tile_size?`, `tile_type?`, `tile_view?`, `tile_view_angle?` | 返回真实 `tile_id` | `get_tiles_pro(tile_id)` |
| `create_path_tiles` | `description`; `outline_mode?`, `seed?`, `tile_depth_ratio?`, `tile_size?`, `tile_type?`, `tile_view_angle?` | 返回真实 tile ID；当前 schema 明写 `square_topdown` 只能为 32 px | 对应 tile 状态查询 |
| `create_topdown_tileset` | `lower_description`, `upper_description`; `detail?`, `lower_base_tile_id?`, `mode?`, `outline?`, `raggedness?`, `shading?`, `slope_size?`, `spread_x?`, `text_guidance_scale?`, `tile_size?`, `tile_strength?`, `tileset_adherence?`, `tileset_adherence_freedom?`, `transition_description?`, `transition_size?`, `upper_base_tile_id?`, `view?` | 返回真实 `tileset_id` | `get_topdown_tileset(tileset_id)` |
| `create_ui_asset` | `description`; `color_palette?`, `elements?`, `height?`, `name?`, `no_background?`, `pieces?`, `seed?`, `width?` | 返回真实 `ui_asset_id`；工具说明为 20–40 generations | `get_ui_asset(ui_asset_id, include_preview?)` |
| `create_map_object` | `description`; `background_image?`, `detail?`, `height?`, `inpainting?`, `outline?`, `shading?`, `view?`, `width?` | 返回真实 `object_id`；状态结果有时效，须立即取回 | `get_map_object(object_id)` |

## 状态与 usage/cost 记录规则

`get_image` 的唯一参数是 `job_id`；`get_tiles_pro`、`get_topdown_tileset`、`get_ui_asset`、`get_map_object` 分别使用 `tile_id`、`tileset_id`、`ui_asset_id`、`object_id`。创建成功后立即把原始创建响应写入 fetch plan，轮询时把每次真实状态响应追加保存；完成响应中的下载 URL 或 base64 直接写进 `source`。

usage/cost 没有统一的结构化返回 schema。账本只抄录界面或真实响应出现的字段；未出现就写 `UNREPORTED`，不得用输出张数估算。D-08 的项目 tile 基线仍为 `T = 16`，所以当前要求 `square_topdown tile_size = 32` 的 `create_path_tiles` 不可直接作为 D-08 的 16 px 生产接口。
