class_name NetworkBuilder
extends Node2D

## Generates and draws deterministic transport-network extensions.
##
## Node record fields:
## - node_id: deterministic identifier
## - organ_id: owning organ identifier
## - trunk_route_id: selected route identifier
## - sequence: zero-based position along the extension
## - grid_position: integer grid coordinate
## - pixel_position: integer pixel coordinate aligned to the Balance tile size
##
## Edge record fields:
## - edge_id, start_node_id, end_node_id
## - organ_id, trunk_route_id, extension_profile_id, spec_tier_id
## - coverage_radius, base_capacity, capacity_multiplier, effective_capacity
##
## test_determinism() generates the same input twice and compares every node and
## edge field. Tier acceptance: heart_reinforced reads six tiles and radius 2.5;
## heart_early_flow reads five tiles and radius 2.0 from Balance.

const PLACEHOLDER_COLOR := Color("#6f8f9d")
const PLACEHOLDER_WIDTH_PX := 2.0

var nodes: Array:
	get:
		return _nodes.duplicate(true)

var edges: Array:
	get:
		return _edges.duplicate(true)

var _balance_access: Node
var _event_bus: Node
var _nodes: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _route_lines: Dictionary = {}


func configure(balance_access: Node, event_bus: Node) -> void:
	_disconnect_event_bus()
	_balance_access = balance_access
	_event_bus = event_bus
	if _event_bus == null or not _event_bus.has_signal("organ_built"):
		push_warning("[NETWORK] Event bus is missing organ_built.")
		return
	_event_bus.connect("organ_built", _on_organ_built)


func generate_extension(
	organ_id: StringName,
	decision_id: StringName,
	option_id: StringName
) -> Dictionary:
	if _balance_access == null:
		push_warning("[NETWORK] Cannot generate without Balance.")
		return {}
	var option_path := "build_options.%s.%s" % [decision_id, option_id]
	var network_variant: Variant = _balance_access.call(
		"get_value",
		"%s.network" % option_path,
		{}
	)
	if not network_variant is Dictionary:
		push_warning("[NETWORK] Missing network input for '%s'." % option_id)
		return {}
	var network: Dictionary = network_variant
	var start_anchor := _read_coordinate(network.get("start_anchor"))
	var end_anchor := _read_coordinate(network.get("end_anchor"))
	if start_anchor == Vector2i(-1, -1) or end_anchor == Vector2i(-1, -1):
		push_warning("[NETWORK] Invalid anchors for '%s'." % option_id)
		return {}

	var trunk_route_id := StringName(network.get("trunk_route_id", ""))
	var extension_profile_id := StringName(network.get("extension_profile_id", ""))
	var spec_tier_id := StringName(network.get("spec_tier_id", ""))
	var base_capacity := _read_number(network.get("network_capacity"))
	var extension_length := int(
		_balance_access.call(
			"get_value",
			"%s.network.extension_length_by_spec.%s" % [option_path, spec_tier_id],
			0
		)
	)
	var coverage_radius := float(
		_balance_access.call(
			"get_value",
			"network.transport.coverage_radius_by_spec.%s" % spec_tier_id,
			-1.0
		)
	)
	var capacity_multiplier := float(
		_balance_access.call(
			"get_value",
			"network.transport.capacity_multiplier_by_spec.%s" % spec_tier_id,
			-1.0
		)
	)
	var tile_size_px := int(
		_balance_access.call("get_value", "build_options.grid.tile_size_px", 0)
	)
	if (
		trunk_route_id.is_empty()
		or extension_profile_id.is_empty()
		or spec_tier_id.is_empty()
		or base_capacity < 0.0
		or extension_length <= 0
		or coverage_radius < 0.0
		or capacity_multiplier < 0.0
		or tile_size_px <= 0
		or start_anchor == end_anchor
	):
		push_warning("[NETWORK] Invalid extension parameters for '%s'." % option_id)
		return {}

	var route_nodes: Array[Dictionary] = []
	var route_edges: Array[Dictionary] = []
	var delta := end_anchor - start_anchor
	var dominant_distance := maxi(absi(delta.x), absi(delta.y))
	var grid_step := Vector2(delta) / float(dominant_distance)
	for sequence in range(extension_length + 1):
		var grid_position := Vector2i(
			roundi(start_anchor.x + grid_step.x * sequence),
			roundi(start_anchor.y + grid_step.y * sequence)
		)
		var node_id := StringName("%s_node_%02d" % [trunk_route_id, sequence])
		route_nodes.append({
			"node_id": node_id,
			"organ_id": organ_id,
			"trunk_route_id": trunk_route_id,
			"sequence": sequence,
			"grid_position": grid_position,
			"pixel_position": grid_position * tile_size_px,
		})
		if sequence == 0:
			continue
		route_edges.append({
			"edge_id": StringName("%s_edge_%02d" % [trunk_route_id, sequence - 1]),
			"start_node_id": route_nodes[sequence - 1]["node_id"],
			"end_node_id": node_id,
			"organ_id": organ_id,
			"trunk_route_id": trunk_route_id,
			"extension_profile_id": extension_profile_id,
			"spec_tier_id": spec_tier_id,
			"coverage_radius": coverage_radius,
			"base_capacity": base_capacity,
			"capacity_multiplier": capacity_multiplier,
			"effective_capacity": base_capacity * capacity_multiplier,
		})

	return {
		"nodes": route_nodes,
		"edges": route_edges,
	}


