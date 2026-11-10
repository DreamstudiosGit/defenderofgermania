extends GutTest
## The war table between two views of a game: figures follow their armies (at once without
## animations, by a glide, a drop or a sink with them, and a second update redirects a glide),
## a conquered province ends in its new owner's colour, another game is set up without any
## motion, and the graphics quality switches the costly light off.

const SIZE := Vector2i(1280, 800)
const HOUSE := "welfen"

var _map: MapData
var _state: GameState
var _quality := 0


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, EconomyConfig.load_file(), 1)
	_quality = App.quality()


func after_each() -> void:
	App.settings.set_value(UserSettings.QUALITY, _quality)


func test_figures_reach_the_end_state_at_once_without_animations() -> void:
	var table := _table(false)
	table.update_view(_state)
	var army := _state.armies_of(HOUSE)[0]
	var target := _empty_neighbour(army.province)
	army.province = target
	var recruited := _state.add_army(HOUSE, _state.houses[HOUSE].home_province)
	var gone := _foreign_army()
	var gone_figure := _pieces(table).figure_of(gone.id)
	_state.remove_army(gone)
	table.update_view(_state)
	var figure := _pieces(table).figure_of(army.id)
	assert_eq(figure.position, table.world_position(target), "the moved army stands there")
	assert_false(figure.is_moving())
	var dropped := _pieces(table).figure_of(recruited.id)
	assert_not_null(dropped, "the new army has a figure")
	assert_eq(dropped.position, dropped.place)
	assert_false(dropped.is_moving())
	assert_eq(table.figure_count(), _state.armies.size())
	assert_null(_pieces(table).figure_of(gone.id))
	assert_true(gone_figure.is_queued_for_deletion(), "the removed army's figure is gone")


func test_a_moved_army_glides_and_a_second_update_redirects_it() -> void:
	var table := _table(true)
	table.update_view(_state)
	var army := _state.armies_of(HOUSE)[0]
	var origin := army.province
	var start := table.world_position(origin)
	var first := _empty_neighbour(origin)
	army.province = first
	table.update_view(_state)
	var figure := _pieces(table).figure_of(army.id)
	assert_eq(figure.place, table.world_position(first), "the state is final at once")
	assert_eq(figure.position, start, "the picture still stands at the start")
	assert_true(figure.is_moving())
	var screen := table.camera.unproject_position(figure.place + Vector3.UP * 2.0)
	assert_eq(table.army_at(screen), army.id, "a click meets the army where it stands now")
	figure.advance(0.15)
	assert_gt(figure.position.y, start.y, "it hops on the way")
	table.update_view(_state)
	assert_true(figure.is_moving(), "an update without news leaves the glide alone")
	var second := _empty_neighbour(first, origin)
	army.province = second
	table.update_view(_state)
	figure.advance(0.1)
	assert_true(figure.is_moving())
	figure.advance(1.0)
	assert_eq(figure.position, table.world_position(second), "it ends where the army is")
	assert_false(figure.is_moving())


func test_a_new_army_drops_in_and_a_removed_one_sinks_away() -> void:
	var table := _table(true)
	table.update_view(_state)
	var count := table.figure_count()
	var recruited := _state.add_army(HOUSE, _empty_neighbour(_state.houses[HOUSE].home_province))
	var gone := _foreign_army()
	var sinking := _pieces(table).figure_of(gone.id)
	_state.remove_army(gone)
	table.update_view(_state)
	assert_eq(table.figure_count(), count, "one more, one less: counted at once")
	var dropped := _pieces(table).figure_of(recruited.id)
	assert_gt(dropped.position.y, dropped.place.y + 1.0, "it starts above its place")
	dropped.advance(1.0)
	assert_eq(dropped.position, dropped.place)
	assert_null(_pieces(table).figure_of(gone.id), "the removed army answers no click")
	assert_false(sinking.is_queued_for_deletion(), "its figure is still sinking")
	sinking.advance(0.1)
	assert_lt(sinking.position.y, sinking.place.y)
	sinking.advance(1.0)
	assert_true(sinking.is_queued_for_deletion())


func test_another_game_is_set_up_without_motion() -> void:
	var table := _table(true)
	table.update_view(_state)
	var other := GameSetup.create(_map, EconomyConfig.load_file(), 2)
	var army := other.armies_of(HOUSE)[0]
	army.province = _empty_neighbour(army.province)
	other.provinces[army.province].owner = HOUSE
	table.update_view(other)
	assert_false(_pieces(table).figure_of(army.id).is_moving())
	assert_eq(_paint(table, army.province), _owner_paint(HOUSE))
	assert_false(_conquest(table).is_processing())


func test_an_owner_change_ends_in_the_new_colour_at_once_without_animations() -> void:
	var table := _table(false)
	table.update_view(_state)
	var province := _foreign_province()
	_state.provinces[province].owner = HOUSE
	table.update_view(_state)
	assert_eq(_paint(table, province), _owner_paint(HOUSE))
	assert_false(_conquest(table).is_running(province))


