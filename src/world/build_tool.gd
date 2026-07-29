class_name BuildTool
extends RefCounted

## Grid-snapped, anatomically constrained building placement for the interactive
## city-builder prototype. The tool owns placement rules, not presentation.

const INVALID_CELL := Vector2i(-1, -1)

var grid_size := Vector2i.ZERO
var footprint := Vector2i.ONE
var build_zone := Rect2i()
var preview_origin := INVALID_CELL
var placed_origin := INVALID_CELL
var blocked_cells: Array[Vector2i] = []


func configure(
	p_grid_size: Vector2i,
	p_footprint: Vector2i,
	p_build_zone: Rect2i,
	p_blocked_cells: Array[Vector2i] = []
) -> void:
	grid_size = p_grid_size
	footprint = p_footprint
	build_zone = p_build_zone
	blocked_cells = p_blocked_cells.duplicate()
	preview_origin = INVALID_CELL
	placed_origin = INVALID_CELL


func pointer_to_grid(
	local_position: Vector2,
	map_origin: Vector2,
	tile_size_px: int
) -> Vector2i:
	if tile_size_px <= 0:
		return INVALID_CELL
	var map_position := local_position - map_origin
	return Vector2i(
		floori(map_position.x / float(tile_size_px)),
		floori(map_position.y / float(tile_size_px))
	)


func set_preview(origin: Vector2i) -> bool:
	preview_origin = origin
	return is_valid_origin(origin)


func place_preview() -> bool:
	if not is_valid_origin(preview_origin):
		return false
	placed_origin = preview_origin
	return true


func move_placed_building() -> void:
	if placed_origin != INVALID_CELL:
		preview_origin = placed_origin
	placed_origin = INVALID_CELL


func clear() -> void:
	preview_origin = INVALID_CELL
	placed_origin = INVALID_CELL


func is_valid_origin(origin: Vector2i) -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return false
	if footprint.x <= 0 or footprint.y <= 0:
		return false
	for cell in footprint_cells(origin):
		if not _is_in_grid(cell):
			return false
		if not build_zone.has_point(cell):
			return false
		if blocked_cells.has(cell):
			return false
	return true


func footprint_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in range(origin.y, origin.y + footprint.y):
		for column in range(origin.x, origin.x + footprint.x):
			cells.append(Vector2i(column, row))
	return cells


func placed_cells() -> Array[Vector2i]:
	if placed_origin == INVALID_CELL:
		return []
	return footprint_cells(placed_origin)


func has_placement() -> bool:
	return placed_origin != INVALID_CELL


func _is_in_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)
