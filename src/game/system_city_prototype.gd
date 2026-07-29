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
	DELIVERY_OUT,
	DELIVERY_IN,
	COMPLETE,
}

const LOG_PREFIX := "[SYSTEM CITY]"
const TILE_SIZE_PX := 16
const GRID_SIZE := Vector2i(40, 20)
const MAP_ORIGIN := Vector2(0, 40)
const MAP_SIZE := Vector2(640, 320)
const FACILITY_FOOTPRINT := Vector2i(6, 6)
const BUILD_ZONE := Rect2i(17, 3, 16, 14)
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
		"accent": Color("#F4B860"),
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
		"accent": Color("#E85D75"),
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
		"accent": Color("#D9A3E8"),
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
		"accent": Color("#9CE8DE"),
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
var _ambient_phase := 0.0

var _map_textures: Dictionary = {}
var _building_textures: Dictionary = {}
var _vehicle_textures: Dictionary = {}
var _road_textures: Array[Texture2D] = []

var _system_title: Label = null
var _network_status: Label = null
var _objective_label: Label = null
var _feedback_label: Label = null
var _build_button: Button = null
var _dispatch_button: Button = null
var _system_buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_load_textures()
	_build_interface()
	_incoming_routes[_system_id(0)] = _entry_route_for(0)
	_set_feedback(
		"Build the Nutrient Exchange Depot, then dispatch supplies across the body.",
		false
	)
	_refresh_interface()
	queue_redraw()
	print("%s Prototype ready with %d system maps." % [LOG_PREFIX, SYSTEMS.size()])


func _process(delta: float) -> void:
	_ambient_phase = fmod(_ambient_phase + delta * 2.4, 10000.0)
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_delivery_progress += delta * DELIVERY_SPEED_CELLS_PER_SEC
		if _delivery_progress >= float(_delivery_path.size()):
			_finish_delivery_leg()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = _pointer_to_grid(event.position)
		queue_redraw()
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _mode != Mode.PLACING:
		return
	_hover_cell = _pointer_to_grid(event.position)
	_place_facility_at(_hover_cell)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
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
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, SYSTEMS[_current_system_index]["accent"])
		draw_rect(rect, CohesiveMapVisuals.OUTLINE, false, 3.0)


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
	var zone_rect := Rect2(
		_grid_to_pixel(BUILD_ZONE.position),
		Vector2(BUILD_ZONE.size * TILE_SIZE_PX)
	)
	draw_rect(zone_rect, Color(COLOR_VALID, 0.10))
	draw_rect(zone_rect, Color(COLOR_VALID, 0.65), false, 2.0)
	if not _is_grid_cell(_hover_cell):
		return
	var preview := Rect2(
		_grid_to_pixel(_hover_cell),
		Vector2(FACILITY_FOOTPRINT * TILE_SIZE_PX)
	)
	var color := COLOR_VALID if _is_valid_origin(_hover_cell) else COLOR_INVALID
	draw_rect(preview, Color(color, 0.24))
	draw_rect(preview, color, false, 2.0)


func _build_interface() -> void:
	var top_bar := Panel.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(800, 40)
	top_bar.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL))
	add_child(top_bar)

	_system_title = Label.new()
	_system_title.position = Vector2(10, 7)
	_system_title.size = Vector2(410, 26)
	_system_title.add_theme_font_size_override("font_size", 15)
	top_bar.add_child(_system_title)

	_network_status = Label.new()
	_network_status.position = Vector2(420, 8)
	_network_status.size = Vector2(368, 24)
	_network_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_network_status.add_theme_font_size_override("font_size", 11)
	top_bar.add_child(_network_status)

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
	maps_title.add_theme_font_size_override("font_size", 11)
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
	_dispatch_button = _add_button(column, "DispatchCargo", "Dispatch Cargo")
	_dispatch_button.pressed.connect(_dispatch_to_next_system)

	var reset_button := _add_button(column, "ResetNetwork", "Reset Network")
	reset_button.pressed.connect(_reset_network)
	var title_button := _add_button(column, "ReturnToTitle", "Return to Title")
	title_button.pressed.connect(_return_to_title)

	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(8, 368)
	info_panel.size = Vector2(624, 74)
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color("#35202F")))
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(info_panel)

	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 5)
	info_panel.add_child(info_column)
	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 11)
	info_column.add_child(_objective_label)
	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 10)
	_feedback_label.custom_minimum_size = Vector2(600, 34)
	info_column.add_child(_feedback_label)


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


