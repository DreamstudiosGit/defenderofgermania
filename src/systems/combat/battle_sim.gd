class_name BattleSim
extends RefCounted
## Deterministic real-time battle at a fixed tick: a BattleSetup goes in, one BattleInput per
## side and tick drives it, a BattleResult comes out. No devices, clocks or global random
## numbers; the seed only varies the figures' formation jitter.

var cfg: CombatConfig
var rules: BattleRules
var setup: BattleSetup
var state: BattleState

var _company_grid: BattleGrid
var _contacts: BattleContacts
var _damage := PackedFloat64Array()


func _init(config: CombatConfig, battle_setup: BattleSetup, seed_value: int) -> void:
	cfg = config
	rules = config.battle
	setup = battle_setup
	state = BattleDeployment.create(config, battle_setup, seed_value)
	_company_grid = BattleGrid.new(rules.field_size, rules.rally_radius)
	_contacts = BattleContacts.new(rules)
	_company_grid.rebuild(state.pos, _present_mask())


func tick_seconds() -> float:
	return 1.0 / rules.tick_rate


func is_over() -> bool:
	return state.phase == BattleState.Phase.OVER


## Seconds left in the deployment, or in the fight once it started.
func seconds_left() -> float:
	if state.phase == BattleState.Phase.DEPLOY:
		return maxf(0.0, (rules.deploy_ticks() - state.tick) * tick_seconds())
	var fought := state.fight_ticks(rules.deploy_ticks())
	return maxf(0.0, (rules.time_limit_ticks() - fought) * tick_seconds())


func step(attacker_input: BattleInput, defender_input: BattleInput) -> void:
	if is_over():
		return
	state.events.clear()
	state.tick += 1
	if state.phase == BattleState.Phase.DEPLOY and state.tick > rules.deploy_ticks():
		state.phase = BattleState.Phase.FIGHT
		state.events.append(BattleEvent.new(BattleEvent.Kind.FIGHT_START, -1))
	var dt := tick_seconds()
	BattleOrders.apply(state, rules, _company_grid, 0, attacker_input)
	BattleOrders.apply(state, rules, _company_grid, 1, defender_input)
	BattleMovement.update(state, rules, _company_grid, dt)
	_contacts.update(state, rules, dt)
	if state.phase != BattleState.Phase.FIGHT:
		return
	_damage.resize(state.company_count())
	_damage.fill(0.0)
	BattleRanged.update(state, rules, _company_grid, _damage, dt)
	BattleMelee.update(state, rules, _damage, dt)
	BattleMorale.update(state, rules, _damage, dt)
	BattleOutcome.update(state, cfg, setup)


func result() -> BattleResult:
	return BattleOutcome.result(state, setup, rules.tick_rate)


func _present_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(state.company_count())
	for c: int in state.company_count():
		mask[c] = 1 if state.is_present(c) else 0
	return mask
