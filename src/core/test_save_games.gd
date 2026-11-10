extends GutTest
## Saving and continuing a campaign: autosave and slots on disk, the header for the load
## screen, the newest save for "Weiterspielen", and a resumed session that plays on exactly.
## A write never costs the save before it: it fails cleanly, keeps a backup, and a damaged
## slot falls back to that backup — told by its status, without an error in the log.

const FOLDER := "user://test_saves"
const SLOT := "slot_2"

var _folder := ""
var _rules: GameRules


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_folder = SaveGames.folder
	SaveGames.folder = FOLDER
	_empty_folder()


func after_each() -> void:
	_empty_folder()
	DirAccess.remove_absolute(FOLDER)
	SaveGames.folder = _folder


func test_a_saved_campaign_loads_back_exactly() -> void:
	var session := _session()
	assert_eq(SaveGames.write(session.state, "slot_2"), OK)
	var loaded := SaveGames.read("slot_2")
	assert_not_null(loaded)
	assert_eq(loaded.checksum(), session.state.checksum())
	var head := SaveGames.header("slot_2")
	assert_eq(head["turn"], session.state.turn)
	assert_eq(head["humans"], ["welfen"])
	assert_eq(head["game_version"], ProjectSettings.get_setting("application/config/version"))
	assert_eq(SaveGames.status("slot_2"), SaveGames.Status.INTACT)
	assert_eq(SaveGames.status("slot_1"), SaveGames.Status.EMPTY)
	assert_eq(SaveGames.header("slot_1"), {})


func test_continue_picks_the_newest_save() -> void:
	assert_eq(SaveGames.latest(), "", "nothing saved yet")
	var session := _session()
	SaveGames.write(session.state, "slot_1")
	OS.delay_msec(1100)
	SaveGames.write(session.state, SaveGames.AUTOSAVE)
	assert_eq(SaveGames.latest(), SaveGames.AUTOSAVE)


func test_a_resumed_session_plays_on_like_the_original() -> void:
	var original := _session()
	SaveGames.write(original.state, SaveGames.AUTOSAVE)
	var resumed := CampaignSession.resume(GameRules.load_files(), SaveGames.read(SaveGames.AUTOSAVE))
	assert_eq(resumed.humans, ["welfen"] as Array[String])
	for session: CampaignSession in [original, resumed]:
		for _i: int in 6:
			session.execute(EndPhaseCommand.new(session.rules, session.active_house()))
	assert_eq(resumed.state.checksum(), original.state.checksum())


func test_broken_or_missing_saves_read_as_nothing() -> void:
	assert_null(SaveGames.read("slot_3"))
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(SaveGames.path("slot_3"), FileAccess.WRITE)
	file.store_var("not a save")
	file = null
	assert_eq(SaveGames.status("slot_3"), SaveGames.Status.BROKEN)
	assert_eq(SaveGames.header("slot_3"), {})
	assert_false(SaveGames.is_loadable("slot_3"))
	assert_eq(SaveGames.latest(), "")
	assert_push_error_count(0, "asking what a slot holds logs nothing")
	assert_null(SaveGames.read("slot_3"))
	assert_push_error("not a save file")


func test_a_write_keeps_the_save_before_as_the_backup() -> void:
	var first := _state(1)
	var second := _state(2)
	assert_eq(SaveGames.write(first, SLOT), OK)
	assert_false(FileAccess.file_exists(SaveGames.backup_path(SLOT)), "nothing to keep yet")
	assert_eq(SaveGames.write(second, SLOT), OK)
	assert_eq(SaveGames.read(SLOT).checksum(), second.checksum())
	var backup := SaveFile.load_file(SaveGames.backup_path(SLOT))
	assert_eq(backup.kind, SaveFile.Kind.VALID)
	assert_eq(backup.header["turn"], 1)
	assert_false(FileAccess.file_exists(SaveGames.temporary_path(SLOT)), "nothing left behind")
	assert_eq(_files(), ["slot_2.bak", "slot_2.sav"])


