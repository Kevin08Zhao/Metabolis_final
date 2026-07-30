class_name CityBuilderPrototype
extends Control

## Local interactive vertical slice for the map-first Metabolis rework.
##
## The player directly places a heart blueprint inside a guided anatomical zone,
## draws a vessel route from the existing source port, and commits the connected
## plan. The existing four-stage game remains available from the title screen.

enum Mode {
	READY,
	PLACING_HEART,
	ROUTING,
	CONSTRUCTING,
	OPERATING,
}

const LOG_PREFIX := "[BUILDER]"
const TILE_SIZE_PX := 16
const GRID_SIZE := Vector2i(40, 20)
const MAP_ORIGIN := Vector2(0, 40)
const HEART_FOOTPRINT := Vector2i(6, 6)
const HEART_ZONE := Rect2i(18, 3, 15, 14)
const SOURCE_ORIGIN := Vector2i(10, 9)
const SOURCE_FOOTPRINT := Vector2i(6, 6)
const SOURCE_PORT := Vector2i(16, 12)
const CONSTRUCTION_DURATION_SEC := 1.4

const COLOR_ZONE := Color(0.39, 0.87, 0.85, 0.16)
const COLOR_VALID := Color("#58d6a9")
const COLOR_INVALID := Color("#ef6f77")
const COLOR_ROUTE := Color("#5fd7ff")
const COLOR_ROUTE_FAILED := Color("#ff6b6b")
const COLOR_BOTTLENECK := Color("#ff3b4f")
const COLOR_SELECTED := Color("#fff2a8")
const COLOR_PORT := Color("#ffd166")
const COLOR_PANEL := Color(0.10, 0.05, 0.13, 0.94)

var _mode := Mode.READY
var _build_tool := BuildTool.new()
var _route_tool := RouteTool.new()
var _operation_tool := NetworkOperationTool.new()
var _hover_cell := Vector2i(-1, -1)
var _heart_port := Vector2i(-1, -1)
var _heart_state := &"blueprint"
var _construction_elapsed := 0.0
var _flow_phase := 0.0
var _stability_drain_accumulator := 0.0

var _nutrient_energy := 80
var _cell_material := 75
var _development_signal := 65
var _stability := 85
var _coverage := 0
var _pressure := 0

var _heart_blueprint: Texture2D = null
var _heart_construction: Texture2D = null
var _heart_operating: Texture2D = null
var _heart_cohesive: Texture2D = null
var _source_texture: Texture2D = null
var _path_textures: Array[Texture2D] = []

var _objective_label: Label = null
var _feedback_label: Label = null
var _resource_label: Label = null
var _coverage_label: Label = null
var _select_heart_button: Button = null
var _move_heart_button: Button = null
var _clear_route_button: Button = null
var _commit_button: Button = null
var _stress_button: Button = null
var _repair_button: Button = null
var _operation_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_build_tool.configure(
		GRID_SIZE,
		HEART_FOOTPRINT,
		HEART_ZONE,
		_rect_cells(Rect2i(SOURCE_ORIGIN, SOURCE_FOOTPRINT))
	)
	_load_textures()
	_build_interface()
	_set_feedback(
		"Select Place Heart, then click inside the teal body zone.",
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
			_heart_state = &"operating"
			_coverage = 100
			_pressure = NetworkOperationTool.NORMAL_PRESSURE
			_objective_label.text = (
				"System online: the early heart pump now moves material through "
				+ "the connected route. Use Stress Test to begin live operations."
			)
			_set_feedback(
				"Connection complete. Flow is live on your route.",
				false
			)
			_refresh_interface()
			print("%s Heart system operating." % LOG_PREFIX)
	if _mode == Mode.OPERATING:
		_flow_phase = fmod(_flow_phase + delta * 4.0, 1000.0)
		if _operation_tool.bottleneck_active:
			_stability_drain_accumulator += delta * 2.0
			var drain := floori(_stability_drain_accumulator)
			if drain > 0:
				_stability = maxi(_stability - drain, 55)
				_stability_drain_accumulator -= float(drain)
			_coverage = _operation_tool.coverage_percent()
			_pressure = _operation_tool.pressure_percent()
			_refresh_interface()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_pointer(event.position)
		if _mode == Mode.ROUTING and _route_tool.drawing:
			if not _route_tool.extend_to(_hover_cell):
				_set_feedback(
					"That route crosses a building or leaves the body-city grid.",
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
		if _mode == Mode.PLACING_HEART:
			_place_heart_at(_hover_cell)
		elif _mode == Mode.ROUTING:
			if not _route_tool.begin(_hover_cell):
				_set_feedback(
					"Begin the transport road at the amber source port.",
					true
				)
		elif _mode == Mode.OPERATING and _operation_tool.bottleneck_active:
			if _operation_tool.select_route_cell(_hover_cell):
				_set_feedback(
					"Bottleneck selected. Repair this route segment to restore flow.",
					false
				)
			else:
				_set_feedback("Select the flashing red route segment.", true)
			_refresh_interface()
	else:
		if _mode == Mode.ROUTING and _route_tool.drawing:
			if _route_tool.finish(_hover_cell):
				_coverage = 100
				_set_feedback(
					"Route connected. You may move the heart, erase the route, "
					+ "or commit the complete plan.",
					false
				)
			else:
				_coverage = 0
				_set_feedback(
					"Transport coverage is zero: the route did not reach the "
					+ "heart port. Drag again from the amber source.",
					true
				)
			_refresh_interface()
	queue_redraw()


func _draw() -> void:
	_draw_map()
	_draw_build_zone()
	_draw_source()
	_draw_route()
	_draw_bottleneck()
	_draw_heart()
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
			_mode == Mode.PLACING_HEART
			or (_mode == Mode.ROUTING and not _route_tool.route_complete)
		)
	)


