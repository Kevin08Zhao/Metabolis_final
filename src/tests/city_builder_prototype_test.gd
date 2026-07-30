extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	AudioRouter.set_muted(true)
	await _test_tools()
	await _test_origin_scene()
	await _test_prototype_scene()
	await _test_system_city_scene()
	await _test_title_entry()
	if _failures.is_empty():
		print("[BUILDER TEST] RESULT PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("[BUILDER TEST] %s" % failure)
	print("[BUILDER TEST] RESULT FAIL count=", _failures.size())
	get_tree().quit(1)


func _test_tools() -> void:
	var build_tool := BuildTool.new()
	build_tool.configure(
		Vector2i(40, 20),
		Vector2i(6, 6),
		Rect2i(18, 3, 15, 14),
		[]
	)
	_expect(build_tool.set_preview(Vector2i(20, 8)), "valid heart origin must pass")
	_expect(build_tool.place_preview(), "valid heart preview must place")
	_expect(
		build_tool.placed_cells().size() == 36,
		"6 x 6 heart footprint must occupy thirty-six cells"
	)
	_expect(
		not build_tool.is_valid_origin(Vector2i(30, 14)),
		"footprint extending outside the body zone must fail"
	)

	var route_tool := RouteTool.new()
	route_tool.configure(
		Vector2i(40, 20),
		Vector2i(13, 10),
		Vector2i(19, 9),
		[]
	)
	_expect(route_tool.begin(Vector2i(13, 10)), "route must start at source port")
	_expect(route_tool.extend_to(Vector2i(17, 10)), "route must accept a partial segment")
	_expect(
		route_tool.extend_to(Vector2i(15, 10))
		and route_tool.segment_count() == 2,
		"drawing backward over the route must erase the redundant tail"
	)
	_expect(route_tool.extend_to(Vector2i(19, 9)), "route must extend to target")
	_expect(route_tool.finish(Vector2i(19, 9)), "route must finish at target port")
	_expect(route_tool.is_contiguous(), "committed route must be orthogonally contiguous")
	_expect(
		route_tool.segment_count() == 7 and route_tool.turn_count() == 1,
		"route tool must report length and bends for layout trade-offs"
	)

	var operation_tool := NetworkOperationTool.new()
	operation_tool.configure(route_tool.path())
	_expect(operation_tool.trigger_bottleneck(), "connected route must accept a bottleneck")
	_expect(
		operation_tool.coverage_percent() == 45
		and operation_tool.pressure_percent() == 82,
		"bottleneck must reduce coverage and raise pressure"
	)
	_expect(
		operation_tool.select_route_cell(operation_tool.bottleneck_cell),
		"bottleneck route cell must be directly selectable"
	)
	_expect(
		operation_tool.repair(6, 8),
		"selected bottleneck must repair with the exact resource cost"
	)
	_expect(
		operation_tool.coverage_percent() == 100
		and operation_tool.pressure_percent() == 12,
		"repair must restore normal network values"
	)


func _test_origin_scene() -> void:
	var packed := load("res://game/origin_builder_prototype.tscn") as PackedScene
	_expect(packed != null, "origin prototype scene must load")
	if packed == null:
		return
	var prototype := packed.instantiate() as OriginBuilderPrototype
	get_tree().root.add_child(prototype)
	await get_tree().process_frame

	_expect(
		not prototype.debug_place_cluster(Vector2i(2, 2)),
		"origin prototype must reject placement outside the origin zone"
	)
	_expect(
		prototype.debug_place_cluster(Vector2i(20, 8)),
		"origin prototype must accept direct cell-district placement"
	)
	_expect(
		prototype.debug_connect_route(),
		"origin prototype must accept a player-authored nutrient conduit"
	)
	var before: Dictionary = prototype.debug_snapshot()
	_expect(
		bool(before.get("route_complete", false))
		and int(before.get("coverage", 0)) == 100,
		"connected nutrient conduit must be complete and provide coverage"
	)
	_expect(prototype.debug_commit_plan(), "complete origin plan must commit")
	var after_commit: Dictionary = prototype.debug_snapshot()
	var resources: Dictionary = after_commit.get("resources", {})
	_expect(
		int(resources.get("nutrient_energy", 0)) == 58
		and int(resources.get("cell_material", 0)) == 32
		and int(resources.get("development_signal", 0)) == 39,
		"origin construction must deduct its resource costs exactly once"
	)

	await get_tree().create_timer(1.3).timeout
	var operating: Dictionary = prototype.debug_snapshot()
	_expect(
		int(operating.get("mode", -1)) == OriginBuilderPrototype.Mode.OPERATING,
		"origin construction must transition to operating"
	)
	for cycle in range(3):
		_expect(
			prototype.debug_run_division_cycle(),
			"origin division cycle %d must run" % (cycle + 1)
		)
	var complete: Dictionary = prototype.debug_snapshot()
	var final_resources: Dictionary = complete.get("resources", {})
	_expect(
		int(complete.get("division_cycles", 0)) == 3
		and bool(complete.get("origin_complete", false)),
		"three division cycles must complete the origin goal"
	)
	_expect(
		int(final_resources.get("nutrient_energy", 0)) == 52
		and int(final_resources.get("cell_material", 0)) == 41
		and int(final_resources.get("development_signal", 0)) == 39,
		"division cycles must consume nutrient energy and produce cell material"
	)
	prototype.queue_free()
	await get_tree().process_frame


func _test_prototype_scene() -> void:
	var packed := load("res://game/city_builder_prototype.tscn") as PackedScene
	_expect(packed != null, "prototype scene must load")
	if packed == null:
		return
	var prototype := packed.instantiate() as CityBuilderPrototype
	get_tree().root.add_child(prototype)
	await get_tree().process_frame

	_expect(
		not prototype.debug_place_heart(Vector2i(2, 2)),
		"prototype must reject placement outside the anatomical zone"
	)
	_expect(
		prototype.debug_place_heart(Vector2i(20, 8)),
		"prototype must accept direct heart placement in the anatomical zone"
	)
	_expect(
		prototype.debug_connect_route(),
		"prototype must accept a player-authored source-to-heart route"
	)
	var before: Dictionary = prototype.debug_snapshot()
	_expect(bool(before.get("route_complete", false)), "connected route must be complete")
	_expect(int(before.get("coverage", 0)) == 100, "connected route must provide coverage")
	_expect(prototype.debug_commit_plan(), "complete plan must commit")
	var after_commit: Dictionary = prototype.debug_snapshot()
	var resources: Dictionary = after_commit.get("resources", {})
	_expect(
		int(resources.get("nutrient_energy", 0)) == 56
		and int(resources.get("cell_material", 0)) == 55
		and int(resources.get("development_signal", 0)) == 53,
		"commit must deduct the prototype construction costs"
	)

	await get_tree().create_timer(1.6).timeout
	var operating: Dictionary = prototype.debug_snapshot()
	_expect(
		int(operating.get("mode", -1)) == CityBuilderPrototype.Mode.OPERATING,
		"construction must transition to operating"
	)
	_expect(
		prototype.debug_trigger_bottleneck(),
		"operating prototype must start the route stress scenario"
	)
	await get_tree().create_timer(0.6).timeout
	var stressed: Dictionary = prototype.debug_snapshot()
	var stressed_resources: Dictionary = stressed.get("resources", {})
	_expect(
		bool(stressed.get("bottleneck_active", false))
		and int(stressed.get("coverage", 0)) == 45
		and int(stressed.get("pressure", 0)) == 82,
		"live bottleneck must visibly change coverage and pressure"
	)
	_expect(
		int(stressed_resources.get("stability", 85)) < 85,
		"unrepaired bottleneck must reduce stability over time"
	)
	_expect(
		prototype.debug_select_bottleneck(),
		"player must be able to select the problem on the route"
	)
	_expect(
		prototype.debug_repair_bottleneck(),
		"selected route bottleneck must accept repair"
	)
	var repaired: Dictionary = prototype.debug_snapshot()
	var repaired_resources: Dictionary = repaired.get("resources", {})
	_expect(
		not bool(repaired.get("bottleneck_active", true))
		and int(repaired.get("coverage", 0)) == 100
		and int(repaired.get("pressure", 0)) == 12,
		"repair must restore coverage and normal pressure"
	)
	_expect(
		int(repaired_resources.get("cell_material", 0)) == 49
		and int(repaired_resources.get("development_signal", 0)) == 45
		and int(repaired.get("repair_count", 0)) == 1,
		"repair must deduct its resources exactly once"
	)
	prototype.queue_free()
	await get_tree().process_frame


func _test_system_city_scene() -> void:
	var packed := load("res://game/system_city_prototype.tscn") as PackedScene
	_expect(packed != null, "system-city prototype scene must load")
	if packed == null:
		return
	var prototype := packed.instantiate()
	get_tree().root.add_child(prototype)
	await get_tree().process_frame

	_expect(
		not prototype.debug_switch_system(1),
		"locked body-system map must reject manual switching"
	)
	var placements := [
		Vector2i(22, 7),
		Vector2i(22, 5),
		Vector2i(22, 9),
		Vector2i(22, 6),
	]
	for index in range(4):
		var before_build: Dictionary = prototype.debug_snapshot()
		var placement: Vector2i = placements[index]
		var build_zone: Rect2i = before_build.get(
			"current_build_zone",
			Rect2i()
		)
		_expect(
			build_zone.size.x >= 13
			and build_zone.size.y >= 11
			and int(before_build.get("background_avenue_count", 0)) >= 2
			and int(before_build.get("ambient_actor_count", 0)) == 3,
			"system %d must expose a spacious civic parcel, planned avenues, and ambient city life" % index
		)
		_expect(
			not prototype.debug_place_facility(Vector2i(2, 2)),
			"system %d must reject placement outside its civic construction zone" % index
		)
		_expect(
			prototype.debug_place_facility(placement),
			"system %d must accept a 6 x 6 facility inside its civic construction zone" % index
		)
		var constructing: Dictionary = prototype.debug_snapshot()
		_expect(
			bool(constructing.get("service_apron_active", false)),
			"system %d facility placement must create a grounded adaptive service apron" % index
		)
		var before_build_resources: Dictionary = before_build.get("resources", {})
		var constructing_resources: Dictionary = constructing.get("resources", {})
		var facility_cost: Dictionary = constructing.get("current_facility_cost", {})
		_expect(
			int(constructing.get("mode", -1))
			== SystemCityPrototype.Mode.CONSTRUCTING
			and is_equal_approx(
				float(constructing.get("current_build_time_sec", 0.0)),
				3.0
			),
			"system %d placement must begin a real three-second build" % index
		)
		_expect(
			int(constructing_resources.get("nutrient_energy", 0))
			== int(before_build_resources.get("nutrient_energy", 0))
			- int(facility_cost.get("nutrient_energy", 0))
			and int(constructing_resources.get("cell_material", 0))
			== int(before_build_resources.get("cell_material", 0))
			- int(facility_cost.get("cell_material", 0))
			and int(constructing_resources.get("development_signal", 0))
			== int(before_build_resources.get("development_signal", 0))
			- int(facility_cost.get("development_signal", 0)),
			"system %d placement must deduct the previewed building cost" % index
		)
		if index == 0:
			await get_tree().create_timer(3.1).timeout
			var built_after_wait: Dictionary = prototype.debug_snapshot()
			_expect(
				int(built_after_wait.get("mode", -1))
				== SystemCityPrototype.Mode.ROUTING
				and is_equal_approx(
					float(built_after_wait.get("construction_progress", 0.0)),
					1.0
				),
				"facility construction must finish after the real three-second wait"
			)
			var before_move_resources: Dictionary = built_after_wait.get(
				"resources",
				{}
			)
			_expect(
				not prototype.debug_place_facility(Vector2i(2, 2)),
				"facility relocation must remain inside the civic construction zone"
			)
			_expect(
				prototype.debug_place_facility(Vector2i(19, 8)),
				"facility must relocate within the civic construction zone"
			)
			var moved: Dictionary = prototype.debug_snapshot()
			var moved_resources: Dictionary = moved.get("resources", {})
			_expect(
				is_equal_approx(
					float(moved_resources.get("nutrient_energy", 0.0)),
					float(before_move_resources.get("nutrient_energy", 0.0))
				)
				and is_equal_approx(
					float(moved_resources.get("cell_material", 0.0)),
					float(before_move_resources.get("cell_material", 0.0))
				)
				and is_equal_approx(
					float(moved_resources.get("development_signal", 0.0)),
					float(before_move_resources.get("development_signal", 0.0))
				),
				"relocation must refund the old facility before charging the new one"
			)
		_expect(
			prototype.debug_finish_construction(),
			"system %d test build must be finishable after construction starts" % index
		)
		_expect(
			not prototype.debug_dispatch(),
			"system %d must reject automatic dispatch before a route exists" % index
		)
		var waypoints: Array[Vector2i] = []
		if index == 0:
			waypoints = [Vector2i(26, 5)]
		_expect(
			prototype.debug_build_route(waypoints),
			"system %d must accept a player-authored boundary route" % index
		)
		var planned: Dictionary = prototype.debug_snapshot()
		var metrics: Dictionary = planned.get("route_metrics", {})
		var route_cost: Dictionary = metrics.get("route_cost", {})
		_expect(
			int(metrics.get("road_cells", 0)) > 0
			and int(metrics.get("throughput", 0)) > 0
			and int(metrics.get("pressure", 0)) > 0,
			"system %d route must expose cost and performance metrics" % index
		)
		_expect(
			int(route_cost.get("cell_material", 0))
			== int(metrics.get("road_cells", 0))
			and int(route_cost.get("development_signal", 0)) == 0,
			"road cost must depend only on the number of occupied road tiles"
		)
		if index == 0:
			_expect(
				int(metrics.get("excess_segments", 0)) > 0
				and int(metrics.get("turns", 0)) >= 2
				and int(metrics.get("throughput", 100)) < 100,
				"a detoured route must be longer, bend more, and lose throughput"
			)
		_expect(
			prototype.debug_dispatch(),
			"system %d must commit its planned boundary network" % index
		)
		var committed: Dictionary = prototype.debug_snapshot()
		var before_resources: Dictionary = planned.get("resources", {})
		var after_resources: Dictionary = committed.get("resources", {})
		var total_cost: Dictionary = metrics.get("total_cost", {})
		_expect(
			int(after_resources.get("nutrient_energy", 0))
			== int(before_resources.get("nutrient_energy", 0))
			- int(total_cost.get("nutrient_energy", 0))
			and int(after_resources.get("cell_material", 0))
			== int(before_resources.get("cell_material", 0))
			- int(total_cost.get("cell_material", 0))
			and int(after_resources.get("development_signal", 0))
			== int(before_resources.get("development_signal", 0))
			- int(total_cost.get("development_signal", 0)),
			"system %d commit must deduct its displayed plan cost exactly once" % index
		)
		prototype.debug_finish_delivery()
		var post_delivery: Dictionary = prototype.debug_snapshot()
		if int(post_delivery.get("mode", -1)) == SystemCityPrototype.Mode.BOTTLENECK:
			_expect(
				bool(post_delivery.get("bottleneck_active", false)),
				"scripted system %d fault must appear on the committed route" % index
			)
			_expect(
				prototype.debug_select_bottleneck(),
				"system %d bottleneck must be selected on the map" % index
			)
			_expect(
				prototype.debug_repair_bottleneck(),
				"system %d bottleneck must consume resources and restore flow" % index
			)
		if index < 3:
			var unlocked: Dictionary = prototype.debug_snapshot()
			_expect(
				int(unlocked.get("unlocked_count", 0)) == index + 2
				and int(unlocked.get("current_system_index", -1)) == index + 1,
				"delivery must unlock and enter system %d" % (index + 1)
			)
			prototype.debug_finish_delivery()

	var complete: Dictionary = prototype.debug_snapshot()
	_expect(
		int(complete.get("mode", -1)) == SystemCityPrototype.Mode.COMPLETE
		and int(complete.get("unlocked_count", 0)) == 4
		and int(complete.get("facility_count", 0)) == 4
		and int(complete.get("completed_dispatch_count", 0)) == 4,
		"four facilities and four boundary dispatches must complete the body network"
	)
	var final_resources: Dictionary = complete.get("resources", {})
	_expect(
		int(final_resources.get("cell_material", 0)) > 0
		and int(final_resources.get("development_signal", 0)) > 0,
		"the four-system loop must remain economically completable"
	)
	_expect(
		prototype.debug_switch_system(0),
		"completed network must still allow switching to an unlocked map"
	)
	prototype.queue_free()
	await get_tree().process_frame


func _test_title_entry() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_expect(packed != null, "main scene must load")
	if packed == null:
		return
	var main := packed.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var button := main.find_child(
		"Entry_builder_prototype",
		true,
		false
	) as Button
	_expect(button != null, "title must expose Interactive Builder Prototype")
	if button != null:
		button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var router := main.get_node_or_null("SceneRouter") as SceneRouter
		_expect(router != null, "main scene must expose its scene router")
		if router != null:
			_expect(
				router.current_route() == SceneRouter.ROUTE_SYSTEM_CITY,
				"interactive entry must begin with the body-system city"
			)
		_expect(
			main.find_child("SystemCityPrototype", true, false) != null,
			"interactive entry must load the system-map scene"
		)
	main.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
