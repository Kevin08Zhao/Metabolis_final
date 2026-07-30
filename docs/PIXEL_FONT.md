# Metabolis Pixel UI Font

The interface font is generated in-repo. No third-party font binary is
vendored, so there is nothing to license or attribute.

## Source of truth

- Deterministic generator: `tools/build_pixel_font.py` (glyph pixel grids are
  written out longhand in `GLYPHS`).
- Generated atlas and descriptor: `art/fonts/metabolis_pixel_font.png` and
  `art/fonts/metabolis_pixel_font.fnt` (BMFont text format).
- Runtime wiring: `src/core/ui_theme.gd` (autoload `UiTheme`) and
  `src/ui/metabolis_pixel_theme.tres`.
- QA: `docs/assets/PIXEL_FONT_QA.json`.

Rebuild:

```bash
python tools/build_pixel_font.py --repo-root .
```

## Metrics

| Property | Value |
|---|---|
| Native size | `10` |
| Line height | `10` |
| Baseline | row `7` |
| Capitals and digits | `5 x 7`, sitting on the baseline |
| Lowercase x-height | `5 x 5`, `yoffset = 2` |
| Descenders | two rows below the baseline (`g j p q y`) |
| Coverage | all 95 printable ASCII characters, `0x20`-`0x7E` |
| Atlas | white pixels, binary alpha, one page |

The atlas carries no color of its own, so `font_color` and
`font_outline_color` fully control the rendered result. The font therefore sits
outside the 22-color contract in `art/palette.gpl`, which governs pixel art
rather than UI theme colors; the theme picks palette entries for the colors.

## Font sizes MUST be whole multiples of 10

`UiTheme` sets `fixed_size_scale_mode = FIXED_SIZE_SCALE_INTEGER_ONLY`. A
requested size that is not a multiple of the native `10` gets snapped to the
nearest whole scale factor, so the text still renders but not at the size the
layout asked for. `UiTheme.snap_font_size()` rounds a size down onto the grid.

Every panel in the game was laid out against Godot's 16px default font. The
pixel font is 6px per character at `1x` and 12px at `2x`, so `2x` runs past
those panel edges while `1x` fits with room to spare. The theme default is
therefore `10`, and a larger size has to be asked for explicitly and checked
against its container.

| Element | `font_size` | Scale |
|---|---:|---:|
| `TitleBand` | `70` | `7x` |
| Title menu buttons | `20` | `2x` |
| `system_city` map title | `20` | `2x` |
| Gameplay action title, gameplay status | `20` | `2x` |
| Everything else | `10` | `1x` |

Advance widths at native size, for layout math:

| String | Width |
|---|---:|
| `METABOLIS` | `52` |
| `BIRTH OF THE CITY OF LIFE` | `134` |
| `Body-System City Builder` | `129` |
| `Chapter Select` | `77` |

`Body-System City Builder` is the widest menu entry: `129 x 2 + 28` of button
padding is `286`, which is why `MENU_BUTTON_SIZE` in `src/ui/title_intro.gd` is
`290` wide.

## Why the theme is assembled at runtime

`art/` lives outside the Godot project root, so no `ext_resource` can reach the
font from a `.tres`. Two further Godot behaviors rule out the simpler wirings:

- A `Theme` assigned to the scene tree root does not reach a route's UI. Godot
  resolves a Control's theme by walking up Control and Window parents only, and
  every route sits under `SceneRouter` and the `SceneHost` it creates, both
  plain `Node`s, which severs that chain.
- `ThemeDB.fallback_font` is already baked into the default theme by the time an
  autoload runs, so assigning it changes nothing.

The project theme is the one lookup consulted from anywhere in the tree.
`src/ui/metabolis_pixel_theme.tres` is registered as `gui/theme/custom` and
carries only colors; `UiTheme` loads the font from `art/fonts/` at startup and
injects it into that resource. If the font file is missing, `UiTheme` warns and
every Control keeps the engine font, so the game stays playable.

The trade-off is that the Godot editor previews Controls with the default engine
font. The pixel font only appears once the project is running.

## Checking that text still fits

`src/tests/check_ui_text_fits.gd` walks the live scene tree on each route and
fails when a string is wider than the box holding it, or when a Control spills
past the 800px canvas. It also rejects any `font_size` that is not a multiple of
`10`. Wrapped and `clip_text` labels are skipped, since they degrade readably
rather than spilling.

```bash
godot --headless --path src --script res://tests/check_ui_text_fits.gd
```

Routes gated on save state, such as chapter select, quietly refuse to open; the
check reports which scene was actually resident so the coverage is not
overstated.

## Required validation after edits

1. Run the rebuild command and confirm QA status is `PASS` with
   `covers_printable_ascii: true`.
2. Run `/opt/homebrew/bin/godot --headless --path src --editor --quit` and
   confirm there are no script or resource errors.
3. Run the text-fitting check above and confirm `[UI FIT] PASS`.
4. Run the project and confirm the log contains
   `[UI THEME] pixel theme applied at native size 10`.
5. Confirm on screen that the title and menu render in the pixel font, and that
   no menu label overflows its button.
