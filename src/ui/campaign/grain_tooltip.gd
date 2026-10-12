class_name GrainTooltip
extends RefCounted
## Tooltip of the house's grain: this round's meal with its terms, spoilage, and the
## Kornvogt forecast with the expected harvest until the next autumn.


static func text(
	state: GameState, rules: GameRules, house: String, forecast: EconomyForecast
) -> String:
	var cfg := rules.economy
	var lines := PackedStringArray()
	var meal := GrainBreakdown.grain_demand(state, cfg, house, state.season())
	lines.append(CampaignFormat.terms_text(_t("CAMPAIGN_GRAIN_MEAL"), meal, 1, false))
	var spoilage := GrainBreakdown.spoilage(state, cfg, house)
	lines.append(_t("CAMPAIGN_GRAIN_SPOILAGE") % [
		CampaignFormat.percent(spoilage.value), CampaignFormat.formula(spoilage.formula)
	])
	lines.append("")
	lines.append(_t("CAMPAIGN_KORNVOGT") % CampaignFormat.in_rounds(forecast.rounds_to_harvest))
	lines.append("   %s: %s" % [
		_t("CAMPAIGN_KORNVOGT_BEFORE"), CampaignFormat.number(forecast.stock_before_harvest)
	])
	var harvest := GrainBreakdown.harvest(
		state, rules.map, cfg, house, {}, forecast.rounds_to_harvest
	)
	for line: String in CampaignFormat.terms_text(
		_t("CAMPAIGN_KORNVOGT_HARVEST"), harvest, 0, false
	).split("\n"):
		lines.append("   " + line)
	lines.append("   %s: %s" % [
		_t("CAMPAIGN_KORNVOGT_AFTER"), CampaignFormat.number(forecast.stock_after_harvest)
	])
	var yearly := GrainBreakdown.yearly_grain_demand(state, cfg, house)
	lines.append("   %s: %s" % [_t("CAMPAIGN_KORNVOGT_YEARLY"), CampaignFormat.number(yearly)])
	if forecast.runs_short():
		lines.append(_t("CAMPAIGN_FORECAST_SHORT") % [
			CampaignFormat.in_rounds(forecast.shortage_round),
			CampaignFormat.number(forecast.shortage),
		])
	return "\n".join(lines)


static func _t(key: String) -> String:
	return CampaignFormat.t(key)
