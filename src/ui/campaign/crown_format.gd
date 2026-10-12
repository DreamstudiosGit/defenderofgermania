class_name CrownFormat
extends RefCounted
## Text for the road to the crown, shared by the realm tab, the HUD and the coronation plate:
## the three pillars of a house, its votes and the favour of electors and neutral lords.


## Favour, taler and votes with a decimal only where there is one: "55", "37,5".
static func amount(value: float) -> String:
	return CampaignFormat.number(value, 0 if is_equal_approx(value, roundf(value)) else 1)


static func regalia_name(kind: String) -> String:
	return CampaignFormat.t("CAMPAIGN_CROWN_REGALIA_" + kind.to_upper())


## "echte", "keine · nachgemachte im Bau (2 Rd.)", "echte und nachgemachte".
static func regalia(state: GameState, house: String) -> String:
	var held := CrownRules.regalia(state, house)
	var parts := PackedStringArray()
	if held.is_empty():
		parts.append(CampaignFormat.t("CAMPAIGN_CROWN_REGALIA_NONE"))
	elif held.size() == CrownData.REGALIA.size():
		parts.append(CampaignFormat.t("CAMPAIGN_CROWN_REGALIA_BOTH"))
	else:
		parts.append(regalia_name(held[0]))
	if state.crown.forging.has(house):
		parts.append(CampaignFormat.t("CAMPAIGN_CROWN_REGALIA_FORGING") % state.crown.forging[house])
	return " · ".join(parts)


## Where the true regalia lie and who holds them.
static func regalia_hint(state: GameState) -> String:
	var id := state.crown.regalia_province
	var province: ProvinceState = state.provinces.get(id)
	if province == null:
		return ""
	return CampaignFormat.t("CAMPAIGN_CROWN_REGALIA_HINT") % [
		CampaignFormat.province_name(id), CampaignFormat.owner_name(province.owner, id)
	]


## Province with the coronation site tag, e.g. Aachen for "coronation_site"; "" if none.
static func site_province(map: MapData, site: String) -> String:
	for def: MapData.ProvinceDef in map.provinces.values():
		if site in def.tags:
			return def.id
	return ""


static func site_name(map: MapData, site: String) -> String:
	return CampaignFormat.province_name(site_province(map, site))


static func holds_any_site(state: GameState, map: MapData, house: String) -> bool:
	for site: String in map.crown.archbishops:
		if CrownRules.holds_site(state, map, house, site):
			return true
	return false


## The coronation sites the house holds: "Aachen", "Aachen, Mainz" or "keiner in Eurer Hand".
static func sites(state: GameState, map: MapData, house: String) -> String:
	var held := PackedStringArray()
	for site: String in map.crown.archbishops:
		if CrownRules.holds_site(state, map, house, site):
			held.append(site_name(map, site))
	return ", ".join(held) if not held.is_empty() else CampaignFormat.t("CAMPAIGN_CROWN_SITE_NONE")


## Who holds each coronation site now.
static func sites_hint(state: GameState, map: MapData) -> String:
	var lines := PackedStringArray([CampaignFormat.t("CAMPAIGN_CROWN_SITES_HINT")])
	for site: String in map.crown.archbishops:
		var province: ProvinceState = state.provinces.get(site_province(map, site))
		if province != null:
			lines.append("%s (%s): %s" % [
				CampaignFormat.province_name(province.id),
				CampaignFormat.t("CAMPAIGN_TAG_" + site.to_upper()),
				CampaignFormat.owner_name(province.owner, province.id),
			])
	return "\n".join(lines)


static func any_archbishop_willing(state: GameState, map: MapData, house: String) -> bool:
	for site: String in map.crown.archbishops:
		if CrownRules.archbishop_willing(state, map, house, site):
			return true
	return false


## "Köln willig · Mainz unwillig".
static func archbishops(state: GameState, map: MapData, house: String) -> String:
	var parts := PackedStringArray()
	for site: String in map.crown.archbishops:
		var name := CampaignFormat.province_name(map.crown.archbishops[site])
		var willing := CrownRules.archbishop_willing(state, map, house, site)
		var key := "CAMPAIGN_CROWN_WILLING" if willing else "CAMPAIGN_CROWN_UNWILLING"
		parts.append(CampaignFormat.t(key) % name)
	return " · ".join(parts)


static func archbishops_hint(state: GameState, map: MapData, house: String) -> String:
	var crown := map.crown
	var lines := PackedStringArray([
		CampaignFormat.t("CAMPAIGN_CROWN_ARCHBISHOPS_HINT") % amount(crown.archbishop_min_favour)
	])
	for site: String in crown.archbishops:
		var id := crown.archbishops[site]
		lines.append(CampaignFormat.t("CAMPAIGN_CROWN_ARCHBISHOP_LINE") % [
			CampaignFormat.owner_name(map.provinces[id].owner, id),
			site_name(map, site),
			amount(state.crown.favour_of(id, house)),
		])
	return "\n".join(lines)


