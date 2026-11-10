extends SceneTree
## Screenshots of the scenes that are a picture: the main menu, the war table of a new game or
## the castle view, at a graphics quality, a window size and a render scale of choice. The
## candle flicker and the cameras rest, so two runs compare pixel by pixel. The options change
## in memory only and saves are read from a folder of its own. The scenes' classes are loaded
## by path: a --script file is compiled before the autoloads they use exist.
## Usage: godot --script res://scripts/preview_scenes.gd -- --shot=<png path>
## [--view=table|menu|castle] [--quality=low|medium|high] [--size=1280x720] [--scale=1.0]
## [--locale=de|en] [--pad: the hints of a controller] [--level=<home castle level>]
## table only: [--select: an army with its reachable provinces] [--zoom=<distance>]
## [--focus=<province id>] [--motion=<seconds>: an army conquers a neighbour, one is raised
## and one removed; the shot shows the table that long afterwards]

const QUALITIES: Array[String] = ["low", "medium", "high"]
const SAVES := "user://preview_scenes_saves"
const SETTINGS := "user://preview_scenes_settings.cfg"
const SEED := 1
const HOUSE := "welfen"
## The menu's entrance and the castle's time-lapse are over and the shadows have settled.
const SETTLE_FRAMES := 300


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	TranslationServer.set_locale(args.get("locale", "de"))
	var size := str(args.get("size", "1280x720")).split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	var settings: UserSettings = root.get_node("App").get("settings")
	settings.path = SETTINGS
	settings.set_value(UserSettings.QUALITY, maxi(QUALITIES.find(args.get("quality", "medium")), 0))
	settings.set_value(UserSettings.RENDER_SCALE, float(args.get("scale", "1.0")))
	settings.set_value(UserSettings.UI_SCALE, 1.0)
	SaveGames.folder = SAVES
	if args.has("pad"):
		var press := InputEventJoypadButton.new()
		press.button_index = JOY_BUTTON_LEFT_STICK
		press.pressed = true
		Input.parse_input_event(press)
	var rules := GameRules.load_files()
	var state := GameSetup.create(rules.map, rules.economy, SEED)
	var table: Node3D = null
	match args.get("view", "table"):
		"menu":
			_add_menu()
		"castle":
			_add_castle(rules, state, int(args.get("level", "4")))
		_:
			table = _add_table(rules, state, args)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	if table != null and args.has("motion"):
		_change(rules, state, table)
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < float(args["motion"]) * 1e6:
			await process_frame
	await RenderingServer.frame_post_draw
	var shot := str(args.get("shot", "user://scene.png"))
	var error := root.get_texture().get_image().save_png(shot)
	print("scene preview: %s (%s)" % [shot, error_string(error)])
	DirAccess.remove_absolute(SAVES)
	quit(0 if error == OK else 1)


func _add_menu() -> void:
	var scene := (load("res://src/render/menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var backdrop: Node = scene.get("backdrop")
	var camera := backdrop.get("camera") as Camera3D
	camera.call("drift", 20.0)
	camera.set_process(false)
	(backdrop.get("table") as Node).get_node("Lighting").set_process(false)


func _add_castle(rules: GameRules, state: GameState, level: int) -> void:
	var house := state.houses[HOUSE]
	var province := state.provinces[house.home_province]
	province.castle_level = level
	province.population = 90.0
	house.decorations.assign(rules.economy.decorations.keys())
	var view: Node3D = (load("res://src/render/castle/castle_view.gd") as GDScript).new()
	root.add_child(view)
	view.call("show_province", state, rules, house.home_province)
	(view.find_child("Camera", true, false) as Camera3D).set_process(false)


func _add_table(rules: GameRules, state: GameState, args: Dictionary[String, String]) -> Node3D:
	var table: Node3D = (load("res://src/render/map/map_table.gd") as GDScript).new()
	root.add_child(table)
	table.call("build", rules.map)
	table.call("update_view", state)
	table.get_node("Lighting").set_process(false)
	if args.has("select"):
		var army := state.armies_of(state.active_house())[0]
		_select(rules, table, army)
	var camera: Camera3D = table.get("camera")
	if args.has("focus"):
		camera.call("focus", args["focus"])
	if args.has("zoom"):
		camera.call("zoom_to", float(args["zoom"]))
	return table


## The active house's first army conquers a neighbour; it raises a new army and loses a foe.
func _change(rules: GameRules, state: GameState, table: Node3D) -> void:
	var army := state.armies_of(state.active_house())[0]
	var from := army.province
	for neighbor: String in rules.map.provinces[from].neighbors:
		if state.provinces[neighbor].owner != army.owner:
			army.province = neighbor
	state.provinces[army.province].owner = army.owner
	state.add_army(army.owner, from)
	for foe: ArmyState in state.armies:
		if foe.owner != army.owner:
			state.remove_army(foe)
			break
	table.call("update_view", state)
	_select(rules, table, army)


func _select(rules: GameRules, table: Node3D, army: ArmyState) -> void:
	var reachable: Array[String] = rules.map.provinces[army.province].neighbors
	table.call("set_selection", army.province, army.id, reachable)


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
