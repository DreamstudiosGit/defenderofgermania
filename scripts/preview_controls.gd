extends SceneTree
## Screenshots of the controls tab of the options in the states scripts/preview_options.gd
## cannot reach: waiting for a binding, the question before a reset, the notice after a
## swap or a refusal. Bindings are read from and written to a file of its own, and the
## options are defaults in memory; the player's files are never touched.
## Usage: godot --script res://scripts/preview_controls.gd -- --shot=<png path>
## [--view=list|wait_keys|wait_pad|ask_reset|swap|refused] [--locale=de|en]
## [--size=1280x800] [--ui-scale=<percent>] [--focus=<control name, e.g. reset_battle>]

const SHOT_FRAMES := 40
const BUILD_FRAMES := 10
const BINDINGS := "user://preview_controls/input.cfg"
# Loaded by path once the tree runs: the screen uses the autoloads, which a --script run only
# knows after this script was compiled.
const OPTIONS_SCREEN := "res://src/ui/menu/options_screen.gd"
const CONTROLS_TAB := 3


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := _arguments()
	root.mode = Window.MODE_WINDOWED
	var size := str(args.get("size", "1280x720")).split("x")
	root.size = Vector2i(size[0].to_int(), size[1].to_int())
	root.content_scale_factor = str(args.get("ui-scale", "100")).to_float() / 100.0
	if args.has("locale"):
		TranslationServer.set_locale(args["locale"])
	InputOverrides.path = BINDINGS
	InputOverrides.load_file()
	var screen: Control = (load(OPTIONS_SCREEN) as GDScript).new()
	screen.set("settings", UserSettings.new())
	root.add_child(screen)
	screen.call("open")
	for step: int in CONTROLS_TAB:
		var next_tab := InputEventAction.new()
		next_tab.action = "ui_page_down"
		next_tab.pressed = true
		root.push_input(next_tab)
	for frame: int in BUILD_FRAMES:
		await process_frame
	if args.has("focus"):
		(screen.find_child(args["focus"], true, false) as Control).grab_focus()
	await _show(screen, str(args.get("view", "list")))
	for frame: int in SHOT_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := str(args.get("shot", "user://controls.png"))
	var error := root.get_texture().get_image().save_png(path)
	print("controls preview: %s (%s)" % [path, error_string(error)])
	DirAccess.remove_absolute(BINDINGS)
	DirAccess.remove_absolute(BINDINGS.get_base_dir())
	quit(0 if error == OK else 1)


func _show(screen: Control, view: String) -> void:
	match view:
		"wait_keys":
			_select(screen, "battle_attack/keys")
		"wait_pad":
			_select(screen, "raid_high/pad")
		"ask_reset":
			_select(screen, "reset_battle")
		"swap":
			_select(screen, "battle_attack/keys")
			await process_frame
			var key := InputEventKey.new()
			key.physical_keycode = KEY_F
			key.pressed = true
			root.push_input(key)
		"refused":
			_select(screen, "siege_fire/pad")
			await process_frame
			var start := InputEventJoypadButton.new()
			start.button_index = JOY_BUTTON_START
			start.pressed = true
			root.push_input(start)


## Focuses and presses a button of the list: "<scene>_<action>/keys", ".../pad", "reset_<scene>".
func _select(screen: Control, path: String) -> void:
	var parts := path.split("/")
	var button := screen.find_child(parts[0], true, false)
	if parts.size() > 1:
		button = button.get_node(parts[1])
	(button as Button).grab_focus()
	(button as Button).pressed.emit()


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
