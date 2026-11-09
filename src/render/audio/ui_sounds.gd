class_name UiSounds
extends Node
## Gives every button, tab and slider its sound without each screen asking for it: it listens
## for controls entering the tree. A button plays `ui_click` unless its meta "sound" names
## another id (SOUND_META), e.g. `button.set_meta(UiSounds.SOUND_META, &"ui_confirm")`.

const SOUND_META := &"sound"
const CLICK := &"ui_click"
const HOVER := &"ui_hover"
const FOCUS := &"ui_focus"
const TAB := &"ui_tab"
const SLIDER := &"ui_slider"
## Focus only ticks when a key or the controller moved it, not when a screen opens.
const NAVIGATION_WINDOW_MS := 250
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev",
]

var _last_navigation := -100000
## Tabs and sliders also change when a screen refreshes; they only sound right after the
## player pressed, clicked or dragged something.
var _last_touch := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if motion.button_mask != 0:
			_last_touch = Time.get_ticks_msec()
		return
	if event.is_pressed():
		_last_touch = Time.get_ticks_msec()
	for action: StringName in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action, true):
			_last_navigation = Time.get_ticks_msec()
			return


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(_on_pressed.bind(button))
		button.focus_entered.connect(_on_focused)
		button.mouse_entered.connect(_on_hovered.bind(button))
	elif node is TabContainer:
		(node as TabContainer).tab_changed.connect(_on_tab_changed)
	elif node is Slider:
		(node as Slider).value_changed.connect(_on_slider_changed)
		(node as Slider).focus_entered.connect(_on_focused)


func _on_pressed(button: BaseButton) -> void:
	var id: StringName = button.get_meta(SOUND_META, CLICK)
	Audio.play(id)


func _on_hovered(button: BaseButton) -> void:
	# Flat buttons are the many value lines with a tooltip; they stay quiet.
	if button.disabled or (button is Button and (button as Button).flat):
		return
	Audio.play(HOVER)


func _on_focused() -> void:
	if Time.get_ticks_msec() - _last_navigation <= NAVIGATION_WINDOW_MS:
		Audio.play(FOCUS)


func _on_tab_changed(_tab: int) -> void:
	if _touched():
		Audio.play(TAB)


func _on_slider_changed(_value: float) -> void:
	if _touched():
		Audio.play(SLIDER)


func _touched() -> bool:
	return Time.get_ticks_msec() - _last_touch <= NAVIGATION_WINDOW_MS
