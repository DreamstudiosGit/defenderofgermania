class_name PauseMenu
extends Control
## The pause menu of every scene: resume, options, save and load (where the scene offers a
## state), the scene's own way out, back to the main menu, quit. While open it pauses the
## tree, so simulations, timers and cameras rest; it keeps running itself and dims the scene
## behind it. Esc / B closes an open sub-screen first, otherwise resumes; focus returns to
## where it was. A scene needs one line: PauseMenu.mount(self).

signal resumed
## The player picked a save to continue (only with state_source).
signal load_requested(slot: String)
## The player chose the scene's own entry (leave_text), e.g. to give up a battle.
signal leave_requested

const LAYER := 50
const DIM_ALPHA := 0.6

## Returns the GameState to save, or null while saving is not possible: () -> GameState.
## Set it to offer "save" and "load" (the campaign).
var state_source := Callable()
## Text key of the scene's own entry; empty hides it.
var leave_text := ""
## What "main menu" and "quit game" do once confirmed: App.to_main_menu and App.quit unless
## a test puts its own in.
var main_menu_action := Callable()
var quit_action := Callable()

var _title := CampaignStyle.title()
var _resume := CampaignStyle.modal_button("")
var _options_entry := CampaignStyle.modal_button("")
var _save := CampaignStyle.modal_button("")
var _save_hint := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _load := CampaignStyle.modal_button("")
var _leave := CampaignStyle.modal_button("")
var _main_menu := CampaignStyle.modal_button("")
var _quit := CampaignStyle.modal_button("")
var _options := OptionsScreen.new()
var _slots := SaveSlotsScreen.new()
var _confirm := ConfirmDialog.new()
## The panel with the entries; it steps aside while a sub-screen shows, so focus cannot
## wander to entries behind it.
var _panel: Control
var _focus_before: Control = null
## The entry that opened a sub-screen; it gets focus back.
var _origin: Button = null
var _confirmed_action := Callable()
var _opened_frame := -1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, DIM_ALPHA))
	_panel = column.get_parent()
	column.add_theme_constant_override("separation", 10)
	column.add_child(_title)
	_add_entry(column, _resume, "resume", close)
	_add_entry(column, _options_entry, "options", _on_options_pressed)
	_add_entry(column, _save, "save", _on_save_pressed)
	_save_hint.name = "save_hint"
	_save_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_save_hint)
	_add_entry(column, _load, "load", _on_load_pressed)
	_add_entry(column, _leave, "leave", _on_leave_pressed)
	_add_entry(column, _main_menu, "main_menu", _on_main_menu_pressed)
	_add_entry(column, _quit, "quit", _on_quit_pressed)
	_resume.set_meta(UiSounds.SOUND_META, &"ui_back")
	_options.name = "options_screen"
	_options.allow_language = false
	_options.closed.connect(_uncover)
	add_child(_options)
	_slots.name = "save_slots"
	_slots.closed.connect(_uncover)
	_slots.load_requested.connect(_on_load_requested)
	add_child(_slots)
	_confirm.name = "confirm_dialog"
	_confirm.cancelled.connect(_uncover)
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)
	add_child(FocusTrap.new())
	visible = false


func _exit_tree() -> void:
	# A scene that is freed with its menu open must not leave the next one frozen.
	if visible:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# The press that opened the menu can arrive here in the same frame.
	if Engine.get_process_frames() == _opened_frame:
		return
	if _options.visible:
		_options.close()
	elif _slots.visible:
		_slots.close()
	elif not _confirm.visible:
		close()


## Puts a pause menu on its own layer above the scene's screens.
static func mount(parent: Node) -> PauseMenu:
	var layer := CanvasLayer.new()
	layer.name = "pause_layer"
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var menu := PauseMenu.new()
	layer.add_child(menu)
	parent.add_child(layer)
	return menu


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	_opened_frame = Engine.get_process_frames()
	_show_entries()
	_panel.visible = true
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if _options.visible:
		_options.close()
	if _slots.visible:
		_slots.close()
	_confirm.visible = false
	_origin = null
	get_tree().paused = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null
	resumed.emit()


func _add_entry(column: Container, entry: Button, entry_name: String, action: Callable) -> void:
	entry.name = entry_name
	entry.pressed.connect(action)
	column.add_child(entry)


## Texts in the language in use and the entries the scene offers right now.
func _show_entries() -> void:
	_title.text = tr("PAUSE_TITLE")
	_resume.text = tr("PAUSE_RESUME")
	_options_entry.text = tr("PAUSE_OPTIONS")
	_save.text = tr("PAUSE_SAVE")
	_save_hint.text = tr("PAUSE_SAVE_BLOCKED")
	_load.text = tr("PAUSE_LOAD")
	_leave.text = tr(leave_text)
	_main_menu.text = tr("PAUSE_MAIN_MENU")
	_quit.text = tr("PAUSE_QUIT")
	var with_saves := state_source.is_valid()
	var can_save := with_saves and state_source.call() != null
	_save.visible = with_saves
	_save.disabled = not can_save
	_save.focus_mode = Control.FOCUS_ALL if can_save else Control.FOCUS_NONE
	_save.tooltip_text = "" if can_save else _save_hint.text
	_save_hint.visible = with_saves and not can_save
	_load.visible = with_saves
	_leave.visible = not leave_text.is_empty()
	var entries := FocusTrap.focusables(_panel)
	FocusTrap.link_column(entries, true)
	FocusTrap.ring(entries[0], entries[entries.size() - 1])
	for entry: Control in entries:
		FocusTrap.pin(entry, [SIDE_LEFT, SIDE_RIGHT])


## Hides the entries while a sub-screen opened by `origin` shows.
func _cover(origin: Button) -> void:
	_origin = origin
	_panel.visible = false


## Shows the entries again and gives focus back to the one that opened the sub-screen.
func _uncover() -> void:
	_panel.visible = true
	if visible and _origin != null:
		_origin.grab_focus()
	_origin = null


func _ask(origin: Button, question_key: String, confirm_key: String, action: Callable) -> void:
	var question := tr(question_key)
	if state_source.is_valid():
		question += "\n" + tr("PAUSE_UNSAVED")
	_confirmed_action = action
	_cover(origin)
	_confirm.ask(question, tr(confirm_key))


func _on_options_pressed() -> void:
	_cover(_options_entry)
	_options.open()


func _on_save_pressed() -> void:
	var state := state_source.call() as GameState
	if state != null:
		_cover(_save)
		_slots.open(SaveSlotsScreen.Mode.SAVE, state)


func _on_load_pressed() -> void:
	_cover(_load)
	_slots.open(SaveSlotsScreen.Mode.LOAD)


func _on_load_requested(slot: String) -> void:
	close()
	load_requested.emit(slot)


func _on_leave_pressed() -> void:
	close()
	leave_requested.emit()


func _on_main_menu_pressed() -> void:
	var action := main_menu_action if main_menu_action.is_valid() else App.to_main_menu
	_ask(_main_menu, "PAUSE_ASK_MAIN_MENU", "PAUSE_CONFIRM_MAIN_MENU", action)


func _on_quit_pressed() -> void:
	var action := quit_action if quit_action.is_valid() else App.quit
	_ask(_quit, "PAUSE_ASK_QUIT", "PAUSE_CONFIRM_QUIT", action)


## The entries come back first: should the way out fail, the menu is still usable.
func _on_confirmed() -> void:
	_uncover()
	_confirmed_action.call()
