extends GutTest
## The campaign scene and its autosave: every round a human plays is saved once, and a
## campaign continued from an older slot leaves a newer autosave alone until its next round.

const SCENE := "res://src/render/campaign/campaign_main.tscn"
const SAVES := "user://test_campaign_saves"
const HUMANS: Array[String] = ["welfen"]
const SEED := 1198

var _saves_before := ""


func before_each() -> void:
	_saves_before = SaveGames.folder
	SaveGames.folder = SAVES


func after_each() -> void:
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)
	DirAccess.remove_absolute(SAVES)
	SaveGames.folder = _saves_before


func test_a_resumed_campaign_keeps_a_newer_autosave_until_its_next_round() -> void:
	var scene := _open()
	scene.call("start", HUMANS, SEED)
	assert_eq(_autosaved_round(), 0, "the first round is saved as it begins")
	assert_eq(scene.call("save_to", "slot_1"), OK)
	_play_to_round(scene, 2)
	assert_eq(_autosaved_round(), 2)
	scene.free()
	var resumed := _open("slot_1")
	assert_eq(_session(resumed).state.turn, 0, "the older save is running")
	_dismiss_screens(resumed)
	resumed.call("_after_change")
	assert_eq(_autosaved_round(), 2, "the newer autosave is still there")
	_play_to_round(resumed, 1)
	assert_eq(_autosaved_round(), 1, "the next round is saved again")
	var saved := SaveGames.read(SaveGames.AUTOSAVE)
	assert_eq(saved.checksum(), _session(resumed).state.checksum())


func _open(launch_slot: String = "") -> Node:
	var scene := (load(SCENE) as PackedScene).instantiate()
	scene.set("launch_slot", launch_slot)
	add_child_autofree(scene)
	return scene


## The round the autosave was made in; -1 without one.
func _autosaved_round() -> int:
	return SaveGames.header(SaveGames.AUTOSAVE).get("turn", -1)


## Ends the human's phases until the round begins and its report is closed.
func _play_to_round(scene: Node, turn: int) -> void:
	var session := _session(scene)
	var guard := 0
	while session.state.turn < turn and guard < 100:
		guard += 1
		_dismiss_screens(scene)
		scene.call("execute", EndPhaseCommand.new(session.rules, session.active_house()))
	_dismiss_screens(scene)


func _session(scene: Node) -> CampaignSession:
	return scene.get("session")


## Closes report and handover as a player would; the event dialog is only hidden, since the
## test ends event phases with EndPhaseCommand (default choices).
func _dismiss_screens(scene: Node) -> void:
	for screen_name: String in ["_report", "_handover", "_events"]:
		var screen: Control = scene.get(screen_name)
		while screen.visible:
			screen.visible = false
			if screen is SettlementReport:
				(screen as SettlementReport).closed.emit()
			elif screen is HandoverScreen:
				(screen as HandoverScreen).confirmed.emit()
