extends GutTest
## The list of saved campaigns: its rows tell what the slots hold, LOAD passes the picked save
## on, SAVE writes (asking before it overwrites) and reports a write that failed, a used slot
## can be deleted, and every text key exists in both languages. Saves live in a folder of the
## test's own. (Keys, focus and size: test_save_slots_navigation.gd.)

const FOLDER := "user://test_save_slots"
const TEXTS := "res://data/i18n/texts.csv"
const SOURCES: Array[String] = [
	"res://src/ui/menu/save_slots_screen.gd", "res://src/ui/menu/save_slot_row.gd",
]
const ALL_HOUSES: Array[String] = ["welfen", "wettiner", "staufer", "wittelsbacher"]

var _folder := ""
var _locale := ""
var _rules: GameRules
var _screen: SaveSlotsScreen


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_folder = SaveGames.folder
	_locale = TranslationServer.get_locale()
	SaveGames.folder = FOLDER
	TranslationServer.set_locale("de")
	_empty_folder()
	_screen = add_child_autofree(SaveSlotsScreen.new())


func after_each() -> void:
	_empty_folder()
	DirAccess.remove_absolute(FOLDER)
	SaveGames.folder = _folder
	TranslationServer.set_locale(_locale)


func test_rows_tell_what_their_slots_hold() -> void:
	SaveGames.write(_state(11, ["welfen", "staufer"]), SaveGames.AUTOSAVE)
	SaveGames.write(_state(4), "slot_2")
	SaveGames.write(_state(5), "slot_2")
	_truncate(SaveGames.path("slot_2"))
	_write_header("slot_3", {"version": GameState.SAVE_VERSION + 1, "game_version": "0.1.0"})
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	assert_eq(_title(), "Spiel laden")
	var autosave := _row(SaveGames.AUTOSAVE)
	assert_eq(_text(autosave, "date"), "Runde 12 · Winter 1200")
	assert_eq(autosave.house_names(), ["Welfen", "Staufer"] as Array[String])
	var saved_at := str(SaveGames.header(SaveGames.AUTOSAVE)["saved_at"])
	assert_eq(_text(autosave, "saved"), SaveCaption.date(saved_at))
	assert_eq(_text(autosave, "status"), "", "nothing to say about a save that is fine")
	assert_true(autosave.is_pickable())
	assert_false(autosave.delete.visible, "the autosave is the game's, not the player's")
	var empty := _row("slot_1")
	assert_eq(_text(empty, "date"), "Leer")
	assert_false(empty.is_pickable())
	assert_false(empty.delete.visible)
	var recovered := _row("slot_2")
	assert_eq(_text(recovered, "status"), "Beschädigt – die Sicherung wird geladen")
	assert_eq(_text(recovered, "date"), "Runde 5 · Frühling 1199", "what the backup holds")
	assert_true(recovered.is_pickable())
	assert_true(recovered.delete.visible)
	var foreign := _row("slot_3")
	assert_eq(_text(foreign, "status"), "Aus Version 0.1.0 – kann nicht geladen werden")
	assert_false(foreign.is_pickable())
	assert_true(foreign.delete.visible, "it can still be thrown away")
	DirAccess.remove_absolute(SaveGames.backup_path("slot_2"))
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	assert_eq(_text(recovered, "date"), "Beschädigt – kann nicht geladen werden")
	assert_eq(_text(recovered, "status"), "")
	assert_false(recovered.is_pickable())
	assert_true(recovered.delete.visible)


func test_load_starts_on_the_newest_readable_save_and_passes_the_pick_on() -> void:
	_write_header("slot_1", {"version": GameState.SAVE_VERSION, "saved_unix": 100.0})
	SaveGames.write(_state(3), "slot_3")
	_write_header("slot_2", {"version": GameState.SAVE_VERSION + 1, "saved_unix": 9.0e12})
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	assert_eq(_focus(), _row("slot_3").button)
	assert_eq(_message(), "")
	watch_signals(_screen)
	_press("ui_accept")
	assert_signal_emitted_with_parameters(_screen, "load_requested", ["slot_3"])
	assert_signal_emit_count(_screen, "closed", 1)
	assert_false(_screen.visible)


