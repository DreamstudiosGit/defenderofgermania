class_name PauseMenu
extends Control
## The pause menu of every scene: resume, options, save and load (where the scene offers a
## state), the scene's own way out, back to the main menu, quit. While open it pauses the
## tree, so simulations, timers and cameras rest; it keeps running itself.

signal resumed
## The player picked a save to continue (only with state_source).
signal load_requested(slot: String)
## The player chose the scene's own entry (leave_text), e.g. to give up a battle.
signal leave_requested

## Returns the GameState to save, or null while saving is not possible: () -> GameState.
## Set it to offer "save" and "load" (the campaign).
var state_source := Callable()
## Text key of the scene's own entry; empty hides it.
var leave_text := ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()
