class_name CompanyBars
extends Control
## Health and morale bars above every company on the field, projected through the camera.

const WIDTH := 30.0
const HEIGHT := 4.0
const LIFT := 3.4
const BACK := Color(0.08, 0.06, 0.05, 0.75)
const HEALTH_FULL := Color(0.35, 0.85, 0.30)
const HEALTH_LOW := Color(0.90, 0.20, 0.15)
const MORALE := Color(0.35, 0.60, 1.0)
const BROKEN := Color(1.0, 0.65, 0.15)
const MORALE_SCALE := 100.0

var _state: BattleState
var _camera: Camera3D
var _positions := PackedVector2Array()
var _colors: Array[Color] = []
var _blink: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(camera: Camera3D, colors: Array[Color]) -> void:
	_camera = camera
	_colors = colors


func update_view(state: BattleState, positions: PackedVector2Array, delta: float) -> void:
	_state = state
	_positions = positions
	_blink = fmod(_blink + delta, 0.5)
	queue_redraw()


func _draw() -> void:
	if _state == null or _camera == null:
		return
	for c: int in _state.company_count():
		if not _state.is_present(c) or c >= _positions.size():
			continue
		var world := Vector3(_positions[c].x, LIFT, _positions[c].y)
		if _camera.is_position_behind(world):
			continue
		var at := _camera.unproject_position(world) - Vector2(WIDTH / 2, 0)
		var health := _state.hp[c] / _state.max_hp[c]
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(WIDTH + 2, HEIGHT * 2 + 3)), BACK)
		draw_rect(Rect2(at, Vector2(WIDTH * health, HEIGHT)), HEALTH_LOW.lerp(HEALTH_FULL, health))
		draw_rect(Rect2(at + Vector2(-4, 0), Vector2(3, HEIGHT * 2 + 1)), _colors[_state.side[c]])
		if _state.is_leader(c):
			continue
		var fleeing := _state.status[c] == BattleState.Status.FLEEING
		var morale := clampf(_state.morale[c] / MORALE_SCALE, 0.0, 1.0)
		var color := BROKEN if fleeing and _blink < 0.25 else MORALE
		draw_rect(Rect2(at + Vector2(0, HEIGHT + 1), Vector2(WIDTH * morale, HEIGHT)), color)
