extends GutTest

const EPSILON := 0.001
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1024, 768)
]

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()
	BattleInputMap.register()


func test_fixed_camera_fits_all_field_corners_at_desktop_and_deck_sizes() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		var camera := _camera_at(resolution)
		_assert_field_fits(camera, resolution)


func test_ground_projection_roundtrip_preserves_mouse_command_coordinates() -> void:
	var field := _cfg.battle.field_size
	var points: Array[Vector2] = [
		Vector2.ZERO, Vector2(field.x, 0), field, Vector2(0, field.y), field * 0.5,
		Vector2(field.x * 0.21, field.y * 0.73)
	]
	for resolution: Vector2i in RESOLUTIONS:
		var camera := _camera_at(resolution)
		for point: Vector2 in points:
			var screen := camera.unproject_position(Vector3(point.x, 0, point.y))
			var restored := BattleCamera.field_point(camera, screen)
			assert_almost_eq(restored.x, point.x, EPSILON, "mouse ground x at %s" % resolution)
			assert_almost_eq(restored.y, point.y, EPSILON, "mouse ground y at %s" % resolution)


func test_resize_reframes_the_entire_field_without_following_selection() -> void:
	var camera := _camera_at(RESOLUTIONS[1])
	var viewport := camera.get_viewport() as SubViewport
	var original_position := camera.position
	viewport.size = RESOLUTIONS[0]
	viewport.size_changed.emit()
	_assert_field_fits(camera, RESOLUTIONS[0])
	assert_eq(camera.position, original_position, "resize keeps the field center fixed")
	camera.setup(_cfg.battle.field_size, Vector2.ZERO)
	assert_eq(camera.position, original_position, "selection focus does not move the camera")
	camera.setup(_cfg.battle.field_size, _cfg.battle.field_size)
	assert_eq(camera.position, original_position, "other selection does not move the camera")


func test_only_pressed_right_mouse_button_queues_a_keyboard_command() -> void:
	var camera := _camera_at(RESOLUTIONS[0])
	var reader := BattleInputReader.new(BattleInputMap.Device.KEYBOARD)
	var point := _cfg.battle.field_size * Vector2(0.25, 0.65)
	var screen := camera.unproject_position(Vector3(point.x, 0, point.y))
	reader.handle_event(_mouse(MOUSE_BUTTON_LEFT, screen, true), camera)
	assert_false(reader.take().command_point)
	reader.handle_event(_mouse(MOUSE_BUTTON_RIGHT, screen, false), camera)
	assert_false(reader.take().command_point)
	reader.handle_event(_mouse(MOUSE_BUTTON_RIGHT, screen, true), camera)
	var command := reader.take()
	assert_true(command.command_point)
	assert_almost_eq(command.point.x, point.x, EPSILON)
	assert_almost_eq(command.point.y, point.y, EPSILON)
	assert_false(reader.take().command_point, "command is consumed once")
	var controller := BattleInputReader.new(BattleInputMap.Device.PAD_1)
	controller.handle_event(_mouse(MOUSE_BUTTON_RIGHT, screen, true), camera)
	assert_false(controller.take().command_point, "mouse does not command the controller player")


func test_mouse_wheel_leaves_camera_and_pending_orders_unchanged() -> void:
	var camera := _camera_at(RESOLUTIONS[0])
	var reader := BattleInputReader.new(BattleInputMap.Device.KEYBOARD)
	var original := camera.transform
	var original_size := camera.size
	for button: MouseButton in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		reader.handle_event(_mouse(button, Vector2(400, 300), true), camera)
		var command := reader.take()
		assert_false(command.command_point)
		assert_false(command.attack)
		assert_eq(command.move, Vector2.ZERO)
	assert_eq(camera.transform, original)
	assert_eq(camera.size, original_size)


func test_four_group_hud_fits_both_halves_of_the_deck_viewport_after_resize() -> void:
	var camera := _camera_at(RESOLUTIONS[1])
	var viewport := camera.get_viewport() as SubViewport
	var setup := BattleSetup.new()
	for unit_id: String in ["spearmen", "crossbowmen", "knights", "trebuchet"]:
		setup.attacker.add_company(unit_id)
		setup.defender.add_company(unit_id)
	var sim := BattleSim.new(_cfg, setup, 1198)
	var hud := BattleHud.new()
	viewport.add_child(hud)
	hud.setup(sim.state, _cfg.battle.armies, PackedInt32Array([0, 1]), camera)
	await get_tree().process_frame
	viewport.size = RESOLUTIONS[0]
	viewport.size_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Array = hud.get("_rows")
	for side: int in BattleState.SIDES:
		var row: HBoxContainer = rows[side]
		var rect := row.get_global_rect()
		assert_gte(rect.position.x, -EPSILON, "HUD starts inside the viewport")
		assert_lte(rect.end.x, float(RESOLUTIONS[0].x) + EPSILON, "HUD ends inside the viewport")
		assert_lte(rect.end.y, float(RESOLUTIONS[0].y) + EPSILON, "HUD bottom is visible")
		assert_eq(row.get_child_count(), 6, "four shields and two switch hints")
		for child: Node in row.get_children():
			if child is GroupShield:
				var shield := child as GroupShield
				assert_false(shield.active, "shared couch view has no gold selection rim")
	var left: HBoxContainer = rows[0]
	var right: HBoxContainer = rows[1]
	assert_lt(left.get_global_rect().end.x, right.get_global_rect().position.x,
		"the opposing four-group rows do not overlap")


func _camera_at(resolution: Vector2i) -> BattleCamera:
	var viewport := SubViewport.new()
	viewport.size = resolution
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var camera := BattleCamera.new()
	viewport.add_child(camera)
	camera.current = true
	camera.setup(_cfg.battle.field_size, _cfg.battle.field_size * 0.5)
	return camera


func _assert_field_fits(camera: BattleCamera, resolution: Vector2i) -> void:
	var field := _cfg.battle.field_size
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(field.x, 0), field, Vector2(0, field.y)]
	for corner: Vector2 in corners:
		for height: float in [0.0, 5.0]:
			var world := Vector3(corner.x, height, corner.y)
			var screen := camera.unproject_position(world)
			assert_false(camera.is_position_behind(world))
			assert_gte(screen.x, -EPSILON, "field left at %s" % resolution)
			assert_lte(screen.x, float(resolution.x) + EPSILON, "field right at %s" % resolution)
			assert_gte(screen.y, -EPSILON, "field top at %s" % resolution)
			assert_lte(screen.y, float(resolution.y) + EPSILON, "field bottom at %s" % resolution)


func _mouse(button: MouseButton, at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = pressed
	return event
