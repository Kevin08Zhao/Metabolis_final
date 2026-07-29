class_name NetworkOperationTool
extends RefCounted

## Minimal map-based operations model for the city-builder vertical slice.
## A route bottleneck is selected on the route itself and repaired with resources.

const INVALID_CELL := Vector2i(-1, -1)
const REPAIR_CELL_MATERIAL_COST := 6
const REPAIR_DEVELOPMENT_SIGNAL_COST := 8
const NORMAL_COVERAGE := 100
const BOTTLENECK_COVERAGE := 45
const NORMAL_PRESSURE := 12
const BOTTLENECK_PRESSURE := 82

var bottleneck_cell := INVALID_CELL
var selected_cell := INVALID_CELL
var bottleneck_active := false
var repair_count := 0

var _route: Array[Vector2i] = []


func configure(route: Array[Vector2i]) -> void:
	_route = route.duplicate()
	bottleneck_cell = INVALID_CELL
	selected_cell = INVALID_CELL
	bottleneck_active = false


func trigger_bottleneck() -> bool:
	if bottleneck_active or _route.size() < 5:
		return false
	var middle_index := clampi(_route.size() / 2, 2, _route.size() - 3)
	bottleneck_cell = _route[middle_index]
	selected_cell = INVALID_CELL
	bottleneck_active = true
	return true


func select_route_cell(cell: Vector2i) -> bool:
	if not bottleneck_active or cell != bottleneck_cell:
		selected_cell = INVALID_CELL
		return false
	selected_cell = cell
	return true


func can_repair(cell_material: int, development_signal: int) -> bool:
	return (
		bottleneck_active
		and selected_cell == bottleneck_cell
		and cell_material >= REPAIR_CELL_MATERIAL_COST
		and development_signal >= REPAIR_DEVELOPMENT_SIGNAL_COST
	)


func repair(cell_material: int, development_signal: int) -> bool:
	if not can_repair(cell_material, development_signal):
		return false
	bottleneck_active = false
	selected_cell = INVALID_CELL
	repair_count += 1
	return true


func coverage_percent() -> int:
	return BOTTLENECK_COVERAGE if bottleneck_active else NORMAL_COVERAGE


func pressure_percent() -> int:
	return BOTTLENECK_PRESSURE if bottleneck_active else NORMAL_PRESSURE


func flowing_path() -> Array[Vector2i]:
	if not bottleneck_active:
		return _route.duplicate()
	var index := _route.find(bottleneck_cell)
	if index < 0:
		return []
	return _route.slice(0, index + 1)


func route() -> Array[Vector2i]:
	return _route.duplicate()
