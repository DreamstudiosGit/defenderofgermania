class_name AiFormat
extends RefCounted
## Text for the computer opponents on the campaign screens: personality and difficulty names,
## their tooltips from data/ai.json and economy.json, a house's player and utilities.

## Personality choice the setup rolls from the seed.
const RANDOM := "random"


static func personality_name(id: String) -> String:
	return CampaignFormat.t("CAMPAIGN_AI_PERSONALITY_" + id.to_upper())


static func difficulty_name(level: int) -> String:
	return CampaignFormat.t("CAMPAIGN_AI_DIFFICULTY_%d" % level)


## "Mensch" or "Computer · Ritter".
static func player(house: HouseState) -> String:
	if not house.is_computer():
		return CampaignFormat.t("CAMPAIGN_SETUP_HUMAN")
	return CampaignFormat.t("CAMPAIGN_AI_COMPUTER_ROLE") % difficulty_name(house.difficulty)


## The house it plays by default and its weight for every kind of action.
static func personality_hint(config: AiConfig, id: String) -> String:
	if id == RANDOM:
		return CampaignFormat.t("CAMPAIGN_AI_RANDOM_HINT")
	var lines := PackedStringArray()
	if config.default_house.has(id):
		lines.append(
			CampaignFormat.t("CAMPAIGN_AI_DEFAULT_FOR")
			% CampaignFormat.house_name(config.default_house[id])
		)
	lines.append(CampaignFormat.t("CAMPAIGN_AI_WEIGHTS"))
	for category: String in AiConfig.CATEGORIES:
		lines.append("   %s ×%s" % [
			CampaignFormat.t("CAMPAIGN_AI_CATEGORY_" + category.to_upper()),
			CampaignFormat.number(config.weight(id, category), 1),
		])
	return "\n".join(lines)


## Income ("−20 %"), share of deliberately worse decisions and the cleverer habits.
static func difficulty_hint(config: AiConfig, economy: EconomyConfig, level: int) -> String:
	var difficulty := config.difficulty(level)
	var income := economy.computer_income[clampi(level, 0, economy.computer_income.size() - 1)]
	var change := CampaignFormat.t("CAMPAIGN_AI_INCOME_NORMAL")
	if not is_equal_approx(income, 1.0):
		change = "%s %%" % CampaignFormat.signed((income - 1.0) * 100.0, 0)
	var lines := PackedStringArray([CampaignFormat.t("CAMPAIGN_AI_INCOME") % change])
	if difficulty.suboptimal_share > 0.0:
		lines.append(
			CampaignFormat.t("CAMPAIGN_AI_SUBOPTIMAL")
			% CampaignFormat.percent(difficulty.suboptimal_share)
		)
	var habits: Array[Array] = [
		[difficulty.better_targets, "CAMPAIGN_AI_BETTER_TARGETS"],
		[difficulty.counters, "CAMPAIGN_AI_COUNTERS"],
		[difficulty.coalition, "CAMPAIGN_AI_COALITION"],
	]
	for habit: Array in habits:
		if habit[0]:
			lines.append(CampaignFormat.t(habit[1]))
	if lines.size() == 1:
		lines.append(CampaignFormat.t("CAMPAIGN_AI_STANDARD"))
	return "\n".join(lines)


## Utility rounded to what tells options apart: two decimals below 10, none from 100 on.
static func utility(value: float) -> String:
	if is_inf(value):
		return "∞" if value > 0.0 else CampaignFormat.MINUS + "∞"
	var size := absf(value)
	var decimals := 2 if size < 10.0 else (1 if size < 100.0 else 0)
	return CampaignFormat.number(value, decimals)