func test_load_keeps_empty_and_unreadable_slots_out_of_reach() -> void:
	_write_header("slot_2", {"version": GameState.SAVE_VERSION + 1})
	SaveGames.write(_state(1), "slot_3")
	_truncate(SaveGames.path("slot_3"))
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	for row: SaveSlotRow in _rows():
		assert_true(row.button.disabled, row.slot)
		assert_eq(row.button.focus_mode, Control.FOCUS_NONE, row.slot)
	assert_eq(_focus(), _button("back"), "something visible has the focus")
	assert_eq(_message(), "Es gibt keinen Spielstand zum Laden.")
	watch_signals(_screen)
	_press("ui_accept")
	assert_signal_not_emitted(_screen, "load_requested")
	assert_signal_emit_count(_screen, "closed", 1, "back closes")


func test_save_writes_an_empty_slot_at_once() -> void:
	SaveGames.write(_state(1), SaveGames.AUTOSAVE)
	var state := _state(7)
	_screen.open(SaveSlotsScreen.Mode.SAVE, state)
	assert_eq(_title(), "Spiel speichern")
	assert_false(_row(SaveGames.AUTOSAVE).is_pickable(), "the autosave is not for the player")
	assert_eq(_focus(), _row("slot_1").button, "the first manual slot")
	assert_string_contains(_message(), "automatische")
	watch_signals(_screen)
	_press("ui_accept")
	assert_false(_dialog().visible, "nothing to lose, nothing to ask")
	assert_eq(SaveGames.read("slot_1").checksum(), state.checksum())
	assert_signal_emitted_with_parameters(_screen, "saved", ["slot_1"])
	assert_true(_screen.visible, "the list stays open")
	assert_eq(_text(_row("slot_1"), "date"), "Runde 8 · Winter 1199", "the row shows the save")
	assert_true(_row("slot_1").delete.visible)
	assert_eq(_message(), "Spielstand 1 gespeichert.")
	assert_eq(_focus(), _row("slot_1").button)


