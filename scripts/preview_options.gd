extends SceneTree
## Screenshots of the options screen (one tab) or of the pause menu, over a stand-in scene.
## The options shown are defaults in memory; the screen never writes the player's file.
## Usage: godot --script res://scripts/preview_options.gd --
## --view=video|audio|game|controls|pause --shot=<png path> [--locale=de|en]
## [--size=1280x800] (window; the base canvas 1280x720 if left out) [--ui-scale=<percent>]
## options: [--pad] (switch tabs by RB) [--ingame] (language locked) [--focus=<control name>]
## pause: [--saves=yes|blocked] [--leave=<text key>]

const SHOT_FRAMES := 30
const TABS: Array[String] = ["video", "audio", "game", "controls"]
# Loaded by path once the tree runs: the screens use the autoloads, which a --script run only
# knows after this script was compiled.
const OPTIONS_SCREEN := "res://src/ui/menu/options_screen.gd"
const PAUSE_MENU := "res://src/ui/menu/pause_menu.gd"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	# App applies the player's window mode and size at boot, whatever --resolution says; the
	# shot needs the size asked for.
	root.mode = Window.MODE_WINDOWED
	var wanted: String = args.get("size", "")
	var parts := wanted.split("x")
	root.size = root.content_scale_size
	if parts.size() == 2:
		root.size = Vector2i(parts[0].to_int(), parts[1].to_int())
	var percent: String = args.get("ui-scale", "100")
	root.content_scale_factor = percent.to_float() / 100.0
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	var scene := _stand_in_scene()
	root.add_child(scene)
	var view: String = args.get("view", "video")
	if view == "pause":
		_open_pause(scene, args)
	else:
		_open_options(scene, args, maxi(TABS.find(view), 0))
	for frame: int in SHOT_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = args.get("shot", "user://options.png")
	var error := root.get_texture().get_image().save_png(path)
	print("options preview: %s (%s)" % [path, error_string(error)])
	paused = false
	quit(0 if error == OK else 1)


func _open_options(scene: Node, args: Dictionary[String, String], tab: int) -> void:
	var screen: Control = (load(OPTIONS_SCREEN) as GDScript).new()
	screen.set("settings", UserSettings.new())
	screen.set("allow_language", not args.has("ingame"))
	scene.add_child(screen)
	screen.call("open")
	for step: int in tab:
		root.push_input(_next_tab(args.has("pad")))
	var focused := screen.find_child(args.get("focus", ""), true, false) as Control
	if focused != null:
		focused.grab_focus()


func _open_pause(scene: Node, args: Dictionary[String, String]) -> void:
	var menu: Control = (load(PAUSE_MENU) as GDScript).call("mount", scene)
	menu.set("leave_text", args.get("leave", ""))
	match args.get("saves", ""):
		"yes":
			menu.set("state_source", func() -> GameState: return GameState.new())
		"blocked":
			menu.set("state_source", func() -> GameState: return null)
	menu.call("open")


func _next_tab(pad: bool) -> InputEvent:
	if pad:
		var button := InputEventJoypadButton.new()
		button.button_index = JOY_BUTTON_RIGHT_SHOULDER
		button.pressed = true
		return button
	var action := InputEventAction.new()
	action.action = "ui_page_down"
	action.pressed = true
	return action


## Something bright and busy behind the modal, to judge how well it is dimmed.
func _stand_in_scene() -> Control:
	var scene := Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := ColorRect.new()
	ground.color = Color(0.42, 0.52, 0.30)
	scene.add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
