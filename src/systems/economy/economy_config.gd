class_name EconomyConfig
extends RefCounted
## Balancing values of the economy, read from data/economy.json.

const PATH := "res://data/economy.json"

var start_gold: float
var start_grain: float
var start_prestige: float
var start_tax_rate: int
var start_ration: int
var start_satisfaction: float
var tax_rates: Array[int] = []
var rations: Array[int] = []
var normal_ration: int

var tax_factor: float
var tax_base: float
var tax_satisfaction_divisor: float
var market_factor: float
var market_autumn_multiplier: float
var market_unrest_threshold: float
var market_unrest_multiplier: float

var harvest_disrupted_multiplier: float
var weather_values: PackedFloat64Array
var weather_weights: PackedFloat32Array
var winter_abroad_multiplier: float
var shortage_satisfaction: float
var shortage_population: float
var shortage_morale: float
var shortage_prestige: float
var spoilage_base: float
var spoilage_min: float

var base_grain_price: float
var price_noise_min: float
var price_noise_max: float
var price_rise_per_round: float
var grain_spread: float
var price_impact_per_100: float
var price_min: float
var price_max: float

var satisfaction_adjust_rate: float
var satisfaction_base: float
var tax_pivot: float
var tax_weight: float
var ration_weight: float
var prestige_divisor: float
var home_castle_bonus: float
var occupation_penalty: float
var ban_penalty: float
var revolt_threshold: float
var revolt_chance_per_point: float
var revolt_prestige: float
var rebel_population_divisor: float
var concession_rounds: int
var concession_satisfaction: float
var satisfaction_max: float

var growth_base: float
var growth_pivot: float
var growth_span: float
var ration_growth: float
var capacity_start_factor: float
var capacity_per_castle_level: float
var capacity_per_market_level: float

var prestige_decay: float
var prestige_max: float
var ban_prestige: float
var desertion_share: float
var treasury_satisfaction_penalty: float
var recruit_population_per_unit: float
var recruit_satisfaction_cost: float
var battle_won_prestige: float
var battle_lost_prestige: float
var tournament_won_prestige: float
var tournament_hosted_prestige: float
var tournament_cost: float
var slots_per_province: int
var slots_per_home_castle_level: int
var slots_max: int
var ransom_base: float
var ransom_per_home_castle_level: float
var siege_starve_loss: float
var siege_upkeep_multiplier: float
var decoration_limit: int

var houses: Dictionary[String, HouseModifiers] = {}
var units: Dictionary[String, RecruitDef] = {}
var buildings: Dictionary[String, BuildingDef] = {}
var home_castle: Dictionary[int, CastleLevelDef] = {}
var province_castle: Dictionary[int, CastleLevelDef] = {}
var decorations: Dictionary[String, DecorationDef] = {}


class HouseModifiers:
	var market_multiplier: float = 1.0
	var grain_spread: float
	var building_income: Dictionary[String, float] = {}
	var building_cost: Dictionary[String, float] = {}
	var unit_cost: Dictionary[String, float] = {}


static func load_file(path: String = PATH) -> EconomyConfig:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var config := EconomyConfig.new()
	config._read(reader, data)
	config._check(reader)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else config


func _read(r: DataReader, data: Dictionary) -> void:
	var start := r.object(data, "start")
	start_gold = r.number(start, "gold")
	start_grain = r.number(start, "grain")
	start_prestige = r.number(start, "prestige")
	start_tax_rate = r.integer(start, "tax_rate")
	start_ration = r.integer(start, "ration")
	start_satisfaction = r.number(start, "satisfaction")
	for value: float in r.numbers(data, "tax_rates"):
		tax_rates.append(int(value))
	for value: float in r.numbers(data, "rations"):
		rations.append(int(value))
	normal_ration = r.integer(data, "normal_ration")

	var tax := r.object(data, "tax")
	tax_factor = r.number(tax, "factor")
	tax_base = r.number(tax, "base")
	tax_satisfaction_divisor = r.number(tax, "satisfaction_divisor")
	var market := r.object(data, "market")
	market_factor = r.number(market, "factor")
	market_autumn_multiplier = r.number(market, "autumn_multiplier")
	market_unrest_threshold = r.number(market, "unrest_threshold")
	market_unrest_multiplier = r.number(market, "unrest_multiplier")

	harvest_disrupted_multiplier = r.number(
		r.object(data, "harvest"), "disrupted_multiplier"
	)
	var weather := r.object(data, "weather")
	weather_values = r.numbers(weather, "values")
	weather_weights = PackedFloat32Array(Array(r.numbers(weather, "weights")))
	var grain := r.object(data, "grain")
	winter_abroad_multiplier = r.number(grain, "winter_abroad_multiplier")
	shortage_satisfaction = r.number(grain, "shortage_satisfaction")
	shortage_population = r.number(grain, "shortage_population")
	shortage_morale = r.number(grain, "shortage_morale")
	shortage_prestige = r.number(grain, "shortage_prestige")
	spoilage_base = r.number(grain, "spoilage_base")
	spoilage_min = r.number(grain, "spoilage_min")

	var price := r.object(data, "grain_market")
	base_grain_price = r.number(price, "base_price")
	price_noise_min = r.number(price, "noise_min")
	price_noise_max = r.number(price, "noise_max")
	price_rise_per_round = r.number(price, "rise_per_round")
	grain_spread = r.number(price, "spread")
	price_impact_per_100 = r.number(price, "impact_per_100")
	price_min = r.number(price, "price_min")
	price_max = r.number(price, "price_max")

	_read_society(r, data)
	_read_tables(r, data)


