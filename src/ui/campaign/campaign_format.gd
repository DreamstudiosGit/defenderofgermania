class_name CampaignFormat
extends RefCounted
## Text for the campaign screens: localized numbers, names from data ids and the
## calculation tooltips built from EconomyTerm lists.

## The year the campaign starts in (game title "THRONSTREIT 1198").
const START_YEAR := 1198
const MINUS := "−"
const MIN_LUMINANCE := 0.5
const SEASON_KEYS: Array[String] = [
	"SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"
]
const PHASE_KEYS: Array[String] = [
	"CAMPAIGN_PHASE_EVENT",
	"CAMPAIGN_PHASE_ADMINISTRATION",
	"CAMPAIGN_PHASE_CAMPAIGN",
	"CAMPAIGN_PHASE_SETTLEMENT",
	"CAMPAIGN_PHASE_GAME_OVER",
]


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## True if the key has a text; untranslated keys come back unchanged.
static func has_text(key: String) -> bool:
	return t(key) != key


## Number with a fixed count of decimals and the locale's decimal separator.
static func number(value: float, decimals: int = 0) -> String:
	var text := ("%." + str(decimals) + "f") % value if decimals > 0 else str(roundi(value))
	text = text.replace(".", t("CAMPAIGN_DECIMAL_SEPARATOR")).replace("-", MINUS)
	return "0" if text == MINUS + "0" else text


## Number with an explicit sign: "+20,9", "−6,0".
static func signed(value: float, decimals: int = 1) -> String:
	var text := number(value, decimals)
	return text if text.begins_with(MINUS) or is_zero_approx(value) else "+" + text


static func percent(share: float, decimals: int = 0) -> String:
	return "%s %%" % number(share * 100.0, decimals)


## A formula from EconomyTerm with the locale's decimal separator; where that is a comma,
## arguments are separated by semicolons.
static func formula(text: String) -> String:
	var separator := t("CAMPAIGN_DECIMAL_SEPARATOR")
	if separator == ",":
		text = text.replace(", ", "; ")
	return text.replace(".", separator).replace("-", MINUS)


static func term_label(term: EconomyTerm) -> String:
	var text := t(term.label_key)
	if term.args.is_empty():
		return text
	var names: Array[String] = []
	for key: String in term.args:
		names.append(t(key))
	return text % names


## "+20,9  Steuer Braunschweig = 60 × 15 % × 3 × (0,5 + 55/200)"
static func term_line(term: EconomyTerm, decimals: int = 1, with_sign: bool = true) -> String:
	var value := signed(term.value, decimals) if with_sign else number(term.value, decimals)
	var line := "%s   %s" % [value, term_label(term)]
	return line if term.formula.is_empty() else "%s = %s" % [line, formula(term.formula)]


## A title line with the total, then one line per term.
## signed_total is false where the total is a level (Z*) rather than a change.
static func terms_text(
	title: String,
	terms: Array[EconomyTerm],
	decimals: int = 1,
	with_sign: bool = true,
	signed_total: bool = true
) -> String:
	var lines := PackedStringArray()
	var total := EconomyTerm.sum(terms)
	var shown := number(total, decimals)
	if with_sign and signed_total:
		shown = signed(total, decimals)
	lines.append("%s: %s" % [title, shown])
	for term: EconomyTerm in terms:
		lines.append("   " + term_line(term, decimals, with_sign))
	return "\n".join(lines)


static func house_name(house: String) -> String:
	return t("BATTLE_HOUSE_" + house.to_upper())


## A house, or the lord of a province without a house (elector, church, neutral).
static func owner_name(owner: String, province_id: String = "") -> String:
	if owner == "elector" and has_text("ELECTOR_" + province_id):
		return t("ELECTOR_" + province_id)
	if owner in MapData.NON_HOUSE_OWNERS:
		return t("CAMPAIGN_OWNER_" + owner.to_upper())
	return house_name(owner)


## The house's field colour, lightened until it reads on the dark panels.
static func owner_color(map: MapData, owner: String) -> Color:
	if not map.house_colors.has(owner):
		return CampaignStyle.MUTED
	var color: Color = map.house_colors[owner][0].lightened(0.35)
	while color.get_luminance() < MIN_LUMINANCE:
		color = color.lightened(0.2)
	return color


static func province_name(province_id: String) -> String:
	return t(EconomyTerm.province_key(province_id))


static func unit_name(unit_id: String) -> String:
	return t(EconomyTerm.unit_key(unit_id))


static func season_name(season: GameState.Season) -> String:
	return t(SEASON_KEYS[season])


static func phase_name(phase: GameState.Phase) -> String:
	return t(PHASE_KEYS[phase])


static func year(state: GameState) -> int:
	@warning_ignore("integer_division")
	return START_YEAR + state.turn / GameState.ROUNDS_PER_YEAR


## "Frühling 1198 · Runde 1 von 48"
static func date(state: GameState, rules: GameRules) -> String:
	var round_text := t("CAMPAIGN_ROUND") % [state.turn + 1, rules.map.campaign.max_rounds]
	return "%s %d · %s" % [season_name(state.season()), year(state), round_text]


## "this round", "next round" or "in n rounds" for a settlement counted from now.
static func in_rounds(settlement: int) -> String:
	if settlement <= 1:
		return t("CAMPAIGN_THIS_ROUND" if settlement == 0 else "CAMPAIGN_NEXT_ROUND")
	return t("CAMPAIGN_IN_ROUNDS") % settlement


static func castle_name(level: int, is_home: bool) -> String:
	return t(EconomyTerm.castle_key(level, is_home))


## River, pass, ore, port, church land, elector and special places of a province.
static func features(def: MapData.ProvinceDef) -> String:
	var parts := PackedStringArray()
	if not def.river.is_empty():
		parts.append(t("CAMPAIGN_RIVER") % t("CAMPAIGN_RIVER_" + def.river.to_upper()))
	for feature: String in ["pass", "ore", "port"]:
		if def.has_feature(feature):
			parts.append(t("CAMPAIGN_FEATURE_" + feature.to_upper()))
	if def.is_church:
		parts.append(t("CAMPAIGN_CHURCH_LAND"))
	for tag: String in def.tags:
		parts.append(t("CAMPAIGN_TAG_" + tag.to_upper()))
	return "" if parts.is_empty() else t("CAMPAIGN_FEATURES") % ", ".join(parts)
