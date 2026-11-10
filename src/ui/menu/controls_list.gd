class_name ControlsList
extends ScrollContainer
## The scrolling list of the controls tab: a heading per scene, a row per action
## (ControlsRow), the scene's fixed mouse input and a button that resets the scene. Confirm,
## cancel and pause, which belong to the engine and to App, come first as fixed rows. It
## spells out the ways between its controls and scrolls the focused line into view together
## with the headings and fixed rows around it, which take no focus themselves.

signal rebind_requested(row: ControlsRow, family: InputTable.Family)
signal reset_requested(scene: String)

const HEADING_SIZE := 18
const HEADING_HEIGHT := 38.0
const MIN_HEIGHT := 110.0

var _box := VBoxContainer.new()
var _rows: Array[ControlsRow] = []
## The lines that take focus from top to bottom, each as [left, right]; one may be null.
var _lines: Array[Array] = []


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	follow_focus = true
	custom_minimum_size.y = MIN_HEIGHT
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 2)
	_box.sort_children.connect(_reveal_focused)
	add_child(_box)
	_add_general()
	for scene: String in InputTable.scenes():
		_add_scene(scene)
	_link_lines()


## Shows the bindings as they are now.
func refresh() -> void:
	for row: ControlsRow in _rows:
		row.show_bindings()


func row_of(scene: String, action: String) -> ControlsRow:
	for row: ControlsRow in _rows:
		if row.scene == scene and row.action == action:
			return row
	return null


## The control up leads to from below the list; null for an empty list.
func last_control() -> Control:
	return _at(_lines.size() - 1, 1) if not _lines.is_empty() else null


## Where up leads from the first line and down from the last; null keeps focus there.
func link_ends(above: Control, below: Control) -> void:
	if _lines.is_empty():
		return
	for column: int in 2:
		var first: Control = _lines[0][column]
		if first != null:
			first.focus_neighbor_top = first.get_path_to(above if above != null else first)
		var last: Control = _lines[_lines.size() - 1][column]
		if last != null:
			last.focus_neighbor_bottom = last.get_path_to(below if below != null else last)


func _add_general() -> void:
	_box.add_child(_heading(tr("INPUT_SCENE_GENERAL")))
	var general: Dictionary[String, StringName] = {
		"INPUT_GENERAL_ACCEPT": &"ui_accept",
		"INPUT_GENERAL_CANCEL": &"ui_cancel",
		InputRebind.PAUSE_TEXT: App.PAUSE_ACTION,
	}
	for text_key: String in general:
		var texts := PackedStringArray()
		for family: InputTable.Family in InputTable.Family.values():
			texts.append(InputGlyphs.join(InputGlyphs.action_tokens(general[text_key], family)))
		var row := ControlsRow.new(tr(text_key))
		row.use_texts(texts)
		_box.add_child(row)


func _add_scene(scene: String) -> void:
	var scene_name := tr(InputTable.scene_text(scene))
	_box.add_child(_heading(scene_name))
	for action: String in InputTable.actions(scene):
		var row := ControlsRow.new(tr(InputTable.action_text(scene, action)))
		row.use_action(scene, action)
		row.rebind_requested.connect(
			func(family: InputTable.Family) -> void: rebind_requested.emit(row, family)
		)
		_rows.append(row)
		_box.add_child(row)
		if row.is_rebindable():
			_add_line(row.cells[InputTable.Family.KEYS], row.cells[InputTable.Family.PAD])
	for fixed_name: String in InputTable.fixed(scene):
		var row := ControlsRow.new(tr(InputTable.action_text(scene, fixed_name)))
		var tokens := InputTable.fixed_tokens(scene, fixed_name)
		row.use_texts(PackedStringArray([InputGlyphs.join(tokens)]))
		_box.add_child(row)
	var reset := Button.new()
	reset.name = "reset_%s" % scene
	reset.text = tr("INPUT_RESET_SCENE") % scene_name
	reset.add_theme_font_size_override("font_size", ControlsRow.FONT_SIZE)
	reset.pressed.connect(func() -> void: reset_requested.emit(scene))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(reset)
	_box.add_child(line)
	_add_line(null, reset)


func _heading(text: String) -> Label:
	var heading := CampaignStyle.heading(text, HEADING_SIZE)
	heading.custom_minimum_size.y = HEADING_HEIGHT
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return heading


func _add_line(left: Control, right: Control) -> void:
	_lines.append([left, right])
	for control: Control in [left, right]:
		if control != null:
			control.focus_entered.connect(_reveal_focused, CONNECT_DEFERRED)


## Up and down keep the column where the next line has one, left and right stay inside the
## line. Godot's own search for a neighbour would leave the list for the screen behind it.
func _link_lines() -> void:
	for index: int in _lines.size():
		for column: int in 2:
			var control: Control = _lines[index][column]
			if control == null:
				continue
			var beside: Control = _lines[index][1 - column]
			FocusTrap.pin(control, [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM])
			if beside != null:
				var inner := SIDE_RIGHT if column == 0 else SIDE_LEFT
				control.set_focus_neighbor(inner, control.get_path_to(beside))
			if index > 0:
				control.focus_neighbor_top = control.get_path_to(_at(index - 1, column))
			if index + 1 < _lines.size():
				control.focus_neighbor_bottom = control.get_path_to(_at(index + 1, column))


## The control of a line in a column, or the line's only one.
func _at(index: int, column: int) -> Control:
	var control: Control = _lines[index][column]
	return control if control != null else _lines[index][1 - column]


## Shows the lines around the focused one that cannot take focus along with it: focus alone
## would never scroll a heading or a fixed row into view. It also runs once the list is laid
## out, because focus given right after the page was built arrives before that.
func _reveal_focused() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused == null or not _box.is_ancestor_of(focused):
		return
	var line := focused.get_parent() as Control
	for step: int in [-1, 1]:
		var index := line.get_index() + step
		var furthest: Control = null
		while index >= 0 and index < _box.get_child_count():
			var other := _box.get_child(index) as Control
			if not FocusTrap.focusables(other).is_empty():
				break
			furthest = other
			index += step
		if furthest != null:
			ensure_control_visible(furthest)
	ensure_control_visible(line)