func test_save_asks_before_it_overwrites() -> void:
	var old := _state(2)
	var new := _state(9)
	SaveGames.write(old, "slot_2")
	_screen.open(SaveSlotsScreen.Mode.SAVE, new)
	watch_signals(_screen)
	_row("slot_2").button.grab_focus()
	_press("ui_accept")
	assert_true(_dialog().visible)
	assert_eq(_question(), "Spielstand 2 überschreiben?\nRunde 3 · Herbst 1198")
	assert_eq(_focus(), _dialog().find_child("cancel", true, false), "the harmless answer")
	assert_eq(SaveGames.read("slot_2").checksum(), old.checksum(), "not before the answer")
	_press("ui_accept")
	assert_false(_dialog().visible)
	assert_eq(SaveGames.read("slot_2").checksum(), old.checksum(), "cancelled")
	assert_signal_not_emitted(_screen, "saved")
	assert_eq(_focus(), _row("slot_2").button, "back on the row")
	_press("ui_accept")
	(_dialog().find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(SaveGames.read("slot_2").checksum(), new.checksum())
	assert_signal_emitted_with_parameters(_screen, "saved", ["slot_2"])
	assert_signal_emit_count(_screen, "saved", 1)
	assert_eq(_focus(), _row("slot_2").button)
	assert_eq(_text(_row("slot_2"), "date"), "Runde 10 · Sommer 1200")


func test_a_write_that_fails_says_why_and_keeps_the_list_open() -> void:
	_screen.open(SaveSlotsScreen.Mode.SAVE, _state(1))
	# A folder where the save's file is to be built: the write cannot open it.
	DirAccess.make_dir_recursive_absolute(SaveGames.temporary_path("slot_1").path_join("x"))
	watch_signals(_screen)
	_press("ui_accept")
	assert_signal_not_emitted(_screen, "saved")
	assert_true(_screen.visible)
	assert_string_starts_with(_message(), "Speichern fehlgeschlagen: ")
	assert_gt(_message().length(), "Speichern fehlgeschlagen: ".length(), "with the reason")
	assert_eq(_row("slot_1").status, SaveGames.Status.EMPTY)
	assert_eq(_focus(), _row("slot_1").button)
	_press("ui_down")
	_press("ui_accept")
	assert_signal_emitted_with_parameters(_screen, "saved", ["slot_2"])
	assert_eq(_message(), "Spielstand 2 gespeichert.", "the next save answers anew")


func test_delete_asks_first_and_removes_the_save_with_its_backup() -> void:
	SaveGames.write(_state(1), "slot_2")
	SaveGames.write(_state(2), "slot_2")
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	var row := _row("slot_2")
	row.delete.grab_focus()
	_press("ui_accept")
	assert_true(_dialog().visible)
	assert_eq(_question(), "Spielstand 2 löschen?\nRunde 3 · Herbst 1198")
	_press("ui_accept")
	assert_eq(SaveGames.status("slot_2"), SaveGames.Status.INTACT, "cancelled")
	assert_eq(_focus(), row.delete)
	_press("ui_accept")
	(_dialog().find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(SaveGames.status("slot_2"), SaveGames.Status.EMPTY)
	assert_eq(DirAccess.get_files_at(FOLDER).size(), 0, "nothing of it is left")
	assert_false(row.delete.visible)
	assert_false(row.is_pickable(), "nothing to load any more")
	assert_eq(_message(), "Spielstand 2 gelöscht.")
	assert_eq(_focus(), _button("back"), "the focus is never lost")


func test_a_deleted_slot_can_be_saved_into_right_away() -> void:
	SaveGames.write(_state(1), "slot_3")
	var state := _state(6)
	_screen.open(SaveSlotsScreen.Mode.SAVE, state)
	_row("slot_3").delete.pressed.emit()
	(_dialog().find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(_focus(), _row("slot_3").button)
	_press("ui_accept")
	assert_false(_dialog().visible, "the slot is empty now")
	assert_eq(SaveGames.read("slot_3").checksum(), state.checksum())


func test_a_row_shows_its_houses_without_the_map() -> void:
	SaveGames.write(_state(1, ["wettiner"]), "slot_1")
	var row: SaveSlotRow = add_child_autofree(SaveSlotRow.new("slot_1"))
	row.show_slot(null)
	assert_eq(row.house_names(), ["Wettiner"] as Array[String])
	assert_eq(row.status, SaveGames.Status.INTACT)


func test_every_text_key_exists_in_both_languages() -> void:
	var texts: Dictionary[String, Array] = {}
	var file := FileAccess.open(TEXTS, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			texts[line[0]] = [line[1], line[2]]
	var pattern := RegEx.create_from_string("\"(SAVES_[A-Z0-9_]*[A-Z0-9])\"")
	var used: Dictionary[String, bool] = {}
	for source: String in SOURCES:
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(source)):
			used[found.get_string(1)] = true
	assert_gt(used.size(), 15, "the list's keys were found")
	for key: String in used:
		assert_true(texts.has(key), "missing text key %s" % key)
		if texts.has(key):
			assert_false(str(texts[key][0]).is_empty() or str(texts[key][1]).is_empty(), key)
			assert_ne(tr(key), key, "%s is in the translation in use" % key)


## A campaign in the given round with these human houses.
func _state(turn: int, humans: Array[String] = ["welfen"]) -> GameState:
	var computers: Dictionary[String, Array] = {}
	for house: String in ALL_HOUSES:
		if house not in humans:
			computers[house] = ["builder", 1]
	var state := CampaignSession.create(_rules, humans, 9, computers).state
	state.turn = turn
	return state


## A save file with this header and a real state.
func _write_header(slot: String, header: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	SaveFile.store(SaveGames.path(slot), SaveFile.encode(header, _state(0).to_bytes()))


func _truncate(file_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(file_path)
	SaveFile.store(file_path, data.slice(0, data.size() >> 1))


func _rows() -> Array[SaveSlotRow]:
	var rows: Array[SaveSlotRow] = []
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		rows.append(_row(slot))
	return rows


func _row(slot: String) -> SaveSlotRow:
	return _screen.find_child(slot, true, false) as SaveSlotRow


func _text(row: SaveSlotRow, label_name: String) -> String:
	return (row.find_child(label_name, true, false) as Label).text


func _button(button_name: String) -> Button:
	return _screen.find_child(button_name, true, false) as Button


func _title() -> String:
	return (_screen.find_children("*", "Label", true, false)[0] as Label).text


func _message() -> String:
	return (_screen.find_child("message", true, false) as Label).text


func _dialog() -> ConfirmDialog:
	return _screen.find_child("ask_dialog", true, false) as ConfirmDialog


func _question() -> String:
	return (_dialog().find_children("*", "Label", true, false)[0] as Label).text


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Presses and releases an action the way a key or a controller button would.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _empty_folder(folder: String = FOLDER) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_empty_folder(folder.path_join(sub))
		DirAccess.remove_absolute(folder.path_join(sub))
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
