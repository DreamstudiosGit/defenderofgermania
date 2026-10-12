class_name MerchantSim
extends RefCounted
## Deterministic merchant train raid at the battle's fixed tick (data/combat.json
## battle.tick_rate): a MerchantSetup goes in, one MerchantInput per tick drives the leader, a
## MerchantResult comes out. Escorts and ambushing companies follow fixed patterns. The seed
## only sets the cargo values, the escorts' posts and the phase of the crossbow's sway — all
## visible before they matter. No devices, clocks or global random numbers.

## Arrival tolerance against rounding of the wagon positions.
const GATE_EPSILON := 0.000001

var cfg: MerchantConfig
var combat: CombatConfig
var setup: MerchantSetup
var escort: MerchantConfig.EscortSkill
var state := MerchantState.new()
var tick_rate: int


func _init(
	config: MerchantConfig, combat_config: CombatConfig, raid_setup: MerchantSetup,
	seed_value: int
) -> void:
	cfg = config
	combat = combat_config
	for problem: String in raid_setup.errors(config, combat_config):
		push_error("merchant raid: %s" % problem)
	setup = raid_setup.playable(config, combat_config)
	escort = config.escort_skill(setup.escort_skill)
	tick_rate = combat_config.battle.tick_rate
	_deploy(seed_value)


func tick_seconds() -> float:
	return 1.0 / tick_rate


func intro_ticks() -> int:
	return roundi(cfg.intro_seconds * tick_rate)


func is_over() -> bool:
	return state.phase == MerchantState.Phase.OVER


func raid_seconds() -> float:
	return state.raid_ticks * tick_seconds()


## Seconds until the rear wagon reaches the gate, or of the intro while it runs.
func seconds_left() -> float:
	if state.phase == MerchantState.Phase.INTRO:
		return maxf(0.0, (intro_ticks() - state.tick) * tick_seconds())
	return maxf(0.0, cfg.train_seconds - raid_seconds())


func step(input: MerchantInput) -> void:
	if is_over():
		return
	state.events.clear()
	state.tick += 1
	if state.phase == MerchantState.Phase.INTRO:
		if state.tick >= intro_ticks():
			state.phase = MerchantState.Phase.RAID
			state.events.append(MerchantEvent.new(MerchantEvent.Kind.RAID_START))
		return
	state.raid_ticks += 1
	var dt := tick_seconds()
	_roll_wagons()
	MerchantLeader.update(self, input if input != null else MerchantInput.new(), dt)
	MerchantEscorts.update(self, dt)
	MerchantCompanies.update(self, dt)
	if state.captured or state.count_wagons(MerchantState.Wagon.ROLLING) == 0:
		state.phase = MerchantState.Phase.OVER
		state.events.append(MerchantEvent.new(MerchantEvent.Kind.OVER))


func result() -> MerchantResult:
	var outcome := MerchantResult.new()
	outcome.wagons_total = state.wagon_count()
	outcome.wagons_stopped = state.count_wagons(MerchantState.Wagon.STOPPED)
	outcome.leader_captured = state.captured
	outcome.taler = 0 if state.captured else state.loot()
	outcome.seconds = raid_seconds()
	return outcome


func box_x(w: int) -> float:
	return state.wagon_x[w] + cfg.box_ahead


func horses_x(w: int) -> float:
	return state.wagon_x[w] + cfg.horses_ahead


## The crossbow's aim swings in a fixed, visible rhythm; riding fast swings it wider.
## A bolt cuts the harness while |sway| <= hit_window.
func sway() -> float:
	var riding := clampf(absf(state.leader_velocity) / cfg.leader_speed, 0.0, 1.0)
	var amplitude := lerpf(cfg.sway_still, cfg.sway_riding, riding)
	return amplitude * sin(TAU * raid_seconds() / cfg.sway_period + state.sway_phase)


## The rolling wagon whose horses stand in the crossbow's range ahead of the leader, or -1.
func crossbow_target() -> int:
	var best := -1
	var best_distance := INF
	for w: int in state.wagon_count():
		if not state.is_rolling(w):
			continue
		var distance := (horses_x(w) - state.leader_x) * state.leader_facing
		if distance >= cfg.range_min and distance <= cfg.range_max and distance < best_distance:
			best = w
			best_distance = distance
	return best


