class_name SiegeNews
extends RefCounted
## Words for what a shot did: one line for the HUD ("Gate −240", "Short. …") and the big shout
## for what deserves one (breach, collapse, fire, counterfire).


static func part_name(castle: SiegeCastle, part: int) -> String:
	if part < 0 or part >= castle.part_count():
		return ""
	return tr_key("SIEGE_PART_" + castle.parts[part].kind.to_upper())


static func shot_line(report: TrebuchetSim.ShotReport, castle: SiegeCastle) -> String:
	var parts := PackedStringArray()
	for event: SiegeEvent in report.events:
		match event.kind:
			SiegeEvent.Kind.HIT:
				parts.append("%s −%d" % [part_name(castle, event.part), roundi(event.amount)])
			SiegeEvent.Kind.MISS_SHORT:
				parts.append(tr_key("SIEGE_SHORT"))
			SiegeEvent.Kind.MISS_LONG:
				parts.append(tr_key("SIEGE_LONG"))
			SiegeEvent.Kind.YARD:
				parts.append(tr_key("SIEGE_YARD"))
			SiegeEvent.Kind.GARRISON:
				parts.append(tr_key("SIEGE_GARRISON_HIT") % roundi(event.amount * 100.0))
			SiegeEvent.Kind.IGNITED:
				parts.append(tr_key("SIEGE_FIRE_STARTED"))
	if parts.is_empty() and report.impact != null and report.impact.part >= 0:
		parts.append(tr_key("SIEGE_NO_EFFECT") % part_name(castle, report.impact.part))
	return " · ".join(parts)


## [title, subtitle] of the biggest thing that happened, or empty.
static func shout(events: Array[SiegeEvent], castle: SiegeCastle) -> PackedStringArray:
	var collapse := ""
	var burnt := ""
	for event: SiegeEvent in events:
		match event.kind:
			SiegeEvent.Kind.BREACH:
				return PackedStringArray([tr_key("SIEGE_BREACH"), tr_key("SIEGE_BREACH_SUB")])
			SiegeEvent.Kind.COUNTERFIRE:
				return PackedStringArray(
					[tr_key("SIEGE_COUNTERFIRE"), tr_key("SIEGE_COUNTERFIRE_SUB")]
				)
			SiegeEvent.Kind.DESTROYED:
				var name := part_name(castle, event.part)
				if event.cause == SiegeEvent.Cause.BURNT:
					burnt = burnt if not burnt.is_empty() else name
				elif collapse.is_empty():
					collapse = name
	if not collapse.is_empty():
		return PackedStringArray([tr_key("SIEGE_COLLAPSE") % collapse, ""])
	if not burnt.is_empty():
		return PackedStringArray([tr_key("SIEGE_BURNT") % burnt, ""])
	return PackedStringArray()


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)
