extends GutTest
## The castle view's layout against the game state (levels, decorations, buildings, village,
## constructions) and a headless build of the view with its time-lapse and close signal.

const HOUSE := "welfen"

var _rules: GameRules
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	CastleTimelapse.forget()


func test_every_home_level_builds_and_swaps_pieces() -> void:
	var previous: Dictionary = {}
	for level: int in range(1, 6):
		_home().castle_level = level
		var layout := _plan(_home_id())
		assert_eq(layout.name_key, "ECONOMY_HOME_CASTLE_%d" % level)
		var pieces := _keys(layout, CastleLayout.Kind.CASTLE)
		assert_false(pieces.is_empty(), "level %d has castle pieces" % level)
		if not previous.is_empty():
			assert_true(_adds_something(pieces, previous), "level %d adds or swaps" % level)
		previous = pieces
		var view := _show(_home_id())
		assert_gt(view.find_child("Pieces", true, false).get_child_count(), pieces.size())


func test_every_province_level_builds_and_swaps_pieces() -> void:
	var province := _province()
	var previous: Dictionary = {}
	for level: int in range(0, 4):
		province.castle_level = level
		var layout := _plan(province.id)
		assert_false(layout.is_home)
		assert_eq(layout.name_key, "ECONOMY_PROVINCE_CASTLE_%d" % level)
		var pieces := _keys(layout, CastleLayout.Kind.CASTLE)
		if level > 0:
			assert_true(_adds_something(pieces, previous), "level %d adds or swaps" % level)
		previous = pieces
		_show(province.id)


func test_every_province_of_a_new_game_plans_in_its_lord_colours() -> void:
	var heraldry := _rules.map.heraldry()
	for id: String in _state.provinces:
		var layout := _plan(id)
		assert_not_null(layout, id)
		var owner := _state.provinces[id].owner
		assert_eq(layout.primary, heraldry[owner][0], id)
		assert_eq(layout.is_home, id == _rules.map.home_province(owner), id)
	var church := ""
	for id: String in _state.provinces:
		if _state.provinces[id].owner == "church":
			church = id
	var view := _show(church)
	assert_gt(view.find_child("Pieces", true, false).get_child_count(), 0)


func test_decorations_show_only_when_owned() -> void:
	_home().castle_level = 3
	for id: String in _rules.economy.decorations:
		_house().decorations.clear()
		assert_eq(_sources(_plan(_home_id()), CastleLayout.Kind.DECORATION, id), 0, id)
		_house().decorations.assign([id])
		var expected := 0 if id == "stained_glass" else 1
		assert_eq(mini(_sources(_plan(_home_id()), CastleLayout.Kind.DECORATION, id), 1), expected, id)


func test_stained_glass_needs_the_chapel_of_level_four() -> void:
	_house().decorations.assign(["stained_glass"])
	for level: int in range(1, 6):
		_home().castle_level = level
		var count := _sources(_plan(_home_id()), CastleLayout.Kind.DECORATION, "stained_glass")
		assert_eq(count > 0, level >= 4, "level %d" % level)


func test_decorations_never_show_at_a_province_castle() -> void:
	_house().decorations.assign(_rules.economy.decorations.keys())
	var province := _province()
	province.castle_level = 2
	assert_eq(_plan(province.id).pieces_of(CastleLayout.Kind.DECORATION).size(), 0)


func test_each_building_adds_its_piece() -> void:
	for id: String in _rules.economy.buildings:
		_home().buildings.clear()
		_home().constructions.clear()
		assert_eq(_sources(_plan(_home_id()), CastleLayout.Kind.BUILDING, id), 0, id)
		_home().buildings.assign([id])
		var layout := _plan(_home_id())
		assert_gt(_sources(layout, CastleLayout.Kind.BUILDING, id), 0, id)
		for placement: CastleLayout.Placement in layout.pieces_of(CastleLayout.Kind.BUILDING):
			assert_eq(placement.progress, 1.0, id)


func test_village_grows_with_the_population_up_to_its_maximum() -> void:
	var maximum := int(CastleArt.section("settlement")["max_houses"])
	var last := 0
	for population: float in [5.0, 25.0, 45.0, 70.0, 100.0, 10000.0]:
		_home().population = population
		var houses := _plan(_home_id()).pieces_of(CastleLayout.Kind.HOUSE).size()
		assert_eq(houses, CastleSettlement.house_count(population), "population %d" % population)
		assert_gte(houses, last, "population %d" % population)
		assert_lte(houses, maximum)
		last = houses
	assert_eq(last, maximum, "a huge population fills the village")
	_home().population = 25.0
	var small := _plan(_home_id()).pieces_of(CastleLayout.Kind.HOUSE).size()
	_home().population = 70.0
	assert_gt(_plan(_home_id()).pieces_of(CastleLayout.Kind.HOUSE).size(), small)


