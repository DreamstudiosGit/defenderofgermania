class_name CampaignStyle
extends RefCounted
## Look of the campaign screens: dark parchment panels with a gold rim like the battle menus,
## light text, and buttons at least 44 px high (GDD "UI/UX": later handheld and touch).

const GOLD := GroupShield.GOLD
const TEXT := Color(0.96, 0.91, 0.80)
const MUTED := Color(0.74, 0.66, 0.54)
const GOOD := Color(0.62, 0.86, 0.46)
const BAD := Color(1.0, 0.52, 0.40)
const INK := Color(0.10, 0.07, 0.05)
const PANEL := Color(0.17, 0.12, 0.08, 0.96)
const BUTTON := Color(0.27, 0.19, 0.12)
const BUTTON_HOVER := Color(0.36, 0.26, 0.16)
const BUTTON_PRESSED := Color(0.48, 0.33, 0.14)
const BUTTON_DISABLED := Color(0.20, 0.15, 0.11)
const BUTTON_HEIGHT := 44
const FONT_SIZE := 16
const SMALL_SIZE := 14
## Theme type variation for rows of short choices.
const CHOICE := "ChoiceButton"

static var _theme: Theme


## The shared theme; set it on the root Control of every campaign screen.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = FONT_SIZE
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "PanelContainer", panel_style())
	_add_buttons(_theme)
	_add_tabs(_theme)
	var tip := panel_style(Color(0.12, 0.08, 0.05, 0.98), 1, 10)
	_theme.set_stylebox("panel", "TooltipPanel", tip)
	_theme.set_color("font_color", "TooltipLabel", TEXT)
	_theme.set_font_size("font_size", "TooltipLabel", SMALL_SIZE + 1)
	_theme.set_stylebox("background", "ProgressBar", _box(INK, 0, 3))
	_theme.set_stylebox("fill", "ProgressBar", _box(GOOD.darkened(0.25), 0, 3))
	_theme.set_font_size("font_size", "ProgressBar", SMALL_SIZE - 2)
	_theme.set_stylebox("slider", "HSlider", _box(INK, 0, 4, 4))
	_theme.set_stylebox("grabber_area", "HSlider", _box(GOLD.darkened(0.3), 0, 4, 4))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, 0, 4, 4))
	_theme.set_stylebox("focus", "HSlider", _focus_box())
	_theme.set_stylebox("normal", "LineEdit", _box(INK, 1, 6))
	_theme.set_stylebox("focus", "LineEdit", _focus_box())
	_theme.set_color("font_color", "LineEdit", TEXT)
	_theme.set_stylebox("separator", "HSeparator", _line())
	_theme.set_constant("separation", "HSeparator", 10)
	return _theme


## Opaque parchment-brown panel with a gold rim.
static func panel_style(
	color: Color = PANEL, border: int = 2, margin: int = 14
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = GOLD.darkened(0.15)
	style.set_border_width_all(border)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	return style


## Label outline of the battle HUD, for text drawn over the map.
static func outline(font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = TEXT
	settings.outline_size = 5
	settings.outline_color = INK
	return settings


## Turns root into a full-screen modal: a backdrop that swallows clicks (opaque hides the
## screen below, e.g. for the hot-seat handover) and a centred panel; returns its column.
static func modal(root: Control, backdrop: Color) -> VBoxContainer:
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = backdrop
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(PANEL, 3, 28))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column


## A centred action button for modal screens.
static func modal_button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.x = 220
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return result


## A label that shows its tooltip on hover.
static func label(text: String = "", font_size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


## A flat, focusable line for a value with a calculation tooltip, so keys and controllers can
## reach the tooltip too (FocusTooltip).
static func info(font_size: int = FONT_SIZE) -> Button:
	var result := Button.new()
	result.flat = true
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_constant_override("h_separation", 0)
	result.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	result.add_theme_stylebox_override("hover", _box(Color(GOLD, 0.08), 0, 4, 2))
	result.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	result.custom_minimum_size.y = 26
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func heading(text: String = "", font_size: int = 20) -> Label:
	return label(text, font_size, GOLD)


## A label that wraps inside its container instead of widening it.
static func paragraph(text: String = "", font_size: int = SMALL_SIZE) -> Label:
	var result := label(text, font_size, MUTED)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 120
	return result


static func _add_buttons(target: Theme) -> void:
	# 11 px above and below a 16 px line make the 44 px minimum height. CHOICE is a narrower
	# variation for rows of short options (tax rates, rations).
	target.set_type_variation(CHOICE, "Button")
	for type: String in ["Button", CHOICE]:
		var side := 10 if type == "Button" else 6
		target.set_stylebox("normal", type, _box(BUTTON, 1, side, 11))
		target.set_stylebox("hover", type, _box(BUTTON_HOVER, 1, side, 11))
		target.set_stylebox("pressed", type, _box(BUTTON_PRESSED, 2, side, 11))
		var hover_pressed := _box(BUTTON_PRESSED.lightened(0.1), 2, side, 11)
		target.set_stylebox("hover_pressed", type, hover_pressed)
		target.set_stylebox("disabled", type, _box(BUTTON_DISABLED, 1, side, 11, 0.35))
	target.set_stylebox("focus", "Button", _focus_box())
	target.set_color("font_color", "Button", TEXT)
	target.set_color("font_hover_color", "Button", Color.WHITE)
	target.set_color("font_focus_color", "Button", Color.WHITE)
	target.set_color("font_pressed_color", "Button", GOLD)
	target.set_color("font_hover_pressed_color", "Button", GOLD)
	target.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))


static func _add_tabs(target: Theme) -> void:
	target.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), 0, 8))
	target.set_stylebox("tab_selected", "TabContainer", _box(BUTTON_PRESSED, 1, 8))
	target.set_stylebox("tab_unselected", "TabContainer", _box(BUTTON, 1, 8))
	target.set_stylebox("tab_hovered", "TabContainer", _box(BUTTON_HOVER, 1, 8))
	target.set_stylebox("tab_focus", "TabContainer", _focus_box())
	target.set_color("font_selected_color", "TabContainer", GOLD)
	target.set_color("font_unselected_color", "TabContainer", TEXT)
	target.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	target.set_font_size("font_size", "TabContainer", SMALL_SIZE + 1)


static func _box(
	color: Color, border: int, margin: int, vertical: int = -1, rim_alpha: float = 0.7
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(GOLD, rim_alpha).darkened(0.35)
	style.set_border_width_all(border)
	style.set_corner_radius_all(5)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.5 if vertical < 0 else vertical
	style.content_margin_bottom = style.content_margin_top
	return style


static func _focus_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_expand_margin_all(2)
	return style


static func _line() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = Color(GOLD, 0.35)
	style.thickness = 1
	return style
