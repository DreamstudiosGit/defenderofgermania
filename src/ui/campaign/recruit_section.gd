class_name RecruitSection
extends AdministrationSection
## Recruiting in the selected own province: the yearly budget left, the army the companies
## join and every unit with its cost in taler, people and satisfaction.

var _title := CampaignStyle.heading("", 18)
var _hint := CampaignStyle.paragraph()
var _budget := CampaignStyle.paragraph()
var _target := OptionButton.new()
var _units := VBoxContainer.new()
var _state: GameState
var _rules: GameRules
var _house := ""
var _province := ""


func _init() -> void:
	super()
	for child: Control in [_title, _hint, _budget, _target, _units]:
		column.add_child(child)
	_units.add_theme_constant_override("separation", 6)
	_target.item_selected.connect(func(_index: int) -> void: _show_units())


func refresh(state: GameState, rules: GameRules, house: String, province_id: String) -> void:
	_state = state
	_rules = rules
	_house = house
	_province = province_id
	var province: ProvinceState = state.provinces.get(province_id)
	var own := province != null and province.owner == house
	_hint.visible = not own
	for part: Control in [_budget, _target, _units]:
		part.visible = own
	if not own:
		_title.text = tr("CAMPAIGN_RECRUIT")
		_hint.text = tr("CAMPAIGN_SELECT_OWN_PROVINCE")
		return
	_title.text = tr("CAMPAIGN_RECRUIT_IN") % CampaignFormat.province_name(province_id)
	var lines := PackedStringArray([tr("CAMPAIGN_RECRUIT_BUDGET") % [
		province.recruits_left,
		CampaignFormat.number(province.population, 1),
		CampaignFormat.number(province.satisfaction, 1),
	]])
	if province.castle_level < 1:
		lines.append(tr("TURN_NO_CASTLE"))
	_budget.text = "\n".join(lines)
	_fill_targets(state, house, province_id)
	_show_units()


## "Automatic" first, then every own army in the province; item metadata is the army id
## (OptionButton ids cannot be -1).
func _fill_targets(state: GameState, house: String, province_id: String) -> void:
	var chosen := _target_army()
	_target.clear()
	_target.add_item(tr("CAMPAIGN_RECRUIT_AUTO"))
	_target.set_item_metadata(0, RecruitCommand.AUTO_ARMY)
	var leader_army := state.houses[house].leader_army
	for army: ArmyState in state.armies_in(province_id):
		if army.owner != house:
			continue
		var key := "CAMPAIGN_ARMY_LEADER" if army.id == leader_army else "CAMPAIGN_ARMY_CAPTAIN"
		_target.add_item(tr(key) % army.company_count())
		_target.set_item_metadata(_target.item_count - 1, army.id)
		if army.id == chosen:
			_target.select(_target.item_count - 1)
	if _target_army() != chosen:
		_target.select(0)


func _target_army() -> int:
	if _target.selected < 0:
		return RecruitCommand.AUTO_ARMY
	return int(_target.get_item_metadata(_target.selected))


func _show_units() -> void:
	if _state == null or not _state.provinces.has(_province):
		return
	var cfg := _rules.economy
	var army := _target_army()
	for id: String in cfg.units:
		var choice := button(_units, "unit_" + id)
		var cost := RecruitCommand.unit_cost(cfg, _house, id)
		var caption := "%s · %s T" % [CampaignFormat.unit_name(id), CampaignFormat.number(cost)]
		var command := RecruitCommand.new(cfg, _rules.map, _house, _province, id, army)
		var details := CampaignEffects.unit(_state, cfg, _house, id, _province)
		offer(choice, caption, command, _state, details)
