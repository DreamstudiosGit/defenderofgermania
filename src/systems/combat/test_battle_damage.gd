extends GutTest
## Damage formulas of the real-time battle against the GDD values in data/combat.json.

const EPSILON := 1e-9

var _cfg: CombatConfig


func before_all() -> void:
	_cfg = CombatConfig.load_file()


func test_battle_section_loads() -> void:
	assert_not_null(_cfg.battle)
	assert_eq(_cfg.battle.tick_rate, 30)
	assert_eq(_cfg.battle.field_size, Vector2(300, 180))
	assert_eq(_cfg.battle.armies.size(), 2)


func test_damage_is_attack_minus_armor_at_least_one() -> void:
	assert_eq(BattleDamage.hit(14.0, 6.0), 8.0)
	assert_eq(BattleDamage.hit(4.0, 6.0), 1.0)
	assert_eq(BattleDamage.hit(6.0, 6.0), 1.0)


func test_crossbows_halve_armor() -> void:
	var crossbow := _cfg.units["crossbowmen"]
	# 14 - 6 * 0.5 against knights, 14 - 3 * 0.5 against spearmen.
	assert_almost_eq(BattleDamage.volley(crossbow, 6.0, 1.0), 11.0, EPSILON)
	assert_almost_eq(BattleDamage.volley(crossbow, 3.0, 1.0), 12.5, EPSILON)
	var staggered := _cfg.battle.formation(BattleState.Group.ARCHERS, 1)
	assert_almost_eq(BattleDamage.volley(crossbow, 3.0, staggered.volley), 6.25, EPSILON)


func test_spearmen_against_cavalry() -> void:
	var spearmen := _cfg.units["spearmen"]
	# 8 * 2.5 - 6 against knights, plain 8 - 3 against spearmen.
	assert_almost_eq(BattleDamage.melee(spearmen, 6.0, true, 0.0), 14.0, EPSILON)
	assert_almost_eq(BattleDamage.melee(spearmen, 3.0, false, 0.0), 5.0, EPSILON)


func test_knights_double_only_when_charging_fast() -> void:
	var knights := _cfg.units["knights"]
	assert_almost_eq(BattleDamage.melee(knights, 3.0, false, 5.0), 25.0, EPSILON)
	assert_almost_eq(BattleDamage.melee(knights, 3.0, false, 4.9), 11.0, EPSILON)
	var leader := _cfg.units["leader"]
	assert_almost_eq(BattleDamage.melee(leader, 3.0, false, 6.0), 13.0, EPSILON)


func test_charge_impact_needs_full_runup() -> void:
	var knights := _cfg.units["knights"]
	var wedge := _cfg.battle.formation(BattleState.Group.CAVALRY, 0).impact
	# (14 * 2 wedge * 2 charge - 1 armor) * 3 impact seconds, scaled by run / 30 m.
	var full := 55.0 * 3.0
	assert_almost_eq(BattleDamage.impact(knights, 1.0, 8.0, 30.0, wedge, _cfg.battle), full, EPSILON)
	assert_almost_eq(BattleDamage.impact(knights, 1.0, 8.0, 90.0, wedge, _cfg.battle), full, EPSILON)
	assert_almost_eq(
		BattleDamage.impact(knights, 1.0, 8.0, 15.0, wedge, _cfg.battle), full / 2.0, EPSILON
	)
	assert_eq(BattleDamage.impact(knights, 1.0, 8.0, 0.0, wedge, _cfg.battle), 0.0)


func test_wedge_hits_twice_as_hard_as_line() -> void:
	var knights := _cfg.units["knights"]
	var line := _cfg.battle.formation(BattleState.Group.CAVALRY, 1).impact
	# Below charge speed: 14 * 2 wedge - 1 versus 14 * 1 line - 1.
	assert_almost_eq(BattleDamage.impact(knights, 1.0, 4.0, 30.0, 2.0, _cfg.battle), 81.0, EPSILON)
	assert_almost_eq(BattleDamage.impact(knights, 1.0, 4.0, 30.0, line, _cfg.battle), 39.0, EPSILON)


func test_hedgehog_doubles_protection_against_cavalry() -> void:
	var line := _cfg.battle.formation(BattleState.Group.INFANTRY, 0)
	var hedgehog := _cfg.battle.formation(BattleState.Group.INFANTRY, 1)
	assert_eq(hedgehog.shape, "hedgehog")
	assert_eq(hedgehog.speed, 0.0)
	assert_almost_eq(line.cavalry_damage_taken / hedgehog.cavalry_damage_taken, 2.0, EPSILON)


func test_flank_and_rear_lie_outside_the_front_arc() -> void:
	var front := deg_to_rad(60.0)
	var target := Vector2(100, 100)
	assert_false(BattleDamage.is_flank(Vector2(110, 100), target, 0.0, front))
	assert_false(BattleDamage.is_flank(Vector2(110, 105), target, 0.0, front))
	assert_true(BattleDamage.is_flank(Vector2(100, 110), target, 0.0, front))
	assert_true(BattleDamage.is_flank(Vector2(90, 100), target, 0.0, front))
	assert_false(BattleDamage.is_flank(Vector2(90, 100), target, 0.0, PI))
