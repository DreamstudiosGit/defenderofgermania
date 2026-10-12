class_name SiegeWindVane
extends Control
## The wind of the coming shot: an arrow (right blows towards the castle, left back at the
## trebuchet) whose length and colour follow the strength, and the speed in m/s.

const SIZE := Vector2(220, 64)
const CALM := 0.05
const TAIL := Color(0.55, 0.85, 0.55)
const HEAD := Color(0.95, 0.55, 0.40)

var wind: float = 0.0:
	set(value):
		wind = value
		queue_redraw()
var limit: float = 6.0


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var text := tr("SIEGE_WIND_CALM")
	if absf(wind) >= CALM:
		text = tr("SIEGE_WIND") % ("%.1f" % absf(wind))
	draw_string_outline(font, Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x, 18, 4,
		Color(0.1, 0.07, 0.05))
	draw_string(font, Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, SIZE.x, 18)
	var middle := Vector2(SIZE.x * 0.5, 44)
	draw_line(middle - Vector2(SIZE.x * 0.45, 0), middle + Vector2(SIZE.x * 0.45, 0),
		Color(1, 1, 1, 0.25), 2.0)
	if absf(wind) < CALM:
		draw_circle(middle, 5.0, Color(1, 1, 1, 0.6))
		return
	var share := clampf(absf(wind) / maxf(limit, 0.1), 0.0, 1.0)
	var direction := signf(wind)
	var tip := middle + Vector2(direction * SIZE.x * 0.45 * share, 0)
	var color := TAIL if wind > 0.0 else HEAD
	draw_line(middle, tip, color, 6.0)
	var back := tip - Vector2(direction * 12.0, 0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(direction * 4.0, 0),
		back + Vector2(0, -9), back + Vector2(0, 9)]), color)
