extends GutTest
## Castle raids in the campaign: the leader reaches castles in or next to his army's province,
## each target does what the GDD says, failure means captivity or a wound, church land risks the
## ban, and the hostage card's rescue raids the strongest rival's dungeon.

var _rules: GameRules
var _state: GameState


func before_each() -> void:
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	_state.phase = GameState.Phase.CAMPAIGN
	_state.active_index = _state.turn_order.find("welfen")
	# The Welfen leader rides into Alsace, next to Trifels (Staufer, castle 3, true regalia).
	_state.army(_state.houses["welfen"].leader_army).province = "ELS"


func test_the_leader_reaches_castles_next_to_his_army() -> void:
	assert_true("SPT" in CastleRaids.castles(_state, _rules, "welfen"))
	assert_false("BSW" in CastleRaids.castles(_state, _rules, "welfen"), "never his own")
	var targets := CastleRaids.targets(_state, "SPT")
	assert_eq(targets, ["treasury", "granary", "regalia"] as Array[String])
	_state.houses["wettiner"].leader_captor = "staufer"
	assert_true("dungeon" in CastleRaids.targets(_state, "SPT"), "a prisoner waits")
	var far := CastleRaidCommand.new(_rules, "welfen", "SWB", "treasury")
	assert_eq(far.validate(_state), CastleRaidCommand.ERROR_NO_CASTLE)


func test_plundering_the_treasury() -> void:
	_raid("SPT", "treasury", _success())
	assert_eq(_state.houses["staufer"].gold, 160.0, "a fifth of 200")
	var welfen := _state.houses["welfen"]
	assert_eq(welfen.gold, 240.0)
	assert_eq(welfen.pending_prestige, 3.0)
	assert_eq(welfen.wins["blade"], 1)
	assert_eq(welfen.adventure_turn, _state.turn)


func test_stealing_the_true_regalia() -> void:
	_raid("SPT", "regalia", _success())
	assert_eq(_state.crown.regalia_province, "BSW", "into the raider's home castle")
	assert_true(CrownRules.holds_true_regalia(_state, "welfen"))
	assert_eq(_state.houses["welfen"].pending_prestige, 10.0)


func test_burning_the_granary_and_opening_the_dungeon() -> void:
	_raid("SPT", "granary", _success())
	assert_almost_eq(_state.houses["staufer"].grain, 210.0, 1e-9)
	_state.houses["welfen"].adventure_turn = -1
	_state.houses["wettiner"].leader_captor = "staufer"
	_raid("SPT", "dungeon", _success())
	assert_false(_state.houses["wettiner"].is_leader_captured())


func test_a_failed_raid_ends_in_captivity_or_a_wound() -> void:
	var captured := RaidResult.new()
	captured.outcome = RaidResult.Outcome.CAPTURED
	_raid("SPT", "treasury", captured)
	assert_eq(_state.houses["welfen"].leader_captor, "staufer")
	before_each()
	var wounded := RaidResult.new()
	wounded.outcome = RaidResult.Outcome.ESCAPED_WOUNDED
	_raid("SPT", "treasury", wounded)
	assert_eq(_state.houses["welfen"].wounded_until, _state.turn + 2)
	assert_eq(_state.houses["staufer"].gold, 200.0)


func test_raiding_church_land_risks_the_ban() -> void:
	_state.provinces["OSN"].castle_level = 1
	_state.provinces["OSN"].owner = "staufer"
	_state.army(_state.houses["welfen"].leader_army).province = "BSW"
	_rules.map.crown.ban_raid_church_chance = 1.0
	_raid("OSN", "treasury", _success())
	assert_true(_state.houses["welfen"].is_banned)


func test_one_adventure_a_round() -> void:
	_raid("SPT", "treasury", _success())
	var again := CastleRaidCommand.new(_rules, "welfen", "SPT", "granary")
	assert_eq(again.validate(_state), Adventures.ERROR_DONE)


func test_the_hostage_rescue_raids_the_strongest_rivals_dungeon() -> void:
	_state.houses["wittelsbacher"].prestige = 40.0
	assert_eq(Adventures.hostage_castle(_state, "welfen"), "BAY")
	_state.phase = GameState.Phase.EVENT
	_state.events.drawn.assign([EventState.EventCard.create("hostage", "welfen", "")])
	_state.events.pending = 1
	_rules.adventure_resolver = func(setup: RefCounted) -> RefCounted:
		assert_eq((setup as RaidSetup).target, CastleRaids.DUNGEON)
		assert_eq((setup as RaidSetup).defender_owner, "wittelsbacher")
		return _success()
	assert_eq(ChooseEventCommand.new(_rules, "welfen", "raid").execute(_state), "")
	assert_true(_state.events.drawn[0].won)


func test_the_computer_raids_when_nobody_plays_live() -> void:
	var command := CastleRaidCommand.new(_rules, "welfen", "SPT", "treasury")
	assert_true(command.adventure_setup(_state) is RaidSetup)
	assert_eq(command.execute(_state), "")
	assert_eq(_state.houses["welfen"].adventure_turn, _state.turn)


func _raid(province: String, target: String, result: RaidResult) -> void:
	result.target = target
	_rules.adventure_resolver = func(_setup: RefCounted) -> RefCounted: return result
	var command := CastleRaidCommand.new(_rules, "welfen", province, target)
	assert_eq(command.execute(_state), "", "%s %s" % [province, target])
	_rules.adventure_resolver = Callable()


func _success() -> RaidResult:
	var result := RaidResult.new()
	result.success = true
	result.outcome = RaidResult.Outcome.SUCCESS
	return result
