# D-02 Color-Vision and Grayscale Validation Report

## Review Method

This report checks the final D-02 palette after the corrections in `PALETTE_HEX_ADJUSTMENTS.md`. Protanopia, deuteranopia, and tritanopia use the full-severity Machado, Oliveira, and Fernandes simulation matrices in linear sRGB. Normal and simulated colors are compared in CIE L*a*b* with the minimum corresponding dark/main/light `ΔE*ab`; grayscale uses the minimum corresponding `ΔL*`. A value below `10.00` fails. The simulation method is documented by the [Machado et al. paper](https://doi.org/10.1109/TVCG.2009.113) and the [Colour implementation](https://colour.readthedocs.io/en/develop/generated/colour.matrix_cvd_Machado2009.html).

## Pairwise Retest

| Color pair | Normal vision | Protanopia | Deuteranopia | Tritanopia | Grayscale | Result | Smallest correction |
|---|---:|---:|---:|---:|---:|---|---|
| Arterial coral / oxygen blue | `65.13` | `46.15` | `46.22` | `77.83` | `36.00` | PASS | None |
| Arterial coral / blue violet | `35.66` | `26.45` | `30.86` | `42.00` | `12.03` | PASS | None |
| Arterial coral / tissue pink | `28.94` | `24.30` | `26.47` | `29.31` | `11.94` | PASS | None |
| Arterial coral / warm amber | `41.24` | `31.49` | `22.71` | `33.80` | `24.02` | PASS | None |
| Arterial coral / mint green | `72.21` | `56.17` | `49.07` | `82.69` | `49.01` | PASS | None |
| Oxygen blue / blue violet | `48.92` | `46.59` | `44.52` | `48.09` | `43.31` | PASS | None |
| Oxygen blue / tissue pink | `41.38` | `27.53` | `23.56` | `49.19` | `24.03` | PASS | None |
| Oxygen blue / warm amber | `40.58` | `37.02` | `39.31` | `38.25` | `11.91` | PASS | None |
| Oxygen blue / mint green | `15.15` | `14.89` | `15.10` | `13.18` | `11.88` | PASS | None |
| Blue violet / tissue pink | `39.65` | `17.87` | `30.33` | `52.15` | `19.28` | PASS | None |
| Blue violet / warm amber | `71.87` | `68.93` | `74.67` | `53.86` | `31.39` | PASS | None |
| Blue violet / mint green | `72.20` | `68.28` | `62.40` | `60.85` | `55.18` | PASS | None |
| Tissue pink / warm amber | `38.42` | `36.98` | `31.53` | `14.74` | `12.06` | PASS | None |
| Tissue pink / mint green | `51.46` | `41.20` | `33.77` | `54.97` | `35.91` | PASS | None |
| Warm amber / mint green | `41.46` | `38.20` | `38.40` | `42.19` | `23.79` | PASS | None |

**ALL PASS**

## Required Final Answer

No pair fails the stated threshold. The most dangerous final pair is oxygen blue and mint green under grayscale, where the minimum corresponding-value separation is `ΔL* = 11.88`.
