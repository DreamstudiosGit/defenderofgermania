class_name RaidInputMap
extends RefCounted
## The castle raid's input actions, one set per device like the battle (BattleInputMap.Device
## numbering): "raid_kb_<action>" for keyboard and mouse, "raid_pad<n>_<action>" for
## controller n. Heights come from up / down held while striking or parrying (nothing held:
## middle); the mouse aims by pointing above or below the leader's body. Their bindings are
## data (data/input.json, InputTable).

const PADS := InputTable.PADS


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "raid_kb_"
	return "raid_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	InputTable.register()
