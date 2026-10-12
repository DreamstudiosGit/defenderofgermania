class_name FocusTooltip
extends PanelContainer
## Shows the tooltip of the focused control while the player steers with keys or a
## controller; mouse tooltips only appear on hover (GDD "UI/UX": hover or hold). Add one to a
## screen's root; it hides as soon as the mouse moves.

const GAP := 6.0
const MAX_WIDTH := 560.0
const STICK_DEADZONE := 0.5

var _label := Label.new()
var _steering := false


func _init() -> void:
	top_level = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	add_theme_stylebox_override(
		"panel", CampaignStyle.panel_style(Color(0.12, 0.08, 0.05, 0.98), 1, 10)
	)
	_label.add_theme_font_size_override("font_size", CampaignStyle.SMALL_SIZE + 1)
	add_child(_label)


## Shows tooltips for focus from now on, as if keys or a controller were in use.
func steer_by_focus() -> void:
	_steering = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_steering = false
	elif event is InputEventKey or event is InputEventJoypadButton:
		_steering = true
	elif event is InputEventJoypadMotion:
		_steering = _steering or absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE


func _process(_delta: float) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if not _steering or owner == null or owner.tooltip_text.is_empty():
		visible = false
		return
	if not owner.is_visible_in_tree():
		visible = false
		return
	if _label.text != owner.tooltip_text:
		_label.text = owner.tooltip_text
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.custom_minimum_size.x = 0.0
		if _label.get_minimum_size().x > MAX_WIDTH:
			_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_label.custom_minimum_size.x = MAX_WIDTH
		reset_size()
	_place(owner)
	visible = true


func _place(owner: Control) -> void:
	var screen := get_viewport().get_visible_rect().size
	var area := owner.get_global_rect()
	var spot := Vector2(area.position.x, area.end.y + GAP)
	if spot.y + size.y > screen.y:
		spot.y = area.position.y - GAP - size.y
	spot.x = clampf(spot.x, GAP, maxf(GAP, screen.x - size.x - GAP))
	spot.y = clampf(spot.y, GAP, maxf(GAP, screen.y - size.y - GAP))
	global_position = spot
