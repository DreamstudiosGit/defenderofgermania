extends GutTest
## Keyboard and controller steer the raiding leader alike; several devices share one leader.

const ACTIONS: Array[String] = ["left", "right", "pull", "strike", "parry", "shoot"]


func before_all() -> void:
	MerchantInputMap.register()


func after_each() -> void:
	for device: int in [BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1]:
		for action: String in ACTIONS:
			Input.action_release(MerchantInputMap.prefix(device) + action)


func test_every_action_exists_for_keyboard_and_both_controllers() -> void:
	for device: int in [
		BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1, BattleInputMap.Device.PAD_2
	]:
		for action: String in ACTIONS + ["menu"]:
			var name := MerchantInputMap.prefix(device) + action
			assert_true(InputMap.has_action(name), name)
			assert_false(InputMap.action_get_events(name).is_empty(), name)


func test_keyboard_and_controller_steer_the_same_leader() -> void:
	var reader := MerchantInputReader.new(PackedInt32Array([
		BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1, -1
	]))
	assert_eq(reader.devices.size(), 2, "the computer slot is no device")
	Input.action_press(MerchantInputMap.prefix(BattleInputMap.Device.KEYBOARD) + "right")
	Input.action_press(MerchantInputMap.prefix(BattleInputMap.Device.PAD_1) + "pull")
	Input.action_press(MerchantInputMap.prefix(BattleInputMap.Device.PAD_1) + "parry")
	reader.poll()
	var input := reader.take()
	assert_eq(input.move, 1.0)
	assert_true(input.pull, "held pull counts every tick")
	assert_true(input.parry)
	assert_false(input.strike)
	assert_false(reader.take().parry, "a press is taken once")


func test_no_device_leaves_the_raid_to_the_computer() -> void:
	assert_true(MerchantInputReader.new(PackedInt32Array()).is_empty())
	assert_true(MerchantInputReader.new(PackedInt32Array([-1])).is_empty())
