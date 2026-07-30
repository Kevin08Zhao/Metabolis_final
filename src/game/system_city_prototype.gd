class_name SystemCityPrototype
extends Control

## Multi-map body-city prototype.
##
## Each page represents one body system. A system facility is placed directly
## on its page, then a city road carries a visible delivery vehicle to the map
## edge. The delivery continues from the next system's opposite edge, unlocking
## that page without pretending that the two maps share one physical canvas.

enum Mode {
	READY,
	PLACING,
	CONSTRUCTING,
	ROUTING,
	PLAN_READY,
	DELIVERY_OUT,
	DELIVERY_IN,
	BOTTLENECK,
	COMPLETE,
}

const LOG_PREFIX := "[SYSTEM CITY]"
const TILE_SIZE_PX := 16
const GRID_SIZE := Vector2i(40, 20)
const MAP_ORIGIN := Vector2(0, 40)
const MAP_SIZE := Vector2(640, 320)
const FACILITY_FOOTPRINT := Vector2i(6, 6)
const FULL_MAP_BUILD_ZONE := Rect2i(Vector2i.ZERO, GRID_SIZE)
const DEFAULT_BUILD_TIME_SEC := 3.0
## Biomass charged per road tile. Road cost depends on length and nothing else.
const ROAD_BIOMASS_COST_PER_TILE := 2.0
## A committed road tile keeps costing after it is built: it draws oxygen and
## it generates waste. This is where route length gains an ongoing consequence.
const ROAD_TILE_ECONOMY := {
	&"oxygen_demand": 0.03,
	&"waste_output": 0.01,
}
const REPAIR_BIOMASS_COST := 15.0
const BOTTLENECK_STABILITY_DRAIN_PER_SEC := 1.5
const STAGING_CELLS := [
	Vector2i(8, 10),
	Vector2i(8, 7),
	Vector2i(8, 12),
	Vector2i(8, 9),
]
const EXIT_ROWS := [10, 7, 12, 9]
const DELIVERY_SPEED_CELLS_PER_SEC := 7.0

const SYSTEMS := [
	{
		"id": &"system_nutrition",
		"name": "Nutrient Exchange",
		"short": "NUTRIENT",
		"facility": "Nutrient Exchange Depot",
		"map_asset": &"map_nutrient_system_warm",
		"building_asset": &"building_nutrient_depot",
		"vehicle_asset": &"vehicle_nutrient_delivery",
		"cargo": "nutrient cargo",
		"role": "The city's oxygen source and main producer",
		"accent": Color("#F4B860"),
		"facility_cost_biomass": 60.0,
		"build_time_sec": 3.0,
		## The exchange interface is the city's oxygen source and its largest
		## biomass producer. It clears only as much waste as it makes.
		"economy": {
			&"biomass_output": 3.0,
			&"oxygen_supply": 10.0,
			&"oxygen_demand": 2.0,
			&"waste_output": 0.40,
			&"waste_clearance": 0.40,
		},
		"bottleneck_required": true,
	},
	{
		"id": &"system_circulation",
		"name": "Circulatory System",
		"short": "CIRCULATION",
		"facility": "Central Heart Transit Station",
		"map_asset": &"map_circulation_system_warm",
		"building_asset": &"building_circulation_station",
		"vehicle_asset": &"vehicle_circulation_freight",
		"cargo": "circulation freight",
		"role": "The pump: this is what takes the waste out",
		"accent": Color("#E85D75"),
		"facility_cost_biomass": 80.0,
		"build_time_sec": 3.0,
		## The pump produces less biomass than the exchange but is the city's
		## clearance capacity. Building it visibly reverses the waste trend,
		## which is the teaching moment of the first two maps.
		"economy": {
			&"biomass_output": 1.5,
			&"oxygen_supply": 0.0,
			&"oxygen_demand": 3.0,
			&"waste_output": 0.30,
			&"waste_clearance": 1.10,
		},
		"bottleneck_required": false,
	},
	{
		"id": &"system_neural",
		"name": "Nervous System",
		"short": "NEURAL",
		"facility": "Neural Dispatch Center",
		"map_asset": &"map_neural_system_warm",
		"building_asset": &"building_neural_dispatch",
		"vehicle_asset": &"vehicle_neural_courier",
		"cargo": "signal parcels",
		"role": "Signal dispatch, and the biggest oxygen draw",
		"accent": Color("#D9A3E8"),
		"facility_cost_biomass": 90.0,
		"build_time_sec": 3.0,
		## Provisional. The nervous system is where the first real oxygen
		## deficit is meant to appear; see RESOURCE_ECONOMY_DESIGN section 4.5.
		"economy": {
			&"biomass_output": 1.0,
			&"oxygen_supply": 0.0,
			&"oxygen_demand": 8.0,
			&"waste_output": 0.50,
			&"waste_clearance": 0.20,
		},
		"bottleneck_required": true,
	},
	{
		"id": &"system_respiratory",
		"name": "Respiratory System",
		"short": "RESPIRATORY",
		"facility": "Air Exchange Terminal",
		"map_asset": &"map_respiratory_system_warm",
		"building_asset": &"building_respiratory_terminal",
		"vehicle_asset": &"vehicle_oxygen_tram",
		"cargo": "oxygen canisters",
		"role": "Gas exchange: the supply that pays the brain",
		"accent": Color("#9CE8DE"),
		"facility_cost_biomass": 100.0,
		"build_time_sec": 3.0,
		## Provisional. The lungs are what pay off the nervous system's oxygen
		## demand; see RESOURCE_ECONOMY_DESIGN section 4.5.
		"economy": {
			&"biomass_output": 1.0,
			&"oxygen_supply": 14.0,
			&"oxygen_demand": 3.0,
			&"waste_output": 0.30,
			&"waste_clearance": 0.50,
		},
		"bottleneck_required": false,
	},
]

const COLOR_PANEL := Color(0.10, 0.05, 0.13, 0.96)
const COLOR_PANEL_EDGE := Color("#C84F7C")
const COLOR_TEXT := Color("#FFF1E2")
const COLOR_MUTED := Color("#C6A8B8")
const COLOR_VALID := Color("#58D6A9")
const COLOR_INVALID := Color("#EF6F77")
const COLOR_PORT := Color("#FFD166")
const COLOR_PORTAL := Color("#62DDD8")
const COLOR_PORTAL_LIGHT := Color("#C8FFF4")
const COLOR_SHADOW := Color(0.12, 0.05, 0.14, 0.38)
const COLOR_NOTIFICATION_MUTED := Color("#817582")
const COMPLETION_NOTIFICATION_DURATION_SEC := 5.0
const COMPLETION_NOTIFICATION_POSITION := Vector2(400, 48)
const COMPLETION_NOTIFICATION_SIZE := Vector2(384, 96)
## The three flows shown in the header, in display order. Stability is not one
## of them: it is a state bar, built separately by `_build_stability_bar`.
const METRIC_ORDER: Array[StringName] = [
	&"biomass",
	&"oxygen",
	&"waste",
]
## Icon silhouettes are reused by role. ENCODING_SPEC fixes the shapes but not
## which resource owns which shape, so this needs no new art.
const METRIC_ICON_ASSETS := {
	&"biomass": {
		&"normal": &"ui_resource_nutrient_energy_sufficient",
		&"warning": &"ui_resource_nutrient_energy_insufficient",
	},
	&"oxygen": {
		&"normal": &"ui_resource_developmental_signal_sufficient",
		&"warning": &"ui_resource_developmental_signal_insufficient",
	},
	&"waste": {
		&"normal": &"ui_resource_cell_material_sufficient",
		&"warning": &"ui_resource_cell_material_insufficient",
	},
}
const METRIC_SHORT_NAMES := {
	&"biomass": "BIO",
	## The generated pixel font has no subscript glyph, and its capital O is
	## hard to tell from a zero, so the oxygen metric spells out three letters.
	&"oxygen": "OXY",
	&"waste": "WST",
}
const METRIC_DISPLAY_NAMES := {
	&"biomass": "BIOMASS",
	&"oxygen": "OXYGEN",
	&"waste": "WASTE",
}
const INFO_CARD_WIDTH := 272.0
const INFO_CARD_LINE_COUNT := 4
const STABILITY_BAR_SIZE := Vector2(150.0, 6.0)
const HOVER_PANEL_POSITION := Vector2(416.0, 42.0)
const HOVER_PANEL_WIDTH := 374.0

var _mode := Mode.READY
var _current_system_index := 0
var _unlocked_count := 1
var _hover_cell := Vector2i(-1, -1)
var _facility_origins: Dictionary = {}
var _outgoing_routes: Dictionary = {}
var _incoming_routes: Dictionary = {}
var _completed_dispatches: Dictionary = {}
var _delivery_path: Array[Vector2i] = []
var _delivery_progress := 0.0
var _delivery_system_index := 0
var _construction_elapsed := 0.0
var _construction_system_index := -1
var _ambient_phase := 0.0
var _route_dragging := false
var _pointer_position := Vector2.ZERO
var _pending_delivery_system_index := -1
var _resources := ResourcePool.new()
var _build_tools: Dictionary = {}
var _route_tools: Dictionary = {}
var _operation_tools: Dictionary = {}
var _route_metrics: Dictionary = {}
var _committed_systems: Dictionary = {}

var _map_textures: Dictionary = {}
var _building_textures: Dictionary = {}
var _vehicle_textures: Dictionary = {}
var _road_textures: Array[Texture2D] = []

var _system_title: Label = null
var _link_status: Label = null
var _resource_value_labels: Dictionary = {}
var _resource_icon_nodes: Dictionary = {}
var _resource_icon_textures: Dictionary = {}
var _metric_containers: Dictionary = {}
var _stability_bar_fill: ColorRect = null
var _stability_bar_label: Label = null
var _hover_panel: PanelContainer = null
var _hover_panel_column: VBoxContainer = null
var _hovered_metric: StringName = &""
var _latest_feedback := ""
var _latest_feedback_is_error := false
var _build_button: Button = null
var _dispatch_button: Button = null
var _route_button: Button = null
var _system_buttons: Array[Button] = []
var _build_preview_card: PanelContainer = null
var _build_preview_name: Label = null
var _build_preview_cost: Label = null
var _build_preview_time: Label = null
var _route_cost_bubble: PanelContainer = null
var _route_cost_label: Label = null
var _info_card: PanelContainer = null
var _info_name: Label = null
var _info_status: Label = null
var _info_subtitle: Label = null
var _info_lines: Array[Label] = []
var _completion_overlay: Control = null
var _completion_window: PanelContainer = null
var _completion_title: Label = null
var _completion_message: Label = null
var _completion_time: Label = null
var _completion_remaining_sec := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_resources.reset_economy()
	_load_textures()
	_build_interface()
	_initialize_gameplay_tools()
	_incoming_routes[_system_id(0)] = _entry_route_for(0)
	_set_feedback(
		"Place the Nutrient Exchange Depot, draw its road, then commit the network.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Prototype ready with %d system maps." % [LOG_PREFIX, SYSTEMS.size()])


