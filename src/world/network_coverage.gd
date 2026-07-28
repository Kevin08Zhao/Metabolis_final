class_name NetworkCoverage
extends RefCounted

## Calculates continuous transport coverage through the generated network graph.
##
## Interface records:
## - organs: organ_id, state, required_flow, and optional grid_position
## - nodes: NetworkBuilder node records
## - edges: NetworkBuilder edge records
## - source_node_ids: graph entry nodes that currently receive transport flow
## - delivered_flow_by_organ: actual settled delivery, keyed by organ_id
##
## Only completed and operating organs are traversable and included in the result.
## Nodes sharing a grid_position form a junction. Coverage follows Operation
## Specification E3: delivered / max(required, denominator floor), clamped to
## the configured normalized range. An unreachable organ receives the range min.

const PASSABLE_STATES: Array[StringName] = [
	&"completed",
	&"operating",
]

var _balance_access: Node


func configure(balance_access: Node) -> void:
	_balance_access = balance_access


func calculate_coverages(
	organs: Array[Dictionary],
	nodes: Array,
	edges: Array,
	source_node_ids: Array[StringName],
	delivered_flow_by_organ: Dictionary
) -> Dictionary:
	if _balance_access == null:
		push_warning("[COVERAGE] Cannot calculate without Balance.")
		return {}

	var organ_by_id: Dictionary = {}
	for organ in organs:
		var organ_id := StringName(organ.get("organ_id", ""))
		if organ_id.is_empty():
			continue
		organ_by_id[organ_id] = organ

	var adjacency: Dictionary = {}
	var node_owner: Dictionary = {}
	var node_positions: Dictionary = {}
	var nodes_by_position: Dictionary = {}
	for node_value in nodes:
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		var node_id := StringName(node.get("node_id", ""))
		var grid_position: Variant = node.get("grid_position")
		if node_id.is_empty() or not grid_position is Vector2i:
			continue
		adjacency[node_id] = []
		node_owner[node_id] = StringName(node.get("organ_id", ""))
		node_positions[node_id] = grid_position
		if not nodes_by_position.has(grid_position):
			nodes_by_position[grid_position] = []
		(nodes_by_position[grid_position] as Array).append(node_id)

	for edge_value in edges:
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var start_node_id := StringName(edge.get("start_node_id", ""))
		var end_node_id := StringName(edge.get("end_node_id", ""))
		if not adjacency.has(start_node_id) or not adjacency.has(end_node_id):
			continue
		_add_undirected_link(adjacency, start_node_id, end_node_id)

	for junction_nodes_value in nodes_by_position.values():
		var junction_nodes: Array = junction_nodes_value
		for left_index in range(junction_nodes.size()):
			for right_index in range(left_index + 1, junction_nodes.size()):
				_add_undirected_link(
					adjacency,
					StringName(junction_nodes[left_index]),
					StringName(junction_nodes[right_index])
				)

	var reachable := _breadth_first_search(
		adjacency,
		node_owner,
		organ_by_id,
		source_node_ids
	)
	var reachable_edges: Array[Dictionary] = []
	for edge_value in edges:
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		var start_node_id := StringName(edge.get("start_node_id", ""))
		var end_node_id := StringName(edge.get("end_node_id", ""))
		if (
			reachable.has(start_node_id)
			and reachable.has(end_node_id)
			and node_positions.has(start_node_id)
			and node_positions.has(end_node_id)
		):
			reachable_edges.append(edge)

	var distance_metric := StringName(
		_balance_access.call("get_value", "network.transport.distance_metric", "")
	)
	if distance_metric != &"manhattan":
		push_warning("[COVERAGE] Unsupported transport distance metric '%s'." % distance_metric)
		return {}

	var normalized_min := float(
		_balance_access.call("get_value", "operations.normalized.min", 0.0)
	)
	var normalized_max := float(
		_balance_access.call("get_value", "operations.normalized.max", 1.0)
	)
	var denominator_floor := float(
		_balance_access.call(
			"get_value",
			"network.transport.coverage.denominator_floor",
			0.0
		)
	)
	var no_demand_value := float(
		_balance_access.call(
			"get_value",
			"network.transport.coverage.no_demand_value",
			normalized_max
		)
	)
	if normalized_max < normalized_min or denominator_floor <= 0.0:
		push_warning("[COVERAGE] Invalid Balance coverage range or denominator.")
		return {}

	var result: Dictionary = {}
	for organ_id_value in organ_by_id:
		var organ_id := StringName(organ_id_value)
		var organ: Dictionary = organ_by_id[organ_id]
		if not _organ_is_passable(organ):
			continue
		var required_flow := float(organ.get("required_flow", 0.0))
		if required_flow <= 0.0:
			result[organ_id] = clampf(no_demand_value, normalized_min, normalized_max)
			continue
		var organ_position := _organ_grid_position(organ, organ_id, nodes)
		if (
			organ_position == Vector2i(-1, -1)
			or not _position_is_covered(
				organ_position,
				reachable_edges,
				node_positions,
				distance_metric
			)
		):
			result[organ_id] = normalized_min
			continue
		var delivered_flow := float(delivered_flow_by_organ.get(organ_id, 0.0))
		result[organ_id] = clampf(
			delivered_flow / maxf(required_flow, denominator_floor),
			normalized_min,
			normalized_max
		)
	return result