func test_castle_construction_shows_the_next_level_raised_by_progress() -> void:
	_home().castle_level = 2
	var rounds := _rules.economy.home_castle[3].build_rounds
	_home().constructions.append(ConstructionState.create(ConstructionState.CASTLE, rounds - 1))
	var layout := _plan(_home_id())
	var expected := 1.0 - float(rounds - 1) / rounds
	var rising: Array[String] = []
	for placement: CastleLayout.Placement in layout.pieces_of(CastleLayout.Kind.CASTLE):
		if placement.source == ConstructionState.CASTLE:
			rising.append(placement.piece)
			assert_almost_eq(placement.progress, expected, 0.001, placement.piece)
		else:
			assert_eq(placement.progress, 1.0, placement.piece)
	assert_has(rising, "castle_curtain_wall")
	assert_has(rising, "castle_gatehouse")
	assert_does_not_have(rising, "castle_keep", "the keep stands already")
	assert_gt(layout.pieces_of(CastleLayout.Kind.SCAFFOLD).size(), 0, "scaffolding")
	assert_gt(layout.pieces_of(CastleLayout.Kind.SITE).size(), 0, "site props")


func test_building_construction_shows_scaffolding_and_progress() -> void:
	_home().constructions.append(ConstructionState.create("monastery", 1))
	var layout := _plan(_home_id())
	var monastery := layout.pieces_of(CastleLayout.Kind.BUILDING).filter(
		func(placement: CastleLayout.Placement) -> bool: return placement.source == "monastery"
	)
	assert_eq(monastery.size(), 1)
	assert_almost_eq((monastery[0] as CastleLayout.Placement).progress, 0.5, 0.001)
	assert_gt(layout.pieces_of(CastleLayout.Kind.SCAFFOLD).size(), 0)


func test_timelapse_raises_the_construction_and_pops_the_houses() -> void:
	_home().castle_level = 2
	_home().constructions.append(ConstructionState.create(ConstructionState.CASTLE, 1))
	var view := _show(_home_id())
	var timelapse := view.find_child("Timelapse", true, false) as CastleTimelapse
	var wall := _node(view, "castle_curtain_wall")
	assert_true(timelapse.is_playing())
	var start := wall.position.y
	timelapse.advance(CastleArt.number("timelapse", "duration", 3.0) + 30.0)
	assert_false(timelapse.is_playing())
	assert_lt(start, wall.position.y, "the wall rose")
	assert_lt(wall.position.y, 0.0, "but is not finished")
	for child: Node in view.find_child("Pieces", true, false).get_children():
		assert_true((child as Node3D).visible, "%s shows after the time-lapse" % child.name)


func test_timelapse_replays_only_what_is_new_since_the_last_view() -> void:
	_home().castle_level = 3
	var view := _show(_home_id())
	var timelapse := view.find_child("Timelapse", true, false) as CastleTimelapse
	timelapse.advance(30.0)
	view.show_province(_state, _rules, _home_id())
	assert_false(timelapse.is_playing(), "nothing new, nothing to replay")
	_home().buildings.append("granary")
	view.show_province(_state, _rules, _home_id())
	assert_true(timelapse.is_playing(), "the new granary rises")
	var granary := _node(view, "building_granary")
	assert_lt(granary.position.y, 0.0)
	timelapse.advance(30.0)
	assert_almost_eq(granary.position.y, 0.0, 0.001)


func test_castle_takes_the_owner_colours() -> void:
	_home().castle_level = 3
	var view := _show(_home_id())
	var colors := _rules.map.heraldry()[HOUSE]
	var gate := _node(view, "castle_gatehouse")
	assert_eq(gate.get_instance_shader_parameter("house_primary"), colors[0])
	assert_eq(gate.get_instance_shader_parameter("house_secondary"), colors[1])


func test_closed_fires_on_ui_cancel() -> void:
	var view := _show(_home_id())
	watch_signals(view)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	get_viewport().push_input(cancel)
	assert_signal_emitted(view, "closed")


func _house() -> HouseState:
	return _state.houses[HOUSE]


func _home_id() -> String:
	return _house().home_province


func _home() -> ProvinceState:
	return _state.provinces[_home_id()]


func _province() -> ProvinceState:
	for province: ProvinceState in _state.provinces_of(HOUSE):
		if province.id != _home_id():
			return province
	return null


func _plan(province_id: String) -> CastleLayout:
	return CastleLayout.plan(_state, _rules, province_id)


func _show(province_id: String) -> CastleView:
	var view := CastleView.new()
	add_child_autofree(view)
	view.show_province(_state, _rules, province_id)
	return view


func _node(view: CastleView, piece: String) -> MeshInstance3D:
	for child: Node in view.find_child("Pieces", true, false).get_children():
		if child.name.begins_with(piece + "_"):
			return child as MeshInstance3D
	return null


static func _keys(layout: CastleLayout, kind: CastleLayout.Kind) -> Dictionary:
	var keys: Dictionary = {}
	for placement: CastleLayout.Placement in layout.pieces_of(kind):
		keys[placement.key()] = true
	return keys


static func _adds_something(pieces: Dictionary, previous: Dictionary) -> bool:
	for key: String in pieces:
		if not previous.has(key):
			return true
	return false


static func _sources(layout: CastleLayout, kind: CastleLayout.Kind, source: String) -> int:
	var count := 0
	for placement: CastleLayout.Placement in layout.pieces_of(kind):
		if placement.source == source:
			count += 1
	return count
