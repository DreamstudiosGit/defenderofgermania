class_name RaidSetup
extends RefCounted
## What the campaign hands a castle raid. RaidSim validates it and refuses to play a broken one.

## Raiding house (its colours and crest; the leader wears them).
var raider_house: String = "wittelsbacher"
## Leader's blade value (GDD "Häuser & Anführer").
var blade: int = 3
## One of RaidConfig.TARGETS.
var target: String = "treasury"
## Owner of the castle: a house id, or "neutral", "church", "elector".
var defender_owner: String = "welfen"
## Castle level: home castles 1–5, province castles 1–3 (data "castles").
var castle_level: int = 2
var home_castle: bool = false
## Guard skill 0–3 (fixed patterns, data "guards.skills").
var guard_skill: int = 1
## Practice raids count for nothing in the campaign.
var practice: bool = false


func validate(cfg: RaidConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if raider_house.is_empty() or defender_owner.is_empty():
		errors.append("raider_house and defender_owner must be set")
	elif raider_house == defender_owner:
		errors.append("a house cannot raid its own castle")
	if blade < 0 or blade > cfg.max_blade:
		errors.append("blade must be 0–%d, got %d" % [cfg.max_blade, blade])
	if target not in RaidConfig.TARGETS:
		errors.append("unknown target '%s'" % target)
	if cfg.castle(home_castle, castle_level) == null:
		errors.append("no raid rules for castle level %d (home: %s)" % [castle_level, home_castle])
	if guard_skill < 0 or guard_skill >= RaidConfig.SKILLS:
		errors.append("guard_skill must be 0–%d, got %d" % [RaidConfig.SKILLS - 1, guard_skill])
	return errors


func copy() -> RaidSetup:
	var other := RaidSetup.new()
	other.raider_house = raider_house
	other.blade = blade
	other.target = target
	other.defender_owner = defender_owner
	other.castle_level = castle_level
	other.home_castle = home_castle
	other.guard_skill = guard_skill
	other.practice = practice
	return other
