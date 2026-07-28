# D-02 Color-Vision and Grayscale Validation Report

## Review Method

This report reviews the initial D-01 palette. The same input was simulated under complete protanopia, deuteranopia, and tritanopia. A composite color difference below 10 fails, 10–15 is borderline, and a grayscale luminance difference below 10 fails. Dark, main, and light values are compared only with the corresponding value of an adjacent semantic group. An em dash means that the condition did not expose a problem. The table lists only problematic pairs.

## Findings

| Color pair | Normal vision | Protanopia | Deuteranopia | Tritanopia | Grayscale | Result | Smallest correction |
|---|---|---|---|---|---|---|---|
| Arterial coral `#9B3F4A/#E45F5F/#FF9B8C` and tissue pink `#884A64/#C97891/#F2B2BE` | All three borderline | Dark and light borderline | Dark and light borderline | All three fail | All three fail | FAIL | Lower coral luminance and raise tissue-pink luminance while preserving hue assignments |
| Arterial coral `#9B3F4A/#E45F5F` and warm amber `#92522A/#D98D32` | — | Dark borderline | Dark fails; main borderline | Dark and main fail | Dark and main fail | FAIL | Lower coral dark and main values; keep amber in the higher luminance band |
| Arterial coral `#9B3F4A/#E45F5F` and mint green `#356B55/#53AD7D` | — | Dark fails; main borderline | Dark and main fail | — | Dark and main fail | FAIL | Lower coral and raise mint; changing hue alone is forbidden |
| Oxygen blue `#245B7A` and blue violet `#4B536B` | Dark borderline | Dark fails | Dark fails | Dark borderline | Dark fails | FAIL | Raise oxygen-blue shadow luminance and lower blue-violet shadow luminance |
| Oxygen blue `#245B7A/#3B9BC5/#9FE2F4` and tissue pink `#884A64/#C97891/#F2B2BE` | — | Dark fails; main and light borderline | — | — | All three fail | FAIL | Move all oxygen-blue values into a luminance band above tissue pink |
| Oxygen blue `#245B7A/#3B9BC5/#9FE2F4` and warm amber `#92522A/#D98D32/#FFD06A` | — | — | — | — | All three fail | FAIL | Raise all three oxygen-blue values; do not add a new blue |
| Oxygen blue `#245B7A/#3B9BC5/#9FE2F4` and mint green `#356B55/#53AD7D/#A2E3B1` | — | — | — | All three fail | All three fail | FAIL | Separate their luminance bands while keeping oxygen blue below mint |
| Blue-violet shadow `#4B536B` and tissue-pink shadow `#884A64` | — | Fails | Borderline | — | Fails | FAIL | Lower the blue-violet waste value into the darkest resource band |
| Blue-violet shadow `#4B536B` and neutral dark `#443B49` | Borderline | Borderline | Borderline | Borderline | Fails | FAIL | Lower blue-violet shadow, raise neutral dark, and retain the global outline separator |
| Tissue pink `#884A64/#C97891/#F2B2BE` and warm amber `#92522A/#D98D32/#FFD06A` | — | — | — | All three fail | All three fail | FAIL | Put tissue pink in a distinct luminance band below amber |
| Tissue pink `#884A64/#C97891/#F2B2BE` and mint green `#356B55/#53AD7D/#A2E3B1` | — | — | All three fail | — | All three fail | FAIL | Lower tissue pink, raise mint, and preserve both assigned hues |
| Warm amber `#92522A/#D98D32/#FFD06A` and mint green `#356B55/#53AD7D/#A2E3B1` | — | All three borderline | — | — | All three fail | FAIL | Raise mint into a luminance band above amber |

## Adjustment and Retest Result

The exact substitutions are recorded in `PALETTE_HEX_ADJUSTMENTS.md`. After adjustment, the six resource anchors are ordered by grayscale luminance as waste, developmental signal, cell material, nutrient energy, knowledge badge, and stability. Semantic assignments did not change and no colors were added. Retesting must include the six fixed shapes in `ENCODING_SPEC.md`, because color is never the only signal.

The most dangerous original pair was arterial-coral shadow `#9B3F4A` and tissue-pink shadow `#884A64` under grayscale; their original grayscale luminance difference was approximately 0.1.
