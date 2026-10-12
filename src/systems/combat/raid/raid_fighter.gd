class_name RaidFighter
extends RefCounted
## The leader or one guard: place on the corridor, health and current action. Actions count
## whole ticks; a blow lands on the tick its windup is full.

enum Action { POST, READY, WINDUP, RECOVER, PARRY, OPEN, STAGGER, DOWN }
enum Height { HIGH, MID, LOW }

## Metres from the entrance along the corridor.
var x: float = 0.0
var health: float = 0.0
var max_health: float = 0.0
var stamina: float = 0.0
var action: Action = Action.READY
## Height of the current windup or parry.
var height: int = Height.MID
## Guard: the height it covers while ready.
var stance: int = Height.MID
var action_ticks: int = 0
## Ticks the current action lasts; 0 for open-ended ones (POST, READY, DOWN).
var action_length: int = 0

var skill: int = 0
var post_x: float = 0.0
var reinforcement: bool = false
var avoided: bool = false
var idle_ticks: int = 0
var stance_ticks: int = 0
var attack_index: int = 0
var stance_index: int = 0
var react_index: int = 0
## Ticks until the guard turns its guard to react_height; -1 when nothing is pending.
var react_in: int = -1
var react_height: int = Height.MID
## Leader: ticks since stamina was last spent.
var rested_ticks: int = 0


func start(next: Action, length: int = 0, at_height: int = -1) -> void:
	action = next
	action_ticks = 0
	action_length = length
	if at_height >= 0:
		height = at_height


func is_down() -> bool:
	return action == Action.DOWN


## Takes part in the fight: standing, not left behind by a sneak path.
func is_active() -> bool:
	return action != Action.DOWN and not avoided


## Share of the current action done, 0–1 (0 for open-ended actions).
func progress() -> float:
	if action_length <= 0:
		return 0.0
	return clampf(float(action_ticks) / action_length, 0.0, 1.0)


func ticks_left() -> int:
	return action_length - action_ticks


func checksum() -> int:
	return hash([x, health, stamina, action, height, stance, action_ticks, idle_ticks, avoided])
