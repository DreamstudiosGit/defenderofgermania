class_name SiegePartBars
extends Control
## HP bars above the castle parts, projected through the camera: always for wall and gate
## segments (the ones that open a breach, with a gold rim), for other parts once they are
## damaged or burning (burning bars blink).

const WIDTH := 44.0
const HEIGHT := 6.0
const BACK := Color(0.08, 0.06, 0.05, 0.8)
const FULL := Color(0.35, 0.85, 0.30)
const LOW := Color(0.90, 0.20, 0.15)
const FIRE := Color(1.0, 0.6, 0.15)

var _castle: SiegeCastle
var _camera: Camera3D
var _tops := PackedVector3Array()
var _blink: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(castle: SiegeCastle, camera: Camera3D, tops: PackedVector3Array) -> void:
	_castle = castle
	_camera = camera
	_tops = tops


func update_view(delta: float) -> void:
	_blink = fmod(_blink + delta, 0.6)
	queue_redraw()


func _draw() -> void:
	if _castle == null or _camera == null or not _camera.is_inside_tree():
		return
	for i: int in mini(_castle.part_count(), _tops.size()):
		if not _castle.is_damageable(i) or _camera.is_position_behind(_tops[i]):
			continue
		var share := float(_castle.hp[i]) / maxi(_castle.max_hp[i], 1)
		var segment := _castle.parts[i].is_breach_segment()
		if not segment and share >= 1.0 and _castle.burning[i] == 0:
			continue
		var at := _camera.unproject_position(_tops[i]) - Vector2(WIDTH * 0.5, 0.0)
		var rim := GroupShield.GOLD if segment else BACK
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(WIDTH + 4, HEIGHT + 4)), rim)
		draw_rect(Rect2(at, Vector2(WIDTH, HEIGHT)), BACK)
		var color := LOW.lerp(FULL, share)
		if _castle.burning[i] == 1 and _blink < 0.3:
			color = FIRE
		draw_rect(Rect2(at, Vector2(WIDTH * share, HEIGHT)), color)