func _process(delta: float) -> void:
	_ambient_phase = fmod(_ambient_phase + delta * 2.4, 10000.0)
	## The economy runs whenever a map is open, so every value the header shows
	## is a value that moves without the player pressing anything. Rates are
	## per second and integrated continuously.
	_resources.apply_tick(delta)
	_refresh_resource_status()
	if _completion_popup_visible():
		_completion_remaining_sec -= delta
		if _completion_remaining_sec <= 0.0:
			_dismiss_completion_popup()
	if _mode == Mode.CONSTRUCTING:
		_construction_elapsed += delta
		if _construction_elapsed >= _current_build_time_sec():
			_finish_facility_construction()
		else:
			_refresh_interface()
	elif _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_delivery_progress += delta * DELIVERY_SPEED_CELLS_PER_SEC
		if _delivery_progress >= float(_delivery_path.size()):
			_finish_delivery_leg()
	elif _mode == Mode.BOTTLENECK:
		_resources.stability = maxf(
			25.0,
			_resources.stability - BOTTLENECK_STABILITY_DRAIN_PER_SEC * delta
		)
		_refresh_interface()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_position = event.position
		_hover_cell = _pointer_to_grid(event.position)
		if _mode == Mode.PLACING:
			_current_build_tool().set_preview(_hover_cell)
		elif _mode == Mode.ROUTING and _route_dragging:
			_current_route_tool().extend_to(_hover_cell)
			_update_route_plan_feedback()
		_update_context_cards()
		queue_redraw()
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _mode in [Mode.ROUTING, Mode.PLAN_READY]:
			_clear_current_route()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_pointer_position = event.position
	_hover_cell = _pointer_to_grid(event.position)
	if event.pressed:
		match _mode:
			Mode.PLACING:
				_current_build_tool().set_preview(_hover_cell)
				_place_facility_at(_hover_cell)
			Mode.ROUTING:
				var route_tool := _current_route_tool()
				if route_tool.drawing:
					route_tool.extend_to(_hover_cell)
				elif not route_tool.begin(_hover_cell):
					_set_feedback(
						"Begin the route at the facility's gold output port.",
						true
					)
				_route_dragging = route_tool.drawing
				_update_route_plan_feedback()
				_update_context_cards()
				queue_redraw()
			Mode.BOTTLENECK:
				_select_bottleneck_at(_hover_cell)
		return
	if _mode != Mode.ROUTING or not _route_dragging:
		return
	var route_tool := _current_route_tool()
	route_tool.extend_to(_hover_cell)
	_route_dragging = false
	if _hover_cell == route_tool.target_port and route_tool.finish(_hover_cell):
		_mode = Mode.PLAN_READY
		_update_route_plan_feedback()
	else:
		_set_feedback(
			"Route extended. Continue from its end to the right boundary gate; right-click clears it.",
			false
		)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _completion_popup_visible() and event.keycode == KEY_ESCAPE:
		_dismiss_completion_popup()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_1:
			_switch_system(0)
		KEY_2:
			_switch_system(1)
		KEY_3:
			_switch_system(2)
		KEY_4:
			_switch_system(3)


func _draw() -> void:
	_draw_map_background()
	_draw_routes()
	_draw_boundary_portals()
	_draw_facility()
	_draw_ports()
	_draw_delivery()
	_draw_build_overlay()
	_draw_bottleneck_overlay()


func _draw_map_background() -> void:
	var texture: Texture2D = _map_textures.get(_system_id(), null)
	var rect := Rect2(MAP_ORIGIN, MAP_SIZE)
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		CohesiveMapVisuals.draw_ground(
			self,
			MAP_ORIGIN,
			GRID_SIZE,
			TILE_SIZE_PX,
			false
		)
	var accent: Color = SYSTEMS[_current_system_index]["accent"]
	draw_rect(rect, Color(accent, 0.06))
	draw_rect(rect, Color(accent, 0.40), false, 2.0)


func _draw_routes() -> void:
	var system_id := _system_id()
	var incoming: Array[Vector2i] = _route_for(_incoming_routes, system_id)
	var outgoing: Array[Vector2i] = _route_for(_outgoing_routes, system_id)
	CohesiveMapVisuals.draw_path(
		self,
		incoming,
		MAP_ORIGIN,
		TILE_SIZE_PX,
		_road_textures
	)
	CohesiveMapVisuals.draw_path(
		self,
		outgoing,
		MAP_ORIGIN,
		TILE_SIZE_PX,
		_road_textures
	)
	if (
		_mode in [Mode.ROUTING, Mode.PLAN_READY]
		and not _committed_systems.get(system_id, false)
	):
		CohesiveMapVisuals.draw_path(
			self,
			_current_route_tool().path(),
			MAP_ORIGIN,
			TILE_SIZE_PX,
			_road_textures
		)


func _draw_boundary_portals() -> void:
	var row: int = EXIT_ROWS[_current_system_index]
	_draw_portal(Vector2(0, row * TILE_SIZE_PX + MAP_ORIGIN.y), true)
	_draw_portal(Vector2(MAP_SIZE.x, row * TILE_SIZE_PX + MAP_ORIGIN.y), false)


func _draw_portal(anchor: Vector2, is_left: bool) -> void:
	var direction := 1.0 if is_left else -1.0
	var outer := PackedVector2Array([
		anchor + Vector2(0, -15),
		anchor + Vector2(direction * 12, -11),
		anchor + Vector2(direction * 12, 27),
		anchor + Vector2(0, 31),
	])
	draw_colored_polygon(outer, CohesiveMapVisuals.OUTLINE)
	var inner := PackedVector2Array([
		anchor + Vector2(0, -10),
		anchor + Vector2(direction * 7, -7),
		anchor + Vector2(direction * 7, 23),
		anchor + Vector2(0, 26),
	])
	draw_colored_polygon(inner, COLOR_PORTAL)
	draw_line(
		anchor + Vector2(0, -7),
		anchor + Vector2(0, 23),
		COLOR_PORTAL_LIGHT,
		2.0
	)


func _draw_facility() -> void:
	var system_id := _system_id()
	if not _facility_origins.has(system_id):
		return
	var origin: Vector2i = _facility_origins[system_id]
	var rect := Rect2(
		_grid_to_pixel(origin),
		Vector2(FACILITY_FOOTPRINT * TILE_SIZE_PX)
	)
	draw_rounded_shadow(rect)
	var texture: Texture2D = _building_textures.get(system_id, null)
	var constructing := (
		_mode == Mode.CONSTRUCTING
		and _construction_system_index == _current_system_index
	)
	if texture != null and constructing:
		var progress := _construction_progress()
		draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.16))
		var reveal_height := rect.size.y * progress
		if reveal_height > 0.0:
			var texture_size := texture.get_size()
			var destination := Rect2(
				rect.position + Vector2(0.0, rect.size.y - reveal_height),
				Vector2(rect.size.x, reveal_height)
			)
			var source := Rect2(
				Vector2(0.0, texture_size.y * (1.0 - progress)),
				Vector2(texture_size.x, texture_size.y * progress)
			)
			draw_texture_rect_region(texture, destination, source)
	elif texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		var fallback_color: Color = SYSTEMS[_current_system_index]["accent"]
		if constructing:
			fallback_color = Color(fallback_color, 0.25 + _construction_progress() * 0.75)
		draw_rect(rect, fallback_color)
		draw_rect(rect, CohesiveMapVisuals.OUTLINE, false, 3.0)
	if constructing:
		_draw_construction_animation(rect)


func _draw_construction_animation(rect: Rect2) -> void:
	var progress := _construction_progress()
	var accent: Color = SYSTEMS[_current_system_index]["accent"]
	var scan_y := rect.end.y - rect.size.y * progress
	draw_rect(rect, Color(accent, 0.08 + (1.0 - progress) * 0.14))
	draw_rect(rect, Color(COLOR_PORTAL_LIGHT, 0.72), false, 2.0)
	for column in range(1, 3):
		var x := rect.position.x + rect.size.x * float(column) / 3.0
		draw_line(
			Vector2(x, rect.position.y),
			Vector2(x, rect.end.y),
			Color(COLOR_PORTAL_LIGHT, 0.35),
			1.0
		)
	for row in range(1, 3):
		var y := rect.position.y + rect.size.y * float(row) / 3.0
		draw_line(
			Vector2(rect.position.x, y),
			Vector2(rect.end.x, y),
			Color(COLOR_PORTAL_LIGHT, 0.35),
			1.0
		)
	draw_line(
		Vector2(rect.position.x, scan_y),
		Vector2(rect.end.x, scan_y),
		Color.WHITE,
		2.0
	)
	var progress_rect := Rect2(
		rect.position + Vector2(5.0, rect.size.y - 9.0),
		Vector2(rect.size.x - 10.0, 5.0)
	)
	draw_rect(progress_rect, Color(0.05, 0.03, 0.08, 0.85))
	draw_rect(
		Rect2(progress_rect.position, Vector2(progress_rect.size.x * progress, 5.0)),
		COLOR_VALID
	)


func draw_rounded_shadow(rect: Rect2) -> void:
	draw_circle(rect.get_center() + Vector2(0, 30), 34.0, COLOR_SHADOW)


func _draw_ports() -> void:
	var staging: Vector2i = STAGING_CELLS[_current_system_index]
	_draw_port_marker(staging)
	var system_id := _system_id()
	if not _facility_origins.has(system_id):
		return
	var origin: Vector2i = _facility_origins[system_id]
	_draw_port_marker(Vector2i(origin.x - 1, origin.y + 3))
	_draw_port_marker(Vector2i(origin.x + FACILITY_FOOTPRINT.x, origin.y + 3))


func _draw_port_marker(cell: Vector2i) -> void:
	var center := _cell_center(cell)
	draw_circle(center, 7.0, COLOR_PORT)
	draw_circle(center, 7.0, Color.WHITE, false, 1.5)


func _draw_delivery() -> void:
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_draw_vehicle_on_path(
			_delivery_path,
			_delivery_progress,
			_delivery_system_index,
			true
		)
		return
	var outgoing: Array[Vector2i] = _route_for(
		_outgoing_routes,
		_system_id()
	)
	if (
		not outgoing.is_empty()
		and _completed_dispatches.get(_system_id(), false)
	):
		var progress := fmod(_ambient_phase, float(outgoing.size()))
		_draw_vehicle_on_path(
			outgoing,
			progress,
			_current_system_index,
			false
		)


