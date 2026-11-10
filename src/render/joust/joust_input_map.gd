class_name JoustInputMap
extends RefCounted
## The joust's input actions, one set per device like the battle (BattleInputMap.Device):
## "joust_kb_<action>" for keyboard and mouse, "joust_pad<n>_<action>" for controller n. Their
## bindings are data (data/input.json, InputTable). The mouse aims the lance
## (JoustInputReader).


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "joust_kb_"
	return "joust_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	InputTable.register()
