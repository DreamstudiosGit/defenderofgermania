class_name JoustAIProfile
extends RefCounted
## Fixed error pattern of a computer rider at one skill level (data/combat_joust.json "ai"):
## which gait beats it spurs and how far off, where it aims and misses, how much of its lance
## sway it cancels, how far off it couches the lance and in which passes it reads the shield.
## Lists repeat; the joust seed only picks where in each list a rider starts.

var spurs := PackedInt32Array()
var spur_error_ms := PackedFloat64Array()
## Zone ids aimed at, one per pass.
var targets: Array[String] = []
## Miss of the lance hand in metres, one per pass.
var aim_error := PackedVector2Array()
## Share of the own sway at impact the rider steers against (0 none, 1 all).
var sway_compensation: float
var strike_error_ms := PackedFloat64Array()
## Per pass: whether the rider turns the shield towards the incoming lance.
var shield_reads: Array[bool] = []
## Delay after the aim starts before the rider moves lance and shield.
var reaction_seconds: float


static func read(r: DataReader, data: Dictionary) -> JoustAIProfile:
	var profile := JoustAIProfile.new()
	for beat: float in r.numbers(data, "spurs"):
		profile.spurs.append(int(beat))
	profile.spur_error_ms = r.numbers(data, "spur_error_ms")
	profile.targets = r.strings(data, "targets")
	for entry: Variant in r.list(data, "aim_error"):
		var pair: Array = entry if entry is Array else []
		if pair.size() != 2 or not (pair[0] is float or pair[0] is int):
			r.errors.append("%s.aim_error: expected [x, y] pairs" % r.context)
			continue
		profile.aim_error.append(Vector2(float(pair[0]), float(pair[1])))
	profile.sway_compensation = r.number(data, "sway_compensation")
	profile.strike_error_ms = r.numbers(data, "strike_error_ms")
	for entry: Variant in r.list(data, "shield_reads"):
		if entry is bool:
			profile.shield_reads.append(entry)
		else:
			r.errors.append("%s.shield_reads: expected true or false" % r.context)
	profile.reaction_seconds = r.number(data, "reaction_seconds")
	return profile


func check(where: String, beats: int, zone_ids: Array[String]) -> PackedStringArray:
	var errors: PackedStringArray = []
	var lists: Dictionary[String, int] = {
		"spurs": spurs.size(), "spur_error_ms": spur_error_ms.size(),
		"targets": targets.size(), "aim_error": aim_error.size(),
		"strike_error_ms": strike_error_ms.size(), "shield_reads": shield_reads.size(),
	}
	for key: String in lists:
		if lists[key] == 0 and key != "spurs":
			errors.append("%s.%s: needs at least one entry" % [where, key])
	for beat: int in spurs:
		if beat < 0 or beat >= beats:
			errors.append("%s.spurs: beat %d outside 0..%d" % [where, beat, beats - 1])
	for zone: String in targets:
		if zone not in zone_ids:
			errors.append("%s.targets: unknown zone '%s'" % [where, zone])
	if sway_compensation < 0.0 or sway_compensation > 1.0:
		errors.append("%s.sway_compensation: must lie in 0..1" % where)
	if reaction_seconds < 0.0:
		errors.append("%s.reaction_seconds: must not be negative" % where)
	return errors