func _draw_vehicle_on_path(
	path: Array[Vector2i],
	progress: float,
	system_index: int,
	emphasized: bool
) -> void:
	if path.is_empty():
		return
	var position := _path_position(path, progress)
	var bob := sin(_ambient_phase * 4.0) * 1.5
	var shadow_rect := Rect2(position + Vector2(-20, 8), Vector2(40, 9))
	draw_ellipse_shadow(shadow_rect)
	var texture: Texture2D = _vehicle_textures.get(
		_system_id(system_index),
		null
	)
	var vehicle_rect := Rect2(
		position + Vector2(-32, -21 + bob),
		Vector2(64, 42)
	)
	var edge_fade := clampf(
		minf(position.x / 24.0, (MAP_SIZE.x - position.x) / 24.0),
		0.15,
		1.0
	)
	var alpha := edge_fade if emphasized else edge_fade * 0.90
	if texture != null:
		draw_texture_rect(texture, vehicle_rect, false, Color(1, 1, 1, alpha))
	else:
		draw_rect(vehicle_rect, Color(SYSTEMS[system_index]["accent"], alpha))
		draw_rect(vehicle_rect, CohesiveMapVisuals.OUTLINE, false, 2.0)


func draw_ellipse_shadow(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.5, COLOR_SHADOW)


func _draw_build_overlay() -> void:
	if _mode != Mode.PLACING:
		return
	var preview_origin := _current_build_tool().preview_origin
	if not _is_grid_cell(preview_origin):
		return
	var preview := Rect2(
		_grid_to_pixel(preview_origin),
		Vector2(FACILITY_FOOTPRINT * TILE_SIZE_PX)
	)
	var color := (
		COLOR_VALID
		if _current_build_tool().is_valid_origin(preview_origin)
		else COLOR_INVALID
	)
	draw_rect(preview, Color(color, 0.24))
	draw_rect(preview, color, false, 2.0)


func _draw_bottleneck_overlay() -> void:
	if _mode != Mode.BOTTLENECK:
		return
	var operation_tool := _current_operation_tool()
	if not operation_tool.bottleneck_active:
		return
	var center := _cell_center(operation_tool.bottleneck_cell)
	var pulse := 8.0 + sin(_ambient_phase * 5.0) * 2.0
	draw_circle(center, pulse, Color(COLOR_INVALID, 0.35))
	draw_arc(center, pulse, 0.0, TAU, 16, COLOR_INVALID, 3.0)
	if operation_tool.selected_cell == operation_tool.bottleneck_cell:
		draw_arc(center, pulse + 5.0, 0.0, TAU, 16, Color.WHITE, 2.0)


func _build_interface() -> void:
	var top_bar := Panel.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(800, 40)
	top_bar.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL))
	add_child(top_bar)

	_system_title = Label.new()
	_system_title.position = Vector2(10, 7)
	_system_title.size = Vector2(410, 26)
	_system_title.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(_system_title)

	_build_resource_status(top_bar)

	var quiet_footer := Panel.new()
	quiet_footer.name = "QuietFooter"
	quiet_footer.position = Vector2(0, 360)
	quiet_footer.size = Vector2(640, 90)
	quiet_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quiet_footer.add_theme_stylebox_override("panel", _quiet_footer_style())
	add_child(quiet_footer)

	var side_panel := PanelContainer.new()
	side_panel.position = Vector2(640, 40)
	side_panel.size = Vector2(160, 410)
	side_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL))
	side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(side_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	side_panel.add_child(column)

	var maps_title := Label.new()
	maps_title.text = "BODY SYSTEM MAPS"
	maps_title.add_theme_font_size_override("font_size", 10)
	column.add_child(maps_title)

	for index in range(SYSTEMS.size()):
		var button := _add_button(
			column,
			"System_%s" % SYSTEMS[index]["short"],
			String(SYSTEMS[index]["short"])
		)
		button.pressed.connect(_switch_system.bind(index))
		_system_buttons.append(button)

	var separator := HSeparator.new()
	column.add_child(separator)

	_build_button = _add_button(column, "BuildFacility", "Place Facility")
	_build_button.pressed.connect(_select_facility)
	_route_button = _add_button(column, "ClearRoute", "Clear Route")
	_route_button.pressed.connect(_clear_current_route)
	_dispatch_button = _add_button(column, "PrimaryAction", "Commit Network")
	_dispatch_button.pressed.connect(_on_primary_action)

	var reset_button := _add_button(column, "ResetNetwork", "Reset Network")
	reset_button.pressed.connect(_reset_network)
	var title_button := _add_button(column, "ReturnToTitle", "Return to Title")
	title_button.pressed.connect(_return_to_title)

	_build_context_cards()
	_build_completion_popup()


func _build_resource_status(top_bar: Control) -> void:
	var status_panel := PanelContainer.new()
	status_panel.name = "ResourceStatus"
	status_panel.position = Vector2(416, 3)
	status_panel.size = Vector2(374, 34)
	## The panel and its containers must pass hover through so the metric rows
	## below can receive it. Setting IGNORE here is what made every tooltip in
	## this bar unreachable before.
	status_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	status_panel.add_theme_stylebox_override(
		"panel",
		_status_panel_style()
	)
	top_bar.add_child(status_panel)

	var column := VBoxContainer.new()
	column.name = "ResourceStatusColumn"
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	status_panel.add_child(column)

	var row := HBoxContainer.new()
	row.name = "ResourceStatusRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(row)

	for metric_id in METRIC_ORDER:
		_build_resource_metric(row, metric_id)

	_build_stability_bar(column)
	_build_hover_panel()


func _build_resource_metric(
	row: HBoxContainer,
	metric_id: StringName
) -> void:
	var metric := HBoxContainer.new()
	metric.name = "%sMetric" % String(metric_id).to_pascal_case()
	metric.custom_minimum_size = Vector2(118, 18)
	metric.add_theme_constant_override("separation", 2)
	## The metric row is the hover target for the breakdown panel. It carries no
	## tooltip: the panel is the tooltip, and a second floating box on top of it
	## just covers the stability bar.
	metric.mouse_filter = Control.MOUSE_FILTER_STOP
	metric.mouse_entered.connect(_on_metric_hovered.bind(metric_id))
	metric.mouse_exited.connect(_on_metric_unhovered.bind(metric_id))
	row.add_child(metric)
	_metric_containers[metric_id] = metric

	var icon := TextureRect.new()
	icon.name = "%sIcon" % String(metric_id).to_pascal_case()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metric.add_child(icon)
	_resource_icon_nodes[metric_id] = icon

	var value_label := Label.new()
	value_label.name = "%sValue" % String(metric_id).to_pascal_case()
	value_label.custom_minimum_size = Vector2(100, 18)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metric.add_child(value_label)
	_resource_value_labels[metric_id] = value_label


## Stability is a state, not a stock, so it is drawn as a bar apart from the
## three flows rather than as a fourth number in the row.
func _build_stability_bar(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "StabilityRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(row)

	_link_status = Label.new()
	_link_status.name = "LinkStatus"
	_link_status.custom_minimum_size = Vector2(96, 12)
	_link_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_link_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_link_status.add_theme_font_size_override("font_size", 9)
	_link_status.add_theme_color_override("font_color", COLOR_MUTED)
	_link_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_link_status)

	var track := ColorRect.new()
	track.name = "StabilityTrack"
	track.custom_minimum_size = STABILITY_BAR_SIZE
	track.color = Color(1.0, 1.0, 1.0, 0.14)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)

	_stability_bar_fill = ColorRect.new()
	_stability_bar_fill.name = "StabilityFill"
	_stability_bar_fill.position = Vector2.ZERO
	_stability_bar_fill.size = STABILITY_BAR_SIZE
	_stability_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_stability_bar_fill)

	## Tick marks at the two production-tier boundaries, so the steps in
	## `ResourcePool._stability_factor_for` are visible rather than implied.
	for threshold in [
		ResourcePool.STABILITY_STRAINED,
		ResourcePool.STABILITY_HEALTHY,
	]:
		var mark := ColorRect.new()
		mark.name = "StabilityTick%d" % int(threshold)
		mark.color = Color(0.08, 0.04, 0.11, 0.85)
		mark.size = Vector2(1.0, STABILITY_BAR_SIZE.y)
		mark.position = Vector2(
			STABILITY_BAR_SIZE.x * float(threshold) / 100.0,
			0.0
		)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(mark)

	_stability_bar_label = Label.new()
	_stability_bar_label.name = "StabilityValue"
	_stability_bar_label.custom_minimum_size = Vector2(84, 12)
	_stability_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stability_bar_label.add_theme_font_size_override("font_size", 9)
	_stability_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_stability_bar_label)


func _build_hover_panel() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.name = "ResourceBreakdown"
	_hover_panel.position = HOVER_PANEL_POSITION
	_hover_panel.custom_minimum_size = Vector2(HOVER_PANEL_WIDTH, 0.0)
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.z_index = 40
	_hover_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.08, 0.04, 0.11, 0.97))
	)
	_hover_panel.visible = false
	add_child(_hover_panel)

	_hover_panel_column = VBoxContainer.new()
	_hover_panel_column.name = "ResourceBreakdownColumn"
	_hover_panel_column.add_theme_constant_override("separation", 1)
	_hover_panel_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(_hover_panel_column)


func _on_metric_hovered(metric_id: StringName) -> void:
	_hovered_metric = metric_id
	_refresh_hover_panel()


func _on_metric_unhovered(metric_id: StringName) -> void:
	if _hovered_metric != metric_id:
		return
	_hovered_metric = &""
	_refresh_hover_panel()


