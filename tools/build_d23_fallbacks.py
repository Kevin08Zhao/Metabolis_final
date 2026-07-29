"""Build D-23 static fallbacks from the accepted D-22 timeline endpoints."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def build(repo_root: Path) -> list[Path]:
    pairs = {
        repo_root / "art" / "birth" / "birth_fallback_start.png":
            repo_root / "art" / "birth" / "frames" / "stage1_umbilical_stop_00000_2x.png",
        repo_root / "art" / "birth" / "birth_fallback_end.png":
            repo_root / "art" / "birth" / "frames" / "stage5_ending_42000_2x.png",
    }
    outputs: list[Path] = []
    for target, source in pairs.items():
        if not source.is_file():
            raise FileNotFoundError(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        outputs.append(target)
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    for output in build(args.repo_root.resolve()):
        print(output.relative_to(args.repo_root.resolve()).as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
