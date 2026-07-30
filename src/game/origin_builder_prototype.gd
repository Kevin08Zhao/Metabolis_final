class_name OriginBuilderPrototype
extends Control

## Map-first Origin slice. The player places a cell district, draws its nutrient
## conduit, commits construction, and performs three visible division cycles.

enum Mode {
	READY,
	PLACING_CLUSTER,
	ROUTING,
	CONSTRUCTING,
	OPERATING,
}

const LOG_PREFIX := "[ORIGIN BUILDER]"
const TILE_SIZE_PX := 16
const GRID_SIZE := Vector2i(40, 20)
const MAP_ORIGIN := Vector2(0, 40)
const CLUSTER_FOOTPRINT := Vector2i(6, 6)
const CLUSTER_ZONE := Rect2i(18, 3, 15, 14)
const SOURCE_ORIGIN := Vector2i(10, 9)
const SOURCE_FOOTPRINT := Vector2i(2, 2)
const SOURCE_PORT := Vector2i(12, 10)
const CONSTRUCTION_DURATION_SEC := 1.1
const REQUIRED_DIVISION_CYCLES := 3

const COLOR_ZONE := Color(0.39, 0.87, 0.85, 0.16)
const COLOR_VALID := Color("#58d6a9")
const COLOR_INVALID := Color("#ef6f77")
const COLOR_NUTRIENT_ROUTE := Color("#f1b45b")
const COLOR_PORT := Color("#ffe29a")
const COLOR_PANEL := Color(0.10, 0.05, 0.13, 0.94)
const COLOR_CELL := Color("#f189aa")
const COLOR_CELL_CORE := Color("#ffe1bb")

var _mode := Mode.READY
var _build_tool := BuildTool.new()
var _route_tool := RouteTool.new()
var _hover_cell := Vector2i(-1, -1)
var _cluster_port := Vector2i(-1, -1)
var _construction_elapsed := 0.0
var _flow_phase := 0.0
var _division_cycles := 0

var _nutrient_energy := 70
var _cell_material := 40
var _development_signal := 45
var _stability := 90
var _coverage := 0
var _cell_district_texture: Texture2D = null
var _path_textures: Array[Texture2D] = []

var _objective_label: Label = null
var _feedback_label: Label = null
var _resource_label: Label = null
var _coverage_label: Label = null
var _place_button: Button = null
var _move_button: Button = null
var _erase_button: Button = null
var _commit_button: Button = null
var _division_button: Button = null
var _continue_button: Button = null
var _operation_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_build_tool.configure(
		GRID_SIZE,
		CLUSTER_FOOTPRINT,
		CLUSTER_ZONE,
		_rect_cells(Rect2i(SOURCE_ORIGIN, SOURCE_FOOTPRINT))
	)
	_load_textures()
	_build_interface()
	_set_feedback(
		"Select Place Cell District, then click inside the teal origin zone.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Prototype ready." % LOG_PREFIX)