func _build_completion_popup() -> void:
	_completion_overlay = Control.new()
	_completion_overlay.name = "TaskCompletionOverlay"
	_completion_overlay.position = Vector2.ZERO
	_completion_overlay.size = Vector2(800, 450)
	_completion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completion_overlay.z_index = 100
	add_child(_completion_overlay)

	_completion_window = PanelContainer.new()
	_completion_window.name = "TaskCompletionNotification"
	_completion_window.position = COMPLETION_NOTIFICATION_POSITION
	_completion_window.custom_minimum_size = COMPLETION_NOTIFICATION_SIZE
	_completion_window.size = COMPLETION_NOTIFICATION_SIZE
	_completion_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_completion_window.tooltip_text = "Click to dismiss"
	_completion_window.add_theme_stylebox_override(
		"panel",
		_completion_window_style()
	)
	_completion_window.gui_input.connect(_on_completion_notification_input)
	_completion_overlay.add_child(_completion_window)

	var frame_art := TextureRect.new()
	frame_art.name = "NotificationFrameArt"
	frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	frame_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_art.texture = AssetLoader.get_static_texture(
		&"ui_system_completion_notification"
	)
	_completion_window.add_child(frame_art)

	var content_margin := MarginContainer.new()
	content_margin.name = "NotificationContentMargin"
	content_margin.add_theme_constant_override("margin_left", 26)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_right", 25)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completion_window.add_child(content_margin)

	var notification_row := HBoxContainer.new()
	notification_row.name = "NotificationRow"
	notification_row.add_theme_constant_override("separation", 10)
	notification_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_child(notification_row)

	var icon_frame := MarginContainer.new()
	icon_frame.name = "AppIconFrame"
	icon_frame.custom_minimum_size = Vector2(58, 58)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_constant_override("margin_left", 11)
	icon_frame.add_theme_constant_override("margin_top", 11)
	icon_frame.add_theme_constant_override("margin_right", 11)
	icon_frame.add_theme_constant_override("margin_bottom", 11)
	notification_row.add_child(icon_frame)

	var app_icon := TextureRect.new()
	app_icon.name = "AppIcon"
	app_icon.custom_minimum_size = Vector2(34, 34)
	app_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	app_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	app_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_icon.texture = AssetLoader.get_static_texture(
		&"ui_resource_stability_normal"
	)
	icon_frame.add_child(app_icon)

	var content_column := VBoxContainer.new()
	content_column.name = "NotificationContent"
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 2)
	content_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_row.add_child(content_column)

	var heading_row := HBoxContainer.new()
	heading_row.name = "NotificationHeading"
	heading_row.add_theme_constant_override("separation", 8)
	heading_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_column.add_child(heading_row)

	_completion_title = Label.new()
	_completion_title.name = "TaskCompletionTitle"
	_completion_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_completion_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_completion_title.add_theme_font_size_override("font_size", 13)
	_completion_title.add_theme_color_override("font_color", Color("#F4FFF8"))
	heading_row.add_child(_completion_title)

	_completion_time = Label.new()
	_completion_time.name = "TaskCompletionTime"
	_completion_time.text = "now"
	_completion_time.add_theme_font_size_override("font_size", 10)
	_completion_time.add_theme_color_override(
		"font_color",
		COLOR_NOTIFICATION_MUTED
	)
	heading_row.add_child(_completion_time)

	_completion_message = Label.new()
	_completion_message.name = "TaskCompletionMessage"
	_completion_message.custom_minimum_size = Vector2(245, 40)
	_completion_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_completion_message.max_lines_visible = 2
	_completion_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_completion_message.add_theme_font_size_override("font_size", 11)
	_completion_message.add_theme_color_override(
		"font_color",
		Color("#E8DCCF")
	)
	content_column.add_child(_completion_message)
	_completion_overlay.visible = false


func _on_completion_notification_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_dismiss_completion_popup()
		get_viewport().set_input_as_handled()


func _build_context_cards() -> void:
	_build_preview_card = PanelContainer.new()
	_build_preview_card.name = "BuildPreviewCard"
	_build_preview_card.size = Vector2(238, 90)
	_build_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_preview_card.z_index = 30
	_build_preview_card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.08, 0.04, 0.11, 0.96))
	)
	add_child(_build_preview_card)
	var build_column := VBoxContainer.new()
	build_column.add_theme_constant_override("separation", 3)
	_build_preview_card.add_child(build_column)
	_build_preview_name = Label.new()
	_build_preview_name.add_theme_font_size_override("font_size", 10)
	_build_preview_name.add_theme_color_override("font_color", COLOR_PORT)
	build_column.add_child(_build_preview_name)
	_build_preview_cost = Label.new()
	_build_preview_cost.add_theme_font_size_override("font_size", 10)
	build_column.add_child(_build_preview_cost)
	_build_preview_time = Label.new()
	_build_preview_time.add_theme_font_size_override("font_size", 10)
	_build_preview_time.add_theme_color_override("font_color", COLOR_MUTED)
	build_column.add_child(_build_preview_time)
	_build_preview_card.visible = false

	_route_cost_bubble = PanelContainer.new()
	_route_cost_bubble.name = "RouteCostBubble"
	_route_cost_bubble.size = Vector2(184, 40)
	_route_cost_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_cost_bubble.z_index = 30
	_route_cost_bubble.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.08, 0.04, 0.11, 0.94))
	)
	add_child(_route_cost_bubble)
	_route_cost_label = Label.new()
	_route_cost_label.add_theme_font_size_override("font_size", 10)
	_route_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_route_cost_bubble.add_child(_route_cost_label)
	_route_cost_bubble.visible = false

	_build_info_card()


## Pointer-following card for anything already on the map: a facility in any of
## its states, or a committed road. The build preview and the route bubble own
## the placing and routing modes; this one owns everything after.
func _build_info_card() -> void:
	_info_card = PanelContainer.new()
	_info_card.name = "MapObjectInfoCard"
	_info_card.custom_minimum_size = Vector2(INFO_CARD_WIDTH, 0.0)
	_info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_card.z_index = 30
	_info_card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.08, 0.04, 0.11, 0.96))
	)
	add_child(_info_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_card.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)

	_info_name = Label.new()
	_info_name.name = "InfoName"
	_info_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name.add_theme_font_size_override("font_size", 10)
	_info_name.add_theme_color_override("font_color", COLOR_PORT)
	_info_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_info_name)

	_info_status = Label.new()
	_info_status.name = "InfoStatus"
	_info_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_status.add_theme_font_size_override("font_size", 10)
	_info_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_info_status)

	_info_subtitle = Label.new()
	_info_subtitle.name = "InfoSubtitle"
	_info_subtitle.add_theme_font_size_override("font_size", 9)
	_info_subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	## No autowrap. An autowrapping label reports a minimum width of its longest
	## word, so the panel's minimum height balloons to the wrapped line count and
	## the card ends up taller than the map.
	_info_subtitle.clip_text = true
	_info_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_info_subtitle)

	_info_lines.clear()
	for index in range(INFO_CARD_LINE_COUNT):
		var line := Label.new()
		line.name = "InfoLine%d" % index
		line.add_theme_font_size_override("font_size", 9)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(line)
		_info_lines.append(line)

	_info_card.visible = false


