class_name EventState
extends RefCounted
## Event cards in a running game (milestone M5): filled by the events system. Part of the save
## (GameState.to_dict).


static func from_dict(_r: DataReader, _data: Dictionary) -> EventState:
	return EventState.new()


func to_dict() -> Dictionary:
	return {}