func _draw_build_zone() -> void:
	if _mode != Mode.PLACING_HEART:
		return
	var zone_rect := Rect2(
		_grid_to_pixel(HEART_ZONE.position),
		Vector2(HEART_ZONE.size * TILE_SIZE_PX)
	)
	draw_rect(zone_rect, COLOR_ZONE)
	draw_rect(zone_rect, COLOR_VALID, false, 2.0)


func _draw_source() -> void:
	var rect := Rect2(
		_grid_to_pixel(SOURCE_ORIGIN),
		Vector2(SOURCE_FOOTPRINT * TILE_SIZE_PX)
	)
	if _source_texture != null:
		draw_texture_rect(_source_texture, rect, false)
	else:
		draw_rect(rect, Color("#c47f59"))


func _draw_heart() -> void:
	var origin := Vector2i(-1, -1)
	var valid := false
	if _mode == Mode.PLACING_HEART:
		origin = _build_tool.preview_origin
		valid = _build_tool.is_valid_origin(origin)
	elif _build_tool.has_placement():
		origin = _build_tool.placed_origin
		valid = true
	if origin.x < 0 or origin.y < 0:
		return

	var rect := Rect2(
		_grid_to_pixel(origin),
		Vector2(HEART_FOOTPRINT * TILE_SIZE_PX)
	)
	var texture := _heart_texture()
	if texture != null:
		draw_texture_rect(
			texture,
			rect,
			false,
			Color(1, 1, 1, 0.72 if _heart_state == &"blueprint" else 1.0)
		)
	else:
		draw_rect(rect, Color("#d65a67"))
	if _mode == Mode.PLACING_HEART:
		var outline := COLOR_VALID if valid else COLOR_INVALID
		draw_rect(rect, outline, false, 2.0)


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


func _draw_bottleneck() -> void:
	if not _operation_tool.bottleneck_active:
		return
	var cell := _operation_tool.bottleneck_cell
	if not _is_grid_cell(cell):
		return
	var pulse := 0.72 + sin(_flow_phase * 2.2) * 0.18
	draw_circle(_cell_center(cell), 10.0, Color(COLOR_BOTTLENECK, pulse))
	draw_line(
		_cell_center(cell) - Vector2(5, 5),
		_cell_center(cell) + Vector2(5, 5),
		Color.WHITE,
		2.0
	)
	draw_line(
		_cell_center(cell) + Vector2(-5, 5),
		_cell_center(cell) + Vector2(5, -5),
		Color.WHITE,
		2.0
	)
	if _operation_tool.selected_cell == cell:
		draw_circle(_cell_center(cell), 13.0, COLOR_SELECTED, false, 2.0)


func _draw_ports() -> void:
	draw_circle(_cell_center(SOURCE_PORT), 7.0, COLOR_PORT)
	draw_circle(_cell_center(SOURCE_PORT), 7.0, Color.WHITE, false, 1.5)
	if _heart_port.x >= 0:
		draw_circle(_cell_center(_heart_port), 7.0, COLOR_PORT)
		draw_circle(_cell_center(_heart_port), 7.0, Color.WHITE, false, 1.5)


