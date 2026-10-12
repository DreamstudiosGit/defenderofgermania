class_name TrebuchetResult
extends RefCounted
## Outcome of the trebuchet minigame for the campaign. A breach means the storm follows at once,
## without the wall bonus at that segment; otherwise the siege goes on next round.

var breach: bool = false
## Layout part id of the segment that fell first ("" without a breach), e.g. "gate".
var breach_part: String = ""
## "gate" or "wall" ("" without a breach).
var breach_kind: String = ""
## Share of the wall's HP destroyed in total after this bombardment: the earlier rounds'
## damage plus wall_damage_dealt. The campaign stores it back (ProvinceState.wall_damage).
var wall_damage: float = 0.0
## Share of the wall's HP destroyed by this bombardment alone.
var wall_damage_dealt: float = 0.0
## Share of the garrison's full health lost to fire pots.
var garrison_damage: float = 0.0
var shots_fired: int = 0
## Shots the counterfire cost (every third shot from wall level 3).
var shots_lost: int = 0
## Shots that struck the castle (a part, or the bailey for fire pots).
var hits: int = 0
## Estimated playing time: aiming, throw, flight and settling per shot plus counterfire.
var duration_seconds: float = 0.0
