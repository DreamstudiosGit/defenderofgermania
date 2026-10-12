extends GutTest
## Lance and blade values of the leader (GDD "Häuser & Anführer").

var _cfg: CombatConfig


func before_all() -> void:
	_cfg = CombatConfig.load_file()


func test_joust_window_is_60_plus_15_per_lance_point() -> void:
	assert_eq(_cfg.joust_window_ms(2, "welfen"), 90.0)
	assert_eq(_cfg.joust_window_ms(5, "wittelsbacher"), 135.0)


func test_staufer_knighthood_widens_the_joust_window_by_40_ms() -> void:
	assert_eq(_cfg.joust_window_ms(3, "staufer"), 60.0 + 45.0 + 40.0)


func test_lance_steadies_the_aim_and_blade_sharpens_sword_and_parry() -> void:
	assert_eq(_cfg.sway_reduction_per_lance, 0.1)
	assert_eq(_cfg.damage_per_blade, 0.1)
	assert_eq(_cfg.parry_window_per_blade_ms, 20.0)


func test_three_wins_raise_a_skill() -> void:
	assert_eq(MapData.load_file().campaign.leader_wins_per_point, 3)
