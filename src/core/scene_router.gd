class_name SceneRouter
extends Node

## Title screen entry and scene routing.
##
## Owns which main scene is resident and, on the title, which entries the player
## is offered. Both are decisions rather than presentation: this script produces
## no art, and its buttons use the engine's default style with placeholder text
## so that D-14 and D-17 can replace them without touching routing.
##
## Exactly one primary scene is resident at a time. The outgoing scene is removed
## from the tree and freed before the incoming one is added, not queued for
## deletion alongside it, so there is never a frame with two of them present.
##
## The title offers what the save can actually support and nothing more. No save
## means one entry. A save means continue and new game, and chapter select only
## when at least one finished stage has a snapshot that can really be entered -
## offering it otherwise would open an empty list.
##
## docs/EVENT_API.md defines no scene-routing event and this script adds none.
## Routing is not an animation or audio moment; the beats that are already have
## their own rows. Callers listen to `route_changed` instead.
##
## Requires the `SaveManager` and `Balance` autoloads.

const LOG_PREFIX := "[ROUTE]"

## The original title, game, and ending routes remain unchanged. The local
## builder sequence is a parallel entry used to migrate the four-stage flow one
## playable map-first slice at a time.
const ROUTE_TITLE := &"title"
const ROUTE_GAME := &"game"
const ROUTE_ENDING := &"ending"
const ROUTE_ORIGIN_BUILDER := &"origin_builder"
const ROUTE_BUILDER_PROTOTYPE := &"builder_prototype"
const ROUTE_SYSTEM_CITY := &"system_city"

## Title entries, in the order they are offered.
const ENTRY_CONTINUE := &"continue"
const ENTRY_NEW_GAME := &"new_game"
const ENTRY_CHAPTER_SELECT := &"chapter_select"
const ENTRY_BUILDER_PROTOTYPE := &"builder_prototype"

## Placeholder text. The display name is the full one; the internal identifier
## stays Metabolis, per the naming rules in docs/CONTEXT.md.
const ENTRY_LABELS := {
	ENTRY_CONTINUE: "Continue",
	ENTRY_NEW_GAME: "New Game",
	ENTRY_CHAPTER_SELECT: "Chapter Select",
	ENTRY_BUILDER_PROTOTYPE: "Body-System City Builder",
}
const CONFIRM_LABEL := "New Game will overwrite your progress. Confirm?"
const CONFIRM_YES := "Yes, start a new game"
const CONFIRM_NO := "No, go back"

## A node in this group inside the loaded title scene receives the entry
## buttons. Without one, or without a title scene at all, the menu is built
## under the router itself, which is what happened before the scenes existed.
const TITLE_MENU_ANCHOR_GROUP := &"title_menu_anchor"

## A TextureRect in this group inside the title scene gets the background filled
## in at runtime. It cannot be filled in the scene file: art/ lives outside the
## Godot project root, so no ext_resource can reach it, and AssetLoader reading
## res://../art is the only route to an image there.
const TITLE_BACKGROUND_GROUP := &"title_background"

## The logical name AssetLoader resolves, in its {category}_{subject}_{variant}
## form. docs/assets/D-29_MANIFEST.md records the landed file this names.
const TITLE_BACKGROUND_ASSET := &"background_title"

## Where each route's scene lives. Assigned rather than hardcoded at the point of
## use so an integrator can repoint them; the registration steps in
## docs/coord/done/T-32.md say which scenes to create.
##
## The title entry is optional. Leave it empty and the title stays what T-32
## delivered: a menu the router builds itself, with no scene resident. Point it
## at a scene and the title becomes a scene like the other two, which is what
## D-29 needs in order to dress it.
var scene_paths := {
	ROUTE_TITLE: "res://ui/title.tscn",
	ROUTE_GAME: "res://game/main.tscn",
	ROUTE_ENDING: "res://ui/ending.tscn",
	ROUTE_ORIGIN_BUILDER: "res://game/origin_builder_prototype.tscn",
	ROUTE_BUILDER_PROTOTYPE: "res://game/city_builder_prototype.tscn",
	ROUTE_SYSTEM_CITY: "res://game/system_city_prototype.tscn",
}

signal route_changed(route: StringName)
## Emitted when the title entries are rebuilt, carrying what is on offer.
signal title_entries_changed(entries: Array[StringName])

