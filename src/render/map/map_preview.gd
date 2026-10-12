extends Node3D
## Preview of the war table for a fresh game: click a province to select it (its neighbours
## light up), click an army to select it. Run with
## `godot res://src/render/map/map_preview.tscn`; append
## `-- --screenshot=<path> [--focus=<ID>] [--zoom=<distance>]` to save one frame as PNG and
## quit.

const SEED := 1
const SETTLE_FRAMES := 45

var _map: MapData
var _state: GameState
var _table := MapTable.new()
var _province: String = ""
var _army: int = MapTable.NO_ARMY


func _ready() -> void:
	_map = MapData.load_file()
	var economy := EconomyConfig.load_file()
	if _map == null or economy == null:
		push_error("map preview: data/map.json or data/economy.json could not be loaded")
		return
	_state = GameSetup.create(_map, economy, SEED)
	if DisplayServer.get_name() != "headless":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	add_child(_table)
	_table.build(_map)
	_table.update_view(_state)
	_table.province_clicked.connect(_on_province_clicked)
	_table.army_clicked.connect(_on_army_clicked)
	var options := _options()
	if options.has("focus"):
		_on_province_clicked(options["focus"])
	elif options.has("screenshot"):
		_on_army_clicked(_state.armies_of(_state.active_house())[0].id)
	if options.has("zoom"):
		_table.camera.zoom_to(float(options["zoom"]))
	if options.has("screenshot"):
		_capture(options["screenshot"])


func _on_province_clicked(province_id: String) -> void:
	_province = province_id
	_table.set_selection(_province, _army, _map.provinces[province_id].neighbors)
	_table.camera.focus(province_id)


func _on_army_clicked(army_id: int) -> void:
	_army = army_id
	var army := _state.army(army_id)
	_province = army.province
	_table.set_selection(_province, _army, _map.provinces[_province].neighbors)


func _capture(path: String) -> void:
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("map preview: saved %s (error %d)" % [path, error])
	get_tree().quit(0 if error == OK else 1)


static func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options
