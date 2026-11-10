class_name BattleInputMap
extends RefCounted
## The battle's input actions, one set per device: "battle_kb_<action>" for keyboard and
## mouse, "battle_pad<n>_<action>" for controller n (joypad device n). Their bindings are
## data (data/input.json, InputTable).

enum Device { KEYBOARD, PAD_1, PAD_2 }

const PADS := InputTable.PADS
const SLOTS := 4


static func prefix(device: int) -> String:
	if device == Device.KEYBOARD:
		return "battle_kb_"
	return "battle_pad%d_" % (device - Device.PAD_1)


static func register() -> void:
	InputTable.register()
