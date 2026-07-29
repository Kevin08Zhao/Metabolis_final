class_name CohesiveMapVisuals
extends RefCounted

## Shared map rendering for the local builder sequence.
##
## The logical 16 px grid still controls placement, but it is a temporary tool
## overlay rather than the permanent visual identity of the world.

const GROUND := Color("#F7A39E")
const GROUND_LIGHT := Color("#FFC2B6")
const TISSUE_TOP := Color("#F27FA3")
const TISSUE_MID := Color("#BD4178")
const TISSUE_WALL := Color("#752754")
const OUTLINE := Color("#28152F")
const CYAN := Color("#64DDD8")
const CYAN_LIGHT := Color("#C7FFF4")
const GRID := Color(0.24, 0.10, 0.22, 0.10)

const PATH_TILE_BY_MASK := {
	0: 1,
	1: 2,
	2: 3,
	4: 4,
	8: 5,
	10: 6,
	5: 7,
	6: 8,
	12: 9,
	3: 10,
	9: 11,
	14: 12,
	13: 13,
	7: 15,
	15: 16,
	11: 17,
}

const CELL_BUBBLES := [
	Vector2(154, 66),
	Vector2(214, 126),
	Vector2(272, 286),
	Vector2(346, 112),
	Vector2(408, 264),
	Vector2(455, 158),
	Vector2(176, 252),
	Vector2(376, 206),
]


static func load_path_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for index in range(18):
		textures.append(
			AssetLoader.get_static_texture(
				StringName("tile_city_road_transparent_%02d" % index)
			)
		)
	return textures


static func draw_ground(
	canvas: CanvasItem,
	map_origin: Vector2,
	grid_size: Vector2i,
	tile_size_px: int,
	show_grid: bool
) -> void:
	var map_size := Vector2(grid_size * tile_size_px)
	canvas.draw_rect(Rect2(map_origin, map_size), GROUND)

	_draw_plateau(
		canvas,
		map_origin,
		PackedVector2Array([
			Vector2(0, 0),
			Vector2(126, 0),
			Vector2(136, 20),
			Vector2(128, 47),
			Vector2(96, 59),
			Vector2(54, 55),
			Vector2(23, 42),
			Vector2(0, 44),
		])
	)
	_draw_plateau(
		canvas,
		map_origin,
		PackedVector2Array([
			Vector2(474, 0),
			Vector2(640, 0),
			Vector2(640, 62),
			Vector2(610, 68),
			Vector2(570, 60),
			Vector2(532, 63),
			Vector2(495, 47),
		])
	)
	_draw_plateau(
		canvas,
		map_origin,
		PackedVector2Array([
			Vector2(0, 250),
			Vector2(38, 240),
			Vector2(82, 249),
			Vector2(115, 273),
			Vector2(126, 320),
			Vector2(0, 320),
		])
	)
	_draw_plateau(
		canvas,
		map_origin,
		PackedVector2Array([
			Vector2(500, 265),
			Vector2(539, 245),
			Vector2(586, 250),
			Vector2(616, 271),
			Vector2(640, 268),
			Vector2(640, 320),
			Vector2(494, 320),
		])
	)

	for bubble in CELL_BUBBLES:
		var center: Vector2 = map_origin + Vector2(bubble)
		canvas.draw_circle(center, 6.0, GROUND_LIGHT)
		canvas.draw_circle(center, 4.0, GROUND)
		canvas.draw_arc(center, 5.0, 0.0, TAU, 12, Color.WHITE, 1.0)
		canvas.draw_rect(
			Rect2(center + Vector2(2, -4), Vector2(2, 2)),
			CYAN_LIGHT
		)

	if not show_grid:
		return
	for column in range(grid_size.x + 1):
		var x := map_origin.x + column * tile_size_px
		canvas.draw_line(
			Vector2(x, map_origin.y),
			Vector2(x, map_origin.y + map_size.y),
			GRID,
			1.0
		)
	for row in range(grid_size.y + 1):
		var y := map_origin.y + row * tile_size_px
		canvas.draw_line(
			Vector2(map_origin.x, y),
			Vector2(map_origin.x + map_size.x, y),
			GRID,
			1.0
		)


static func draw_path(
	canvas: CanvasItem,
	path: Array[Vector2i],
	map_origin: Vector2,
	tile_size_px: int,
	textures: Array[Texture2D],
	failed: bool = false
) -> void:
	if path.is_empty():
		return
	for cell in path:
		var mask := _path_mask(cell, path)
		var texture_index: int = int(PATH_TILE_BY_MASK.get(mask, 1))
		if texture_index < 0 or texture_index >= textures.size():
			continue
		var texture := textures[texture_index]
		var rect := Rect2(
			map_origin + Vector2(cell * tile_size_px),
			Vector2.ONE * tile_size_px
		)
		canvas.draw_texture_rect(
			texture,
			rect,
			false,
			Color(1.0, 0.45, 0.52) if failed else Color.WHITE
		)


static func _path_mask(cell: Vector2i, path: Array[Vector2i]) -> int:
	var mask := 0
	if path.has(cell + Vector2i.UP):
		mask |= 1
	if path.has(cell + Vector2i.RIGHT):
		mask |= 2
	if path.has(cell + Vector2i.DOWN):
		mask |= 4
	if path.has(cell + Vector2i.LEFT):
		mask |= 8
	return mask


static func _draw_plateau(
	canvas: CanvasItem,
	map_origin: Vector2,
	local_points: PackedVector2Array
) -> void:
	var wall_points := PackedVector2Array()
	var top_points := PackedVector2Array()
	for point in local_points:
		wall_points.append(map_origin + point + Vector2(0, 7))
		top_points.append(map_origin + point)

	canvas.draw_colored_polygon(wall_points, OUTLINE)
	canvas.draw_polyline(
		_closed(wall_points),
		OUTLINE,
		3.0,
		false
	)
	canvas.draw_colored_polygon(top_points, TISSUE_MID)
	canvas.draw_polyline(
		_closed(top_points),
		OUTLINE,
		2.0,
		false
	)

	var inset := PackedVector2Array()
	var center := Vector2.ZERO
	for point in top_points:
		center += point
	center /= float(top_points.size())
	for point in top_points:
		inset.append(point.lerp(center, 0.10))
	canvas.draw_colored_polygon(inset, TISSUE_TOP)

	for index in range(0, top_points.size(), 2):
		var marker := top_points[index].lerp(center, 0.22)
		canvas.draw_rect(Rect2(marker, Vector2(3, 3)), TISSUE_WALL)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
