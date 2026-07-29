# Shared File Ownership

Most files in this repository belong to the task that produced them, and the task
guides forbid editing a file another account owns. A few files do not fit that
rule: every account needs them changed, but no open task declares them as an
output. This document names a standing owner for each one.

Task-produced files are not listed here. Their owner is the account recorded in
`docs/coord/done/<task>.md`.

## Table O1: Standing owners

| File | Owner | Why it needs a standing owner |
|---|---|---|
| `src/project.godot` | ACCOUNT_C | Every new autoload singleton requires a line in `[autoload]`. The file was produced by T-03, which is closed, and no other task declares it as an output. Account C owns the release chain (T-38, T-39, T-40), so it is the account that most needs the project to boot and the first to notice when it does not |
| `docs/coord/OWNERSHIP.md` | ACCOUNT_C | This file |
| `src/main.tscn` | ACCOUNT_C | The boot scene, and the project's main scene. It holds `SceneRouter` and nothing else. Produced by no task; it existed as a bare placeholder that every route pointed at |
| `src/ui/title.tscn` | ACCOUNT_C | See the note below on the three runtime scenes |
| `src/game/main.tscn` | ACCOUNT_C | Same |
| `src/ui/ending.tscn` | ACCOUNT_C | Same |

`docs/coord/README.md` and the markers under `docs/coord/done/` remain with
ACCOUNT_A and with each task's own account respectively. This document does not
change either.

## The three runtime scenes

`res://ui/title.tscn`, `res://game/main.tscn`, and `res://ui/ending.tscn` are
here for the same reason `src/project.godot` is: every account needs them to
exist, and no task in any queue declares them as an output.

The gap was a deadlock rather than an oversight, and both halves of it are on
record. T-32 delivers `src/core/scene_router.gd` alone, and its marker says the
three scene paths are placeholders and that creating the scenes is "D-29's and
the integration pass's work". D-29 delivers a PixelLab description, a font plan,
and a screenshot plan, and `docs/coord/rework/D-29__from_ACCOUNT_D.open.md` says
it cannot proceed because "the title, game, and ending scenes do not exist".
Each task was waiting for the other to produce a file neither was asked to
produce.

ACCOUNT_C takes them for the reason already recorded for `src/project.godot`: it
owns the release chain, T-38 through T-40. T-38 is marked DONE only after a
complete playthrough and T-39 requires evidence of one, so the release chain
cannot finish without real scenes either. The account that most needs them is
the account that holds them.

What is owned here is structure and wiring, not appearance. The scenes carry
named nodes at the rectangles of section 2 of `docs/UI_LAYOUT.md`, engine
default styling throughout, and no texture assigned to either background slot.
The title's visual treatment, font sizing, letter spacing, pulse, and the
background image itself remain D-29's, and landing them needs no change to the
node structure.

### How the title scene reaches the router

`SceneRouter.scene_paths` now carries all three routes. The title entry is
optional: leave it empty and the title stays what T-32 delivered, a menu the
router builds under itself with no scene resident. Point it at a scene and the
router loads that scene and puts the entry buttons into whichever node inside it
carries the group `title_menu_anchor`.

That is the whole contract. A replacement title scene needs one node in that
group and nothing else.

## How to request a change to `src/project.godot`

Do not edit the file. Instead:

1. Record the exact lines your task needs in the `interface_changes` block of your
   done marker, as T-10 and T-11 both did.
2. The owner adds them in a separate commit and confirms the project still starts.

This keeps the one-production-file constraint intact: your task still delivers one
file, and the shared file changes under a single pair of hands.

## Table O2: Registered autoloads

Order matters. `Balance` is listed after `EventBus` but neither depends on the
other at load time.

| Name | Script | Registered for |
|---|---|---|
| `EventBus` | `res://autoload/event_bus.gd` | T-10 |
| `Balance` | `res://autoload/balance.gd` | T-11 |
| `SaveManager` | `res://autoload/save_manager.gd` | T-26 |
| `AudioRouter` | `res://core/audio_router.gd` | T-37 |
| `AssetLoader` | `res://core/asset_loader.gd` | T-36 |

A script that references an unregistered autoload fails at **parse** time, not at
run time, so a missing entry breaks every file that mentions it rather than only
the code path that uses it. `src/core/chapter_flow.gd` references both.

This table listed only the first two until 2026-07-28, while `src/project.godot`
had carried `SaveManager` and `AudioRouter` for some time. The table was the
thing that was wrong, not the project file, and it is corrected here rather than
elsewhere.

`AssetLoader` was registered on the same day, and it is the one entry that was
genuinely missing from both. T-36 delivered it and its own header says to
register it, but nothing had. It is required now because `art/` lives outside the
Godot project root, so no scene can reach an image through `ext_resource`; the
loader reading `res://../art` at runtime is the only route to one.

## Warning: the editor rewrites `src/project.godot`

Opening the project in the Godot editor, or running `--import`, causes Godot to
rewrite this file and silently drop any setting whose value equals the engine
default. This has already removed two settings that T-03 deliberately configured:

```ini
window/dpi/allow_hidpi=true
window/stretch/aspect="keep"
```

Both were restored. The owner must read the full `git diff` of
`src/project.godot` before committing and put back anything the editor pruned.
Never stage this file with `git add -A`.

Settings currently at risk, all owned by T-03 and listed in `docs/GODOT_SETUP.md`:
the two above, plus `window/stretch/mode`, `window/stretch/scale_mode`, and
`textures/canvas_textures/default_texture_filter`.
