class_name GameState
extends RefCounted
## The complete simulation state as plain data: systems mutate it, render/ui only read it.
## to_dict() is the save format; bump SAVE_VERSION whenever its shape changes.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
enum Phase { EVENT, ADMINISTRATION, CAMPAIGN, SETTLEMENT, GAME_OVER }

const SAVE_VERSION := 2
const ROUNDS_PER_YEAR := 4

var turn: int = 0
var phase: Phase = Phase.EVENT
## Houses in playing order this round; active_index points at the one whose turn it is.
var turn_order: Array[String] = []
var active_index: int = 0
var winner: String = ""
var next_army_id: int = 0
## Net bushels all houses bought this round; shifts the grain price until settlement.
var grain_traded: float = 0.0
var rng := RandomNumberGenerator.new()
var autumn_grain_price: float = 0.0
var weather: Dictionary[String, float] = {}
var houses: Dictionary[String, HouseState] = {}
var provinces: Dictionary[String, ProvinceState] = {}
var armies: Array[ArmyState] = []


static func from_dict(data: Dictionary) -> GameState:
	var r := DataReader.new()
	var version := r.integer(data, "version")
	if version != SAVE_VERSION:
		push_error("save version %d is not supported (expected %d)" % [version, SAVE_VERSION])
		return null
	var state := GameState.new()
	state.turn = r.integer(data, "turn")
	var phase_value := r.integer(data, "phase")
	if phase_value not in Phase.values():
		r.errors.append("phase: unknown value %d" % phase_value)
	state.phase = phase_value as Phase
	state.turn_order = r.strings(data, "turn_order")
	state.active_index = r.integer(data, "active_index")
	state.winner = r.text(data, "winner")
	state.next_army_id = r.integer(data, "next_army_id")
	state.grain_traded = r.number(data, "grain_traded")
	# Setting the seed resets the RNG state, so the state must be restored afterwards.
	state.rng.seed = r.text(data, "rng_seed").to_int()
	state.rng.state = r.text(data, "rng_state").to_int()
	state.autumn_grain_price = r.number(data, "autumn_grain_price")
	var weather_data := r.object(data, "weather")
	for region: String in weather_data:
		state.weather[region] = r.number(weather_data, region)
	for entry: Variant in r.list(data, "houses"):
		var house := HouseState.from_dict(r, _as_object(r, entry))
		state.houses[house.id] = house
	for entry: Variant in r.list(data, "provinces"):
		var province := ProvinceState.from_dict(r, _as_object(r, entry))
		state.provinces[province.id] = province
	for entry: Variant in r.list(data, "armies"):
		state.armies.append(ArmyState.from_dict(r, _as_object(r, entry)))
	for error: String in r.errors:
		push_error("save data: %s" % error)
	return null if r.errors else state


static func from_bytes(bytes: PackedByteArray) -> GameState:
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		push_error("save data: not a dictionary")
		return null
	return from_dict(data)


static func _as_object(r: DataReader, value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	r.errors.append("expected an object, got %s" % type_string(typeof(value)))
	return {}


func active_house() -> String:
	return turn_order[active_index] if active_index < turn_order.size() else ""


func is_over() -> bool:
	return phase == Phase.GAME_OVER


func season() -> Season:
	return (turn % ROUNDS_PER_YEAR) as Season


func rounds_since_autumn() -> int:
	return posmod(turn - Season.AUTUMN, ROUNDS_PER_YEAR)


func provinces_of(owner: String) -> Array[ProvinceState]:
	var result: Array[ProvinceState] = []
	for province: ProvinceState in provinces.values():
		if province.owner == owner:
			result.append(province)
	return result


func armies_of(owner: String) -> Array[ArmyState]:
	var result: Array[ArmyState] = []
	for army: ArmyState in armies:
		if army.owner == owner:
			result.append(army)
	return result


func army(army_id: int) -> ArmyState:
	for candidate: ArmyState in armies:
		if candidate.id == army_id:
			return candidate
	return null


func armies_in(province_id: String) -> Array[ArmyState]:
	var result: Array[ArmyState] = []
	for candidate: ArmyState in armies:
		if candidate.province == province_id:
			result.append(candidate)
	return result


func add_army(owner: String, province_id: String) -> ArmyState:
	var created := ArmyState.new()
	created.id = next_army_id
	next_army_id += 1
	created.owner = owner
	created.province = province_id
	armies.append(created)
	return created


## Removes the army; a free leader riding with it returns to the home castle.
func remove_army(removed: ArmyState) -> void:
	armies.erase(removed)
	var house: HouseState = houses.get(removed.owner)
	if house != null and house.leader_army == removed.id:
		house.leader_army = HouseState.NO_ARMY


## Castle level of the house's home province; 0 while the house has lost it.
func home_castle_level(house_id: String) -> int:
	var home: ProvinceState = provinces.get(houses[house_id].home_province)
	return home.castle_level if home != null and home.owner == house_id else 0


## An army in a foreign province with a castle besieges it: garrisons fall the moment they
## break, so a foreign castle the army sits in still holds out.
func is_besieging(besieger: ArmyState) -> bool:
	var province := provinces[besieger.province]
	return province.owner != besieger.owner and province.castle_level > 0


## Hash of the full state; equal for equal seeds and commands (determinism check).
func checksum() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(to_bytes())
	return hashing.finish().hex_encode()


## Binary save data. Not JSON: Godot's JSON parser does not read doubles back exactly,
## so a game loaded from JSON would drift away from the original.
func to_bytes() -> PackedByteArray:
	return var_to_bytes(to_dict())


func to_dict() -> Dictionary:
	var house_data: Array[Dictionary] = []
	for house: HouseState in houses.values():
		house_data.append(house.to_dict())
	var province_data: Array[Dictionary] = []
	for province: ProvinceState in provinces.values():
		province_data.append(province.to_dict())
	var army_data: Array[Dictionary] = []
	for army: ArmyState in armies:
		army_data.append(army.to_dict())
	# 64-bit RNG values are strings so the dict survives JSON dumps, whose numbers lose
	# precision above 2^53.
	return {
		"version": SAVE_VERSION,
		"turn": turn,
		"phase": phase,
		"turn_order": turn_order,
		"active_index": active_index,
		"winner": winner,
		"next_army_id": next_army_id,
		"grain_traded": grain_traded,
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
		"autumn_grain_price": autumn_grain_price,
		"weather": weather,
		"houses": house_data,
		"provinces": province_data,
		"armies": army_data,
	}
