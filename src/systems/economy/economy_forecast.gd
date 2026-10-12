class_name EconomyForecast
extends RefCounted
## The "Kornvogt" (GDD "UI/UX"): the house's grain stock against its demand until the next
## autumn harvest, at today's people and armies and normal weather. Settlements are counted
## from now: settlement 0 ends this round, the harvest comes in at settlement
## rounds_to_harvest, before that settlement's meal (docs/design/economy.md, "Settlement order").

const NO_SHORTAGE := -1

## Settlements before the one that brings in the harvest; 0 in autumn.
var rounds_to_harvest: int
var stock: float
## Stock left when the harvest comes in, after the meals and spoilage before it.
var stock_before_harvest: float
var expected_harvest: float
## Stock after the harvest settlement's meal and spoilage.
var stock_after_harvest: float
## Grain eaten at settlements 0 … rounds_to_harvest.
var demand := PackedFloat64Array()
## First settlement whose meal the stock cannot cover, or NO_SHORTAGE.
var shortage_round: int = NO_SHORTAGE
## Bushels missing at shortage_round.
var shortage: float = 0.0


static func create(
	state: GameState, map: MapData, cfg: EconomyConfig, house_id: String
) -> EconomyForecast:
	var forecast := EconomyForecast.new()
	var season := state.season()
	forecast.rounds_to_harvest = posmod(
		GameState.Season.AUTUMN - season, GameState.ROUNDS_PER_YEAR
	)
	forecast.stock = state.houses[house_id].grain
	var harvest_terms := GrainBreakdown.harvest(
		state, map, cfg, house_id, {}, forecast.rounds_to_harvest
	)
	forecast.expected_harvest = EconomyTerm.sum(harvest_terms)
	var kept := 1.0 - GrainBreakdown.spoilage(state, cfg, house_id).value
	var left := forecast.stock
	for settlement: int in forecast.rounds_to_harvest + 1:
		var settlement_season := posmod(season + settlement, GameState.ROUNDS_PER_YEAR)
		var meal := EconomyTerm.sum(
			GrainBreakdown.grain_demand(
				state, cfg, house_id, settlement_season as GameState.Season
			)
		)
		forecast.demand.append(meal)
		if settlement == forecast.rounds_to_harvest:
			forecast.stock_before_harvest = left
			left += forecast.expected_harvest
		if meal > left and forecast.shortage_round == NO_SHORTAGE:
			forecast.shortage_round = settlement
			forecast.shortage = meal - left
		left = maxf(0.0, left - meal) * kept
	forecast.stock_after_harvest = left
	return forecast


func runs_short() -> bool:
	return shortage_round != NO_SHORTAGE
