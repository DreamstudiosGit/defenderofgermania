class_name JoustAimOverlay
extends Control
## Aim marks projected onto the opponent: the hit zones as thin gold rings with their points,
## the swaying lance tip, where the hand is heading, and a closing ring that meets the tip at
## the impact and turns gold inside the rider's perfect window.

const TIP_RADIUS := 9.0
const RING_LEAD_SECONDS := 1.0
const RING_SPAN := 90.0
const GOLD := Color(1.0, 0.82, 0.3)
const INK := Color(0.08, 0.06, 0.05, 0.85)
const ZONE_ALPHA := 0.55

var zone_labels: bool = true

var _camera: Camera3D
var _chest := Vector3.ZERO
var _axes := Basis()
var _tip := Vector2.ZERO
var _goal := Vector2.ZERO
var _zones: Array[JoustConfig.Zone] = []
var _until_impact: float = INF
var _window: float = 0.0
var _show_goal: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_zones(zones: Array[JoustConfig.Zone]) -> void:
	_zones = zones


## Everything in metres of the target plane on the opponent's chest.
func show_aim(
	camera: Camera3D, chest: Vector3, axes: Basis, tip: Vector2, goal: Vector2,
	until_impact: float, window: float, show_goal: bool
) -> void:
	_camera = camera
	_chest = chest
	_axes = axes
	_tip = tip
	_goal = goal
	_until_impact = until_impact
	_window = window
	_show_goal = show_goal
	visible = true
	queue_redraw()


## Screen point and pixels per metre of the opponent's chest, for the mouse aim.
func screen_frame() -> Array:
	if _camera == null or _camera.is_position_behind(_chest):
		return [Vector2.ZERO, 0.0]
	var center := _camera.unproject_position(_chest)
	var side := _camera.unproject_position(_chest + _axes.x)
	return [center, center.distance_to(side)]


func _draw() -> void:
	if _camera == null or _camera.is_position_behind(_chest):
		return
	var font := get_theme_default_font()
	for zone: JoustConfig.Zone in _zones:
		var center := _project(zone.center)
		var radius := center.distance_to(_project(zone.center + Vector2(zone.radius, 0.0)))
		var color := Color(GOLD, ZONE_ALPHA)
		draw_arc(center, radius, 0.0, TAU, 48, Color(INK, 0.4), 4.0, true)
		draw_arc(center, radius, 0.0, TAU, 48, color, 2.0, true)
		if zone_labels:
			var label := "%d" % zone.points
			var at := center + Vector2(radius * 0.72, -radius * 0.72)
			draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, INK)
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	if _show_goal:
		var goal := _project(_goal)
		draw_line(goal - Vector2(7, 0), goal + Vector2(7, 0), Color(1, 1, 1, 0.45), 2.0)
		draw_line(goal - Vector2(0, 7), goal + Vector2(0, 7), Color(1, 1, 1, 0.45), 2.0)
	var tip := _project(_tip)
	draw_arc(tip, TIP_RADIUS, 0.0, TAU, 24, INK, 5.0, true)
	draw_arc(tip, TIP_RADIUS, 0.0, TAU, 24, Color.WHITE, 2.5, true)
	draw_circle(tip, 2.5, Color.WHITE)
	if _until_impact >= -_window and _until_impact <= RING_LEAD_SECONDS:
		var span := maxf(_until_impact, 0.0) / RING_LEAD_SECONDS
		var ring := TIP_RADIUS + 4.0 + RING_SPAN * span
		var perfect := absf(_until_impact) <= _window
		var color := GOLD if perfect else Color(1, 1, 1, 0.8)
		draw_arc(tip, ring, 0.0, TAU, 48, INK, 6.0, true)
		draw_arc(tip, ring, 0.0, TAU, 48, color, 3.0 if perfect else 2.0, true)


func _project(offset: Vector2) -> Vector2:
	return _camera.unproject_position(JoustTrack.target_point(_chest, _axes, offset))