func _select_facility() -> void:
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN, Mode.COMPLETE]:
		return
	if _facility_origins.has(_system_id()):
		_set_feedback("This system facility is already established.", true)
		return
	_mode = Mode.PLACING
	_set_feedback(
		"Click a valid 6 × 6 location inside the highlighted construction district.",
		false
	)
	_refresh_interface()
	queue_redraw()


func _place_facility_at(origin: Vector2i) -> bool:
	if _mode != Mode.PLACING:
		return false
	if not _is_valid_origin(origin):
		_set_feedback(
			"The complete 6 × 6 facility must stay inside the highlighted district.",
			true
		)
		queue_redraw()
		return false
	_facility_origins[_system_id()] = origin
	_mode = Mode.READY
	_set_feedback(
		"%s established. Dispatch %s to the next body system."
		% [
			SYSTEMS[_current_system_index]["facility"],
			SYSTEMS[_current_system_index]["cargo"],
		],
		false
	)
	print(
		"%s Placed %s at %s."
		% [LOG_PREFIX, SYSTEMS[_current_system_index]["facility"], origin]
	)
	_refresh_interface()
	queue_redraw()
	return true


func _dispatch_to_next_system() -> bool:
	if _mode != Mode.READY:
		return false
	var system_id := _system_id()
	if not _facility_origins.has(system_id):
		_set_feedback("Place this system's facility before dispatching cargo.", true)
		return false
	if _completed_dispatches.get(system_id, false):
		_set_feedback("This cross-system delivery link is already operating.", true)
		return false

	var origin: Vector2i = _facility_origins[system_id]
	var start := Vector2i(
		origin.x + FACILITY_FOOTPRINT.x,
		origin.y + 3
	)
	var target := Vector2i(GRID_SIZE.x - 1, EXIT_ROWS[_current_system_index])
	var route := _orthogonal_route(start, target)
	_outgoing_routes[system_id] = route
	_delivery_path = route
	_delivery_progress = 0.0
	_delivery_system_index = _current_system_index
	_mode = Mode.DELIVERY_OUT
	_set_feedback(
		"A dedicated delivery vehicle is carrying %s toward the map boundary."
		% SYSTEMS[_current_system_index]["cargo"],
		false
	)
	print("%s Dispatch left %s." % [LOG_PREFIX, SYSTEMS[_current_system_index]["name"]])
	_refresh_interface()
	queue_redraw()
	return true


func _finish_delivery_leg() -> void:
	if _mode == Mode.DELIVERY_OUT:
		_completed_dispatches[_system_id(_delivery_system_index)] = true
		var next_index := _delivery_system_index + 1
		if next_index >= SYSTEMS.size():
			_mode = Mode.COMPLETE
			_delivery_path.clear()
			_set_feedback(
				"All four body-system maps now exchange resources through the city network.",
				false
			)
			print("%s Full body network complete." % LOG_PREFIX)
			_refresh_interface()
			return
		_unlocked_count = maxi(_unlocked_count, next_index + 1)
		_current_system_index = next_index
		var incoming := _entry_route_for(next_index)
		_incoming_routes[_system_id(next_index)] = incoming
		_delivery_path = incoming
		_delivery_progress = 0.0
		_delivery_system_index = next_index
		_mode = Mode.DELIVERY_IN
		_set_feedback(
			"%s unlocked. The same delivery has reappeared at this map's boundary."
			% SYSTEMS[next_index]["name"],
			false
		)
		print("%s Unlocked %s." % [LOG_PREFIX, SYSTEMS[next_index]["name"]])
		_refresh_interface()
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


