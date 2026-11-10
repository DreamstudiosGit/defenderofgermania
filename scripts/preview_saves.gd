extends SceneTree
## Screenshots of the list of saved campaigns, alone or opened from the pause menu, over a
## stand-in scene. The saves shown are made in a folder of the tool's own, one per slot in
## the state asked for; the player's are never touched.
## Usage: godot --script res://scripts/preview_saves.gd -- --shot=<png path>
## [--view=load|save|pause-load|pause-save] [--locale=de|en] [--size=1280x800] (window; the
## base canvas 1280x720 if left out) [--ui-scale=<percent>]
## [--slots=<autosave>,<slot 1>,<slot 2>,<slot 3>] each used|hotseat|empty|recovered|broken|
## other (default used,hotseat,recovered,empty) [--pick=<slot>] [--delete=<slot>] (press that
## row or its delete button, e.g. to see the question) [--wait=<frames after the press>]

const SHOT_FRAMES := 30
const SAVES := "user://preview_save_list"
const DEFAULT_SLOTS := "used,hotseat,recovered,empty"
const HOUSES: Array[String] = ["welfen", "wettiner", "staufer", "wittelsbacher"]
# Loaded by path once the tree runs: the screens use the autoloads, which a --script run only
# knows after this script was compiled.
const SLOTS_SCREEN := "res://src/ui/menu/save_slots_screen.gd"
const PAUSE_MENU := "res://src/ui/menu/pause_menu.gd"

var _rules: GameRules


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	root.mode = Window.MODE_WINDOWED
	var parts := str(args.get("size", "")).split("x")
	root.size = root.content_scale_size
	if parts.size() == 2:
		root.size = Vector2i(parts[0].to_int(), parts[1].to_int())
	root.content_scale_factor = str(args.get("ui-scale", "100")).to_float() / 100.0
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	_rules = GameRules.load_files()
	SaveGames.folder = SAVES
	_remove_saves()
	var kinds := str(args.get("slots", DEFAULT_SLOTS)).split(",")
	var slots: Array[String] = [SaveGames.AUTOSAVE]
	slots.append_array(SaveGames.SLOTS)
	for index: int in mini(kinds.size(), slots.size()):
		_fill(slots[index], kinds[index], 11 + 9 * index)
	var scene := _stand_in_scene()
	root.add_child(scene)
	var view: String = args.get("view", "load")
	var screen := _open(scene, view)
	for frame: int in SHOT_FRAMES:
		await process_frame
	for action: String in ["pick", "delete"]:
		if args.has(action):
			var row := screen.find_child(args[action], true, false)
			(row.find_child(action, true, false) as Button).pressed.emit()
			for frame: int in str(args.get("wait", SHOT_FRAMES)).to_int():
				await process_frame
	await RenderingServer.frame_post_draw
	var path: String = args.get("shot", "user://saves.png")
	var error := root.get_texture().get_image().save_png(path)
	print("saves preview: %s (%s)" % [path, error_string(error)])
	paused = false
	_remove_saves()
	quit(0 if error == OK else 1)


## Opens the list in the view's mode, directly or through the pause menu's entry.
func _open(scene: Node, view: String) -> Control:
	var state := _state(30, ["welfen"])
	if view.begins_with("pause"):
		var menu: Control = (load(PAUSE_MENU) as GDScript).call("mount", scene)
		menu.set("state_source", func() -> GameState: return state)
		menu.call("open")
		(menu.find_child(view.trim_prefix("pause-"), true, false) as Button).pressed.emit()
		return menu.find_child("save_slots", true, false) as Control
	var screen: Control = (load(SLOTS_SCREEN) as GDScript).new()
	scene.add_child(screen)
	screen.call("open", 1 if view == "save" else 0, state)
	return screen


## Puts a save of the given kind into the slot.
func _fill(slot: String, kind: String, turn: int) -> void:
	var humans: Array[String] = ["welfen"]
	if kind == "hotseat":
		humans = HOUSES
	match kind:
		"used", "hotseat":
			SaveGames.write(_state(turn, humans), slot)
		"recovered":
			SaveGames.write(_state(turn, humans), slot)
			SaveGames.write(_state(turn + 1, humans), slot)
			_truncate(SaveGames.path(slot))
		"broken":
			SaveGames.write(_state(turn, humans), slot)
			_truncate(SaveGames.path(slot))
		"other":
			var state := _state(turn, humans)
			var header := SaveFile.header_for(state, state.to_bytes())
			header["version"] = GameState.SAVE_VERSION - 1
			header["game_version"] = "0.7.0"
			DirAccess.make_dir_recursive_absolute(SAVES)
			SaveFile.store(SaveGames.path(slot), SaveFile.encode(header, state.to_bytes()))


func _state(turn: int, humans: Array[String]) -> GameState:
	var computers: Dictionary[String, Array] = {}
	for house: String in HOUSES:
		if house not in humans:
			computers[house] = ["builder", 1]
	var state := CampaignSession.create(_rules, humans, 9, computers).state
	state.turn = turn
	return state


func _truncate(file_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(file_path)
	SaveFile.store(file_path, data.slice(0, data.size() >> 1))


func _remove_saves() -> void:
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)
	DirAccess.remove_absolute(SAVES)


## Something bright and busy behind the modal, to judge how well it is dimmed.
func _stand_in_scene() -> Control:
	var scene := Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 8
	scene.add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in 40:
		var field := ColorRect.new()
		field.color = Color.from_hsv(0.08 + 0.05 * (index % 5), 0.45, 0.55 + 0.08 * (index % 4))
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(field)
	return scene


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