var _route: StringName = &""
var _awaiting_new_game_confirmation: bool = false
var _scene_host: Node = null
var _title_menu: VBoxContainer = null
var _resident_scene: Node = null
var _ending_summary: Dictionary = {}


func _ready() -> void:
	_scene_host = Node.new()
	_scene_host.name = "SceneHost"
	add_child(_scene_host)
	# Boot routing: always open the title on launch. Deferred so the autoloads
	# that go_to_title reads (SaveManager, Balance) are fully ready.
	call_deferred("go_to_title")


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

## Show the title and build its entries from what the save can support.
##
## The title scene is loaded when one is registered, and the entries go into its
## anchor. When none is registered the router builds the menu under itself and
## leaves nothing resident, which is the behaviour T-32 delivered and accepted.
func go_to_title() -> void:
	_awaiting_new_game_confirmation = false
	_free_title_menu()
	_free_resident_scene()
	_route = ROUTE_TITLE
	_load_title_scene()
	_build_title_menu()
	print("%s title" % LOG_PREFIX)
	route_changed.emit(_route)


## Put the title scene in the host, if there is one to put there. A registered
## path that will not load is an error rather than a silent fallback: a title
## that quietly loses its background is worse than one that says why.
func _load_title_scene() -> void:
	var path: String = str(scene_paths.get(ROUTE_TITLE, ""))
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_error("%s Title scene '%s' is registered but does not exist." % [LOG_PREFIX, path])
		return

	var packed: PackedScene = load(path)
	if packed == null:
		push_error("%s Could not load the title scene '%s'." % [LOG_PREFIX, path])
		return

	_resident_scene = packed.instantiate()
	_scene_host.add_child(_resident_scene)
	_fill_title_background()


## Put the accepted background into the slot the title scene reserved for it.
## A missing slot is silent, because a title scene is allowed not to have one.
## A slot that stays empty is not: AssetLoader returns its placeholder rather
## than null when the file is missing, so an empty texture here means the loader
## is not registered, which is worth saying out loud.
func _fill_title_background() -> void:
	var tree := get_tree()
	if tree == null or _resident_scene == null:
		return
	for node in tree.get_nodes_in_group(TITLE_BACKGROUND_GROUP):
		if not (_resident_scene.is_ancestor_of(node) or node == _resident_scene):
			continue
		if not node is TextureRect:
			push_warning(
				"%s '%s' is in group '%s' but is not a TextureRect."
				% [LOG_PREFIX, node.name, TITLE_BACKGROUND_GROUP]
			)
			continue
		var slot: TextureRect = node
		slot.texture = AssetLoader.get_static_texture(TITLE_BACKGROUND_ASSET)
		if slot.texture == null:
			push_error(
				"%s The title background slot is still empty after asking for '%s'."
				% [LOG_PREFIX, TITLE_BACKGROUND_ASSET]
			)


## Where the entry buttons go. The anchor inside the title scene when there is
## one, and the router itself when there is not.
func _title_menu_parent() -> Node:
	if _resident_scene == null or not is_instance_valid(_resident_scene):
		return self
	var tree := get_tree()
	if tree == null:
		return self
	for node in tree.get_nodes_in_group(TITLE_MENU_ANCHOR_GROUP):
		if _resident_scene.is_ancestor_of(node) or node == _resident_scene:
			return node
	push_warning(
		"%s The title scene has no node in group '%s'; the entries were built outside it."
		% [LOG_PREFIX, TITLE_MENU_ANCHOR_GROUP]
	)
	return self


## Continue the existing run. Refused when there is nothing to continue.
func continue_game() -> bool:
	if not has_save():
		push_warning("%s Nothing to continue." % LOG_PREFIX)
		return false
	return _enter_route(ROUTE_GAME)


## Ask for a new game. Never starts one: it arms the confirmation and rebuilds the
## title so the player has to answer. A destructive action gets a second look.
func request_new_game() -> bool:
	if _route != ROUTE_TITLE:
		return false
	if not has_save():
		# Nothing to overwrite, so nothing to confirm.
		return _enter_route(ROUTE_GAME)
	_awaiting_new_game_confirmation = true
	print("%s new game requested; waiting for confirmation." % LOG_PREFIX)
	_build_title_menu()
	return false


