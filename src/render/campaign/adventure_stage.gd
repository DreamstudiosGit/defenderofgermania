class_name AdventureStage
extends Node
## Runs the minigame of an adventure over the war table: asks whether to play it live
## (AdventureChoice), opens the minigame scene that fits the setup and hands the command back
## with the result — null when the computer plays the house's side.

signal opened
signal decided(command: Command, result: RefCounted)

const SCENES := {
	Adventures.MERCHANT_TRAIN: "res://src/render/merchant/merchant_main.tscn",
}

var choice := AdventureChoice.new()
var _command: Command = null
var _setup: RefCounted = null
var _adventure := ""
var _seed := 0
var _scene: Node = null


func _ready() -> void:
	choice.chosen.connect(_on_chosen)


## Asks how to play the adventure `command` starts with `setup`.
func ask(command: Command, setup: RefCounted, seed_value: int) -> void:
	_command = command
	_setup = setup
	_adventure = adventure_of(setup)
	_seed = seed_value
	choice.open(_adventure)


func is_running() -> bool:
	return _scene != null or choice.visible


static func adventure_of(setup: RefCounted) -> String:
	if setup is MerchantSetup:
		return Adventures.MERCHANT_TRAIN
	return ""


func _on_chosen(play_live: bool) -> void:
	if not play_live or not SCENES.has(_adventure):
		_decide(null)
		return
	_scene = (load(SCENES[_adventure]) as PackedScene).instantiate()
	var devices := PackedInt32Array([BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1])
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
