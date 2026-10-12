class_name RaidState
extends RefCounted
## Everything that changes during a raid. Guards keep their index for the whole raid;
## reinforcements are appended when they arrive.

var tick: int = 0
var leader := RaidFighter.new()
var guards: Array[RaidFighter] = []
var alarm: bool = false
var reinforcements_left: int = 0
var next_reinforcement_tick: int = 0
## Index into RaidLayout.sneak_paths while the leader is on one, else -1.
var sneak_path: int = -1
## 0–1 along the current sneak path.
var sneak_progress: float = 0.0
## 0–1 of the deed in the target room.
var deed_progress: float = 0.0
## Guard the leader faces (nearest active guard ahead), -1 for none.
var front: int = -1
## The front guard is close enough to fight; sneak paths and the deed wait.
var engaged: bool = false
var over: bool = false
var outcome: RaidResult.Outcome = RaidResult.Outcome.ESCAPED_WOUNDED
var events: Array[RaidEvent] = []


func is_sneaking() -> bool:
	return sneak_path >= 0


func front_guard() -> RaidFighter:
	return guards[front] if front >= 0 else null


func count_guards(defeated: bool) -> int:
	var count := 0
	for guard: RaidFighter in guards:
		if (guard.is_down() if defeated else guard.avoided and not guard.is_down()):
			count += 1
	return count


func checksum() -> int:
	var parts: Array = [tick, leader.checksum(), alarm, sneak_path, sneak_progress, deed_progress]
	for guard: RaidFighter in guards:
		parts.append(guard.checksum())
	return hash(parts)