func _process(delta: float) -> void:
	if _mode == Mode.CONSTRUCTING:
		_construction_elapsed += delta
		if _construction_elapsed >= CONSTRUCTION_DURATION_SEC:
			_mode = Mode.OPERATING
			_coverage = 100
			_objective_label.text = (
				"Cell district online: run three division cycles while the "
				+ "district stays inside its established boundary."
			)
			_set_feedback(
				"The nutrient conduit is active. Run a division cycle.",
				false
			)
			_refresh_interface()
			print("%s Cell district operating." % LOG_PREFIX)
	if _mode == Mode.OPERATING:
		_flow_phase = fmod(_flow_phase + delta * 3.2, 1000.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_pointer(event.position)
		if _mode == Mode.ROUTING and _route_tool.drawing:
			if not _route_tool.extend_to(_hover_cell):
				_set_feedback(
					"The nutrient path cannot cross the district footprint.",
					true
				)
		queue_redraw()
		return

	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_update_pointer(event.position)
	if event.pressed:
		if _mode == Mode.PLACING_CLUSTER:
			_place_cluster_at(_hover_cell)
		elif _mode == Mode.ROUTING:
			if not _route_tool.begin(_hover_cell):
				_set_feedback("Begin at the amber origin port.", true)
	else:
		if _mode == Mode.ROUTING and _route_tool.drawing:
			if _route_tool.finish(_hover_cell):
				_coverage = 100
				_set_feedback(
					"Nutrient conduit connected. Commit the complete plan.",
					false
				)
			else:
				_coverage = 0
				_set_feedback(
					"Coverage is zero. The conduit must reach the district port.",
					true
				)
			_refresh_interface()
	queue_redraw()


func _draw() -> void:
	_draw_map()
	_draw_build_zone()
	_draw_origin_core()
	_draw_route()
	_draw_cluster()
	_draw_ports()
	_draw_hover_cell()
	_draw_flow_particles()


func _draw_map() -> void:
	CohesiveMapVisuals.draw_ground(
		self,
		MAP_ORIGIN,
		GRID_SIZE,
		TILE_SIZE_PX,
		(
			_mode == Mode.PLACING_CLUSTER
			or (_mode == Mode.ROUTING and not _route_tool.route_complete)
		)
	)


func _draw_build_zone() -> void:
	if _mode != Mode.PLACING_CLUSTER:
		return
	var zone_rect := Rect2(
		_grid_to_pixel(CLUSTER_ZONE.position),
		Vector2(CLUSTER_ZONE.size * TILE_SIZE_PX)
	)
	draw_rect(zone_rect, COLOR_ZONE)
	draw_rect(zone_rect, COLOR_VALID, false, 2.0)


func _draw_origin_core() -> void:
	var center := _grid_to_pixel(SOURCE_ORIGIN) + Vector2(16, 16)
	draw_circle(center, 15.0, Color("#c47f9b"))
	draw_circle(center, 10.0, Color("#8f4f78"))
	draw_circle(center, 4.0, COLOR_CELL_CORE)
	draw_circle(center, 15.0, Color.WHITE, false, 1.0)


func _draw_route() -> void:
	var path := _route_tool.path()
	CohesiveMapVisuals.draw_path(
		self,
		path,
		MAP_ORIGIN,
		TILE_SIZE_PX,
		_path_textures,
		_route_tool.route_failed and not _route_tool.route_complete
	)


func _draw_cluster() -> void:
	var origin := Vector2i(-1, -1)
	var valid := false
	if _mode == Mode.PLACING_CLUSTER:
		origin = _build_tool.preview_origin
		valid = _build_tool.is_valid_origin(origin)
	elif _build_tool.has_placement():
		origin = _build_tool.placed_origin
		valid = true
	if origin.x < 0 or origin.y < 0:
		return

	var rect := Rect2(
		_grid_to_pixel(origin),
		Vector2(CLUSTER_FOOTPRINT * TILE_SIZE_PX)
	)
	var outline := COLOR_VALID if valid else COLOR_INVALID
	if _mode == Mode.PLACING_CLUSTER:
		draw_rect(rect, Color(0.40, 0.18, 0.35, 0.24))
	var visible_cells := 4
	if _mode == Mode.CONSTRUCTING:
		visible_cells = 6
	elif _mode == Mode.OPERATING:
		visible_cells = 4 + _division_cycles * 4
	if (
		_mode == Mode.OPERATING
		and _division_cycles >= REQUIRED_DIVISION_CYCLES
		and _cell_district_texture != null
	):
		draw_texture_rect(_cell_district_texture, rect, false)
	else:
		var columns := mini(visible_cells, 4)
		var rows := ceili(float(visible_cells) / float(columns))
		var spacing := 18.0
		var start := rect.get_center() - Vector2(
			float(columns - 1) * spacing * 0.5,
			float(rows - 1) * spacing * 0.5
		)
		for index in range(visible_cells):
			var column := index % columns
			var row := index / columns
			var cell_center := start + Vector2(
				column * spacing,
				row * spacing
			)
			draw_circle(cell_center, 7.0, CohesiveMapVisuals.OUTLINE)
			draw_circle(cell_center, 6.0, COLOR_CELL)
			draw_rect(
				Rect2(cell_center - Vector2(1, 1), Vector2(2, 2)),
				COLOR_CELL_CORE
			)
	if _mode == Mode.PLACING_CLUSTER:
		draw_rect(rect, outline, false, 2.0)


func _draw_ports() -> void:
	draw_circle(_cell_center(SOURCE_PORT), 7.0, COLOR_PORT)
	draw_circle(_cell_center(SOURCE_PORT), 7.0, Color.WHITE, false, 1.5)
	if _cluster_port.x >= 0:
		draw_circle(_cell_center(_cluster_port), 7.0, COLOR_PORT)
		draw_circle(_cell_center(_cluster_port), 7.0, Color.WHITE, false, 1.5)


func _draw_hover_cell() -> void:
	if not _is_grid_cell(_hover_cell):
		return
	if _mode not in [Mode.PLACING_CLUSTER, Mode.ROUTING]:
		return
	var color := Color(1, 1, 1, 0.6)
	if _mode == Mode.PLACING_CLUSTER:
		color = (
			COLOR_VALID
			if _build_tool.is_valid_origin(_hover_cell)
			else COLOR_INVALID
		)
	draw_rect(_cell_rect(_hover_cell), color, false, 2.0)


func _draw_flow_particles() -> void:
	if _mode != Mode.OPERATING:
		return
	var path := _route_tool.path()
	if path.size() < 2:
		return
	for particle_index in range(3):
		var progress := fmod(
			_flow_phase + float(particle_index) * float(path.size()) / 3.0,
			float(path.size() - 1)
		)
		var segment := mini(floori(progress), path.size() - 2)
		var fraction := progress - float(segment)
		var position := _cell_center(path[segment]).lerp(
			_cell_center(path[segment + 1]),
			fraction
		)
		draw_circle(position, 3.0, COLOR_CELL_CORE)


func _build_interface() -> void:
	var hud := ColorRect.new()
	hud.name = "TopHud"
	hud.position = Vector2.ZERO
	hud.size = Vector2(800, 40)
	hud.color = COLOR_PANEL
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	_resource_label = Label.new()
	_resource_label.name = "Resources"
	_resource_label.position = Vector2(12, 5)
	_resource_label.size = Vector2(500, 30)
	_resource_label.add_theme_font_size_override("font_size", 10)
	hud.add_child(_resource_label)

	_coverage_label = Label.new()
	_coverage_label.name = "Coverage"
	_coverage_label.position = Vector2(530, 5)
	_coverage_label.size = Vector2(258, 30)
	_coverage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coverage_label.add_theme_font_size_override("font_size", 10)
	hud.add_child(_coverage_label)

	var side_rail := ColorRect.new()
	side_rail.name = "ControlRail"
	side_rail.position = Vector2(640, 40)
	side_rail.size = Vector2(160, 410)
	side_rail.color = COLOR_PANEL
	side_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_rail)

	var info_panel := PanelContainer.new()
	info_panel.name = "MapInformation"
	info_panel.position = Vector2(8, 368)
	info_panel.size = Vector2(624, 74)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_panel)

	var info_column := VBoxContainer.new()
	info_column.name = "InformationContent"
	info_column.add_theme_constant_override("separation", 3)
	info_panel.add_child(info_column)

	_objective_label = Label.new()
	_objective_label.name = "Objective"
	_objective_label.text = (
		"Origin objective: establish the first cell district and nutrient conduit."
	)
	_objective_label.custom_minimum_size = Vector2(610, 31)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 10)
	info_column.add_child(_objective_label)

	_feedback_label = Label.new()
	_feedback_label.name = "Feedback"
	_feedback_label.custom_minimum_size = Vector2(610, 28)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 10)
	info_column.add_child(_feedback_label)

	var tool_panel := PanelContainer.new()
	tool_panel.name = "BuildTray"
	tool_panel.position = Vector2(648, 48)
	tool_panel.size = Vector2(144, 210)
	tool_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tool_panel)

	var tray := VBoxContainer.new()
	tray.name = "TrayContent"
	tray.add_theme_constant_override("separation", 4)
	tool_panel.add_child(tray)

	var tray_title := Label.new()
	tray_title.text = "ORIGIN TOOLS"
	tray_title.add_theme_font_size_override("font_size", 10)
	tray.add_child(tray_title)

	_place_button = _add_button(tray, "PlaceCluster", "Place Cell District")
	_place_button.pressed.connect(_select_cluster)
	_move_button = _add_button(tray, "MoveCluster", "Move District")
	_move_button.pressed.connect(_move_cluster)
	_erase_button = _add_button(tray, "ClearConduit", "Erase Conduit")
	_erase_button.pressed.connect(_clear_route)
	_commit_button = _add_button(tray, "CommitOrigin", "Commit Plan")
	_commit_button.pressed.connect(_commit_plan)

	var reset_button := _add_button(tray, "ResetOrigin", "Reset")
	reset_button.pressed.connect(_reset_prototype)
	var title_button := _add_button(tray, "ReturnToTitle", "Return to Title")
	title_button.pressed.connect(_return_to_title)

	var operation_panel := PanelContainer.new()
	operation_panel.name = "GrowthPanel"
	operation_panel.position = Vector2(648, 270)
	operation_panel.size = Vector2(144, 172)
	operation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(operation_panel)

	var operation_column := VBoxContainer.new()
	operation_column.name = "GrowthContent"
	operation_column.add_theme_constant_override("separation", 4)
	operation_panel.add_child(operation_column)

	var operation_title := Label.new()
	operation_title.text = "CELL OPERATIONS"
	operation_title.add_theme_font_size_override("font_size", 10)
	operation_column.add_child(operation_title)

	_operation_label = Label.new()
	_operation_label.name = "GrowthStatus"
	_operation_label.custom_minimum_size = Vector2(128, 30)
	_operation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_operation_label.add_theme_font_size_override("font_size", 10)
	operation_column.add_child(_operation_label)

	_division_button = _add_button(
		operation_column,
		"RunDivision",
		"Run Division"
	)
	_division_button.pressed.connect(_run_division_cycle)
	_continue_button = _add_button(
		operation_column,
		"ContinueHeart",
		"Continue to Heart"
	)
	_continue_button.pressed.connect(_continue_to_heart)


