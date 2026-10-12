extends GutTest

const HOUSES: Array[String] = ["welfen", "wettiner", "staufer", "wittelsbacher"]
## Units that wear a helmet with the house crest.
const CRESTED: Array[String] = ["spearmen", "crossbowmen", "knights", "leader"]
## Mercenaries carry no house colours.
const UNPAINTED: Array[String] = ["brabanters"]

var _cfg: CombatConfig


func before_all() -> void:
	_cfg = CombatConfig.load_file()


func test_every_unit_has_a_model_for_every_house() -> void:
	for unit_id: String in _cfg.units:
		for house: String in HOUSES:
			var mesh := BattleModels.unit_mesh(unit_id, house)
			assert_not_null(mesh, "%s %s" % [unit_id, house])
			if mesh == null:
				continue
			assert_gt(mesh.get_aabb().size.y, 1.5, "models use metres and Y up")
			assert_almost_eq(mesh.get_aabb().position.y, 0.0, 0.2, "ground pivot")
			var has_stride := false
			var slots: Array[int] = []
			for surface: int in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
				for mask: Vector2 in uv2:
					has_stride = has_stride or mask.x > 0.5
				var material := mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material)
				if material != null:
					slots.append(int(material.get_shader_parameter("house_slot")))
					assert_eq(material.next_pass, BattleModels.outline(), "ink outline")
			if unit_id != "trebuchet":
				assert_true(has_stride, "%s has animated limbs" % unit_id)
			assert_eq(1 in slots, unit_id not in UNPAINTED, "%s wears house colours" % unit_id)


func test_crests_sit_on_the_helmet_and_differ_by_house() -> void:
	var units: Dictionary = BattleModels.settings()["unit_models"]
	for unit_id: String in CRESTED:
		var base := BattleModels.mesh("unit_%s" % units[unit_id], true)
		for house: String in HOUSES:
			var mesh := BattleModels.unit_mesh(unit_id, house)
			assert_gt(mesh.get_surface_count(), base.get_surface_count(), "%s %s" % [unit_id, house])
			assert_gt(mesh.get_aabb().end.y, base.get_aabb().end.y - 0.4, "crest above the helmet")
		var welfen := BattleModels.unit_mesh(unit_id, "welfen")
		assert_ne(welfen, BattleModels.unit_mesh(unit_id, "staufer"), "each house its crest")
	var levy := BattleModels.unit_mesh("levy", "welfen")
	assert_eq(levy, BattleModels.mesh("unit_levy", true), "the levy wears no helmet and no crest")


func test_all_environment_exports_load() -> void:
	for filename: String in DirAccess.get_files_at(BattleModels.DIRECTORY):
		if filename.ends_with(".glb") and not filename.begins_with("unit_"):
			var mesh := BattleModels.mesh(filename.get_basename())
			assert_not_null(mesh, filename)
			if mesh != null:
				assert_gt(mesh.get_surface_count(), 0, filename)
				assert_gt(mesh.get_aabb().size.x, 0.0, filename)


func test_batches_cover_units_and_reset_on_restart() -> void:
	var setup := BattleSetup.new()
	for unit_id: String in _cfg.units:
		if unit_id != "leader":
			setup.attacker.add_company(unit_id)
			setup.defender.add_company(unit_id)
	setup.attacker.has_leader = true
	setup.defender.has_leader = true
	var sim := BattleSim.new(_cfg, setup, 1198)
	var view := BattleFigures.new()
	add_child_autofree(view)
	view.setup(sim.state, _cfg.battle.armies, sim.tick_seconds())
	view.update_view(sim.state, sim.state.fig_pos, 1.0)
	assert_eq(view.get_child_count(), 16, "seven unit batches per side, spears and rings")
	var count := 0
	for child: Node in view.get_children():
		var instance := child as MultiMeshInstance3D
		assert_not_null(instance)
		if instance != null and not instance.name.begins_with("Figures_spear_"):
			if not instance.name.begins_with("Figures_ring_"):
				count += instance.multimesh.instance_count
	assert_eq(count, sim.state.fig_pos.size())
	view.setup(sim.state, _cfg.battle.armies, sim.tick_seconds())
	assert_eq(view.get_child_count(), 16, "restart replaces the batches")