func _add_button(parent: Container, node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(144, 27)
	parent.add_child(button)
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLOR_PANEL_EDGE
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _status_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.07, 0.48)
	style.border_color = Color(0.79, 0.31, 0.49, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _quiet_footer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#160C1D")
	style.border_color = Color(0.79, 0.31, 0.49, 0.56)
	style.border_width_top = 1
	return style


func _completion_window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	return style


func _select_facility() -> void:
	if _mode in [
		Mode.CONSTRUCTING,
		Mode.DELIVERY_OUT,
		Mode.DELIVERY_IN,
		Mode.BOTTLENECK,
		Mode.COMPLETE,
	]:
		return
	var system_id := _system_id()
	if _completed_dispatches.get(system_id, false):
		_set_feedback("This system's network is already operating.", true)
		return
	if _committed_systems.get(system_id, false):
		_set_feedback("A committed network cannot be moved during delivery.", true)
		return
	if _facility_origins.has(system_id):
		_current_build_tool().move_placed_building()
		_facility_origins.erase(system_id)
		_current_route_tool().clear()
		_route_metrics.erase(system_id)
		_resources.refund(_facility_cost())
	_mode = Mode.PLACING
	_set_feedback(
		"Place the 6 × 6 facility anywhere it fits. Cost and build time follow the cursor.",
		false
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


func _place_facility_at(origin: Vector2i) -> bool:
	if _mode != Mode.PLACING:
		return false
	var build_tool := _current_build_tool()
	build_tool.set_preview(origin)
	if not build_tool.place_preview():
		_set_feedback(
			"The complete 6 × 6 facility must fit on the map and avoid occupied cells.",
			true
		)
		queue_redraw()
		return false
	var facility_cost := _facility_cost()
	if not _resources.can_afford(facility_cost):
		_set_feedback(
			"Insufficient biomass. Need %s." % _biomass_cost_text(facility_cost),
			true
		)
		_update_context_cards()
		return false
	_resources.spend(facility_cost)
	var system_id := _system_id()
	_facility_origins[system_id] = origin
	var route_tool := _current_route_tool()
	var blocked_cells: Array[Vector2i] = build_tool.placed_cells()
	route_tool.configure(
		GRID_SIZE,
		Vector2i(origin.x + FACILITY_FOOTPRINT.x, origin.y + 3),
		Vector2i(GRID_SIZE.x - 1, EXIT_ROWS[_current_system_index]),
		blocked_cells
	)
	_route_metrics.erase(system_id)
	_construction_elapsed = 0.0
	_construction_system_index = _current_system_index
	_mode = Mode.CONSTRUCTING
	_set_feedback(
		"Construction started. %s spent; completion in %.1f seconds."
		% [
			_biomass_cost_text(facility_cost),
			_current_build_time_sec(),
		],
		false
	)
	print(
		"%s Placed %s at %s."
		% [LOG_PREFIX, SYSTEMS[_current_system_index]["facility"], origin]
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()
	return true


func _finish_facility_construction() -> void:
	if _mode != Mode.CONSTRUCTING:
		return
	_construction_elapsed = _current_build_time_sec()
	_construction_system_index = -1
	_mode = Mode.ROUTING
	_set_feedback(
		"%s complete. Draw a road from its right port to the boundary gate."
		% SYSTEMS[_current_system_index]["facility"],
		false
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


func _dispatch_to_next_system() -> bool:
	if _mode != Mode.PLAN_READY:
		_set_feedback("Finish a route to the right boundary before committing.", true)
		return false
	var system_id := _system_id()
	if not _facility_origins.has(system_id):
		_set_feedback("Place this system's facility before committing the network.", true)
		return false
	if _completed_dispatches.get(system_id, false):
		_set_feedback("This cross-system delivery link is already operating.", true)
		return false
	var route_tool := _current_route_tool()
	if not route_tool.route_complete or not route_tool.is_contiguous():
		_set_feedback("The road must be continuous and end at the boundary gate.", true)
		return false
	var metrics := _route_plan_metrics()
	var total_cost := float(metrics.get("total_cost", 0.0))
	if not _resources.can_afford(total_cost):
		_set_feedback(
			"Insufficient biomass. Need %s." % _biomass_cost_text(total_cost),
			true
		)
		return false
	_resources.spend(total_cost)
	var route := route_tool.path()
	_outgoing_routes[system_id] = route
	_route_metrics[system_id] = metrics
	_committed_systems[system_id] = true
	## The facility and its road start producing only once the network is
	## committed, which is when the player has paid for both.
	_register_system_economy(
		_current_system_index,
		int(metrics.get("road_cells", 0))
	)
	_current_operation_tool().configure(route)
	## Duplicate: `_finish_delivery_leg` clears `_delivery_path`, and sharing the
	## array with `_outgoing_routes` erased the committed road the moment the
	## delivery animation ended. That is why finished roads never stayed drawn.
	_delivery_path = route.duplicate()
	_delivery_progress = 0.0
	_delivery_system_index = _current_system_index
	_pending_delivery_system_index = _current_system_index
	_mode = Mode.DELIVERY_OUT
	_set_feedback(
		"Network committed for %s. %s is now producing."
		% [
			_biomass_cost_text(total_cost),
			SYSTEMS[_current_system_index]["facility"],
		],
		false
	)
	print("%s Dispatch left %s." % [LOG_PREFIX, SYSTEMS[_current_system_index]["name"]])
	_refresh_interface()
	queue_redraw()
	return true


func _finish_delivery_leg() -> void:
	if _mode == Mode.DELIVERY_OUT:
		_delivery_path.clear()
		_delivery_progress = 0.0
		var system: Dictionary = SYSTEMS[_delivery_system_index]
		var operation_tool := _operation_tool_for(_delivery_system_index)
		if (
			bool(system.get("bottleneck_required", false))
			and operation_tool.repair_count == 0
			and operation_tool.trigger_bottleneck()
		):
			_current_system_index = _delivery_system_index
			_mode = Mode.BOTTLENECK
			_set_feedback(
				"Flow has stalled. Click the flashing road segment before stability falls further.",
				true
			)
			_refresh_interface()
			queue_redraw()
			return
		_continue_after_outgoing_delivery()
		return

	if _mode == Mode.DELIVERY_IN:
		_mode = Mode.READY
		_delivery_path.clear()
		_delivery_progress = 0.0
		_set_feedback(
			"Cargo reached the local staging depot. Place this system's 6 × 6 facility.",
			false
		)
		_refresh_interface()


func _continue_after_outgoing_delivery() -> void:
	var completed_index := _pending_delivery_system_index
	if completed_index < 0:
		completed_index = _delivery_system_index
	var completed_id := _system_id(completed_index)
	_completed_dispatches[completed_id] = true
	## No lump-sum completion reward. The incentive to finish a map is that its
	## facility permanently raises production, which a payout would obscure.
	var production_note := _production_note(completed_index)
	_pending_delivery_system_index = -1
	var next_index := completed_index + 1
	if next_index >= SYSTEMS.size():
		_mode = Mode.COMPLETE
		_current_system_index = completed_index
		_delivery_path.clear()
		_set_feedback(
			"Final link online. The body-city network is complete.",
			false
		)
		print("%s Full body network complete." % LOG_PREFIX)
		_refresh_interface()
		_show_completion_popup(
			"BODY NETWORK COMPLETE",
			(
				"%s is online.\nAll four body systems now exchange resources.\n%s"
				% [
					SYSTEMS[completed_index]["name"],
					production_note,
				]
			),
			true
		)
		queue_redraw()
		return
	_unlocked_count = maxi(_unlocked_count, next_index + 1)
	_current_system_index = next_index
	var incoming := _entry_route_for(next_index)
	_incoming_routes[_system_id(next_index)] = incoming
	_delivery_path = incoming.duplicate()
	_delivery_progress = 0.0
	_delivery_system_index = next_index
	_mode = Mode.DELIVERY_IN
	_set_feedback(
		"Output delivered. %s is now unlocked." % SYSTEMS[next_index]["name"],
		false
	)
	print("%s Unlocked %s." % [LOG_PREFIX, SYSTEMS[next_index]["name"]])
	_refresh_interface()
	_show_completion_popup(
		"%s LINK COMPLETE" % SYSTEMS[completed_index]["short"],
		(
			"%s\n%s is now ready to develop."
			% [production_note, SYSTEMS[next_index]["name"]]
		),
		false
	)
	queue_redraw()


## One line naming what the finished facility now contributes every second.
func _production_note(index: int) -> String:
	var economy: Dictionary = SYSTEMS[index].get("economy", {})
	var parts: Array[String] = []
	var biomass_output := float(economy.get(&"biomass_output", 0.0))
	if biomass_output > 0.0:
		parts.append("+%.1f biomass/s" % biomass_output)
	var oxygen_supply := float(economy.get(&"oxygen_supply", 0.0))
	if oxygen_supply > 0.0:
		parts.append("+%.0f oxygen supply" % oxygen_supply)
	var net_waste := (
		float(economy.get(&"waste_clearance", 0.0))
		- float(economy.get(&"waste_output", 0.0))
	)
	if net_waste > 0.0:
		parts.append("-%.2f waste/s" % net_waste)
	if parts.is_empty():
		return "This facility is now operating."
	return "Now producing %s." % ", ".join(parts)


func _on_primary_action() -> void:
	if _mode == Mode.PLAN_READY:
		_dispatch_to_next_system()
	elif _mode == Mode.BOTTLENECK:
		_repair_selected_bottleneck()


func _select_bottleneck_at(cell: Vector2i) -> bool:
	if _mode != Mode.BOTTLENECK:
		return false
	var operation_tool := _current_operation_tool()
	if not operation_tool.select_route_cell(cell):
		_set_feedback("Select the flashing damaged segment on the road.", true)
		_refresh_interface()
		queue_redraw()
		return false
	_set_feedback(
		"Fault isolated. Repair costs %s."
		% _biomass_cost_text(NetworkOperationTool.REPAIR_BIOMASS_COST),
		false
	)
	_refresh_interface()
	queue_redraw()
	return true


func _repair_selected_bottleneck() -> bool:
	if _mode != Mode.BOTTLENECK:
		return false
	var operation_tool := _current_operation_tool()
	if not operation_tool.can_repair(_resources.biomass):
		_set_feedback(
			"Select the flashing segment and keep %s available."
			% _biomass_cost_text(REPAIR_BIOMASS_COST),
			true
		)
		return false
	_resources.spend(REPAIR_BIOMASS_COST)
	if not operation_tool.repair(_resources.biomass + REPAIR_BIOMASS_COST):
		_resources.refund(REPAIR_BIOMASS_COST)
		return false
	_resources.stability = minf(100.0, _resources.stability + 5.0)
	_set_feedback("Segment repaired. Flow and system stability are restored.", false)
	_continue_after_outgoing_delivery()
	return true


func _switch_system(index: int) -> bool:
	if index < 0 or index >= _unlocked_count:
		_set_feedback("Develop the previous body system to unlock this map.", true)
		return false
	if _mode in [
		Mode.CONSTRUCTING,
		Mode.DELIVERY_OUT,
		Mode.DELIVERY_IN,
		Mode.BOTTLENECK,
	]:
		_set_feedback(
			"Wait for the current construction or delivery event before changing maps.",
			true
		)
		return false
	_current_system_index = index
	_mode = _mode_for_system(index)
	_set_feedback("Switched to the %s map." % SYSTEMS[index]["name"], false)
	_refresh_interface()
	queue_redraw()
	print("%s Switched to %s." % [LOG_PREFIX, SYSTEMS[index]["name"]])
	return true


func _reset_network() -> void:
	if _completion_overlay != null:
		_completion_overlay.visible = false
	_completion_remaining_sec = 0.0
	_mode = Mode.READY
	_current_system_index = 0
	_unlocked_count = 1
	_hover_cell = Vector2i(-1, -1)
	_facility_origins.clear()
	_outgoing_routes.clear()
	_incoming_routes.clear()
	_completed_dispatches.clear()
	_delivery_path.clear()
	_delivery_progress = 0.0
	_delivery_system_index = 0
	_construction_elapsed = 0.0
	_construction_system_index = -1
	_route_dragging = false
	_pending_delivery_system_index = -1
	_resources.reset_economy()
	_route_metrics.clear()
	_committed_systems.clear()
	_initialize_gameplay_tools()
	_incoming_routes[_system_id(0)] = _entry_route_for(0)
	_set_feedback(
		"Network reset. Place a facility, draw its road, then commit the plan.",
		false
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


func _return_to_title() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to_title"):
			node.call_deferred("go_to_title")
			return
		node = node.get_parent()


func _show_completion_popup(
	title: String,
	message: String,
	is_final: bool
) -> void:
	if (
		_completion_overlay == null
		or _completion_title == null
		or _completion_message == null
		or _completion_time == null
	):
		return
	_completion_title.text = title.capitalize()
	_completion_message.text = message
	_completion_time.text = "now"
	_completion_remaining_sec = (
		COMPLETION_NOTIFICATION_DURATION_SEC + 2.0
		if is_final
		else COMPLETION_NOTIFICATION_DURATION_SEC
	)
	_completion_overlay.visible = true
	_completion_overlay.move_to_front()


func _dismiss_completion_popup() -> void:
	if not _completion_popup_visible():
		return
	_completion_overlay.visible = false
	_completion_remaining_sec = 0.0
	if _mode == Mode.DELIVERY_IN:
		_set_feedback(
			"Follow the delivery into %s."
			% SYSTEMS[_current_system_index]["name"],
			false
		)
	_refresh_interface()


func _completion_popup_visible() -> bool:
	return _completion_overlay != null and _completion_overlay.visible


func _initialize_gameplay_tools() -> void:
	_build_tools.clear()
	_route_tools.clear()
	_operation_tools.clear()
	for index in range(SYSTEMS.size()):
		var system_id := _system_id(index)
		var build_tool := BuildTool.new()
		var blocked_cells: Array[Vector2i] = _entry_route_for(index)
		for row in range(GRID_SIZE.y):
			blocked_cells.append(Vector2i(GRID_SIZE.x - 1, row))
		build_tool.configure(
			GRID_SIZE,
			FACILITY_FOOTPRINT,
			FULL_MAP_BUILD_ZONE,
			blocked_cells
		)
		_build_tools[system_id] = build_tool
		_route_tools[system_id] = RouteTool.new()
		_operation_tools[system_id] = NetworkOperationTool.new()


func _current_build_tool() -> BuildTool:
	return _build_tools.get(_system_id()) as BuildTool


func _current_route_tool() -> RouteTool:
	return _route_tools.get(_system_id()) as RouteTool


func _current_operation_tool() -> NetworkOperationTool:
	return _operation_tool_for(_current_system_index)


func _operation_tool_for(index: int) -> NetworkOperationTool:
	return _operation_tools.get(_system_id(index)) as NetworkOperationTool


func _update_context_cards() -> void:
	if _build_preview_card == null or _route_cost_bubble == null:
		return
	_build_preview_card.visible = _mode == Mode.PLACING
	## The object card takes priority over the route bubble, because the
	## "built but not connected" state only exists while a route is being
	## drawn. Over open ground the bubble comes back.
	_update_info_card()
	_route_cost_bubble.visible = (
		_mode in [Mode.ROUTING, Mode.PLAN_READY]
		and not _info_card.visible
	)
	if _build_preview_card.visible:
		var facility_cost := _facility_cost()
		_build_preview_name.text = String(
			SYSTEMS[_current_system_index]["facility"]
		)
		_build_preview_cost.text = "Cost   %s" % _biomass_cost_text(facility_cost)
		_build_preview_cost.add_theme_color_override(
			"font_color",
			COLOR_TEXT if _resources.can_afford(facility_cost) else COLOR_INVALID
		)
		_build_preview_time.text = "Build time   %.1f s" % _current_build_time_sec()
		_position_follow_card(
			_build_preview_card,
			Vector2(FACILITY_FOOTPRINT.x * TILE_SIZE_PX + 18.0, 18.0)
		)
	if _route_cost_bubble.visible:
		var road_cells := _current_road_cell_count()
		var road_cost := float(road_cells) * ROAD_BIOMASS_COST_PER_TILE
		_route_cost_label.text = "Road  %d tiles   ·   %s" % [
			road_cells,
			_biomass_cost_text(road_cost),
		]
		_route_cost_label.add_theme_color_override(
			"font_color",
			COLOR_TEXT if _resources.can_afford(road_cost) else COLOR_INVALID
		)
		_position_follow_card(_route_cost_bubble, Vector2(16.0, 16.0))


## Fill and place the map-object card from whatever the pointer is over.
func _update_info_card() -> void:
	if _info_card == null:
		return
	if _mode == Mode.PLACING:
		_info_card.visible = false
		return
	var content := _info_card_content()
	if content.is_empty():
		_info_card.visible = false
		return

	var muted := bool(content.get("muted", false))
	_info_name.text = String(content.get("name", ""))
	_info_name.add_theme_color_override(
		"font_color",
		COLOR_MUTED if muted else COLOR_PORT
	)
	_info_status.text = String(content.get("status", ""))
	_info_status.add_theme_color_override(
		"font_color",
		content.get("status_color", COLOR_TEXT)
	)
	_info_subtitle.text = String(content.get("subtitle", ""))
	_info_subtitle.visible = not _info_subtitle.text.is_empty()

	var lines: Array = content.get("lines", [])
	for index in range(_info_lines.size()):
		var label := _info_lines[index]
		if index < lines.size():
			label.text = String(lines[index])
			label.visible = true
			label.add_theme_color_override(
				"font_color",
				COLOR_MUTED if muted else COLOR_TEXT
			)
		else:
			label.visible = false

	_info_card.visible = true
	## Hug the content: the line count changes between states, and a container
	## left at its previous size keeps the empty rows' height.
	_info_card.size = _info_card.get_combined_minimum_size()
	_position_follow_card(_info_card, Vector2(18.0, 18.0))


func _info_card_content() -> Dictionary:
	var facility_index := _hovered_facility_index()
	if facility_index >= 0:
		return _facility_card_content(facility_index)
	var road_index := _hovered_road_index()
	if road_index >= 0:
		return _road_card_content(road_index)
	return {}


## Only the facility of the map currently on screen can be under the pointer.
func _hovered_facility_index() -> int:
	var system_id := _system_id()
	if not _facility_origins.has(system_id):
		return -1
	var origin: Vector2i = _facility_origins[system_id]
	var offset := _hover_cell - origin
	if (
		offset.x < 0
		or offset.y < 0
		or offset.x >= FACILITY_FOOTPRINT.x
		or offset.y >= FACILITY_FOOTPRINT.y
	):
		return -1
	return _current_system_index


func _hovered_road_index() -> int:
	var system_id := _system_id()
	var route: Array[Vector2i] = _route_for(_outgoing_routes, system_id)
	if route.has(_hover_cell):
		return _current_system_index
	return -1


func _facility_card_content(index: int) -> Dictionary:
	var system: Dictionary = SYSTEMS[index]
	var system_id := _system_id(index)
	var economy: Dictionary = system.get("economy", {})
	var facility_name := String(system["facility"])

	if _mode == Mode.CONSTRUCTING and _construction_system_index == index:
		var remaining := maxf(
			_current_build_time_sec() - _construction_elapsed,
			0.0
		)
		return {
			"name": facility_name,
			"status": "CONSTRUCTING",
			"status_color": COLOR_PORT,
			"subtitle": String(system.get("role", "")),
			"lines": ["Ready in %.1f s" % remaining],
		}

	var committed := bool(_committed_systems.get(system_id, false))
	if not committed:
		## Built but not yet earning. Show what connecting it would be worth,
		## dimmed, so the card is a reason to draw the road rather than a wall.
		return {
			"name": facility_name,
			"status": "NOT CONNECTED",
			"status_color": COLOR_MUTED,
			"subtitle": "Draw a road to the boundary gate to start it",
			"muted": true,
			"lines": [
				"Biomass    - / %s per s" % _rate_text(
					float(economy.get(&"biomass_output", 0.0))
				),
				_oxygen_line(economy),
				_waste_line(economy),
			],
		}

	## Operating. Only biomass is throttled, so only biomass carries an
	## actual-over-nominal pair; the reason for any gap is named beside it.
	var nominal := float(economy.get(&"biomass_output", 0.0))
	var actual := nominal * _resources.oxygen_ratio * _resources.stability_factor
	var throttled := not is_equal_approx(actual, nominal)
	var lines: Array[String] = [
		"Biomass    %s / %s per s" % [_rate_text(actual), _rate_text(nominal)],
		_oxygen_line(economy),
		_waste_line(economy),
	]
	## The reason for the gap gets its own line rather than a trailing
	## parenthesis, which would run past the edge of the card.
	var reasons: Array[String] = []
	if _resources.oxygen_ratio < 1.0:
		reasons.append("oxygen x%.2f" % _resources.oxygen_ratio)
	if _resources.stability_factor < 1.0:
		reasons.append("stability x%.2f" % _resources.stability_factor)
	if not reasons.is_empty():
		lines.append("Throttled by %s" % ", ".join(reasons))
	return {
		"name": facility_name,
		"status": "THROTTLED" if throttled else "OPERATING",
		"status_color": COLOR_INVALID if throttled else COLOR_VALID,
		"subtitle": String(system.get("role", "")),
		"lines": lines,
	}


func _road_card_content(index: int) -> Dictionary:
	var route: Array[Vector2i] = _route_for(_outgoing_routes, _system_id(index))
	var tiles := route.size()
	var spec := _road_economy_spec(tiles)
	return {
		"name": "%s roads" % SYSTEMS[index]["name"],
		"status": "OPERATING",
		"status_color": COLOR_VALID,
		"subtitle": "Every tile draws oxygen and makes waste",
		"lines": [
			"Length     %d tiles   built for %s" % [
				tiles,
				_biomass_cost_text(float(tiles) * ROAD_BIOMASS_COST_PER_TILE),
			],
			"Oxygen     demand %.2f" % float(spec[&"oxygen_demand"]),
			"Waste      in %s per s" % _rate_text(
				float(spec[&"waste_output"]),
				2
			),
		],
	}


func _oxygen_line(economy: Dictionary) -> String:
	return "Oxygen     supply %.1f   demand %.1f" % [
		float(economy.get(&"oxygen_supply", 0.0)),
		float(economy.get(&"oxygen_demand", 0.0)),
	]


func _waste_line(economy: Dictionary) -> String:
	var produced := float(economy.get(&"waste_output", 0.0))
	var cleared := float(economy.get(&"waste_clearance", 0.0))
	return "Waste      in %s   cleared %s   net %s" % [
		_rate_text(produced, 2),
		_rate_text(-cleared, 2),
		_rate_text(produced - cleared, 2),
	]


func _rate_text(value: float, decimals: int = 1) -> String:
	if is_zero_approx(value):
		return "0.%s" % "0".repeat(decimals)
	return ("%%+.%df" % decimals) % value


func _position_follow_card(card: Control, offset: Vector2) -> void:
	var card_size := card.size
	var position := _pointer_position + offset
	var minimum := MAP_ORIGIN + Vector2(8.0, 8.0)
	var maximum := MAP_ORIGIN + MAP_SIZE - card_size - Vector2(8.0, 8.0)
	if position.x > maximum.x:
		position.x = _pointer_position.x - card_size.x - 18.0
	if position.y > maximum.y:
		position.y = _pointer_position.y - card_size.y - 18.0
	card.position = Vector2(
		clampf(position.x, minimum.x, maximum.x),
		clampf(position.y, minimum.y, maximum.y)
	)


func _clear_current_route() -> void:
	if _mode not in [Mode.ROUTING, Mode.PLAN_READY]:
		return
	_current_route_tool().clear()
	_route_metrics.erase(_system_id())
	_route_dragging = false
	_mode = Mode.ROUTING
	_set_feedback(
		"Route cleared. Drag again from the facility's right port to the boundary gate.",
		false
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


func _update_route_plan_feedback() -> void:
	var route_tool := _current_route_tool()
	if route_tool.path().is_empty():
		return
	var metrics := _route_plan_metrics()
	_route_metrics[_system_id()] = metrics
	_set_feedback(
		"Road: %d tiles | Cost %s | Running oxygen %.2f, waste %.2f/s"
		% [
			int(metrics.get("road_cells", 0)),
			_biomass_cost_text(float(metrics.get("total_cost", 0.0))),
			float(metrics.get("road_oxygen_demand", 0.0)),
			float(metrics.get("road_waste_output", 0.0)),
		],
		false
	)
	_refresh_interface()
	_update_context_cards()
	queue_redraw()


## Road length is the only term. It buys biomass once, then keeps costing
## oxygen and generating waste for as long as the road exists.
func _route_plan_metrics() -> Dictionary:
	var route_tool := _current_route_tool()
	var segments := route_tool.segment_count()
	var road_cells := _current_road_cell_count()
	var turns := route_tool.turn_count()
	var minimum_segments := (
		absi(route_tool.target_port.x - route_tool.source_port.x)
		+ absi(route_tool.target_port.y - route_tool.source_port.y)
	)
	var route_cost := float(road_cells) * ROAD_BIOMASS_COST_PER_TILE
	var road_spec := _road_economy_spec(road_cells)
	return {
		"segments": segments,
		"road_cells": road_cells,
		"turns": turns,
		"minimum_segments": minimum_segments,
		"excess_segments": maxi(segments - minimum_segments, 0),
		"route_cost": route_cost,
		"road_oxygen_demand": float(road_spec[&"oxygen_demand"]),
		"road_waste_output": float(road_spec[&"waste_output"]),
		"facility_cost": _facility_cost(),
		"total_cost": route_cost,
	}


func _current_road_cell_count() -> int:
	var route_tool := _current_route_tool()
	if route_tool == null:
		return 0
	return route_tool.path().size()


func _current_build_time_sec() -> float:
	return float(
		SYSTEMS[_current_system_index].get(
			"build_time_sec",
			DEFAULT_BUILD_TIME_SEC
		)
	)


func _construction_progress() -> float:
	var duration := _current_build_time_sec()
	if duration <= 0.0:
		return 1.0
	return clampf(_construction_elapsed / duration, 0.0, 1.0)


func _facility_cost(index: int = -1) -> float:
	var system_index := _current_system_index if index < 0 else index
	return float(SYSTEMS[system_index].get("facility_cost_biomass", 0.0))


func _biomass_cost_text(amount: float) -> String:
	return "BIO %d" % roundi(amount)


## Aggregate economy specification of one map's committed road, scaled by tile
## count. Registering roads as one source keeps the hover breakdown to a single
## line per map instead of a line per tile.
func _road_economy_spec(road_cells: int) -> Dictionary:
	return {
		&"label": "Roads, %d tiles" % road_cells,
		&"oxygen_demand": (
			float(ROAD_TILE_ECONOMY[&"oxygen_demand"]) * float(road_cells)
		),
		&"waste_output": (
			float(ROAD_TILE_ECONOMY[&"waste_output"]) * float(road_cells)
		),
	}


func _register_system_economy(index: int, road_cells: int) -> void:
	var system_id := _system_id(index)
	var spec: Dictionary = SYSTEMS[index].get("economy", {}).duplicate(true)
	spec[&"label"] = String(SYSTEMS[index]["facility"])
	_resources.register_source(system_id, spec)
	_resources.register_source(
		_road_source_id(index),
		_road_economy_spec(road_cells)
	)


func _unregister_system_economy(index: int) -> void:
	_resources.unregister_source(_system_id(index))
	_resources.unregister_source(_road_source_id(index))


func _road_source_id(index: int) -> StringName:
	return StringName("%s_roads" % _system_id(index))


func _mode_for_system(index: int) -> Mode:
	if _completed_dispatches.size() == SYSTEMS.size():
		return Mode.COMPLETE
	var system_id := _system_id(index)
	if _completed_dispatches.get(system_id, false):
		return Mode.READY
	if not _facility_origins.has(system_id):
		return Mode.READY
	var route_tool := _route_tools.get(system_id) as RouteTool
	if route_tool != null and route_tool.route_complete:
		return Mode.PLAN_READY
	return Mode.ROUTING


func _refresh_resource_status() -> void:
	if _link_status == null:
		return
	_link_status.text = "Links %d/%d" % [
		_completed_dispatches.size(),
		SYSTEMS.size(),
	]
	for metric_id in METRIC_ORDER:
		var value_label: Label = _resource_value_labels.get(metric_id)
		var icon: TextureRect = _resource_icon_nodes.get(metric_id)
		if value_label == null or icon == null:
			continue
		value_label.text = _metric_text(metric_id)
		value_label.add_theme_color_override(
			"font_color",
			_metric_color(metric_id)
		)
		var state := _metric_icon_state(metric_id)
		var asset_name: StringName = METRIC_ICON_ASSETS[metric_id][state]
		if not _resource_icon_textures.has(asset_name):
			_resource_icon_textures[asset_name] = AssetLoader.get_static_texture(
				asset_name
			)
		icon.texture = _resource_icon_textures[asset_name]
	_refresh_stability_bar()
	_refresh_hover_panel()


func _metric_text(metric_id: StringName) -> String:
	match metric_id:
		&"biomass":
			return "%s %d %s" % [
				METRIC_SHORT_NAMES[metric_id],
				floori(_resources.biomass),
				_signed_rate_text(_resources.biomass_rate),
			]
		&"oxygen":
			return "%s %d/%d" % [
				METRIC_SHORT_NAMES[metric_id],
				roundi(_resources.oxygen_supply),
				roundi(_resources.oxygen_demand),
			]
		&"waste":
			return "%s %d %s" % [
				METRIC_SHORT_NAMES[metric_id],
				floori(_resources.waste),
				_signed_rate_text(_resources.waste_rate),
			]
	return ""


func _signed_rate_text(rate: float) -> String:
	if is_zero_approx(rate):
		return "0.0"
	return "%+.1f" % rate


## Positive is good for biomass, bad for waste; oxygen is judged on whether
## demand outruns supply.
func _metric_color(metric_id: StringName) -> Color:
	match metric_id:
		&"biomass":
			return COLOR_VALID if _resources.biomass_rate > 0.0 else COLOR_INVALID
		&"oxygen":
			return COLOR_INVALID if _resources.is_oxygen_short() else COLOR_TEXT
		&"waste":
			if _resources.waste >= ResourcePool.WASTE_CAPACITY:
				return COLOR_INVALID
			return COLOR_VALID if _resources.waste_rate < 0.0 else COLOR_PORT
	return COLOR_TEXT


func _metric_icon_state(metric_id: StringName) -> StringName:
	match metric_id:
		&"biomass":
			return &"normal" if _resources.biomass_rate > 0.0 else &"warning"
		&"oxygen":
			return &"warning" if _resources.is_oxygen_short() else &"normal"
		&"waste":
			return (
				&"warning"
				if _resources.waste_ratio() >= ResourcePool.WASTE_SAFE
				else &"normal"
			)
	return &"normal"


func _refresh_stability_bar() -> void:
	if _stability_bar_fill == null or _stability_bar_label == null:
		return
	var ratio := clampf(_resources.stability / 100.0, 0.0, 1.0)
	_stability_bar_fill.size = Vector2(
		STABILITY_BAR_SIZE.x * ratio,
		STABILITY_BAR_SIZE.y
	)
	var color := COLOR_VALID
	if _resources.stability < ResourcePool.STABILITY_STRAINED:
		color = COLOR_INVALID
	elif _resources.stability < ResourcePool.STABILITY_HEALTHY:
		color = COLOR_PORT
	_stability_bar_fill.color = color
	_stability_bar_label.text = "STABILITY %d" % roundi(_resources.stability)
	_stability_bar_label.add_theme_color_override("font_color", color)


## Every line of the breakdown names something the player built, so there is no
## contribution shown that they cannot act on.
func _refresh_hover_panel() -> void:
	if _hover_panel == null or _hover_panel_column == null:
		return
	if _hovered_metric == &"":
		_hover_panel.visible = false
		return
	var lines := _breakdown_lines(_hovered_metric)
	## Reuse the existing labels rather than freeing them. `queue_free` defers
	## to the end of the frame, so rebuilding every frame would leave the old
	## rows visible alongside the new ones.
	var existing := _hover_panel_column.get_child_count()
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		var label: Label
		if index < existing:
			label = _hover_panel_column.get_child(index) as Label
		else:
			label = _breakdown_label("", false)
			_hover_panel_column.add_child(label)
		label.visible = true
		label.text = String(line.get("text", ""))
		label.add_theme_color_override(
			"font_color",
			COLOR_MUTED if bool(line.get("muted", false)) else COLOR_TEXT
		)
	for index in range(lines.size(), existing):
		(_hover_panel_column.get_child(index) as Label).visible = false
	_hover_panel.visible = not lines.is_empty()


func _breakdown_label(text: String, muted: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override(
		"font_color",
		COLOR_MUTED if muted else COLOR_TEXT
	)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _breakdown_lines(metric_id: StringName) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var sources := _resources.sources()
	match metric_id:
		&"biomass":
			lines.append({
				"text": "BIOMASS%s%d" % [
					_breakdown_gap(),
					floori(_resources.biomass),
				],
			})
			for source_id in sources:
				var entry: Dictionary = sources[source_id]
				var output := float(entry[&"biomass_output"])
				if is_zero_approx(output):
					continue
				lines.append(_breakdown_row(String(entry[&"label"]), "%+.1f/s" % output))
			lines.append(_breakdown_row(
				"Oxygen efficiency",
				"x%.2f" % _resources.oxygen_ratio,
				true
			))
			lines.append(_breakdown_row(
				"Stability efficiency",
				"x%.2f" % _resources.stability_factor,
				true
			))
			lines.append(_breakdown_row(
				"Net",
				"%s/s" % _signed_rate_text(_resources.biomass_rate)
			))
		&"oxygen":
			lines.append({
				"text": "OXYGEN%s%d / %d" % [
					_breakdown_gap(),
					roundi(_resources.oxygen_supply),
					roundi(_resources.oxygen_demand),
				],
			})
			for source_id in sources:
				var entry: Dictionary = sources[source_id]
				var supply := float(entry[&"oxygen_supply"])
				if not is_zero_approx(supply):
					lines.append(_breakdown_row(
						"%s  supply" % entry[&"label"],
						"+%.1f" % supply
					))
			for source_id in sources:
				var entry: Dictionary = sources[source_id]
				var demand := float(entry[&"oxygen_demand"])
				if not is_zero_approx(demand):
					lines.append(_breakdown_row(
						"%s  demand" % entry[&"label"],
						"%.1f" % demand,
						true
					))
			lines.append(_breakdown_row(
				"Ratio",
				"%.2f" % _resources.oxygen_ratio
			))
		&"waste":
			lines.append({
				"text": "WASTE%s%d" % [
					_breakdown_gap(),
					floori(_resources.waste),
				],
			})
			for source_id in sources:
				var entry: Dictionary = sources[source_id]
				var output := float(entry[&"waste_output"])
				if not is_zero_approx(output):
					lines.append(_breakdown_row(
						String(entry[&"label"]),
						"+%.2f" % output
					))
			for source_id in sources:
				var entry: Dictionary = sources[source_id]
				var clearance := float(entry[&"waste_clearance"])
				if not is_zero_approx(clearance):
					lines.append(_breakdown_row(
						"%s  clearance" % entry[&"label"],
						"-%.2f" % clearance,
						true
					))
			lines.append(_breakdown_row(
				"Net",
				"%s/s" % _signed_rate_text(_resources.waste_rate)
			))
			lines.append(_breakdown_row(
				"Capacity",
				"%d/%d" % [
					floori(_resources.waste),
					int(ResourcePool.WASTE_CAPACITY),
				],
				true
			))
	if lines.size() <= 1:
		lines.append(_breakdown_row(
			"Nothing built yet",
			"commit a network",
			true
		))
	return lines


func _breakdown_row(
	label: String,
	value: String,
	muted: bool = false
) -> Dictionary:
	var padded := label
	while padded.length() < 30:
		padded += " "
	return {"text": "  %s%s" % [padded, value], "muted": muted}


func _breakdown_gap() -> String:
	return "                       "


func _refresh_interface() -> void:
	if _system_title == null:
		return
	_system_title.text = "%s MAP" % SYSTEMS[_current_system_index]["name"].to_upper()
	_refresh_resource_status()
	for index in range(_system_buttons.size()):
		var unlocked := index < _unlocked_count
		_system_buttons[index].disabled = (
			not unlocked
			or _mode in [
				Mode.CONSTRUCTING,
				Mode.DELIVERY_OUT,
				Mode.DELIVERY_IN,
				Mode.BOTTLENECK,
			]
		)
		_system_buttons[index].text = "%s%s" % [
			"● %d " % (index + 1) if index == _current_system_index else "%d " % (index + 1),
			SYSTEMS[index]["short"] if unlocked else "LOCKED",
		]
	var system_id := _system_id()
	var has_facility := _facility_origins.has(system_id)
	var committed := bool(_committed_systems.get(system_id, false))
	var completed := bool(_completed_dispatches.get(system_id, false))
	_build_button.disabled = (
		committed
		or completed
		or _mode in [
			Mode.CONSTRUCTING,
			Mode.DELIVERY_OUT,
			Mode.DELIVERY_IN,
			Mode.BOTTLENECK,
			Mode.COMPLETE,
		]
	)
	_build_button.text = "Move Facility" if has_facility else "Place Facility"
	_route_button.disabled = (
		not has_facility
		or committed
		or _mode not in [Mode.ROUTING, Mode.PLAN_READY]
	)
	_dispatch_button.disabled = (
		_mode not in [Mode.PLAN_READY, Mode.BOTTLENECK]
		or (
			_mode == Mode.BOTTLENECK
			and _current_operation_tool().selected_cell
			!= _current_operation_tool().bottleneck_cell
		)
	)
	if _mode == Mode.BOTTLENECK:
		_dispatch_button.text = "Repair Segment"
	elif completed:
		_dispatch_button.text = "Link Operating"
	elif _mode == Mode.PLAN_READY:
		_dispatch_button.text = (
			"Complete Network"
			if _current_system_index == SYSTEMS.size() - 1
			else "Commit Network"
		)
	else:
		_dispatch_button.text = "Finish Route"
	_update_context_cards()


func _objective_text() -> String:
	if _mode == Mode.COMPLETE:
		return "Body network complete: all system maps exchange resources."
	if _mode == Mode.PLACING:
		return "Place %s anywhere it fits on the map." % SYSTEMS[_current_system_index]["facility"]
	if _mode == Mode.CONSTRUCTING:
		return "Constructing %s: %d%% complete." % [
			SYSTEMS[_current_system_index]["facility"],
			roundi(_construction_progress() * 100.0),
		]
	if _mode == Mode.ROUTING:
		return "Draw a road from the facility output to the right boundary gate."
	if _mode == Mode.PLAN_READY:
		var metrics: Dictionary = _route_metrics.get(
			_system_id(),
			_route_plan_metrics()
		)
		return "Plan ready: %d road tiles for %s. Commit or redraw." % [
			int(metrics.get("road_cells", 0)),
			_biomass_cost_text(float(metrics.get("total_cost", 0.0))),
		]
	if _mode == Mode.DELIVERY_OUT:
		return "Delivery in transit: vehicle exits this map at the city boundary."
	if _mode == Mode.DELIVERY_IN:
		return "Delivery continuity: vehicle has entered the newly unlocked map."
	if _mode == Mode.BOTTLENECK:
		return "Emergency: click the flashing road segment, then repair it for %s." % (
			_biomass_cost_text(REPAIR_BIOMASS_COST)
		)
	if _completed_dispatches.get(_system_id(), false):
		var economy: Dictionary = SYSTEMS[_current_system_index].get("economy", {})
		return "Operating link: +%.1f biomass/s from %s." % [
			float(economy.get(&"biomass_output", 0.0)),
			SYSTEMS[_current_system_index]["facility"],
		]
	if not _facility_origins.has(_system_id()):
		return "Develop this system: place its 6 × 6 civic facility."
	return "Connect this system: finish a player-authored road to the boundary."


func _set_feedback(message: String, is_error: bool) -> void:
	_latest_feedback = message
	_latest_feedback_is_error = is_error


func _load_textures() -> void:
	_road_textures = CohesiveMapVisuals.load_path_textures()
	for system in SYSTEMS:
		var system_id: StringName = system["id"]
		_map_textures[system_id] = AssetLoader.get_static_texture(
			system["map_asset"]
		)
		_building_textures[system_id] = AssetLoader.get_static_texture(
			system["building_asset"]
		)
		_vehicle_textures[system_id] = AssetLoader.get_static_texture(
			system["vehicle_asset"]
		)


func _is_valid_origin(origin: Vector2i) -> bool:
	return _current_build_tool().is_valid_origin(origin)


func _entry_route_for(index: int) -> Array[Vector2i]:
	var start := Vector2i(0, EXIT_ROWS[index])
	return _orthogonal_route(start, STAGING_CELLS[index])


func _orthogonal_route(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start]
	var cursor := start
	while cursor.x != target.x:
		cursor.x += signi(target.x - cursor.x)
		route.append(cursor)
	while cursor.y != target.y:
		cursor.y += signi(target.y - cursor.y)
		route.append(cursor)
	return route


func _path_position(path: Array[Vector2i], progress: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var clamped := clampf(progress, 0.0, maxf(0.0, float(path.size() - 1)))
	var first_index := mini(floori(clamped), path.size() - 1)
	var second_index := mini(first_index + 1, path.size() - 1)
	var fraction := clamped - float(first_index)
	return _cell_center(path[first_index]).lerp(
		_cell_center(path[second_index]),
		fraction
	)


func _route_for(source: Dictionary, system_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var value: Variant = source.get(system_id, [])
	if value is Array:
		for cell in value:
			if cell is Vector2i:
				result.append(cell)
	return result


func _system_id(index: int = -1) -> StringName:
	var resolved := _current_system_index if index < 0 else index
	return SYSTEMS[resolved]["id"]


func _pointer_to_grid(position: Vector2) -> Vector2i:
	var local := position - MAP_ORIGIN
	return Vector2i(
		floori(local.x / float(TILE_SIZE_PX)),
		floori(local.y / float(TILE_SIZE_PX))
	)


func _grid_to_pixel(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell * TILE_SIZE_PX)


func _cell_center(cell: Vector2i) -> Vector2:
	return _grid_to_pixel(cell) + Vector2.ONE * TILE_SIZE_PX * 0.5


func _is_grid_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < GRID_SIZE.x
		and cell.y < GRID_SIZE.y
	)


## Deterministic acceptance helpers.
func debug_place_facility(origin: Vector2i) -> bool:
	_select_facility()
	return _place_facility_at(origin)


func debug_finish_construction() -> bool:
	if _mode != Mode.CONSTRUCTING:
		return false
	_finish_facility_construction()
	return true


func debug_build_route(waypoints: Array[Vector2i] = []) -> bool:
	if _mode != Mode.ROUTING:
		return false
	var route_tool := _current_route_tool()
	route_tool.clear()
	if not route_tool.begin(route_tool.source_port):
		return false
	for waypoint in waypoints:
		if not route_tool.extend_to(waypoint):
			return false
	if not route_tool.extend_to(route_tool.target_port):
		return false
	if not route_tool.finish(route_tool.target_port):
		return false
	_mode = Mode.PLAN_READY
	_update_route_plan_feedback()
	return true


func debug_dispatch() -> bool:
	return _dispatch_to_next_system()


func debug_finish_delivery() -> void:
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_finish_delivery_leg()


func debug_select_bottleneck() -> bool:
	if _mode != Mode.BOTTLENECK:
		return false
	return _select_bottleneck_at(_current_operation_tool().bottleneck_cell)


func debug_repair_bottleneck() -> bool:
	return _repair_selected_bottleneck()


func debug_switch_system(index: int) -> bool:
	return _switch_system(index)


## Fast-forward the economy by the given number of seconds using the real tick,
## so acceptance runs do not have to wait in real time for biomass to build up.
func debug_advance_economy(seconds: float) -> void:
	_resources.apply_tick(seconds)
	_refresh_interface()


## Move the pointer onto a grid cell and return what the map-object card would
## show there. An empty dictionary means the cell carries no inspectable object.
func debug_inspect_cell(cell: Vector2i) -> Dictionary:
	_hover_cell = cell
	_update_context_cards()
	var content := _info_card_content()
	if content.is_empty():
		return {}
	content["card_visible"] = _info_card != null and _info_card.visible
	return content


func debug_hover_metric(metric_id: StringName) -> bool:
	if not _metric_containers.has(metric_id):
		return false
	_on_metric_hovered(metric_id)
	return _hover_panel != null and _hover_panel.visible


func debug_dismiss_completion_popup() -> bool:
	if not _completion_popup_visible():
		return false
	_dismiss_completion_popup()
	return true


func debug_snapshot() -> Dictionary:
	var system_id := _system_id()
	var operation_tool := _current_operation_tool()
	return {
		"mode": _mode,
		"current_system_index": _current_system_index,
		"unlocked_count": _unlocked_count,
		"facility_count": _facility_origins.size(),
		"completed_dispatch_count": _completed_dispatches.size(),
		"construction_progress": _construction_progress(),
		"current_facility_cost": _facility_cost(),
		"current_build_time_sec": _current_build_time_sec(),
		"delivery_path": _delivery_path.duplicate(),
		"route": _route_for(_outgoing_routes, system_id),
		"route_metrics": _route_metrics.get(system_id, {}).duplicate(true),
		"resources": {
			"biomass": _resources.biomass,
			"waste": _resources.waste,
			"stability": _resources.stability,
			"oxygen_supply": _resources.oxygen_supply,
			"oxygen_demand": _resources.oxygen_demand,
			"oxygen_ratio": _resources.oxygen_ratio,
			"biomass_rate": _resources.biomass_rate,
			"waste_rate": _resources.waste_rate,
			"stability_rate": _resources.stability_rate,
		},
		"economy_sources": _resources.sources(),
		"bottleneck_active": operation_tool.bottleneck_active,
		"bottleneck_selected": (
			operation_tool.selected_cell == operation_tool.bottleneck_cell
		),
		"repair_count": operation_tool.repair_count,
		"completion_popup_visible": _completion_popup_visible(),
		"latest_feedback": _latest_feedback,
		"latest_feedback_is_error": _latest_feedback_is_error,
	}
