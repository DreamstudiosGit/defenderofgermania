class_name JoustShieldWidget
extends Control
## The rider seen from inside: where the opponent's lance points (red mark) and where the shield
## is turned (heater shield in house colours); a gold ring when the shield meets the lance.

const RADIUS := 52.0
const GOLD := Color(1.0, 0.82, 0.3)
const INK := Color(0.08, 0.06, 0.05, 0.9)
const LANCE := Color(0.95, 0.3, 0.22)

var _incoming := Vector2.ZERO
var _shield := Vector2.ZERO
var _aligned: bool = false
var _active: bool = false
var _colors := PackedColorArray([Color.WHITE, Color.GRAY])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS * 2.0 + 24.0, RADIUS * 2.0 + 24.0)


func set_colors(colors: PackedColorArray) -> void:
	_colors = colors


## incoming: the opponent's tip in this rider's own view (x right, y up), metres from the chest.
func show_shield(incoming: Vector2, shield: Vector2, aligned: bool, active: bool) -> void:
	_incoming = incoming
	_shield = shield
	_aligned = aligned
	_active = active
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS + 6.0, Color(0.1, 0.08, 0.06, 0.75))
	draw_arc(center, RADIUS + 6.0, 0.0, TAU, 48, GOLD if _aligned else Color(GOLD, 0.35), 3.0, true)
	draw_circle(center + Vector2(0, -RADIUS * 0.42), RADIUS * 0.17, Color(0.55, 0.52, 0.48, 0.6))
	var shoulders := PackedVector2Array([
		center + Vector2(-RADIUS * 0.45, RADIUS * 0.15), center + Vector2(-RADIUS * 0.2, -RADIUS * 0.2),
		center + Vector2(RADIUS * 0.2, -RADIUS * 0.2), center + Vector2(RADIUS * 0.45, RADIUS * 0.15),
		center + Vector2(RADIUS * 0.3, RADIUS * 0.6), center + Vector2(-RADIUS * 0.3, RADIUS * 0.6),
	])
	draw_colored_polygon(shoulders, Color(0.55, 0.52, 0.48, 0.45))
	if _active and not _incoming.is_zero_approx():
		var mark := center + Vector2(_incoming.x, -_incoming.y).normalized() * RADIUS
		draw_circle(mark, 7.0, INK)
		draw_circle(mark, 5.0, LANCE)
	if _shield.length() > 0.05:
		var direction := Vector2(_shield.x, -_shield.y).normalized()
		_draw_heater(center + direction * RADIUS * 0.62 * minf(_shield.length(), 1.0), direction)


func _draw_heater(at: Vector2, direction: Vector2) -> void:
	var angle := direction.angle() + PI / 2
	var points := PackedVector2Array()
	for corner: Vector2 in [
		Vector2(-12, -12), Vector2(12, -12), Vector2(12, 0), Vector2(7, 9), Vector2(0, 15),
		Vector2(-7, 9), Vector2(-12, 0),
	]:
		points.append(at + corner.rotated(angle))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, _colors[0])
	draw_line(at + Vector2(0, -12).rotated(angle), at + Vector2(0, 15).rotated(angle), _colors[1], 4.0)
	draw_polyline(outline, INK, 2.5, true)