func lowest_coverage_organs(coverages: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for organ_id_value in coverages:
		records.append({
			"organ_id": StringName(organ_id_value),
			"coverage": float(coverages[organ_id_value]),
		})
	records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			if not is_equal_approx(float(left["coverage"]), float(right["coverage"])):
				return float(left["coverage"]) < float(right["coverage"])
			return String(left["organ_id"]) < String(right["organ_id"])
	)
	if records.size() > 3:
		records.resize(3)
	return records


func run_acceptance_test() -> Dictionary:
	var organs: Array[Dictionary] = [
		{"organ_id": &"organ_a", "state": &"completed", "required_flow": 10.0, "grid_position": Vector2i(0, 0)},
		{"organ_id": &"organ_b", "state": &"completed", "required_flow": 10.0, "grid_position": Vector2i(1, 0)},
		{"organ_id": &"organ_c", "state": &"operating", "required_flow": 10.0, "grid_position": Vector2i(2, 0)},
		{"organ_id": &"organ_d", "state": &"completed", "required_flow": 10.0, "grid_position": Vector2i(3, 1)},
	]
	var nodes: Array[Dictionary] = [
		{"node_id": &"node_a", "organ_id": &"organ_a", "grid_position": Vector2i(0, 0)},
		{"node_id": &"node_b", "organ_id": &"organ_b", "grid_position": Vector2i(1, 0)},
		{"node_id": &"node_c", "organ_id": &"organ_c", "grid_position": Vector2i(2, 0)},
		{"node_id": &"node_d", "organ_id": &"organ_d", "grid_position": Vector2i(3, 0)},
	]
	var chain_edges: Array[Dictionary] = [
		{"start_node_id": &"node_a", "end_node_id": &"node_b", "coverage_radius": 1.0},
		{"start_node_id": &"node_b", "end_node_id": &"node_c", "coverage_radius": 1.0},
		{"start_node_id": &"node_c", "end_node_id": &"node_d", "coverage_radius": 1.0},
	]
	var full_delivery := {
		&"organ_a": 10.0,
		&"organ_b": 10.0,
		&"organ_c": 10.0,
		&"organ_d": 10.0,
	}
	var full := calculate_coverages(organs, nodes, chain_edges, [&"node_a"], full_delivery)
	var partial_delivery := full_delivery.duplicate()
	partial_delivery[&"organ_d"] = 4.0
	var partial := calculate_coverages(
		organs,
		nodes,
		chain_edges,
		[&"node_a"],
		partial_delivery
	)
	var blocked_organs := organs.duplicate(true)
	blocked_organs[1]["state"] = &"under_construction"
	var blocked := calculate_coverages(
		blocked_organs,
		nodes,
		chain_edges,
		[&"node_a"],
		full_delivery
	)
	var ring_edges: Array[Dictionary] = [
		{"start_node_id": &"node_a", "end_node_id": &"node_b", "coverage_radius": 1.0},
		{"start_node_id": &"node_b", "end_node_id": &"node_c", "coverage_radius": 1.0},
		{"start_node_id": &"node_c", "end_node_id": &"node_a", "coverage_radius": 1.0},
	]
	var ring := calculate_coverages(organs, nodes, ring_edges, [&"node_a"], full_delivery)
	var narrow_edges := chain_edges.duplicate(true)
	narrow_edges[2]["coverage_radius"] = 0.0
	var narrow := calculate_coverages(organs, nodes, narrow_edges, [&"node_a"], full_delivery)
	var no_demand_organs := organs.duplicate(true)
	no_demand_organs[3]["required_flow"] = 0.0
	no_demand_organs[3]["grid_position"] = Vector2i(100, 100)
	var no_demand := calculate_coverages(
		no_demand_organs,
		nodes,
		chain_edges,
		[&"node_a"],
		full_delivery
	)
	var results := {
		"full": {"expected": 1.0, "actual": float(full[&"organ_d"])},
		"partial": {"expected": 0.4, "actual": float(partial[&"organ_d"])},
		"blocked": {"expected": 0.0, "actual": float(blocked[&"organ_c"])},
		"ring": {"expected": 1.0, "actual": float(ring[&"organ_c"])},
		"radius": {"expected": 0.0, "actual": float(narrow[&"organ_d"])},
		"no_demand": {"expected": 1.0, "actual": float(no_demand[&"organ_d"])},
	}
	for case_id in results:
		print(
			"[COVERAGE] ",
			case_id,
			" expected=",
			results[case_id]["expected"],
			" actual=",
			results[case_id]["actual"]
		)
	return results


