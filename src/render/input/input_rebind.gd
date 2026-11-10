class_name InputRebind
extends RefCounted
## What happens when the player gives an action a new event. Inside one scene and device
## family an event belongs to one action only: the action that had it keeps its other events,
## or takes over the old ones of the rebound action when it would be left with none (a swap).
## An event the scene reads as a fixed mouse path, one of a locked action and the ones that
## open the pause menu everywhere are refused. Every change is saved (InputOverrides).

enum Result { BOUND, SWAPPED, TAKEN, UNCHANGED, REFUSED }

## Text key of the row that stands for the pause menu's events.
const PAUSE_TEXT := "INPUT_GENERAL_PAUSE"


class Outcome:
	var result := Result.BOUND
	## SWAPPED, TAKEN: the action that gave the event up.
	var other := ""
	## REFUSED: text key of what holds the event; empty when the event fits no binding.
	var holder_text := ""
	## False when the bindings could not be written to the player's file.
	var saved := true


## Binds `token` (InputNotation) to the action for one device family and resolves a conflict.
static func assign(
	scene: String, action: String, family: InputTable.Family, token: String
) -> Outcome:
	var outcome := Outcome.new()
	var mine := PackedStringArray([token])
	var before := InputTable.tokens(scene, action, family)
	outcome.holder_text = reserved_by(scene, family, token)
	if not outcome.holder_text.is_empty() or not InputTable.accepts(scene, action, family, mine):
		outcome.result = Result.REFUSED
		return outcome
	if before == mine:
		outcome.result = Result.UNCHANGED
		return outcome
	outcome.other = holder_of(scene, family, token, action)
	if not outcome.other.is_empty():
		var rest := _without(InputTable.tokens(scene, outcome.other, family), token)
		outcome.result = Result.TAKEN
		if rest.is_empty():
			rest = _without(before, token)
			outcome.result = Result.SWAPPED
		if not rest.is_empty():
			outcome.saved = InputOverrides.set_binding(scene, outcome.other, family, rest) == OK
	outcome.saved = InputOverrides.set_binding(scene, action, family, mine) == OK and outcome.saved
	return outcome


## The action of the scene, other than `except`, that has the event for this family; empty
## when none has.
static func holder_of(
	scene: String, family: InputTable.Family, token: String, except: String = ""
) -> String:
	for action: String in InputTable.actions(scene):
		if action != except and token in InputTable.tokens(scene, action, family):
			return action
	return ""


## Text key of what keeps the event from being bound in this scene: a fixed mouse path, a
## locked action or the pause menu; empty when it is free to bind.
static func reserved_by(scene: String, family: InputTable.Family, token: String) -> String:
	if family == InputTable.Family.KEYS:
		for fixed_name: String in InputTable.fixed(scene):
			if token in InputTable.fixed_tokens(scene, fixed_name):
				return InputTable.action_text(scene, fixed_name)
	for action: String in InputTable.actions(scene):
		var locked := InputTable.is_locked(scene, action)
		if locked and token in InputTable.tokens(scene, action, family):
			return InputTable.action_text(scene, action)
	if token in InputGlyphs.action_tokens(App.PAUSE_ACTION, family):
		return PAUSE_TEXT
	return ""


static func _without(tokens: PackedStringArray, token: String) -> PackedStringArray:
	var rest := PackedStringArray()
	for other: String in tokens:
		if other != token:
			rest.append(other)
	return rest
