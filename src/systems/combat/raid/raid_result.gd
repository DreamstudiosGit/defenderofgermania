class_name RaidResult
extends RefCounted
## Outcome of a castle raid. The campaign applies it: loot, prestige, prisoner or wound.

enum Outcome { SUCCESS, CAPTURED, ESCAPED_WOUNDED }

var success: bool = false
var target: String = ""
var outcome: Outcome = Outcome.ESCAPED_WOUNDED
## Raid time in seconds (without the intro).
var time_used: float = 0.0
var alarm_raised: bool = false
var guards_defeated: int = 0
var guards_avoided: int = 0
var practice: bool = false
