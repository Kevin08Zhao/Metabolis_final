#!/usr/bin/env python3
"""Build Metabolis' single-threaded Godot Web release in an isolated staging tree."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = REPOSITORY_ROOT / "src"
BUILDS_ROOT = REPOSITORY_ROOT / "builds"
WEB_OUTPUT_ROOT = BUILDS_ROOT / "web"
ITCH_ZIP_PATH = BUILDS_ROOT / "metabolis-html5.zip"

REQUIRED_EXPORT_FILES = (
    "index.html",
    "index.js",
    "index.pck",
    "index.wasm",
)
SKIPPED_ART_DIRECTORIES = {
    "candidates",
    "reference",
    "screenshots",
    "source",
}
RUNTIME_COPY_RULES = (
    ("art", frozenset({".png"})),
    ("anim", frozenset({".json", ".png"})),
    ("audio", frozenset({".wav"})),
)


@dataclass(frozen=True)
class Replacement:
    old: str
    new: str
    expected_count: int = 1


STAGING_REPLACEMENTS: dict[str, tuple[Replacement, ...]] = {
    "autoload/balance.gd": (
        Replacement(
            'const BALANCE_PATH := "res://../docs/BALANCE.json"',
            'const BALANCE_PATH := "res://runtime/docs/BALANCE.json"',
        ),
    ),
    "core/asset_loader.gd": (
        Replacement(
            'const STATIC_ART_ROOT := "res://../art"',
            'const STATIC_ART_ROOT := "res://runtime/art"',
        ),
        Replacement(
            'const ANIMATION_ROOT := "res://../anim"',
            'const ANIMATION_ROOT := "res://runtime/anim"',
        ),
        Replacement(
            'const EXPECTED_MANIFEST_ROOT := "res://../docs/assets"',
            'const EXPECTED_MANIFEST_ROOT := "res://runtime/docs/assets"',
        ),
        Replacement(
            """\tvar image := Image.load_from_file(matches[0])
\tif image == null or image.is_empty():
\t\t_warn("Could not read image file %s." % _display_path(matches[0]))
\t\treturn _get_placeholder_texture()

\treturn ImageTexture.create_from_image(image)""",
            """\tvar texture := ResourceLoader.load(matches[0], "Texture2D") as Texture2D
\tif texture == null:
\t\t_warn("Could not read texture resource %s." % _display_path(matches[0]))
\t\treturn _get_placeholder_texture()

\treturn texture""",
        ),
        Replacement(
            "\tif not FileAccess.file_exists(sheet_path):",
            "\tif not ResourceLoader.exists(sheet_path):",
        ),
        Replacement(
            """\tvar sheet_image := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
\tif sheet_image == null or sheet_image.is_empty():""",
            """\tvar sheet_texture := ResourceLoader.load(sheet_path, "Texture2D") as Texture2D
\tvar sheet_image := sheet_texture.get_image() if sheet_texture != null else null
\tif sheet_image == null or sheet_image.is_empty():""",
        ),
        Replacement(
            """\tvar absolute_root := ProjectSettings.globalize_path(STATIC_ART_ROOT)
\t_collect_static_matches(absolute_root, file_name, matches, true)""",
            "\t_collect_static_matches(STATIC_ART_ROOT, file_name, matches, true)",
        ),
        Replacement(
            """\t\tif candidate_file == file_name:
\t\t\tmatches.append(directory_path.path_join(candidate_file))""",
            """\t\tif candidate_file == file_name or candidate_file == "%s.import" % file_name:
\t\t\tmatches.append(directory_path.path_join(file_name))""",
        ),
        Replacement(
            "\tvar manifest_directory := ProjectSettings.globalize_path(EXPECTED_MANIFEST_ROOT)",
            "\tvar manifest_directory := EXPECTED_MANIFEST_ROOT",
        ),
        Replacement(
            '\t\tvar repository_path := "res://../%s" % relative_path',
            '\t\tvar repository_path := "res://runtime/%s" % relative_path',
        ),
        Replacement(
            """\t\tif not FileAccess.file_exists(repository_path):
