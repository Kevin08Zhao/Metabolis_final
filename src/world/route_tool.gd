class_name RouteTool
extends RefCounted

## Builds a player-authored orthogonal grid route between two compatible ports.
## Presentation and resource settlement remain the scene owner's responsibility.

var grid_size := Vector2i.ZERO
var source_port := Vector2i(-1, -1)
var target_port := Vector2i(-1, -1)
var blocked_cells: Array[Vector2i] = []
var drawing := false
var route_complete := false
var route_failed := false

var _path: Array[Vector2i] = []


func configure(
	p_grid_size: Vector2i,
	p_source_port: Vector2i,
	p_target_port: Vector2i,
	p_blocked_cells: Array[Vector2i]
) -> void:
	grid_size = p_grid_size
	source_port = p_source_port
	target_port = p_target_port
	blocked_cells = p_blocked_cells.duplicate()
	clear()


func begin(cell: Vector2i) -> bool:
	if cell != source_port:
		route_failed = true
		return false
	_path = [source_port]
	drawing = true
	route_complete = false
	route_failed = false
	return true


func extend_to(cell: Vector2i) -> bool:
	if not drawing or _path.is_empty() or not _is_in_grid(cell):
		return false
	var cursor := _path[-1]
	while cursor.x != cell.x:
		cursor.x += signi(cell.x - cursor.x)
		if not _append_cell(cursor):
			return false
	while cursor.y != cell.y:
		cursor.y += signi(cell.y - cursor.y)
		if not _append_cell(cursor):
			return false
	return true


func finish(cell: Vector2i) -> bool:
	if not drawing:
		return false
	extend_to(cell)
	drawing = false
	route_complete = not _path.is_empty() and _path[-1] == target_port
	route_failed = not route_complete
	return route_complete


func clear() -> void:
	_path.clear()
	drawing = false
	route_complete = false
	route_failed = false


func path() -> Array[Vector2i]:
	return _path.duplicate()


func is_contiguous() -> bool:
	if _path.is_empty():
		return false
	for index in range(1, _path.size()):
		var delta := _path[index] - _path[index - 1]
		if absi(delta.x) + absi(delta.y) != 1:
			return false
	return true


func _append_cell(cell: Vector2i) -> bool:
	if not _is_in_grid(cell):
		route_failed = true
		return false
	if blocked_cells.has(cell) and cell != target_port:
		route_failed = true
		return false
	if not _path.is_empty() and _path[-1] == cell:
		return true
	_path.append(cell)
	return true


func _is_in_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)
