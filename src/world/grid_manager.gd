class_name GridManager
extends Control

## Renders the Balance-driven map grid with ordinary Control nodes.
##
## Scene setup:
## 1. Add a Control node named GridManager below Main.
## 2. Attach res://world/grid_manager.gd.
## 3. Set Position to (0, 40), the fixed playable-region origin from GRID_BASELINE.
## 4. Leave child nodes empty; this script creates every ColorRect and hover overlay.
## 5. Connect slot_hovered and slot_unhovered to the build-decision presenter.
##
## Solid state colors:
## - UNAVAILABLE: #242A30 (dark neutral)
## - CANDIDATE:   #3F9B8F (teal)
## - OCCUPIED:    #B87537 (amber)
##
## Hovering the three heart_early_flow slots in order prints exactly:
## [GRID] slot_hovered slot_20_8
## [GRID] slot_unhovered slot_20_8
## [GRID] slot_hovered slot_26_8
## [GRID] slot_unhovered slot_26_8
## [GRID] slot_hovered slot_32_8
## [GRID] slot_unhovered slot_32_8

signal slot_hovered(slot_id: StringName)
signal slot_unhovered(slot_id: StringName)

enum CellState {
	UNAVAILABLE,
	CANDIDATE,
	OCCUPIED,
}

const STATE_TEXTURE_NAMES: Dictionary = {
	CellState.UNAVAILABLE: &"tile_tissue_ground",
	CellState.CANDIDATE: &"tile_construction_focus",
	CellState.OCCUPIED: &"tile_construction_background",
}
const FOOTPRINT_TILES: Dictionary = {
	&"standard_building": Vector2i(2, 2),
	&"landmark_organ": Vector2i(3, 3),
}

var _balance_access: Node
var _columns := 0
var _rows := 0
var _tile_size := 0
var _cells: Array[Array] = []
var _cell_states: Array[Array] = []
var _slot_overlays: Dictionary = {}
var _occupied_cells: Array[Vector2i] = []
var _state_textures: Dictionary = {}


func _ready() -> void:
	if _balance_access == null:
		configure(get_node_or_null("/root/Balance"))
	if _balance_access != null:
		rebuild_grid()


func configure(balance_access: Node) -> void:
	_balance_access = balance_access


func rebuild_grid() -> bool:
	if _balance_access == null:
		push_warning("[GRID] Cannot rebuild without Balance.")
		return false

	_columns = int(_balance_access.call("get_value", "build_options.grid.columns", 0))
	_rows = int(_balance_access.call("get_value", "build_options.grid.rows", 0))
	_tile_size = int(_balance_access.call("get_value", "build_options.grid.tile_size_px", 0))
	if _columns <= 0 or _rows <= 0 or _tile_size <= 0:
		push_warning("[GRID] Grid columns, rows, and tile size must be positive.")
		return false

	_clear_generated_nodes()
	_cells.clear()
	_cell_states.clear()
	_state_textures.clear()
	for state in STATE_TEXTURE_NAMES:
		_state_textures[state] = AssetLoader.get_static_texture(
			STATE_TEXTURE_NAMES[state]
		)
	for row in range(_rows):
		var cell_row: Array[TextureRect] = []
		var state_row: Array[CellState] = []
		for column in range(_columns):
			var cell := TextureRect.new()
			cell.name = "Cell_%d_%d" % [column, row]
			cell.position = Vector2(column * _tile_size, row * _tile_size)
			cell.size = Vector2(_tile_size, _tile_size)
			cell.texture = _state_textures[CellState.UNAVAILABLE]
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP
			cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cell)
			cell_row.append(cell)
			state_row.append(CellState.UNAVAILABLE)
		_cells.append(cell_row)
		_cell_states.append(state_row)

	size = Vector2(_columns * _tile_size, _rows * _tile_size)
	custom_minimum_size = size
	print("[GRID] rebuilt columns=", _columns, " rows=", _rows, " tile_size_px=", _tile_size)
	return true


func grid_dimensions() -> Vector2i:
	return Vector2i(_columns, _rows)


