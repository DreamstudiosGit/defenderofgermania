class_name BattleInput
extends RefCounted
## One player's commands for one battle tick, device independent. The simulation validates
## every field, so AI, local players and replays share this path.

## Stick or WASD direction in field axes (x right, y towards the camera), length up to 1.
var move := Vector2.ZERO
## -1 previous group, +1 next group.
var group_step: int = 0
## Picks the n-th group shield directly (0-based), -1 for none.
var group_slot: int = -1
var attack: bool = false
var formation: bool = false
var rally: bool = false
## Right-click: attacks the enemy company at point, otherwise moves the group there.
var command_point: bool = false
var point := Vector2.ZERO