\t\t\tmissing_paths.append(repository_path)""",
            """\t\tvar exists := (
\t\t\tResourceLoader.exists(repository_path)
\t\t\tif repository_path.ends_with(".png")
\t\t\telse FileAccess.file_exists(repository_path)
\t\t)
\t\tif not exists:
\t\t\tmissing_paths.append(repository_path)""",
        ),
    ),
    "core/audio_router.gd": (
        Replacement(
            '"res://../audio',
            '"res://runtime/audio',
            expected_count=4,
        ),
        Replacement(
            """\tif not FileAccess.file_exists(path):
\t\t_warn_missing_once(path)
\t\treturn null

\tvar stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))""",
            """\tif not ResourceLoader.exists(path):
\t\t_warn_missing_once(path)
\t\treturn null

\tvar stream := ResourceLoader.load(path, "AudioStreamWAV") as AudioStreamWAV""",
        ),
    ),
    "core/scene_router.gd": (
        Replacement(
            """\t_scene_host.name = "SceneHost"
\tadd_child(_scene_host)
\t# Boot routing: always open the title on launch.""",
            """\t_scene_host.name = "SceneHost"
\tadd_child(_scene_host)
\tSaveManager.load_save()
\t# Boot routing: always open the title on launch.""",
        ),
    ),
    "ui/resource_bar.gd": (
        Replacement(
            'const RESOURCE_ICON_ROOT := "res://../art/icons"',
            'const RESOURCE_ICON_ROOT := "res://runtime/art/icons"',
        ),
        Replacement(
            """\tvar image := Image.load_from_file(ProjectSettings.globalize_path(path))
\tif image == null or image.is_empty():
\t\tpush_warning("%s Missing icon '%s'." % [LOG_PREFIX, path])
\t\treturn null
\treturn ImageTexture.create_from_image(image)""",
            """\tvar texture := ResourceLoader.load(path, "Texture2D") as Texture2D
\tif texture == null:
\t\tpush_warning("%s Missing icon '%s'." % [LOG_PREFIX, path])
\t\treturn null
\treturn texture""",
        ),
    ),
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create an isolated Godot Web staging project, export a release build, "
            "and package an itch.io-ready ZIP."
        )
    )
    parser.add_argument(
        "--godot",
        default="/opt/homebrew/bin/godot" if platform.system() == "Darwin" else "godot",
        help="Godot editor executable (default: %(default)s)",
    )
    parser.add_argument(
        "--keep-staging",
        type=Path,
        help="Copy the final staging project to this empty path for inspection.",
    )
    return parser.parse_args()


def run_command(command: list[str], *, cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )
    combined = "\n".join(part for part in (result.stdout, result.stderr) if part)
    if result.returncode != 0:
        raise RuntimeError(
            "Command failed with exit code "
            f"{result.returncode}: {' '.join(command)}\n{combined}"
        )
    return combined


def engine_version(godot: str) -> tuple[str, str]:
    full_version = run_command([godot, "--version"]).strip().splitlines()[0]
    template_version = full_version.split(".official", maxsplit=1)[0]
    if not template_version:
        raise RuntimeError(f"Could not derive template version from: {full_version}")
    return full_version, template_version


def export_template_root() -> Path:
    system = platform.system()
    if system == "Darwin":
        return Path.home() / "Library/Application Support/Godot/export_templates"
    if system == "Windows":
        app_data = os.environ.get("APPDATA")
        if not app_data:
            raise RuntimeError("APPDATA is unset; cannot locate Godot export templates.")
        return Path(app_data) / "Godot/export_templates"
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return data_home / "godot/export_templates"


def verify_export_template(template_version: str) -> Path:
    template = (
        export_template_root()
        / template_version
        / "web_nothreads_release.zip"
    )
    if not template.is_file():
        raise RuntimeError(
            "Matching single-threaded Web export template is missing: "
            f"{template}\nInstall it from Editor > Manage Export Templates."
        )
    return template


