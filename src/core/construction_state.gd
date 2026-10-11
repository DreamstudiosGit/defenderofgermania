class_name ConstructionState
extends RefCounted
## A building or the next castle level under construction in a province.

const CASTLE := "castle"

## Building id, or CASTLE for the next castle level.
var project: String
var rounds_left: int


static func create(project_id: String, rounds: int) -> ConstructionState:
	var construction := ConstructionState.new()
	construction.project = project_id
	construction.rounds_left = rounds
	return construction


static func from_dict(r: DataReader, data: Dictionary) -> ConstructionState:
	return create(r.text(data, "project"), r.integer(data, "rounds_left"))


func to_dict() -> Dictionary:
	return {"project": project, "rounds_left": rounds_left}
