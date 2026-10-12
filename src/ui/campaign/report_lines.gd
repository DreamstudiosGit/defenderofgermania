class_name ReportLines
extends RefCounted
## The settlement report of one house, worked out from the snapshots before and after the
## settlement: taler, grain, prestige and what changed in each province.

enum Tone { NORMAL, HEADING, WARNING }


class Line:
	var text: String
	var tone: Tone

	func _init(line_tone: Tone, line_text: String) -> void:
		tone = line_tone
		text = line_text


static func for_house(
	before: GameState, after: GameState, rules: GameRules, house: String
) -> Array[Line]:
	var lines: Array[Line] = []
	var old := before.houses[house]
	var now := after.houses[house]
	lines.append(_change(_t("CAMPAIGN_GOLD"), old.gold, now.gold, 0))
	var cfg := rules.economy
	var income := EconomyTerm.sum(EconomyBreakdown.income(before, rules.map, cfg, house))
	var upkeep := EconomyTerm.sum(EconomyBreakdown.upkeep(before, cfg, house))
	lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_INCOME") % _signed(income)))
	lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_UPKEEP") % _signed(upkeep)))
	if now.gold < 0.0:
		lines.append(Line.new(Tone.WARNING, _t("CAMPAIGN_REPORT_DEBT")))
	lines.append_array(_grain(before, after, rules, house))
	lines.append(_change(_t("CAMPAIGN_PRESTIGE"), old.prestige, now.prestige, 1))
	lines.append(Line.new(Tone.HEADING, _t("CAMPAIGN_REPORT_PROVINCES")))
	for province: ProvinceState in after.provinces_of(house):
		lines.append_array(_province(before.provinces[province.id], province))
	for province: ProvinceState in before.provinces_of(house):
		if after.provinces[province.id].owner != house:
			var lost := _t("CAMPAIGN_REPORT_LOST") % CampaignFormat.province_name(province.id)
			lines.append(Line.new(Tone.WARNING, lost))
	return lines


static func _grain(
	before: GameState, after: GameState, rules: GameRules, house: String
) -> Array[Line]:
	var cfg := rules.economy
	var stock := before.houses[house].grain
	var left := after.houses[house].grain
	var lines: Array[Line] = [_change(_t("CAMPAIGN_GRAIN"), stock, left, 0)]
	var harvest := 0.0
	if before.season() == GameState.Season.AUTUMN:
		var weather := after.weather
		harvest = EconomyTerm.sum(GrainBreakdown.harvest(before, rules.map, cfg, house, weather))
		lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_HARVEST") % _signed(harvest)))
	var meal := EconomyTerm.sum(GrainBreakdown.grain_demand(before, cfg, house, before.season()))
	var eaten := minf(stock + harvest, meal)
	var spoiled := maxf(0.0, stock + harvest - eaten - left)
	lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_EATEN") % _signed(-eaten)))
	lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_SPOILED") % _signed(-spoiled)))
	if eaten < meal:
		var missing := CampaignFormat.number(meal - eaten)
		lines.append(Line.new(Tone.WARNING, _t("CAMPAIGN_REPORT_HUNGER") % missing))
	return lines


static func _province(prior: ProvinceState, province: ProvinceState) -> Array[Line]:
	var name := CampaignFormat.province_name(province.id)
	var lines: Array[Line] = []
	var text := _t("CAMPAIGN_REPORT_SATISFACTION") % [
		name,
		CampaignFormat.number(prior.satisfaction, 1),
		CampaignFormat.number(province.satisfaction, 1),
	]
	if not is_equal_approx(prior.population, province.population):
		text += " · " + _t("CAMPAIGN_REPORT_PEOPLE") % [
			CampaignFormat.number(prior.population, 1),
			CampaignFormat.number(province.population, 1),
		]
	lines.append(Line.new(Tone.NORMAL, text))
	for id: String in province.buildings:
		if id not in prior.buildings:
			var built := _t(EconomyTerm.building_key(id))
			lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_FINISHED") % [built, name]))
	if province.castle_level > prior.castle_level:
		var castle := _t("CAMPAIGN_LEVEL") % province.castle_level
		lines.append(Line.new(Tone.NORMAL, _t("CAMPAIGN_REPORT_CASTLE") % [name, castle]))
	if province.in_revolt and not prior.in_revolt:
		lines.append(Line.new(Tone.WARNING, _t("CAMPAIGN_REPORT_REVOLT") % name))
	return lines


static func _change(title: String, old: float, now: float, decimals: int) -> Line:
	return Line.new(Tone.HEADING, "%s: %s → %s (%s)" % [
		title,
		CampaignFormat.number(old, decimals),
		CampaignFormat.number(now, decimals),
		CampaignFormat.signed(now - old, maxi(decimals, 1)),
	])


static func _signed(value: float) -> String:
	return CampaignFormat.signed(value, 1)


static func _t(key: String) -> String:
	return CampaignFormat.t(key)
