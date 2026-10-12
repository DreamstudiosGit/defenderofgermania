class_name SiegeCastle
extends RefCounted
## The besieged castle as rules see it: kit parts in the side view with whole-number HP (the
## wall's HP spread by hp_share), stone damage, burning wood and the data-driven collapse —
## a destroyed part brings down every part resting on it and crashes onto its `falls_onto`
## neighbours for fall_damage_share of its own HP, which can bring those down in turn. The
## first wall or gate segment at 0 opens the breach.

var parts: Array[SiegeConfig.PartDef] = []
## Distance of the castle front from the trebuchet.
var front: float
var wall_hp: int
var max_hp := PackedInt32Array()
var start_hp := PackedInt32Array()
var hp := PackedInt32Array()
var burning := PackedByteArray()
var destroyed := PackedByteArray()
var causes := PackedInt32Array()
## Index of the segment that opened the breach, -1 while the wall holds.
var breach: int = -1

var _config: SiegeConfig
var _events: Array[SiegeEvent] = []
var _index: Dictionary[String, int] = {}


## Earlier rounds' damage (a share of the wall's HP) is spread evenly over the parts.
func _init(
	config: SiegeConfig, layout: Array[SiegeConfig.PartDef], wall_level: int,
	prior_damage: float = 0.0
) -> void:
	_config = config
	parts = layout
	front = config.castle_front
	wall_hp = config.wall_hp(wall_level)
	var count := parts.size()
	max_hp.resize(count)
	start_hp.resize(count)
	hp.resize(count)
	causes.resize(count)
	burning.resize(count)
	destroyed.resize(count)
	for i: int in count:
		_index[parts[i].id] = i
		max_hp[i] = roundi(parts[i].hp_share * wall_hp)
		var left := max_hp[i]
		if parts[i].is_solid_only():
			left = 0
		elif prior_damage >= 1.0:
			left = 0
		elif prior_damage > 0.0:
			left = maxi(1, roundi(max_hp[i] * (1.0 - prior_damage)))
		start_hp[i] = left
		hp[i] = left
	for i: int in count:
		if not parts[i].is_solid_only() and hp[i] <= 0 and destroyed[i] == 0:
			_collapse(i, SiegeEvent.Cause.NONE)
	_events.clear()


func part_count() -> int:
	return parts.size()


func index_of(id: String) -> int:
	return _index.get(id, -1)


## Whether the part still stands in the way of projectiles (mounds always do).
func blocks(i: int) -> bool:
	return destroyed[i] == 0


func is_damageable(i: int) -> bool:
	return not parts[i].is_solid_only() and destroyed[i] == 0


## [left, bottom, right, top] in metres from the trebuchet.
func world_rect(i: int) -> PackedFloat64Array:
	var part := parts[i]
	return PackedFloat64Array([front + part.x0, part.y0, front + part.x1, part.y1])


## Distance of the rear end of the castle from the trebuchet.
func back() -> float:
	var result := front
	for part: SiegeConfig.PartDef in parts:
		result = maxf(result, front + part.x1)
	return result


## HP the parts lost since the castle was set up (overkill not counted).
func damage_dealt() -> int:
	var total := 0
	for i: int in parts.size():
		total += start_hp[i] - hp[i]
	return total


## A stone: damage to the part it hits.
func strike(i: int, damage: int) -> void:
	if not is_damageable(i):
		return
	var dealt := mini(damage, hp[i])
	hp[i] -= dealt
	_events.append(SiegeEvent.make(SiegeEvent.Kind.HIT, i, dealt))
	if hp[i] <= 0:
		_collapse(i, SiegeEvent.Cause.HIT)


## A fire pot: wooden parts catch fire.
func ignite(i: int) -> void:
	if not is_damageable(i) or parts[i].material != SiegeConfig.WOOD or burning[i] == 1:
		return
	burning[i] = 1
	_events.append(SiegeEvent.make(SiegeEvent.Kind.IGNITED, i))


## End of a shot: every burning part loses its share of HP; burnt parts come down.
func burn() -> void:
	for i: int in parts.size():
		if burning[i] == 0 or not is_damageable(i):
			continue
		var loss := mini(maxi(1, roundi(max_hp[i] * _config.burn_share_per_shot)), hp[i])
		hp[i] -= loss
		_events.append(SiegeEvent.make(SiegeEvent.Kind.BURNED, i, loss))
		if hp[i] <= 0:
			_collapse(i, SiegeEvent.Cause.BURNT)


## Events since the last call, in the order they happened.
func take_events() -> Array[SiegeEvent]:
	var events := _events
	_events = []
	return events


func _collapse(first: int, cause: SiegeEvent.Cause) -> void:
	var queue: Array[int] = [first]
	destroyed[first] = 1
	causes[first] = cause
	while not queue.is_empty():
		var p: int = queue.pop_front()
		hp[p] = 0
		burning[p] = 0
		_events.append(SiegeEvent.make(SiegeEvent.Kind.DESTROYED, p, 0.0, -1, causes[p]))
		if breach < 0 and parts[p].is_breach_segment():
			breach = p
			_events.append(SiegeEvent.make(SiegeEvent.Kind.BREACH, p))
		for q: int in parts.size():
			if is_damageable(q) and parts[p].id in parts[q].supported_by:
				destroyed[q] = 1
				causes[q] = SiegeEvent.Cause.FELL
				queue.append(q)
		var weight := roundi(max_hp[p] * _config.fall_damage_share)
		for id: String in parts[p].falls_onto:
			var q := index_of(id)
			if q < 0 or not is_damageable(q):
				continue
			var dealt := mini(weight, hp[q])
			hp[q] -= dealt
			_events.append(SiegeEvent.make(SiegeEvent.Kind.CRUSHED, q, dealt, p))
			if hp[q] <= 0:
				destroyed[q] = 1
				causes[q] = SiegeEvent.Cause.CRUSHED
				queue.append(q)