func test_selection_only_shows_the_players_active_group() -> void:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), 1198)
	var view := BattleFigures.new()
	add_child_autofree(view)
	view.setup(sim.state, _cfg.battle.armies, sim.tick_seconds())
	view.set_selection_sides([true, false])
	for c: int in sim.state.company_count():
		var expected := sim.state.side[c] == 0 and sim.state.group[c] == BattleState.Group.INFANTRY
		assert_eq(view.selection_visible(sim.state, c), expected)
	sim.state.active_group[0] = BattleState.Group.CAVALRY
	assert_false(view.selection_visible(sim.state, 0), "previous group has no circle")
	view.set_selection_sides([false, false])
	for c: int in sim.state.company_count():
		assert_false(view.selection_visible(sim.state, c), "shared couch view hides selections")


func test_water_and_foliage_have_animation_shaders() -> void:
	var tree := BattleModels.mesh("tree_oak")
	for i: int in tree.get_surface_count():
		var material := tree.surface_get_material(i) as ShaderMaterial
		assert_not_null(material)
		if material != null:
			assert_eq(material.shader, BattleModels.WIND)
	var river := BattleModels.mesh("terrain_river_straight")
	var has_water := false
	for i: int in river.get_surface_count():
		var material := river.surface_get_material(i) as ShaderMaterial
		if material != null and material.shader == BattleModels.WATER:
			has_water = true
	assert_true(has_water, "river uses the flowing water shader")


func test_character_exports_include_named_actions() -> void:
	var art := BattleModels.settings()
	var units: Dictionary = art["unit_models"]
	for role: String in units.values():
		var path := BattleModels.DIRECTORY + "unit_%s.glb" % role
		var packed := load(path) as PackedScene
		var model := packed.instantiate()
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(player, role)
		var actions: Array[String] = ["idle", "walk", "attack", "hit", "death", "cheer"]
		if role in ["knight", "leader"]:
			actions.append_array(["horse_trot", "horse_gallop", "horse_charge"])
		if player != null:
			for action: String in actions:
				assert_true(player.has_animation(action), "%s has %s" % [role, action])
		model.free()


func test_shared_view_selection_policy() -> void:
	var packed := load("res://src/render/battle/battle_main.tscn") as PackedScene
	var battle := packed.instantiate()
	add_child_autofree(battle)
	battle.set_process(false)
	for devices: PackedInt32Array in [
		PackedInt32Array([0, -1]), PackedInt32Array([-1, 0]),
		PackedInt32Array([0, 1]), PackedInt32Array([-1, -1])
	]:
		battle.set("_devices", devices)
		var selected: Array = battle.call("_selection_sides")
		var count := int(devices[0] >= 0) + int(devices[1] >= 0)
		assert_eq(selected[0], count == 1 and devices[0] >= 0)
		assert_eq(selected[1], count == 1 and devices[1] >= 0)
	battle.set("_devices", PackedInt32Array([0, 1]))
	var sim: BattleSim = battle.get("_sim")
	var camera: BattleCamera = battle.get("_camera")
	for level: int in BattleCamera.ZOOM_LEVELS:
		camera.zoom_level = level
		sim.state.active_group[0] = BattleState.Group.INFANTRY
		battle.call("_process", 0.0)
		var original := camera.transform
		sim.state.active_group[0] = BattleState.Group.CAVALRY
		battle.call("_process", 0.0)
		assert_eq(camera.transform, original, "couch camera at zoom %d hides the selection" % level)


func test_hud_hides_active_borders_for_couch_and_ai() -> void:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), 1198)
	var hud := BattleHud.new()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	add_child_autofree(hud)
	for devices: PackedInt32Array in [
		PackedInt32Array([0, -1]), PackedInt32Array([0, 1]), PackedInt32Array([-1, -1])
	]:
		hud.setup(sim.state, _cfg.battle.armies, devices, camera)
		hud.update_view(sim, sim.state.pos, 0.0)
		var shields: Array = hud.get("_shields")
		for side: int in BattleState.SIDES:
			for shield: GroupShield in shields[side]:
				var expected := devices[0] == 0 and devices[1] == -1 and side == 0
				expected = expected and shield.group == BattleState.Group.INFANTRY
				assert_eq(shield.active, expected)
