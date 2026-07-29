# T-35 rework required from T-05d

status: OPEN
reported_at: 2026-07-30T01:57:13+08:00
reporter: CODEX
blocking_task: T-35
upstream_task: T-05d

## Blocking finding

All 14 current candidate IDs cite real general developmental processes, but
none has candidate-specific evidence that its distinctive tier, order, or rate
is a normal human developmental variation or developmental-rate difference.
The canonical T-05d/T-35 contract requires that evidence and requires an
unsupported candidate to be redesigned or deleted.

Affected candidates:

- `cluster_compact`
- `cluster_wave`
- `placenta_exchange`
- `placenta_interface`
- `layers_parallel`
- `layers_staged`
- `heart_reinforced`
- `heart_early_flow`
- `neural_cranial`
- `neural_distributed`
- `lung_branching`
- `lung_maturation`
- `pulmonary_reserve`
- `pulmonary_transition`

## Safety corrections already applied

- Candidate tradeoff descriptions now identify city metrics instead of
  presenting unsupported biological advantages.
- Both heart candidates begin pumping at the same visible beat.
- Both neural candidates show one neutral closure before city-route lighting;
  no disputed multi-initiation closure model is depicted.
- `layers_staged` highlights already completed outlines rather than forming the
  germ layers one at a time.
- Placenta candidates no longer claim unsupported alternative biological
  construction order.

## Required resolution

Choose one route and synchronize it across D1, D2, D5, D9, D10, D11,
`docs/BALANCE.json`, runtime option IDs, card art, animation metadata, tests,
and every downstream consumer:

1. Replace candidates with alternatives backed by candidate-specific evidence
   of normal human variation or developmental-rate difference.
2. Delete unsupported candidates and add supported replacements so each
   decision still meets the required candidate-count and balance contracts.
3. Obtain owner approval to revise the canonical T-05d contract so choices are
   explicitly city-engineering decisions rather than claimed human
   developmental variants.

T-35 must then run again in a new blank context. Do not rename this file to
`.resolved.md` or create `docs/coord/done/T-35.md` until the second audit returns
zero inaccurate entries.
