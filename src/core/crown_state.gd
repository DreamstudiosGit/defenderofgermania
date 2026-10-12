class_name CrownState
extends RefCounted
## The road to the crown in a running game: where the true regalia lie, who forged them, the
## favour of every elector and neutral lord, patron cards, gifts of the year, penance, promised
## votes and the coronation itself. Part of the save (GameState.to_dict).

## Province whose owner holds the true regalia (Trifels at the start).
var regalia_province: String = ""
## Houses that hold forged regalia, and houses forging them with the rounds left.
var forged_regalia: Array[String] = []
var forging: Dictionary[String, int] = {}
## Favour of a lord (elector or neutral province) towards a house, keyed "<PROVINCE>:<house>".
var favour: Dictionary[String, float] = {}
## Elector province → house it promised its vote (event "Böhmische Königswürde").
var promised_votes: Dictionary[String, String] = {}
## Patron cards a house has left, and how many it played this round.
var patron_cards: Dictionary[String, int] = {}
var patron_played: Dictionary[String, int] = {}
## Strength of a patron power's cards (england, france); 1 is full.
var patron_strength: Dictionary[String, float] = {}
## Mercenary companies a patron sent for the house's next battle.
var mercenaries: Dictionary[String, int] = {}
## Gifts a house gave a lord this year, keyed "<PROVINCE>:<house>"; cleared every spring.
var gifts: Dictionary[String, int] = {}
## First round in which a house that did penance may campaign again.
var penance_until: Dictionary[String, int] = {}
## Round in which a house last hosted a tournament.
var tournament_turn: Dictionary[String, int] = {}
## Coronation site tag of the winner's coronation; "" until someone is crowned.
var crowned_at: String = ""


static func key(province_id: String, house: String) -> String:
	return "%s:%s" % [province_id, house]


func favour_of(province_id: String, house: String) -> float:
	return favour.get(key(province_id, house), 0.0)


func has_favour_list(province_id: String, house: String) -> bool:
	return favour.has(key(province_id, house))


func set_favour(province_id: String, house: String, value: float, maximum: float) -> void:
	favour[key(province_id, house)] = clampf(value, 0.0, maximum)


static func from_dict(r: DataReader, data: Dictionary) -> CrownState:
	var crown := CrownState.new()
	crown.regalia_province = r.text(data, "regalia_province")
	crown.forged_regalia = r.strings(data, "forged_regalia")
	crown.crowned_at = r.text(data, "crowned_at")
	var favour_data := r.object(data, "favour")
	for id: String in favour_data:
		crown.favour[id] = r.number(favour_data, id)
	var strength := r.object(data, "patron_strength")
	for id: String in strength:
		crown.patron_strength[id] = r.number(strength, id)
	var promised := r.object(data, "promised_votes")
	for id: String in promised:
		crown.promised_votes[id] = r.text(promised, id)
	for field: String in [
		"forging", "patron_cards", "patron_played", "mercenaries", "gifts", "penance_until",
		"tournament_turn",
	]:
		var counts := r.object(data, field)
		var target: Dictionary[String, int] = crown.get(field)
		for id: String in counts:
			target[id] = r.integer(counts, id, 0)
	return crown


func to_dict() -> Dictionary:
	return {
		"regalia_province": regalia_province,
		"forged_regalia": forged_regalia,
		"forging": forging,
		"favour": favour,
		"promised_votes": promised_votes,
		"patron_cards": patron_cards,
		"patron_played": patron_played,
		"patron_strength": patron_strength,
		"mercenaries": mercenaries,
		"gifts": gifts,
		"penance_until": penance_until,
		"tournament_turn": tournament_turn,
		"crowned_at": crowned_at,
	}
