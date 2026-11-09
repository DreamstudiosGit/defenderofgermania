class_name UiMotion
extends RefCounted
## The few animations all screens share, so they move alike: panels pop in, changed values
## pulse, numbers count up. Headless runs (tests) skip them and show the end state at once.

const POP_SECONDS := 0.18
const PULSE_SECONDS := 0.28
const COUNT_SECONDS := 0.45
const TWEEN_META := &"ui_motion_tween"


## From now on `panel` pops in whenever `screen` becomes visible.
static func pop_on_show(screen: Control, panel: Control) -> void:
	screen.visibility_changed.connect(
		func() -> void:
			if screen.is_visible_in_tree():
				pop(panel)
	)


## Fades and grows the panel in from slightly smaller.
static func pop(panel: Control) -> void:
	if _still():
		return
	panel.pivot_offset_ratio = Vector2(0.5, 0.5)
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var tween := _fresh_tween(panel).set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, POP_SECONDS)
	tween.tween_property(panel, "modulate:a", 1.0, POP_SECONDS)


## Slides the control in from `offset` pixels away while fading in (banners, toasts).
static func slide_in(control: Control, offset: Vector2, seconds: float = POP_SECONDS) -> void:
	if _still():
		return
	var rest := control.position
	control.position = rest + offset
	control.modulate.a = 0.0
	var tween := _fresh_tween(control).set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", rest, seconds)
	tween.tween_property(control, "modulate:a", 1.0, seconds)


## A short swell that draws the eye to a value that just changed; `tint` flashes over it.
static func pulse(control: Control, tint: Color = Color.WHITE) -> void:
	if _still():
		return
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	control.scale = Vector2(1.12, 1.12)
	control.self_modulate = tint
	var tween := _fresh_tween(control).set_parallel()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE_SECONDS)
	tween.tween_property(control, "self_modulate", Color.WHITE, PULSE_SECONDS)


## Counts from one value to another; `show` receives each step: func(value: float) -> void.
static func count(owner: Control, from: float, to: float, show: Callable) -> void:
	if _still() or is_equal_approx(from, to):
		show.call(to)
		return
	var tween := _fresh_tween(owner)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(show, from, to, COUNT_SECONDS)


static func _still() -> bool:
	return DisplayServer.get_name() == "headless"


## One running animation per control: a new one replaces the old.
static func _fresh_tween(control: Control) -> Tween:
	var old: Variant = control.get_meta(TWEEN_META, null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := control.create_tween()
	control.set_meta(TWEEN_META, tween)
	return tween
