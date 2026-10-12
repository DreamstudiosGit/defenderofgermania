class_name MerchantState
extends RefCounted
## Merchant train raid state as packed arrays: one entry per wagon, escort and company.
## Positions are metres along the road, x towards the town gate. The raid systems mutate it;
## render/ui only read it.

enum Phase { INTRO, RAID, OVER }
enum Wagon { ROLLING, STOPPED, ARRIVED }
## How a wagon came to a halt: its driver pulled off the box, or its harness cut by a bolt.
enum Stop { NONE, DRIVER, HARNESS }
## An escort's pattern runs COVER → WINDUP → blow → RECOVER; STAGGERED after a parried blow,
## DOWN in the ditch after losing his guard, BOUND while a company holds him.
enum Escort { PATROL, APPROACH, COVER, WINDUP, RECOVER, STAGGERED, DOWN, BOUND }
enum Company { HIDDEN, RUNNING, FIGHTING, PULLING, IDLE }

## The leader as the actor of an event or the target of an escort.
const LEADER := -1

var tick: int = 0
var phase: int = Phase.INTRO
var raid_ticks: int = 0
var gate_x: float = 0.0
## Events of the last tick, for the presentation only.
var events: Array[MerchantEvent] = []

var wagon_x := PackedFloat64Array()
var wagon_status := PackedInt32Array()
var wagon_stop := PackedInt32Array()
## Who stopped the wagon: LEADER or a company index.
var wagon_raider := PackedInt32Array()
var wagon_value := PackedInt32Array()

var leader_x: float = 0.0
var leader_velocity: float = 0.0
## +1 facing the gate, -1 facing back; the crossbow shoots this way.
var leader_facing: int = 1
var composure: int = 0
var captured: bool = false
var stun: float = 0.0
var strike_cooldown: float = 0.0
## Seconds the parry stays open, and until the next parry.
var parry_open: float = 0.0
var parry_cooldown: float = 0.0
var pull_wagon: int = -1
var pull_progress: float = 0.0
## Seconds until the crossbow is spanned again, and the bolts left.
var reload: float = 0.0
var bolts: int = 0
var sway_phase: float = 0.0

var escort_x := PackedFloat64Array()
var escort_state := PackedInt32Array()
var escort_timer := PackedFloat64Array()
var escort_guard := PackedFloat64Array()
## The wagon each escort walks beside, and where: near its driver's box.
var escort_post := PackedInt32Array()
var escort_post_offset := PackedFloat64Array()
## LEADER or the company index the escort goes for.
var escort_target := PackedInt32Array()

var company_unit := PackedStringArray()
var company_x := PackedFloat64Array()
var company_state := PackedInt32Array()
var company_timer := PackedFloat64Array()
## The escort a company fights or the wagon whose driver it pulls.
var company_target := PackedInt32Array()
var company_ambush_x := PackedFloat64Array()
var company_speed := PackedFloat64Array()
## Fight seconds against an escort of reference guard, from the unit's melee.
var company_fight := PackedFloat64Array()


func wagon_count() -> int:
	return wagon_x.size()


func escort_count() -> int:
	return escort_x.size()


func company_count() -> int:
	return company_x.size()


func is_rolling(w: int) -> bool:
	return wagon_status[w] == Wagon.ROLLING


func count_wagons(status: Wagon) -> int:
	var count := 0
	for w: int in wagon_count():
		if wagon_status[w] == status:
			count += 1
	return count


## Taler on the stopped wagons.
func loot() -> int:
	var total := 0
	for w: int in wagon_count():
		if wagon_status[w] == Wagon.STOPPED:
			total += wagon_value[w]
	return total


## Escorts on their feet and free: neither in the ditch nor held by a company.
func escort_free(e: int) -> bool:
	return escort_state[e] != Escort.DOWN and escort_state[e] != Escort.BOUND


func checksum() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(var_to_bytes([
		tick, phase, raid_ticks, wagon_x, wagon_status, wagon_stop, wagon_raider, wagon_value,
		leader_x, leader_velocity, leader_facing, composure, captured, stun, strike_cooldown,
		parry_open, parry_cooldown, pull_wagon, pull_progress, reload, bolts, sway_phase,
		escort_x, escort_state, escort_timer, escort_guard, escort_post, escort_target,
		company_x, company_state, company_timer, company_target,
	]))
	return hashing.finish().hex_encode()
