# Metabolis Desktop Export and Packaging Runbook

This runbook is locked to **Godot 4.7.1.stable.official.a13da4feb** on
**macOS**. It creates fallback desktop releases for **Windows x86_64** and
**macOS universal**. Each archive is extract-and-run and requires no editor,
SDK, runtime installer, or other development tool.

## Release matrix

| Target | Engine preset | Output | Verification on this machine |
|---|---|---|---|
| macOS 13 or later on Apple Silicon; macOS 11 or later on Intel | `macOS`, universal | `builds/metabolis-macos-universal.zip` | Export, package inspection, and executable smoke test |
| Windows 10/11 x86_64 | `Windows Desktop`, x86_64 | `builds/metabolis-windows-x86_64.zip` | Cross-export and package inspection only |

Godot can cross-export Windows from macOS because the matching official
template is platform-independent. This macOS host cannot prove that Windows
Defender accepts the file, that the executable starts on the receiver's GPU, or
that the Windows save path is writable. Those checks must be performed on a
clean Windows machine.

The macOS package uses Godot's built-in ad-hoc signature so the modified bundle
has a valid integrity seal, but it has no trusted Apple Developer identity and
is not notarized. Windows is unsigned. macOS may therefore show an
unidentified-developer or quarantine warning, and Windows may show Microsoft
Defender SmartScreen's unknown-publisher warning. For this limited external
test, the receiver should open only the archive delivered by the expected
sender. A public release would require platform-specific developer signing and,
on macOS, notarization.

## Export-template setup

1. Open **Help > About Godot** and confirm
   `4.7.1.stable.official.a13da4feb`.
2. Open **Editor > Manage Export Templates**.
3. Confirm the installed template row is exactly `4.7.1.stable`.
4. On macOS, confirm these official files exist:

   ```text
   ~/Library/Application Support/Godot/export_templates/4.7.1.stable/macos.zip
   ~/Library/Application Support/Godot/export_templates/4.7.1.stable/windows_release_x86_64.exe
   ```

Do not build if the editor and template directory versions differ.

## Project settings and export presets

The versioned source of truth is `src/export_presets.cfg`.

### Shared project settings

| Setting | Menu path | Required value |
|---|---|---|
| Main scene | **Project > Project Settings > Application > Run > Main Scene** | `res://main.tscn` |
| Renderer | **Project > Project Settings > Rendering > Renderer > Rendering Method** | `gl_compatibility` |
| Viewport | **Project > Project Settings > Display > Window > Size** | 640 × 360 viewport; 1280 × 720 override |
| Stretch | **Project > Project Settings > Display > Window > Stretch** | `canvas_items`, `keep`, integer |
| Texture filter | **Project > Project Settings > Rendering > Textures > Canvas Textures > Default Texture Filter** | Nearest |
| ETC2/ASTC import | **Project > Project Settings > Rendering > Textures > VRAM Compression > Import ETC2 ASTC** | On (required by Apple Silicon and the universal macOS export) |

### macOS preset

Open **Project > Export > macOS** and confirm:

- Architecture: **Universal**
- Bundle Identifier: `io.itch.michaelmas12121.metabolis`
- High Resolution: **On**
- S3TC/BPTC and ETC2/ASTC texture compression: **On**
- Code Signing: **Built-in (ad-hoc only)**
- Notarization: **Disabled**
- Resources: **Export all resources**
- Include filter begins with `runtime/**/*`

### Windows preset

Open **Project > Export > Windows Desktop** and confirm:

- Architecture: **x86_64**
- Embed PCK: **On**
- S3TC/BPTC desktop texture compression: **On**
- ETC2/ASTC texture compression: **On**
- Code Signing: **Disabled**
- Product Name: `Metabolis`
- Resources: **Export all resources**
- Include filter begins with `runtime/**/*`

## Build and package

From the repository root:

```bash
python3 tools/build_desktop_export.py
```

Only Godot's official export templates create the application binaries. The
script uses Python's standard library, not a third-party packager, to construct
an isolated staging project and the final ZIP containers.

The staging project is necessary because production `art/`, `anim/`, `audio/`,
`docs/BALANCE.json`, and `docs/assets/` live beside `src/`. The script:

1. copies `src/` to a disposable directory;
2. copies every production runtime asset into `res://runtime/`;
3. changes only the staged dynamic-load paths to exported Godot resources;
4. imports the staging project;
5. calls Godot's `--export-release` for both presets;
6. verifies the macOS bundle, ad-hoc signature, Windows executable, executable
   permissions, and archive structure;
7. launches the macOS executable headlessly and requires
   `[ASSET] Startup check: 97 expected file(s), 0 missing.`; and
8. writes the two release ZIPs.

The production GDScript files are never edited. Do not manually delete files
from either output to reduce size.

## Archive structure

macOS:

```text
metabolis-macos-universal.zip
├── Metabolis.app/
└── README.txt
```

Windows:

```text
metabolis-windows-x86_64.zip
├── Metabolis.exe
└── README.txt
```

If Godot emits an adjacent `.pck` for a future Windows preset, the packager
automatically keeps it beside `Metabolis.exe`. The receiver must extract the
entire archive rather than moving only the executable.

Each `README.txt` contains exactly two user-facing sections: **How to run** and
**Known limitations**. It intentionally contains no engine, source, debug,
or contributor information. It also discloses that optional event cues without
a matching sound file are silent.

## Dynamic-resource audit

Before distribution, run:

```bash
python3 tools/build_desktop_export.py
python3 tools/check_assets.py
python3 tools/check_anim.py
```

The desktop builder must report nonzero counts for art, animation, audio,
balance, and manifests. The macOS smoke log must report exactly 97 expected
files and zero missing. The Windows export comes from the same imported staging
tree and embedded PCK; inspect the ZIP for `Metabolis.exe` and confirm it is
nontrivial in size before the clean-Windows run.

## Save behavior

The runtime writes:

```text
user://metabolis_save.json
```

Godot maps that path per operating-system user:

- macOS:
  `~/Library/Application Support/Godot/app_userdata/Metabolis/metabolis_save.json`
- Windows:
  `%APPDATA%\Godot\app_userdata\Metabolis\metabolis_save.json`

The save is outside the extracted application directory, so replacing or moving
the application normally preserves progress for the same OS user. On first
launch without a save, the title displays **New Game** and no enabled
**Continue** action. After the first tutorial transition writes a save,
restarting the application must display **Continue** and restore the run.

## Clean-machine validation checklist

Use a machine with no editor, SDK, or development tools installed. Complete no
more than these five checks on each target.

| # | Behavior | Pass standard | First failure check |
|---|---|---|---|
| 1 | Extract and launch | Extracting the entire ZIP and double-clicking the app/executable reaches the title without installing anything | Confirm the whole archive was extracted and review the OS security prompt |
| 2 | Runtime resources and audio | Title art, resource icons, animation, and heartbeat appear; the log-free player shows no missing-data placeholder | Re-extract the archive and confirm no adjacent file was removed |
| 3 | Core flow | New Game reaches Stage 1 and mouse/keyboard actions respond at the expected window size | Confirm the window has input focus and restart once |
| 4 | Save creation | The first tutorial transition completes and the documented OS save file appears | Confirm the current user can write to the documented application-data directory |
| 5 | Save restoration | After fully quitting and reopening, Continue is enabled and re-enters the run | Confirm the same OS user launched both times and the save file still exists |

Record the target OS version, CPU architecture, archive checksum, and result of
each row. A Windows package remains **cross-export verified, not machine
verified** until all five rows pass on a clean Windows 10/11 x86_64 computer.
