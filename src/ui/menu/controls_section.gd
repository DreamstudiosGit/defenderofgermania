class_name ControlsSection
extends VBoxContainer
## The controls tab of the options: every action of every scene with its keyboard and
## controller binding (ControlsList), rebinding and a reset to the defaults. Selecting a
## binding waits for the next key, mouse button, controller button or stick (BindingCapture);
## a conflict inside the scene swaps or is refused (InputRebind) and the line at the bottom
## says what happened. The list scrolls by itself between the column titles and that line,
## so both stay in view; the options screen's own scroll area has nothing left to scroll.

const FOOTER_HEIGHT := 44.0

var _list := ControlsList.new()
var _notice := CampaignStyle.paragraph()
var _reset_all := Button.new()
var _confirm := ConfirmDialog.new()
var _capture: BindingCapture = null
## The scene the open question is about; empty for all of them.
var _asked_scene := ""


func _init() -> void:
	InputTable.register()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	add_child(_column_titles(_list.get_v_scroll_bar()))
	_list.name = "list"
	_list.rebind_requested.connect(_on_rebind_requested)
	_list.reset_requested.connect(_ask_reset)
	add_child(_list)
	add_child(_footer())
	# In front of the whole screen, whatever the section's own place in it.
	_confirm.name = "confirm_reset"
	_confirm.top_level = true
	_confirm.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm)
	FocusTrap.pin(_reset_all, [SIDE_LEFT, SIDE_RIGHT, SIDE_BOTTOM])
	var last := _list.last_control()
	_reset_all.focus_neighbor_top = _reset_all.get_path_to(last if last != null else _reset_all)
	_list.link_ends(null, _reset_all)


func _unhandled_input(event: InputEvent) -> void:
	# What the question in front does not use must not reach the options screen behind it,
	# which switches tabs and closes on keys of its own.
	if _confirm.is_visible_in_tree() and not event is InputEventMouse:
		get_viewport().set_input_as_handled()


## Shows the current bindings.
func refresh() -> void:
	_list.refresh()
	if is_inside_tree():
		_link_ways_out()


func _column_titles(bar: ScrollBar) -> Control:
	var titles := ControlsRow.new(tr("INPUT_COLUMN_ACTION"))
	titles.custom_minimum_size.y = 0
	titles.use_texts(PackedStringArray([tr("INPUT_COLUMN_KEYS"), tr("INPUT_COLUMN_PAD")]))
	for label: Label in titles.get_children():
		label.add_theme_font_size_override("font_size", CampaignStyle.SMALL_SIZE)
		label.add_theme_color_override("font_color", CampaignStyle.MUTED)
		label.tooltip_text = ""
	# The titles stand outside the list; they keep clear of its scroll bar to line up.
	var gap := Control.new()
	titles.add_child(gap)
	bar.resized.connect(
		func() -> void: gap.custom_minimum_size.x = maxf(bar.size.x - ControlsRow.SEPARATION, 0.0)
	)
	return titles


func _footer() -> Control:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_notice.name = "notice"
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.custom_minimum_size.y = FOOTER_HEIGHT
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Clipped like the options' description line: a long notice never moves the panel.
	_notice.clip_text = true
	footer.add_child(_notice)
	_reset_all.name = "reset_all"
	_reset_all.text = tr("INPUT_RESET_ALL")
	_reset_all.pressed.connect(_ask_reset.bind(""))
	footer.add_child(_reset_all)
	return footer


## The ways out of the section: up to the tab bar it sits under, down to whatever follows
## it on the screen (the options' back button). Without either, focus stays.
func _link_ways_out() -> void:
	var tabs: Node = self
	while tabs != null and not tabs is TabContainer:
		tabs = tabs.get_parent()
	_list.link_ends((tabs as TabContainer).get_tab_bar() if tabs != null else null, _reset_all)
	var next := _reset_all.find_next_valid_focus()
	if next == null or is_ancestor_of(next):
		next = _reset_all
	_reset_all.focus_neighbor_bottom = _reset_all.get_path_to(next)


func _show_notice(text: String, problem: bool = false) -> void:
	_notice.text = text
	var color := CampaignStyle.BAD if problem else CampaignStyle.TEXT
	_notice.add_theme_color_override("font_color", color)


func _ask_reset(scene: String) -> void:
	_asked_scene = scene
	var question := tr("INPUT_ASK_RESET_ALL")
	if not scene.is_empty():
		question = tr("INPUT_ASK_RESET_SCENE") % tr(InputTable.scene_text(scene))
	_confirm.ask(question, tr("INPUT_CONFIRM_RESET"))


func _on_reset_confirmed() -> void:
	var saved := InputOverrides.reset(_asked_scene) == OK
	refresh()
	if not saved:
		_show_notice(tr("INPUT_NOTICE_NOT_SAVED"), true)
	elif _asked_scene.is_empty():
		_show_notice(tr("INPUT_NOTICE_RESET_ALL"))
	else:
		_show_notice(tr("INPUT_NOTICE_RESET_SCENE") % tr(InputTable.scene_text(_asked_scene)))


func _on_rebind_requested(row: ControlsRow, family: InputTable.Family) -> void:
	if is_instance_valid(_capture):
		return
	_show_notice("")
	var heading := tr("INPUT_CAPTURE_ACTION") % [tr(InputTable.scene_text(row.scene)), row.title]
	var current := InputGlyphs.join(InputTable.tokens(row.scene, row.action, family))
	_capture = BindingCapture.new(family, heading, current)
	_capture.name = "capture"
	_capture.top_level = true
	_capture.captured.connect(_on_captured.bind(row, family))
	add_child(_capture)


func _on_captured(token: String, row: ControlsRow, family: InputTable.Family) -> void:
	var outcome := InputRebind.assign(row.scene, row.action, family, token)
	var glyph := InputGlyphs.text(token)
	refresh()
	var changed: Array[ControlsRow] = [row]
	var other := _list.row_of(row.scene, outcome.other)
	var texts := [row.title, glyph]
	if other != null:
		changed.append(other)
		texts.append(other.title)
		texts.append(InputGlyphs.join(InputTable.tokens(row.scene, outcome.other, family)))
	match outcome.result:
		InputRebind.Result.REFUSED:
			Audio.play(&"ui_back")
			var reason := tr("INPUT_NOTICE_INVALID")
			if not outcome.holder_text.is_empty():
				reason = tr("INPUT_NOTICE_REFUSED") % [glyph, tr(outcome.holder_text)]
			_show_notice(reason, true)
			return
		InputRebind.Result.UNCHANGED:
			return
		InputRebind.Result.BOUND:
			_show_notice(tr("INPUT_NOTICE_BOUND") % texts)
		InputRebind.Result.SWAPPED:
			_show_notice(tr("INPUT_NOTICE_SWAPPED") % texts)
		InputRebind.Result.TAKEN:
			_show_notice(tr("INPUT_NOTICE_TAKEN") % texts)
	Audio.play(&"ui_confirm")
	for shown: ControlsRow in changed:
		UiMotion.pulse(shown.cells[family], CampaignStyle.GOLD)
	if not outcome.saved:
		_show_notice(tr("INPUT_NOTICE_NOT_SAVED"), true)
