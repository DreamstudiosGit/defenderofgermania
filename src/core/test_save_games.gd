extends GutTest
## Saving and continuing a campaign: autosave and slots on disk, the header for the load
## screen, the newest save for "Weiterspielen", and a resumed session that plays on exactly.

const FOLDER := "user://test_saves"

var _folder := ""


func before_each() -> void:
	_folder = SaveGames.folder
	SaveGames.folder = FOLDER
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)


func after_each() -> void:
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)
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
	var file := FileAccess.open(SaveGames.path("slot_3"), FileAccess.WRITE)
	file.store_var("not a save")
	file = null
	assert_null(SaveGames.read("slot_3"))
	assert_push_error("not a save file")


func _session() -> CampaignSession:
	var humans: Array[String] = ["welfen"]
	var computers: Dictionary[String, Array] = {}
	for house: String in ["wettiner", "staufer", "wittelsbacher"]:
		computers[house] = ["builder", 1]
	return CampaignSession.create(GameRules.load_files(), humans, 9, computers)
