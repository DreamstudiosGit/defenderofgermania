class_name MerchantInputMap
extends RefCounted
## The merchant train's input actions, one set per device as in the battle:
## "merchant_kb_<action>" for keyboard and mouse, "merchant_pad<n>_<action>" for controller
## n. Devices are BattleInputMap.Device values, so the campaign passes the same ids to both.
## Their bindings are data (data/input.json, InputTable).


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "merchant_kb_"
	return "merchant_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	InputTable.register()
