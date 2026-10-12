class_name MerchantView
extends Node3D
## Draws a MerchantSim between its ticks: the train, the people and the comic effects, with
## positions interpolated from the last tick, and turns the raid's events into effects.

const GOLD := Color(1.0, 0.84, 0.3)
const RED := Color(1.0, 0.42, 0.32)
const STEEL := Color(0.86, 0.9, 0.95)
const GREY := Color(0.75, 0.72, 0.68)
const BRAWL_INTERVAL := 0.35

var wagons: MerchantWagons = null
var people: MerchantPeople = null
var effects := MerchantEffects.new()

var _sim: MerchantSim
var _previous_wagons := PackedFloat64Array()
var _previous_leader: float = 0.0
var _previous_escorts := PackedFloat64Array()
var _previous_companies := PackedFloat64Array()
var _brawl_clock: float = 0.0


func _ready() -> void:
	add_child(effects)


func setup(sim: MerchantSim, house_colors: PackedColorArray, neutral: PackedColorArray) -> void:
	_sim = sim
	if wagons != null:
		wagons.queue_free()
		people.queue_free()
	wagons = MerchantWagons.new()
	people = MerchantPeople.new()
	add_child(wagons)
	add_child(people)
	wagons.setup(sim, neutral)
	people.setup(sim, house_colors, neutral)
	effects.clear()
	snapshot()


## Positions before the next tick, the start of the interpolation.
func snapshot() -> void:
	var s := _sim.state
	_previous_wagons = s.wagon_x.duplicate()
	_previous_leader = s.leader_x
	_previous_escorts = s.escort_x.duplicate()
	_previous_companies = s.company_x.duplicate()


## alpha: share of the tick since the last step; time: seconds for the motion clocks.
func update_view(alpha: float, time: float, delta: float) -> void:
	var s := _sim.state
	wagons.update_view(_sim, _lerp(_previous_wagons, s.wagon_x, alpha), time)
	var leader_x := lerpf(_previous_leader, s.leader_x, alpha)
	var escort_x := _lerp(_previous_escorts, s.escort_x, alpha)
	var company_x := _lerp(_previous_companies, s.company_x, alpha)
	people.update_view(_sim, leader_x, escort_x, company_x, time, delta)
	_brawl_clock -= delta
	if _brawl_clock <= 0.0:
		_brawl_clock = BRAWL_INTERVAL
		for brawl: Vector3 in people.brawls:
			effects.dust(brawl, 3, 1.2)
	var dazed := wagons.dazed.duplicate()
	dazed.append_array(people.dazed)
	effects.update_view(dazed, time, delta)


## The events of the last tick as effects.
func play_events(events: Array[MerchantEvent]) -> void:
	var s := _sim.state
	var leader := Vector3(s.leader_x, 2.6, MerchantPeople.LEADER_Z)
	for event: MerchantEvent in events:
		var escort := Vector3.ZERO
		if event.escort >= 0:
			escort = Vector3(s.escort_x[event.escort], 2.4, MerchantPeople.ESCORT_FIGHT_Z)
		match event.kind:
			MerchantEvent.Kind.DRIVER_PULLED:
				var box := Vector3(_sim.box_x(event.wagon), 2.4, 0.5)
				effects.popup(tr("MERCHANT_POP_DRIVER"), box, GOLD)
				effects.dust(box, 6, 1.0)
			MerchantEvent.Kind.HARNESS_CUT, MerchantEvent.Kind.BOLT_MISSED:
				_shot(event)
			MerchantEvent.Kind.STRIKE:
				people.lunge()
			MerchantEvent.Kind.BLOCKED:
				effects.popup(tr("MERCHANT_POP_BLOCKED"), escort, STEEL)
			MerchantEvent.Kind.ESCORT_HIT:
				effects.popup(tr("MERCHANT_POP_HIT"), escort, GOLD)
				effects.dust(escort, 3, 0.6)
			MerchantEvent.Kind.ESCORT_DOWN:
				effects.popup(tr("MERCHANT_POP_DOWN"), escort, GOLD)
				effects.dust(escort, 8, 1.2)
			MerchantEvent.Kind.PARRIED:
				effects.popup(tr("MERCHANT_POP_PARRIED"), leader, GOLD)
			MerchantEvent.Kind.LEADER_HIT:
				effects.popup(tr("MERCHANT_POP_OUCH"), leader, RED)
				people.shake()
			MerchantEvent.Kind.AMBUSH:
				var hideout := Vector3(s.company_x[event.raider], 1.8, MerchantPeople.HIDE_Z)
				effects.dust(hideout, 10, 1.6)
			MerchantEvent.Kind.WAGON_ARRIVED:
				var gate := Vector3(s.gate_x, 3.0, 0.0)
				effects.popup(tr("MERCHANT_POP_LOST") % s.wagon_value[event.wagon], gate, GREY)


func _shot(event: MerchantEvent) -> void:
	var s := _sim.state
	var from := Vector3(s.leader_x, 2.3, MerchantPeople.LEADER_Z)
	var to := from + Vector3(s.leader_facing * 9.0, -2.3, -1.0)
	if event.wagon >= 0:
		to = Vector3(_sim.horses_x(event.wagon) - 0.4, 1.3, 0.0)
	effects.bolt(from, to)
	if event.kind == MerchantEvent.Kind.HARNESS_CUT:
		effects.popup(tr("MERCHANT_POP_CUT"), to + Vector3.UP, GOLD)
		effects.dust(to, 5, 0.8)
	else:
		effects.popup(tr("MERCHANT_POP_MISS"), to + Vector3.UP, GREY)


static func _lerp(
	previous: PackedFloat64Array, current: PackedFloat64Array, alpha: float
) -> PackedFloat64Array:
	if previous.size() != current.size():
		return current
	var result := PackedFloat64Array()
	result.resize(current.size())
	for i: int in current.size():
		result[i] = lerpf(previous[i], current[i], alpha)
	return result
