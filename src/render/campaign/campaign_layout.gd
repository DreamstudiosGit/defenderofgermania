class_name CampaignLayout
extends RefCounted
## Where the campaign scene's panels sit: the HUD across the top, the administration panel on
## the left, the province and army panels on the right; modal screens cover everything.

const MARGIN := 8.0
const TOP := 80.0
const SIDE_WIDTH := 340.0
const ADMIN_WIDTH := 450.0


## A full-screen root on the UI layer that lets clicks through to the war table.
static func root(ui: CanvasLayer, base: Control) -> void:
	ui.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.theme = CampaignStyle.theme()


static func top(base: Control, hud: Control) -> void:
	base.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN)


static func left(base: Control, panel: Control) -> void:
	base.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = MARGIN
	panel.offset_top = TOP
	panel.offset_right = MARGIN + ADMIN_WIDTH
	panel.offset_bottom = -MARGIN


## A column on the right holding the panels from top to bottom.
static func right(base: Control, panels: Array[Control]) -> VBoxContainer:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", MARGIN)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -MARGIN - SIDE_WIDTH
	side.offset_top = TOP
	side.offset_right = -MARGIN
	side.offset_bottom = -MARGIN
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for panel: Control in panels:
		side.add_child(panel)
	return side