func test_an_owner_change_blends_to_the_new_colour() -> void:
	var table := _table(true)
	table.update_view(_state)
	var province := _foreign_province()
	var before := _paint(table, province)
	_state.provinces[province].owner = HOUSE
	table.update_view(_state)
	var conquest := _conquest(table)
	assert_true(conquest.is_running(province))
	assert_eq(_paint(table, province), before, "the blend starts from the old colour")
	conquest.advance(0.2)
	var midway := _paint(table, province)
	assert_ne(midway, before)
	assert_ne(midway, _owner_paint(HOUSE))
	table.update_view(_state)
	assert_eq(_paint(table, province), midway, "an update without news leaves the blend alone")
	conquest.advance(2.0)
	assert_eq(_paint(table, province), _owner_paint(HOUSE))
	assert_false(conquest.is_running(province))
	assert_false(conquest.is_processing(), "nothing runs per frame once it has ended")


func test_quality_low_switches_the_costly_light_off() -> void:
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.LOW)
	var table := _table(false)
	var environment := (table.get_node("Lighting/Environment") as WorldEnvironment).environment
	assert_false(environment.ssao_enabled, "no ambient occlusion")
	assert_false(environment.ssil_enabled, "no indirect light")
	assert_false(environment.glow_enabled, "no glow")
	assert_false(environment.volumetric_fog_enabled, "no volumetric fog")
	assert_eq(_candle_shadows(table), 0, "no candle casts a shadow")
	assert_eq(_viewport(table).positional_shadow_atlas_size, 1024, "a smaller shadow map")
	var key := table.get_node("Lighting/KeyLight") as DirectionalLight3D
	assert_eq(key.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)


func test_the_table_follows_a_change_of_the_quality_option() -> void:
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.LOW)
	var table := _table(false)
	var environment := (table.get_node("Lighting/Environment") as WorldEnvironment).environment
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.MEDIUM)
	assert_true(environment.ssao_enabled)
	assert_true(environment.glow_enabled)
	assert_false(environment.ssil_enabled)
	assert_eq(_candle_shadows(table), 2, "the candles the data names")
	App.settings.set_value(UserSettings.QUALITY, UserSettings.Quality.HIGH)
	assert_true(environment.ssil_enabled)
	assert_eq(_candle_shadows(table), MapArt.settings()["candles"].size(), "every candle")


func test_the_candles_flicker_around_their_energy() -> void:
	var table := _table(false)
	var lighting := table.get_node("Lighting") as MapLighting
	var amount := MapArt.number("light", "flicker_amount", 0.14)
	var candles: Array = MapArt.settings()["candles"]
	var changed := false
	for step: int in 20:
		lighting.flicker(0.05)
		var index := 0
		for child: Node in lighting.get_children():
			var light := child as OmniLight3D
			if light == null:
				continue
			var energy := float((candles[index] as Dictionary)["energy"])
			assert_almost_eq(light.light_energy, energy, energy * amount + 0.001)
			changed = changed or not is_equal_approx(light.light_energy, energy)
			index += 1
	assert_true(changed, "the light moves")


func _table(animated: bool) -> MapTable:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var table := MapTable.new()
	viewport.add_child(table)
	table.build(_map)
	_pieces(table).animated = animated
	(table.get_node("Board") as MapBoard).animated = animated
	return table


func _pieces(table: MapTable) -> MapPieces:
	return table.get_node("Pieces") as MapPieces


func _conquest(table: MapTable) -> MapConquest:
	return table.get_node("Board/Conquest") as MapConquest


func _viewport(table: MapTable) -> Viewport:
	return table.get_viewport()


func _paint(table: MapTable, province: String) -> Color:
	var field := table.get_node("Board/Field_" + province) as MeshInstance3D
	return field.get_instance_shader_parameter("paint")


func _owner_paint(owner: String) -> Color:
	var paper := MapArt.color("sheet", "paper", Color.WHITE)
	return MapArt.owner_color(_map, owner).lerp(paper, MapArt.number("field", "paint_mix", 0.12))


func _candle_shadows(table: MapTable) -> int:
	var count := 0
	for child: Node in table.get_node("Lighting").get_children():
		var light := child as OmniLight3D
		if light != null and light.shadow_enabled:
			count += 1
	return count


## A neighbour without an army, so a figure moved there stands on the field's centre.
func _empty_neighbour(province: String, avoid: String = "") -> String:
	for neighbour: String in _map.provinces[province].neighbors:
		if _state.armies_in(neighbour).is_empty() and neighbour != avoid:
			return neighbour
	return ""


func _foreign_province() -> String:
	for id: String in _state.provinces:
		if _state.provinces[id].owner != HOUSE:
			return id
	return ""


func _foreign_army() -> ArmyState:
	for army: ArmyState in _state.armies:
		if army.owner != HOUSE:
			return army
	return null
