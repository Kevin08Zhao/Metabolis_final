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

`docs/coord/README.md` and the markers under `docs/coord/done/` remain with
ACCOUNT_A and with each task's own account respectively. This document does not
change either.

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

A script that references an unregistered autoload fails at **parse** time, not at
run time, so a missing entry breaks every file that mentions it rather than only
the code path that uses it. `src/core/chapter_flow.gd` references both.

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
