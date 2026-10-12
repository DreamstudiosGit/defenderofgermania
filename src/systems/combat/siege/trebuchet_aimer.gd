class_name TrebuchetAimer
extends RefCounted
## The computer's trebuchet crew for auto-resolve and tests: it aims stones at the middle of
## the front-most standing wall or gate segment, works out the counterweight for its angle
## from the wind it allows for, then misses by a fixed error pattern of its skill (0–3). No
## dice: the same siege and seed always play out the same way.

var skill: int

var _config: SiegeConfig
var _shots: int = 0


func _init(config: SiegeConfig, skill_level: int) -> void:
	_config = config
	skill = clampi(skill_level, 0, SiegeConfig.AI_SKILLS - 1)


func aim(sim: TrebuchetSim) -> TrebuchetShot:
	var crew := _config.skills[skill]
	var target := target_part(sim.castle)
	var angle := crew.angle
	var weight := _config.start_counterweight
	if target >= 0:
		var rect := sim.castle.world_rect(target)
		var middle := (rect[1] + rect[3]) * 0.5
		weight = solve(_config, angle, sim.wind() * crew.wind_awareness, rect[0], middle)
	var errors := crew.counterweight_errors
	var tilts := crew.angle_errors
	weight += errors[_shots % errors.size()]
	angle += tilts[_shots % tilts.size()]
	_shots += 1
	return TrebuchetShot.make(
		clampi(weight, _config.counterweight_min, _config.counterweight_max),
		clampi(angle, _config.angle_min, _config.angle_max),
		TrebuchetShot.Projectile.STONE, crew.aim_seconds
	)


## Plays the whole minigame with this crew.
func play(sim: TrebuchetSim) -> TrebuchetResult:
	while not sim.is_over():
		if sim.is_counterfire_slot():
			sim.endure_counterfire()
		else:
			sim.fire(aim(sim))
	return sim.result()


## Front-most standing wall or gate segment, -1 if none stands.
static func target_part(castle: SiegeCastle) -> int:
	var best := -1
	for i: int in castle.part_count():
		if not castle.parts[i].is_breach_segment() or not castle.is_damageable(i):
			continue
		if best < 0 or castle.parts[i].x0 < castle.parts[best].x0:
			best = i
	return best


## Smallest counterweight whose stone passes x at height y or above (the path rises with the
## load), so it strikes a wall face at x from height y up.
static func solve(
	config: SiegeConfig, angle: int, wind: float, x: float, y: float,
	projectile: TrebuchetShot.Projectile = TrebuchetShot.Projectile.STONE
) -> int:
	var low := config.counterweight_min
	var high := config.counterweight_max
	if _height(config, high, angle, wind, projectile, x) < y:
		return high
	while low < high:
		@warning_ignore("integer_division")
		var middle := (low + high) / 2
		if _height(config, middle, angle, wind, projectile, x) >= y:
			high = middle
		else:
			low = middle + 1
	return low


static func _height(
	config: SiegeConfig, weight: int, angle: int, wind: float,
	projectile: TrebuchetShot.Projectile, x: float
) -> float:
	var shot := TrebuchetShot.make(weight, angle, projectile)
	return SiegeBallistics.height_at(SiegeBallistics.launch(config, shot, wind), x)
