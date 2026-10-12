class_name FavourBar
extends Control
## A lord's favour towards the house from 0 to the maximum: the fill in the house's colour,
## gold marks at the thresholds that matter (vote, archbishop, homage) and a small wedge under
## the bar at the best rival's favour.

const BAR_TOP := 2.0
const BAR_HEIGHT := 8.0

var maximum := 100.0
var value := 0.0
var color := CampaignStyle.GOOD
var marks := PackedFloat32Array()
## Favour of the best rival; below zero for none.
var rival := -1.0
var rival_color := CampaignStyle.MUTED


func _init() -> void:
	custom_minimum_size = Vector2(100, 17)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS


func show_favour(favour: float, top: float, thresholds: PackedFloat32Array) -> void:
	maximum = maxf(top, 1.0)
	value = favour
	marks = thresholds
	queue_redraw()


func show_rival(favour: float, wedge_color: Color) -> void:
	rival = favour
	rival_color = wedge_color
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(0.0, BAR_TOP, size.x, BAR_HEIGHT)
	draw_rect(bar, CampaignStyle.INK)
	draw_rect(Rect2(bar.position, Vector2(_x(value), BAR_HEIGHT)), color)
	draw_rect(bar, Color(CampaignStyle.GOLD, 0.45), false, 1.0)
	for mark: float in marks:
		var x := _x(mark)
		draw_line(Vector2(x, 0.0), Vector2(x, BAR_TOP * 2.0 + BAR_HEIGHT), CampaignStyle.GOLD, 2.0)
	if rival < 0.0:
		return
	var tip := Vector2(_x(rival), BAR_TOP + BAR_HEIGHT)
	var wedge := PackedVector2Array([
		tip, Vector2(tip.x + 4.5, size.y), Vector2(tip.x - 4.5, size.y)
	])
	draw_colored_polygon(wedge, rival_color)


func _x(amount: float) -> float:
	return size.x * clampf(amount / maximum, 0.0, 1.0)
