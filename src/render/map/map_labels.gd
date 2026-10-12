class_name MapLabels
extends Node3D
## Province names painted flat onto the fields below their centres, shrunk or wrapped to stay
## inside narrow fields.

const LIFT := 0.02
const MIN_SCALE := 0.7
const MIN_SCALE_WORD := 0.5

## Area each name covers on the table (x, z), so props keep clear of it.
var areas: Dictionary[String, Rect2] = {}


func build(board: MapBoard) -> void:
	var style := MapArt.section("labels")
	var font := SystemFont.new()
	var names: PackedStringArray = []
	for font_name: Variant in style.get("font_names", []):
		names.append(str(font_name))
	font.font_names = names
	var font_size := int(style.get("font_size", 64))
	var pixel_size := float(style.get("pixel_size", 0.022))
	for id: String in board.cells:
		var text := tr("PROVINCE_" + id)
		var at := board.spot(id, Vector2.DOWN, float(style.get("offset", 4.2)))
		var chord := _chord(board.cells[id], Vector2(at.x, at.z))
		var room := chord.y - chord.x
		var room_used := room * float(style.get("max_width", 0.9))
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		# Names with a space wrap once they cannot shrink further; single words shrink more.
		var smallest := pixel_size * (MIN_SCALE if " " in text else MIN_SCALE_WORD)
		var size := clampf(room_used / text_size.x, smallest, pixel_size)
		var lines := 1 if text_size.x * size <= room_used or " " not in text else 2
		var width := minf(text_size.x * size, room_used)
		var label := Label3D.new()
		label.name = "Label_" + id
		label.text = text
		label.font = font
		label.font_size = font_size
		label.pixel_size = size
		label.outline_size = int(style.get("outline_size", 14))
		label.modulate = Color.from_string(str(style.get("color", "")), Color.BLACK)
		label.outline_modulate = Color.from_string(str(style.get("outline_color", "")), Color.WHITE)
		if lines > 1:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.width = room_used / size
		var x := clampf(at.x, chord.x + width * 0.5, maxf(chord.y - width * 0.5, chord.x))
		label.position = Vector3(x, at.y + LIFT, at.z)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.shaded = true
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label)
		var height := text_size.y * size * lines
		areas[id] = Rect2(x - width * 0.5, at.z - height * 0.5, width, height)


## Start and end x of the cell's horizontal chord through the point.
static func _chord(cell: PackedVector2Array, point: Vector2) -> Vector2:
	var line := PackedVector2Array([Vector2(-1e5, point.y), Vector2(1e5, point.y)])
	for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, cell):
		var start := minf(piece[0].x, piece[piece.size() - 1].x)
		var end := maxf(piece[0].x, piece[piece.size() - 1].x)
		if point.x >= start and point.x <= end:
			return Vector2(start, end)
	return Vector2(point.x - 2.0, point.x + 2.0)
