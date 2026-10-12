class_name BattleState
extends RefCounted
## Real-time battle state as packed arrays: one entry per company or per figure. Positions are
## meters on the field (x to the right, y towards the camera), facings radians (0 = +x).
## A side's leader is a one-figure company after its regular companies (setup_index -1).
## The battle systems mutate it; render/ui only read it.

enum Phase { DEPLOY, FIGHT, OVER }
enum Status { ACTIVE, FLEEING, FLED, DESTROYED, CAPTURED }
enum Order { HOLD, MOVE, STICK, CHARGE, CAV_CHARGE, FIRE }
enum Group { INFANTRY, ARCHERS, CAVALRY, SIEGE }

const SIDES := 2
const NO_TICK := -1000000

var tick: int = 0
var phase: int = Phase.DEPLOY
var winner: int = -1
var timed_out: bool = false
## Events of the last tick, for the presentation only.
var events: Array[BattleEvent] = []

var stats: Array[CombatConfig.UnitStats] = []
var unit_ids: PackedStringArray = []
var side: PackedInt32Array = []
var group: PackedInt32Array = []
var setup_index: PackedInt32Array = []
var start_morale: PackedFloat64Array = []
var max_hp: PackedFloat64Array = []

var pos: PackedVector2Array = []
var facing: PackedFloat64Array = []
var speed: PackedFloat64Array = []
## Collision radius from formation and living figures, refreshed every tick.
var radius: PackedFloat64Array = []
var hp: PackedFloat64Array = []
var morale: PackedFloat64Array = []
## Sum of one-off morale changes (flank attacks, captured leader, rally).
var shock: PackedFloat64Array = []
var status: PackedInt32Array = []
var order: PackedInt32Array = []
## Target point for MOVE and HOLD, direction for STICK and CAV_CHARGE.
var order_point: PackedVector2Array = []
var order_target: PackedInt32Array = []
var charge_run: PackedFloat64Array = []
var formation: PackedInt32Array = []
var bolts: PackedInt32Array = []
var reload_timer: PackedFloat64Array = []
var volley_cooldown: PackedFloat64Array = []
var fire_pending: PackedByteArray = []
## Siege engines: the target circle on the ground and the stone in flight (timer < 0: none).
var aim_point: PackedVector2Array = []
var shot_point: PackedVector2Array = []
var shot_timer: PackedFloat64Array = []
## Enemy company this one fights in melee this tick, -1 for none.
var contact: PackedInt32Array = []
var last_contact_tick: PackedInt32Array = []
var fig_start: PackedInt32Array = []
var fig_count: PackedInt32Array = []

var fig_pos: PackedVector2Array = []
var fig_jitter: PackedVector2Array = []
var fig_company: PackedInt32Array = []

var leader := PackedInt32Array([-1, -1])
var active_group := PackedInt32Array([0, 0])
var stick_held := PackedByteArray([0, 0])
var rally_cooldown := PackedFloat64Array([0.0, 0.0])
## Groups each side brought, in Group order; their shields stay even when emptied.
var side_groups: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]


func company_count() -> int:
	return pos.size()


func is_present(company: int) -> bool:
	return status[company] == Status.ACTIVE or status[company] == Status.FLEEING


func is_leader(company: int) -> bool:
	return setup_index[company] < 0


## Figures still standing; at least one while the company has health left.
func alive_figures(company: int) -> int:
	if not is_present(company) or hp[company] <= 0.0:
		return 0
	return clampi(ceili(hp[company] / max_hp[company] * fig_count[company]), 1, fig_count[company])


func members(of_side: int, of_group: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for c: int in company_count():
		if side[c] == of_side and group[c] == of_group:
			result.append(c)
	return result


## Members of the group that still take orders.
func active_members(of_side: int, of_group: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for c: int in members(of_side, of_group):
		if status[c] == Status.ACTIVE:
			result.append(c)
	return result


func facing_vector(company: int) -> Vector2:
	return Vector2.from_angle(facing[company])


func fight_ticks(deploy_ticks: int) -> int:
	return maxi(0, tick - deploy_ticks)


## SHA-256 over everything that evolves; equal for equal setup, seed and inputs.
func checksum() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(var_to_bytes(_snapshot()))
	return hashing.finish().hex_encode()


func _snapshot() -> Array:
	return [
		tick, phase, winner, timed_out, pos, facing, speed, radius, hp, morale, shock, status,
		order, order_point, order_target, charge_run, formation, bolts, reload_timer,
		volley_cooldown, fire_pending, aim_point, shot_point, shot_timer, contact,
		last_contact_tick, fig_pos, leader, active_group, stick_held, rally_cooldown,
	]