func confirm_new_game() -> bool:
	if not _awaiting_new_game_confirmation:
		push_warning("%s No new game was requested." % LOG_PREFIX)
		return false
	_awaiting_new_game_confirmation = false
	print("%s new game confirmed." % LOG_PREFIX)
	return _enter_route(ROUTE_GAME)


func cancel_new_game() -> void:
	if not _awaiting_new_game_confirmation:
		return
	_awaiting_new_game_confirmation = false
	print("%s new game cancelled." % LOG_PREFIX)
	_build_title_menu()


func open_chapter_select() -> bool:
	if not chapter_select_available():
		push_warning("%s Chapter select has nothing to offer." % LOG_PREFIX)
		return false
	return _enter_route(ROUTE_GAME)


func open_builder_prototype() -> bool:
	return _enter_route(ROUTE_BUILDER_PROTOTYPE)


func open_origin_builder() -> bool:
	return _enter_route(ROUTE_ORIGIN_BUILDER)


func open_system_city() -> bool:
	return _enter_route(ROUTE_SYSTEM_CITY)


func go_to_ending(summary: Dictionary = {}) -> bool:
	_ending_summary = summary.duplicate(true)
	return _enter_route(ROUTE_ENDING)


func ending_summary() -> Dictionary:
	return _ending_summary.duplicate(true)


func current_route() -> StringName:
	return _route


func awaiting_new_game_confirmation() -> bool:
	return _awaiting_new_game_confirmation


# ---------------------------------------------------------------------------
# What the title offers
# ---------------------------------------------------------------------------

## The entries the title should show, in order. While a new game is awaiting
## confirmation the list is replaced by the two answers, so the player cannot
## sidestep the question by pressing something else.
func title_entries() -> Array[StringName]:
	if _awaiting_new_game_confirmation:
		return [ENTRY_NEW_GAME]
	var entries: Array[StringName] = []
	if has_save():
		entries.append(ENTRY_CONTINUE)
	entries.append(ENTRY_NEW_GAME)
	entries.append(ENTRY_BUILDER_PROTOTYPE)
	if chapter_select_available():
		entries.append(ENTRY_CHAPTER_SELECT)
	return entries


## A save counts when the file loaded well enough to leave progress behind. A
## corrupt file is not a save to continue from, and T-27 already reports that.
func has_save() -> bool:
	var progress: Dictionary = SaveManager.build_payload().get("main_progress", {})
	return not progress.is_empty()


## Only when a finished stage has a snapshot that can genuinely be entered.
## Showing the entry for an empty list would be worse than hiding it.
func chapter_select_available() -> bool:
	for stage_id in completed_stage_ids():
		if SaveManager.can_replay_stage(stage_id):
			return true
	return false


## Stages the main line has moved past, walked from configuration rather than
## listed here.
func completed_stage_ids() -> Array[StringName]:
	var finished: Array[StringName] = []
	var progress: Dictionary = SaveManager.build_payload().get("main_progress", {})
	var current := StringName(str(progress.get("current_stage_id", "")))
	if current == &"":
		return finished
	for stage_id in _stage_order():
		if stage_id == current:
			break
		finished.append(stage_id)
	return finished


func _stage_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var stage_id := StringName(str(Balance.get_value("progress.initial.current_stage_id", "")))
	while stage_id != &"" and not order.has(stage_id):
		order.append(stage_id)
		var value: Variant = Balance.get_value("chapters.%s.next_stage_id" % stage_id, null)
		stage_id = &"" if value == null else StringName(str(value))
	return order


# ---------------------------------------------------------------------------
# Scene residency
#
# The order below is the whole point of this section. Remove, free, then add.
# queue_free would leave the outgoing scene in the tree until the end of the
# frame, so for that frame two main scenes would be resident and both would
# receive input and process time.
# ---------------------------------------------------------------------------

