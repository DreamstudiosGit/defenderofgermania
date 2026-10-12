extends GutTest
## Raid controls: keyboard, mouse and controller give the same RaidInputs.

const ACTIONS: Array[String] = ["left", "right", "high", "low", "strike", "parry", "act", "menu"]


func before_all() -> void:
	RaidInputMap.register()


func after_each() -> void:
	for device: int in [BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1]:
		for action: String in ACTIONS:
			Input.action_release(RaidInputMap.prefix(device) + action)


func test_every_device_has_every_action() -> void:
	for device: int in [
		BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1, BattleInputMap.Device.PAD_2
	]:
		for action: String in ACTIONS:
			assert_true(InputMap.has_action(RaidInputMap.prefix(device) + action), action)


func test_held_height_picks_the_blow() -> void:
	for device: int in [BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1]:
		var reader := RaidInputReader.new(device)
		var prefix := RaidInputMap.prefix(device)
		Input.action_press(prefix + "high")
		Input.action_press(prefix + "strike")
		reader.poll()
		var input := reader.take()
		assert_eq(input.strike, RaidFighter.Height.HIGH, "device %d strikes high" % device)
		assert_eq(input.parry, -1)
		Input.action_release(prefix + "high")
		Input.action_release(prefix + "strike")
		assert_eq(reader.held_height(), RaidFighter.Height.MID, "nothing held is the middle")


func test_mouse_aims_by_its_height_on_the_leader() -> void:
	var reader := RaidInputReader.new(BattleInputMap.Device.KEYBOARD)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = Vector2(400, 590)
	reader.handle_event(click, 300.0, 600.0)
	assert_eq(reader.take().parry, RaidFighter.Height.LOW, "pointing at the legs parries low")
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(400, 320)
	reader.handle_event(click, 300.0, 600.0)
	assert_eq(reader.take().strike, RaidFighter.Height.HIGH, "pointing at the head strikes high")


func test_a_controller_ignores_the_mouse() -> void:
	var reader := RaidInputReader.new(BattleInputMap.Device.PAD_1)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	reader.handle_event(click, 300.0, 600.0)
	assert_eq(reader.take().strike, -1)
