class_name CastleOverlay
extends CanvasLayer
## Screen layer of the castle view: the rendered castle stage full screen, the castle's name with
## its province, a bar for the castle construction, the buttons for the time-lapse and back to
## the campaign, and a line that names the keys of the device in use. Only the button back takes
## focus and it keeps it: the arrow keys and the d-pad turn the castle instead of moving focus.

signal close_pressed
signal timelapse_pressed

const LAYER := 20
const TITLE_SIZE := 28
const MARGIN := 20

var _stage := TextureRect.new()
var _title := Label.new()
var _subtitle := Label.new()
var _construction := ProgressBar.new()
var _timelapse := Button.new()
var _close := Button.new()
var _hint := Label.new()


func _init() -> void:
	layer = LAYER
	_stage.name = "Stage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.stretch_mode = TextureRect.STRETCH_SCALE
	# The stage has the window's pixels, more than the canvas has units: it must not size the rect.
	_stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme = CampaignStyle.theme()
	for side: String in ["left", "right", "top"]:
		frame.add_theme_constant_override("margin_" + side, MARGIN)
	frame.add_child(FocusTrap.new())
	add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	frame.add_child(row)
	row.add_child(_name_plate())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_timelapse.name = "Replay"
	_timelapse.focus_mode = Control.FOCUS_NONE
	_timelapse.pressed.connect(timelapse_pressed.emit)
	_add_button(row, _timelapse, 200)
	_close.name = "Close"
	_close.text = tr("CASTLE_CLOSE")
	_close.set_meta(UiSounds.SOUND_META, &"ui_back")
	_close.pressed.connect(close_pressed.emit)
	_add_button(row, _close, 170)
	FocusTrap.pin(_close, [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM])
	FocusTrap.ring(_close, _close)
	_hint.name = "Hint"
	_hint.label_settings = CampaignStyle.outline(CampaignStyle.SMALL_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.theme = CampaignStyle.theme()
	_hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN
	)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)
	show_timelapse(false)
	show_device(App.pad_in_use)
	App.pad_in_use_changed.connect(show_device)


func show_stage(texture: Texture2D) -> void:
	_stage.texture = texture


## construction: progress of the next castle level, or a negative value when none is building.
func show_castle(title: String, subtitle: String, construction: float) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_construction.visible = construction >= 0.0
	_construction.value = maxf(construction, 0.0)


## The time-lapse button offers to skip while one plays, to watch it again otherwise.
func show_timelapse(playing: bool) -> void:
	_timelapse.text = tr("CASTLE_TIMELAPSE_SKIP" if playing else "CASTLE_TIMELAPSE")


## The hint line for a controller or for keyboard and mouse.
func show_device(pad: bool) -> void:
	_hint.text = tr("CASTLE_HINT_PAD" if pad else "CASTLE_HINT_KEYS")


## Puts focus on the button back, so a key or a controller always has something to act on.
func take_focus() -> void:
	if _close.is_visible_in_tree():
		_close.grab_focus()


func _name_plate() -> PanelContainer:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	panel.add_child(column)
	_title.name = "Title"
	_title.add_theme_font_override("font", UiFonts.display())
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", CampaignStyle.GOLD)
	column.add_child(_title)
	_subtitle.name = "Subtitle"
	_subtitle.add_theme_color_override("font_color", CampaignStyle.MUTED)
	column.add_child(_subtitle)
	_construction.name = "Construction"
	_construction.show_percentage = false
	_construction.max_value = 1.0
	_construction.custom_minimum_size = Vector2(0, 8)
	column.add_child(_construction)
	return panel


func _add_button(row: Container, button: Button, width: float) -> void:
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(width, CampaignStyle.BUTTON_HEIGHT)
	row.add_child(button)