func _draw_hover_cell() -> void:
	if not _is_grid_cell(_hover_cell):
		return
	if _mode not in [Mode.PLACING_HEART, Mode.ROUTING]:
		return
	var color := Color(1, 1, 1, 0.6)
	if _mode == Mode.PLACING_HEART:
		color = (
			COLOR_VALID
			if _build_tool.is_valid_origin(_hover_cell)
			else COLOR_INVALID
		)
	draw_rect(_cell_rect(_hover_cell), color, false, 2.0)


func _draw_flow_particles() -> void:
	if _mode != Mode.OPERATING:
		return
	var path := _operation_tool.flowing_path()
	if path.size() < 2:
		return
	for particle_index in range(4):
		var progress := fmod(
			_flow_phase + float(particle_index) * float(path.size()) / 4.0,
			float(path.size() - 1)
		)
		var segment := mini(floori(progress), path.size() - 2)
		var fraction := progress - float(segment)
		var position := _cell_center(path[segment]).lerp(
			_cell_center(path[segment + 1]),
			fraction
		)
		draw_circle(position, 3.0, Color("#ffe29a"))


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
		"Objective: place the early heart pump and connect it to the source network."
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
	tray_title.text = "BODY-CITY TOOLS"
	tray_title.add_theme_font_size_override("font_size", 10)
	tray.add_child(tray_title)

	_select_heart_button = _add_button(tray, "SelectHeart", "Place Heart")
	_select_heart_button.pressed.connect(_select_heart)
	_move_heart_button = _add_button(tray, "MoveHeart", "Move Heart")
	_move_heart_button.pressed.connect(_move_heart)
	_clear_route_button = _add_button(tray, "ClearRoute", "Erase Road")
	_clear_route_button.pressed.connect(_clear_route)
	_commit_button = _add_button(tray, "CommitPlan", "Commit Plan")
	_commit_button.pressed.connect(_commit_plan)

	var reset_button := _add_button(tray, "ResetPrototype", "Reset")
	reset_button.pressed.connect(_reset_prototype)
	var title_button := _add_button(tray, "ReturnToTitle", "Return to Title")
	title_button.pressed.connect(_return_to_title)

	var operation_panel := PanelContainer.new()
	operation_panel.name = "OperationsPanel"
	operation_panel.position = Vector2(648, 270)
	operation_panel.size = Vector2(144, 172)
	operation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(operation_panel)

	var operation_column := VBoxContainer.new()
	operation_column.name = "OperationContent"
	operation_column.add_theme_constant_override("separation", 4)
	operation_panel.add_child(operation_column)

	var operation_title := Label.new()
	operation_title.text = "NETWORK OPS"
	operation_title.add_theme_font_size_override("font_size", 10)
	operation_column.add_child(operation_title)

	_operation_label = Label.new()
	_operation_label.name = "OperationStatus"
	_operation_label.custom_minimum_size = Vector2(128, 30)
	_operation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_operation_label.add_theme_font_size_override("font_size", 10)
	operation_column.add_child(_operation_label)

	_stress_button = _add_button(
		operation_column,
		"StressNetwork",
		"Stress Test"
	)
	_stress_button.pressed.connect(_trigger_bottleneck)
	_repair_button = _add_button(
		operation_column,
		"RepairSegment",
		"Repair Segment"
	)
	_repair_button.pressed.connect(_repair_bottleneck)


