extends SceneTree
## Frame-time benchmark of the scenes that are a picture more than a game: the main menu over
## the war table, the war table of a campaign the computer houses played for ten rounds (an
## army selected, its reachable provinces lit) and the castle view of a grown home castle.
## Runs one scene in a window with vsync and the frame limit off and prints the average frame
## time, the 1 % low (the mean of the slowest hundredth of the frames) and the time the
## graphics card itself spent on a frame, which still tells the quality levels apart where
## the processor sets the pace. The options change in memory only and saves are read from a
## folder of its own, so the player's files stay untouched. The scenes' classes are loaded by
## path: a --script file is compiled before the autoloads they use exist.
## Usage: godot --script res://scripts/benchmark_scenes.gd -- --scene=menu|table|castle
## [--quality=low|medium|high] [--size=1280x800] [--seconds=10] [--scale=<3D render scale>]

const SCENES: Array[String] = ["menu", "table", "castle"]
const QUALITIES: Array[String] = ["low", "medium", "high"]
const SAVES := "user://benchmark_saves"
const SETTINGS := "user://benchmark_settings.cfg"
const SEED := 1198
const ROUNDS := 10
## Ending a phase may be refused or lead to a screen; the campaign must still stop.
const MAX_PHASES := 400
## Shaders are compiled, shadows have settled and the castle's time-lapse is over.
const WARM_UP_SECONDS := 6.0

## The viewports that render the scene: the window and, for the castle, its stage.
var _viewports: Array[RID] = []
## Milliseconds the graphics card spent on the measured frames.
var _gpu_time := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := _arguments()
	var scene: String = args.get("scene", "table")
	var quality := QUALITIES.find(args.get("quality", "medium"))
	if scene not in SCENES or quality < 0:
		printerr("scene benchmark: --scene=%s --quality=%s" % ["|".join(SCENES), "|".join(QUALITIES)])
		quit(1)
		return
	var size := str(args.get("size", "1280x800")).split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	var settings: UserSettings = root.get_node("App").get("settings")
	settings.path = SETTINGS
	settings.set_value(UserSettings.VSYNC, false)
	settings.set_value(UserSettings.FPS_LIMIT, 0)
	settings.set_value(UserSettings.QUALITY, quality)
	settings.set_value(UserSettings.RENDER_SCALE, float(args.get("scale", "1.0")))
	settings.set_value(UserSettings.UI_SCALE, 1.0)
	SaveGames.folder = SAVES
	_viewports.append(root.get_viewport_rid())
	var rules := GameRules.load_files()
	match scene:
		"menu":
			root.add_child((load("res://src/render/menu/main_menu.tscn") as PackedScene).instantiate())
		"table":
			_add_table(rules)
		"castle":
			_add_castle(rules)
	for viewport: RID in _viewports:
		RenderingServer.viewport_set_measure_render_time(viewport, true)
	await _wait(WARM_UP_SECONDS)
	var times := await _measure(float(args.get("seconds", "10")))
	times.sort()
	var total := 0.0
	for time: float in times:
		total += time
	var slow_frames := maxi(times.size() / 100, 1)
	var slow := 0.0
	for index: int in range(times.size() - slow_frames, times.size()):
		slow += times[index]
	var average := total / times.size()
	var low := slow / slow_frames
	var report := "scene benchmark: %s, quality %s, %dx%d, render scale %.2f: %.2f ms average " \
		+ "(%.0f fps), 1 %% low %.2f ms (%.0f fps), graphics card %.2f ms, %d frames on %s"
	print(report % [
		scene, QUALITIES[quality], root.size.x, root.size.y,
		settings.get_float(UserSettings.RENDER_SCALE), average, 1000.0 / average, low,
		1000.0 / low, _gpu_time / times.size(), times.size(),
		RenderingServer.get_video_adapter_name(),
	])
	DirAccess.remove_absolute(SAVES)
	quit()


## The war table as the campaign shows it in its tenth round.
func _add_table(rules: GameRules) -> void:
	var config := AiConfig.load_file()
	var ai := AiPlayer.new(rules, config)
	var human: Array[String] = [rules.map.houses[0]]
	var computers := AiPlayer.opponents(config, rules.map.houses, human)
	var session := CampaignSession.create(rules, human, SEED, computers, ai.play_phase)
	var phases := 0
	while session.state.turn < ROUNDS and not session.state.is_over() and phases < MAX_PHASES:
		phases += 1
		session.execute(EndPhaseCommand.new(rules, session.active_house()))
	var state := session.state
	var table: Node3D = (load("res://src/render/map/map_table.gd") as GDScript).new()
	root.add_child(table)
	table.call("build", rules.map)
	table.call("update_view", state)
	var armies := state.armies_of(human[0])
	if armies.is_empty():
		armies = state.armies
	if not armies.is_empty():
		var army := armies[0]
		var reachable: Array[String] = rules.map.provinces[army.province].neighbors
		table.call("set_selection", army.province, army.id, reachable)
	print("scene benchmark: round %d, %d armies" % [state.turn + 1, state.armies.size()])


## A home castle of the highest level with every building and decoration and a full village.
func _add_castle(rules: GameRules) -> void:
	var state := GameSetup.create(rules.map, rules.economy, SEED)
	var house := state.houses[rules.map.houses[0]]
	var province := state.provinces[house.home_province]
	province.castle_level = int(rules.economy.home_castle.keys().max())
	province.population = 10000.0
	house.decorations.assign(rules.economy.decorations.keys())
	province.buildings.clear()
	for id: String in rules.economy.buildings:
		var is_replaced := rules.economy.buildings.values().any(
			func(other: BuildingDef) -> bool: return other.upgrade_of == id
		)
		if not is_replaced:
			province.buildings.append(id)
	var view: Node3D = (load("res://src/render/castle/castle_view.gd") as GDScript).new()
	root.add_child(view)
	view.call("show_province", state, rules, house.home_province)
	_viewports.append((view.get_node("Stage") as SubViewport).get_viewport_rid())


func _wait(seconds: float) -> void:
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await process_frame


## Frame times in milliseconds over `seconds`.
func _measure(seconds: float) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var start := Time.get_ticks_usec()
	var last := start
	while last - start < seconds * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		for viewport: RID in _viewports:
			_gpu_time += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	return times


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
