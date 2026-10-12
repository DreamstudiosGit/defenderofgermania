class_name CrownSection
extends AdministrationSection
## The road to the crown for the house (GDD "Setting & Legitimität", "Wahlfürsten"): the three
## pillars at a glance with the coronation, then forged regalia, tournament and penance, the
## patron's cards, and every elector and neutral lord (CrownLordRows).

var _regalia := CampaignStyle.info()
var _sites := CampaignStyle.info()
var _archbishops := CampaignStyle.info()
var _votes := CampaignStyle.info()
var _ban := CampaignStyle.paragraph()
var _coronation := VBoxContainer.new()
var _court := VBoxContainer.new()
var _patron_title := CampaignStyle.heading("", 18)
var _patron_cards := CampaignStyle.paragraph()
var _patron := HBoxContainer.new()
var _patron_notes := CampaignStyle.paragraph()
var _electors_title := CampaignStyle.heading("", 18)
var _electors := VBoxContainer.new()
var _lords_note := CampaignStyle.paragraph()
var _lords := VBoxContainer.new()
var _no_lords := CampaignStyle.paragraph()


func _init() -> void:
	super()
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_CROWN_PILLARS"), 18))
	var lines: Dictionary[String, Button] = {
		"regalia": _regalia, "sites": _sites, "archbishops": _archbishops, "votes": _votes
	}
	for key: String in lines:
		lines[key].name = key
		column.add_child(lines[key])
	_ban.add_theme_color_override("font_color", CampaignStyle.BAD)
	column.add_child(_ban)
	column.add_child(_coronation)
	column.add_child(HSeparator.new())
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_CROWN_COURT"), 18))
	column.add_child(_court)
	column.add_child(HSeparator.new())
	for child: Control in [_patron_title, _patron_cards, _patron, _patron_notes]:
		column.add_child(child)
	column.add_child(HSeparator.new())
	column.add_child(_electors_title)
	column.add_child(_electors)
	column.add_child(HSeparator.new())
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_CROWN_LORDS"), 18))
	_no_lords.text = tr("CAMPAIGN_CROWN_NO_LORDS")
	for child: Control in [_lords_note, _lords, _no_lords]:
		column.add_child(child)
	for box: BoxContainer in [_coronation, _court, _patron]:
		box.add_theme_constant_override("separation", 6)
	for box: BoxContainer in [_electors, _lords]:
		box.add_theme_constant_override("separation", 14)


func refresh(state: GameState, rules: GameRules, house: String, _province_id: String) -> void:
	var map := rules.map
	_show_pillars(state, map, house)
	_show_court(state, rules, house)
	_show_patron(state, map, house)
	_electors_title.text = tr("CAMPAIGN_CROWN_ELECTORS") % [
		CrownRules.vote_count(state, map, house), map.electors().size()
	]
	CrownLordRows.show_electors(self, _electors, state, map, house)
	_lords_note.text = tr("CAMPAIGN_CROWN_LORDS_NOTE") % [
		CrownFormat.amount(map.crown.homage_threshold), CrownFormat.amount(map.crown.homage_cost)
	]
	CrownLordRows.show_lords(self, _lords, state, map, house)
	_no_lords.visible = _lords.get_child_count() == 0


func _show_pillars(state: GameState, map: MapData, house: String) -> void:
	_pillar(
		_regalia,
		tr("CAMPAIGN_CROWN_REGALIA") % CrownFormat.regalia(state, house),
		not CrownRules.regalia(state, house).is_empty(),
		CrownFormat.regalia_hint(state)
	)
	_pillar(
		_sites,
		tr("CAMPAIGN_CROWN_SITES") % CrownFormat.sites(state, map, house),
		CrownFormat.holds_any_site(state, map, house),
		CrownFormat.sites_hint(state, map)
	)
	_pillar(
		_archbishops,
		tr("CAMPAIGN_CROWN_ARCHBISHOPS") % CrownFormat.archbishops(state, map, house),
		CrownFormat.any_archbishop_willing(state, map, house),
		CrownFormat.archbishops_hint(state, map, house)
	)
	var needed := CrownRules.votes_needed(state, map, house)
	var enough := needed > 0 and CrownRules.vote_count(state, map, house) >= needed
	_pillar(
		_votes, CrownFormat.votes(state, map, house), enough, CrownFormat.table(state, map, house)
	)
	var owner := state.houses[house]
	_ban.visible = owner.is_banned or CrownRules.is_doing_penance(state, house)
	_ban.text = tr("CAMPAIGN_CROWN_BANNED" if owner.is_banned else "CROWN_PENANCE_NO_CAMPAIGN")
	var site := CrownRules.coronation_site(state, map, house)
	var caption := tr("CAMPAIGN_CROWN_CORONATION")
	if not site.is_empty():
		caption = tr("CAMPAIGN_CROWN_CORONATION_AT") % CrownFormat.site_name(map, site)
	var command := CoronationCommand.new(map, house)
	var crown := button(_coronation, "coronation")
	offer(crown, caption, command, state, tr("CAMPAIGN_CROWN_CORONATION_HINT"))
	var reason := note(_coronation, "coronation_reason")
	reason.text = tr(command.validate(state)) if crown.disabled else ""
	reason.visible = crown.disabled


