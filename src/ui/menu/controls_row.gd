class_name ControlsRow
extends HBoxContainer
## One line of the controls list: what an action does and its binding for the keyboard and
## mouse and for the controllers. A binding the player can change is a button; a fixed one,
## and the gap where an action does not exist on a device, is plain text.

## The player asks for another binding of this device family.
signal rebind_requested(family: InputTable.Family)

const HEIGHT := 34.0
const TITLE_WIDTH := 150.0
const CELL_WIDTH := 196.0
const SEPARATION := 8
const FONT_SIZE := CampaignStyle.SMALL_SIZE + 1
## Two bindings side by side ("L-Stick → / Steuerkreuz →") have to fit a cell.
const BINDING_SIZE := CampaignStyle.SMALL_SIZE

static var _cell_styles: Dictionary[String, StyleBox] = {}

var scene := ""
var action := ""
var title := ""
## The buttons by InputTable.Family; null where the row has nothing to press.
var cells: Array[Button] = [null, null]

## The bindings of a locked action, by InputTable.Family.
var _locked: Array[Label] = [null, null]


## `title_text` is the translated name of what the row is about; use_action() or
## use_texts() fills the two binding columns.
func _init(title_text: String) -> void:
	title = title_text
	custom_minimum_size.y = HEIGHT
	add_theme_constant_override("separation", SEPARATION)
	var label := CampaignStyle.label(title, FONT_SIZE)
	label.custom_minimum_size.x = TITLE_WIDTH
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = title
	add_child(label)


## Makes it the row of an action of the table.
func use_action(scene_name: String, action_name: String) -> void:
	scene = scene_name
	action = action_name
	name = "%s_%s" % [scene, action]
	for family: InputTable.Family in InputTable.Family.values():
		if InputTable.defaults(scene, action, family).is_empty():
			add_child(_text(tr("INPUT_UNBOUND"), 1))
		elif InputTable.is_locked(scene, action):
			_locked[family] = _text("", 1)
			add_child(_locked[family])
		else:
			cells[family] = _cell(family)
			add_child(cells[family])
	show_bindings()


## Makes it a row that only informs. Two texts fill the two columns; one alone spans both
## (mouse input, which has no controller side).
func use_texts(texts: PackedStringArray) -> void:
	for text: String in texts:
		var label := _text(text, 3 - texts.size())
		label.tooltip_text = _fixed_tip(text)
		add_child(label)


## Shows the action's bindings as they are now.
func show_bindings() -> void:
	for family: InputTable.Family in InputTable.Family.values():
		var text := InputGlyphs.join(InputTable.tokens(scene, action, family))
		if cells[family] != null:
			cells[family].text = text
			cells[family].tooltip_text = "%s\n%s" % [text, tr("INPUT_REBIND_HINT")]
		elif _locked[family] != null:
			_locked[family].text = text
			_locked[family].tooltip_text = _fixed_tip(text)


## True when the player can change at least one of the row's bindings.
func is_rebindable() -> bool:
	return cells[0] != null or cells[1] != null


func _cell(family: InputTable.Family) -> Button:
	var cell := Button.new()
	cell.name = InputTable.FAMILIES[family]
	cell.custom_minimum_size = Vector2(CELL_WIDTH, HEIGHT)
	cell.clip_text = true
	cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_theme_font_size_override("font_size", BINDING_SIZE)
	for state: String in ["normal", "hover", "pressed"]:
		cell.add_theme_stylebox_override(state, _cell_style(state))
	cell.pressed.connect(func() -> void: rebind_requested.emit(family))
	return cell


## A muted text over `columns` of the two binding columns.
func _text(text: String, columns: int) -> Label:
	var label := CampaignStyle.label(text, BINDING_SIZE, CampaignStyle.MUTED)
	label.custom_minimum_size.x = CELL_WIDTH * columns + SEPARATION * (columns - 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _fixed_tip(binding: String) -> String:
	return "%s\n%s" % [binding, tr("INPUT_FIXED_HINT")]


## Flatter than the theme's buttons, and dark like an input field.
static func _cell_style(state: String) -> StyleBox:
	if _cell_styles.is_empty():
		_cell_styles["normal"] = GameTheme.box(UiPalette.INK, 1, 8, 4)
		_cell_styles["hover"] = GameTheme.box(UiPalette.BUTTON_HOVER, 1, 8, 4, 1.0)
		_cell_styles["pressed"] = GameTheme.box(UiPalette.BUTTON_PRESSED, 2, 8, 4, 1.0)
	return _cell_styles[state]