func _add_button(parent: Container, node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(132, 25)
	parent.add_child(button)
	return button


func _select_heart() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_build_tool.clear()
	_route_tool.clear()
	_operation_tool.configure([])
	_heart_port = Vector2i(-1, -1)
	_heart_state = &"blueprint"
	_coverage = 0
	_pressure = 0
	_mode = Mode.PLACING_HEART
	_set_feedback(
		"Click a valid 6 × 6 position inside the teal zone.",
		false
	)
	_refresh_interface()
	queue_redraw()


func _place_heart_at(origin: Vector2i) -> bool:
	_build_tool.set_preview(origin)
	if not _build_tool.place_preview():
		_set_feedback(
			"The complete 6 × 6 footprint must stay inside the highlighted zone.",
			true
		)
		queue_redraw()
		return false
	_heart_port = Vector2i(origin.x - 1, origin.y + 2)
	var blocked := _rect_cells(Rect2i(SOURCE_ORIGIN, SOURCE_FOOTPRINT))
	blocked.append_array(_build_tool.placed_cells())
	_route_tool.configure(GRID_SIZE, SOURCE_PORT, _heart_port, blocked)
	_mode = Mode.ROUTING
	_set_feedback(
		"Drag from the amber source port to the amber heart port.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Heart blueprint placed at %s." % [LOG_PREFIX, origin])
	return true


func _move_heart() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_build_tool.move_placed_building()
	_route_tool.clear()
	_heart_port = Vector2i(-1, -1)
	_coverage = 0
	_mode = Mode.PLACING_HEART
	_set_feedback("Heart unlocked. Click a new valid map position.", false)
	_refresh_interface()
	queue_redraw()


func _clear_route() -> void:
	if _mode in [Mode.CONSTRUCTING, Mode.OPERATING]:
		return
	_route_tool.clear()
	_coverage = 0
	if _build_tool.has_placement():
		_mode = Mode.ROUTING
	_set_feedback(
		"Road erased. Drag again from the source port.",
		false
	)
	_refresh_interface()
	queue_redraw()


func _commit_plan() -> bool:
	if (
		_mode != Mode.ROUTING
		or not _build_tool.has_placement()
		or not _route_tool.route_complete
	):
		_set_feedback(
			"Place the heart and complete its transport road before committing.",
			true
		)
		return false
	_mode = Mode.CONSTRUCTING
	_heart_state = &"under_construction"
	_construction_elapsed = 0.0
	_nutrient_energy -= 24
	_cell_material -= 20
	_development_signal -= 12
	_operation_tool.configure(_route_tool.path())
	_pressure = NetworkOperationTool.NORMAL_PRESSURE
	_objective_label.text = (
		"Construction in progress: the connected heart pump is joining the "
		+ "body-city network."
	)
	_set_feedback(
		"Resources committed. The route and building position are now locked.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Plan committed." % LOG_PREFIX)
	return true


func _trigger_bottleneck() -> bool:
	if _mode != Mode.OPERATING:
		_set_feedback("Bring the connected heart system online first.", true)
		return false
	if not _operation_tool.trigger_bottleneck():
		_set_feedback("The network already has an unresolved bottleneck.", true)
		return false
	_coverage = _operation_tool.coverage_percent()
	_pressure = _operation_tool.pressure_percent()
	_stability_drain_accumulator = 0.0
	_objective_label.text = (
		"Transport bottleneck: click the flashing red route segment, then repair it."
	)
	_set_feedback(
		"Flow is restricted. Coverage fell and stability will keep declining.",
		true
	)
	_refresh_interface()
	queue_redraw()
	print(
		"%s Bottleneck at %s." % [
			LOG_PREFIX,
			_operation_tool.bottleneck_cell,
		]
	)
	return true


func _repair_bottleneck() -> bool:
	if not _operation_tool.bottleneck_active:
		_set_feedback("There is no active route bottleneck.", true)
		return false
	if _operation_tool.selected_cell != _operation_tool.bottleneck_cell:
		_set_feedback("Click the flashing red route segment before repairing.", true)
		return false
	## This older slice keeps its own local resource counters. It pays the
	## shared repair cost out of cell material so that one constant governs
	## every repair in the project.
	if not _operation_tool.repair(float(_cell_material)):
		_set_feedback(
			"Repair needs %d cell material."
			% int(NetworkOperationTool.REPAIR_BIOMASS_COST),
			true
		)
		return false
	_cell_material -= int(NetworkOperationTool.REPAIR_BIOMASS_COST)
	_coverage = _operation_tool.coverage_percent()
	_pressure = _operation_tool.pressure_percent()
	_stability = mini(_stability + 3, 85)
	_stability_drain_accumulator = 0.0
	_objective_label.text = (
		"Network recovered: material flow reaches the heart again."
	)
	_set_feedback(
		"Repair complete. Coverage recovered because the blocked segment reopened.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Bottleneck repaired." % LOG_PREFIX)
	return true


func _reset_prototype() -> void:
	_mode = Mode.READY
	_build_tool.clear()
	_route_tool.clear()
	_operation_tool.configure([])
	_hover_cell = Vector2i(-1, -1)
	_heart_port = Vector2i(-1, -1)
	_heart_state = &"blueprint"
	_construction_elapsed = 0.0
	_flow_phase = 0.0
	_stability_drain_accumulator = 0.0
	_nutrient_energy = 80
	_cell_material = 75
	_development_signal = 65
	_stability = 85
	_coverage = 0
	_pressure = 0
	_objective_label.text = (
		"Objective: place the early heart pump and connect it to the source network."
	)
	_set_feedback("Select the heart to begin direct map construction.", false)
	_refresh_interface()
	queue_redraw()


func _return_to_title() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to_title"):
			node.call_deferred("go_to_title")
			return
		node = node.get_parent()


func _update_pointer(local_position: Vector2) -> void:
	_hover_cell = _build_tool.pointer_to_grid(
		local_position,
		MAP_ORIGIN,
		TILE_SIZE_PX
	)
	if _mode == Mode.PLACING_HEART:
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
	_coverage_label.text = "Coverage %d%%   Pressure %d" % [
		_coverage,
		_pressure,
	]
	_select_heart_button.disabled = _mode in [
		Mode.CONSTRUCTING,
		Mode.OPERATING,
	]
	_move_heart_button.disabled = (
		not _build_tool.has_placement()
		or _mode in [Mode.CONSTRUCTING, Mode.OPERATING]
	)
	_clear_route_button.disabled = (
		_route_tool.path().is_empty()
		or _mode in [Mode.CONSTRUCTING, Mode.OPERATING]
	)
	_commit_button.disabled = (
		_mode != Mode.ROUTING
		or not _route_tool.route_complete
	)
	if _operation_label == null:
		return
	if _mode != Mode.OPERATING:
		_operation_label.text = "Bring the connected heart online."
	elif _operation_tool.bottleneck_active:
		_operation_label.text = (
			"Selected: repair ready"
			if _operation_tool.selected_cell == _operation_tool.bottleneck_cell
			else "Alert: click red segment"
		)
	else:
		_operation_label.text = "Flow stable. Test the network."
	_stress_button.disabled = (
		_mode != Mode.OPERATING
		or _operation_tool.bottleneck_active
	)
	_repair_button.disabled = not _operation_tool.can_repair(
		float(_cell_material)
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
	_heart_blueprint = AssetLoader.get_static_texture(&"organ_heart_blueprint")
	_heart_construction = AssetLoader.get_static_texture(
		&"organ_heart_under_construction"
	)
	_heart_operating = AssetLoader.get_static_texture(&"organ_heart_operating")
	_heart_cohesive = AssetLoader.get_static_texture(&"organ_heart_pump_v1")
	_source_texture = AssetLoader.get_static_texture(&"organ_placenta_harbor_v1")
	_path_textures = CohesiveMapVisuals.load_path_textures()


func _heart_texture() -> Texture2D:
	if _heart_cohesive != null:
		return _heart_cohesive
	match _heart_state:
		&"under_construction":
			return _heart_construction
		&"operating":
			return _heart_operating
		_:
			return _heart_blueprint


func _grid_to_pixel(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell * TILE_SIZE_PX)


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_to_pixel(cell) + Vector2.ONE * TILE_SIZE_PX * 0.5


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		_grid_to_pixel(cell),
		Vector2.ONE * TILE_SIZE_PX
	)


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


## Deterministic acceptance surface used by the local headless prototype test.
func debug_place_heart(origin: Vector2i) -> bool:
	_select_heart()
	return _place_heart_at(origin)


func debug_connect_route() -> bool:
	if _mode != Mode.ROUTING:
		return false
	if not _route_tool.begin(SOURCE_PORT):
		return false
	if not _route_tool.extend_to(_heart_port):
		return false
	var connected := _route_tool.finish(_heart_port)
	_coverage = 100 if connected else 0
	_refresh_interface()
	return connected


func debug_commit_plan() -> bool:
	return _commit_plan()


func debug_trigger_bottleneck() -> bool:
	return _trigger_bottleneck()


func debug_select_bottleneck() -> bool:
	return _operation_tool.select_route_cell(_operation_tool.bottleneck_cell)


func debug_repair_bottleneck() -> bool:
	return _repair_bottleneck()


func debug_snapshot() -> Dictionary:
	return {
		"mode": _mode,
		"heart_origin": _build_tool.placed_origin,
		"heart_port": _heart_port,
		"route": _route_tool.path(),
		"route_complete": _route_tool.route_complete,
		"coverage": _coverage,
		"pressure": _pressure,
		"bottleneck_active": _operation_tool.bottleneck_active,
		"bottleneck_cell": _operation_tool.bottleneck_cell,
		"selected_route_cell": _operation_tool.selected_cell,
		"repair_count": _operation_tool.repair_count,
		"resources": {
			"nutrient_energy": _nutrient_energy,
			"cell_material": _cell_material,
			"development_signal": _development_signal,
			"stability": _stability,
		},
	}
