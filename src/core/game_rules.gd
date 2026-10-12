class_name GameRules
extends RefCounted
## Static data and the battle resolver of a running game; rebuilt on load, never saved.

var map: MapData
var economy: EconomyConfig
var combat: CombatConfig
var events: EventData
var merchant: MerchantConfig
var joust: JoustConfig
var siege: SiegeConfig
## Takes a BattleSetup and returns a BattleResult; the real-time battle plugs in here.
## While empty, or when it returns null, battles are auto-resolved with state.rng.
var resolver: Callable = Callable()
## Takes an adventure setup (e.g. MerchantSetup) and returns the result the player achieved
## in its minigame; while empty, or when it returns null, the computer plays the house's side.
var adventure_resolver: Callable = Callable()


static func load_files() -> GameRules:
	var rules := GameRules.new()
	rules.map = MapData.load_file()
	rules.economy = EconomyConfig.load_file()
	rules.combat = CombatConfig.load_file()
	rules.events = EventData.load_file()
	rules.merchant = MerchantConfig.load_file()
	rules.joust = JoustConfig.load_file()
	rules.siege = SiegeConfig.load_file()
	var parts: Array[Variant] = [
		rules.map, rules.economy, rules.combat, rules.events, rules.merchant, rules.joust,
		rules.siege,
	]
	for part: Variant in parts:
		if part == null:
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
