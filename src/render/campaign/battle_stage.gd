class_name BattleStage
extends Node
## A battle a human house is about to fight on the campaign: asks whether to fight it live
## (BattleChoice), runs the battle scene over the war table and hands the live result back —
## null when the battle is left to auto-resolve. The attacker plays on keyboard and mouse, a
## human defender on controller 1.

signal opened
signal decided(result: BattleResult)

const BATTLE_SCENE := preload("res://src/render/battle/battle_main.tscn")

var choice := BattleChoice.new()
var battle: Node = null
var _setup: BattleSetup = null
var _humans: Array[String] = []
var _seed := 0


func _ready() -> void:
	choice.chosen.connect(_on_chosen)


## Asks how to fight the battle in the province.
func ask(
	setup: BattleSetup,
	rules: GameRules,
	province_id: String,
	humans: Array[String],
	seed_value: int
) -> void:
	_setup = setup
	_humans = humans
	_seed = seed_value
	choice.open(setup, rules, province_id)


func is_running() -> bool:
	return battle != null or choice.visible


func _on_chosen(play_live: bool) -> void:
	if not play_live:
		decided.emit(null)
		return
	var defender_human := _setup.defender.owner in _humans
	var devices := PackedInt32Array([
		BattleInputMap.Device.KEYBOARD, BattleInputMap.Device.PAD_1 if defender_human else -1
	])
	_setup.attacker.is_human = true
	_setup.defender.is_human = defender_human
	battle = BATTLE_SCENE.instantiate()
	battle.call("configure_campaign", _setup, devices, _seed)
	battle.connect("battle_finished", _on_finished)
	add_child(battle)
	opened.emit()


func _on_finished(result: BattleResult) -> void:
	battle.queue_free()
	battle = null
	decided.emit(result)
