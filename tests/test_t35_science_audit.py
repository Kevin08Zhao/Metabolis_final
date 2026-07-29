from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class T35ScienceAuditTest(unittest.TestCase):
    def test_corrected_guidance_copy_fits_locked_capacity(self) -> None:
        text = (ROOT / "docs" / "UI_COPY.md").read_text(encoding="utf-8")
        expected = {
            "stage_harbor.developmental_time": (
                "Weeks 2-3: disc to layers",
                25,
            ),
            "stage_birth.developmental_time": (
                "Weeks 9-38: lungs mature",
                24,
            ),
        }
        for key, (copy, reported_count) in expected.items():
            pattern = re.compile(
                rf"`TUTORIAL_STAGE\[{re.escape(key)}\]`"
                rf" \| `{re.escape(copy)}` \| (\d+) \|"
            )
            match = pattern.search(text)
            self.assertIsNotNone(match, key)
            self.assertEqual(int(match.group(1)), reported_count)
            self.assertEqual(len(copy), reported_count)
            self.assertLessEqual(len(copy), 26)
        self.assertIn("Week 1: cell to cluster", text)
        self.assertLessEqual(
            len(expected["stage_harbor.developmental_time"][0]),
            len("Weeks 2-3: the blastocyst"),
        )
        self.assertLessEqual(
            len(expected["stage_birth.developmental_time"][0]),
            len("Weeks 9-38: the lungs form"),
        )

    def test_all_candidates_have_t35_rework_verdicts(self) -> None:
        text = (ROOT / "docs" / "BUILD_DECISION_SPEC.md").read_text(
            encoding="utf-8"
        )
        candidates = {
            "cluster_compact",
            "cluster_wave",
            "placenta_exchange",
            "placenta_interface",
            "layers_parallel",
            "layers_staged",
            "heart_reinforced",
            "heart_early_flow",
            "neural_cranial",
            "neural_distributed",
            "lung_branching",
            "lung_maturation",
            "pulmonary_reserve",
            "pulmonary_transition",
        }
        matrix = text.split(
            "### D10 candidate-to-evidence review matrix", maxsplit=1
        )[1].split("## Table D11", maxsplit=1)[0]
        for candidate in candidates:
            self.assertRegex(
                matrix,
                rf"\| `{re.escape(candidate)}` \|.*"
                rf"\| `MUST_REDESIGN_OR_DELETE` \|",
            )
        self.assertEqual(
            matrix.count("| `MUST_REDESIGN_OR_DELETE` |"),
            len(candidates),
        )

    def test_known_inaccuracies_are_removed(self) -> None:
        science = (ROOT / "docs" / "SCIENCE_NOTES.md").read_text(
            encoding="utf-8"
        )
        build = (ROOT / "docs" / "BUILD_DECISION_SPEC.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("Government public resource", science)
        self.assertNotIn(
            "placental flow stops and breathing begins",
            science,
        )
        self.assertNotIn("exchange tips before branches", build)
        self.assertNotIn("PMID `31049600`", build)
        self.assertNotIn("*J Anat*, PMID `35277594`", build)
        self.assertNotIn("*J Pathol*, PMID `23790957`", build)
        self.assertNotIn("*Dev Cell*, PMID `24449833`", build)
        self.assertNotIn("*Physiol Rev*, PMID `27942377`", build)

    def test_audit_records_unresolved_upstream_rework(self) -> None:
        report = (ROOT / "docs" / "T-35_SCIENCE_AUDIT.md").read_text(
            encoding="utf-8"
        )
        review = (ROOT / "docs" / "T-35_INDEPENDENT_REVIEW.md").read_text(
            encoding="utf-8"
        )
        rework = (
            ROOT
            / "docs"
            / "coord"
            / "rework"
            / "T-35__from_CODEX.open.md"
        ).read_text(encoding="utf-8")
        self.assertIn("Not all accurate", report)
        self.assertIn("fork_turns=none", review)
        self.assertIn("status: OPEN", rework)
        self.assertFalse(
            (ROOT / "docs" / "coord" / "done" / "T-35.md").exists()
        )


if __name__ == "__main__":
    unittest.main()
