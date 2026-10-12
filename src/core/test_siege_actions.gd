extends GutTest
## The besieger's options each round: storm or bombard once, the trebuchet's damage stays, fire
## pots wear the garrison down, and a breach storms at once without the wall's bonus.

var _rules: GameRules
var _state: GameState
var _army: ArmyState


func before_each() -> void:
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	_state.phase = GameState.Phase.CAMPAIGN
	_state.active_index = _state.turn_order.find("staufer")
	# Aachen: a neutral castle of level 3 next to nobody's army.
	_army = _state.add_army("staufer", "AAC")
	for unit: String in ["knights", "knights", "spearmen", "trebuchet"]:
		_army.add_company(unit)


func test_a_besieger_acts_once_a_round() -> void:
	_rules.adventure_resolver = func(_setup: RefCounted) -> RefCounted:
		return _bombardment(false, 0.2, 0.0)
	assert_eq(TrebuchetCommand.new(_rules, "staufer", _army.id).execute(_state), "")
	var storm := StormCommand.new(_rules, "staufer", _army.id)
	assert_eq(storm.validate(_state), StormCommand.ERROR_SIEGE_DONE)
	_state.turn += 1
	assert_eq(storm.validate(_state), "", "next round the army may storm")


func test_the_storm_offers_its_battle_behind_the_walls() -> void:
	var setup := StormCommand.new(_rules, "staufer", _army.id).battle_setup(_state)
	assert_eq(setup.defender_wall, Garrisons.wall(_state, _rules, "AAC"))
	assert_eq(setup.attacker.company_count(), 4)


func test_bombarding_needs_a_trebuchet() -> void:
	_army.remove_company(3)
	assert_eq(
		TrebuchetCommand.new(_rules, "staufer", _army.id).validate(_state),
		TrebuchetCommand.ERROR_NO_TREBUCHET
	)


func test_wall_damage_and_burnt_garrison_stay_without_a_breach() -> void:
	_rules.adventure_resolver = func(setup: RefCounted) -> RefCounted:
		assert_true(setup is TrebuchetSetup)
		assert_eq((setup as TrebuchetSetup).wall_level, 3)
		return _bombardment(false, 0.4, 0.16)
	var bombard := TrebuchetCommand.new(_rules, "staufer", _army.id)
	assert_eq(bombard.execute(_state), "")
	var province := _state.provinces["AAC"]
	assert_almost_eq(province.wall_damage, 0.4, 1e-9)
	assert_almost_eq(province.garrison_health, 0.84, 1e-9)
	assert_eq(province.owner, "neutral", "no breach, no storm")
	assert_eq(_army.siege_turn, _state.turn)


func test_a_breach_storms_at_once_without_the_wall() -> void:
	var walls: Array[int] = []
	_rules.adventure_resolver = func(_setup: RefCounted) -> RefCounted:
		return _bombardment(true, 0.7, 0.0)
	_rules.resolver = func(setup: BattleSetup) -> BattleResult:
		walls.append(setup.defender_wall)
		return _battle(setup, true)
	var bombard := TrebuchetCommand.new(_rules, "staufer", _army.id)
	var storm := bombard.storm_setup(_state, _bombardment(true, 0.7, 0.0))
	assert_eq(storm.defender_wall, 0, "the breach takes the wall's bonus away")
	assert_eq(bombard.execute(_state), "")
	assert_eq(walls, [0] as Array[int])
	assert_eq(_state.provinces["AAC"].owner, "staufer")


func test_the_computer_crew_bombards_when_nobody_plays_live() -> void:
	assert_eq(TrebuchetCommand.new(_rules, "staufer", _army.id).execute(_state), "")
	var province := _state.provinces["AAC"]
	assert_true(province.wall_damage > 0.0 or province.owner == "staufer", "the crew hit")


func _bombardment(breach: bool, wall: float, garrison: float) -> TrebuchetResult:
	var result := TrebuchetResult.new()
	result.breach = breach
	result.wall_damage = wall
	result.garrison_damage = garrison
	return result


func _battle(setup: BattleSetup, attacker_wins: bool) -> BattleResult:
	var result := BattleResult.new()
	result.attacker_won = attacker_wins
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(1.0)
	for i: int in setup.defender.company_count():
		result.defender_health.append(0.0 if attacker_wins else 1.0)
	return result
