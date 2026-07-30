# System Map Mode

## Player Model

The body-city is divided into four connected pages. Each page is one body system, and only unlocked pages can be opened. The map buttons and number keys `1` through `4` switch between unlocked systems.

| Order | Map | Facility | Delivery |
|---|---|---|---|
| 1 | Nutrient Exchange | Nutrient Exchange Depot | Nutrient delivery van |
| 2 | Circulatory System | Central Heart Transit Station | Circulation freight car |
| 3 | Nervous System | Neural Dispatch Center | Signal courier scooter |
| 4 | Respiratory System | Air Exchange Terminal | Oxygen delivery tram |

The Nutrient Exchange map is available at the start. A player places its 7 × 7 facility and dispatches cargo to unlock the Circulatory System. Repeating the same development action unlocks the Nervous and Respiratory systems in order.

## Cross-Boundary Transport

Every map has an incoming boundary gate, local staging point, facility input and output ports, and an outgoing boundary gate. Roads do not end at a decorative wall:

1. a delivery vehicle leaves the facility;
2. it follows the connected city road to the right edge;
3. it fades beneath the boundary gate and disappears;
4. the next map unlocks and opens;
5. the same delivery appears at the left boundary gate;
6. it follows the incoming road to that system's staging point.

Completed connections keep an ambient delivery vehicle moving on their road, so resource exchange remains visible after the initial unlock.

## Visual Rules

- The playable map remains 640 × 320 pixels inside the 800 × 450 interface.
- Map controls stay in the separate 160 pixel right rail.
- Objective and feedback text stay below the map.
- System facilities occupy 7 × 7 tiles, or 112 × 112 logical pixels.
- Delivery vehicles render at 64 × 42 logical pixels.
- Roads use transparent surroundings, preventing square tile backgrounds from covering the system-map art.
- All system maps use warm peach, coral, raspberry, cream, gold, and cyan accents.
- Vehicles replace abstract resource dots; no small-circle transport animation is used.

## PixelLab Asset Record

| Asset | PixelLab ID | Local file |
|---|---|---|
| Nutrient Exchange map | `67d0c34d-65c2-49d2-a6d4-874d2f4800ea` | `art/maps/system/map_nutrient_system_warm.png` |
| Circulatory map | `22a0f02e-80d0-4578-9968-5a7c3e5a5eb5` | `art/maps/system/map_circulation_system_warm.png` |
| Nervous map | `d7ba23e3-4405-4542-889a-ff11dffee3c9` | `art/maps/system/map_neural_system_warm.png` |
| Respiratory map | `ce62b031-cb0a-4c3f-a606-396984f718e6` | `art/maps/system/map_respiratory_system_warm.png` |
| Nutrient delivery van | `047d1e35-f93b-48a1-8ca0-d72f3a0df44e` | `art/vehicles/system/vehicle_nutrient_delivery.png` |
| Circulation freight car | `195b0408-b118-43ca-85a1-11b34a4f6e3f` | `art/vehicles/system/vehicle_circulation_freight.png` |
| Signal courier scooter | `f167297d-e7e2-49aa-b64d-1fe3748cf386` | `art/vehicles/system/vehicle_neural_courier.png` |
| Oxygen delivery tram | `6268e0f1-ebb4-401b-8f74-e476036cdd60` | `art/vehicles/system/vehicle_oxygen_tram.png` |
| Nutrient Exchange Depot | `7c5ce766-bfa9-4399-a3b2-923c20960ec7` candidate `02` | `art/buildings/system/building_nutrient_depot.png` |
| Central Heart Transit Station | `727d6b81-cbea-4328-a52e-6e1693fdbb01` candidate `08` | `art/buildings/system/building_circulation_station.png` |
| Neural Dispatch Center | `e9cd3f81-cad5-48b9-bd92-2ab1fe772692` candidate `08` | `art/buildings/system/building_neural_dispatch.png` |
| Air Exchange Terminal | `c9627adc-2e8d-408c-95b1-1d9113b150d8` candidate `03` | `art/buildings/system/building_respiratory_terminal.png` |