func _pillar(line: Button, text: String, met: bool, details: String) -> void:
	line.text = text
	line.tooltip_text = details
	line.add_theme_color_override("font_color", CampaignStyle.GOOD if met else CampaignStyle.BAD)


func _show_court(state: GameState, rules: GameRules, house: String) -> void:
	var map := rules.map
	var crown := map.crown
	var caption := tr("CAMPAIGN_CROWN_FORGE") % CrownFormat.amount(crown.forged_regalia_cost)
	if house in state.crown.forged_regalia:
		caption = tr("CAMPAIGN_CROWN_FORGED")
	elif state.crown.forging.has(house):
		caption = tr("CAMPAIGN_CROWN_FORGING") % state.crown.forging[house]
	var forge_hint := tr("CAMPAIGN_CROWN_FORGE_HINT") % [
		crown.forged_regalia_home_castle, state.home_castle_level(house), crown.forged_regalia_rounds
	]
	var forge := ForgeRegaliaCommand.new(map, house)
	offer(button(_court, "forge_regalia"), caption, forge, state, forge_hint)
	var cfg := rules.economy
	var multiplier: float = crown.house_favour_multiplier.get(house, 1.0)
	var tournament_hint := tr("CAMPAIGN_CROWN_TOURNAMENT_HINT") % [
		CrownFormat.amount(cfg.tournament_hosted_prestige),
		CrownFormat.amount(crown.favour_changes["tournament_hosted"] * multiplier),
	]
	offer(
		button(_court, "tournament"),
		tr("CAMPAIGN_CROWN_TOURNAMENT") % CrownFormat.amount(cfg.tournament_cost),
		HostTournamentCommand.new(rules, house),
		state,
		tournament_hint
	)
	var keep: Array[String] = ["forge_regalia", "tournament"]
	if state.houses[house].is_banned:
		keep.append("penance")
		var gold := CrownRules.penance_gold(state, map, house)
		var penance_hint := tr("CAMPAIGN_CROWN_PENANCE_HINT") % [
			CrownFormat.amount(crown.penance_prestige),
			crown.penance_campaign_rounds,
			crown.chapel_home_castle,
		]
		offer(
			button(_court, "penance"),
			tr("CAMPAIGN_CROWN_PENANCE") % CrownFormat.amount(gold),
			PenanceCommand.new(map, house),
			state,
			penance_hint
		)
	prune(_court, keep)


func _show_patron(state: GameState, map: MapData, house: String) -> void:
	var crown := map.crown
	var patron := CrownRules.patron_of(map, house)
	var strength: float = state.crown.patron_strength.get(patron, 1.0)
	_patron_title.text = tr("CAMPAIGN_CROWN_PATRON") % tr("PATRON_" + patron.to_upper())
	_patron_cards.text = tr("CAMPAIGN_CROWN_PATRON_CARDS") % [
		state.crown.patron_cards.get(house, 0),
		crown.patron_cards,
		state.crown.patron_played.get(house, 0),
		crown.patron_cards_per_round,
	]
	var unit := CampaignFormat.unit_name(crown.patron_mercenary_unit)
	var notes := PackedStringArray()
	if strength < 1.0:
		notes.append(tr("CAMPAIGN_CROWN_PATRON_WEAK") % CampaignFormat.percent(strength))
	var hired: int = state.crown.mercenaries.get(house, 0)
	if hired > 0:
		notes.append(tr("CAMPAIGN_CROWN_MERCENARIES") % [hired, unit])
	var multiplier: float = crown.house_favour_multiplier.get(house, 1.0)
	var embassy := crown.patron_embassy_favour * strength * multiplier
	notes.append(tr("CAMPAIGN_CROWN_EMBASSY_NOTE") % CrownFormat.amount(embassy))
	_patron_notes.text = "\n".join(notes)
	var silver := "%s · +%s T" % [
		_card_name(PlayPatronCommand.SILVER), CrownFormat.amount(crown.patron_silver * strength)
	]
	var silver_command := PlayPatronCommand.new(map, house, PlayPatronCommand.SILVER)
	var silver_hint := tr("CAMPAIGN_CROWN_SILVER_HINT")
	offer(button(_patron, "patron_silver"), silver, silver_command, state, silver_hint)
	var companies := roundi(crown.patron_mercenary_companies * strength)
	var hire := "%s · %s" % [
		_card_name(PlayPatronCommand.MERCENARIES), tr("CAMPAIGN_CROWN_COMPANIES") % companies
	]
	var hire_command := PlayPatronCommand.new(map, house, PlayPatronCommand.MERCENARIES)
	var hire_hint := tr("CAMPAIGN_CROWN_HIRE_HINT") % [companies, unit]
	offer(button(_patron, "patron_mercenaries"), hire, hire_command, state, hire_hint)


func _card_name(card: String) -> String:
	return tr("PATRON_CARD_" + card.to_upper())