def copy_project(staging_project: Path) -> None:
    def ignore_project_files(_directory: str, names: list[str]) -> set[str]:
        ignored = {".godot"}
        return ignored.intersection(names)

    shutil.copytree(
        PROJECT_ROOT,
        staging_project,
        ignore=ignore_project_files,
    )


def copy_selected_files(
    source_root: Path,
    destination_root: Path,
    allowed_suffixes: frozenset[str],
    *,
    skipped_top_level: set[str] | None = None,
) -> int:
    count = 0
    for source in sorted(source_root.rglob("*")):
        if not source.is_file() or source.suffix.lower() not in allowed_suffixes:
            continue
        relative_path = source.relative_to(source_root)
        if skipped_top_level and relative_path.parts[0] in skipped_top_level:
            continue
        destination = destination_root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        count += 1
    return count


def copy_runtime_data(staging_project: Path) -> dict[str, int]:
    runtime_root = staging_project / "runtime"
    counts: dict[str, int] = {}
    for directory_name, suffixes in RUNTIME_COPY_RULES:
        counts[directory_name] = copy_selected_files(
            REPOSITORY_ROOT / directory_name,
            runtime_root / directory_name,
            suffixes,
            skipped_top_level=(
                SKIPPED_ART_DIRECTORIES if directory_name == "art" else None
            ),
        )

    docs_root = runtime_root / "docs"
    docs_root.mkdir(parents=True, exist_ok=True)
    shutil.copy2(REPOSITORY_ROOT / "docs/BALANCE.json", docs_root / "BALANCE.json")
    counts["balance"] = 1
    counts["manifests"] = copy_selected_files(
        REPOSITORY_ROOT / "docs/assets",
        docs_root / "assets",
        frozenset({".md"}),
    )

    for category, count in counts.items():
        if count < 1:
            raise RuntimeError(f"No runtime {category} files were staged.")
    return counts


def replace_exact(text: str, replacement: Replacement, relative_path: str) -> str:
    actual_count = text.count(replacement.old)
    if actual_count != replacement.expected_count:
        raise RuntimeError(
            f"{relative_path}: expected {replacement.expected_count} occurrence(s), "
            f"found {actual_count}; refusing an unreviewed staging rewrite."
        )
    return text.replace(replacement.old, replacement.new)


def patch_staging_sources(staging_project: Path) -> None:
    for relative_path, replacements in STAGING_REPLACEMENTS.items():
        path = staging_project / relative_path
        text = path.read_text(encoding="utf-8")
        for replacement in replacements:
            text = replace_exact(text, replacement, relative_path)
        path.write_text(text, encoding="utf-8")


def verify_staging(staging_project: Path, counts: dict[str, int]) -> None:
    required_paths = (
        staging_project / "runtime/docs/BALANCE.json",
        staging_project / "runtime/docs/assets",
        staging_project / "runtime/art",
        staging_project / "runtime/anim",
        staging_project / "runtime/audio",
        staging_project / "export_presets.cfg",
    )
    missing = [str(path) for path in required_paths if not path.exists()]
    if missing:
        raise RuntimeError(f"Staging tree is incomplete: {', '.join(missing)}")

    if counts["art"] < 90:
        raise RuntimeError(
            f"Only {counts['art']} production art files were staged; expected at least 90."
        )

    forbidden_roots = (
        staging_project / "runtime/art/candidates",
        staging_project / "runtime/art/reference",
        staging_project / "runtime/art/screenshots",
        staging_project / "runtime/art/source",
    )
    leaked = [str(path) for path in forbidden_roots if path.exists()]
    if leaked:
        raise RuntimeError(f"Non-runtime art leaked into staging: {', '.join(leaked)}")


def export_web_release(godot: str, staging_project: Path, export_root: Path) -> str:
    import_log = run_command(
        [godot, "--headless", "--path", str(staging_project), "--editor", "--quit"]
    )
    export_root.mkdir(parents=True, exist_ok=True)
    export_log = run_command(
        [
            godot,
            "--headless",
            "--path",
            str(staging_project),
            "--export-release",
            "Web",
            str(export_root / "index.html"),
        ]
    )
    return f"{import_log}\n{export_log}"


