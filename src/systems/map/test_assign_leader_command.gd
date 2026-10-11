extends GutTest

var _map: MapData
var _state: GameState
var _army: ArmyState
var _second: ArmyState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, EconomyConfig.load_file(), 1)
	_state.active_index = _state.turn_order.find("welfen")
	_state.phase = GameState.Phase.ADMINISTRATION
	_army = _state.armies_of("welfen")[0]
	_second = _state.add_army("welfen", "BSW")
	_second.add_company("levy")


func test_leader_switches_armies_within_a_province() -> void:
	assert_eq(_assign(_second.id), "")
	assert_eq(_state.houses["welfen"].leader_army, _second.id)


func test_leader_at_court_takes_an_army_in_the_home_province() -> void:
	_state.houses["welfen"].leader_army = HouseState.NO_ARMY
	_second.province = "HOL"
	assert_eq(_assign(_second.id), AssignLeaderCommand.ERROR_LEADER_UNAVAILABLE)
	assert_eq(_assign(_army.id), "")


func test_leader_in_another_province_cannot_switch() -> void:
	_second.province = "HOL"
	assert_eq(_assign(_second.id), AssignLeaderCommand.ERROR_LEADER_UNAVAILABLE)


func test_captured_leader_cannot_lead() -> void:
	_state.houses["welfen"].leader_captor = "staufer"
	_state.houses["welfen"].leader_army = HouseState.NO_ARMY
	assert_eq(_assign(_army.id), AssignLeaderCommand.ERROR_LEADER_UNAVAILABLE)


func test_leader_cannot_leave_an_army_too_big_for_a_captain() -> void:
	while _army.company_count() <= _map.campaign.army_size_captain:
		_army.add_company("levy")
	assert_eq(_assign(_second.id), AssignLeaderCommand.ERROR_ARMY_FULL)


func test_army_must_fit_under_the_leader() -> void:
	var leadership := _state.houses["welfen"].leadership
	while _second.company_count() <= _map.campaign.max_companies(true, leadership):
		_second.add_company("levy")
	assert_eq(_assign(_second.id), AssignLeaderCommand.ERROR_ARMY_FULL)


func test_only_own_armies_in_administration() -> void:
	assert_eq(_assign(_state.armies_of("staufer")[0].id), AssignLeaderCommand.ERROR_UNKNOWN_ARMY)
	_state.phase = GameState.Phase.CAMPAIGN
	assert_eq(_assign(_second.id), Command.ERROR_WRONG_PHASE)


func _assign(army_id: int) -> String:
	return AssignLeaderCommand.new(_map.campaign, "welfen", army_id).execute(_state)