func test_determinism(
	organ_id: StringName,
	decision_id: StringName,
	option_id: StringName
) -> bool:
	var first := generate_extension(organ_id, decision_id, option_id)
	var second := generate_extension(organ_id, decision_id, option_id)
	if first.is_empty() or second.is_empty():
		return false
	return (
		_record_arrays_equal(first["nodes"], second["nodes"])
		and _record_arrays_equal(first["edges"], second["edges"])
	)


func _on_organ_built(
	organ_id: StringName,
	_slot_id: StringName,
	option_id: StringName
) -> void:
	var decision_id := _find_decision_id(option_id)
	if decision_id.is_empty():
		push_warning("[NETWORK] Cannot find decision for option '%s'." % option_id)
		return
	var extension := generate_extension(organ_id, decision_id, option_id)
	if extension.is_empty():
		return
	_publish_extension(extension)


func _publish_extension(extension: Dictionary) -> void:
	var route_nodes: Array = extension["nodes"]
	var route_edges: Array = extension["edges"]
	if route_nodes.is_empty():
		return
	var trunk_route_id: StringName = route_nodes[0]["trunk_route_id"]
	if _route_lines.has(trunk_route_id):
		push_warning("[NETWORK] Route '%s' is already published." % trunk_route_id)
		return
	for node_record in route_nodes:
		_nodes.append((node_record as Dictionary).duplicate(true))
	for edge_record in route_edges:
		_edges.append((edge_record as Dictionary).duplicate(true))

	var line := Line2D.new()
	line.name = "Route_%s" % trunk_route_id
	line.default_color = PLACEHOLDER_COLOR
	line.width = PLACEHOLDER_WIDTH_PX
	var points := PackedVector2Array()
	for node_record in route_nodes:
		points.append(Vector2(node_record["pixel_position"]))
	line.points = points
	add_child(line)
	_route_lines[trunk_route_id] = line
	print(
		"[NETWORK] published route=",
		trunk_route_id,
		" nodes=",
		route_nodes.size(),
		" edges=",
		route_edges.size()
	)


func _find_decision_id(option_id: StringName) -> StringName:
	var build_options_variant: Variant = _balance_access.call("get_value", "build_options", {})
	if not build_options_variant is Dictionary:
		return StringName()
	var build_options: Dictionary = build_options_variant
	for key in build_options:
		var decision_variant: Variant = build_options[key]
		if decision_variant is Dictionary and decision_variant.has(option_id):
			return StringName(key)
	return StringName()


func _record_arrays_equal(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if not first[index] is Dictionary or not second[index] is Dictionary:
			return false
		var first_record: Dictionary = first[index]
		var second_record: Dictionary = second[index]
		if first_record.size() != second_record.size():
			return false
		for field in first_record:
			if not second_record.has(field) or first_record[field] != second_record[field]:
				return false
	return true


func _read_coordinate(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i(-1, -1)
	if (
		(not value[0] is float and not value[0] is int)
		or (not value[1] is float and not value[1] is int)
	):
		return Vector2i(-1, -1)
	return Vector2i(int(value[0]), int(value[1]))


func _read_number(value: Variant) -> float:
	if not value is float and not value is int:
		return -1.0
	return float(value)


func _disconnect_event_bus() -> void:
	if not is_instance_valid(_event_bus):
		return
	if _event_bus.is_connected("organ_built", _on_organ_built):
		_event_bus.disconnect("organ_built", _on_organ_built)
