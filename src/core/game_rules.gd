class_name GameRules
extends RefCounted
## Static data and the battle resolver of a running game; rebuilt on load, never saved.

var map: MapData
var economy: EconomyConfig
var combat: CombatConfig
var events: EventData
## Takes a BattleSetup and returns a BattleResult; the real-time battle plugs in here.
## While empty, or when it returns null, battles are auto-resolved with state.rng.
var resolver: Callable = Callable()


static func load_files() -> GameRules:
	var rules := GameRules.new()
	rules.map = MapData.load_file()
	rules.economy = EconomyConfig.load_file()
	rules.combat = CombatConfig.load_file()
	rules.events = EventData.load_file()
	if rules.map == null or rules.economy == null or rules.combat == null or rules.events == null:
		return null
	return rules


func resolve_battle(state: GameState, setup: BattleSetup) -> BattleResult:
	if not resolver.is_valid():
		return AutoResolve.resolve(combat, setup, state.rng)
	var result: BattleResult = resolver.call(setup)
	if result == null:
		return AutoResolve.resolve(combat, setup, state.rng)
	if (
		result.attacker_health.size() != setup.attacker.company_count()
		or result.defender_health.size() != setup.defender.company_count()
	):
		push_error("battle resolver returned no result matching the setup; auto-resolving")
		return AutoResolve.resolve(combat, setup, state.rng)
	return result