func _add_button(parent: Container, node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(132, 25)
	parent.add_child(button)
	return button


func _select_cluster() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_build_tool.clear()
	_route_tool.clear()
	_cluster_port = Vector2i(-1, -1)
	_division_cycles = 0
	_coverage = 0
	_mode = Mode.PLACING_CLUSTER
	_set_feedback("Click a valid 6 × 6 position inside the teal zone.", false)
	_refresh_interface()
	queue_redraw()


func _place_cluster_at(origin: Vector2i) -> bool:
	_build_tool.set_preview(origin)
	if not _build_tool.place_preview():
		_set_feedback(
			"The complete 6 × 6 district must stay inside the origin zone.",
			true
		)
		queue_redraw()
		return false
	_cluster_port = Vector2i(origin.x - 1, origin.y + 2)
	var blocked := _rect_cells(Rect2i(SOURCE_ORIGIN, SOURCE_FOOTPRINT))
	blocked.append_array(_build_tool.placed_cells())
	_route_tool.configure(GRID_SIZE, SOURCE_PORT, _cluster_port, blocked)
	_mode = Mode.ROUTING
	_set_feedback(
		"Drag from the amber origin port to the district port.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Cell district placed at %s." % [LOG_PREFIX, origin])
	return true


func _move_cluster() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_build_tool.move_placed_building()
	_route_tool.clear()
	_cluster_port = Vector2i(-1, -1)
	_coverage = 0
	_mode = Mode.PLACING_CLUSTER
	_set_feedback("District unlocked. Click a new valid position.", false)
	_refresh_interface()
	queue_redraw()


func _clear_route() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_route_tool.clear()
	_coverage = 0
	if _build_tool.has_placement():
		_mode = Mode.ROUTING
	_set_feedback("Conduit erased. Drag again from the origin port.", false)
	_refresh_interface()
	queue_redraw()


func _commit_plan() -> bool:
	if (
		_mode != Mode.ROUTING
		or not _build_tool.has_placement()
		or not _route_tool.route_complete
	):
		_set_feedback(
			"Place the district and complete its conduit before committing.",
			true
		)
		return false
	_mode = Mode.CONSTRUCTING
	_construction_elapsed = 0.0
	_nutrient_energy -= 12
	_cell_material -= 8
	_development_signal -= 6
	_objective_label.text = (
		"Construction in progress: the first cell district is organizing."
	)
	_set_feedback(
		"Resources committed. District position and conduit are locked.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Plan committed." % LOG_PREFIX)
	return true


func _run_division_cycle() -> bool:
	if _mode != Mode.OPERATING:
		_set_feedback("Bring the cell district online first.", true)
		return false
	if _division_cycles >= REQUIRED_DIVISION_CYCLES:
		_set_feedback("The required division cycles are complete.", false)
		return false
	if _nutrient_energy < 2:
		_set_feedback("Division needs 2 nutrient energy.", true)
		return false
	_nutrient_energy -= 2
	_cell_material += 3
	_division_cycles += 1
	if _division_cycles >= REQUIRED_DIVISION_CYCLES:
		_objective_label.text = (
			"Origin complete: cell count increased through repeated division "
			+ "without the district growing in the same proportion."
		)
		_set_feedback(
			"Development goal complete. Continue to the heart construction demo.",
			false
		)
	else:
		_set_feedback(
			"Division cycle %d/%d: more cells now share the district."
			% [_division_cycles, REQUIRED_DIVISION_CYCLES],
			false
		)
	_refresh_interface()
	queue_redraw()
	print(
		"%s Division cycle %d/%d."
		% [LOG_PREFIX, _division_cycles, REQUIRED_DIVISION_CYCLES]
	)
	return true


func _continue_to_heart() -> bool:
	if _division_cycles < REQUIRED_DIVISION_CYCLES:
		_set_feedback("Complete all three division cycles first.", true)
		return false
	var router := _find_router()
	if router == null or not router.has_method("open_builder_prototype"):
		_set_feedback("The heart prototype route is unavailable.", true)
		return false
	router.call_deferred("open_builder_prototype")
	return true


func _reset_prototype() -> void:
	_mode = Mode.READY
	_build_tool.clear()
	_route_tool.clear()
	_hover_cell = Vector2i(-1, -1)
	_cluster_port = Vector2i(-1, -1)
	_construction_elapsed = 0.0
	_flow_phase = 0.0
	_division_cycles = 0
	_nutrient_energy = 70
	_cell_material = 40
	_development_signal = 45
	_stability = 90
	_coverage = 0
	_objective_label.text = (
		"Origin objective: establish the first cell district and nutrient conduit."
	)
	_set_feedback("Select Place Cell District to begin.", false)
	_refresh_interface()
	queue_redraw()


func _return_to_title() -> void:
	var router := _find_router()
	if router != null and router.has_method("go_to_title"):
		router.call_deferred("go_to_title")


func _find_router() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to_title"):
			return node
		node = node.get_parent()
	return null


func _update_pointer(local_position: Vector2) -> void:
	_hover_cell = _build_tool.pointer_to_grid(
		local_position,
		MAP_ORIGIN,
		TILE_SIZE_PX
	)
	if _mode == Mode.PLACING_CLUSTER:
		_build_tool.set_preview(_hover_cell)


func _refresh_interface() -> void:
	if _resource_label == null:
		return
	_resource_label.text = "N %d   C %d   S %d   Stability %d" % [
		_nutrient_energy,
		_cell_material,
		_development_signal,
		_stability,
	]
	_coverage_label.text = "Nutrient coverage: %d%%" % _coverage
	_place_button.disabled = _mode in [Mode.CONSTRUCTING, Mode.OPERATING]
	_move_button.disabled = (
		not _build_tool.has_placement()
		or _mode in [Mode.CONSTRUCTING, Mode.OPERATING]
	)
	_erase_button.disabled = (
		_route_tool.path().is_empty()
		or _mode in [Mode.CONSTRUCTING, Mode.OPERATING]
	)
	_commit_button.disabled = (
		_mode != Mode.ROUTING
		or not _route_tool.route_complete
	)
	if _mode != Mode.OPERATING:
		_operation_label.text = "Bring the cell district online."
	elif _division_cycles >= REQUIRED_DIVISION_CYCLES:
		_operation_label.text = "Origin goal complete."
	else:
		_operation_label.text = "Division cycles: %d/%d" % [
			_division_cycles,
			REQUIRED_DIVISION_CYCLES,
		]
	_division_button.disabled = (
		_mode != Mode.OPERATING
		or _division_cycles >= REQUIRED_DIVISION_CYCLES
	)
	_continue_button.disabled = (
		_mode != Mode.OPERATING
		or _division_cycles < REQUIRED_DIVISION_CYCLES
	)


func _set_feedback(message: String, is_error: bool) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(
		"font_color",
		COLOR_INVALID if is_error else Color("#d9f6ee")
	)


func _load_textures() -> void:
	_cell_district_texture = AssetLoader.get_static_texture(
		&"organ_cell_district_v2"
	)
	_path_textures = CohesiveMapVisuals.load_path_textures()


func _grid_to_pixel(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell * TILE_SIZE_PX)


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_to_pixel(cell) + Vector2.ONE * TILE_SIZE_PX * 0.5


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_grid_to_pixel(cell), Vector2.ONE * TILE_SIZE_PX)


