class_name SceneCurtain
extends CanvasLayer
## A dark curtain over everything while scenes change: it closes, the scene behind it is
## swapped (so loading hitches stay unseen), and it opens again. While it is not fully open it
## swallows mouse input. Headless runs skip the fades.

const FADE_SECONDS := 0.28
const COLOR := Color(0.05, 0.035, 0.025)

var _shade := ColorRect.new()
var _tween: Tween = null
var _instant: bool


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instant = DisplayServer.get_name() == "headless"
	_shade.color = COLOR
	_shade.modulate.a = 0.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func is_closed() -> bool:
	return _shade.modulate.a >= 1.0


## Fades to dark; await it.
func close() -> void:
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)


## Fades back to the scene; await it.
func open() -> void:
	await _fade_to(0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fade_to(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	if _instant or is_equal_approx(_shade.modulate.a, alpha):
		_shade.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_shade, "modulate:a", alpha, FADE_SECONDS)
	await _tween.finished
