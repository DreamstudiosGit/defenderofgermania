extends GutTest
## The main menu scene: it builds headless over the war table, every request of its screen
## becomes the right scene change (through the scene's seams, never the real App), the
## backdrop's camera drifts in a closed loop while no input moves the table, and a headless
## run passes on to the battle only when the menu is the tree's scene (the smoke test).

const SCENE := "res://src/render/menu/main_menu.tscn"
const FOLDER := "user://test_main_menu_saves"
const FRAMES_PAST_THE_HAND_OVER := 12

var _folder := ""
## [scene path, configure] of every scene change the menu asked for.
var _changes: Array[Array] = []
var _quits := 0


## Stands in for the scene a change leads to; `configure` sets these.
class FakeScene:
	extends Node
	var launch_slot := ""
	var open_options := false


func before_each() -> void:
	_folder = SaveGames.folder
	SaveGames.folder = FOLDER
	_changes.clear()
	_quits = 0


func after_each() -> void:
	SaveGames.folder = _folder


func test_the_menu_builds_headless_over_the_war_table() -> void:
	var menu := _open()
	var backdrop: MenuBackdrop = menu.get("backdrop")
	assert_gt(backdrop.table.field_count(), 0, "the realm lies on the table")
	assert_gt(backdrop.table.figure_count(), 0, "with the armies of a new campaign")
	assert_true(backdrop.camera.current, "seen through the menu's camera")
	var screen := _screen(menu)
	assert_true(screen.is_visible_in_tree())
	var version := screen.find_child("version", true, false) as Label
	var number := str(ProjectSettings.get_setting("application/config/version"))
	assert_string_contains(version.text, number)
	assert_string_contains(version.text, "Early Access")
	assert_not_null(get_viewport().gui_get_focus_owner(), "an entry has the focus")


func test_entries_lead_to_their_scenes() -> void:
	var screen := _screen(_open())
	_entry(screen, "new_campaign").pressed.emit()
	_entry(screen, "quick_battle").pressed.emit()
	assert_eq(_paths(), [App.CAMPAIGN, App.BATTLE])
	assert_false((_changes[0][1] as Callable).is_valid(), "a new campaign opens its setup")
	_entry(screen, "quit").pressed.emit()
	assert_eq(_quits, 1)
	assert_eq(_changes.size(), 2, "quitting changes no scene")


func test_continue_and_load_start_the_campaign_with_their_save() -> void:
	var screen := _screen(_open())
	screen.continue_requested.emit("slot_2")
	screen.slots.load_requested.emit("autosave")
	assert_eq(_paths(), [App.CAMPAIGN, App.CAMPAIGN])
	var slots: Array[String] = []
	for change: Array in _changes:
		var campaign: FakeScene = autofree(FakeScene.new())
		(change[1] as Callable).call(campaign)
		slots.append(campaign.launch_slot)
	assert_eq(slots, ["slot_2", "autosave"] as Array[String])


func test_practice_leads_to_the_four_adventures() -> void:
	var screen := _screen(_open())
	_entry(screen, "practice").pressed.emit()
	for mode: String in ["joust", "siege", "raid", "merchant"]:
		(screen.practice.find_child(mode, true, false) as Button).pressed.emit()
	assert_eq(_paths(), [App.JOUST, App.SIEGE, App.RAID, App.MERCHANT])


func test_a_new_language_rebuilds_the_menu_with_the_options_open() -> void:
	var screen := _screen(_open())
	screen.options.language_changed.emit()
	assert_eq(_paths(), [App.MAIN_MENU])
	var next: FakeScene = autofree(FakeScene.new())
	(_changes[0][1] as Callable).call(next)
	assert_true(next.open_options)
	var rebuilt := _open(func(menu: Node) -> void: menu.set("open_options", true))
	assert_true(_screen(rebuilt).options.visible, "the player is back in the options")


func test_the_camera_drifts_in_a_closed_loop_over_the_realm() -> void:
	var backdrop: MenuBackdrop = _open().get("backdrop")
	var camera := backdrop.camera
	var realm := Rect2(camera.look_point(), Vector2.ZERO)
	for id: String in MapData.load_file().provinces:
		var at := backdrop.table.world_position(id)
		realm = realm.expand(Vector2(at.x, at.z))
	# It looks a little west of the realm it shows; a tenth of the width is as far as that goes.
	var view := realm.grow(realm.size.x * 0.1)
	var start := camera.global_position
	var first_leg := MenuCamera.LAP_SECONDS * 0.25
	camera.drift(first_leg)
	assert_gt(camera.global_position.distance_to(start), 1.0, "it moves")
	var steps := 64
	var off_the_realm := 0
	for i: int in steps:
		camera.drift((MenuCamera.LOOP_SECONDS - first_leg) / steps)
		off_the_realm += 0 if view.has_point(camera.look_point()) else 1
	assert_eq(off_the_realm, 0, "it keeps looking at the realm")
	assert_lt(camera.global_position.distance_to(start), 0.01, "and comes round to its start")


func test_input_does_not_move_the_table_behind_the_menu() -> void:
	var backdrop: MenuBackdrop = _open().get("backdrop")
	var table := backdrop.table
	var target := table.camera.target
	var distance := table.camera.distance
	for action: String in ["map_kb_left", "map_kb_up", "map_kb_zoom_in"]:
		Input.action_press(action)
	await wait_process_frames(3)
	for action: String in ["map_kb_left", "map_kb_up", "map_kb_zoom_in"]:
		Input.action_release(action)
	assert_eq(table.camera.target, target, "the table's camera does not pan")
	assert_eq(table.camera.distance, distance, "nor zoom")
	assert_false(table.is_processing_unhandled_input(), "and the table reports no clicks")


func test_a_headless_run_passes_on_to_the_battle_only_as_the_trees_scene() -> void:
	if DisplayServer.get_name() != "headless":
		pass_test("only a headless run passes on")
		return
	_open()
	await wait_process_frames(FRAMES_PAST_THE_HAND_OVER)
	assert_eq(_changes.size(), 0, "a menu a test instantiates stays")
	var tree := get_tree()
	var scene_before := tree.current_scene
	var menu := _instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	await wait_process_frames(FRAMES_PAST_THE_HAND_OVER)
	tree.current_scene = scene_before
	menu.queue_free()
	assert_eq(_paths(), [App.BATTLE], "the smoke test reaches a battle")


func _instantiate() -> Node:
	var menu := (load(SCENE) as PackedScene).instantiate()
	menu.set("change_scene", _record_change)
	menu.set("quit_game", _record_quit)
	return menu


func _open(configure: Callable = Callable()) -> Node:
	var menu := _instantiate()
	if configure.is_valid():
		configure.call(menu)
	add_child_autofree(menu)
	return menu


func _screen(menu: Node) -> MainMenuScreen:
	return menu.get("screen")


func _entry(screen: MainMenuScreen, entry_name: String) -> Button:
	return screen.entries.find_child(entry_name, true, false) as Button


func _paths() -> Array[String]:
	var paths: Array[String] = []
	for change: Array in _changes:
		paths.append(str(change[0]))
	return paths


func _record_change(scene_path: String, configure: Callable = Callable()) -> void:
	_changes.append([scene_path, configure])


func _record_quit() -> void:
	_quits += 1
