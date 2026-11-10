class_name SaveSlotsScreen
extends Control
## The saved campaigns (SaveGames: the autosave and three slots) as a modal, to load one or to
## save the running campaign into a slot. Every line tells what its slot holds (SaveSlotRow);
## a used manual slot can be deleted, and overwriting or deleting asks first. Esc / B goes
## back. It keeps working while the tree is paused, so the pause menu can show it.

signal closed
## LOAD mode: the player picked a readable save; the caller continues it.
signal load_requested(slot: String)
## SAVE mode: the campaign was written into the slot.
signal saved(slot: String)

enum Mode { LOAD, SAVE }

const BACKDROP_ALPHA := 0.8
## Smaller than the other screens' titles: the list has to fit 720 lines at the largest UI
## scale too.
const TITLE_SIZE := 30
const MESSAGE_HEIGHT := 24.0

var _mode := Mode.LOAD
var _state: GameState = null
var _title := CampaignStyle.title("", TITLE_SIZE)
var _rows: Array[SaveSlotRow] = []
var _message := CampaignStyle.label("", CampaignStyle.SMALL_SIZE + 1, CampaignStyle.MUTED)
var _back := CampaignStyle.modal_button("")
var _confirm := ConfirmDialog.new()
var _confirmed_action := Callable()
## The houses' colours for the rows; read when the list first opens, null if that fails.
var _map: MapData = null
var _map_read := false
var _focus_before: Control = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, BACKDROP_ALPHA))
	column.get_parent().name = "panel"
	column.add_theme_constant_override("separation", 8)
	column.add_child(_title)
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		var row := SaveSlotRow.new(slot)
		row.picked.connect(_on_picked)
		row.delete_requested.connect(_on_delete_requested)
		_rows.append(row)
		column.add_child(row)
	_message.name = "message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.custom_minimum_size.y = MESSAGE_HEIGHT
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_message)
	_back.name = "back"
	_back.set_meta(UiSounds.SOUND_META, &"ui_back")
	_back.pressed.connect(close)
	column.add_child(_back)
	_confirm.name = "ask_dialog"
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _confirm.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play(&"ui_back")
		close()


## Opens the list; SAVE mode writes `state` into the slot the player picks.
func open(mode: Mode, state: GameState = null) -> void:
	if not visible:
		_focus_before = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	_mode = mode
	_state = state
	if not _map_read:
		_map_read = true
		_map = MapData.load_file()
	_title.text = tr("SAVES_TITLE_SAVE") if mode == Mode.SAVE else tr("SAVES_TITLE_LOAD")
	_back.text = tr("UI_BACK")
	_refresh()
	_show_message(_hint())
	visible = true
	_focus_start()


## Gives focus back to where it was; the caller may then move it to its own entry.
func close() -> void:
	if not visible:
		return
	visible = false
	_confirm.visible = false
	_confirmed_action = Callable()
	_state = null
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()


func _refresh() -> void:
	for row: SaveSlotRow in _rows:
		row.show_slot(_map)
		row.set_pickable(_can_pick(row))
	_link_focus()


func _can_pick(row: SaveSlotRow) -> bool:
	if _mode == Mode.SAVE:
		return _state != null and row.slot != SaveGames.AUTOSAVE
	return row.status in [SaveGames.Status.INTACT, SaveGames.Status.RECOVERED]


## Up and down run along the rows that can be picked and along the delete buttons, both
## ending at the back button; left and right lead between a row and its delete button.
func _link_focus() -> void:
	var picks: Array[Control] = []
	var deletes: Array[Control] = []
	var first: Control = null
	for row: SaveSlotRow in _rows:
		var in_row: Array[Control] = []
		if row.is_pickable():
			picks.append(row.button)
			in_row.append(row.button)
		if row.delete.visible:
			deletes.append(row.delete)
			in_row.append(row.delete)
		for control: Control in [row.button, row.delete]:
			control.focus_previous = NodePath()
			FocusTrap.pin(control, [SIDE_LEFT, SIDE_RIGHT])
		if in_row.size() == 2:
			row.button.focus_neighbor_right = row.button.get_path_to(row.delete)
			row.delete.focus_neighbor_left = row.delete.get_path_to(row.button)
		if first == null and not in_row.is_empty():
			first = in_row[0]
	FocusTrap.pin(_back, [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM])
	_back.focus_previous = NodePath()
	# The rows last: up from the back button leads to a row rather than a delete button.
	for column: Array[Control] in [deletes, picks]:
		if not column.is_empty():
			column.append(_back)
			FocusTrap.link_column(column)
	FocusTrap.ring(first if first != null else _back, _back)


## LOAD starts on the newest save that can be loaded, SAVE on the first manual slot.
func _focus_start() -> void:
	var row := _row(SaveGames.SLOTS[0] if _mode == Mode.SAVE else SaveGames.latest())
	if row != null and row.is_pickable():
		row.button.grab_focus()
	else:
		_back.grab_focus()


## What the line under the list says while nothing has happened yet.
func _hint() -> String:
	if _mode == Mode.SAVE:
		return tr("SAVES_AUTOSAVE_NOTE")
	for row: SaveSlotRow in _rows:
		if row.is_pickable():
			return ""
	return tr("SAVES_NONE")


func _show_message(text: String, color: Color = CampaignStyle.MUTED) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _row(slot: String) -> SaveSlotRow:
	for row: SaveSlotRow in _rows:
		if row.slot == slot:
			return row
	return null


## The question about a slot, with what it holds on a second line.
func _question(text_key: String, row: SaveSlotRow) -> String:
	var question := tr(text_key) % SaveSlotRow.slot_name(row.slot)
	if not row.header.is_empty():
		question += "\n" + SaveSlotRow.game_date(row.header)
	return question


func _ask(question: String, confirm_text: String, action: Callable) -> void:
	_confirmed_action = action
	_confirm.ask(question, confirm_text)


func _write(slot: String) -> void:
	var error := SaveGames.write(_state, slot)
	_refresh()
	if error != OK:
		_show_message(tr("SAVES_WRITE_FAILED") % error_string(error), CampaignStyle.BAD)
		return
	_show_message(tr("SAVES_SAVED") % SaveSlotRow.slot_name(slot), CampaignStyle.GOOD)
	UiMotion.pulse(_row(slot).button, CampaignStyle.GOOD)
	Audio.play(&"ui_save")
	saved.emit(slot)


func _delete(slot: String) -> void:
	var error := SaveGames.remove(slot)
	_refresh()
	if error != OK:
		_show_message(tr("SAVES_DELETE_FAILED") % error_string(error), CampaignStyle.BAD)
	else:
		_show_message(tr("SAVES_DELETED") % SaveSlotRow.slot_name(slot))
	# The delete button that had the focus is gone with the save.
	var row := _row(slot)
	if row.delete.visible:
		row.delete.grab_focus()
	elif row.is_pickable():
		row.button.grab_focus()
	else:
		_focus_start()


func _on_picked(slot: String) -> void:
	var row := _row(slot)
	if _mode == Mode.LOAD:
		close()
		load_requested.emit(slot)
	elif row.status == SaveGames.Status.EMPTY:
		_write(slot)
	else:
		_ask(_question("SAVES_ASK_OVERWRITE", row), tr("SAVES_OVERWRITE"), _write.bind(slot))


func _on_delete_requested(slot: String) -> void:
	_ask(_question("SAVES_ASK_DELETE", _row(slot)), tr("SAVES_DELETE"), _delete.bind(slot))


func _on_confirmed() -> void:
	var action := _confirmed_action
	_confirmed_action = Callable()
	if action.is_valid():
		action.call()
