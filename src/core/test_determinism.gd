extends GutTest
## A full game of 48 rounds through the turn loop, with the same seed and the same scripted
## commands (moves, battles, sieges, building, recruiting, trading), must end in the same
## state; this guards replays, saves and async online play.

const SEED := 1198

var _rules: GameRules
var _battles := 0


func before_all() -> void:
	_rules = GameRules.load_files()


func test_same_seed_and_commands_give_same_state() -> void:
	var first := _play(SEED)
	var second := _play(SEED)
	assert_true(first.is_over())
	assert_eq(first.turn, _rules.map.campaign.max_rounds)
	assert_eq(first.checksum(), second.checksum())


func test_different_seed_gives_different_state() -> void:
	assert_ne(_play(SEED).checksum(), _play(SEED + 1).checksum())


func test_scripted_game_fights_and_conquers() -> void:
	_battles = 0
	var state := _play(SEED)
	assert_gt(_battles, 0)
	var conquered := 0
	for province: ProvinceState in state.provinces.values():
		if province.owner != _rules.map.provinces[province.id].owner:
			conquered += 1
	assert_gt(conquered, 0)
	assert_false(state.winner.is_empty())


func _play(seed_value: int) -> GameState:
	var state := GameSetup.create(_rules.map, _rules.economy, seed_value)
	var rules := GameRules.new()
	rules.map = _rules.map
	rules.economy = _rules.economy
	rules.combat = _rules.combat
	rules.events = _rules.events
	var combat := _rules.combat
	# Capturing `rules` itself would make a reference cycle through its resolver.
	rules.resolver = func(setup: BattleSetup) -> BattleResult:
		_battles += 1
		return AutoResolve.resolve(combat, setup, state.rng)
	# Scripted players draw from their own generator so their choices never touch state.rng.
	# Their picks depend on the data lists, so new data can end the game early; the seed is
	# chosen so the game runs all 48 rounds.
	var players := RandomNumberGenerator.new()
	players.seed = 10
	while not state.is_over():
		var house := state.active_house()
		_administrate(state, rules, house, players)
		EndPhaseCommand.new(rules, house).execute(state)
		_campaign(state, rules, house, players)
		EndPhaseCommand.new(rules, house).execute(state)
	return state


func _administrate(
	state: GameState, rules: GameRules, house: String, players: RandomNumberGenerator
) -> void:
	var cfg := rules.economy
	var owned := state.provinces_of(house)
	var buildings: Array[String] = []
	buildings.assign(cfg.buildings.keys())
	var units: Array[String] = []
	units.assign(cfg.units.keys())
	var decorations: Array[String] = []
	decorations.assign(cfg.decorations.keys())
	var rate: int = _pick(players, cfg.tax_rates)
	var ration: int = _pick(players, cfg.rations)
	var decoration: String = _pick(players, decorations)
	var commands: Array[Command] = [
		SetTaxRateCommand.new(cfg, house, rate),
		SetRationCommand.new(cfg, house, ration),
		TradeGrainCommand.new(cfg, house, players.randi_range(-150, 150)),
		PayRansomCommand.new(cfg, house),
		BuyDecorationCommand.new(cfg, house, decoration),
	]
	if not owned.is_empty():
		var site: ProvinceState = _pick(players, owned)
		var building: String = _pick(players, buildings)
		commands.append(BuildCommand.new(cfg, rules.map, house, site.id, building))
		var castle: ProvinceState = _pick(players, owned)
		commands.append(UpgradeCastleCommand.new(cfg, house, castle.id))
		for i: int in 2:
			var barracks: ProvinceState = _pick(players, owned)
			var unit: String = _pick(players, units)
			commands.append(RecruitCommand.new(cfg, rules.map, house, barracks.id, unit))
	for army: ArmyState in state.armies_of(house):
		commands.append(AssignLeaderCommand.new(rules.map.campaign, house, army.id))
	for command: Command in commands:
		command.execute(state)


func _campaign(
	state: GameState, rules: GameRules, house: String, players: RandomNumberGenerator
) -> void:
	for army: ArmyState in state.armies_of(house):
		while state.army(army.id) != null and army.moves_left > 0:
			var target: String = _pick(players, rules.map.provinces[army.province].neighbors)
			# A flood or a penance can refuse every move this round.
			if not MoveArmyCommand.new(rules, house, army.id, target).execute(state).is_empty():
				break
		if state.army(army.id) != null and players.randf() < 0.5:
			StormCommand.new(rules, house, army.id).execute(state)


func _pick(players: RandomNumberGenerator, items: Array) -> Variant:
	return items[players.randi_range(0, items.size() - 1)]
