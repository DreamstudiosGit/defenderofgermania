class_name GroupShield
extends Control
## Coat-of-arms shield for one command group: symbol (spear, crossbow, horse head, trebuchet),
## number of companies, bolt marks for archers, golden glow while the group is active.

const SHIELD_SIZE := Vector2(72, 84)
const FIELD := Color(0.55, 0.38, 0.22)
const RIM := Color(0.30, 0.20, 0.12)
const GOLD := Color(1.0, 0.82, 0.30)
const MUTED := Color(0.25, 0.22, 0.2, 0.6)
const BOLT_FULL := Color(0.96, 0.94, 0.88)
const BOLT_EMPTY := Color(0.2, 0.16, 0.12)

var group: int = 0
var active: bool = false
var companies: int = 0
## Ready volleys for archers, -1 for groups without bolt marks.
var bolts: int = -1
var max_bolts: int = 3
var has_leader: bool = false
var house_color := Color.WHITE
var accent := Color.WHITE


func _init() -> void:
	custom_minimum_size = SHIELD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var outline := _outline(size * 0.5, 1.0)
	if active:
		draw_colored_polygon(_outline(size * 0.5, 1.12), Color(GOLD, 0.35))
	draw_colored_polygon(outline, FIELD if companies > 0 else MUTED)
	var rim := outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, GOLD if active else RIM, 4.0 if active else 2.0, true)
	var ink := house_color if companies > 0 else MUTED
	_draw_symbol(size * 0.5 + Vector2(0, 2), ink)
	if bolts >= 0:
		for i: int in max_bolts:
			var mark := Rect2(size.x * 0.5 - 15 + i * 11, 6, 7, 12)
			draw_rect(mark, BOLT_FULL if i < bolts else BOLT_EMPTY)
	var font := ThemeDB.fallback_font
	var label := "×%d" % companies
	var at := Vector2(size.x - 30, size.y - 8)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, RIM)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if has_leader:
		_draw_crown(Vector2(14, size.y - 16))


func _outline(center: Vector2, scale_factor: float) -> PackedVector2Array:
	var half := SHIELD_SIZE * 0.5 * scale_factor
	var points := PackedVector2Array()
	points.append(center + Vector2(-half.x, -half.y))
	points.append(center + Vector2(half.x, -half.y))
	points.append(center + Vector2(half.x, half.y * 0.2))
	points.append(center + Vector2(0, half.y))
	points.append(center + Vector2(-half.x, half.y * 0.2))
	return points


func _draw_symbol(center: Vector2, ink: Color) -> void:
	match group:
		BattleState.Group.INFANTRY:
			_stroke(center + Vector2(-18, 20), center + Vector2(16, -18), ink)
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(22, -24), center + Vector2(10, -20), center + Vector2(18, -12)
				]),
				ink
			)
		BattleState.Group.ARCHERS:
			_stroke(center + Vector2(-18, 16), center + Vector2(14, -16), ink)
			var bow := center + Vector2(6, -8)
			draw_arc(bow, 16.0, PI * 0.75, PI * 1.75, 12, accent, 6.0)
			draw_arc(bow, 16.0, PI * 0.75, PI * 1.75, 12, ink, 3.5)
		BattleState.Group.CAVALRY:
			var head := PackedVector2Array([
				Vector2(-12, 24), Vector2(-14, 0), Vector2(-8, -14), Vector2(-4, -26),
				Vector2(0, -16), Vector2(12, -10), Vector2(22, 2), Vector2(18, 8),
				Vector2(6, 4), Vector2(2, 8), Vector2(8, 24)
			])
			for i: int in head.size():
				head[i] += center
			draw_colored_polygon(head, ink)
		_:
			draw_circle(center + Vector2(0, 10), 10.0, ink)
			_stroke(center + Vector2(-16, -16), center + Vector2(16, 6), ink)


func _stroke(from: Vector2, to: Vector2, ink: Color) -> void:
	draw_line(from, to, accent, 7.0, true)
	draw_line(from, to, ink, 4.0, true)


func _draw_crown(at: Vector2) -> void:
	var crown := PackedVector2Array([
		at + Vector2(-8, 4), at + Vector2(-8, -4), at + Vector2(-4, 0), at + Vector2(0, -6),
		at + Vector2(4, 0), at + Vector2(8, -4), at + Vector2(8, 4)
	])
	draw_colored_polygon(crown, GOLD)
