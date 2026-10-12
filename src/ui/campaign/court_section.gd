class_name CourtSection
extends AdministrationSection
## The court of the home castle: decorations, the leader (who commands which army) and the
## ransom for a captured leader.

var _decorations_title := CampaignStyle.heading("", 18)
var _decorations := VBoxContainer.new()
var _leader := CampaignStyle.paragraph()
var _armies := VBoxContainer.new()
var _ransom := VBoxContainer.new()


func _init() -> void:
	super()
	column.add_child(_decorations_title)
	column.add_child(_decorations)
	column.add_child(HSeparator.new())
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_LEADER"), 18))
	column.add_child(_leader)
	column.add_child(_armies)
	column.add_child(_ransom)
	for box: VBoxContainer in [_decorations, _armies, _ransom]:
		box.add_theme_constant_override("separation", 6)


func refresh(state: GameState, rules: GameRules, house: String, _province_id: String) -> void:
	var cfg := rules.economy
	var owner := state.houses[house]
	var castle := state.home_castle_level(house)
	_decorations_title.text = tr("CAMPAIGN_DECORATIONS") % [
		owner.decorations.size(), cfg.decoration_limit
	]
	for id: String in cfg.decorations:
		var choice := button(_decorations, "decoration_" + id)
		var name := tr(EconomyTerm.decoration_key(id))
		var caption := "%s · %s T" % [name, CampaignFormat.number(cfg.decorations[id].cost)]
		if id in owner.decorations:
			caption = "%s · %s" % [name, tr("CAMPAIGN_PRESENT")]
		var command := BuyDecorationCommand.new(cfg, house, id)
		offer(choice, caption, command, state, CampaignEffects.decoration(cfg, id, castle))
	_leader.text = _leader_text(state, rules, owner)
	_show_armies(state, rules, owner)
	_show_ransom(state, rules, owner)


func _leader_text(state: GameState, rules: GameRules, owner: HouseState) -> String:
	var skills := tr("CAMPAIGN_LEADER_SKILLS") % [owner.leadership, owner.lance, owner.blade]
	var where := tr("CAMPAIGN_LEADER_AT_COURT")
	if owner.is_leader_captured():
		where = tr("CAMPAIGN_LEADER_CAPTURED") % CampaignFormat.owner_name(owner.leader_captor)
	else:
		var army := state.army(owner.leader_army)
		if army != null:
			where = tr("CAMPAIGN_LEADER_WITH_ARMY") % CampaignFormat.province_name(army.province)
	var room := rules.map.campaign.max_companies(true, owner.leadership)
	return "%s\n%s\n%s" % [skills, where, tr("CAMPAIGN_LEADER_ROOM") % room]


## One button per own army the leader could take over; the current one is left out.
func _show_armies(state: GameState, rules: GameRules, owner: HouseState) -> void:
	var keep: Array[String] = []
	for army: ArmyState in state.armies_of(owner.id):
		if army.id == owner.leader_army:
			continue
		var key := "army_%d" % army.id
		keep.append(key)
		var caption := tr("CAMPAIGN_LEADER_TAKE") % [
			CampaignFormat.province_name(army.province), army.company_count()
		]
		var command := AssignLeaderCommand.new(rules.map.campaign, owner.id, army.id)
		offer(button(_armies, key), caption, command, state, tr("CAMPAIGN_LEADER_TAKE_HINT"))
	prune(_armies, keep)


func _show_ransom(state: GameState, rules: GameRules, owner: HouseState) -> void:
	var keep: Array[String] = []
	if owner.is_leader_captured():
		keep.append("ransom")
		var amount := PayRansomCommand.ransom(state, rules.economy, owner.id)
		var caption := tr("CAMPAIGN_RANSOM") % CampaignFormat.number(amount)
		var command := PayRansomCommand.new(rules.economy, owner.id)
		offer(button(_ransom, "ransom"), caption, command, state, tr("CAMPAIGN_RANSOM_HINT"))
	prune(_ransom, keep)