func tile_size_px() -> int:
	return _tile_size


func grid_to_world(grid_coordinate: Vector2i) -> Vector2:
	return global_position + Vector2(grid_coordinate * _tile_size)


func world_to_grid(world_position: Vector2) -> Vector2i:
	if _tile_size <= 0:
		return Vector2i(-1, -1)
	var local_position := world_position - global_position
	return Vector2i(
		floori(local_position.x / _tile_size),
		floori(local_position.y / _tile_size)
	)


func present_candidates(
	decision_id: StringName,
	option_id: StringName,
	occupied_cells: Array[Vector2i],
	blocked_cells: Array[Vector2i]
) -> Array[StringName]:
	var legal_slot_ids: Array[StringName] = []
	if _balance_access == null or _cells.is_empty():
		push_warning("[GRID] Cannot present candidates before the grid is ready.")
		return legal_slot_ids

	_reset_candidate_rendering()
	_occupied_cells = occupied_cells.duplicate()
	for occupied_cell in _occupied_cells:
		if _is_in_bounds(occupied_cell):
			_set_cell_state(occupied_cell, CellState.OCCUPIED)

	var option_path := "build_options.%s.%s" % [decision_id, option_id]
	var slot_id_values: Variant = _balance_access.call(
		"get_value",
		"%s.available_slot_ids" % option_path,
		[]
	)
	var coordinate_values: Variant = _balance_access.call(
		"get_value",
		"%s.slot_candidates" % option_path,
		[]
	)
	var footprint_id := StringName(
		_balance_access.call("get_value", "%s.footprint_id" % option_path, "")
	)
	if not slot_id_values is Array or not coordinate_values is Array:
		push_warning("[GRID] Candidate slot configuration must use arrays.")
		return legal_slot_ids
	var slot_ids: Array = slot_id_values
	var coordinates: Array = coordinate_values
	if slot_ids.size() < 2 or slot_ids.size() > 4 or slot_ids.size() != coordinates.size():
		push_warning("[GRID] Candidate configuration requires two to four matched IDs and coordinates.")
		return legal_slot_ids
	if not FOOTPRINT_TILES.has(footprint_id):
		push_warning("[GRID] Unknown footprint '%s'." % footprint_id)
		return legal_slot_ids

	var footprint_size: Vector2i = FOOTPRINT_TILES[footprint_id]
	var candidates: Array[Dictionary] = []
	for index in range(slot_ids.size()):
		var coordinate_value: Variant = coordinates[index]
		if not coordinate_value is Array or coordinate_value.size() != 2:
			push_warning("[GRID] Slot '%s' has an invalid coordinate." % slot_ids[index])
			continue
		var top_left := Vector2i(int(coordinate_value[0]), int(coordinate_value[1]))
		candidates.append({
			"slot_id": StringName(slot_ids[index]),
			"top_left": top_left,
			"rect": Rect2i(top_left, footprint_size),
			"cells": _expand_footprint(top_left, footprint_size),
		})

	for candidate in candidates:
		if not _candidate_is_legal(candidate, candidates, occupied_cells, blocked_cells):
			continue
		for cell_coordinate: Vector2i in candidate["cells"]:
			_set_cell_state(cell_coordinate, CellState.CANDIDATE)
		var slot_id: StringName = candidate["slot_id"]
		_create_slot_overlay(slot_id, candidate["rect"])
		legal_slot_ids.append(slot_id)

	return legal_slot_ids


func cell_state(grid_coordinate: Vector2i) -> CellState:
	if not _is_in_bounds(grid_coordinate):
		return CellState.UNAVAILABLE
	return _cell_states[grid_coordinate.y][grid_coordinate.x]


