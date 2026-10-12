class_name ErrorToast
extends PanelContainer
## A short-lived message at the bottom of the screen, e.g. why a command was refused.

const SECONDS := 3.0
const FADE := 0.4

var _label := CampaignStyle.label("", CampaignStyle.FONT_SIZE, CampaignStyle.BAD)
var _tween: Tween


func _init() -> void:
	theme = CampaignStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(
		"panel", CampaignStyle.panel_style(Color(0.20, 0.07, 0.05, 0.95), 2, 12)
	)
	add_child(_label)
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## Shows the text of a key from data/i18n/texts.csv, e.g. a command's error.
func show_error(key: String) -> void:
	_label.text = tr(key)
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	visible = true
	modulate.a = 1.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)
