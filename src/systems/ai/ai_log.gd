class_name AiLog
extends RefCounted
## What a computer house weighed in its last turn: every option with its utility, and which it
## took (the debug overlay's table, GDD "Debug-Overlay zeigt alle Nutzenwerte").

const LIMIT := 200

var entries: Array[Entry] = []


class Entry:
	var turn: int
	var phase: GameState.Phase
	var label: String
	var utility: float
	var taken: bool
	## Error key when the rules refused a taken action.
	var error: String


func add(
	turn: int, phase: GameState.Phase, label: String, utility: float, taken: bool, error: String
) -> void:
	if not entries.is_empty() and entries[0].turn != turn:
		entries.clear()
	if taken or not error.is_empty():
		# The option was listed while weighing; mark it instead of listing it twice.
		for i: int in range(entries.size() - 1, -1, -1):
			var listed := entries[i]
			if listed.label == label and listed.phase == phase and not listed.taken:
				listed.taken = taken
				listed.error = error
				return
	if entries.size() >= LIMIT:
		return
	var entry := Entry.new()
	entry.turn = turn
	entry.phase = phase
	entry.label = label
	entry.utility = utility
	entry.taken = taken
	entry.error = error
	entries.append(entry)