## The rolling wagon whose driver sits within the leader's reach, or -1.
func pull_target() -> int:
	var best := -1
	var best_distance := cfg.pull_reach
	for w: int in state.wagon_count():
		var distance := absf(box_x(w) - state.leader_x)
		if state.is_rolling(w) and distance <= best_distance:
			best = w
			best_distance = distance
	return best


## Seconds a parry stays open: the data's base plus the blade's share (data/combat.json).
func parry_window() -> float:
	return (cfg.parry_window_ms + combat.parry_window_per_blade_ms * setup.blade) / 1000.0


## Escorts notice raiders this far; once a wagon stopped, the alarm widens it.
func notice_range() -> float:
	var alarmed := state.count_wagons(MerchantState.Wagon.STOPPED) > 0
	return escort.notice_range * (cfg.alarm_notice_factor if alarmed else 1.0)


func strike_power() -> float:
	return cfg.strike_damage * (1.0 + combat.damage_per_blade * setup.blade)


func stop_wagon(w: int, how: MerchantState.Stop, raider: int) -> void:
	if state.count_wagons(MerchantState.Wagon.STOPPED) == 0:
		state.events.append(MerchantEvent.new(MerchantEvent.Kind.ALARM, w))
	state.wagon_status[w] = MerchantState.Wagon.STOPPED
	state.wagon_stop[w] = how
	state.wagon_raider[w] = raider
	var kind := (
		MerchantEvent.Kind.DRIVER_PULLED if how == MerchantState.Stop.DRIVER
		else MerchantEvent.Kind.HARNESS_CUT
	)
	state.events.append(MerchantEvent.new(kind, w, -1, raider))


func _roll_wagons() -> void:
	var travelled := cfg.wagon_speed * raid_seconds()
	for w: int in state.wagon_count():
		if not state.is_rolling(w):
			continue
		state.wagon_x[w] = cfg.wagon_start(w) + travelled
		if state.wagon_x[w] >= state.gate_x - GATE_EPSILON:
			state.wagon_status[w] = MerchantState.Wagon.ARRIVED
			state.events.append(MerchantEvent.new(MerchantEvent.Kind.WAGON_ARRIVED, w))


func _deploy(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state.gate_x = cfg.gate_x()
	for w: int in cfg.wagons:
		state.wagon_x.append(cfg.wagon_start(w))
		state.wagon_status.append(MerchantState.Wagon.ROLLING)
		state.wagon_stop.append(MerchantState.Stop.NONE)
		state.wagon_raider.append(MerchantState.LEADER)
		state.wagon_value.append(rng.randi_range(cfg.cargo_min, cfg.cargo_max))
	state.leader_x = cfg.leader_start()
	state.composure = cfg.composure
	state.bolts = cfg.bolts
	state.sway_phase = rng.randf() * TAU
	var count := setup.escort_count
	for e: int in count:
		var post := floori((e + 0.5) * cfg.wagons / count)
		var offset := cfg.box_ahead + rng.randf_range(-cfg.post_jitter, cfg.post_jitter)
		state.escort_x.append(cfg.wagon_start(post) + offset)
		state.escort_state.append(MerchantState.Escort.PATROL)
		state.escort_timer.append(0.0)
		state.escort_guard.append(escort.guard)
		state.escort_post.append(post)
		state.escort_post_offset.append(offset)
		state.escort_target.append(MerchantState.LEADER)
	var road := state.gate_x - cfg.leader_start()
	for c: int in setup.companies.size():
		var stats := combat.units[setup.companies[c]]
		var ambush := cfg.leader_start() + road * cfg.ambush_at[c]
		state.company_unit.append(setup.companies[c])
		state.company_x.append(ambush)
		state.company_ambush_x.append(ambush)
		state.company_state.append(MerchantState.Company.HIDDEN)
		state.company_timer.append(0.0)
		state.company_target.append(-1)
		state.company_speed.append(stats.speed * cfg.company_speed_factor)
		state.company_fight.append(cfg.fight_seconds * cfg.reference_melee / stats.melee)
