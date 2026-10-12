class_name CampaignHud
extends PanelContainer
## Top bar of the campaign: house, date and phase; taler, grain and prestige, each with its
## calculation as tooltip; the electors' votes with the three pillars as tooltip and a ban
## marker; the always visible grain forecast ("Kornvogt") and the button that ends the phase.
## Anchor it to the top edge; refresh() after every command.

signal command_requested(command: Command)

## The Kornvogt warns this many settlements ahead of a shortage (GDD "UI/UX").
const WARNING_ROUNDS := 2

var _badge := HouseBadge.new(Vector2(34, 40))
var _house := CampaignStyle.label("", 22)
var _date := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _gold := CampaignStyle.info(20)
var _grain := CampaignStyle.info(20)
var _prestige := CampaignStyle.info(20)
var _crown := CampaignStyle.info(20)
var _forecast := CampaignStyle.label("", CampaignStyle.SMALL_SIZE - 1, CampaignStyle.MUTED)
var _end_phase := Button.new()
var _rules: GameRules
var _house_id := ""


func _init() -> void:
	theme = CampaignStyle.theme()
	add_theme_stylebox_override("panel", CampaignStyle.panel_style(CampaignStyle.PANEL, 2, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge)
	row.add_child(_stack([_house, _date]))
	row.add_child(VSeparator.new())
	var numbers := VBoxContainer.new()
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.add_theme_constant_override("separation", 0)
	row.add_child(numbers)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 22)
	numbers.add_child(values)
	for button: Button in [_gold, _grain, _prestige, _crown]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		values.add_child(button)
	_crown.name = "crown"
	numbers.add_child(_forecast)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_end_phase.name = "end_phase"
	_end_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_phase.pressed.connect(_on_end_phase_pressed)
	row.add_child(_end_phase)
	_gold.focus_neighbor_left = _gold.get_path_to(_end_phase)
	_end_phase.focus_neighbor_right = _end_phase.get_path_to(_gold)


func refresh(state: GameState, rules: GameRules, house: String) -> void:
	_rules = rules
	_house_id = house
	var owner := state.houses[house]
	_badge.colors = rules.map.house_colors[house]
	_house.text = CampaignFormat.house_name(house)
	_house.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, house))
	_date.text = "%s · %s" % [
		CampaignFormat.date(state, rules), CampaignFormat.phase_name(state.phase)
	]
	_show_gold(state, rules, owner)
	_show_grain(state, rules, owner)
	_show_prestige(state, rules, owner)
	_show_crown(state, rules.map, owner)
	var ends_campaign := state.phase == GameState.Phase.CAMPAIGN
	_end_phase.text = tr("CAMPAIGN_END_CAMPAIGN" if ends_campaign else "CAMPAIGN_END_ADMINISTRATION")
	var error := EndPhaseCommand.new(rules, house).validate(state)
	_end_phase.disabled = not error.is_empty()
	_end_phase.tooltip_text = tr(error) if not error.is_empty() else tr("CAMPAIGN_END_PHASE_HINT")


## Focuses the end-phase button, e.g. when a new house takes over.
func focus_end_phase() -> void:
	_end_phase.grab_focus()


## Focuses the taler, grain (1), prestige (2) or votes (3) number, whose tooltip FocusTooltip
## shows.
func focus_number(index: int) -> void:
	[_gold, _grain, _prestige, _crown][clampi(index, 0, 3)].grab_focus()


func _show_gold(state: GameState, rules: GameRules, owner: HouseState) -> void:
	var terms := EconomyBreakdown.gold_change(state, rules.map, rules.economy, owner.id)
	var change := EconomyTerm.sum(terms)
	_gold.text = "%s %s  (%s)" % [
		tr("CAMPAIGN_GOLD"), CampaignFormat.number(owner.gold), CampaignFormat.signed(change, 0)
	]
	_gold.add_theme_color_override("font_color", _trend_color(owner.gold + change, 0.0))
	_gold.tooltip_text = CampaignFormat.terms_text(tr("CAMPAIGN_GOLD_CHANGE"), terms)


func _show_grain(state: GameState, rules: GameRules, owner: HouseState) -> void:
	var cfg := rules.economy
	var forecast := EconomyForecast.create(state, rules.map, cfg, owner.id)
	var warn := forecast.runs_short() and forecast.shortage_round <= WARNING_ROUNDS
	_grain.text = "%s %s" % [tr("CAMPAIGN_GRAIN"), CampaignFormat.number(owner.grain)]
	_grain.add_theme_color_override(
		"font_color", CampaignStyle.BAD if warn else CampaignStyle.TEXT
	)
	if warn:
		_forecast.text = tr("CAMPAIGN_FORECAST_SHORT") % [
			CampaignFormat.in_rounds(forecast.shortage_round), CampaignFormat.number(forecast.shortage)
		]
	else:
		_forecast.text = tr("CAMPAIGN_FORECAST_OK") % [
			CampaignFormat.in_rounds(forecast.rounds_to_harvest),
			CampaignFormat.number(forecast.stock_before_harvest),
		]
	_forecast.add_theme_color_override(
		"font_color", CampaignStyle.BAD if warn else CampaignStyle.MUTED
	)
	var tip := GrainTooltip.text(state, rules, owner.id, forecast)
	_grain.tooltip_text = tip
	_forecast.tooltip_text = tip


func _show_prestige(state: GameState, rules: GameRules, owner: HouseState) -> void:
	var terms := EconomyBreakdown.prestige(state, rules.economy, owner.id)
	_prestige.text = "%s %s" % [tr("CAMPAIGN_PRESTIGE"), CampaignFormat.number(owner.prestige, 1)]
	var title := tr("CAMPAIGN_PRESTIGE_CHANGE")
	var cfg := rules.economy
	var note := tr("CAMPAIGN_PRESTIGE_NOTE") % [
		CampaignFormat.number(cfg.shortage_prestige), CampaignFormat.number(cfg.revolt_prestige)
	]
	_prestige.tooltip_text = "%s\n%s" % [CampaignFormat.terms_text(title, terms), note]


## "Stimmen 2/7", red with the ban marker while the church bans the house, green once the
## votes reach the cheapest coronation open to it.
func _show_crown(state: GameState, map: MapData, owner: HouseState) -> void:
	var count := CrownRules.vote_count(state, map, owner.id)
	var needed := CrownRules.votes_needed(state, map, owner.id)
	_crown.text = tr("CAMPAIGN_CROWN_HUD_VOTES") % [count, map.electors().size()]
	var color := CampaignStyle.TEXT
	if owner.is_banned:
		_crown.text += " · " + tr("CAMPAIGN_CROWN_HUD_BAN")
		color = CampaignStyle.BAD
	elif needed > 0 and count >= needed:
		color = CampaignStyle.GOOD
	_crown.add_theme_color_override("font_color", color)
	_crown.tooltip_text = CrownFormat.pillars(state, map, owner.id)


func _trend_color(value: float, limit: float) -> Color:
	return CampaignStyle.BAD if value < limit else CampaignStyle.TEXT


func _stack(labels: Array[Label]) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	for label: Label in labels:
		box.add_child(label)
	return box


func _on_end_phase_pressed() -> void:
	if _rules != null:
		command_requested.emit(EndPhaseCommand.new(_rules, _house_id))
