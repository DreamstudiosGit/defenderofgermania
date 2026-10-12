class_name TrebuchetCommand
extends Command
## Bombards the castle an army besieges with its trebuchets (the minigame, GDD "Blide"): the
## wall damage stays until the siege ends, fire pots wear the garrison down, and a breach lets
## the army storm at once without the wall's bonus. A besieger acts once a round.

const SIEGE_GROUP := "siege"
const ERROR_NO_TREBUCHET := "SIEGE_NO_TREBUCHET"
const ERROR_NO_WALL := "SIEGE_NO_WALL"

var army_id: int
var _rules: GameRules


func _init(rules: GameRules, house_id: String, bombarding_army: int) -> void:
	_rules = rules
	house = house_id
	army_id = bombarding_army


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.CAMPAIGN


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	var army := state.army(army_id)
	if army == null or army.owner != house:
		return StormCommand.ERROR_UNKNOWN_ARMY
	error = StormCommand.siege_error(state, _rules, army)
	if not error.is_empty():
		return error
	if trebuchets(_rules, army) == 0:
		return ERROR_NO_TREBUCHET
	return "" if Garrisons.wall(state, _rules, army.province) > 0 else ERROR_NO_WALL


## Companies of the army that are trebuchets.
static func trebuchets(rules: GameRules, army: ArmyState) -> int:
	var count := 0
	for unit: String in army.units:
		if rules.combat.units[unit].group == SIEGE_GROUP:
			count += 1
	return count


## The bombardment, for playing it live first; null if the command is refused.
func adventure_setup(state: GameState) -> RefCounted:
	return trebuchet_setup(state) if validate(state).is_empty() else null


func trebuchet_setup(state: GameState) -> TrebuchetSetup:
	var army := state.army(army_id)
	var province := state.provinces[army.province]
	var owner: HouseState = state.houses.get(province.owner)
	var setup := TrebuchetSetup.new()
	setup.attacker_house = house
	setup.defender_owner = province.owner
	setup.wall_level = Garrisons.wall(state, _rules, province.id)
	setup.is_home_castle = owner != null and owner.home_province == province.id
	setup.castle_level = province.castle_level
	setup.trebuchets = trebuchets(_rules, army)
	setup.garrison_health = province.garrison_health
	setup.wall_damage = province.wall_damage
	return setup


## The storm a breach opens, without walls and against the garrison the fire pots left; null
## without a breach or when the garrison broke.
func storm_setup(state: GameState, result: TrebuchetResult) -> BattleSetup:
	if not result.breach:
		return null
	var army := state.army(army_id)
	var province := state.provinces[army.province]
	var health := province.garrison_health
	province.garrison_health = maxf(health - result.garrison_damage, 0.0)
	var setup: BattleSetup = null
	if Garrisons.size(state, _rules, province.id) > 0:
		setup = CampaignBattles.garrison_battle(state, _rules, army, 0, province.id)
	province.garrison_health = health
	return setup


func apply(state: GameState) -> void:
	var army := state.army(army_id)
	var province := state.provinces[army.province]
	army.moves_left = 0
	army.siege_turn = state.turn
	var result := Adventures.play_trebuchet(state, _rules, trebuchet_setup(state))
	province.wall_damage = result.wall_damage
	province.garrison_health = maxf(province.garrison_health - result.garrison_damage, 0.0)
	if not result.breach or Garrisons.size(state, _rules, province.id) == 0:
		return
	if CampaignBattles.fight_garrison(state, _rules, army, 0, ""):
		Conquest.conquer(state, _rules, province.id, house, true)
