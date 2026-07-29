#!/usr/bin/env python3
"""Build and package Metabolis desktop releases from an isolated staging tree."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

import build_web_export as staging


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
BUILDS_ROOT = REPOSITORY_ROOT / "builds"
DESKTOP_OUTPUT_ROOT = BUILDS_ROOT / "desktop"
MACOS_ZIP_PATH = BUILDS_ROOT / "metabolis-macos-universal.zip"
WINDOWS_ZIP_PATH = BUILDS_ROOT / "metabolis-windows-x86_64.zip"
MACOS_README = REPOSITORY_ROOT / "packaging/desktop/README_MACOS.txt"
WINDOWS_README = REPOSITORY_ROOT / "packaging/desktop/README_WINDOWS.txt"

MACOS_PRESET = "macOS"
WINDOWS_PRESET = "Windows Desktop"
MACOS_TEMPLATE = "macos.zip"
WINDOWS_TEMPLATE = "windows_release_x86_64.exe"
FATAL_EXPORT_MARKERS = (
    "SCRIPT ERROR:",
    "Parse Error:",
    "Export preset not found",
    "Could not open the template",
)
FORBIDDEN_README_TERMS = (
    "godot",
    "source code",
    "debug",
    "development build",
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create isolated Windows x86_64 and macOS universal release exports "
            "and package each as an extract-and-run ZIP."
        )
    )
    parser.add_argument(
        "--godot",
        default="/opt/homebrew/bin/godot" if platform.system() == "Darwin" else "godot",
        help="Godot editor executable (default: %(default)s)",
    )
    parser.add_argument(
        "--skip-macos-smoke",
        action="store_true",
        help="Do not launch the exported macOS executable for its headless asset smoke test.",
    )
    parser.add_argument(
        "--keep-staging",
        type=Path,
        help="Copy the final staging project to this empty path for inspection.",
    )
    return parser.parse_args()


def verify_templates(template_version: str) -> dict[str, Path]:
    template_root = staging.export_template_root() / template_version
    templates = {
        "macOS": template_root / MACOS_TEMPLATE,
        "Windows x86_64": template_root / WINDOWS_TEMPLATE,
    }
    missing = [f"{name}: {path}" for name, path in templates.items() if not path.is_file()]
    if missing:
        raise RuntimeError(
            "Matching desktop export template(s) are missing:\n"
            + "\n".join(missing)
            + "\nInstall them from Editor > Manage Export Templates."
        )
    return templates


def export_desktop_releases(
    godot: str,
    staging_project: Path,
    export_root: Path,
) -> tuple[Path, Path, str]:
    import_log = staging.run_command(
        [godot, "--headless", "--path", str(staging_project), "--editor", "--quit"]
    )

    macos_root = export_root / "macos"
    windows_root = export_root / "windows"
    macos_root.mkdir(parents=True)
    windows_root.mkdir(parents=True)
    macos_app = macos_root / "Metabolis.app"
    windows_exe = windows_root / "Metabolis.exe"

    macos_log = staging.run_command(
        [
            godot,
            "--headless",
            "--path",
            str(staging_project),
            "--export-release",
            MACOS_PRESET,
            str(macos_app),
        ]
    )
    windows_log = staging.run_command(
        [
            godot,
            "--headless",
            "--path",
            str(staging_project),
            "--export-release",
            WINDOWS_PRESET,
            str(windows_exe),
        ]
    )
    return macos_app, windows_exe, "\n".join((import_log, macos_log, windows_log))


def verify_export(
    macos_app: Path,
    windows_exe: Path,
    export_log: str,
) -> None:
    macos_binary = macos_app / "Contents/MacOS/Metabolis"
    required = (macos_app / "Contents/Info.plist", macos_binary, windows_exe)
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise RuntimeError(f"Desktop export is missing: {', '.join(missing)}")

    if macos_binary.stat().st_size < 1_000_000:
        raise RuntimeError("macOS executable is unexpectedly small.")
    if windows_exe.stat().st_size < 1_000_000:
        raise RuntimeError("Windows executable is unexpectedly small.")
    if not os.access(macos_binary, os.X_OK):
        raise RuntimeError(f"macOS executable bit is missing: {macos_binary}")

    if platform.system() == "Darwin":
        signature_check = subprocess.run(
            ["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(macos_app)],
            check=False,
            capture_output=True,
            text=True,
        )
        if signature_check.returncode != 0:
            combined = "\n".join(
                part
                for part in (signature_check.stdout, signature_check.stderr)
                if part
            )
            raise RuntimeError(f"macOS ad-hoc signature is invalid:\n{combined}")

    found_markers = [marker for marker in FATAL_EXPORT_MARKERS if marker in export_log]
    if found_markers:
        raise RuntimeError(
            f"Godot export log contains fatal marker(s): {', '.join(found_markers)}"
        )


def validate_readme(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("How to run\n"):
        raise RuntimeError(f"{path}: must start with 'How to run'.")
    if "\nKnown limitations\n" not in text:
        raise RuntimeError(f"{path}: missing 'Known limitations' section.")
    lowered = text.lower()
    found = [term for term in FORBIDDEN_README_TERMS if term in lowered]
    if found:
        raise RuntimeError(
            f"{path}: contains developer-facing term(s): {', '.join(found)}"
        )
    return text


def copy_outputs(
    macos_app: Path,
    windows_exe: Path,
    package_root: Path,
) -> tuple[Path, Path]:
    macos_package = package_root / "macos"
    windows_package = package_root / "windows"
    macos_package.mkdir(parents=True)
    windows_package.mkdir(parents=True)

    shutil.copytree(macos_app, macos_package / macos_app.name, symlinks=True)
    shutil.copy2(MACOS_README, macos_package / "README.txt")

    for source in sorted(windows_exe.parent.iterdir()):
        if source.is_file():
            shutil.copy2(source, windows_package / source.name)
    shutil.copy2(WINDOWS_README, windows_package / "README.txt")
    return macos_package, windows_package


def zip_tree(source_root: Path, destination: Path) -> None:
    temporary_zip = destination.with_suffix(".zip.tmp")
    if temporary_zip.exists():
        temporary_zip.unlink()

    with zipfile.ZipFile(
        temporary_zip,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for source in sorted(source_root.rglob("*")):
            relative = source.relative_to(source_root)
            archive_name = str(relative)
            source_stat = source.lstat()
            mode = source_stat.st_mode
            if source.is_dir():
                info = zipfile.ZipInfo(f"{archive_name}/", (1980, 1, 1, 0, 0, 0))
                info.external_attr = (mode & 0xFFFF) << 16
                archive.writestr(info, b"")
            elif source.is_symlink():
                info = zipfile.ZipInfo(archive_name, (1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(info, os.readlink(source).encode("utf-8"))
            else:
                info = zipfile.ZipInfo(archive_name, (1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (mode & 0xFFFF) << 16
                archive.writestr(info, source.read_bytes())
    temporary_zip.replace(destination)


def verify_archive(
    archive_path: Path,
    *,
    required_names: tuple[str, ...],
    expected_readme: str,
) -> None:
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        if any(name.startswith("/") or ".." in Path(name).parts for name in names):
            raise RuntimeError(f"{archive_path}: archive contains an unsafe path.")
        missing = [name for name in required_names if name not in names]
        if missing:
            raise RuntimeError(
                f"{archive_path}: archive is missing {', '.join(missing)}"
            )
        readme = archive.read("README.txt").decode("utf-8")
        if readme != expected_readme:
            raise RuntimeError(f"{archive_path}: README.txt differs from its source.")


def macos_smoke_test(macos_app: Path) -> str:
    executable = macos_app / "Contents/MacOS/Metabolis"
    smoke_log = macos_app.parent / "macos-smoke.log"
    result = subprocess.run(
        [
            str(executable),
            "--headless",
            "--log-file",
            str(smoke_log),
            "--quit-after",
            "180",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    combined = "\n".join(part for part in (result.stdout, result.stderr) if part)
    if result.returncode != 0:
        raise RuntimeError(
            f"macOS smoke test exited with {result.returncode}:\n{combined}"
        )
    required_markers = (
        "[ASSET] Startup check: 97 expected file(s), 0 missing.",
        "[ROUTE] title",
    )
    missing = [marker for marker in required_markers if marker not in combined]
    if missing:
        raise RuntimeError(
            "macOS smoke test missed required marker(s): " + ", ".join(missing)
        )
    return combined


def replace_output(
    macos_app: Path,
    windows_exe: Path,
    package_root: Path,
) -> None:
    BUILDS_ROOT.mkdir(parents=True, exist_ok=True)
    if DESKTOP_OUTPUT_ROOT.exists():
        if not DESKTOP_OUTPUT_ROOT.is_dir() or DESKTOP_OUTPUT_ROOT.is_symlink():
            raise RuntimeError(
                f"Refusing to replace unsafe output path: {DESKTOP_OUTPUT_ROOT}"
            )
        shutil.rmtree(DESKTOP_OUTPUT_ROOT)
    DESKTOP_OUTPUT_ROOT.mkdir()
    shutil.copytree(macos_app, DESKTOP_OUTPUT_ROOT / "macos/Metabolis.app", symlinks=True)
    for source in sorted(windows_exe.parent.iterdir()):
        if source.is_file():
            destination = DESKTOP_OUTPUT_ROOT / "windows" / source.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    shutil.copytree(package_root, DESKTOP_OUTPUT_ROOT / "packages", dirs_exist_ok=True)


def main() -> int:
    arguments = parse_arguments()
    full_version, template_version = staging.engine_version(arguments.godot)
    templates = verify_templates(template_version)
    macos_readme = validate_readme(MACOS_README)
    windows_readme = validate_readme(WINDOWS_README)

    with tempfile.TemporaryDirectory(prefix="metabolis-desktop-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        staging_project = temporary_root / "src"
        export_root = temporary_root / "export"
        package_root = temporary_root / "packages"

        staging.copy_project(staging_project)
        counts = staging.copy_runtime_data(staging_project)
        staging.patch_staging_sources(staging_project)
        staging.verify_staging(staging_project, counts)
        macos_app, windows_exe, export_log = export_desktop_releases(
            arguments.godot,
            staging_project,
            export_root,
        )
        verify_export(macos_app, windows_exe, export_log)
        if platform.system() == "Darwin" and not arguments.skip_macos_smoke:
            macos_smoke_test(macos_app)

        macos_package, windows_package = copy_outputs(
            macos_app,
            windows_exe,
            package_root,
        )
        zip_tree(macos_package, MACOS_ZIP_PATH)
        zip_tree(windows_package, WINDOWS_ZIP_PATH)
        verify_archive(
            MACOS_ZIP_PATH,
            required_names=("README.txt", "Metabolis.app/Contents/MacOS/Metabolis"),
            expected_readme=macos_readme,
        )
        verify_archive(
            WINDOWS_ZIP_PATH,
            required_names=("README.txt", "Metabolis.exe"),
            expected_readme=windows_readme,
        )
        replace_output(macos_app, windows_exe, package_root)
        if arguments.keep_staging is not None:
            staging.keep_staging_copy(staging_project, arguments.keep_staging)

    print(f"Godot: {full_version}")
    print(
        "Templates: "
        + ", ".join(f"{name}={path}" for name, path in templates.items())
    )
    print(
        "Runtime files: "
        + ", ".join(f"{category}={count}" for category, count in counts.items())
    )
    print(f"macOS ZIP: {MACOS_ZIP_PATH} ({MACOS_ZIP_PATH.stat().st_size} bytes)")
    print(
        f"Windows ZIP: {WINDOWS_ZIP_PATH} "
        f"({WINDOWS_ZIP_PATH.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        OSError,
        RuntimeError,
        subprocess.SubprocessError,
        zipfile.BadZipFile,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
