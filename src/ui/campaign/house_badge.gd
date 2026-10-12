class_name HouseBadge
extends Control
## A heater shield in the house's two heraldic colours: the field, a band in the charge
## colour and a dark rim.

var colors := PackedColorArray([CampaignStyle.MUTED, CampaignStyle.TEXT]):
	set(value):
		colors = value
		queue_redraw()


func _init(badge_size: Vector2 = Vector2(30, 36)) -> void:
	custom_minimum_size = badge_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var outline := PackedVector2Array()
	outline.append(Vector2(0, 0))
	outline.append(Vector2(w, 0))
	outline.append(Vector2(w, h * 0.45))
	for i: int in range(1, 9):
		var angle := PI * 0.5 * i / 8.0
		outline.append(Vector2(w * 0.5 + w * 0.5 * cos(angle), h * 0.45 + h * 0.55 * sin(angle)))
	for i: int in range(1, 9):
		var angle := PI * 0.5 + PI * 0.5 * i / 8.0
		outline.append(Vector2(w * 0.5 + w * 0.5 * cos(angle), h * 0.45 + h * 0.55 * sin(angle)))
	draw_colored_polygon(outline, colors[0])
	var band := PackedVector2Array([
		Vector2(0, h * 0.24), Vector2(w, h * 0.24), Vector2(w, h * 0.42), Vector2(0, h * 0.42)
	])
	draw_colored_polygon(band, colors[1] if colors.size() > 1 else CampaignStyle.TEXT)
	outline.append(outline[0])
	draw_polyline(outline, CampaignStyle.INK, 2.0, true)
