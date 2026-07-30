# Godot Project Setup

> **Current state, read this first.** The reference canvas below is no longer
> the value in `src/project.godot`. Commit `fd73baf` ("feat: add connected
> body-system city maps") expanded the interface canvas from `640 x 360` to
> `800 x 450`, with the window override moving from `1280 x 720` to
> `1600 x 900`, so that controls stop covering the locked map area. The reasons
> and the layout that depends on it are recorded in
> `docs/CITY_BUILDER_REWORK_PLAN.md`, `docs/SYSTEM_MAP_MODE.md`, and
> `docs/VISUAL_COHESION_GUIDE.md`. This file was not updated at the time and
> still describes the original T-03 verification.
>
> One consequence worth knowing: `640 x 360` divided 1080p exactly at `3x`,
> while `800 x 450` does not (`1920 / 800 = 2.4`). Under
> `stretch/scale_mode = integer` a 1080p fullscreen window therefore falls back
> to `2x` at `1600 x 900` and letterboxes the remainder. Exact integer output
> scales for the current canvas are `2x` at `1600 x 900` and `3x` at
> `2400 x 1350`.
>
> Two settings in the table below, `window/dpi/allow_hidpi` and
> `window/stretch/aspect`, equal the Godot 4 engine defaults. The editor drops
> settings that match their default when it re-saves `project.godot`, so they
> disappear and reappear across commits. Their absence does not change
> behaviour.

The rest of this document records the verified T-03 configuration on Windows 11. The exact engine version is `Godot 4.7.1.stable.official.a13da4feb`, the renderer is `GL Compatibility`, and the project root is `src/`. No plugins, addons, third-party assets, or GDScript files are introduced by this setup task.

## Setup checklist

1. Start Godot `4.7.1.stable.official.a13da4feb` and import `src/project.godot` from the Project Manager.
2. Open Project Settings and set the display, stretch, DPI, texture filtering, and renderer values listed below.
3. Set the project name to `Metabolis` and the main scene to `res://main.tscn`.
4. Keep only one `Node2D` root named `Main` in the main scene and save it as `src/main.tscn`.
5. Close Project Settings, save the project, and confirm that `src/project.godot` contains the target values.
6. Press F5. A blank `1280 x 720` window must open. It displays the `640 x 360` reference canvas at an integer `2x` scale. The Output and Debugger panels must contain no script, scene, or resource errors.

`640 x 360` is the fixed reference canvas. Integer output scales are: `2x` for `1280 x 720` (720p), `3x` for `1920 x 1080` (1080p), and `6x` for `3840 x 2160` (4K).

## Project setting comparison

The "value before verification" column comes from the existing `project.godot` in this working copy. A blank value means the project previously relied on the engine default instead of storing an explicit value.

| Project Settings path | Value before verification | Target value | Reason |
|---|---|---|---|
| Application / Config / Name | `Metabolis` | `Metabolis` | Lock the display name and internal project name. |
| Application / Run / Main Scene | `res://main.tscn` | `res://main.tscn` | Let F5 run the blank main scene directly. |
| Display / Window / Size / Viewport Width | `640` | `640` | Lock the pixel-art reference canvas width. |
| Display / Window / Size / Viewport Height | `360` | `360` | Lock the pixel-art reference canvas height. |
| Display / Window / Size / Window Width Override | `1280` | `1280` | Default to integer `2x` output at 720p. |
| Display / Window / Size / Window Height Override | `720` | `720` | Default to integer `2x` output at 720p. |
| Display / Window / DPI / Allow HiDPI | blank (engine default enabled) | `true` | Use the physical pixel density while integer stretch still controls scaling. |
| Display / Window / Stretch / Mode | `canvas_items` | `canvas_items` | Scale the complete 2D canvas. |
| Display / Window / Stretch / Aspect | blank (engine default `keep`) | `keep` | Preserve the `16:9` aspect ratio without distortion. |
| Display / Window / Stretch / Scale Mode | `integer` | `integer` | Allow only integer scaling and prevent uneven pixel edges. |
| Rendering / Textures / Canvas Textures / Default Texture Filter | `Nearest` | `Nearest` | Disable linear interpolation and preserve sharp pixel edges. |
| Rendering / Renderer / Rendering Method | `gl_compatibility` | `gl_compatibility` | Support the HTML5 primary target and desktop secondary target. |
| Rendering / Renderer / Rendering Method Mobile | `gl_compatibility` | `gl_compatibility` | Keep mobile and Web on the same compatibility rendering path. |

## Expected result after opening the project

The Godot Project Manager displays `Metabolis`. After the editor opens `main.tscn`, the scene tree contains only a `Main (Node2D)` root and the 2D view contains no game objects. Pressing F5 opens a blank `1280 x 720` window titled `Metabolis`. Closing that window returns to the editor with no errors in the Debugger or Output panel.