func _enter_route(route: StringName) -> bool:
	var path: String = str(scene_paths.get(route, ""))
	if path.is_empty():
		push_error("%s No scene registered for route '%s'." % [LOG_PREFIX, route])
		return false
	if not ResourceLoader.exists(path):
		push_error("%s Scene '%s' for route '%s' does not exist yet." % [LOG_PREFIX, path, route])
		return false

	var packed: PackedScene = load(path)
	if packed == null:
		push_error("%s Could not load '%s'." % [LOG_PREFIX, path])
		return false

	_free_title_menu()
	_free_resident_scene()

	_resident_scene = packed.instantiate()
	_scene_host.add_child(_resident_scene)
	if route == ROUTE_ENDING:
		_populate_ending_summary()
	_route = route
	print("%s %s -> %s" % [LOG_PREFIX, route, path])
	route_changed.emit(_route)
	return true


func _populate_ending_summary() -> void:
	if _resident_scene == null or _ending_summary.is_empty():
		return
	var container := _resident_scene.get_node_or_null("Column/Summary")
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var rows := [
		[
			"Completion time",
			_ending_summary.get(&"completion_time", {})
		],
		[
			"Build choices by stage",
			_ending_summary.get(&"build_choices_by_stage", {})
		],
		[
			"Final resources",
			_ending_summary.get(&"final_resources", {})
		],
		[
			"Birth check values",
			_ending_summary.get(&"birth_check_values", {})
		],
		[
			"Minigames",
			_ending_summary.get(&"minigames", {})
		],
	]
	for row in rows:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s: %s" % [row[0], JSON.stringify(row[1])]
		container.add_child(label)


## How many main scenes are resident. Must never exceed one; exposed so a test can
## assert that rather than take it on trust.
func resident_scene_count() -> int:
	if _scene_host == null:
		return 0
	return _scene_host.get_child_count()


func _free_resident_scene() -> void:
	if _resident_scene == null or not is_instance_valid(_resident_scene):
		_resident_scene = null
		return
	_scene_host.remove_child(_resident_scene)
	_resident_scene.free()
	_resident_scene = null


# ---------------------------------------------------------------------------
# The title menu
#
# Default-styled buttons with placeholder text. The time-basis explanation is
# deliberately absent: docs/CHAPTER_TIMELINE.md places it at the first entry into
# stage one, and T-29a presents it there. Putting it here would show it before
# the player has any stage to attach it to.
# ---------------------------------------------------------------------------

func _build_title_menu() -> void:
	_free_title_menu()

	var parent := _title_menu_parent()
	_title_menu = VBoxContainer.new()
	_title_menu.name = "TitleMenu"
	parent.add_child(_title_menu)

	# The scene carries the title when there is a scene. Adding a second one
	# here would put the name on screen twice.
	if parent == self:
		var title := Label.new()
		title.name = "GameTitle"
		title.text = "Metabolis: Birth of the City of Life"
		_title_menu.add_child(title)

	if _awaiting_new_game_confirmation:
		var prompt := Label.new()
		prompt.name = "ConfirmPrompt"
		prompt.text = CONFIRM_LABEL
		_title_menu.add_child(prompt)
		_add_button(&"confirm_yes", CONFIRM_YES, confirm_new_game)
		_add_button(&"confirm_no", CONFIRM_NO, cancel_new_game)
	else:
		for entry in title_entries():
			_add_button(entry, str(ENTRY_LABELS.get(entry, entry)), _handler_for(entry))

	title_entries_changed.emit(title_entries())


func _add_button(id: StringName, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.name = "Entry_%s" % id
	button.text = text
	button.pressed.connect(func() -> void: handler.call(), CONNECT_DEFERRED)
	_title_menu.add_child(button)


func _handler_for(entry: StringName) -> Callable:
	match entry:
		ENTRY_CONTINUE:
			return continue_game
		ENTRY_NEW_GAME:
			return request_new_game
		ENTRY_CHAPTER_SELECT:
			return open_chapter_select
		ENTRY_BUILDER_PROTOTYPE:
			return open_system_city
		_:
			return func() -> void: pass


## The menu's parent is the router when there is no title scene and the scene's
## anchor when there is, so the removal asks the node where it lives rather than
## assuming. Callers must free the menu before the scene that holds it.
func _free_title_menu() -> void:
	if _title_menu == null or not is_instance_valid(_title_menu):
		_title_menu = null
		return
	var parent := _title_menu.get_parent()
	if parent != null:
		parent.remove_child(_title_menu)
	_title_menu.free()
	_title_menu = null
