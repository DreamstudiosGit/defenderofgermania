class_name LeversSection
extends AdministrationSection
## The house's two levers: tax rate and ration. Each choice previews its tax income, target
## satisfaction per province and grain per round in its tooltip.

var _taxes := HFlowContainer.new()
var _rations := HFlowContainer.new()
var _tax_summary := CampaignStyle.paragraph()
var _ration_summary := CampaignStyle.paragraph()


func _init() -> void:
	super()
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_TAX_RATE"), 18))
	column.add_child(_taxes)
	column.add_child(_tax_summary)
	column.add_child(HSeparator.new())
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_RATION"), 18))
	column.add_child(_rations)
	column.add_child(_ration_summary)
	for row: HFlowContainer in [_taxes, _rations]:
		row.add_theme_constant_override("h_separation", 5)
		row.add_theme_constant_override("v_separation", 6)


func refresh(state: GameState, rules: GameRules, house: String, _province_id: String) -> void:
	var cfg := rules.economy
	var owner := state.houses[house]
	var keep: Array[String] = []
	for rate: int in cfg.tax_rates:
		var choice := _choice(_taxes, "tax_%d" % rate, keep)
		var command := SetTaxRateCommand.new(cfg, house, rate)
		offer(choice, "%d %%" % rate, command, state, _tax_preview(state, rules, house, rate))
		choice.set_pressed_no_signal(rate == owner.tax_rate)
	prune(_taxes, keep)
	_tax_summary.text = _tax_line(state, rules, house, owner.tax_rate)
	_tax_summary.tooltip_text = _tax_preview(state, rules, house, owner.tax_rate)
	keep.clear()
	for ration: int in cfg.rations:
		var choice := _choice(_rations, "ration_%d" % ration, keep)
		var command := SetRationCommand.new(cfg, house, ration)
		var caption := "%d · %s" % [ration, tr("CAMPAIGN_RATION_%d" % ration)]
		offer(choice, caption, command, state, _ration_preview(state, rules, house, ration))
		choice.set_pressed_no_signal(ration == owner.ration)
	prune(_rations, keep)
	_ration_summary.text = _grain_line(state, rules, house, owner.ration)
	_ration_summary.tooltip_text = _ration_preview(state, rules, house, owner.ration)


func _choice(row: HFlowContainer, key: String, keep: Array[String]) -> Button:
	var choice := button(row, key)
	choice.toggle_mode = true
	choice.size_flags_horizontal = Control.SIZE_FILL
	choice.theme_type_variation = CampaignStyle.CHOICE
	choice.custom_minimum_size.x = 52
	choice.alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep.append(key)
	return choice


## "Steuern 36,6 T je Runde · Ziel-Zufriedenheit: Braunschweig 55,0, Holstein 60,0"
func _tax_line(state: GameState, rules: GameRules, house: String, rate: int) -> String:
	var tax := EconomyTerm.sum(_tax_terms(state, rules, house, rate))
	return "%s\n%s" % [
		tr("CAMPAIGN_TAX_INCOME") % CampaignFormat.number(tax, 1),
		_targets(state, rules, house, rate, EconomyBreakdown.CURRENT),
	]


func _tax_preview(state: GameState, rules: GameRules, house: String, rate: int) -> String:
	var owner := state.houses[house]
	var now := EconomyTerm.sum(_tax_terms(state, rules, house, owner.tax_rate))
	var title := tr("CAMPAIGN_TAX_PREVIEW") % [rate, CampaignFormat.number(now, 1)]
	return "%s\n%s" % [
		CampaignFormat.terms_text(title, _tax_terms(state, rules, house, rate)),
		_targets(state, rules, house, rate, EconomyBreakdown.CURRENT),
	]


func _grain_line(state: GameState, rules: GameRules, house: String, ration: int) -> String:
	var demand := GrainBreakdown.grain_demand(
		state, rules.economy, house, state.season(), ration
	)
	return "%s\n%s" % [
		tr("CAMPAIGN_GRAIN_PER_ROUND") % CampaignFormat.number(EconomyTerm.sum(demand), 1),
		_targets(state, rules, house, EconomyBreakdown.CURRENT, ration),
	]


func _ration_preview(state: GameState, rules: GameRules, house: String, ration: int) -> String:
	var cfg := rules.economy
	var demand := GrainBreakdown.grain_demand(state, cfg, house, state.season(), ration)
	var title := tr("CAMPAIGN_RATION_PREVIEW") % [ration, tr("CAMPAIGN_RATION_%d" % ration)]
	var lines := PackedStringArray([
		CampaignFormat.terms_text(title, demand, 1, false),
		_targets(state, rules, house, EconomyBreakdown.CURRENT, ration),
	])
	var growth := (
		PopulationRules.growth_rate(cfg, cfg.growth_pivot, ration, 0.0, 0.0)
		- PopulationRules.growth_rate(cfg, cfg.growth_pivot, cfg.normal_ration, 0.0, 0.0)
	)
	lines.append(tr("CAMPAIGN_RATION_GROWTH") % CampaignFormat.signed(growth * 100.0, 0))
	return "\n".join(lines)


func _tax_terms(state: GameState, rules: GameRules, house: String, rate: int) -> Array[EconomyTerm]:
	var taxes: Array[EconomyTerm] = []
	for term: EconomyTerm in EconomyBreakdown.income(state, rules.map, rules.economy, house, rate):
		if term.label_key == "ECONOMY_TERM_TAX":
			taxes.append(term)
	return taxes


## "Ziel-Zufriedenheit: Braunschweig 55,0 (jetzt 55,0), …" for the given levers.
func _targets(
	state: GameState, rules: GameRules, house: String, rate: int, ration: int
) -> String:
	var parts := PackedStringArray()
	for province: ProvinceState in state.provinces_of(house):
		var target := EconomyTerm.sum(EconomyBreakdown.target_satisfaction(
			state, rules.map, rules.economy, house, province.id, rate, ration
		))
		parts.append("%s %s" % [
			CampaignFormat.province_name(province.id), CampaignFormat.number(target, 1)
		])
	return tr("CAMPAIGN_TARGETS") % ", ".join(parts)
