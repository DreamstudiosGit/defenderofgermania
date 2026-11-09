class_name CampaignStyle
extends RefCounted
## Building blocks of the screens on top of the shared look (GameTheme, UiPalette, UiFonts):
## labels, headings, value lines with tooltips and full-screen modals.

const GOLD := UiPalette.GOLD
const TEXT := UiPalette.TEXT
const MUTED := UiPalette.MUTED
const GOOD := UiPalette.GOOD
const BAD := UiPalette.BAD
const INK := UiPalette.INK
const PANEL := UiPalette.PANEL
const BUTTON := UiPalette.BUTTON
const BUTTON_HOVER := UiPalette.BUTTON_HOVER
const BUTTON_PRESSED := UiPalette.BUTTON_PRESSED
const BUTTON_DISABLED := UiPalette.BUTTON_DISABLED
const BUTTON_HEIGHT := GameTheme.BUTTON_HEIGHT
const FONT_SIZE := GameTheme.FONT_SIZE
const SMALL_SIZE := GameTheme.SMALL_SIZE
const TITLE_SIZE := 34
## Theme type variation for rows of short choices.
const CHOICE := GameTheme.CHOICE


## The shared theme; App sets it on every topmost Control.
static func theme() -> Theme:
	return GameTheme.shared()


## Opaque parchment-brown panel with a gold rim.
static func panel_style(
	color: Color = PANEL, border: int = 2, margin: int = 14
) -> StyleBoxFlat:
	return GameTheme.panel(color, border, margin)


## Label outline of the HUDs, for text drawn over a 3D scene.
static func outline(font_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = UiFonts.body(UiFonts.BOLD)
	settings.font_size = font_size
	settings.font_color = TEXT
	settings.outline_size = 5
	settings.outline_color = INK
	return settings


## Turns root into a full-screen modal: a backdrop that swallows clicks (opaque hides the
## screen below, e.g. for the hot-seat handover) and a centred panel that pops in whenever
## the screen shows; returns the panel's column.
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
	panel.add_theme_stylebox_override("panel", GameTheme.panel(PANEL, 3, 28, 24))
	center.add_child(panel)
	UiMotion.pop_on_show(root, panel)
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
	result.add_theme_stylebox_override("hover", GameTheme.box(Color(GOLD, 0.08), 0, 4, 2))
	result.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	result.custom_minimum_size.y = 26
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


## A gold heading in the Textura display face (GDD "Lesbarkeit").
static func heading(text: String = "", font_size: int = 20) -> Label:
	var result := label(text, font_size, GOLD)
	result.add_theme_font_override("font", UiFonts.display())
	return result


## The centred title of a screen.
static func title(text: String = "", font_size: int = TITLE_SIZE) -> Label:
	var result := heading(text, font_size)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result


## A label that wraps inside its container instead of widening it.
static func paragraph(text: String = "", font_size: int = SMALL_SIZE) -> Label:
	var result := label(text, font_size, MUTED)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 120
	return result
