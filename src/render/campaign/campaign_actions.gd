class_name CampaignActions
extends Node
## Runs the human house's commands for the campaign scene. A command that starts a battle
## (battle_setup) or an adventure (adventure_setup) first asks whether to play it live, plays
## it over the war table and then runs with the live results; a trebuchet's breach leads
## straight into the storm. Emits covering(true) while a battle or minigame hides the table and
## finished(command, error) after every command.

signal covering(hidden: bool)
signal finished(command: Command, error: String)

var session: CampaignSession = null
var battles := BattleStage.new()
var adventures := AdventureStage.new()
var _command: Command = null
var _adventure: RefCounted = null


func _ready() -> void:
	add_child(battles)
	add_child(adventures)
	battles.opened.connect(covering.emit.bind(true))
	adventures.opened.connect(covering.emit.bind(true))
	battles.decided.connect(_on_battle_decided)
	adventures.decided.connect(_on_adventure_decided)


func is_running() -> bool:
	return battles.is_running() or adventures.is_running()


## Runs the command, asking first how to play the battle or adventure it starts.
func run(command: Command) -> void:
	var state := session.state
	if command.has_method("adventure_setup"):
		var setup: RefCounted = command.call("adventure_setup", state)
		if setup != null:
			adventures.ask(command, setup, _seed(command))
			return
	if command.has_method("battle_setup"):
		var battle: BattleSetup = command.call("battle_setup", state)
		if battle != null:
			_ask_battle(command, battle, null)
			return
	_execute(command, null, null)


func _ask_battle(command: Command, battle: BattleSetup, adventure: RefCounted) -> void:
	_command = command
	_adventure = adventure
	var where := _province(command)
	battles.ask(battle, session.rules, where, session.humans, _seed(command))


func _on_battle_decided(result: BattleResult) -> void:
	covering.emit(false)
	_execute(_command, result, _adventure)


func _on_adventure_decided(command: Command, result: RefCounted) -> void:
	covering.emit(false)
	if result != null and command.has_method("storm_setup"):
		var storm: BattleSetup = command.call("storm_setup", session.state, result)
		if storm != null:
			_ask_battle(command, storm, result)
			return
	_execute(command, null, result)


func _execute(command: Command, battle: BattleResult, adventure: RefCounted) -> void:
	_command = null
	_adventure = null
	finished.emit(command, session.execute_live(command, battle, adventure))


## Province the command's battle is fought in: a move's target or the army's province.
func _province(command: Command) -> String:
	if command is MoveArmyCommand:
		return (command as MoveArmyCommand).target
	var army := session.state.army(command.get("army_id"))
	return army.province if army != null else ""


## Same campaign moment, same battle or minigame: the round and the acting army (or house).
func _seed(command: Command) -> int:
	var army: Variant = command.get("army_id")
	var actor: int = army if army is int else session.state.active_index
	return session.state.turn * 1000 + actor
