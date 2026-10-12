class_name PlayPatronCommand
extends Command
## Plays a patron card of the house's camp (England for the north, France for the south):
## silver, mercenaries for the next battle, or an embassy to an elector. A weakened patron
## gives less (event "Tod des Löwenherz").

const SILVER := "silver"
const MERCENARIES := "mercenaries"
const EMBASSY := "embassy"
const CARDS: Array[String] = [SILVER, MERCENARIES, EMBASSY]
const ERROR_UNKNOWN_CARD := "CROWN_PATRON_UNKNOWN"
const ERROR_NO_CARDS := "CROWN_NO_PATRON_CARDS"
const ERROR_PLAYED := "CROWN_PATRON_PLAYED"
const ERROR_NOT_ELECTOR := "CROWN_NOT_ELECTOR"

var card: String
## Elector an embassy goes to.
var elector: String
var _map: MapData


func _init(map: MapData, house_id: String, card_id: String, elector_id: String = "") -> void:
	_map = map
	house = house_id
	card = card_id
	elector = elector_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if card not in CARDS:
		return ERROR_UNKNOWN_CARD
	if state.crown.patron_cards.get(house, 0) <= 0:
		return ERROR_NO_CARDS
	if state.crown.patron_played.get(house, 0) >= _map.crown.patron_cards_per_round:
		return ERROR_PLAYED
	if card == EMBASSY and elector not in _map.electors():
		return ERROR_NOT_ELECTOR
	return ""


func apply(state: GameState) -> void:
	var crown := _map.crown
	var strength: float = state.crown.patron_strength.get(CrownRules.patron_of(_map, house), 1.0)
	match card:
		SILVER:
			state.houses[house].gold += crown.patron_silver * strength
		MERCENARIES:
			var companies := roundi(crown.patron_mercenary_companies * strength)
			state.crown.mercenaries[house] = state.crown.mercenaries.get(house, 0) + companies
		EMBASSY:
			var gain := crown.patron_embassy_favour * strength
			CrownRules.change_favour(state, _map, elector, house, gain)
	state.crown.patron_cards[house] -= 1
	state.crown.patron_played[house] = state.crown.patron_played.get(house, 0) + 1
