class_name MapSurroundings
extends Node3D
## Everything on the table around and across the provinces: the oak table with its rim, the
## parchment sheet, the seas with water lines along the coast and the great rivers.

const WOOD := preload("res://src/render/map/map_wood.gdshader")
const PAPER := preload("res://src/render/map/map_paper.gdshader")
const SEA_LIFT := 0.004
const LINE_LIFT := 0.01
const RIVER_LIFT := 0.009

## Table top in table units (x, z); its surface is at height 0.
var table := Rect2()


func build(map: MapData, board: MapBoard) -> void:
	var sheet := board.bounds.grow(MapArt.number("sheet", "margin", 5.0))
	table = sheet.grow(MapArt.number("table", "margin", 9.0))
	_build_table()
	var paper := ShaderMaterial.new()
	paper.shader = PAPER
	paper.set_shader_parameter("paper", MapArt.color("sheet", "paper", Color.WHEAT))
	paper.set_shader_parameter("edge", MapArt.color("sheet", "paper_edge", Color.SADDLE_BROWN))
	paper.set_shader_parameter(
		"sheet", Vector4(sheet.position.x, sheet.position.y, sheet.size.x, sheet.size.y)
	)
	var sheet_mesh := MapMeshes.prism(_corners(sheet), 0.0, board.sheet_top)
	_add("Sheet", sheet_mesh, paper)
	var seas := _seas(map, board, sheet)
	var sea := paper.duplicate() as ShaderMaterial
	sea.set_shader_parameter("paper", MapArt.color("sheet", "sea", Color.CADET_BLUE))
	sea.set_shader_parameter("hatch", MapArt.number("sheet", "sea_hatch", 0.18))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon: PackedVector2Array in seas:
		MapMeshes.add_cap(tool, polygon, board.sheet_top + SEA_LIFT)
	_add("Seas", tool.commit(), sea)
	_build_water_lines(board, seas)
	_build_rivers(map, board)


func _build_table() -> void:
	var wood := ShaderMaterial.new()
	wood.shader = WOOD
	wood.set_shader_parameter("light_wood", MapArt.color("table", "wood_light", Color.BURLYWOOD))
	wood.set_shader_parameter("dark_wood", MapArt.color("table", "wood_dark", Color.SADDLE_BROWN))
	wood.set_shader_parameter("plank_width", MapArt.number("table", "plank_width", 7.5))
	var thickness := MapArt.number("table", "thickness", 3.0)
	_add("Table", MapMeshes.prism(_corners(table), -thickness, 0.0), wood)
	var rim := MapArt.number("table", "rim_width", 2.4)
	var rim_height := MapArt.number("table", "rim_height", 0.9)
	var outer := table.grow(rim)
	var sides: Array[Rect2] = [
		Rect2(outer.position, Vector2(outer.size.x, rim)),
		Rect2(Vector2(outer.position.x, table.end.y), Vector2(outer.size.x, rim)),
		Rect2(Vector2(outer.position.x, table.position.y), Vector2(rim, table.size.y)),
		Rect2(Vector2(table.end.x, table.position.y), Vector2(rim, table.size.y)),
	]
	for side: Rect2 in sides:
		_add("Rim", MapMeshes.prism(_corners(side), -thickness, rim_height), wood)


## Sea polygons on the sheet, cut back to the coast where the drawn realm reaches into them.
func _seas(map: MapData, board: MapBoard, sheet: Rect2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var seas: Dictionary = MapArt.section("seas")
	for key: String in seas:
		var polygon := PackedVector2Array()
		for item: Variant in seas[key]:
			var pair: Array = item if item is Array else []
			if pair.size() == 2:
				var lon_lat := Vector2(float(pair[0]), float(pair[1]))
				polygon.append(board.to_table(map.geography.to_km(lon_lat)))
		if polygon.size() < 3:
			push_error("map art: sea %s needs at least three points" % key)
			continue
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(polygon, _corners(sheet)):
			result.append_array(Geometry2D.clip_polygons(piece, board.realm))
	return result


## Engraved lines following the coast out into the sea.
func _build_water_lines(board: MapBoard, seas: Array[PackedVector2Array]) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := MapArt.number("sheet", "water_line_width", 0.09)
	var distances: Array = MapArt.section("sheet").get("water_lines_km", [])
	for distance: Variant in distances:
		var offset := float(distance) / MapArt.km_per_unit()
		for ring: PackedVector2Array in Geometry2D.offset_polygon(board.realm, offset):
			ring.append(ring[0])
			for sea: PackedVector2Array in seas:
				for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(ring, sea):
					MapMeshes.add_ribbon(tool, line, false, width, board.sheet_top + LINE_LIFT)
	var ink := MapArt.color("ink", "color", Color.BLACK)
	_add("WaterLines", tool.commit(), MapArt.flat(Color(ink, 0.55)))


## Rivers from the "rivers" section, drawn on each field at its height and on the sheet
## outside the realm.
func _build_rivers(map: MapData, board: MapBoard) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := MapArt.number("river", "width", 0.32)
	var rivers: Dictionary = MapArt.section("rivers")
	for key: String in rivers:
		var course := PackedVector2Array()
		for item: Variant in rivers[key]:
			var pair: Array = item if item is Array else []
			if pair.size() == 2:
				var lon_lat := Vector2(float(pair[0]), float(pair[1]))
				course.append(board.to_table(map.geography.to_km(lon_lat)))
		for id: String in board.cells:
			var y := board.heights[id] + RIVER_LIFT
			for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
				course, board.cells[id]
			):
				MapMeshes.add_ribbon(tool, piece, false, width, y)
		for piece: PackedVector2Array in Geometry2D.clip_polyline_with_polygon(course, board.realm):
			MapMeshes.add_ribbon(tool, piece, false, width, board.sheet_top + RIVER_LIFT)
	_add("Rivers", tool.commit(), MapArt.flat(MapArt.color("river", "color", Color.STEEL_BLUE)))


func _add(node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
