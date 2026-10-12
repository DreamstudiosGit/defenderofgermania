class_name GrainTradeSection
extends AdministrationSection
## Grain market: this round's price with the house's buy and sell price, an amount slider and
## buy and sell buttons that show what the trade costs or earns.

const STEP := 10

var _prices := CampaignStyle.label()
var _stock := CampaignStyle.paragraph()
var _amount := HSlider.new()
var _amount_label := CampaignStyle.label()
var _impact := CampaignStyle.paragraph()
var _buy: Button
var _sell: Button
var _state: GameState
var _rules: GameRules
var _house := ""


func _init() -> void:
	super()
	column.add_child(CampaignStyle.heading(tr("CAMPAIGN_GRAIN_MARKET"), 18))
	_prices.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_prices)
	column.add_child(_stock)
	column.add_child(HSeparator.new())
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 10)
	column.add_child(amount_row)
	amount_row.add_child(CampaignStyle.label(tr("CAMPAIGN_AMOUNT")))
	_amount.step = STEP
	_amount.min_value = STEP
	_amount.value = 100
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_amount.custom_minimum_size.y = 28
	_amount.value_changed.connect(func(_value: float) -> void: _show_trades())
	amount_row.add_child(_amount)
	_amount_label.custom_minimum_size.x = 110
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_row.add_child(_amount_label)
	_buy = button(column, "buy")
	_sell = button(column, "sell")
	column.add_child(_impact)


func refresh(state: GameState, rules: GameRules, house: String, _province_id: String) -> void:
	_state = state
	_rules = rules
	_house = house
	var cfg := rules.economy
	var owner := state.houses[house]
	var prices := GrainBreakdown.grain_prices(state, cfg, house)
	_prices.text = tr("CAMPAIGN_PRICES") % [
		CampaignFormat.number(prices[0].value, 2),
		CampaignFormat.number(prices[1].value, 2),
		CampaignFormat.number(prices[2].value, 2),
	]
	var lines := PackedStringArray()
	for term: EconomyTerm in prices:
		lines.append(CampaignFormat.term_line(term, 3, false))
	_prices.tooltip_text = "\n".join(lines)
	_stock.text = tr("CAMPAIGN_STOCK") % [
		CampaignFormat.number(owner.grain), CampaignFormat.number(owner.gold)
	]
	var affordable := floorf(owner.gold / maxf(prices[1].value, 0.01))
	var most := maxf(affordable, owner.grain)
	_amount.max_value = maxf(STEP, floorf(most / STEP) * STEP)
	_impact.text = tr("CAMPAIGN_TRADE_IMPACT") % CampaignFormat.percent(cfg.price_impact_per_100)
	_show_trades()


func _show_trades() -> void:
	if _state == null:
		return
	var amount := int(_amount.value)
	_amount_label.text = tr("CAMPAIGN_BUSHELS") % amount
	var cfg := _rules.economy
	var prices := GrainBreakdown.grain_prices(_state, cfg, _house)
	var cost := CampaignFormat.number(amount * prices[1].value, 1)
	var earning := CampaignFormat.number(amount * prices[2].value, 1)
	var buy := TradeGrainCommand.new(cfg, _house, amount)
	offer(_buy, tr("CAMPAIGN_BUY") % [amount, cost], buy, _state, tr("CAMPAIGN_BUY_HINT"))
	var sell := TradeGrainCommand.new(cfg, _house, -amount)
	offer(_sell, tr("CAMPAIGN_SELL") % [amount, earning], sell, _state, tr("CAMPAIGN_SELL_HINT"))
