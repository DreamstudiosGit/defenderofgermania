class_name JoustResult
extends RefCounted
## Outcome of a joust from the player's side (rider 0). Applying rewards is up to the caller.

enum Decision { UNSEATED, POINTS, STANCE, STATUS_QUO }

const NONE := -1
const PLAYER := 0
const OPPONENT := 1

var won: bool = false
var player_points: int = 0
var opponent_points: int = 0
## The rider who fell from the saddle and lost (PLAYER or OPPONENT), else NONE.
var unseated: int = NONE
var passes: int = 0
var player_stance: float = 0.0
var opponent_stance: float = 0.0
var decided_by: Decision = Decision.POINTS
## Game time in seconds from the herald's call to the end of the ceremony.
var duration: float = 0.0