func test_a_write_that_cannot_build_its_file_leaves_the_save_untouched() -> void:
	var first := _state(1)
	SaveGames.write(first, SLOT)
	var before := FileAccess.get_file_as_bytes(SaveGames.path(SLOT))
	_block(SaveGames.temporary_path(SLOT))
	assert_ne(SaveGames.write(_state(2), SLOT), OK, "the error is reported")
	assert_eq(FileAccess.get_file_as_bytes(SaveGames.path(SLOT)), before)
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.INTACT)
	assert_eq(SaveGames.read(SLOT).checksum(), first.checksum())
	assert_eq(SaveGames.write(_state(2), "slot_3"), OK, "another slot is not affected")
	assert_eq(SaveGames.status("slot_3"), SaveGames.Status.INTACT)


func test_a_write_that_cannot_swap_its_file_in_leaves_the_save_untouched() -> void:
	var first := _state(1)
	SaveGames.write(first, SLOT)
	_block(SaveGames.backup_path(SLOT))
	assert_ne(SaveGames.write(_state(2), SLOT), OK, "the old save cannot become the backup")
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.INTACT)
	assert_eq(SaveGames.read(SLOT).checksum(), first.checksum())
	assert_false(FileAccess.file_exists(SaveGames.temporary_path(SLOT)), "the attempt is gone")


func test_a_folder_that_cannot_be_made_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	SaveFile.store(FOLDER.path_join("file"), PackedByteArray([0]))
	SaveGames.folder = FOLDER.path_join("file/saves")
	assert_ne(SaveGames.write(_state(1), SLOT), OK)
	assert_engine_error_count(1, "the engine logs the folder it could not make")
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.EMPTY)
	assert_eq(SaveGames.latest(), "")


func test_what_an_interrupted_write_left_behind_is_never_read() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var half := SaveFile.encode({"version": GameState.SAVE_VERSION}, _state(4).to_bytes())
	SaveFile.store(SaveGames.temporary_path(SLOT), half.slice(0, 100))
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.EMPTY)
	assert_null(SaveGames.read(SLOT))
	assert_eq(SaveGames.latest(), "")
	var state := _state(1)
	assert_eq(SaveGames.write(state, SLOT), OK, "the next write replaces it")
	assert_eq(SaveGames.read(SLOT).checksum(), state.checksum())
	assert_eq(_files(), ["slot_2.sav"])


func test_a_truncated_save_falls_back_to_its_backup() -> void:
	var first := _state(1)
	SaveGames.write(first, SLOT)
	SaveGames.write(_state(2), SLOT)
	_truncate(SaveGames.path(SLOT))
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.RECOVERED)
	assert_true(SaveGames.is_loadable(SLOT))
	assert_eq(SaveGames.header(SLOT)["turn"], 1, "the header is the backup's")
	assert_eq(SaveGames.latest(), SLOT)
	assert_eq(SaveGames.read(SLOT).checksum(), first.checksum())
	var third := _state(3)
	assert_eq(SaveGames.write(third, SLOT), OK)
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.INTACT)
	assert_eq(SaveGames.read(SLOT).checksum(), third.checksum())
	var backup := SaveFile.load_file(SaveGames.backup_path(SLOT))
	assert_eq(backup.header["turn"], 1, "the damaged file did not push the good backup out")


func test_a_truncated_save_without_a_backup_is_broken() -> void:
	SaveGames.write(_state(1), SLOT)
	_truncate(SaveGames.path(SLOT))
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.BROKEN)
	assert_false(SaveGames.is_loadable(SLOT))
	assert_eq(SaveGames.header(SLOT), {})
	assert_eq(SaveGames.latest(), "")
	assert_push_error_count(0)
	assert_null(SaveGames.read(SLOT))
	assert_push_error("not a save file")
	var state := _state(2)
	assert_eq(SaveGames.write(state, SLOT), OK, "a broken slot can be written again")
	assert_eq(SaveGames.read(SLOT).checksum(), state.checksum())
	assert_eq(_files(), ["slot_2.sav"], "and a damaged file is no backup worth keeping")


