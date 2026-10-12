class_name SiegeConfigCheck
extends RefCounted
## Consistency rules of data/combat_siege.json beyond types: ranges, the projectiles the
## minigame needs, four aimer skills and complete castle layouts whose parts share the wall HP.

const PROJECTILES: Array[String] = ["stone", "fire_pot"]


static func check(c: SiegeConfig, r: DataReader) -> void:
	_require(r, c.wall_hp_per_level > 0, "wall_hp_per_level: must be positive")
	_require(r, c.shots_base >= 1 and c.shots_per_trebuchet >= 0, "shots: base >= 1, per >= 0")
	_require(r, c.counterfire_from_wall >= 1, "counterfire.from_wall: must be at least 1")
	_require(r, c.counterfire_every >= 2, "counterfire.every: must be at least 2")
	for id: String in PROJECTILES:
		_require(r, c.projectiles.has(id), "projectiles: missing '%s'" % id)
	for id: String in c.projectiles:
		var projectile := c.projectiles[id]
		_require(r, projectile.damage >= 0, "projectiles.%s.damage: negative" % id)
		_require(
			r, projectile.garrison_damage >= 0.0 and projectile.garrison_damage <= 1.0,
			"projectiles.%s.garrison_damage: must be a share 0..1" % id
		)
		_require(r, projectile.speed_factor > 0.0, "projectiles.%s.speed_factor: must be > 0" % id)
	_require(
		r, c.burn_share_per_shot > 0.0 and c.burn_share_per_shot <= 1.0,
		"burning.share_per_shot: must be a share above 0"
	)
	_require(r, c.fall_damage_share >= 0.0, "collapse.fall_damage_share: negative")
	_require(r, c.wind_min <= c.wind_max, "wind: min above max")
	_require(r, c.wind_acceleration >= 0.0, "wind.acceleration_per_mps: negative")
	_check_ballistics(c, r)
	_require(
		r, c.aim_limit_seconds > 0.0 and c.typical_aim_seconds > 0.0 and c.throw_seconds >= 0.0
		and c.settle_seconds >= 0.0 and c.counterfire_seconds >= 0.0,
		"timing: limits must be positive and durations not negative"
	)
	var practice_error := c.practice.validate()
	_require(r, practice_error.is_empty(), "practice: %s" % practice_error)
	_check_skills(c, r)
	for key: String in SiegeConfig.LAYOUT_KEYS:
		_require(r, c.layouts.has(key), "layouts: missing '%s'" % key)
	for key: String in c.layouts:
		_check_layout(c, r, key)


static func _check_ballistics(c: SiegeConfig, r: DataReader) -> void:
	_require(r, c.gravity > 0.0, "ballistics.gravity: must be positive")
	_require(r, c.release.y >= 0.0, "ballistics.release: below the ground")
	_require(r, c.speed_min > 0.0 and c.speed_max > c.speed_min, "ballistics: speed range")
	_require(r, c.counterweight_min < c.counterweight_max, "ballistics.counterweight: range")
	_require(
		r, c.angle_min > 0 and c.angle_min < c.angle_max and c.angle_max < 90,
		"ballistics.angle_deg: range must lie within 0..90"
	)
	_require(
		r, c.start_counterweight >= c.counterweight_min
		and c.start_counterweight <= c.counterweight_max
		and c.start_angle >= c.angle_min and c.start_angle <= c.angle_max,
		"ballistics.start: outside the ranges"
	)
	_require(r, c.step_rate >= 30, "ballistics.step_rate: at least 30 steps per second")
	_require(r, c.max_flight_seconds > 0.0, "ballistics.max_flight_seconds: must be positive")
	_require(
		r, c.preview_share > 0.0 and c.preview_share <= 1.0, "ballistics.preview_share: share"
	)
	_require(r, c.castle_front > c.release.x, "ballistics.castle_front: before the trebuchet")


static func _check_skills(c: SiegeConfig, r: DataReader) -> void:
	_require(r, c.skills.size() == SiegeConfig.AI_SKILLS, "ai.skills: expected one per skill 0-3")
	_require(
		r, c.campaign_skill >= 0 and c.campaign_skill < SiegeConfig.AI_SKILLS,
		"ai.campaign_skill: expected 0-3"
	)
	for i: int in c.skills.size():
		var skill := c.skills[i]
		_require(
			r, not skill.counterweight_errors.is_empty() and not skill.angle_errors.is_empty(),
			"ai.skills[%d]: error patterns must not be empty" % i
		)
		_require(
			r, skill.angle >= c.angle_min and skill.angle <= c.angle_max,
			"ai.skills[%d].angle_deg: outside the angle range" % i
		)
		_require(
			r, skill.wind_awareness >= 0.0 and skill.wind_awareness <= 1.0,
			"ai.skills[%d].wind_awareness: must be a share 0..1" % i
		)


static func _check_layout(c: SiegeConfig, r: DataReader, key: String) -> void:
	var parts := c.layout(key)
	var ids: Array[String] = []
	var total := 0.0
	var segments := 0
	for part: SiegeConfig.PartDef in parts:
		var at := "layouts.%s.%s" % [key, part.id]
		_require(r, not part.id.is_empty() and part.id not in ids, "%s: id empty or twice" % at)
		ids.append(part.id)
		_require(r, part.kind in SiegeConfig.KINDS, "%s.kind: unknown '%s'" % [at, part.kind])
		_require(
			r, part.material in SiegeConfig.MATERIALS,
			"%s.material: unknown '%s'" % [at, part.material]
		)
		_require(r, part.x1 > part.x0 and part.y1 > part.y0, "%s.rect: empty" % at)
		_require(r, part.y0 >= 0.0, "%s.rect: below the ground" % at)
		if part.is_solid_only():
			_require(r, part.hp_share == 0.0, "%s.hp_share: a mound takes no damage" % at)
		else:
			_require(r, part.hp_share > 0.0, "%s.hp_share: must be positive" % at)
		total += part.hp_share
		if part.is_breach_segment():
			segments += 1
	for part: SiegeConfig.PartDef in parts:
		var at := "layouts.%s.%s" % [key, part.id]
		for other: String in part.supported_by + part.falls_onto:
			_require(
				r, other in ids and other != part.id, "%s: unknown neighbour '%s'" % [at, other]
			)
	_require(
		r, absf(total - 1.0) <= SiegeConfig.SHARE_TOLERANCE,
		"layouts.%s: hp_share must add up to 1 (is %.3f)" % [key, total]
	)
	_require(r, segments > 0, "layouts.%s: needs a wall or gate segment" % key)


static func _require(r: DataReader, condition: bool, message: String) -> void:
	if not condition:
		r.errors.append(message)
