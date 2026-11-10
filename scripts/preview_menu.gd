extends SceneTree
## Screenshots of the main menu: the menu itself, the practice submenu or the credits. Saves
## are read from a folder of its own, so the player's are never touched; --save writes one
## there to show "continue". The menu's classes are only reached through get() and call():
## a --script file is compiled before the autoloads they use exist.
## Usage: godot --script res://scripts/preview_menu.gd -- --shot=<png path>
## [--view=menu|practice|credits] [--locale=de|en] [--size=1280x720] [--save]
## [--drift=<seconds the camera has travelled>] [--scroll=<pixels into the credits>]

const SCENE := "res://src/render/menu/main_menu.tscn"
const SAVES := "user://preview_saves"
## The entrance animation is over and the shadows have settled.
const SETTLE_FRAMES := 150
const VIEW_FRAMES := 40


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	var size := str(args.get("size", "1280x720")).split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	SaveGames.folder = SAVES
	_remove_saves()
	if args.has("save"):
		var rules := GameRules.load_files()
		SaveGames.write(GameSetup.create(rules.map, rules.economy, 1), SaveGames.SLOTS[0])
	var scene := (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	if args.has("drift"):
		var backdrop: Node = scene.get("backdrop")
		(backdrop.get("camera") as Camera3D).call("drift", float(args["drift"]))
	for frame: int in SETTLE_FRAMES:
		await process_frame
	var view := str(args.get("view", "menu"))
	if view != "menu":
		var screen: Control = scene.get("screen")
		((screen.get("entries") as Control).find_child(view, true, false) as Button).pressed.emit()
		for frame: int in VIEW_FRAMES:
			await process_frame
		if args.has("scroll"):
			(screen.get("credits") as Control).call("scroll_by", float(args["scroll"]))
			for frame: int in VIEW_FRAMES:
				await process_frame
	await RenderingServer.frame_post_draw
	var shot := str(args.get("shot", "user://menu.png"))
	var error := root.get_texture().get_image().save_png(shot)
	print("menu preview: %s (%s)" % [shot, error_string(error)])
	_remove_saves()
	DirAccess.remove_absolute(SAVES)
	quit(0 if error == OK else 1)


func _remove_saves() -> void:
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
