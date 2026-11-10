class_name SiegeInputMap
extends RefCounted
## The trebuchet minigame's input actions, one set per device like the battle
## (BattleInputMap.Device numbering): "siege_kb_<action>" for keyboard and mouse,
## "siege_pad<n>_<action>" for controller n. Up/down tilt the release angle, left/right shift
## the counterweight; their bindings are data (data/input.json, InputTable). The mouse uses
## the HUD sliders and the wheel.

const PADS := InputTable.PADS


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "siege_kb_"
	return "siege_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	InputTable.register()
