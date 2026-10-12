class_name MerchantInput
extends RefCounted
## The raider's commands for one tick, device independent. The simulation validates every
## field, so the computer, players and replays share this path.

## Ride direction along the road: -1 back, +1 towards the gate.
var move: float = 0.0
## Held: pull the driver off the box beside the leader.
var pull: bool = false
## Pressed this tick.
var strike: bool = false
var parry: bool = false
var shoot: bool = false
