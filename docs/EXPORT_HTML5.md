# Metabolis HTML5 Export and itch.io Playtest Runbook

This runbook is locked to **Godot 4.7.1.stable.official.a13da4feb** on
**macOS**. It produces the single-threaded Web build used for the three-person
external playtest.

Official references:

- [Godot 4.7 Web export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
- [Godot export templates and resource filters](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)
- [Godot `user://` data paths](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html)
- [itch.io HTML5 uploads and embed options](https://itch.io/docs/creators/html5)
- [itch.io restricted access](https://itch.io/docs/creators/access-control)
- [itch.io SharedArrayBuffer option](https://itch.io/t/2025776/experimental-sharedarraybuffer-support)

## Release profile

| Item | Required value |
|---|---|
| Engine | `4.7.1.stable.official.a13da4feb` |
| Export template directory | `4.7.1.stable` |
| Renderer | Compatibility / WebGL 2.0 |
| Web threads | Off |
| GDExtension support | Off |
| PWA | Off |
| Reference viewport | 640 × 360 |
| itch.io viewport | 1280 × 720 |
| itch.io fullscreen button | On |
| itch.io SharedArrayBuffer support | **Off** |
| Distribution | itch.io HTML project; no alternate platform |

The project keeps `art/`, `anim/`, `audio/`, and `docs/BALANCE.json` beside the
Godot project root rather than inside it. A normal Godot export cannot package
those `res://../` runtime reads. `tools/build_web_export.py` therefore copies the
project to a disposable staging directory, places production runtime data under
`res://runtime/`, and applies Web-only resource-loading conversions there. It
never edits the production GDScript files.

## First-time export-template setup

1. Launch the same Godot editor that will perform the export.
2. Open **Editor > Manage Export Templates**.
3. The manager's current version must read `4.7.1.stable`.
4. If that row is not installed, select the Web templates and choose
   **Install Selected Templates**. Installing the full official
   `Godot_v4.7.1-stable_export_templates.tpz` from **Install from File** is also
   valid.
5. Close the manager, open **Help > About Godot**, and confirm the editor reports
   `4.7.1.stable.official.a13da4feb`.
6. On macOS, verify this file exists:

   ```text
   ~/Library/Application Support/Godot/export_templates/4.7.1.stable/web_nothreads_release.zip
   ```

Do not export when the editor's `4.7.1.stable` identifier and the template
directory differ. The build script performs the same check and stops on a
mismatch.

## Export preflight checklist

Complete every row before making a tester build.

| Check | Exact location or command | Pass condition |
|---|---|---|
| T-38 release gate | `docs/coord/done/T-38.md` | Status is `DONE`; normal and no-art full runs passed |
| Engine version | **Help > About Godot** or `godot --version` | Exact value is `4.7.1.stable.official.a13da4feb` |
| Export template | **Editor > Manage Export Templates** | `4.7.1.stable` Web template is installed |
| Main scene | **Project > Project Settings > Application > Run > Main Scene** | `res://main.tscn` |
| Viewport | **Project > Project Settings > Display > Window > Size** | Viewport Width `640`; Viewport Height `360`; Window Width Override `1280`; Window Height Override `720` |
| Pixel scaling | **Project > Project Settings > Display > Window > Stretch** | Mode `canvas_items`; Aspect `keep`; Scale Mode `integer` |
| Renderer | **Project > Project Settings > Rendering > Renderer > Rendering Method** | `gl_compatibility` |
| Texture filtering | **Project > Project Settings > Rendering > Textures > Canvas Textures > Default Texture Filter** | `Nearest` |
| Web audio mode | **Project > Project Settings > Audio > General > Default Playback Type** with the Web override selected | `Sample` |
| Web preset | **Project > Export > Web** | Preset exists and has no warning |
| Thread support | **Project > Export > Web > Options > Variant > Thread Support** | Off |
| Extension support | **Project > Export > Web > Options > Variant > Extensions Support** | Off |
| Canvas behavior | **Project > Export > Web > Options > HTML** | Canvas Resize Policy `Adaptive`; Focus Canvas On Start on |
| PWA | **Project > Export > Web > Options > Progressive Web App > Enabled** | Off |
| Resource filter | **Project > Export > Web > Resources** | Export all resources; include filter begins with `runtime/**/*` |
| Runtime inputs | Repository root | `art/`, `anim/`, `audio/`, `docs/BALANCE.json`, and `docs/assets/` exist |
| Working tree | `git status --short` | No unexplained source or credential files |

The Web preset is versioned in `src/export_presets.cfg`. Use it as the source of
truth instead of rebuilding the preset by hand.

## Build and package

From the repository root:

```bash
python3 tools/build_web_export.py
```

The command:

1. checks the editor and template versions;
2. creates a disposable staging project;
3. copies production art, animation, audio, balance data, and asset manifests;
4. converts staged dynamic image and WAV reads to exported Godot resources;
5. imports and exports the staged project with the `Web` release preset;
6. verifies the required files and a nontrivial PCK;
7. writes `builds/web/`; and
8. writes `builds/metabolis-html5.zip` with `index.html` at the ZIP root.

To select another Godot executable:

```bash
python3 tools/build_web_export.py --godot /absolute/path/to/godot
```

Do not rename individual exported files. Godot's HTML, JavaScript, WASM, PCK,
worklets, and icons are one matched set.

## Local browser check

Never open `index.html` with `file://`. Start a local server:

```bash
python3 -m http.server 8877 --bind 127.0.0.1 --directory builds/web
```

Open `http://127.0.0.1:8877/` in a current Chromium browser or Firefox. Confirm:

1. the title art appears and the console prints
   `[ASSET] Startup check: 97 expected file(s), 0 missing.`;
2. the console identifies a `single-threaded` build;
3. clicking **New Game** reaches Stage 1;
4. after the first tutorial transition, the console prints
   `[SAVE] Wrote user://metabolis_save.json`; and
5. refreshing returns to a title with **Continue**, and clicking it reaches the
   game.

Warnings for event names that have no optional SFX file, such as
`stage_loaded.wav`, do not indicate a packaging failure. Any missing balance
file, title background, required manifest asset, ambient heartbeat, WASM, or PCK
is a release blocker.

## Browser audio: concrete player flow

Browsers may suspend Web Audio until a trusted user gesture. Keep itch.io
**Click to Play** enabled and use this exact sequence:

1. The tester clicks itch.io's **Run game** control.
2. The tester clicks **New Game** or **Continue** inside the Godot canvas.
3. That canvas click unlocks audio; the heartbeat bed should then be audible.
4. If it is silent, the tester checks that the tab and site are not muted, then
   reloads and repeats both clicks. Do not depend on sound starting before the
   first interaction.

The release uses Godot's Web `Sample` playback type and does not enable threads
merely to obtain audio.

## Browser save location and loss conditions

The save path remains:

```text
user://metabolis_save.json
```

In a Web export, Godot maps `user://` to the browser's virtual filesystem backed
by **IndexedDB**. It is scoped to the browser profile and the page's origin; it
is not a normal Finder file and it is not synchronized to another browser or
device.

- Refreshing the same page preserves the save.
- Uploading a replacement build to the same itch.io project should preserve it
  while the serving origin and frame configuration stay unchanged.
- Clearing cookies/site data or all browser data deletes it.
- A private-window save normally disappears when the private session closes.
- Switching itch.io's SharedArrayBuffer support can change the serving origin
  and make the previous save inaccessible. Keep that option off for the entire
  playtest.
- Browsers may evict IndexedDB under storage pressure. This playtest save is not
  cloud backup.

## itch.io upload and page configuration

1. Create or open the Metabolis playtest project from the itch.io dashboard.
2. Set **Kind of project** to **HTML**.
3. Set pricing to **No payments**.
4. Upload `builds/metabolis-html5.zip`.
5. Mark the upload **This file will be played in the browser**.
6. In **Embed options**, set:

   | Option | Exact setting |
   |---|---|
   | Launch mode | **Embed in page** |
   | Viewport dimensions | **1280 × 720** |
   | Click to Play | **On** |
   | Fullscreen Button | **On** |
   | Scrollbars | **Off** |
   | Mobile Friendly | **Off** until a separate mobile pass succeeds |
   | SharedArrayBuffer support | **Off** |

7. In **Visibility & access**, choose **Restricted**.
8. Enable **Also allow a password to view page**, use a playtest-only password,
   and share the page URL and password only with the three testers. Restricted
   projects are absent from itch.io browse/search and external search indexes.
9. Choose **Save & view page** and wait for archive processing to finish.

`SharedArrayBuffer support` must stay off because `variant/thread_support=false`
and `variant/extensions_support=false`. Enabling it adds cross-origin isolation
headers that this build does not need and may split the IndexedDB origin used by
existing saves.

## Post-upload browser validation

Run these five checks in an unauthenticated private window. The page password is
allowed; an itch.io account is not required.

| # | Behavior | Pass standard |
|---|---|---|
| 1 | Restricted zero-install launch | Page opens with the password, **Run game** loads the title art, and there is no download or installation step |
| 2 | First-interaction audio | After **Run game**, the first **New Game** or **Continue** click makes the heartbeat audible; no audio is required before that click |
| 3 | Playable canvas and fullscreen | Stage 1 accepts mouse/keyboard input at 1280 × 720; the itch.io fullscreen button enters and exits fullscreen without cropping controls |
| 4 | Required resources and flow | Title art, resource icons, heartbeat, and Stage 1 load; the console reports 97 expected assets and zero missing |
| 5 | Save persistence | Complete the first tutorial transition, refresh, observe **Continue** on the title, and use it to re-enter the game |

If any row fails, keep the page Restricted, preserve the failing browser name and
console output, and replace the ZIP only after a new local browser pass.
