class_name OptionRow
extends HBoxContainer
## One line of the options: a title on the left and one control on the right — a switch, a
## list of choices or a percent slider with its number. Left and right change the value on
## every kind, so keys and controllers never need the pointer. `hint` is the one-line
## description the screen shows while the row has focus.

## The player changed the value: a bool (switch), the value of the chosen entry (choices) or
## the share 0 … 1 (slider).
signal changed(value: Variant)

enum Kind { TOGGLE, CHOICE, PERCENT }

const TITLE_WIDTH := 290.0
const CONTROL_WIDTH := 300.0
const NUMBER_WIDTH := 64.0
const SLIDER_INSET := 10.0
const PERCENT_STEPS := 100.0

var hint := ""
## The row's focusable control.
var control: Control
## Sliders: report the value when a drag ends instead of on every step of it, for options
## that would move the slider under the pointer (UI scale).
var on_release := false

var _kind: Kind
var _title := CampaignStyle.label()
var _note := CampaignStyle.label("", CampaignStyle.SMALL_SIZE - 1, CampaignStyle.MUTED)
var _number: Label = null
var _values: Array = []
var _dragging := false


func _init(kind: Kind, title: String, hint_text: String) -> void:
	_kind = kind
	hint = hint_text
	custom_minimum_size.y = CampaignStyle.BUTTON_HEIGHT
	add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -4)
	texts.custom_minimum_size.x = TITLE_WIDTH
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text = title
	texts.add_child(_title)
	_note.visible = false
	texts.add_child(_note)
	add_child(texts)
	var content := _build_control()
	content.custom_minimum_size.x = CONTROL_WIDTH
	add_child(content)
	control.gui_input.connect(_on_control_input)


static func toggle(title: String, hint_text: String) -> OptionRow:
	return OptionRow.new(Kind.TOGGLE, title, hint_text)


## `values` holds what `changed` reports for each name.
static func choice(
	title: String, hint_text: String, names: Array[String], values: Array
) -> OptionRow:
	var row := OptionRow.new(Kind.CHOICE, title, hint_text)
	row.set_choices(names, values)
	return row


## A slider in whole percent; the option itself is the share 0 … 1.
static func percent(
	title: String, hint_text: String, minimum: int, maximum: int, step: int = 5
) -> OptionRow:
	var row := OptionRow.new(Kind.PERCENT, title, hint_text)
	var slider := row.control as HSlider
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	return row


## Shows the option's value without reporting a change.
func show_value(value: Variant) -> void:
	match _kind:
		Kind.TOGGLE:
			var on: bool = value
			(control as CheckBox).set_pressed_no_signal(on)
			_show_state()
		Kind.CHOICE:
			(control as OptionButton).select(_values.find(value))
		Kind.PERCENT:
			var share: float = value
			var slider := control as HSlider
			slider.set_value_no_signal(roundf(share * PERCENT_STEPS))
			_show_number(slider.value)


func set_choices(names: Array[String], values: Array) -> void:
	var box := control as OptionButton
	box.clear()
	for item: String in names:
		box.add_item(item)
	_values = values


## A small line under the title, e.g. why the row is locked; empty hides it.
func set_note(text: String) -> void:
	_note.text = text
	_note.visible = not text.is_empty()


## A disabled row is skipped by focus and shows its title muted.
func set_enabled(enabled: bool) -> void:
	if control is Slider:
		(control as Slider).editable = enabled
	else:
		(control as BaseButton).disabled = not enabled
	control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	var color := CampaignStyle.TEXT if enabled else CampaignStyle.MUTED.darkened(0.25)
	_title.add_theme_color_override("font_color", color)


## Creates the control of the row's kind and returns what goes into the row's right half.
func _build_control() -> Control:
	match _kind:
		Kind.TOGGLE:
			var box := CheckBox.new()
			box.toggled.connect(_on_toggled)
			control = box
		Kind.CHOICE:
			var list := OptionButton.new()
			list.item_selected.connect(_on_item_selected)
			control = list
		Kind.PERCENT:
			return _build_slider()
	return control


func _build_slider() -> Control:
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_FILL
	slider.value_changed.connect(_on_slider_moved)
	slider.drag_started.connect(_on_drag_started)
	slider.drag_ended.connect(_on_drag_ended)
	control = slider
	_number = CampaignStyle.label()
	_number.custom_minimum_size.x = NUMBER_WIDTH
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var box := HBoxContainer.new()
	box.add_child(slider)
	box.add_child(_number)
	# A slider has no focus style of its own: the row rings slider and number instead.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _slider_frame(false))
	slider.focus_entered.connect(
		func() -> void: frame.add_theme_stylebox_override("panel", _slider_frame(true))
	)
	slider.focus_exited.connect(
		func() -> void: frame.add_theme_stylebox_override("panel", _slider_frame(false))
	)
	frame.add_child(box)
	return frame


func _slider_frame(focused: bool) -> StyleBoxFlat:
	var style := GameTheme.focus_ring()
	if not focused:
		style.set_border_width_all(0)
	style.set_content_margin_all(0)
	style.content_margin_left = SLIDER_INSET
	style.content_margin_right = SLIDER_INSET
	return style


## Left and right step switches and choices; the slider steps by itself.
func _on_control_input(event: InputEvent) -> void:
	if _kind == Kind.PERCENT:
		return
	var step := 0
	for action: StringName in [&"ui_left", &"ui_right"]:
		if event.is_action_pressed(action, true):
			step = -1 if action == &"ui_left" else 1
			# A held stick keeps sending events; only its first push counts.
			if event is InputEventJoypadMotion and not Input.is_action_just_pressed(action):
				step = 0
			control.accept_event()
	if step == 0:
		return
	if _kind == Kind.TOGGLE:
		var box := control as CheckBox
		if box.button_pressed != (step > 0):
			Audio.play(UiSounds.SLIDER)
			box.button_pressed = step > 0
	else:
		var list := control as OptionButton
		var index := clampi(list.selected + step, 0, list.item_count - 1)
		if index != list.selected:
			Audio.play(UiSounds.SLIDER)
			list.select(index)
			list.item_selected.emit(index)


func _on_toggled(on: bool) -> void:
	_show_state()
	changed.emit(on)


func _on_item_selected(index: int) -> void:
	changed.emit(_values[index])


func _on_slider_moved(value: float) -> void:
	_show_number(value)
	if not (on_release and _dragging):
		changed.emit(value / PERCENT_STEPS)


func _on_drag_started() -> void:
	_dragging = true


func _on_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	if on_release:
		changed.emit((control as HSlider).value / PERCENT_STEPS)


func _show_state() -> void:
	var box := control as CheckBox
	box.text = tr("OPTIONS_ON") if box.button_pressed else tr("OPTIONS_OFF")


func _show_number(value: float) -> void:
	_number.text = tr("OPTIONS_PERCENT") % roundi(value)
