class_name TrebuchetSim
extends RefCounted
## The whole trebuchet minigame, one shot at a time: shots = 3 + 2 × trebuchets, from wall
## level 3 the counterfire costs every third one; the wind of every shot is rolled from the
## seed up front and shown before aiming. Each shot flies, hits, damages or sets fire, the
## castle collapses by its rules, fires burn on; a breach ends the bombardment at once.

class ShotReport:
	## 1-based shot number.
	var slot: int
	var shot: TrebuchetShot
	var wind: float
	var path: SiegeBallistics.Launch
	var impact: SiegeBallistics.Impact
	## Whether the shot struck the castle (a part, or the bailey for a fire pot).
	var hit: bool
	var events: Array[SiegeEvent] = []


var config: SiegeConfig
var setup: TrebuchetSetup
## Null when the setup was invalid; the minigame is then over before it starts.
var castle: SiegeCastle
var garrison_health: float
## Current shot, 1-based; above `slots` once all shots are used.
var slot: int = 1
var slots: int = 0
var shots_fired: int = 0
var shots_lost: int = 0
var hits: int = 0
var play_seconds: float = 0.0
var error: String = ""

var _winds := PackedFloat64Array()


func _init(siege_config: SiegeConfig, trebuchet_setup: TrebuchetSetup, seed_value: int) -> void:
	config = siege_config
	setup = trebuchet_setup.duplicate_setup()
	garrison_health = setup.garrison_health
	error = setup.validate()
	if not error.is_empty():
		push_error("trebuchet: %s" % error)
		return
	castle = SiegeCastle.new(
		config, config.layout(setup.layout_key()), setup.wall_level, setup.wall_damage
	)
	slots = config.shots(setup.trebuchets)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var low := roundi(config.wind_min * 10.0)
	var high := roundi(config.wind_max * 10.0)
	for i: int in slots:
		_winds.append(rng.randi_range(low, high) / 10.0)


func is_over() -> bool:
	return castle == null or castle.breach >= 0 or slot > slots


## Wind of the current shot in m/s; positive blows towards the castle.
func wind() -> float:
	return _winds[slot - 1] if slot >= 1 and slot <= slots else 0.0


func is_counterfire_slot() -> bool:
	return not is_over() and config.is_counterfire_slot(slot, setup.wall_level)


## Throws still to come, without those the counterfire will cost.
func shots_left() -> int:
	var count := 0
	for s: int in range(slot, slots + 1):
		if not config.is_counterfire_slot(s, setup.wall_level):
			count += 1
	return count if not is_over() else 0


## The defenders' counterfire costs this shot; fires burn on meanwhile.
func endure_counterfire() -> Array[SiegeEvent]:
	var events: Array[SiegeEvent] = []
	if not is_counterfire_slot():
		return events
	events.append(SiegeEvent.make(SiegeEvent.Kind.COUNTERFIRE))
	shots_lost += 1
	play_seconds += config.counterfire_seconds
	castle.burn()
	events.append_array(castle.take_events())
	slot += 1
	return events


## The shot as the trebuchet can throw it: loads and angles outside its ranges are clamped.
func sanitized(shot: TrebuchetShot) -> TrebuchetShot:
	var seconds := shot.aim_seconds if shot.aim_seconds >= 0.0 else config.typical_aim_seconds
	return TrebuchetShot.make(
		clampi(shot.counterweight, config.counterweight_min, config.counterweight_max),
		clampi(shot.angle, config.angle_min, config.angle_max),
		shot.projectile, clampf(seconds, 0.0, config.aim_limit_seconds)
	)


func path_for(shot: TrebuchetShot) -> SiegeBallistics.Launch:
	return SiegeBallistics.launch(config, sanitized(shot), wind())


## What the player sees before throwing: the first 20 % of the flight.
func preview(shot: TrebuchetShot) -> PackedVector2Array:
	return SiegeBallistics.preview(path_for(shot), config.preview_share)


## Throws the shot of the current slot (counterfire slots before it are endured first).
func fire(input: TrebuchetShot) -> ShotReport:
	var report := ShotReport.new()
	while is_counterfire_slot():
		report.events.append_array(endure_counterfire())
	if is_over():
		return report
	var shot := sanitized(input)
	report.slot = slot
	report.shot = shot
	report.wind = wind()
	report.path = SiegeBallistics.launch(config, shot, report.wind)
	report.impact = SiegeBallistics.trace(config, report.path, castle)
	report.hit = _apply(shot, report.impact, report.events)
	if report.hit:
		hits += 1
	if castle.breach < 0:
		castle.burn()
	report.events.append_array(castle.take_events())
	shots_fired += 1
	play_seconds += (
		shot.aim_seconds + config.throw_seconds + report.impact.time + config.settle_seconds
	)
	slot += 1
	return report


func result() -> TrebuchetResult:
	var result := TrebuchetResult.new()
	result.shots_fired = shots_fired
	result.shots_lost = shots_lost
	result.hits = hits
	result.duration_seconds = play_seconds
	result.garrison_damage = setup.garrison_health - garrison_health
	result.wall_damage = setup.wall_damage
	if castle == null:
		return result
	result.wall_damage_dealt = float(castle.damage_dealt()) / castle.wall_hp
	result.wall_damage = minf(1.0, setup.wall_damage + result.wall_damage_dealt)
	if castle.breach >= 0:
		var part := castle.parts[castle.breach]
		result.breach = true
		result.breach_part = part.id
		result.breach_kind = part.kind
	return result


func _apply(
	shot: TrebuchetShot, impact: SiegeBallistics.Impact, events: Array[SiegeEvent]
) -> bool:
	var projectile := config.projectiles[shot.projectile_id()]
	var inside := impact.x >= castle.front and impact.x <= castle.back()
	if impact.part < 0:
		if not inside:
			var kind := SiegeEvent.Kind.MISS_SHORT
			if impact.x > castle.back():
				kind = SiegeEvent.Kind.MISS_LONG
			events.append(SiegeEvent.make(kind))
			return false
		events.append(SiegeEvent.make(SiegeEvent.Kind.YARD))
	var struck := impact.part >= 0 and castle.is_damageable(impact.part)
	if struck and projectile.damage > 0:
		castle.strike(impact.part, projectile.damage)
	if struck and projectile.ignites:
		castle.ignite(impact.part)
	if projectile.garrison_damage > 0.0:
		var lost := minf(projectile.garrison_damage, garrison_health)
		garrison_health -= lost
		events.append(SiegeEvent.make(SiegeEvent.Kind.GARRISON, -1, lost))
		return true
	return struck