func _switch_system(index: int) -> bool:
	if index < 0 or index >= _unlocked_count:
		_set_feedback("Develop the previous body system to unlock this map.", true)
		return false
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_set_feedback("Wait for the current cross-boundary delivery to arrive.", true)
		return false
	_current_system_index = index
	_mode = Mode.COMPLETE if (
		index == SYSTEMS.size() - 1
		and _completed_dispatches.get(_system_id(index), false)
	) else Mode.READY
	_set_feedback("Switched to the %s map." % SYSTEMS[index]["name"], false)
	_refresh_interface()
	queue_redraw()
	print("%s Switched to %s." % [LOG_PREFIX, SYSTEMS[index]["name"]])
	return true


func _reset_network() -> void:
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
	_incoming_routes[_system_id(0)] = _entry_route_for(0)
	_set_feedback("Network reset. Begin with the Nutrient Exchange map.", false)
	_refresh_interface()
	queue_redraw()


func _return_to_title() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to_title"):
			node.call_deferred("go_to_title")
			return
		node = node.get_parent()


func _refresh_interface() -> void:
	if _system_title == null:
		return
	_system_title.text = "%s MAP" % SYSTEMS[_current_system_index]["name"].to_upper()
	_network_status.text = "Systems online: %d / %d" % [
		_unlocked_count,
		SYSTEMS.size(),
	]
	_objective_label.text = _objective_text()
	for index in range(_system_buttons.size()):
		var unlocked := index < _unlocked_count
		_system_buttons[index].disabled = (
			not unlocked
			or _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]
		)
		_system_buttons[index].text = "%s%s" % [
			"● %d " % (index + 1) if index == _current_system_index else "%d " % (index + 1),
			SYSTEMS[index]["short"] if unlocked else "LOCKED",
		]
	var has_facility := _facility_origins.has(_system_id())
	_build_button.disabled = (
		has_facility
		or _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN, Mode.COMPLETE]
	)
	_dispatch_button.disabled = (
		not has_facility
		or _completed_dispatches.get(_system_id(), false)
		or _mode != Mode.READY
	)
	_dispatch_button.text = (
		"Complete Network"
		if _current_system_index == SYSTEMS.size() - 1
		else "Dispatch Cargo"
	)


func _objective_text() -> String:
	if _mode == Mode.COMPLETE:
		return "Body network complete: all system maps exchange resources."
	if _mode == Mode.PLACING:
		return "Place %s inside the highlighted district." % SYSTEMS[_current_system_index]["facility"]
	if _mode == Mode.DELIVERY_OUT:
		return "Delivery in transit: vehicle exits this map at the city boundary."
	if _mode == Mode.DELIVERY_IN:
		return "Delivery continuity: vehicle has entered the newly unlocked map."
	if not _facility_origins.has(_system_id()):
		return "Develop this system: place its 6 × 6 civic facility."
	return "Connect this system: dispatch cargo through the boundary road."


func _set_feedback(message: String, is_error: bool) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(
		"font_color",
		COLOR_INVALID if is_error else COLOR_TEXT
	)


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
	var footprint := Rect2i(origin, FACILITY_FOOTPRINT)
	if not BUILD_ZONE.encloses(footprint):
		return false
	var staging: Vector2i = STAGING_CELLS[_current_system_index]
	return not footprint.has_point(staging)


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


func debug_dispatch() -> bool:
	return _dispatch_to_next_system()


func debug_finish_delivery() -> void:
	if _mode in [Mode.DELIVERY_OUT, Mode.DELIVERY_IN]:
		_finish_delivery_leg()


func debug_switch_system(index: int) -> bool:
	return _switch_system(index)


func debug_snapshot() -> Dictionary:
	return {
		"mode": _mode,
		"current_system_index": _current_system_index,
		"unlocked_count": _unlocked_count,
		"facility_count": _facility_origins.size(),
		"completed_dispatch_count": _completed_dispatches.size(),
		"delivery_path": _delivery_path.duplicate(),
	}