func _organ_grid_position(
	organ: Dictionary,
	organ_id: StringName,
	nodes: Array
) -> Vector2i:
	var configured_position: Variant = organ.get("grid_position")
	if configured_position is Vector2i:
		return configured_position
	for node_value in nodes:
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		if StringName(node.get("organ_id", "")) != organ_id:
			continue
		var node_position: Variant = node.get("grid_position")
		if node_position is Vector2i:
			return node_position
	return Vector2i(-1, -1)


func _position_is_covered(
	position: Vector2i,
	reachable_edges: Array[Dictionary],
	node_positions: Dictionary,
	distance_metric: StringName
) -> bool:
	for edge in reachable_edges:
		var start_node_id := StringName(edge.get("start_node_id", ""))
		var end_node_id := StringName(edge.get("end_node_id", ""))
		var radius := float(edge.get("coverage_radius", -1.0))
		if radius < 0.0:
			continue
		var start_position: Vector2i = node_positions[start_node_id]
		var end_position: Vector2i = node_positions[end_node_id]
		var distance := _distance_to_edge(
			position,
			start_position,
			end_position,
			distance_metric
		)
		if distance <= radius:
			return true
	return false


func _distance_to_edge(
	position: Vector2i,
	start_position: Vector2i,
	end_position: Vector2i,
	distance_metric: StringName
) -> float:
	if distance_metric != &"manhattan":
		return INF
	if start_position.x == end_position.x:
		var nearest_y := clampi(position.y, mini(start_position.y, end_position.y), maxi(start_position.y, end_position.y))
		return float(absi(position.x - start_position.x) + absi(position.y - nearest_y))
	if start_position.y == end_position.y:
		var nearest_x := clampi(position.x, mini(start_position.x, end_position.x), maxi(start_position.x, end_position.x))
		return float(absi(position.x - nearest_x) + absi(position.y - start_position.y))
	return float(
		mini(
			absi(position.x - start_position.x) + absi(position.y - start_position.y),
			absi(position.x - end_position.x) + absi(position.y - end_position.y)
		)
	)


func _breadth_first_search(
	adjacency: Dictionary,
	node_owner: Dictionary,
	organ_by_id: Dictionary,
	source_node_ids: Array[StringName]
) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[StringName] = []
	for source_node_id in source_node_ids:
		if not adjacency.has(source_node_id):
			continue
		if not _node_is_passable(source_node_id, node_owner, organ_by_id):
			continue
		visited[source_node_id] = true
		queue.append(source_node_id)

	var queue_index := 0
	while queue_index < queue.size():
		var current_node_id := queue[queue_index]
		queue_index += 1
		for neighbor_value in adjacency[current_node_id]:
			var neighbor_id := StringName(neighbor_value)
			if visited.has(neighbor_id):
				continue
			if not _node_is_passable(neighbor_id, node_owner, organ_by_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return visited


func _node_is_passable(
	node_id: StringName,
	node_owner: Dictionary,
	organ_by_id: Dictionary
) -> bool:
	var organ_id := StringName(node_owner.get(node_id, ""))
	if organ_id.is_empty() or not organ_by_id.has(organ_id):
		return true
	return _organ_is_passable(organ_by_id[organ_id])


func _organ_is_passable(organ: Dictionary) -> bool:
	return PASSABLE_STATES.has(StringName(organ.get("state", "")))


func _add_undirected_link(
	adjacency: Dictionary,
	left_node_id: StringName,
	right_node_id: StringName
) -> void:
	if left_node_id == right_node_id:
		return
	var left_neighbors: Array = adjacency[left_node_id]
	var right_neighbors: Array = adjacency[right_node_id]
	if not left_neighbors.has(right_node_id):
		left_neighbors.append(right_node_id)
	if not right_neighbors.has(left_node_id):
		right_neighbors.append(left_node_id)
