class_name RaidRules
extends RefCounted
## Typed sections of data/combat_raid.json, read and checked by RaidConfig.

## Strike and parry heights; RaidFighter.Height indexes this list.
const HEIGHTS: Array[String] = ["high", "mid", "low"]
const MIN_GUARDS := 3
const MAX_GUARDS := 6


## Fixed behaviour of a guard of one skill (0–3): no dice, only patterns that repeat.
class GuardSkill:
	var health: float
	var damage: float
	var idle_ms: float
	var windup_ms: float
	var recover_ms: float
	var open_ms: float
	var stance_ms: float
	## 0: never re-aligns its guard to the leader's blow.
	var react_ms: float
	## After a hit the guard holds its guard at the height it was hit.
	var adapts: bool
	var attacks := PackedInt32Array()
	var stances := PackedInt32Array()
	var reacts: Array[bool] = []

	static func read(r: DataReader, entry: Dictionary) -> GuardSkill:
		var skill := GuardSkill.new()
		skill.health = r.number(entry, "health")
		skill.damage = r.number(entry, "damage")
		skill.idle_ms = r.number(entry, "idle_ms")
		skill.windup_ms = r.number(entry, "windup_ms")
		skill.recover_ms = r.number(entry, "recover_ms")
		skill.open_ms = r.number(entry, "open_ms")
		skill.stance_ms = r.number(entry, "stance_ms")
		skill.react_ms = r.number(entry, "react_ms")
		skill.adapts = r.flag(entry, "adapts")
		skill.attacks = RaidRules.heights(r, entry, "attacks")
		skill.stances = RaidRules.heights(r, entry, "stances")
		skill.reacts = RaidRules.flags(r, entry, "reacts")
		if skill.health <= 0.0 or skill.windup_ms <= 0.0 or skill.idle_ms <= 0.0:
			r.errors.append("%s: health, windup_ms and idle_ms must be positive" % r.context)
		return skill


## What a castle of one level puts in the raider's way.
class Castle:
	var guards: int
	var sneak_paths: int
	var reinforcements: int

	static func read_table(r: DataReader, table: Dictionary) -> Dictionary[int, Castle]:
		var result: Dictionary[int, Castle] = {}
		for key: String in table:
			if not key.is_valid_int():
				r.errors.append("%s: level '%s' is not a whole number" % [r.context, key])
				continue
			var entry: Variant = table[key]
			var castle := Castle.new()
			var data: Dictionary = entry if entry is Dictionary else {}
			castle.guards = r.integer(data, "guards")
			castle.sneak_paths = r.integer(data, "sneak_paths")
			castle.reinforcements = r.integer(data, "reinforcements")
			result[key.to_int()] = castle
		return result

	func check(r: DataReader, level: int) -> void:
		if guards < RaidRules.MIN_GUARDS or guards > RaidRules.MAX_GUARDS:
			r.errors.append("castles level %d: guards must be 3–6 (GDD)" % level)
		if sneak_paths >= guards:
			r.errors.append("castles level %d: at least one guard must stand without a sneak path" % level)


## Distances along the corridor (metres) and the time a sneak path takes.
class Layout:
	var entry_length: float
	var post_spacing: float
	var door_gap: float
	var room_length: float
	var deed_at: float
	var sneak_before: float
	var sneak_after: float
	var sneak_seconds: float
	var reinforcement_interval_seconds: float

	static func read(r: DataReader, data: Dictionary) -> Layout:
		var layout := Layout.new()
		layout.entry_length = r.number(data, "entry_length")
		layout.post_spacing = r.number(data, "post_spacing")
		layout.door_gap = r.number(data, "door_gap")
		layout.room_length = r.number(data, "room_length")
		layout.deed_at = r.number(data, "deed_at")
		layout.sneak_before = r.number(data, "sneak_before")
		layout.sneak_after = r.number(data, "sneak_after")
		layout.sneak_seconds = r.number(data, "sneak_seconds")
		layout.reinforcement_interval_seconds = r.number(data, "reinforcement_interval_seconds")
		if layout.sneak_before + layout.sneak_after >= layout.post_spacing:
			r.errors.append("layout: sneak paths of neighbouring posts must not overlap")
		return layout


## Deed time and reward of one target.
class Target:
	var deed_seconds: float
	var prestige: float
	var taler_share: float
	var taler_max: float
	var grain_loss: float

	static func read(r: DataReader, data: Dictionary) -> Target:
		var target := Target.new()
		target.deed_seconds = r.number(data, "deed_seconds")
		target.prestige = r.number(data, "prestige")
		target.taler_share = r.number(data, "taler_share", 0.0)
		target.taler_max = r.number(data, "taler_max", 0.0)
		target.grain_loss = r.number(data, "grain_loss", 0.0)
		return target


## Fixed error pattern of the computer leader of one skill (0–3).
class AiSkill:
	const PARRIES: Array[String] = ["ok", "late", "early", "wrong"]

	var parries := PackedInt32Array()
	var reads_stance: bool
	var strikes := PackedInt32Array()
	var riposte: bool
	var sneaks: Array[bool] = []

	static func read(r: DataReader, data: Dictionary) -> AiSkill:
		var skill := AiSkill.new()
		for word: String in r.strings(data, "parries"):
			if word in PARRIES:
				skill.parries.append(PARRIES.find(word))
			else:
				r.errors.append("%s.parries: unknown '%s'" % [r.context, word])
		skill.reads_stance = r.flag(data, "reads_stance")
		skill.strikes = RaidRules.heights(r, data, "strikes")
		skill.riposte = r.flag(data, "riposte")
		skill.sneaks = RaidRules.flags(r, data, "sneaks")
		if skill.parries.is_empty():
			r.errors.append("%s.parries: needs at least one entry" % r.context)
		return skill


static func heights(r: DataReader, data: Dictionary, key: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	for word: String in r.strings(data, key):
		if word in HEIGHTS:
			result.append(HEIGHTS.find(word))
		else:
			r.errors.append("%s.%s: unknown height '%s'" % [r.context, key, word])
	if result.is_empty():
		r.errors.append("%s.%s: needs at least one height" % [r.context, key])
	return result


static func flags(r: DataReader, data: Dictionary, key: String) -> Array[bool]:
	var result: Array[bool] = []
	for item: Variant in r.list(data, key):
		if item is bool:
			result.append(item)
		else:
			r.errors.append("%s.%s: expected true or false" % [r.context, key])
	if result.is_empty():
		r.errors.append("%s.%s: needs at least one entry" % [r.context, key])
	return result
