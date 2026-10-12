class_name AdventureStage
extends Node
## Runs the minigame of an adventure over the war table: asks whether to play it live
## (AdventureChoice), opens the minigame scene that fits the setup and hands the command back
## with the result — null when the computer plays the house's side. The device the player used
## last leads (minigames with one rider read only the first device).

signal opened
signal decided(command: Command, result: RefCounted)

const SCENES := {
	Adventures.MERCHANT_TRAIN: "res://src/render/merchant/merchant_main.tscn",
	Adventures.JOUST: "res://src/render/joust/joust_main.tscn",
	Adventures.TREBUCHET: "res://src/render/siege/trebuchet_main.tscn",
}

var choice := AdventureChoice.new()
var _command: Command = null
var _setup: RefCounted = null
var _adventure := ""
var _seed := 0
var _scene: Node = null
var _last_device := BattleInputMap.Device.KEYBOARD


func _ready() -> void:
	choice.chosen.connect(_on_chosen)


## Asks how to play the adventure `command` starts with `setup`.
func ask(command: Command, setup: RefCounted, seed_value: int) -> void:
	_command = command
	_setup = setup
	_adventure = adventure_of(setup)
	_seed = seed_value
	choice.open(_adventure)


func _input(event: InputEvent) -> void:
	var motion := event as InputEventJoypadMotion
	if event is InputEventJoypadButton or (motion != null and absf(motion.axis_value) > 0.5):
		_last_device = BattleInputMap.Device.PAD_1 + clampi(event.device, 0, 1)
	elif event is InputEventKey or event is InputEventMouseButton:
		_last_device = BattleInputMap.Device.KEYBOARD


func is_running() -> bool:
	return _scene != null or choice.visible


static func adventure_of(setup: RefCounted) -> String:
	if setup is MerchantSetup:
		return Adventures.MERCHANT_TRAIN
	if setup is JoustSetup:
		return Adventures.JOUST
	if setup is TrebuchetSetup:
		return Adventures.TREBUCHET
	return ""


func _on_chosen(play_live: bool) -> void:
	if not play_live or not SCENES.has(_adventure):
		_decide(null)
		return
	_scene = (load(SCENES[_adventure]) as PackedScene).instantiate()
	var other := BattleInputMap.Device.PAD_1
	if _last_device != BattleInputMap.Device.KEYBOARD:
		other = BattleInputMap.Device.KEYBOARD
	var devices := PackedInt32Array([_last_device, other])
	_scene.call("configure_campaign", _setup, devices, _seed)
	_scene.connect("finished", _on_finished)
	add_child(_scene)
	opened.emit()


func _on_finished(result: RefCounted) -> void:
	_scene.queue_free()
	_scene = null
	_decide(result)


func _decide(result: RefCounted) -> void:
	var command := _command
	_command = null
	_setup = null
	decided.emit(command, result)
