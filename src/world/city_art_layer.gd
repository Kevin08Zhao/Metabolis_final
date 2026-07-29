class_name CityArtLayer
extends Node2D

## Places landed construction and organ textures on the fixed 16 px city grid.

const TILE_SIZE_PX := 16
const FOOTPRINT_TILES := {
	&"standard_building": Vector2i(2, 2),
	&"landmark_organ": Vector2i(3, 3),
}
const ORGAN_ART_FAMILIES := {
	&"placenta_port": "organ_placenta",
	&"heart_pump": "organ_heart",
	&"lung_exchange": "organ_lungs",
	&"pulmonary_interface": "organ_lungs",
}
var _organ_sprites: Dictionary = {}
var _footprints: Dictionary = {}


func place_organ(
	organ_id: StringName,
	grid_origin: Vector2i,
	footprint_id: StringName,
	state_id: StringName = &"under_construction"
) -> Sprite2D:
	var sprite: Sprite2D = _organ_sprites.get(organ_id)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Organ_%s" % organ_id
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 3
		add_child(sprite)
		_organ_sprites[organ_id] = sprite
	_footprints[organ_id] = {
		"grid_origin": grid_origin,
		"footprint_id": footprint_id,
	}
	_apply_state(sprite, organ_id, grid_origin, footprint_id, state_id)
	return sprite


func set_organ_state(organ_id: StringName, state_id: StringName) -> bool:
	var sprite: Sprite2D = _organ_sprites.get(organ_id)
	var placement: Dictionary = _footprints.get(organ_id, {})
	if sprite == null or placement.is_empty():
		return false
	_apply_state(
		sprite,
		organ_id,
		placement["grid_origin"],
		placement["footprint_id"],
		state_id
	)
	return sprite.texture != null


func _apply_state(
	sprite: Sprite2D,
	organ_id: StringName,
	grid_origin: Vector2i,
	footprint_id: StringName,
	state_id: StringName
) -> void:
	var logical_name := _logical_texture_name(
		organ_id,
		footprint_id,
		state_id
	)
	if logical_name == &"":
		sprite.texture = null
		sprite.visible = false
		return
	sprite.texture = AssetLoader.get_static_texture(logical_name)
	sprite.visible = true
	var footprint: Vector2i = FOOTPRINT_TILES.get(
		footprint_id,
		Vector2i(2, 2)
	)
	var anchor := Vector2(
		grid_origin.x * TILE_SIZE_PX + footprint.x * TILE_SIZE_PX * 0.5,
		(grid_origin.y + footprint.y) * TILE_SIZE_PX
	)
	var rendered_size := Vector2(sprite.texture.get_size())
	sprite.position = anchor - Vector2(rendered_size.x * 0.5, rendered_size.y)


func _logical_texture_name(
	organ_id: StringName,
	footprint_id: StringName,
	state_id: StringName
) -> StringName:
	var family := str(ORGAN_ART_FAMILIES.get(organ_id, ""))
	if not family.is_empty():
		var resolved_state := str(state_id)
		if resolved_state not in [
			"blueprint",
			"under_construction",
			"completed",
			"operating",
			"stressed",
		]:
			resolved_state = "operating"
		return StringName("%s_%s" % [family, resolved_state])

	if state_id == &"operating" or state_id == &"completed":
		return &""
	var zone_kind := (
		"landmark"
		if footprint_id == &"landmark_organ"
		else "standard"
	)
	var zone_state := (
		"blueprint"
		if state_id == &"blueprint"
		else "under_construction"
	)
	return StringName("construction_zone_%s_%s" % [zone_kind, zone_state])
