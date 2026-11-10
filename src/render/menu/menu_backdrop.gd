class_name MenuBackdrop
extends Node3D
## Backdrop of the main menu: the war table set up as a new campaign begins, lit by its
## candles and seen through a MenuCamera. It is a picture, not a board: the table and its own
## camera rest, so no input reaches them.

const SEED := 1198

var table := MapTable.new()
var camera := MenuCamera.new()


## Lays out the table and starts the drift; false when the data cannot be loaded.
func build() -> bool:
	var map := MapData.load_file()
	var economy := EconomyConfig.load_file()
	if map == null or economy == null:
		push_error("menu backdrop: data/map.json or data/economy.json could not be loaded")
		return false
	table.name = "Table"
	add_child(table)
	table.build(map)
	table.update_view(GameSetup.create(map, economy, SEED))
	table.set_process_unhandled_input(false)
	table.camera.process_mode = Node.PROCESS_MODE_DISABLED
	# The armies' company counts are news for a player at the table, not part of the picture.
	for count: Node in table.find_children("*", "Label3D", true, false):
		if count.get_parent() is MapFigure:
			(count as Label3D).visible = false
	var realm := Rect2()
	var ground := 0.0
	var first := true
	for id: String in map.provinces:
		var at := table.world_position(id)
		var point := Vector2(at.x, at.z)
		realm = Rect2(point, Vector2.ZERO) if first else realm.expand(point)
		ground = maxf(ground, at.y)
		first = false
	camera.name = "Camera"
	add_child(camera)
	camera.setup(realm, ground)
	camera.current = true
	return true
