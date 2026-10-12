class_name MerchantRoadStrip
extends Control
## The whole road at a glance, from the leader's start to the town gate: each wagon with its
## cargo value (gold once stopped, grey once through the gate), the escorts, the companies
## and the leader in house colours.

const ROAD := Color(0.72, 0.6, 0.4)
const WAGON := Color(0.55, 0.36, 0.18)
const STOPPED := Color(1.0, 0.8, 0.25)
const LOST := Color(0.45, 0.43, 0.4)
const ESCORT := Color(0.85, 0.8, 0.68)
const ESCORT_DOWN := Color(0.5, 0.48, 0.42)
const GATE := Color(0.62, 0.6, 0.55)
const INK := Color(0.12, 0.08, 0.05)

var _sim: MerchantSim
var _house := PackedColorArray([Color.RED, Color.GOLD])
var _town: String = ""


func setup(sim: MerchantSim, house_colors: PackedColorArray, town: String) -> void:
	_sim = sim
	_house = house_colors
	_town = town
	queue_redraw()


func _process(_delta: float) -> void:
	if _sim != null and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if _sim == null:
		return
	var s := _sim.state
	var font := get_theme_default_font()
	var mid := size.y * 0.62
	draw_rect(Rect2(0.0, mid - 3.0, size.x, 6.0), ROAD)
	var gate := _to_x(s.gate_x)
	draw_rect(Rect2(gate - 6.0, mid - 22.0, 16.0, 30.0), GATE)
	draw_rect(Rect2(gate - 2.0, mid - 10.0, 8.0, 18.0), INK)
	draw_string(font, Vector2(gate - 140.0, mid + 28.0), _town, HORIZONTAL_ALIGNMENT_RIGHT, 150.0,
		14, Color.WHITE)
	for w: int in s.wagon_count():
		var color := WAGON
		match s.wagon_status[w]:
			MerchantState.Wagon.STOPPED:
				color = STOPPED
			MerchantState.Wagon.ARRIVED:
				color = LOST
		var x := _to_x(minf(s.wagon_x[w], s.gate_x))
		draw_rect(Rect2(x - 9.0, mid - 9.0, 18.0, 12.0), color)
		draw_rect(Rect2(x - 9.0, mid - 9.0, 18.0, 12.0), INK, false, 1.5)
		var value := str(s.wagon_value[w])
		draw_string(font, Vector2(x - 20.0, mid - 14.0), value, HORIZONTAL_ALIGNMENT_CENTER, 40.0,
			14, color.lightened(0.3))
	for e: int in s.escort_count():
		var down := s.escort_state[e] == MerchantState.Escort.DOWN
		draw_circle(Vector2(_to_x(s.escort_x[e]), mid + 9.0), 4.0, ESCORT_DOWN if down else ESCORT)
	for c: int in s.company_count():
		var hidden := s.company_state[c] == MerchantState.Company.HIDDEN
		var color := _house[1] if _house.size() > 1 else Color.GOLD
		color.a = 0.45 if hidden else 1.0
		draw_rect(Rect2(_to_x(s.company_x[c]) - 4.0, mid + 5.0, 8.0, 8.0), color)
	var leader := Vector2(_to_x(s.leader_x), mid + 10.0)
	var diamond := PackedVector2Array([
		leader + Vector2(0, -8), leader + Vector2(7, 0), leader + Vector2(0, 8),
		leader + Vector2(-7, 0),
	])
	draw_colored_polygon(diamond, _house[0] if _house.size() > 0 else Color.RED)
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.WHITE, 1.5)


func _to_x(road_x: float) -> float:
	var start := _sim.cfg.leader_start()
	return (road_x - start) / (_sim.state.gate_x + 4.0 - start) * size.x
