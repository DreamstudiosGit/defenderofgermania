class_name MenuEntries
extends VBoxContainer
## A column of menu entries: wide, left-aligned buttons. The entry under the mouse takes the
## focus, so mouse, keys and controller always mark the same one; up from the first entry
## leads to the last and back.

const WIDTH := 380.0
const FONT_SIZE := 17
const SLIDE := Vector2(-28.0, 0.0)
const SLIDE_SECONDS := 0.32
const STAGGER_SECONDS := 0.05


func _init() -> void:
	add_theme_constant_override("separation", 5)
	custom_minimum_size.x = WIDTH
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


## Adds an entry with the (translated) text; `entry_name` is its node name.
func add_entry(entry_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = entry_name
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.mouse_entered.connect(_on_hovered.bind(button))
	add_child(button)
	return button


func entries() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in get_children():
		if child is Button:
			result.append(child as Button)
	return result


## Focuses the first entry that can be chosen.
func focus_first() -> void:
	for button: Button in entries():
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


## Disabled entries never take the focus, and none does while a screen lies on top
## (reachable = false). The first and the last entry in reach lead to each other.
func set_reachable(reachable: bool) -> void:
	var in_reach: Array[Button] = []
	for button: Button in entries():
		var takes_focus := reachable and not button.disabled
		button.focus_mode = Control.FOCUS_ALL if takes_focus else Control.FOCUS_NONE
		# The ends may be others than at the last call.
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
		if takes_focus:
			in_reach.append(button)
	if in_reach.size() > 1:
		in_reach[0].focus_neighbor_top = in_reach[0].get_path_to(in_reach[-1])
		in_reach[-1].focus_neighbor_bottom = in_reach[-1].get_path_to(in_reach[0])


## The entries fade and slide in one after the other, starting `delay` seconds from now. Call
## it once the column has its place on screen.
func play_entrance(delay: float = 0.0) -> void:
	var buttons := entries()
	if buttons.is_empty():
		return
	var tween := create_tween().set_parallel()
	for i: int in buttons.size():
		buttons[i].modulate.a = 0.0
		var slide := UiMotion.slide_in.bind(buttons[i], SLIDE, SLIDE_SECONDS)
		tween.tween_callback(slide).set_delay(delay + i * STAGGER_SECONDS)


func _on_hovered(button: Button) -> void:
	if button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()