def verify_export(export_root: Path, export_log: str) -> None:
    missing = [
        file_name
        for file_name in REQUIRED_EXPORT_FILES
        if not (export_root / file_name).is_file()
    ]
    if missing:
        raise RuntimeError(f"Web export is missing: {', '.join(missing)}")

    if (export_root / "index.pck").stat().st_size < 1_000_000:
        raise RuntimeError("index.pck is unexpectedly small; runtime assets may be absent.")

    fatal_markers = (
        "SCRIPT ERROR:",
        "Parse Error:",
        "Export preset not found",
        "Could not open the template",
    )
    found_markers = [marker for marker in fatal_markers if marker in export_log]
    if found_markers:
        raise RuntimeError(
            f"Godot export log contains fatal marker(s): {', '.join(found_markers)}"
        )


def replace_output(export_root: Path) -> None:
    BUILDS_ROOT.mkdir(parents=True, exist_ok=True)
    if WEB_OUTPUT_ROOT.exists():
        if not WEB_OUTPUT_ROOT.is_dir() or WEB_OUTPUT_ROOT.is_symlink():
            raise RuntimeError(f"Refusing to replace unsafe output path: {WEB_OUTPUT_ROOT}")
        shutil.rmtree(WEB_OUTPUT_ROOT)
    shutil.copytree(export_root, WEB_OUTPUT_ROOT)


def iter_export_files(root: Path) -> Iterable[Path]:
    return sorted(path for path in root.rglob("*") if path.is_file())


def package_itch_zip() -> None:
    temporary_zip = ITCH_ZIP_PATH.with_suffix(".zip.tmp")
    if temporary_zip.exists():
        temporary_zip.unlink()
    with zipfile.ZipFile(
        temporary_zip,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for source in iter_export_files(WEB_OUTPUT_ROOT):
            relative_path = source.relative_to(WEB_OUTPUT_ROOT)
            info = zipfile.ZipInfo(str(relative_path), date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, source.read_bytes())
    temporary_zip.replace(ITCH_ZIP_PATH)

    with zipfile.ZipFile(ITCH_ZIP_PATH) as archive:
        names = archive.namelist()
        if "index.html" not in names:
            raise RuntimeError("itch.io ZIP does not contain index.html at its root.")
        if any(name.startswith("/") or ".." in Path(name).parts for name in names):
            raise RuntimeError("itch.io ZIP contains an unsafe path.")


def keep_staging_copy(staging_project: Path, requested_path: Path) -> None:
    destination = requested_path.resolve()
    if destination.exists():
        raise RuntimeError(f"--keep-staging destination already exists: {destination}")
    shutil.copytree(staging_project, destination)


def main() -> int:
    arguments = parse_arguments()
    full_version, template_version = engine_version(arguments.godot)
    template = verify_export_template(template_version)

    with tempfile.TemporaryDirectory(prefix="metabolis-web-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        staging_project = temporary_root / "src"
        export_root = temporary_root / "export"
        copy_project(staging_project)
        counts = copy_runtime_data(staging_project)
        patch_staging_sources(staging_project)
        verify_staging(staging_project, counts)
        export_log = export_web_release(arguments.godot, staging_project, export_root)
        verify_export(export_root, export_log)
        replace_output(export_root)
        package_itch_zip()
        if arguments.keep_staging is not None:
            keep_staging_copy(staging_project, arguments.keep_staging)

    print(f"Godot: {full_version}")
    print(f"Template: {template}")
    print(
        "Runtime files: "
        + ", ".join(f"{category}={count}" for category, count in counts.items())
    )
    print(f"Web build: {WEB_OUTPUT_ROOT}")
    print(f"itch.io ZIP: {ITCH_ZIP_PATH} ({ITCH_ZIP_PATH.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