func test_a_write_interrupted_between_its_two_steps_reads_the_backup() -> void:
	var first := _state(1)
	SaveGames.write(first, SLOT)
	SaveGames.write(_state(2), SLOT)
	DirAccess.remove_absolute(SaveGames.path(SLOT))
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.RECOVERED)
	assert_eq(SaveGames.read(SLOT).checksum(), first.checksum())


func test_a_save_of_another_version_is_shown_but_never_offered() -> void:
	SaveGames.write(_state(1), "slot_1")
	_write_header(SLOT, {"version": GameState.SAVE_VERSION + 1, "turn": 7, "saved_unix": 9.0e12})
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.OTHER_VERSION)
	assert_false(SaveGames.is_loadable(SLOT))
	assert_eq(SaveGames.header(SLOT)["turn"], 7, "the list can still say what it is")
	assert_eq(SaveGames.latest(), "slot_1", "though it is the newest")
	SaveGames.remove("slot_1")
	assert_eq(SaveGames.latest(), "", "nothing to continue")
	assert_push_error_count(0)
	assert_null(SaveGames.read(SLOT))
	assert_push_error("is not supported")


func test_latest_copes_with_headers_of_any_kind() -> void:
	_write_header("slot_1", {"version": GameState.SAVE_VERSION, "saved_unix": "yesterday"})
	assert_eq(SaveGames.latest(), "slot_1", "a save without a time can still be continued")
	_write_header(SLOT, {"version": GameState.SAVE_VERSION, "saved_unix": [1, 2]})
	_write_header("slot_3", {"version": GameState.SAVE_VERSION, "turn": {}, "humans": 5})
	assert_true(SaveGames.latest() in SaveGames.SLOTS)
	assert_eq(SaveGames.header("slot_3")["turn"], 0)
	assert_eq(SaveGames.header("slot_3")["humans"], [])
	SaveGames.write(_state(1), SaveGames.AUTOSAVE)
	assert_eq(SaveGames.latest(), SaveGames.AUTOSAVE, "one with a time is newer than those")
	_truncate(SaveGames.path(SaveGames.AUTOSAVE))
	assert_true(SaveGames.latest() in SaveGames.SLOTS, "a broken save is not the newest")


func test_remove_also_removes_the_backup_and_leftovers() -> void:
	SaveGames.write(_state(1), SLOT)
	SaveGames.write(_state(2), SLOT)
	SaveFile.store(SaveGames.temporary_path(SLOT), PackedByteArray([1, 2, 3]))
	assert_eq(_files().size(), 3)
	assert_eq(SaveGames.remove(SLOT), OK)
	assert_eq(_files(), [])
	assert_eq(SaveGames.status(SLOT), SaveGames.Status.EMPTY)
	assert_eq(SaveGames.remove(SLOT), OK, "removing nothing is no error")


func _session() -> CampaignSession:
	var humans: Array[String] = ["welfen"]
	var computers: Dictionary[String, Array] = {}
	for house: String in ["wettiner", "staufer", "wittelsbacher"]:
		computers[house] = ["builder", 1]
	return CampaignSession.create(_rules, humans, 9, computers)


## A campaign in the given round; states of different rounds differ.
func _state(turn: int) -> GameState:
	var state := GameSetup.create(_rules.map, _rules.economy, 9)
	state.turn = turn
	return state


## A save file with this header and a real state.
func _write_header(slot: String, header: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	SaveFile.store(SaveGames.path(slot), SaveFile.encode(header, _state(0).to_bytes()))


func _truncate(file_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(file_path)
	SaveFile.store(file_path, data.slice(0, data.size() >> 1))


## Puts a folder that cannot be replaced where a file is to be written.
func _block(file_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(file_path)
	SaveFile.store(file_path.path_join("keep"), PackedByteArray([0]))


func _files() -> Array[String]:
	var files: Array[String] = []
	files.assign(DirAccess.get_files_at(FOLDER))
	files.sort()
	return files


func _empty_folder(folder: String = FOLDER) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_empty_folder(folder.path_join(sub))
		DirAccess.remove_absolute(folder.path_join(sub))
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
