class_name SaveSlotsScreen
extends Control
## The saved campaigns (SaveGames: the autosave and three slots) as a modal, to load one or to
## save the running campaign into a slot.

signal closed
## LOAD mode: the player picked a readable save; the caller continues it.
signal load_requested(slot: String)
## SAVE mode: the campaign was written into the slot.
signal saved(slot: String)

enum Mode { LOAD, SAVE }


func _init() -> void:
	visible = false


## Opens the list; SAVE mode writes `state` into the slot the player picks.
func open(_mode: Mode, _state: GameState = null) -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()