func commit_slot(
	decision_id: StringName,
	option_id: StringName,
	slot_id: StringName
) -> Array[Vector2i]:
	var option_path := "build_options.%s.%s" % [decision_id, option_id]
	var slot_ids: Variant = _balance_access.call(
		"get_value",
		"%s.available_slot_ids" % option_path,
		[]
	)
	var coordinates: Variant = _balance_access.call(
		"get_value",
		"%s.slot_candidates" % option_path,
		[]
	)
	var footprint_id := StringName(
		_balance_access.call("get_value", "%s.footprint_id" % option_path, "")
	)
	if (
		not slot_ids is Array
		or not coordinates is Array
		or not FOOTPRINT_TILES.has(footprint_id)
	):
		return []
	var slot_index := (slot_ids as Array).find(String(slot_id))
	if slot_index < 0 or slot_index >= (coordinates as Array).size():
		return []
	var coordinate: Variant = (coordinates as Array)[slot_index]
	if not coordinate is Array or coordinate.size() != 2:
		return []
	var cells := _expand_footprint(
		Vector2i(int(coordinate[0]), int(coordinate[1])),
		FOOTPRINT_TILES[footprint_id]
	)
	for cell_coordinate in cells:
		if not _occupied_cells.has(cell_coordinate):
			_occupied_cells.append(cell_coordinate)
	_reset_candidate_rendering()
	for cell_coordinate in _occupied_cells:
		_set_cell_state(cell_coordinate, CellState.OCCUPIED)
	return cells


func occupied_cells() -> Array[Vector2i]:
	return _occupied_cells.duplicate()


func _candidate_is_legal(
	candidate: Dictionary,
	all_candidates: Array[Dictionary],
	occupied_cells: Array[Vector2i],
	blocked_cells: Array[Vector2i]
) -> bool:
	for cell_coordinate: Vector2i in candidate["cells"]:
		if not _is_in_bounds(cell_coordinate):
			return false
		if occupied_cells.has(cell_coordinate) or blocked_cells.has(cell_coordinate):
			return false

	var candidate_rect: Rect2i = candidate["rect"]
	for other in all_candidates:
		if other["slot_id"] == candidate["slot_id"]:
			continue
		var other_rect: Rect2i = other["rect"]
		if candidate_rect.grow(1).intersects(other_rect):
			return false
	return true


func _expand_footprint(top_left: Vector2i, footprint_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(top_left.y, top_left.y + footprint_size.y):
		for column in range(top_left.x, top_left.x + footprint_size.x):
			result.append(Vector2i(column, row))
	return result


func _create_slot_overlay(slot_id: StringName, footprint_rect: Rect2i) -> void:
	var overlay := Control.new()
	overlay.name = "SlotOverlay_%s" % slot_id
	overlay.position = Vector2(footprint_rect.position * _tile_size)
	overlay.size = Vector2(footprint_rect.size * _tile_size)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_id))
	overlay.mouse_exited.connect(_on_slot_mouse_exited.bind(slot_id))
	add_child(overlay)
	_slot_overlays[slot_id] = overlay


func _set_cell_state(grid_coordinate: Vector2i, state: CellState) -> void:
	if not _is_in_bounds(grid_coordinate):
		return
	_cell_states[grid_coordinate.y][grid_coordinate.x] = state
	(_cells[grid_coordinate.y][grid_coordinate.x] as TextureRect).texture = (
		_state_textures[state]
	)


func _is_in_bounds(grid_coordinate: Vector2i) -> bool:
	return (
		grid_coordinate.x >= 0
		and grid_coordinate.y >= 0
		and grid_coordinate.x < _columns
		and grid_coordinate.y < _rows
	)


func _reset_candidate_rendering() -> void:
	for overlay in _slot_overlays.values():
		remove_child(overlay)
		overlay.queue_free()
	_slot_overlays.clear()
	for row in range(_rows):
		for column in range(_columns):
			_set_cell_state(Vector2i(column, row), CellState.UNAVAILABLE)


func _on_slot_mouse_entered(slot_id: StringName) -> void:
	print("[GRID] slot_hovered ", slot_id)
	slot_hovered.emit(slot_id)


func _on_slot_mouse_exited(slot_id: StringName) -> void:
	print("[GRID] slot_unhovered ", slot_id)
	slot_unhovered.emit(slot_id)


func _clear_generated_nodes() -> void:
	_slot_overlays.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