func _is_grid_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < GRID_SIZE.x
		and cell.y < GRID_SIZE.y
	)


func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(rect.position.y, rect.end.y):
		for column in range(rect.position.x, rect.end.x):
			result.append(Vector2i(column, row))
	return result


func debug_place_cluster(origin: Vector2i) -> bool:
	_select_cluster()
	return _place_cluster_at(origin)


func debug_connect_route() -> bool:
	if _mode != Mode.ROUTING:
		return false
	if not _route_tool.begin(SOURCE_PORT):
		return false
	if not _route_tool.extend_to(_cluster_port):
		return false
	var connected := _route_tool.finish(_cluster_port)
	_coverage = 100 if connected else 0
	_refresh_interface()
	return connected


func debug_commit_plan() -> bool:
	return _commit_plan()


func debug_run_division_cycle() -> bool:
	return _run_division_cycle()


func debug_snapshot() -> Dictionary:
	return {
		"mode": _mode,
		"cluster_origin": _build_tool.placed_origin,
		"cluster_port": _cluster_port,
		"route": _route_tool.path(),
		"route_complete": _route_tool.route_complete,
		"coverage": _coverage,
		"division_cycles": _division_cycles,
		"origin_complete": _division_cycles >= REQUIRED_DIVISION_CYCLES,
		"resources": {
			"nutrient_energy": _nutrient_energy,
			"cell_material": _cell_material,
			"development_signal": _development_signal,
			"stability": _stability,
		},
	}
