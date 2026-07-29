# T-35 Independent Blank-Context Review Record

Review date: 2026-07-30

## Reproducibility record

- Reviewer task: `/root/t35_science_audit`
- Context mode: `fork_turns=none`; no parent conversation was inherited
- Input commit: `79d198dd4d26ba8d4709884c17bbc0a9f3cadb98`
- Inputs supplied: the canonical T-35 prompt, `docs/SCIENCE_NOTES.md`,
  `docs/UI_COPY.md`, and `docs/BUILD_DECISION_SPEC.md`
- Write access used by reviewer: none
- Required output: five-column problem table, special-check results, and the
  most dangerous statement

This record preserves the independent review result in the repository so the
blank-context requirement is auditable rather than asserted only by the task
author.

## Independent first-pass result

The reviewer returned **FAIL** and identified these required corrections:

| Original | Verdict | Problem | Suggested correction | Evidence |
|---|---|---|---|---|
| `Government public resource` | Inaccurate | NCBI Bookshelf hosts the StatPearls chapters but does not make them U.S. Government-authored or endorsed resources. | `NCBI-hosted StatPearls` | [NCBI Bookshelf disclaimer](https://www.ncbi.nlm.nih.gov/books/about/disclaimer/) |
| `Weeks 2-3: the blastocyst` | Inaccurate | The label obscures the week-2 bilaminar disc and week-3 gastrulation/germ layers. | Use a disc/layers label no longer than the original. | [NCBI Week 2-3](https://www.ncbi.nlm.nih.gov/books/NBK546679/) |
| `Weeks 9-38: the lungs form` | Inaccurate | Lower-respiratory formation starts near day 22; the later period continues maturation. | `Weeks 9-38: lungs mature` | [NCBI Pulmonary Embryology](https://www.ncbi.nlm.nih.gov/books/NBK544372/) |
| `at birth, placental flow stops and breathing begins` | Inaccurate | Breathing and continued placental-newborn flow can overlap before cord clamping. | State that breathing may begin while flow continues. | [WHO delayed cord clamping](https://www.who.int/tools/elena/interventions/cord-clamping) |
| `exchange tips before branches` | Inaccurate | Airway branching precedes exchange-region maturation. | `branches before exchange tips` | [Schittny 2017](https://pmc.ncbi.nlm.nih.gov/articles/PMC5320013/) |
| D10 without a candidate evidence matrix | Inaccurate | Candidate IDs, claimed differences, sources, supported steps, and verdicts could not be audited. | Add a complete candidate matrix and rerun T-35. | Canonical T-35 acceptance contract |

The reviewer found the time-basis distinction, developmental-overlap warning,
rare-abnormality boundary, and title disclaimer acceptable. The most dangerous
first-pass sentence was the instantaneous placental-flow/first-breath wording.

## Cross-review resolution

The first-pass wording and citation errors were corrected. A later
editor/ethics contract review found that general-process citations still did
not prove the candidate-specific normal human variations or rate differences
required by T-05d and T-35. The final audit therefore records 14
`MUST_REDESIGN_OR_DELETE` verdicts and does not create a T-35 done marker.
