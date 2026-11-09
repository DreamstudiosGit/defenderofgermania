class_name GameTheme
extends RefCounted
## The one Theme of the game: dark parchment panels with a gold rim, the two typefaces of
## UiFonts and controls at least 44 px high (GDD "UI/UX": later handheld and touch). App gives
## it to every topmost Control; screens only add what is special about them.

const BUTTON_HEIGHT := 44
const FONT_SIZE := 16
const SMALL_SIZE := 14
## Theme type variation for rows of short choices.
const CHOICE := "ChoiceButton"
const RADIUS := 6

static var _theme: Theme


static func shared() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Parchment-brown panel with a gold rim and a soft shadow.
static func panel(
	color: Color = UiPalette.PANEL, border: int = 2, margin: int = 14, shadow: int = 8
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UiPalette.GOLD.darkened(0.15)
	style.set_border_width_all(border)
	style.set_corner_radius_all(RADIUS + 2)
	style.set_content_margin_all(margin)
	style.shadow_color = UiPalette.SHADOW
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, shadow * 0.25)
	return style


static func box(
	color: Color, border: int, margin: int, vertical: int = -1, rim_alpha: float = 0.7
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(UiPalette.GOLD, rim_alpha).darkened(0.35)
	style.set_border_width_all(border)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.5 if vertical < 0 else vertical
	style.content_margin_bottom = style.content_margin_top
	return style


static func focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = UiPalette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(RADIUS)
	style.set_expand_margin_all(2)
	return style


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = UiFonts.body()
	theme.default_font_size = FONT_SIZE
	theme.set_color("font_color", "Label", UiPalette.TEXT)
	theme.set_color("default_color", "RichTextLabel", UiPalette.TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel())
	_add_buttons(theme)
	_add_tabs(theme)
	_add_popups(theme)
	_add_ranges(theme)
	_add_scroll_bars(theme)
	theme.set_stylebox("normal", "LineEdit", box(UiPalette.INK, 1, 8, 10))
	theme.set_stylebox("focus", "LineEdit", focus_ring())
	theme.set_color("font_color", "LineEdit", UiPalette.TEXT)
	theme.set_color("caret_color", "LineEdit", UiPalette.GOLD)
	theme.set_stylebox("separator", "HSeparator", _line(false))
	theme.set_constant("separation", "HSeparator", 10)
	theme.set_stylebox("separator", "VSeparator", _line(true))
	theme.set_constant("separation", "VSeparator", 10)
	return theme


static func _add_buttons(theme: Theme) -> void:
	# 11 px above and below a 16 px line make the 44 px minimum height. CHOICE is a narrower
	# variation for rows of short options (tax rates, rations).
	theme.set_type_variation(CHOICE, "Button")
	for type: String in ["Button", CHOICE]:
		var side := 14 if type == "Button" else 6
		theme.set_stylebox("normal", type, box(UiPalette.BUTTON, 1, side, 11))
		theme.set_stylebox("hover", type, box(UiPalette.BUTTON_HOVER, 1, side, 11, 1.0))
		theme.set_stylebox("pressed", type, box(UiPalette.BUTTON_PRESSED, 2, side, 11, 1.0))
		var hover_pressed := box(UiPalette.BUTTON_PRESSED.lightened(0.1), 2, side, 11, 1.0)
		theme.set_stylebox("hover_pressed", type, hover_pressed)
		theme.set_stylebox("disabled", type, box(UiPalette.BUTTON_DISABLED, 1, side, 11, 0.35))
	theme.set_stylebox("focus", "Button", focus_ring())
	for type: String in ["Button", "CheckBox", "CheckButton"]:
		theme.set_color("font_color", type, UiPalette.TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, UiPalette.GOLD)
		theme.set_color("font_hover_pressed_color", type, UiPalette.GOLD)
		theme.set_color("font_disabled_color", type, UiPalette.MUTED.darkened(0.25))
	for type: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, box(Color(0, 0, 0, 0), 0, 6, 11))
		theme.set_stylebox("focus", type, focus_ring())
		theme.set_constant("h_separation", type, 10)


static func _add_tabs(theme: Theme) -> void:
	theme.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, 8))
	for type: String in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, box(UiPalette.BUTTON_PRESSED, 1, 10, 9, 1.0))
		theme.set_stylebox("tab_unselected", type, box(UiPalette.BUTTON, 1, 10, 9))
		theme.set_stylebox("tab_hovered", type, box(UiPalette.BUTTON_HOVER, 1, 10, 9))
		theme.set_stylebox("tab_disabled", type, box(UiPalette.BUTTON_DISABLED, 1, 10, 9, 0.35))
		theme.set_stylebox("tab_focus", type, focus_ring())
		theme.set_color("font_selected_color", type, UiPalette.GOLD)
		theme.set_color("font_unselected_color", type, UiPalette.TEXT)
		theme.set_color("font_hovered_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, UiPalette.MUTED.darkened(0.25))
		theme.set_font_size("font_size", type, SMALL_SIZE + 1)


## Tooltips and the lists of dropdowns.
static func _add_popups(theme: Theme) -> void:
	var tip := panel(UiPalette.INSET, 1, 10, 6)
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", UiPalette.TEXT)
	theme.set_font_size("font_size", "TooltipLabel", SMALL_SIZE + 1)
	theme.set_stylebox("panel", "PopupMenu", panel(UiPalette.INSET, 1, 6, 10))
	theme.set_stylebox("hover", "PopupMenu", box(UiPalette.BUTTON_HOVER, 0, 8, 4))
	theme.set_color("font_color", "PopupMenu", UiPalette.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", UiPalette.MUTED.darkened(0.25))
	theme.set_constant("v_separation", "PopupMenu", 14)
	theme.set_constant("h_separation", "PopupMenu", 10)


static func _add_ranges(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", box(UiPalette.INK, 0, 3))
	theme.set_stylebox("fill", "ProgressBar", box(UiPalette.GOOD.darkened(0.25), 0, 3))
	theme.set_font_size("font_size", "ProgressBar", SMALL_SIZE - 2)
	theme.set_stylebox("slider", "HSlider", box(UiPalette.INK, 1, 4, 4))
	theme.set_stylebox("grabber_area", "HSlider", box(UiPalette.GOLD.darkened(0.3), 0, 4, 4))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(UiPalette.GOLD, 0, 4, 4))
	theme.set_stylebox("focus", "HSlider", focus_ring())


static func _add_scroll_bars(theme: Theme) -> void:
	for type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, _bar(Color(UiPalette.INK, 0.6)))
		theme.set_stylebox("scroll_focus", type, _bar(Color(UiPalette.INK, 0.6)))
		theme.set_stylebox("grabber", type, _bar(UiPalette.GOLD.darkened(0.45)))
		theme.set_stylebox("grabber_highlight", type, _bar(UiPalette.GOLD.darkened(0.25)))
		theme.set_stylebox("grabber_pressed", type, _bar(UiPalette.GOLD))


static func _bar(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	return style


static func _line(vertical: bool) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = Color(UiPalette.GOLD, 0.35)
	style.thickness = 1
	style.vertical = vertical
	return style
