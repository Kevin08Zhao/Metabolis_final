# D-16 Bottleneck Marker Manifest

- Status: `PASS`
- PixelLab calls: `0`
- Canvas/anchor: `16x16`, center `(8,8)`
- Contrast: each marker combines `#140F1D` outer pixels and `#E8DCCF` inner support, remaining readable on both palette extremes.

| File | SHA-256 |
|---|---|
| `art/icons/ui_bottleneck_transport_pressure.png` | `1a397b3f8ad20c57a05f508e58c0b16163eda51d1b105aecade37e45ba766f0b` |
| `art/icons/ui_bottleneck_waste_accumulation.png` | `3f099d770c1238b423a86e97742f5b50621484e6f5f8e6d6abd040c7dd44e81f` |
| `art/icons/ui_bottleneck_signal_coverage_low.png` | `9448363d0e12187eac2d20947cc9a75d375cd546592d9d4a2c41e9fca0153703` |

| Bottleneck | Non-color E9 grammar | Organ anchor | Construction-zone anchor | Edge anchor |
|---|---|---|---|---|
| Transport pressure | Narrow-neck hexagon with two stacked directional arrows | Top-right, outside the identifying silhouette | Top edge, clear of progress structure | Centered above the affected edge |
| Waste accumulation | Graduated angular container with a visible bottom-up level | Lower-right, outside the organ body | Right edge, clear of corner marker | At the affected processing-node endpoint |
| Signal coverage low | Broken concentric rings with a gapped dotted wave | Centered outside the top edge | Upper-left, clear of progress structure | At the weakest-path endpoint |

English production descriptions:

- Transport pressure: Draw one 16x16 narrow-neck hexagonal marker with two stacked right-facing arrows at the neck, a one-pixel `#140F1D` outer boundary, and a light inner support edge.
- Waste accumulation: Draw one 16x16 graduated angular container with three measurement ticks and a clearly rising bottom level, using the same dark/light contrast support.
- Low signal coverage: Draw one 16x16 set of broken concentric rings around a dotted wave with a deliberate gap; the broken circular grammar must remain visible without color or animation.

All three use transparent padding, locked palette values, integer pixels, and no text, numbers, gradients, fourth type, or organ-specific variation.
