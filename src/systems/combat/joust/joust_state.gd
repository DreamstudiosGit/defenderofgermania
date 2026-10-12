class_name JoustState
extends RefCounted
## Everything that changes during a joust; rider 0 is the player's house.

enum Phase { INTRO, READY, RUNUP, AIM, CLASH, RETURN, FINALE, OVER }

const RIDERS := 2

var tick: int = 0
var phase: Phase = Phase.INTRO
var phase_tick: int = 0
## Passes begun so far; the one being ridden is pass_count - 1.
var pass_count: int = 0
var pass_start_tick: int = 0
var riders: Array[JoustRider] = []
var events: Array[JoustEvent] = []
var winner: int = -1
var unseated: int = -1
var decided_by: JoustResult.Decision = JoustResult.Decision.POINTS


## A pass is under way from the run-up to the end of the clash.
func in_pass() -> bool:
	return phase in [Phase.RUNUP, Phase.AIM, Phase.CLASH]
