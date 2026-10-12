class_name CastleOverlay
extends CanvasLayer
## Screen layer of the castle view: the rendered castle stage full screen, the castle's name with
## its province, a bar for the castle construction and the button back to the campaign.

signal close_pressed

const LAYER := 20
const TITLE_SIZE := 28

var _stage := TextureRect.new()
var _title := Label.new()
var _subtitle := Label.new()
var _construction := ProgressBar.new()
var _close := Button.new()


func _init() -> void:
	layer = LAYER
	_stage.name = "Stage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.stretch_mode = TextureRect.STRETCH_SCALE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme = CampaignStyle.theme()
	for side: String in ["left", "right", "top"]:
		frame.add_theme_constant_override("margin_" + side, 20)
	add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	var panel := PanelContainer.new()
	row.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_title.name = "Title"
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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_close.name = "Close"
	_close.text = tr("CASTLE_CLOSE")
	_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close.custom_minimum_size = Vector2(140, CampaignStyle.BUTTON_HEIGHT)
	_close.pressed.connect(close_pressed.emit)
	row.add_child(_close)


func show_stage(texture: Texture2D) -> void:
	_stage.texture = texture


## construction: progress of the next castle level, or a negative value when none is building.
func show_castle(title: String, subtitle: String, construction: float) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_construction.visible = construction >= 0.0
	_construction.value = maxf(construction, 0.0)
