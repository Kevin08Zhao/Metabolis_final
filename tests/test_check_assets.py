from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
CHECKER = REPO_ROOT / "tools" / "check_assets.py"


class CheckAssetsTests(unittest.TestCase):
    def run_checker(self, root: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(CHECKER),
                "--repo-root",
                str(root),
                "--format",
                "json",
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_reports_out_of_palette_pixel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (1, 2, 3, 255)).save(
                root / "art" / "bad_color.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "png_color_outside_palette",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_invalid_filename(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (20, 15, 29, 255)).save(
                root / "art" / "Bad Name.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "invalid_asset_name",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_png_without_alpha_channel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGB", (16, 16), (20, 15, 29)).save(
                root / "art" / "missing_alpha.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "png_missing_alpha_channel",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_animation_without_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "anim").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (64, 16), (20, 15, 29, 255)).save(
                root / "anim" / "heartbeat.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "animation_metadata_missing",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_asset_without_provenance_record(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "fetch_plans").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (20, 15, 29, 255)).save(
                root / "art" / "untracked.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "asset_provenance_missing",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_wrong_tile_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art" / "tiles").mkdir(parents=True)
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (32, 32), (20, 15, 29, 255)).save(
                root / "art" / "tiles" / "tile_wrong_size.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "asset_dimension_mismatch",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_audio_name_without_event(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "audio").mkdir()
            (root / "docs").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            (root / "docs" / "EVENT_API.md").write_text(
                "| event | audio |\n| build_confirmed | sfx_build_confirm |\n",
                encoding="utf-8",
            )
            (root / "audio" / "sfx_unknown.wav").write_bytes(b"RIFF")

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "audio_event_unknown",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_allows_the_contract_ambient_heartbeat_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "audio" / "ambient").mkdir(parents=True)
            (root / "docs").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            (root / "docs" / "EVENT_API.md").write_text(
                "| event | audio |\n| build_confirmed | sfx_build_confirm |\n",
                encoding="utf-8",
            )
            (root / "audio" / "ambient" / "heartbeat_bed.wav").write_bytes(b"RIFF")

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertNotIn(
                "audio_event_unknown",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_reports_partial_alpha_in_production_png(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (20, 15, 29, 128)).save(
                root / "art" / "partial_alpha.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "png_partial_alpha",
                {issue["code"] for issue in report["issues"]["error"]},
            )

    def test_valid_tracked_tile_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art" / "tiles").mkdir(parents=True)
            (root / "fetch_plans").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (20, 15, 29, 255)).save(
                root / "art" / "tiles" / "tile_valid.png"
            )
            (root / "fetch_plans" / "valid.json").write_text(
                json.dumps({"target": "art/tiles/tile_valid.png"}),
                encoding="utf-8",
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertEqual(report["status"], "PASS")
            self.assertEqual(report["issues"]["error"], [])

    def test_reports_duplicate_asset_content_as_warning(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art").mkdir()
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            image = Image.new("RGBA", (16, 16), (20, 15, 29, 255))
            image.save(root / "art" / "duplicate_one.png")
            image.save(root / "art" / "duplicate_two.png")

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "duplicate_asset_content",
                {issue["code"] for issue in report["issues"]["warning"]},
            )

    def test_source_candidate_palette_drift_is_non_blocking(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "art" / "candidates").mkdir(parents=True)
            (root / "art" / "palette.gpl").write_text(
                "GIMP Palette\n#\n#140F1D\n", encoding="utf-8"
            )
            Image.new("RGBA", (16, 16), (1, 2, 3, 255)).save(
                root / "art" / "candidates" / "source_raw.png"
            )

            result = self.run_checker(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            self.assertIn(
                "source_png_color_outside_palette",
                {issue["code"] for issue in report["issues"]["warning"]},
            )


if __name__ == "__main__":
    unittest.main()
