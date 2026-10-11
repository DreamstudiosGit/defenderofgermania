class_name BattleDamage
extends RefCounted
## Damage formulas of the real-time battle. Melee values are per second; the caller scales
## them by the tick length.


## Damage per hit = attack - armor, at least 1; armor_factor < 1 pierces armor.
static func hit(attack: float, armor: float, armor_factor: float = 1.0) -> float:
	return maxf(1.0, attack - armor * armor_factor)


## Melee damage per second; spearmen multiply against cavalry, knights while charging fast.
static func melee(
	attacker: CombatConfig.UnitStats, armor: float, target_is_cavalry: bool, speed: float
) -> float:
	var attack := attacker.melee
	if target_is_cavalry:
		attack *= attacker.melee_vs_cavalry
	if is_charging(attacker, speed):
		attack *= attacker.charge_multiplier
	return hit(attack, armor)


## One-off damage when a cavalry charge hits; full strength only after the run-up distance.
static func impact(
	attacker: CombatConfig.UnitStats,
	armor: float,
	speed: float,
	run: float,
	formation_impact: float,
	rules: BattleRules
) -> float:
	var attack := attacker.melee * formation_impact
	if is_charging(attacker, speed):
		attack *= attacker.charge_multiplier
	var runup := clampf(run / rules.runup_distance, 0.0, 1.0)
	return hit(attack, armor) * rules.impact_seconds * runup


static func volley(attacker: CombatConfig.UnitStats, armor: float, volley_factor: float) -> float:
	return hit(attacker.ranged, armor, attacker.armor_piercing) * volley_factor


static func is_charging(attacker: CombatConfig.UnitStats, speed: float) -> bool:
	return attacker.charge_min_speed > 0.0 and speed >= attacker.charge_min_speed


## True when attacker_pos lies outside the target's front arc (flank or rear).
static func is_flank(
	attacker_pos: Vector2, target_pos: Vector2, target_facing: float, front_half_angle: float
) -> bool:
	var bearing := (attacker_pos - target_pos).angle()
	return absf(wrapf(bearing - target_facing, -PI, PI)) > front_half_angle