## "Stimmen: 2 von 7 · nötig 4"; while no row of the table is open, its range ("4–6").
static func votes(state: GameState, map: MapData, house: String) -> String:
	var needed := CrownRules.votes_needed(state, map, house)
	var shown := str(needed) if needed > 0 else _vote_range(map)
	return CampaignFormat.t("CAMPAIGN_CROWN_VOTES") % [
		CrownRules.vote_count(state, map, house), map.electors().size(), shown
	]


## The coronation table, each row the house meets but for the votes marked ready.
static func table(state: GameState, map: MapData, house: String) -> String:
	var lines := PackedStringArray([CampaignFormat.t("CAMPAIGN_CROWN_TABLE")])
	var held := CrownRules.regalia(state, house)
	for rule: CrownData.CoronationRule in map.crown.coronation:
		var line := CampaignFormat.t("CAMPAIGN_CROWN_ROW") % [
			regalia_name(rule.regalia), site_name(map, rule.site), rule.votes
		]
		if (
			rule.regalia in held
			and CrownRules.holds_site(state, map, house, rule.site)
			and CrownRules.archbishop_willing(state, map, house, rule.site)
		):
			line = CampaignFormat.t("CAMPAIGN_CROWN_ROW_READY") % line
		lines.append("   " + line)
	return "\n".join(lines)


## All three pillars in a few lines, for the HUD tooltip.
static func pillars(state: GameState, map: MapData, house: String) -> String:
	var lines := PackedStringArray([
		CampaignFormat.t("CAMPAIGN_CROWN_REGALIA") % regalia(state, house),
		CampaignFormat.t("CAMPAIGN_CROWN_SITES") % sites(state, map, house),
		CampaignFormat.t("CAMPAIGN_CROWN_ARCHBISHOPS") % archbishops(state, map, house),
		votes(state, map, house),
	])
	if state.houses[house].is_banned:
		lines.append(CampaignFormat.t("CAMPAIGN_CROWN_BANNED"))
	return "\n".join(lines)


## "Gunst: Welfen 55 · Staufer 30 · …" for every house still in the game.
static func favour_list(state: GameState, province_id: String) -> String:
	var parts := PackedStringArray()
	for other: HouseState in state.houses.values():
		if not other.is_eliminated:
			parts.append("%s %s" % [
				CampaignFormat.house_name(other.id), amount(state.crown.favour_of(province_id, other.id))
			])
	return CampaignFormat.t("CAMPAIGN_CROWN_FAVOUR_LIST") % " · ".join(parts)


## The other house still in the game with the highest favour; "" if there is none.
static func rival(state: GameState, province_id: String, house: String) -> String:
	var best := ""
	var best_favour := -1.0
	for other: HouseState in state.houses.values():
		if other.id == house or other.is_eliminated:
			continue
		var value := state.crown.favour_of(province_id, other.id)
		if value > best_favour:
			best = other.id
			best_favour = value
	return best


## How the elector votes (CrownRules.votes) and why, seen from the house.
static func vote(
	state: GameState, map: MapData, elector: String, house: String, voted: String
) -> String:
	var occupier := state.provinces[elector].owner
	if state.houses.has(occupier):
		return CampaignFormat.t("CAMPAIGN_CROWN_VOTE_OCCUPIED") % _who(occupier, house)
	if not voted.is_empty():
		var promised: String = state.crown.promised_votes.get(elector, CrownRules.ABSTAIN)
		var key := "CAMPAIGN_CROWN_VOTE_PROMISED" if promised == voted else "CAMPAIGN_CROWN_VOTE_FOR"
		return CampaignFormat.t(key) % _who(voted, house)
	var threshold := map.crown.vote_threshold
	if (
		map.provinces[elector].is_church
		and state.houses[house].is_banned
		and state.crown.favour_of(elector, house) >= threshold
	):
		return CampaignFormat.t("CAMPAIGN_CROWN_VOTE_BANNED")
	if _tied(state, map, elector):
		return CampaignFormat.t("CAMPAIGN_CROWN_VOTE_TIE")
	return CampaignFormat.t("CAMPAIGN_CROWN_VOTE_ABSTAINS")


static func _who(voted: String, house: String) -> String:
	if voted == house:
		return CampaignFormat.t("CAMPAIGN_CROWN_YOU")
	return CampaignFormat.house_name(voted)


## True if two houses share the highest favour from the threshold on.
static func _tied(state: GameState, map: MapData, elector: String) -> bool:
	var is_church := map.provinces[elector].is_church
	var best := -1.0
	var count := 0
	for house: HouseState in state.houses.values():
		if house.is_eliminated or (is_church and house.is_banned):
			continue
		var value := state.crown.favour_of(elector, house.id)
		if value > best:
			best = value
			count = 1
		elif value == best:
			count += 1
	return count > 1 and best >= map.crown.vote_threshold


static func _vote_range(map: MapData) -> String:
	var fewest := 0
	var most := 0
	for rule: CrownData.CoronationRule in map.crown.coronation:
		fewest = rule.votes if fewest == 0 else mini(fewest, rule.votes)
		most = maxi(most, rule.votes)
	return "%d–%d" % [fewest, most]
