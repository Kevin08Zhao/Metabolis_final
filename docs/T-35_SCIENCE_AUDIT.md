# T-35 Scientific Accuracy Audit

Audit date: 2026-07-30

## Scope and method

This audit was performed in an independent blank-context review after T-07,
T-31, and T-34 were complete. It reviewed every scientific statement in:

- `docs/SCIENCE_NOTES.md`
- `docs/UI_COPY.md`
- the candidate evidence and boundary tables in
  `docs/BUILD_DECISION_SPEC.md`

The review separately checked post-fertilization time versus clinical
gestational age, developmental overlap, game-stage ordering, rare abnormalities,
correlation versus causation, diagnostic or treatment language, and every build
candidate. Sources were verified against NCBI/PubMed records, DOI metadata, the
WHO cord-clamping guidance, and the cited papers. Search and verification were
performed on 2026-07-30. Statements that could not be tied to a verified source
were not accepted.

AI-assisted research tools were used for retrieval and cross-checking. Every
reference and identifier reported below was independently resolved against its
publisher, PubMed, NCBI, Crossref, or WHO record.

## First-pass issues

Only problems are listed, as required by T-35. Suggested copy never exceeds the
original copy length.

| Original | Verdict | Problem | Required correction | Evidence |
|---|---|---|---|---|
| `Government public resource` for S1 and S5-S9 | Inaccurate | These are StatPearls chapters hosted by NCBI Bookshelf, not works authored or endorsed by the U.S. Government. | `NCBI-hosted StatPearls` | [NCBI Bookshelf disclaimer](https://www.ncbi.nlm.nih.gov/books/about/disclaimer/) |
| `Weeks 2-3: the blastocyst` | Inaccurate | The label obscures the bilaminar disc in week 2 and gastrulation/germ-layer establishment in week 3. | `Weeks 2-3: disc to layers` (25/25 characters) | [NCBI Embryology, Week 2-3](https://www.ncbi.nlm.nih.gov/books/NBK546679/) and [NCBI Embryology, Gastrulation](https://www.ncbi.nlm.nih.gov/books/NBK554394/) |
| `Weeks 9-38: the lungs form` | Inaccurate | Lower-respiratory development begins around day 22; weeks 9-38 continue differentiation and maturation rather than starting lung formation. | `Weeks 9-38: lungs mature` (24/26 characters) | [NCBI Embryology, Pulmonary](https://www.ncbi.nlm.nih.gov/books/NBK544372/) and [Human lung development review](https://pmc.ncbi.nlm.nih.gov/articles/PMC6124546/) |
| `at birth, placental flow stops and breathing begins` | Inaccurate | Breathing may begin while placental-newborn flow briefly continues before cord clamping. The original makes overlapping events sound instantaneous and synchronous. | `breathing begins while placental flow may continue` (50/51 characters) | [WHO delayed cord clamping](https://www.who.int/tools/elena/interventions/cord-clamping) and [NCBI Fetal Circulation](https://www.ncbi.nlm.nih.gov/books/NBK537149/) |
| `exchange tips before branches` | Inaccurate | Airway branching begins before exchange-region maturation. | `branches before exchange tips` | [NCBI Embryology, Pulmonary](https://www.ncbi.nlm.nih.gov/books/NBK544372/) and [Schittny 2017](https://pmc.ncbi.nlm.nih.gov/articles/PMC5320013/) |
| D10 had no candidate-to-evidence matrix | Inaccurate | T-35 could not determine which part of each candidate was source-supported and which part was only a game analogy. | Add all 14 candidate IDs, sources, supported steps, game-only boundaries, and keep/delete verdicts. | T-35 task contract and the cited candidate papers |
| `Turco and Moffett, Development, PMID 31049600` | Inaccurate | PMID 31049600 identifies a different placenta review. | Correct the PMID. | [Correct PubMed record](https://pubmed.ncbi.nlm.nih.gov/31776138/) |
| `Hikspoors et al., J Anat, PMID 35277594` | Inaccurate | The cited article was published in *Communications Biology*. | Correct the journal. | [PubMed record](https://pubmed.ncbi.nlm.nih.gov/35277594/) |
| `Greene and Copp, J Pathol, PMID 23790957` | Inaccurate | The cited article was authored by Copp, Stanier, and Greene and published in *The Lancet Neurology*. | Correct authors and journal. | [PubMed record](https://pubmed.ncbi.nlm.nih.gov/23790957/) |
| `Morrisey and Hogan, Dev Cell, PMID 24449833` | Inaccurate | The cited article was authored by Herriges and Morrisey and published in *Development*. | Correct authors and journal. | [PubMed record](https://pubmed.ncbi.nlm.nih.gov/24449833/) |
| `Gao and Raj, Physiol Rev, PMID 27942377` | Inaccurate | The cited article was published in *Pulmonary Circulation* and has six authors. | Correct authors and journal. | [PubMed record](https://pubmed.ncbi.nlm.nih.gov/27942377/) |

Before correction, the most dangerous sentence was `at birth, placental flow
stops and breathing begins`. It could make a player believe delivery itself
always ends placental circulation instantly and in synchrony with the first
breath, overlooking the overlapping transition before cord clamping.

## Candidate-by-candidate result

All 14 candidate IDs were rechecked in
`BUILD_DECISION_SPEC.md` table D10:

`cluster_compact`, `cluster_wave`, `placenta_exchange`,
`placenta_interface`, `layers_parallel`, `layers_staged`,
`heart_reinforced`, `heart_early_flow`, `neural_cranial`,
`neural_distributed`, `lung_branching`, `lung_maturation`,
`pulmonary_reserve`, and `pulmonary_transition`.

The cited sources establish the general processes used by the animations, but
none establishes the candidate's distinctive tier, build order, or rate as a
normal human developmental variation. Treating game-only engineering
differences as sufficient evidence would replace the stricter T-05d/T-35
contract with a weaker one. Table D10 therefore marks 14/14
`MUST_REDESIGN_OR_DELETE` and returns them to T-05d.

The current candidate IDs remain temporarily in the runnable build so this
audit does not silently destroy the implemented decision system. They cannot
receive T-35 scientific approval until T-05d supplies candidate-specific
evidence or replaces them with scientifically neutral city decisions and the
task owner approves that contract change.

## Required special checks

| Check | Final result |
|---|---|
| Post-fertilization time versus clinical gestational age | PASS — the two clocks remain distinct and the approximate two-week offset retains its uncertainty qualifier. |
| Developmental overlap and game order | PASS — the text explicitly states that stage order is instructional and not the real order of completed organ development. |
| Rare abnormality presented as universal | PASS — none found. |
| Correlation rewritten as causation | PASS — none remains after correcting the placental-flow transition. |
| Diagnostic, health-advice, or treatment claim | PASS — none found; the title disclaimer uses these terms only to reject medical use. |
| D10 candidate evidence | FAIL — 14/14 lack evidence for the candidate-specific normal human variation or rate difference required by T-05d and T-35. |
| Suggested-copy capacity | PASS — both changed guidance lines remain at or below 26 characters. |

## Final rerun

All first-pass player-facing inaccuracies and citation metadata errors were
corrected. The complete scope was reviewed again, but the D10 candidate
contract still fails.

**Not all accurate — T-05d candidate redesign is required.**

The most dangerous remaining claim would be that a cited general developmental
process proves a selectable candidate-specific normal human variant. That could
teach players that unsupported city tiers, timing, or resource tradeoffs are
recognized biological alternatives. The specification now explicitly rejects
that interpretation and records every affected candidate for upstream rework.
