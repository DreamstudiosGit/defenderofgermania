class_name AiSupply
extends RefCounted
## Decision level 1, supply (GDD): ransom a captured leader, forecast grain until the next
## harvest — buy or cut the ration on a deficit, sell a large surplus — and raise the tax when
## taler run short as long as every province's target satisfaction stays above the minimum;
## lower it again when the people grumble and the treasury allows.


static func run(turn: AiTurn) -> void:
	_ransom(turn)
	_grain(turn)
	_tax(turn)


static func _ransom(turn: AiTurn) -> void:
	var owner := turn.owner()
	if not owner.is_leader_captured():
		return
	var cfg := turn.rules.economy
	var price := PayRansomCommand.ransom(turn.state, cfg, turn.house)
	if owner.gold - price >= turn.reserve():
		turn.act(PayRansomCommand.new(cfg, turn.house), "ransom", price)


static func _grain(turn: AiTurn) -> void:
	var rules := turn.rules
	var cfg := rules.economy
	var forecast := EconomyForecast.create(turn.state, rules.map, cfg, turn.house)
	var owner := turn.owner()
	if forecast.runs_short():
		var need := ceili(forecast.shortage * turn.cfg.supply["grain_buffer"])
		var price := GrainRules.buy_price(
			TradeGrainCommand.current_price(turn.state, cfg), cfg.houses[turn.house].grain_spread
		)
		var affordable := floori(maxf(turn.spare_gold(), 0.0) / maxf(price, 0.01))
		var amount := mini(need, affordable)
		if amount > 0:
			turn.act(TradeGrainCommand.new(cfg, turn.house, amount), "buy grain", amount)
		if amount < need and owner.ration > cfg.rations[0]:
			turn.act(SetRationCommand.new(cfg, turn.house, cfg.rations[0]), "cut ration", need)
		return
	if owner.ration < cfg.normal_ration:
		turn.act(SetRationCommand.new(cfg, turn.house, cfg.normal_ration), "normal ration", 0.0)
	var yearly := GrainBreakdown.yearly_grain_demand(turn.state, cfg, turn.house)
	var surplus := forecast.stock_after_harvest - yearly * turn.cfg.supply["grain_surplus_years"]
	if surplus > 1.0:
		var sold := -floori(surplus)
		turn.act(TradeGrainCommand.new(cfg, turn.house, sold), "sell surplus grain", surplus)


static func _tax(turn: AiTurn) -> void:
	var rules := turn.rules
	var cfg := rules.economy
	var owner := turn.owner()
	var change := EconomyTerm.sum(
		EconomyBreakdown.gold_change(turn.state, rules.map, cfg, turn.house)
	)
	var rates := cfg.tax_rates
	var index := rates.find(owner.tax_rate)
	if owner.gold + change < turn.reserve() and index < rates.size() - 1:
		var higher := rates[index + 1]
		var bankrupt := owner.gold + change < 0.0
		if bankrupt or _lowest_target(turn, higher) >= turn.cfg.supply["min_satisfaction"]:
			turn.act(SetTaxRateCommand.new(cfg, turn.house, higher), "raise tax", -change)
		if bankrupt:
			var silver := PlayPatronCommand.new(rules.map, turn.house, PlayPatronCommand.SILVER)
			if silver.validate(turn.state).is_empty():
				turn.act(silver, "patron silver against bankruptcy", -change)
		return
	var grumbling := _lowest_satisfaction(turn) < turn.cfg.supply["low_satisfaction"]
	if grumbling and index > 0 and owner.gold + change > turn.reserve() * 3.0:
		turn.act(SetTaxRateCommand.new(cfg, turn.house, rates[index - 1]), "lower tax", change)


## Lowest target satisfaction among the own provinces at this tax rate.
static func _lowest_target(turn: AiTurn, tax_rate: int) -> float:
	var lowest := INF
	var rules := turn.rules
	for province: ProvinceState in turn.state.provinces_of(turn.house):
		var terms := EconomyBreakdown.target_satisfaction(
			turn.state, rules.map, rules.economy, turn.house, province.id, tax_rate
		)
		lowest = minf(lowest, EconomyTerm.sum(terms))
	return lowest


static func _lowest_satisfaction(turn: AiTurn) -> float:
	var lowest := INF
	for province: ProvinceState in turn.state.provinces_of(turn.house):
		lowest = minf(lowest, province.satisfaction)
	return lowest
