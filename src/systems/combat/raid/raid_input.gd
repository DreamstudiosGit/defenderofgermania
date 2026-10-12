class_name RaidInput
extends RefCounted
## The leader's commands for one raid tick, device independent. RaidSim checks every field, so
## players, the computer leader and test scripts share this path.

## -1 back towards the entrance … +1 on towards the target.
var move: float = 0.0
## RaidFighter.Height of a new blow, -1 for none.
var strike: int = -1
## RaidFighter.Height of a new parry, -1 for none; wins over a strike in the same tick.
var parry: int = -1
## Held: takes a sneak path at its entrance and does the deed in the target room.
var act: bool = false
## Gives up: the leader escapes with a wound.
var flee: bool = false
