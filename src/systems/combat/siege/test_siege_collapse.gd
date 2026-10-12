extends GutTest
## The castle's collapse rules and the ballistics underneath: parts resting on a destroyed
## part fall, falling parts crush their neighbours, mounds only block, paths hit the first
## face they enter.

var _cfg: SiegeConfig


func before_all() -> void:
	_cfg = SiegeConfig.load_file()


func test_hp_is_the_wall_hp_spread_by_shares() -> void:
	var castle := _castle("province_3", 3)
	var total := 0
	for i: int in castle.part_count():
		total += castle.max_hp[i]
	assert_eq(total, 1200)
	assert_eq(castle.max_hp[castle.index_of("gate")], 360)


func test_a_part_resting_on_a_destroyed_part_falls() -> void:
	var castle := _castle("province_3", 3)
	var gate := castle.index_of("gate")
	var hoarding := castle.index_of("hoarding")
	castle.strike(gate, 240)
	castle.strike(gate, 240)
	assert_eq(castle.destroyed[gate], 1)
	assert_eq(castle.destroyed[hoarding], 1, "the hoarding rested on the gate")
	assert_eq(castle.causes[hoarding], SiegeEvent.Cause.FELL)
	assert_eq(castle.breach, gate)


func test_a_falling_part_crushes_its_neighbours() -> void:
	var castle := _castle("province_3", 3)
	var gate := castle.index_of("gate")
	var hoarding := castle.index_of("hoarding")
	castle.strike(hoarding, 240)
	assert_eq(castle.destroyed[hoarding], 1)
	var weight := roundi(castle.max_hp[hoarding] * _cfg.fall_damage_share)
	assert_eq(castle.hp[gate], castle.max_hp[gate] - weight, "the hoarding came down on the gate")
	var crushed := castle.take_events().filter(
		func(event: SiegeEvent) -> bool: return event.kind == SiegeEvent.Kind.CRUSHED
	)
	assert_eq(crushed.size(), 1)
	assert_eq((crushed[0] as SiegeEvent).other, hoarding)


func test_crushing_can_bring_down_the_next_part_and_open_a_breach() -> void:
	var castle := _castle("province_2", 2)
	var gate := castle.index_of("gate")
	castle.strike(gate, 240)
	assert_eq(castle.breach, -1)
	castle.strike(castle.index_of("hoarding"), 240)
	assert_eq(castle.destroyed[gate], 1, "the falling hoarding finished the weakened gate")
	assert_eq(castle.causes[gate], SiegeEvent.Cause.CRUSHED)
	assert_eq(castle.breach, gate)


func test_toppled_keep_crushes_the_hall() -> void:
	var castle := _castle("province_3", 3)
	var keep := castle.index_of("keep")
	var hall := castle.index_of("hall")
	castle.strike(keep, 240)
	castle.strike(keep, 240)
	assert_eq(castle.destroyed[keep], 1)
	assert_eq(castle.destroyed[hall], 1, "a keep of 324 HP falls on a hall of 96")
	assert_eq(castle.breach, -1, "halls and keeps are no wall segments")


func test_burning_parts_burn_down_and_fall() -> void:
	var castle := _castle("home_5", 4)
	var spire := castle.index_of("spire")
	castle.ignite(spire)
	var keep := castle.index_of("keep")
	castle.ignite(keep)
	assert_eq(castle.burning[keep], 0, "stone does not burn")
	for i: int in 3:
		castle.burn()
	assert_eq(castle.destroyed[spire], 1)
	assert_eq(castle.causes[spire], SiegeEvent.Cause.BURNT)


func test_mounds_block_but_take_no_damage() -> void:
	var castle := _castle("home_3", 3)
	var motte := castle.index_of("motte")
	assert_true(castle.blocks(motte))
	assert_false(castle.is_damageable(motte))
	castle.strike(motte, 240)
	assert_eq(castle.destroyed[motte], 0)
	assert_eq(castle.damage_dealt(), 0)


func test_path_hits_the_front_face_it_reaches_first() -> void:
	var castle := _castle("province_3", 3)
	var gate := castle.index_of("gate")
	var weight := TrebuchetAimer.solve(_cfg, 45, 0.0, castle.front, 4.0)
	var path := SiegeBallistics.launch(_cfg, TrebuchetShot.make(weight, 45), 0.0)
	var impact := SiegeBallistics.trace(_cfg, path, castle)
	assert_eq(impact.part, gate)
	assert_eq(impact.face, SiegeBallistics.Face.FRONT)
	assert_almost_eq(impact.x, castle.front, 1e-6)
	assert_between(impact.y, 4.0, 6.0)


func test_destroyed_parts_no_longer_stop_stones() -> void:
	var castle := _castle("province_3", 3)
	var gate := castle.index_of("gate")
	var weight := TrebuchetAimer.solve(_cfg, 45, 0.0, castle.front, 4.0)
	var path := SiegeBallistics.launch(_cfg, TrebuchetShot.make(weight, 45), 0.0)
	castle.strike(gate, 400)
	var impact := SiegeBallistics.trace(_cfg, path, castle)
	assert_ne(impact.part, gate)
	assert_gt(impact.x, castle.front)


func test_wind_carries_the_stone() -> void:
	var shot := TrebuchetShot.make(50, 45)
	var calm := SiegeBallistics.launch(_cfg, shot, 0.0)
	var tail := SiegeBallistics.launch(_cfg, shot, 5.0)
	var head := SiegeBallistics.launch(_cfg, shot, -5.0)
	var t := SiegeBallistics.ground_time(calm)
	assert_gt(tail.x_at(t), calm.x_at(t) + 5.0)
	assert_lt(head.x_at(t), calm.x_at(t) - 5.0)


func test_preview_shows_the_first_fifth_of_the_flight() -> void:
	var path := SiegeBallistics.launch(_cfg, TrebuchetShot.make(60, 50), 2.0)
	var points := SiegeBallistics.preview(path, _cfg.preview_share)
	var end := SiegeBallistics.ground_time(path) * 0.2
	assert_almost_eq(points[0], Vector2(_cfg.release), Vector2.ONE * 1e-3)
	assert_almost_eq(points[points.size() - 1], path.point(end), Vector2.ONE * 1e-3)


func test_sine_and_cosine_match_the_engine() -> void:
	for degrees: int in range(0, 91):
		assert_almost_eq(SiegeBallistics.sin_deg(degrees), sin(deg_to_rad(degrees)), 1e-9)
		assert_almost_eq(SiegeBallistics.cos_deg(degrees), cos(deg_to_rad(degrees)), 1e-9)


func _castle(layout: String, wall: int) -> SiegeCastle:
	return SiegeCastle.new(_cfg, _cfg.layout(layout), wall)
