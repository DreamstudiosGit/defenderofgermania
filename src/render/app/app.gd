extends Node
## Autoload "App": the shell around every scene. It holds the player's options and applies
## them, gives all screens the shared look, changes scenes behind a curtain, knows whether the
## player is on a controller right now (for button prompts and rumble) and quits cleanly.

## True while the last input came from a controller.
signal pad_in_use_changed(pad: bool)

const MAIN_MENU := "res://src/render/menu/main_menu.tscn"
const CAMPAIGN := "res://src/render/campaign/campaign_main.tscn"
const BATTLE := "res://src/render/battle/battle_main.tscn"
const JOUST := "res://src/render/joust/joust_main.tscn"
const SIEGE := "res://src/render/siege/trebuchet_main.tscn"
const RAID := "res://src/render/raid/raid_main.tscn"
const MERCHANT := "res://src/render/merchant/merchant_main.tscn"

const STICK_THRESHOLD := 0.5
const MOUSE_THRESHOLD := 4.0

var settings := UserSettings.new()
var applier: SettingsApplier
var curtain := SceneCurtain.new()
var pad_in_use := false
## Joypad id of the controller used last.
var last_pad := 0

var _changing := false
var _focused := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var first_start := not FileAccess.file_exists(settings.path)
	settings.load_file()
	if first_start and OS.has_feature("editor"):
		# Development runs start in a window; a shipped game starts borderless fullscreen.
		settings.set_value(UserSettings.WINDOW_MODE, UserSettings.WindowMode.WINDOWED)
	var window := get_tree().root
	ThemeDB.fallback_font = UiFonts.body()
	ThemeDB.fallback_font_size = CampaignStyle.FONT_SIZE
	window.theme = CampaignStyle.theme()
	get_tree().node_added.connect(_on_node_added)
	applier = SettingsApplier.new(settings, window)
	applier.apply_all()
	settings.changed.connect(applier.apply)
	add_child(curtain)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_mute(settings.get_bool(UserSettings.MUTE_UNFOCUSED))
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_mute(false)
		NOTIFICATION_WM_CLOSE_REQUEST:
			settings.save_file()


func _input(event: InputEvent) -> void:
	var pad := pad_in_use
	if event is InputEventJoypadButton:
		pad = true
		last_pad = event.device
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_THRESHOLD:
			pad = true
			last_pad = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_THRESHOLD:
			pad = false
	if pad != pad_in_use:
		pad_in_use = pad
		pad_in_use_changed.emit(pad)


## Replaces the current scene behind the curtain. `configure` receives the new scene before it
## enters the tree, e.g. to hand it a save to resume: func(scene: Node) -> void.
func go_to(scene_path: String, configure: Callable = Callable()) -> void:
	if _changing:
		return
	_changing = true
	await curtain.close()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("app: cannot load scene %s" % scene_path)
	else:
		var next := packed.instantiate()
		if configure.is_valid():
			configure.call(next)
		var tree := get_tree()
		if tree.current_scene != null:
			tree.current_scene.queue_free()
			await tree.process_frame
		tree.paused = false
		tree.root.add_child(next)
		tree.current_scene = next
		# Scenes build their world in _ready; let it settle before the curtain opens.
		await tree.process_frame
		await tree.process_frame
		applier.apply_quality()
	await curtain.open()
	_changing = false


func to_main_menu() -> void:
	go_to(MAIN_MENU)


func is_changing_scene() -> bool:
	return _changing


## Graphics quality level (UserSettings.Quality) for scenes that scale their own extras.
func quality() -> int:
	return settings.get_int(UserSettings.QUALITY)


## Strength of camera shake the player asked for: 0 none … 1 full.
func shake_scale() -> float:
	return settings.get_float(UserSettings.SCREEN_SHAKE)


## Vibrates a controller if the player allows it; joypad < 0 means the one used last, and
## nothing happens while the player is on mouse and keyboard.
func rumble(weak: float, strong: float, seconds: float, joypad: int = -1) -> void:
	if not settings.get_bool(UserSettings.RUMBLE):
		return
	if joypad < 0:
		if not pad_in_use:
			return
		joypad = last_pad
	Input.start_joy_vibration(joypad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


func quit() -> void:
	settings.save_file()
	get_tree().quit()


## A theme only passes from Control to Control (or Window); the screens hang under
## CanvasLayers and 3D scenes, so every topmost Control gets the shared look here.
func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control == null or control.theme != null:
		return
	var parent := control.get_parent()
	if not (parent is Control or parent is Window):
		control.theme = CampaignStyle.theme()


func _mute(muted: bool) -> void:
	AudioServer.set_bus_mute(0, muted or settings.get_float(UserSettings.VOLUME_MASTER) <= 0.0)