func _read_society(r: DataReader, data: Dictionary) -> void:
	var sat := r.object(data, "satisfaction")
	satisfaction_adjust_rate = r.number(sat, "adjust_rate")
	satisfaction_base = r.number(sat, "base")
	tax_pivot = r.number(sat, "tax_pivot")
	tax_weight = r.number(sat, "tax_weight")
	ration_weight = r.number(sat, "ration_weight")
	prestige_divisor = r.number(sat, "prestige_divisor")
	home_castle_bonus = r.number(sat, "home_castle_bonus")
	occupation_penalty = r.number(sat, "occupation_penalty")
	ban_penalty = r.number(sat, "ban_penalty")
	revolt_threshold = r.number(sat, "revolt_threshold")
	revolt_chance_per_point = r.number(sat, "revolt_chance_per_point")
	revolt_prestige = r.number(sat, "revolt_prestige")
	rebel_population_divisor = r.number(sat, "rebel_population_divisor")
	concession_rounds = r.integer(sat, "concession_rounds")
	concession_satisfaction = r.number(sat, "concession_satisfaction")
	satisfaction_max = r.number(sat, "max")

	var pop := r.object(data, "population")
	growth_base = r.number(pop, "growth_base")
	growth_pivot = r.number(pop, "growth_pivot")
	growth_span = r.number(pop, "growth_span")
	ration_growth = r.number(pop, "ration_growth")
	capacity_start_factor = r.number(pop, "capacity_start_factor")
	capacity_per_castle_level = r.number(pop, "capacity_per_castle_level")
	capacity_per_market_level = r.number(pop, "capacity_per_market_level")

	var prestige := r.object(data, "prestige")
	prestige_decay = r.number(prestige, "decay")
	prestige_max = r.number(prestige, "max")
	ban_prestige = r.number(prestige, "ban_per_round")
	battle_won_prestige = r.number(prestige, "battle_won")
	battle_lost_prestige = r.number(prestige, "battle_lost")
	tournament_won_prestige = r.number(prestige, "tournament_won")
	tournament_hosted_prestige = r.number(prestige, "tournament_hosted")
	tournament_cost = r.number(r.object(data, "tournament"), "cost")
	var treasury := r.object(data, "treasury")
	desertion_share = r.number(treasury, "desertion_share")
	treasury_satisfaction_penalty = r.number(treasury, "satisfaction_penalty")
	var recruitment := r.object(data, "recruitment")
	recruit_population_per_unit = r.number(recruitment, "population_per_unit")
	recruit_satisfaction_cost = r.number(recruitment, "satisfaction_cost")
	_read_administration(r, data)


func _read_administration(r: DataReader, data: Dictionary) -> void:
	var slots := r.object(data, "slots")
	slots_per_province = r.integer(slots, "province")
	slots_per_home_castle_level = r.integer(slots, "home_per_castle_level")
	slots_max = r.integer(slots, "max")
	var ransom := r.object(data, "ransom")
	ransom_base = r.number(ransom, "base")
	ransom_per_home_castle_level = r.number(ransom, "per_home_castle_level")
	var siege := r.object(data, "siege")
	siege_starve_loss = r.number(siege, "starve_loss")
	siege_upkeep_multiplier = r.number(siege, "upkeep_multiplier")
	decoration_limit = r.integer(data, "decoration_limit")


func _read_tables(r: DataReader, data: Dictionary) -> void:
	var house_data := r.object(data, "houses")
	for id: String in house_data:
		r.context = "houses.%s" % id
		var entry := r.object(house_data, id)
		var house := HouseModifiers.new()
		house.market_multiplier = r.number(entry, "market_multiplier", 1.0)
		house.grain_spread = r.number(entry, "grain_spread", grain_spread)
		house.building_income = _multipliers(r, entry, "building_income")
		house.building_cost = _multipliers(r, entry, "building_cost")
		house.unit_cost = _multipliers(r, entry, "unit_cost")
		houses[id] = house

	var unit_data := r.object(data, "units")
	for id: String in unit_data:
		r.context = "units.%s" % id
		units[id] = RecruitDef.read(r, r.object(unit_data, id))

	var building_data := r.object(data, "buildings")
	for id: String in building_data:
		r.context = "buildings.%s" % id
		buildings[id] = BuildingDef.read(r, r.object(building_data, id))

	r.context = ""
	home_castle = CastleLevelDef.read_table(r, data, "home_castle")
	province_castle = CastleLevelDef.read_table(r, data, "province_castle")

	var decoration_data := r.object(data, "decorations")
	for id: String in decoration_data:
		r.context = "decorations.%s" % id
		decorations[id] = DecorationDef.read(r, r.object(decoration_data, id))
	r.context = ""


func _multipliers(r: DataReader, entry: Dictionary, key: String) -> Dictionary[String, float]:
	var result: Dictionary[String, float] = {}
	var data := r.object(entry, key, false)
	for id: String in data:
		result[id] = r.number(data, id)
	return result


func _check(r: DataReader) -> void:
	if weather_values.size() != weather_weights.size():
		r.errors.append("weather: values and weights differ in length")
	if start_tax_rate not in tax_rates:
		r.errors.append("start.tax_rate: not one of tax_rates")
	if start_ration not in rations or normal_ration not in rations:
		r.errors.append("start.ration / normal_ration: not one of rations")
	if not home_castle.has(1) or not province_castle.has(0):
		r.errors.append("castle tables: need home_castle level 1 and province_castle level 0")
	for id: String in buildings:
		var upgrade_of := buildings[id].upgrade_of
		if not upgrade_of.is_empty() and not buildings.has(upgrade_of):
			r.errors.append("buildings.%s.upgrade_of: unknown building '%s'" % [id, upgrade_of])
	for id: String in units:
		var requires := units[id].requires
		if not requires.is_empty() and not buildings.has(requires):
			r.errors.append("units.%s.requires: unknown building '%s'" % [id, requires])
