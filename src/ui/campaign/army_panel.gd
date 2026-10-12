class_name ArmyPanel
extends PanelContainer
## The selected army: owner, where it stands and what it does there, its leader or captain,
## moves left, upkeep, and every company with its health.

var _title := CampaignStyle.heading("", 20)
var _owner := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _command := CampaignStyle.info()
var _moves := CampaignStyle.info()
var _upkeep := CampaignStyle.info()
var _companies := GridContainer.new()


func _init() -> void:
	theme = CampaignStyle.theme()
	custom_minimum_size = Vector2(340, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	for child: Control in [_title, _owner, _command, _moves, _upkeep]:
		column.add_child(child)
	_companies.columns = 3
	_companies.add_theme_constant_override("h_separation", 10)
	_companies.add_theme_constant_override("v_separation", 4)
	column.add_child(_companies)


func refresh(state: GameState, rules: GameRules, _house: String, army_id: int) -> void:
	var army := state.army(army_id)
	for child: Control in [_owner, _command, _moves, _upkeep, _companies]:
		child.visible = army != null
	if army == null:
		_title.text = tr("CAMPAIGN_NO_ARMY")
		return
	var owner: HouseState = state.houses.get(army.owner)
	_title.text = tr("CAMPAIGN_ARMY_IN") % CampaignFormat.province_name(army.province)
	var status := CampaignFormat.owner_name(army.owner)
	if state.is_besieging(army):
		status += " · " + tr("CAMPAIGN_BESIEGING")
	_owner.text = status
	var color := CampaignFormat.owner_color(rules.map, army.owner)
	_owner.add_theme_color_override("font_color", color)
	_show_command(rules, army, owner)
	_moves.text = tr("CAMPAIGN_MOVES_LEFT") % army.moves_left
	_moves.tooltip_text = tr("CAMPAIGN_MOVES_HINT") % [
		rules.map.campaign.moves_per_round(false), rules.map.campaign.moves_per_round(true)
	]
	_moves.visible = owner != null
	_upkeep.visible = owner != null
	if owner != null:
		_show_upkeep(state, rules, army)
	_show_companies(army)


func _show_command(rules: GameRules, army: ArmyState, owner: HouseState) -> void:
	var led := owner != null and owner.leader_army == army.id
	var room := rules.map.campaign.max_companies(led, owner.leadership if led else 0)
	if led:
		_command.text = tr("CAMPAIGN_LED_BY_LEADER") % [
			owner.leadership, owner.lance, owner.blade
		]
	else:
		_command.text = tr("CAMPAIGN_LED_BY_CAPTAIN")
	_command.tooltip_text = tr("CAMPAIGN_ARMY_ROOM") % [army.company_count(), room]


## The army's own terms: upkeep and troop grain list one term per army in armies_of order,
## the troops after one term per own province.
func _show_upkeep(state: GameState, rules: GameRules, army: ArmyState) -> void:
	var cfg := rules.economy
	var index := state.armies_of(army.owner).find(army)
	var gold: Array[EconomyTerm] = [EconomyBreakdown.upkeep(state, cfg, army.owner)[index]]
	var demand := GrainBreakdown.grain_demand(state, cfg, army.owner, state.season())
	var people := state.provinces_of(army.owner).size()
	var grain: Array[EconomyTerm] = [demand[people + index]]
	_upkeep.text = tr("CAMPAIGN_ARMY_UPKEEP") % [
		CampaignFormat.number(-EconomyTerm.sum(gold), 1),
		CampaignFormat.number(EconomyTerm.sum(grain), 1),
	]
	_upkeep.tooltip_text = "%s\n%s" % [
		CampaignFormat.terms_text(tr("CAMPAIGN_GOLD_UPKEEP"), gold),
		CampaignFormat.terms_text(tr("CAMPAIGN_GRAIN_UPKEEP"), grain, 1, false),
	]


func _show_companies(army: ArmyState) -> void:
	for child: Node in _companies.get_children():
		_companies.remove_child(child)
		child.queue_free()
	for i: int in army.company_count():
		_companies.add_child(CampaignStyle.label(CampaignFormat.unit_name(army.units[i])))
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = army.health[i]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_companies.add_child(bar)
		var share := CampaignStyle.label(
			CampaignFormat.percent(army.health[i]), CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED
		)
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_companies.add_child(share)
