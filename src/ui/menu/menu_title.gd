class_name MenuTitle
extends VBoxContainer
## The game's name as the main menu shows it: "THRONSTREIT" in the Textura face, the year
## between two gold rules, and the tagline below. Outlined, since it stands over the 3D table.

const NAME_SIZE := 76
const YEAR_SIZE := 28
const TAGLINE_SIZE := 19
const RULE_HEIGHT := 2.0


func _init() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var title := CampaignStyle.heading(tr("MENU_TITLE"), NAME_SIZE)
	title.name = "name"
	_outline(title, 10)
	add_child(title)
	var year_row := HBoxContainer.new()
	year_row.add_theme_constant_override("separation", 14)
	add_child(year_row)
	year_row.add_child(_rule())
	var year := CampaignStyle.heading(tr("MENU_TITLE_YEAR"), YEAR_SIZE)
	year.add_theme_color_override("font_color", UiPalette.TEXT)
	_outline(year, 6)
	year_row.add_child(year)
	year_row.add_child(_rule())
	var tagline := CampaignStyle.label(tr("MENU_TAGLINE"), TAGLINE_SIZE)
	tagline.name = "tagline"
	tagline.add_theme_font_override("font", UiFonts.italic())
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(tagline, 5)
	add_child(tagline)


static func _outline(label: Label, width: int) -> void:
	label.add_theme_constant_override("outline_size", width)
	label.add_theme_color_override("font_outline_color", UiPalette.INK)


static func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiPalette.GOLD.darkened(0.15)
	rule.custom_minimum_size.y = RULE_HEIGHT
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule
