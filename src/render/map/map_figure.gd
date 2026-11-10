class_name MapFigure
extends Node3D
## One army on the map table: a painted wooden knight in its owner's colours, its company
## count, and a breathing gold ring with the figure lifted while it is selected. `place` is
## where the army stands and where a click meets it; the picture glides there with a small
## hop, drops in from above or sinks away ("motion" in data/map_art.json) and catches up on
## its own. With `animated` off (headless runs) every move ends at once.

enum Motion { REST, GLIDE, DROP, SINK }

const HEIGHT := 1.3
const RADIUS := 0.4
const COUNT_AT := Vector3(0.38, 1.38, 0.0)
## Share of a drop the figure falls; it settles with a small bounce for the rest.
const FALL_SHARE := 0.75
const BOUNCE := 0.06

## Where the army stands on the table, in the parent's coordinates.
var place := Vector3.ZERO
## Province the army stood in when the figure was last placed.
var province := ""
var animated := true

var _body := MeshInstance3D.new()
var _count := Label3D.new()
var _ring := MeshInstance3D.new()
var _scale: float = 2.7
var _lift: float = 0.8
var _lift_seconds: float = 0.12
var _selected := false
## How far the figure is lifted: 0 standing … 1 selected.
var _raised := 0.0
var _motion := Motion.REST
var _from := Vector3.ZERO
var _time := 0.0
var _seconds := 0.35
## Height of the hop of a glide, or the height a drop starts from.
var _height := 0.0


func _init() -> void:
	var pieces := MapArt.section("pieces")
	_scale = float(pieces.get("figure_scale", 2.7))
	_lift = float(pieces.get("lift", 0.8))
	_lift_seconds = MapArt.number("motion", "lift_seconds", 0.12)
	_body.mesh = MapPieceMeshes.figure()
	_body.scale = Vector3.ONE * _scale
	add_child(_body)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4 * _scale
	ring.outer_radius = 0.5 * _scale
	ring.rings = 32
	_ring.mesh = ring
	_ring.position.y = 0.05
	_ring.material_override = MapArt.rim(
		MapArt.color("pieces", "ring_color", Color.GOLD),
		MapArt.number("motion", "ring_breath", 0.35)
	)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.fixed_size = true
	_count.no_depth_test = true
	_count.render_priority = 2
	_count.outline_render_priority = 1
	_count.font_size = int(pieces.get("count_font_size", 40))
	_count.pixel_size = float(pieces.get("count_pixel_size", 0.0006))
	_count.outline_size = 12
	_count.modulate = MapArt.color("pieces", "count_color", Color.WHITE)
	_count.outline_modulate = MapArt.color("pieces", "count_outline_color", Color.BLACK)
	_count.position = COUNT_AT * _scale
	add_child(_count)


func _ready() -> void:
	set_process(is_moving())


func show_army(companies: int, paints: Array[Color]) -> void:
	_count.text = str(companies)
	for slot: int in mini(_body.mesh.get_surface_count(), paints.size()):
		_body.set_surface_override_material(slot, MapArt.paint(paints[slot]))


func set_selected(selected: bool) -> void:
	_selected = selected
	_ring.visible = selected
	if animated:
		set_process(true)
	else:
		_raise(1.0 if selected else 0.0)


## Stands at the spot at once.
func stand_at(spot: Vector3) -> void:
	place = spot
	position = spot
	scale = Vector3.ONE
	_motion = Motion.REST


## Glides to the spot within `seconds`, rising by `hop` on the way.
func glide_to(spot: Vector3, seconds: float, hop: float) -> void:
	if not animated:
		stand_at(spot)
		return
	place = spot
	_start(Motion.GLIDE, seconds, hop)


## Falls onto the spot from `height` above it.
func drop_in(spot: Vector3, seconds: float, height: float) -> void:
	stand_at(spot)
	if animated:
		position = spot + Vector3.UP * height
		_start(Motion.DROP, seconds, height)


## Sinks into the table and frees itself; it no longer answers to clicks.
func sink_away(seconds: float) -> void:
	_ring.visible = false
	_count.visible = false
	if animated:
		_start(Motion.SINK, seconds, 0.0)
	else:
		queue_free()


func is_moving() -> bool:
	return _motion != Motion.REST


func _process(delta: float) -> void:
	advance(delta)


## Moves the picture on by `delta` seconds; rests once it has caught up.
func advance(delta: float) -> void:
	var lifting := _advance_lift(delta)
	if _motion == Motion.REST:
		set_process(lifting)
		return
	_time += delta
	var t := clampf(_time / maxf(_seconds, 0.001), 0.0, 1.0)
	match _motion:
		Motion.GLIDE:
			var eased := t * t * (3.0 - 2.0 * t)
			position = _from.lerp(place, eased) + Vector3.UP * (_height * 4.0 * t * (1.0 - t))
		Motion.DROP:
			position = place + Vector3.UP * _drop_height(t)
		Motion.SINK:
			position = _from + Vector3.DOWN * (HEIGHT * _scale * t * t)
			scale = Vector3.ONE * (1.0 - 0.5 * t)
	if t >= 1.0:
		if _motion == Motion.SINK:
			queue_free()
		else:
			position = place
		_motion = Motion.REST


func foot() -> Vector3:
	var parent := get_parent_node_3d()
	var at := place + Vector3.UP * _body.position.y
	return parent.global_transform * at if parent != null else at


func head() -> Vector3:
	return foot() + Vector3.UP * HEIGHT * _scale


func radius() -> float:
	return RADIUS * _scale


func _start(motion: Motion, seconds: float, height: float) -> void:
	_motion = motion
	_from = position
	_time = 0.0
	_seconds = seconds
	_height = height
	set_process(true)


## Height above the spot at the share `t` of a drop: a fall, then one small bounce.
func _drop_height(t: float) -> float:
	if t < FALL_SHARE:
		var fall := t / FALL_SHARE
		return _height * (1.0 - fall * fall)
	return _height * BOUNCE * sin(PI * (t - FALL_SHARE) / (1.0 - FALL_SHARE))


## Eases the lift towards the selection; true while it still moves.
func _advance_lift(delta: float) -> bool:
	var goal := 1.0 if _selected else 0.0
	if is_equal_approx(_raised, goal):
		return false
	_raise(move_toward(_raised, goal, delta / maxf(_lift_seconds, 0.001)))
	return true


func _raise(share: float) -> void:
	_raised = share
	var eased := share * share * (3.0 - 2.0 * share)
	_body.position.y = _lift * eased
	_count.position.y = COUNT_AT.y * _scale + _lift * eased
