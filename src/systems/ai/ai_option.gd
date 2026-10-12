class_name AiOption
extends RefCounted
## One thing a computer house could do: the command, its utility in taler worth per taler (or
## per round) and a readable label for the debug overlay.

var label: String
var utility: float
var command: Command
## Taler the action costs; the house keeps its reserve.
var cost: float = 0.0
## Taler the action adds to the upkeep every round.
var upkeep: float = 0.0


static func create(text: String, worth: float, action: Command, price: float = 0.0) -> AiOption:
	var option := AiOption.new()
	option.label = text
	option.utility = worth
	option.command = action
	option.cost = price
	return option
