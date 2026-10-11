class_name BattleResult
extends RefCounted
## Outcome of a battle. Health arrays hold each company's remaining share of full HP in the
## order of the BattleSetup; 0 means destroyed. Applying it to armies is up to the caller.

var attacker_won: bool = false
var attacker_health: PackedFloat64Array = []
var defender_health: PackedFloat64Array = []
var attacker_leader_captured: bool = false
var defender_leader_captured: bool = false
## Battle time in seconds; 0 for auto-resolve.
var duration: float = 0.0
