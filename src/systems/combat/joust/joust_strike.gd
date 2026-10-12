class_name JoustStrike
extends RefCounted
## How one lance meets the other rider at the impact: couched in time, which zone it hits, how
## hard (tempo) and whether the shield turned it aside.

## Rounding guard for window edges, far below a tick.
const EPSILON := 1e-6


## Scores the attacker's lance and takes the stance off the defender.
static func attack(cfg: JoustConfig, attacker: JoustRider, defender: JoustRider) -> void:
	var offset := absf(attacker.strike_offset)
	attacker.last_couched = (
		not is_nan(attacker.strike_offset) and offset <= cfg.couch_window_ms / 1000.0 + EPSILON
	)
	attacker.last_perfect = attacker.last_couched and offset <= attacker.window + EPSILON
	attacker.last_zone = zone_at(cfg, attacker.impact_tip)
	defender.last_damage_taken = 0.0
	defender.last_shielded = false
	if not attacker.last_couched or attacker.last_zone < 0:
		return
	attacker.points += cfg.zones[attacker.last_zone].points
	if attacker.last_perfect:
		attacker.points += cfg.perfect_points
	var damage := cfg.perfect_stance if attacker.last_perfect else cfg.normal_stance
	damage *= force(cfg, attacker.tempo)
	defender.last_shielded = shield_aligned(cfg, defender.impact_shield, attacker.impact_tip)
	if defender.last_shielded:
		damage *= cfg.shield_damage_factor
	defender.stance -= damage
	defender.last_damage_taken = damage


## Index of the first zone containing the tip, -1 for a miss.
static func zone_at(cfg: JoustConfig, tip: Vector2) -> int:
	for i: int in cfg.zones.size():
		var zone := cfg.zones[i]
		if tip.distance_to(zone.center) <= zone.radius:
			return i
	return -1


## Share of the stance hit a rider deals at this tempo: full from the ideal tempo up.
static func force(cfg: JoustConfig, tempo: float) -> float:
	return lerpf(cfg.min_force, 1.0, clampf(tempo / cfg.tempo_ideal, 0.0, 1.0))


## Whether the defender's shield points at the incoming tip. The tip is given as the attacker
## sees the defender, so it is mirrored into the defender's own view first.
static func shield_aligned(cfg: JoustConfig, shield: Vector2, incoming_tip: Vector2) -> bool:
	if shield.length() < cfg.shield_min_deflection:
		return false
	var toward := Vector2(-incoming_tip.x, incoming_tip.y)
	if toward.is_zero_approx():
		return true
	return absf(shield.angle_to(toward)) <= deg_to_rad(cfg.shield_tolerance_deg) + EPSILON
